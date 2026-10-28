// Package tui is the interactive manager for omnitun-server: users, their
// links and QR codes, protocols and the web API settings. Everything goes
// through server/manager, the same layer the CLI and the web API use; a
// running server picks changes up within seconds.
package tui

import (
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/charmbracelet/bubbles/table"
	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/huh"
	"github.com/charmbracelet/lipgloss"

	"github.com/NoobforAl/omnitun/server/logs"
	"github.com/NoobforAl/omnitun/server/manager"
	"github.com/NoobforAl/omnitun/server/qrterm"
	"github.com/NoobforAl/omnitun/server/store"
)

type view int

const (
	viewUsers view = iota
	viewProtocols
	viewServer
	viewLogs
	viewAlerts
	viewUser // links and QR codes of one user
)

var tabs = []string{"Users", "Protocols", "Server", "Logs", "Alerts"}

// prompt is a pending single-line input or yes/no question.
type prompt struct {
	label  string
	submit func(m *model, value string) error
}

type tickMsg time.Time

var (
	titleStyle  = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("86"))
	dimStyle    = lipgloss.NewStyle().Foreground(lipgloss.Color("245"))
	errStyle    = lipgloss.NewStyle().Foreground(lipgloss.Color("203"))
	okStyle     = lipgloss.NewStyle().Foreground(lipgloss.Color("78"))
	boxStyle    = lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(lipgloss.Color("240")).Padding(0, 1)
	tabStyle    = lipgloss.NewStyle().Padding(0, 2).Foreground(lipgloss.Color("245"))
	tabOnStyle  = lipgloss.NewStyle().Padding(0, 2).Bold(true).Foreground(lipgloss.Color("86")).Underline(true)
	maskedToken = strings.Repeat("•", 24)
)

type model struct {
	mgr    *manager.Manager
	loaded time.Time

	info   *manager.ServerInfo
	protos []manager.ProtocolInfo
	users  []manager.UserInfo
	api    store.API
	cert   *manager.CertInfo
	logs   []logs.Record

	logLevel       logs.Level   // the lowest level the log view shows
	alerts         []logs.Alert // newest first
	unacknowledged int          // shown as a badge on every screen
	alertCursor    int
	alertDetail    bool // the selected alert is expanded

	view    view
	table   table.Model
	user    string           // user shown in viewUser
	links   *manager.LinkSet // that user's links
	qrIndex int              // 0 = subscription, then each link
	proto   int              // cursor in viewProtocols
	showTok bool             // reveal the API token in viewServer

	input   textinput.Model
	prompt  *prompt
	confirm *prompt
	form    *huh.Form // the "add user" form while open
	newUser manager.NewUser
	days    string
	quota   string

	status string
	err    error
	width  int
	height int
}

// Run starts the TUI.
func Run(s *store.Store) error {
	m, err := newModel(manager.New(s))
	if err != nil {
		return err
	}
	_, err = tea.NewProgram(m, tea.WithAltScreen()).Run()
	return err
}

func newModel(mgr *manager.Manager) (*model, error) {
	tbl := table.New(
		table.WithColumns([]table.Column{
			{Title: "Name", Width: 16},
			{Title: "Status", Width: 10},
			{Title: "Expires", Width: 11},
			{Title: "Used (month)", Width: 12},
			{Title: "Quota", Width: 10},
			{Title: "Online", Width: 7},
			{Title: "Note", Width: 16},
		}),
		table.WithFocused(true),
		table.WithHeight(12),
	)
	in := textinput.New()
	in.CharLimit = 64
	m := &model{mgr: mgr, table: tbl, input: in}
	if err := m.load(); err != nil {
		return nil, err
	}
	m.loadAlerts()
	return m, nil
}

func (m *model) Init() tea.Cmd { return tick() }

func tick() tea.Cmd {
	return tea.Tick(2*time.Second, func(t time.Time) tea.Msg { return tickMsg(t) })
}

