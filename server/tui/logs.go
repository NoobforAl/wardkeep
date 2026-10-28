package tui

import (
	"fmt"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"

	"github.com/NoobforAl/omnitun/server/logs"
	"github.com/NoobforAl/omnitun/server/manager"
)

var (
	warnStyle  = lipgloss.NewStyle().Foreground(lipgloss.Color("214"))
	alertStyle = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("231")).Background(lipgloss.Color("160")).Padding(0, 1)
)

// logLevels are what the l key cycles through: the lowest level shown.
var logLevels = []logs.Level{logs.LevelTrace, logs.LevelDebug, logs.LevelInfo, logs.LevelWarn, logs.LevelError}

// loadLogs reads as many records as fit on the screen, at the chosen level or above.
func (m *model) loadLogs() {
	count := 15
	if m.height > 12 {
		count = m.height - 10
	}
	records, err := m.mgr.LogRecords(manager.LogQuery{Level: m.logLevel.String(), Limit: count})
	if err == nil {
		m.logs = records
	}
}

func (m *model) updateLogs(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "q":
		return m, tea.Quit
	case "r":
		m.loadLogs()
	case "l":
		next := 0
		for i, level := range logLevels {
			if level == m.logLevel {
				next = (i + 1) % len(logLevels)
			}
		}
		m.logLevel = logLevels[next]
		m.loadLogs()
	}
	return m, nil
}

// levelStyle colours a level name.
func levelStyle(level string) lipgloss.Style {
	switch level {
	case "fatal", "error":
		return errStyle
	case "warn":
		return warnStyle
	case "info":
		return lipgloss.NewStyle()
	}
	return dimStyle
}

// truncate cuts text to width runes (with an ellipsis).
func truncate(text string, width int) string {
	if runes := []rune(text); width > 1 && len(runes) > width {
		return string(runes[:width-1]) + "…"
	}
	return text
}

func (m *model) logsView() string {
	var out strings.Builder
	out.WriteString("Server log (refreshes every 2 s) · level " + levelStyle(m.logLevel.String()).Render(m.logLevel.String()) + " and above\n\n")
	if len(m.logs) == 0 {
		out.WriteString(dimStyle.Render("Nothing logged at this level. The log is written while `omnitun-server run` is running.") + "\n")
	} else {
		out.WriteString(dimStyle.Render(fmt.Sprintf("%-8s %-5s %-8s %s", "TIME", "LEVEL", "SOURCE", "MESSAGE")) + "\n")
	}
	width := m.width - 2
	for _, rec := range m.logs {
		at := "        "
		if !rec.Time.IsZero() {
			at = rec.Time.Local().Format("15:04:05")
		}
		message := rec.Msg
		if fields := rec.Fields(); len(fields) > 0 {
			message += " " + dimStyle.Render(strings.Join(fields, " "))
		}
		line := fmt.Sprintf("%s %s %-8s %s", dimStyle.Render(at), levelStyle(rec.Level).Render(fmt.Sprintf("%-5s", strings.ToUpper(rec.Level))), truncate(rec.Source, 8), message)
		if width > 20 && lipgloss.Width(line) > width {
			// Cut the plain text (colour codes would be cut in half).
			plain := fmt.Sprintf("%s %-5s %-8s %s", at, strings.ToUpper(rec.Level), truncate(rec.Source, 8), rec.Msg)
			if fields := rec.Fields(); len(fields) > 0 {
				plain += " " + strings.Join(fields, " ")
			}
			line = levelStyle(rec.Level).Render(truncate(plain, width))
		}
		out.WriteString(line + "\n")
	}
	out.WriteString("\n" + dimStyle.Render("l level · r refresh · tab next · q quit"))
	return out.String()
}

// loadAlerts reads the alerts (newest first).
func (m *model) loadAlerts() {
	list, err := m.mgr.Alerts()
	if err != nil {
		return
	}
	m.alerts = list
	m.unacknowledged = 0
	for _, alert := range list {
		if !alert.Acknowledged {
			m.unacknowledged++
		}
	}
	if m.alertCursor >= len(list) {
		m.alertCursor = max(0, len(list)-1)
	}
}

