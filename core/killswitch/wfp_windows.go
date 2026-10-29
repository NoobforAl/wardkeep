//go:build windows

package killswitch

import (
	"errors"
	"fmt"
	"net"
	"slices"
	"strings"
	"sync"

	"github.com/tailscale/wf"
	"golang.org/x/sys/windows"
	"golang.zx2c4.com/wireguard/windows/tunnel/winipcfg"
)

const supported = true

// namePrefix starts the name of every WFP object this package creates, so
// leftovers can be recognised (and only ours removed).
const namePrefix = "Wardkeep kill switch"

// wfpBackend keeps one dynamic WFP session. A dynamic session (the
// FWPM_SESSION_FLAG_DYNAMIC of the Windows API) removes everything created in
// it when the session is closed or the process ends, however it ends: a
// crash, a kill or a power cut cannot leave a block rule behind that would cut
// the machine off the network. The price is the same: if the core process dies
// the kill switch is gone with it and traffic flows normally again; the
// service restarts by itself and the user's app reconnects.
type wfpBackend struct {
	mu   sync.Mutex
	sess *wf.Session
}

func newBackend() Backend { return &wfpBackend{} }

func (b *wfpBackend) Apply(rules []Rule) error {
	b.mu.Lock()
	defer b.mu.Unlock()
	next, err := installRules(rules)
	if err != nil {
		return err
	}
	// The new set is complete before the old one goes: no gap in between.
	old := b.sess
	b.sess = next
	if old != nil {
		old.Close()
	}
	return nil
}

func (b *wfpBackend) Remove() error {
	b.mu.Lock()
	defer b.mu.Unlock()
	if b.sess == nil {
		return nil
	}
	err := b.sess.Close()
	b.sess = nil
	return err
}

func installRules(rules []Rule) (*wf.Session, error) {
	sess, err := wf.New(&wf.Options{
		Name:        namePrefix,
		Description: "Blocks traffic outside the VPN tunnel while the VPN is up",
		Dynamic:     true,
	})
	if err != nil {
		return nil, fmt.Errorf("open the Windows Filtering Platform (needs administrator rights): %w", err)
	}
	ok := false
	defer func() {
		if !ok {
			sess.Close()
		}
	}()

	providerGUID, err := windows.GenerateGUID()
	if err != nil {
		return nil, err
	}
	sublayerGUID, err := windows.GenerateGUID()
	if err != nil {
		return nil, err
	}
	provider := wf.ProviderID(providerGUID)
	if err := sess.AddProvider(&wf.Provider{ID: provider, Name: namePrefix}); err != nil {
		return nil, fmt.Errorf("add provider: %w", err)
	}
	sublayer := wf.SublayerID(sublayerGUID)
	if err := sess.AddSublayer(&wf.Sublayer{ID: sublayer, Name: namePrefix, Provider: provider, Weight: 0xFFFF}); err != nil {
		return nil, fmt.Errorf("add sublayer: %w", err)
	}

	// Permits first and the block last, so there is never an instant in which
	// the block exists and the permits do not.
	ordered := slices.Clone(rules)
	slices.SortStableFunc(ordered, func(a, c Rule) int {
		switch {
		case a.Weight > c.Weight:
			return -1
		case a.Weight < c.Weight:
			return 1
		}
		return 0
	})
	appIDs := map[string]string{}
	for _, rule := range ordered {
		wr, err := toWF(rule, appIDs)
		if err != nil {
			return nil, fmt.Errorf("%s: %w", rule.Name, err)
		}
		id, err := windows.GenerateGUID()
		if err != nil {
			return nil, err
		}
		wr.ID = wf.RuleID(id)
		wr.Provider = provider
		wr.Sublayer = sublayer
		if err := sess.AddRule(wr); err != nil {
			return nil, fmt.Errorf("add rule %q: %w", rule.Name, err)
		}
	}
	ok = true
	return sess, nil
}