// load reads everything the views show.
func (m *model) load() error {
	info, err := m.mgr.Server()
	if err != nil {
		return err
	}
	protos, err := m.mgr.Protocols()
	if err != nil {
		return err
	}
	users, err := m.mgr.Users()
	if err != nil {
		return err
	}
	api, err := m.mgr.API()
	if err != nil {
		return err
	}
	cert, err := m.mgr.Certificate()
	if err != nil {
		return err
	}
	m.info, m.protos, m.users, m.api, m.cert = info, protos, users, api, cert
	m.loaded = m.mgr.Store.ModTime()
	m.refreshRows()
	if m.view == viewUser {
		m.links, _ = m.mgr.Links(m.user)
	}
	return nil
}

// reload picks up changes made by the CLI, the API or another TUI.
func (m *model) reload() {
	if !m.mgr.Store.ModTime().Equal(m.loaded) {
		if err := m.load(); err != nil {
			m.err = err
		}
	}
}

// do runs a manager call and reports its outcome.
func (m *model) do(done string, f func() error) {
	if err := f(); err != nil {
		m.err, m.status = err, ""
		return
	}
	m.err, m.status = nil, done
	if err := m.load(); err != nil {
		m.err = err
	}
}

func expiry(u manager.UserInfo) string {
	if u.ExpiresAt == nil {
		return "never"
	}
	return u.ExpiresAt.Local().Format("2006-01-02")
}

// humanBytes formats a byte count (1 GB = 2^30 bytes, like quotas).
func humanBytes(size int64) string {
	const k = 1024.0
	value := float64(size)
	switch {
	case value >= k*k*k:
		return fmt.Sprintf("%.2f GB", value/(k*k*k))
	case value >= k*k:
		return fmt.Sprintf("%.1f MB", value/(k*k))
	case value >= k:
		return fmt.Sprintf("%.1f KB", value/k)
	}
	return fmt.Sprintf("%d B", size)
}

func quota(u manager.UserInfo) string {
	if u.QuotaGB <= 0 {
		return "unlimited"
	}
	return strconv.FormatFloat(u.QuotaGB, 'f', -1, 64) + " GB"
}

func (m *model) refreshRows() {
	rows := make([]table.Row, 0, len(m.users))
	for _, user := range m.users {
		online := "-"
		if user.Usage.Connections > 0 {
			online = strconv.Itoa(user.Usage.Connections)
		}
		rows = append(rows, table.Row{user.Name, user.Status, expiry(user), humanBytes(user.Usage.MonthBytes), quota(user), online, user.Note})
	}
	m.table.SetRows(rows)
	// An empty table leaves the cursor at -1; select the first row once there is one.
	if m.table.Cursor() < 0 && len(rows) > 0 {
		m.table.SetCursor(0)
	}
}

func (m *model) selectedUser() *manager.UserInfo {
	row := m.table.SelectedRow()
	if row == nil {
		return nil
	}
	for i := range m.users {
		if m.users[i].Name == row[0] {
			return &m.users[i]
		}
	}
	return nil
}

func (m *model) ask(label, initial string, submit func(*model, string) error) {
	m.prompt = &prompt{label: label, submit: submit}
	m.input.SetValue(initial)
	m.input.CursorEnd()
	m.input.Focus()
}

func (m *model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	if wm, ok := msg.(tea.WindowSizeMsg); ok {
		m.width, m.height = wm.Width, wm.Height
		m.table.SetHeight(max(5, wm.Height-12))
	}
	if m.form != nil {
		return m.updateForm(msg)
	}
	switch msg := msg.(type) {
	case tickMsg:
		m.reload()
		m.loadAlerts()
		if m.view == viewLogs {
			m.loadLogs()
		}
		return m, tick()
	case tea.KeyMsg:
		if msg.String() == "ctrl+c" {
			return m, tea.Quit
		}
		if m.prompt != nil {
			return m.updatePrompt(msg)
		}
		if m.confirm != nil {
			if msg.String() == "y" {
				if err := m.confirm.submit(m, ""); err != nil {
					m.err = err
				}
			}
			m.confirm = nil
			return m, nil
		}
		if m.view != viewUser {
			switch msg.String() {
			case "tab":
				m.view = (m.view + 1) % view(len(tabs))
				return m, nil
			case "shift+tab":
				m.view = (m.view + view(len(tabs)) - 1) % view(len(tabs))
				return m, nil
			case "1", "2", "3", "4", "5":
				m.view = view(msg.String()[0] - '1')
				switch m.view {
				case viewLogs:
					m.loadLogs()
				case viewAlerts:
					m.loadAlerts()
				}
				return m, nil
			}
		}
		switch m.view {
		case viewUsers:
			return m.updateUsers(msg)
		case viewUser:
			return m.updateUser(msg)
		case viewProtocols:
			return m.updateProtocols(msg)
		case viewServer:
			return m.updateServer(msg)
		case viewLogs:
			return m.updateLogs(msg)
		case viewAlerts:
			return m.updateAlerts(msg)
		}
	}
	return m, nil
}