// alertBadge is the header's notice of unacknowledged alerts ("" when there are none).
func (m *model) alertBadge() string {
	if m.unacknowledged == 0 {
		return ""
	}
	noun := "alert"
	if m.unacknowledged > 1 {
		noun = "alerts"
	}
	return alertStyle.Render(fmt.Sprintf("⚠ %d %s · press 5", m.unacknowledged, noun))
}

func (m *model) updateAlerts(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "q":
		return m, tea.Quit
	case "up", "k":
		if m.alertCursor > 0 {
			m.alertCursor--
		}
	case "down", "j":
		if m.alertCursor < len(m.alerts)-1 {
			m.alertCursor++
		}
	case "enter":
		m.alertDetail = !m.alertDetail
	case "esc":
		m.alertDetail = false
	case "a":
		if m.alertCursor < len(m.alerts) {
			id := m.alerts[m.alertCursor].ID
			m.ackAlerts("alert acknowledged", []string{id}, false)
		}
	case "A":
		m.ackAlerts("all alerts acknowledged", nil, true)
	}
	return m, nil
}

func (m *model) ackAlerts(done string, ids []string, all bool) {
	if _, err := m.mgr.AckAlerts(ids, all); err != nil {
		m.err, m.status = err, ""
		return
	}
	m.err, m.status = nil, done
	m.loadAlerts()
}

func (m *model) alertsView() string {
	var out strings.Builder
	out.WriteString(fmt.Sprintf("Alerts: failures nothing handled (%d, %d new)\n\n", len(m.alerts), m.unacknowledged))
	if len(m.alerts) == 0 {
		out.WriteString(dimStyle.Render("No alerts. A protocol that stops or does not start, a certificate that is not renewed or a crash shows up here.") + "\n")
	}
	width := m.width - 2
	for i, alert := range m.alerts {
		cursor := "  "
		if i == m.alertCursor {
			cursor = okStyle.Render("▸ ")
		}
		state := errStyle.Render("NEW")
		if alert.Acknowledged {
			state = dimStyle.Render(" ok")
		}
		text := alert.Msg
		if alert.Count > 1 {
			text += fmt.Sprintf(" (%d×)", alert.Count)
		}
		if width > 40 {
			text = truncate(text, width-30)
		}
		out.WriteString(fmt.Sprintf("%s%s %s %s %s\n", cursor, state, dimStyle.Render(alert.Last.Local().Format("01-02 15:04")),
			levelStyle(alert.Level).Render(fmt.Sprintf("%-5s", strings.ToUpper(alert.Level))), text))
		if i == m.alertCursor && m.alertDetail {
			out.WriteString(m.alertDetails(alert))
		}
	}
	out.WriteString("\n" + dimStyle.Render("enter details · a acknowledge · A acknowledge all · tab next · q quit"))
	return out.String()
}

// alertDetails is the expanded view of one alert.
func (m *model) alertDetails(alert logs.Alert) string {
	var lines []string
	add := func(label, value string) {
		if value != "" {
			lines = append(lines, fmt.Sprintf("%-8s %s", label, value))
		}
	}
	add("first", alert.Time.Local().Format("2006-01-02 15:04:05"))
	add("last", alert.Last.Local().Format("2006-01-02 15:04:05"))
	add("count", fmt.Sprint(alert.Count))
	add("source", alert.Source)
	add("target", alert.Target)
	add("op", alert.Op)
	add("user", alert.User)
	add("code", alert.Code)
	add("error", alert.Err)
	if alert.Stack != "" {
		stack := strings.Split(alert.Stack, "\n")
		if len(stack) > 12 {
			stack = append(stack[:12], "…")
		}
		lines = append(lines, "stack", strings.Join(stack, "\n"))
	}
	return boxStyle.Width(max(40, min(m.width-6, 110))).Render(strings.Join(lines, "\n")) + "\n"
}