// toWF converts a rule to the library's type. appIDs caches path -> WFP
// application identifier.
func toWF(rule Rule, appIDs map[string]string) (*wf.Rule, error) {
	out := &wf.Rule{Name: rule.Name, Weight: rule.Weight}
	switch {
	case rule.Direction == Outbound && rule.Family == IPv4:
		out.Layer = wf.LayerALEAuthConnectV4
	case rule.Direction == Outbound && rule.Family == IPv6:
		out.Layer = wf.LayerALEAuthConnectV6
	case rule.Direction == Inbound && rule.Family == IPv4:
		out.Layer = wf.LayerALEAuthRecvAcceptV4
	case rule.Direction == Inbound && rule.Family == IPv6:
		out.Layer = wf.LayerALEAuthRecvAcceptV6
	default:
		return nil, errors.New("unknown direction or family")
	}
	switch rule.Action {
	case Permit:
		out.Action = wf.ActionPermit
	case Block:
		out.Action = wf.ActionBlock
	default:
		return nil, errors.New("unknown action")
	}
	for _, c := range rule.Conditions {
		ms, err := matches(c, appIDs)
		if err != nil {
			return nil, err
		}
		out.Conditions = append(out.Conditions, ms...)
	}
	return out, nil
}

func matches(cond Condition, appIDs map[string]string) ([]*wf.Match, error) {
	if cond.Field == Loopback {
		return []*wf.Match{{Field: wf.FieldFlags, Op: wf.MatchTypeFlagsAllSet, Value: wf.ConditionFlagIsLoopback}}, nil
	}
	field, err := wfField(cond.Field)
	if err != nil {
		return nil, err
	}
	var out []*wf.Match
	for _, value := range cond.Values {
		switch cond.Field {
		case Application:
			path, ok := value.(string)
			if !ok {
				return nil, fmt.Errorf("application value %T", value)
			}
			id, ok := appIDs[path]
			if !ok {
				if id, err = wf.AppID(path); err != nil {
					return nil, fmt.Errorf("application id of %s: %w", path, err)
				}
				appIDs[path] = id
			}
			value = id
		case Protocol:
			p, ok := value.(uint8)
			if !ok {
				return nil, fmt.Errorf("protocol value %T", value)
			}
			value = wf.IPProto(p)
		}
		out = append(out, &wf.Match{Field: field, Op: wf.MatchTypeEqual, Value: value})
	}
	return out, nil
}

func wfField(field Field) (wf.FieldID, error) {
	switch field {
	case RemoteAddress:
		return wf.FieldIPRemoteAddress, nil
	case LocalInterface:
		return wf.FieldIPLocalInterface, nil
	case Application:
		return wf.FieldALEAppID, nil
	case Protocol:
		return wf.FieldIPProtocol, nil
	case LocalPort:
		return wf.FieldIPLocalPort, nil
	case RemotePort:
		return wf.FieldIPRemotePort, nil
	}
	return wf.FieldID{}, fmt.Errorf("unknown field %v", field)
}

// tunLUID finds an adapter by its connection name.
func tunLUID(name string) (uint64, error) {
	ifc, err := net.InterfaceByName(name)
	if err != nil {
		return 0, err
	}
	luid, err := winipcfg.LUIDFromIndex(uint32(ifc.Index)) //nolint:gosec // G115: interface indexes are positive 32-bit values
	if err != nil {
		return 0, err
	}
	return uint64(luid), nil
}

// Cleanup removes WFP objects of an earlier run that are still there. Our
// session is dynamic, so after a crash there is normally nothing to remove;
// this is for objects an older build or a manual experiment made
// non-dynamic. It only touches objects whose name starts with our prefix.
// It needs administrator rights and is safe to run twice.
func Cleanup() error {
	sess, err := wf.New(&wf.Options{Name: namePrefix + " cleanup"})
	if err != nil {
		return err
	}
	defer sess.Close()
	rules, err := sess.Rules()
	if err != nil {
		return fmt.Errorf("list rules: %w", err)
	}
	var errs []error
	for _, r := range rules {
		if strings.HasPrefix(r.Name, namePrefix) {
			if err := sess.DeleteRule(r.ID); err != nil {
				errs = append(errs, err)
			}
		}
	}
	subs, err := sess.Sublayers()
	if err != nil {
		return errors.Join(append(errs, fmt.Errorf("list sublayers: %w", err))...)
	}
	for _, s := range subs {
		if strings.HasPrefix(s.Name, namePrefix) {
			if err := sess.DeleteSublayer(s.ID); err != nil {
				errs = append(errs, err)
			}
		}
	}
	provs, err := sess.Providers()
	if err != nil {
		return errors.Join(append(errs, fmt.Errorf("list providers: %w", err))...)
	}
	for _, p := range provs {
		if strings.HasPrefix(p.Name, namePrefix) {
			if err := sess.DeleteProvider(p.ID); err != nil {
				errs = append(errs, err)
			}
		}
	}
	return errors.Join(errs...)
}