func (m *model) updatePrompt(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "esc":
		m.prompt = nil
		return m, nil
	case "enter":
		p := m.prompt
		m.prompt = nil
		if err := p.submit(m, strings.TrimSpace(m.input.Value())); err != nil {
			m.err = err
		}
		return m, nil
	}
	var cmd tea.Cmd
	m.input, cmd = m.input.Update(msg)
	return m, cmd
}

// openAddForm shows the "add user" form.
func (m *model) openAddForm() tea.Cmd {
	m.newUser, m.days, m.quota = manager.NewUser{}, "", ""
	number := func(s string) error {
		if s == "" {
			return nil
		}
		if n, err := strconv.ParseFloat(s, 64); err != nil || n < 0 {
			return fmt.Errorf("enter a number, or leave empty")
		}
		return nil
	}
	m.form = huh.NewForm(huh.NewGroup(
		huh.NewInput().Title("Name").Description("letters, digits, . _ -").Value(&m.newUser.Name).
			Validate(func(s string) error {
				if s == "" {
					return fmt.Errorf("a name is required")
				}
				return nil
			}),
		huh.NewInput().Title("Days until it expires").Description("empty = never").Value(&m.days).Validate(number),
		huh.NewInput().Title("Data cap in GB").Description("empty = unlimited").Value(&m.quota).Validate(number),
		huh.NewInput().Title("Note").Value(&m.newUser.Note),
	)).WithShowHelp(true)
	return m.form.Init()
}

func (m *model) updateForm(msg tea.Msg) (tea.Model, tea.Cmd) {
	if k, ok := msg.(tea.KeyMsg); ok {
		switch k.String() {
		case "ctrl+c":
			return m, tea.Quit
		case "esc":
			m.form = nil
			return m, nil
		}
	}
	model, cmd := m.form.Update(msg)
	if f, ok := model.(*huh.Form); ok {
		m.form = f
	}
	switch m.form.State {
	case huh.StateCompleted:
		m.form = nil
		m.newUser.Days, _ = strconv.Atoi(m.days)
		m.newUser.QuotaGB, _ = strconv.ParseFloat(m.quota, 64)
		name := m.newUser.Name
		m.do("added "+name, func() error { _, err := m.mgr.AddUser(m.newUser); return err })
		return m, nil
	case huh.StateAborted:
		m.form = nil
		return m, nil
	}
	return m, cmd
}

func (m *model) updateUsers(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	selected := m.selectedUser()
	switch msg.String() {
	case "q":
		return m, tea.Quit
	case "a":
		return m, m.openAddForm()
	case "enter":
		if selected != nil {
			m.view, m.user, m.qrIndex = viewUser, selected.Name, 0
			m.links, _ = m.mgr.Links(selected.Name)
		}
	case "e", " ":
		if selected != nil {
			name, enable := selected.Name, !selected.Enabled
			m.do(fmt.Sprintf("%s %s", name, map[bool]string{true: "enabled", false: "disabled"}[enable]),
				func() error { _, err := m.mgr.UpdateUser(name, manager.UserPatch{Enabled: &enable}); return err })
		}
	case "x":
		if selected != nil {
			name := selected.Name
			m.ask("Days until "+name+" expires (empty/never = no expiry)", "", func(m *model, v string) error {
				return m.setExpiry(name, v)
			})
		}
	case "g":
		if selected != nil {
			name := selected.Name
			m.ask("Data cap for "+name+" in GB (0 = unlimited)", strconv.FormatFloat(selected.QuotaGB, 'f', -1, 64), func(m *model, v string) error {
				gb, err := strconv.ParseFloat(v, 64)
				if err != nil || gb < 0 {
					return fmt.Errorf("invalid quota %q", v)
				}
				m.do("quota updated", func() error { _, err := m.mgr.UpdateUser(name, manager.UserPatch{QuotaGB: &gb}); return err })
				return nil
			})
		}
	case "n":
		if selected != nil {
			name := selected.Name
			m.ask("Note for "+name, selected.Note, func(m *model, v string) error {
				m.do("note updated", func() error { _, err := m.mgr.UpdateUser(name, manager.UserPatch{Note: &v}); return err })
				return nil
			})
		}
	case "d":
		if selected != nil {
			name := selected.Name
			m.confirm = &prompt{label: "Delete " + name + "? (y/N)", submit: func(m *model, _ string) error {
				m.do("deleted "+name, func() error { return m.mgr.DeleteUser(name) })
				return nil
			}}
		}
	case "r":
		if selected != nil {
			m.confirmReset(selected.Name)
		}
	case "u":
		if selected != nil {
			name := selected.Name
			m.confirm = &prompt{label: "Restart " + name + "'s traffic count for this month? (y/N)", submit: func(m *model, _ string) error {
				m.do("usage reset for "+name, func() error { _, err := m.mgr.ResetUsage(name); return err })
				return nil
			}}
		}
	default:
		var cmd tea.Cmd
		m.table, cmd = m.table.Update(msg)
		return m, cmd
	}
	return m, nil
}

func (m *model) confirmReset(name string) {
	m.confirm = &prompt{label: "Issue new credentials for " + name + "? Old links stop working. (y/N)", submit: func(m *model, _ string) error {
		m.do("new credentials for "+name, func() error { _, err := m.mgr.ResetUser(name); return err })
		return nil
	}}
}

func (m *model) setExpiry(name, value string) error {
	days := 0
	if value != "" && value != "never" {
		n, err := strconv.Atoi(value)
		if err != nil || n < 0 {
			return fmt.Errorf("invalid number of days %q", value)
		}
		days = n
	}
	m.do(name+" expiry updated", func() error {
		_, err := m.mgr.UpdateUser(name, manager.UserPatch{ExpireDays: &days})
		return err
	})
	return nil
}

// qrTargets are the subscription URL and every link for the shown user.
func (m *model) qrTargets() []manager.Link {
	if m.links == nil {
		return nil
	}
	var out []manager.Link
	if m.links.Subscription != "" {
		out = append(out, manager.Link{Protocol: "subscription (all protocols)", URL: m.links.Subscription})
	}
	return append(out, m.links.Links...)
}

func (m *model) updateUser(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	count := len(m.qrTargets())
	switch msg.String() {
	case "esc", "q", "backspace":
		m.view = viewUsers
	case "right", "l", "tab":
		if count > 0 {
			m.qrIndex = (m.qrIndex + 1) % count
		}
	case "left", "h", "shift+tab":
		if count > 0 {
			m.qrIndex = (m.qrIndex - 1 + count) % count
		}
	case "r":
		m.confirmReset(m.user)
	}
	return m, nil
}

func (m *model) updateProtocols(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	selected := m.protos[m.proto]
	switch msg.String() {
	case "q":
		return m, tea.Quit
	case "up", "k":
		m.proto = (m.proto - 1 + len(m.protos)) % len(m.protos)
	case "down", "j":
		m.proto = (m.proto + 1) % len(m.protos)
	case " ", "e":
		on := !selected.Enabled
		m.do(selected.Key+" toggled", func() error {
			_, err := m.mgr.SetProtocol(selected.Key, manager.ProtocolPatch{Enabled: &on})
			return err
		})
	case "v":
		// AmneziaWG 2.0 <-> 1.x: new obfuscation parameters, so every user imports their config again.
		if selected.Key == store.AmneziaWGKey {
			next := store.AWG2
			if selected.AmneziaWGVersion == store.AWG2 {
				next = store.AWGClassic
			}
			m.do("AmneziaWG "+next+" (users must import their config again)", func() error {
				_, err := m.mgr.SetProtocol(selected.Key, manager.ProtocolPatch{AmneziaWGVersion: &next})
				return err
			})
		}
	case "enter":
		m.ask("Port for "+selected.Key, strconv.Itoa(selected.Port), func(m *model, value string) error {
			port, err := strconv.Atoi(value)
			if err != nil || port < 1 || port > 65535 {
				return fmt.Errorf("invalid port %q", value)
			}
			m.do(selected.Key+" port updated", func() error {
				_, err := m.mgr.SetProtocol(selected.Key, manager.ProtocolPatch{Port: &port})
				return err
			})
			return nil
		})
	}
	return m, nil
}

func (m *model) updateServer(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "q":
		return m, tea.Quit
	case "t":
		m.showTok = !m.showTok
	case "e":
		on := !m.api.Enabled
		m.do("web API "+map[bool]string{true: "enabled", false: "disabled"}[on]+" (applies on the next run)",
			func() error { _, err := m.mgr.SetAPI(manager.APIPatch{Enabled: &on}); return err })
	case "n":
		m.confirm = &prompt{label: "Issue a new API token? The old one stops working. (y/N)", submit: func(m *model, _ string) error {
			m.do("new API token issued", func() error { _, err := m.mgr.SetAPI(manager.APIPatch{NewToken: true}); return err })
			return nil
		}}
	case "l":
		m.ask("API listen address (e.g. 127.0.0.1 or 0.0.0.0)", m.api.Listen, func(m *model, value string) error {
			if value == "" {
				return fmt.Errorf("an address is required")
			}
			m.do("API address updated", func() error { _, err := m.mgr.SetAPI(manager.APIPatch{Listen: &value}); return err })
			return nil
		})
	case "p":
		m.ask("API port", strconv.Itoa(m.api.Port), func(m *model, value string) error {
			port, err := strconv.Atoi(value)
			if err != nil {
				return fmt.Errorf("invalid port %q", value)
			}
			m.do("API port updated", func() error { _, err := m.mgr.SetAPI(manager.APIPatch{Port: &port}); return err })
			return nil
		})
	}
	return m, nil
}

func (m *model) View() string {
	if m.form != nil {
		return titleStyle.Render("New user") + "\n\n" + m.form.View()
	}
	var out strings.Builder
	out.WriteString(titleStyle.Render("Wardkeep server") + dimStyle.Render(fmt.Sprintf("  %s · %s · %s", m.info.Name, m.info.PublicHost, m.mgr.Store.Dir)))
	if badge := m.alertBadge(); badge != "" {
		out.WriteString("  " + badge)
	}
	out.WriteString("\n")
	if m.view != viewUser {
		for i, t := range tabs {
			style := tabStyle
			if view(i) == m.view {
				style = tabOnStyle
			}
			if view(i) == viewAlerts && m.unacknowledged > 0 {
				t = fmt.Sprintf("%s (%d)", t, m.unacknowledged)
			}
			out.WriteString(style.Render(fmt.Sprintf("%d %s", i+1, t)))
		}
	}
	out.WriteString("\n\n")

	switch m.view {
	case viewUsers:
		out.WriteString(m.usersView())
	case viewUser:
		out.WriteString(m.userView())
	case viewProtocols:
		out.WriteString(m.protocolsView())
	case viewServer:
		out.WriteString(m.serverView())
	case viewLogs:
		out.WriteString(m.logsView())
	case viewAlerts:
		out.WriteString(m.alertsView())
	}

	out.WriteString("\n\n")
	switch {
	case m.prompt != nil:
		out.WriteString(m.prompt.label + ": " + m.input.View() + dimStyle.Render("  (enter to save, esc to cancel)"))
	case m.confirm != nil:
		out.WriteString(errStyle.Render(m.confirm.label))
	case m.err != nil:
		out.WriteString(errStyle.Render("Error: " + m.err.Error()))
	case m.status != "":
		out.WriteString(okStyle.Render(m.status))
	}
	return out.String()
}

func (m *model) usersView() string {
	var out strings.Builder
	out.WriteString(fmt.Sprintf("Users (%d, %d active)\n", m.info.Users, m.info.ActiveUsers))
	if len(m.users) == 0 {
		out.WriteString(dimStyle.Render("No users yet — press a to add one.") + "\n")
	} else {
		out.WriteString(m.table.View() + "\n")
	}
	out.WriteString(dimStyle.Render("enter links & QR · a add · e enable/disable · x expiry · g quota · n note · u reset usage · r new credentials · d delete · tab next · q quit"))
	return out.String()
}

func (m *model) userView() string {
	var selected *manager.UserInfo
	for i := range m.users {
		if m.users[i].Name == m.user {
			selected = &m.users[i]
		}
	}
	if selected == nil {
		return "user not found"
	}
	var out strings.Builder
	out.WriteString(fmt.Sprintf("%s  %s  expires %s\n\n", titleStyle.Render(selected.Name), selected.Status, expiry(*selected)))
	targets := m.qrTargets()
	if len(targets) == 0 {
		return out.String() + "No protocols enabled."
	}
	t := targets[m.qrIndex%len(targets)]
	out.WriteString(fmt.Sprintf("%s %s\n", okStyle.Render(fmt.Sprintf("[%d/%d]", m.qrIndex%len(targets)+1, len(targets))), t.Protocol))
	if code, err := qrterm.Render(t.URL); err == nil {
		out.WriteString(code)
	}
	out.WriteString(boxStyle.Width(max(40, min(m.width-4, 110))).Render(t.URL) + "\n")
	out.WriteString(dimStyle.Render("←/→ switch link · r new credentials · esc back"))
	return out.String()
}

func (m *model) protocolsView() string {
	var out strings.Builder
	out.WriteString("Protocols\n\n")
	for i, entry := range m.protos {
		cursor := "  "
		if i == m.proto {
			cursor = okStyle.Render("▸ ")
		}
		state := errStyle.Render("off")
		if entry.Enabled {
			state = okStyle.Render("on ")
		}
		detail := entry.Transport
		if entry.AmneziaWGVersion != "" {
			detail += " · " + entry.AmneziaWGVersion
		}
		out.WriteString(fmt.Sprintf("%s%s  %-14s port %-5d %s\n", cursor, state, entry.Key, entry.Port, dimStyle.Render(detail)))
	}
	out.WriteString("\n" + dimStyle.Render("space toggle · enter change port · v AmneziaWG 2.0/1.x · tab next · q quit"))
	return out.String()
}

func (m *model) serverView() string {
	var out strings.Builder
	i := m.info
	out.WriteString(fmt.Sprintf("%s  %s\n", titleStyle.Render(i.Name), i.PublicHost))
	out.WriteString(fmt.Sprintf("users %d (%d active) · protocols on %d", i.Users, i.ActiveUsers, i.Protocols))
	if i.Running {
		out.WriteString(okStyle.Render(fmt.Sprintf(" · running, %d connection(s)", i.Connections)))
	} else {
		out.WriteString(errStyle.Render(" · server not running"))
	}
	if i.SubscriptionPort > 0 {
		out.WriteString(fmt.Sprintf(" · subscriptions on port %d", i.SubscriptionPort))
	}
	out.WriteString("\n")
	switch {
	case m.cert.Mode == "acme" && m.cert.Status == "issued":
		out.WriteString(okStyle.Render(fmt.Sprintf("certificate: %s, valid until %s", m.cert.Domain, m.cert.NotAfter.Local().Format("2006-01-02"))))
	case m.cert.Mode == "acme":
		out.WriteString(errStyle.Render(fmt.Sprintf("certificate: waiting for %s from the CA (self-signed meanwhile)", m.cert.Domain)))
	default:
		out.WriteString(dimStyle.Render("certificate: self-signed (omnitun-server cert acme --domain … for a real one)"))
	}
	out.WriteString("\n\nWeb API\n")
	state := errStyle.Render("off")
	if m.api.Enabled {
		state = okStyle.Render("on")
	}
	tok := maskedToken
	if m.showTok {
		tok = m.api.Token
	}
	out.WriteString(fmt.Sprintf("  state    %s\n  listen   %s:%d\n  token    %s\n  docs     http://%s:%d/docs\n",
		state, m.api.Listen, m.api.Port, tok, m.api.Listen, m.api.Port))
	out.WriteString("\n" + dimStyle.Render("e enable/disable API · t show token · n new token · l address · p port · tab next · q quit"))
	return out.String()
}
