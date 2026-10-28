package manager

import (
	"maps"
	"sort"
	"strings"

	"github.com/NoobforAl/omnitun/server/store"
)

// SubscriptionInfo describes how the subscription is signed and what order of protocols it asks for.
type SubscriptionInfo struct {
	Enabled bool `json:"enabled"`
	Port    int  `json:"port"`
	// PublicKey is the signing key clients check answers against (base64); it is in every subscription link after "#pk=".
	PublicKey string `json:"public_key" doc:"Ed25519 key that signs the subscription (base64); clients that have it refuse a changed answer"`
	// ProtocolOrder is the order of protocols clients are asked to try, for everyone ("") and per country ("IR").
	ProtocolOrder map[string]string `json:"protocol_order,omitempty" doc:"Protocols clients are asked to try first, by client protocol name; \"\" is for everyone, a country code for that country"`
}

func subscriptionInfo(st *store.State) *SubscriptionInfo {
	s := st.Server.Subscription
	info := &SubscriptionInfo{Enabled: s.Enabled, Port: s.Port, PublicKey: s.SigningPublic()}
	if len(s.ProtocolOrder) > 0 {
		info.ProtocolOrder = map[string]string{}
		maps.Copy(info.ProtocolOrder, s.ProtocolOrder)
	}
	return info
}

// Subscription returns the signing key and the protocol order.
func (m *Manager) Subscription() (*SubscriptionInfo, error) {
	st, err := m.Store.Load()
	if err != nil {
		return nil, err
	}
	return subscriptionInfo(st), nil
}

// SetProtocolOrder sets the order clients are asked to try protocols in. country is "" for everyone or a two-letter
// country code; an empty list clears it. The order is signed with the answer, so a client with the key trusts it.
func (m *Manager) SetProtocolOrder(country, list string) (*SubscriptionInfo, error) {
	country = strings.ToUpper(strings.TrimSpace(country))
	if country != "" && (len(country) != 2 || country[0] < 'A' || country[0] > 'Z' || country[1] < 'A' || country[1] > 'Z') {
		return nil, invalid("the country must be a two-letter code such as IR (got %q)", country)
	}
	items, err := store.ParseProtocolOrder(list)
	if err != nil {
		return nil, invalid("%v", err)
	}
	var out *SubscriptionInfo
	err = m.Store.Update(func(st *store.State) error {
		sub := &st.Server.Subscription
		if len(items) == 0 {
			delete(sub.ProtocolOrder, country)
			if len(sub.ProtocolOrder) == 0 {
				sub.ProtocolOrder = nil
			}
		} else {
			if sub.ProtocolOrder == nil {
				sub.ProtocolOrder = map[string]string{}
			}
			sub.ProtocolOrder[country] = strings.Join(items, ",")
		}
		out = subscriptionInfo(st)
		return nil
	})
	return out, err
}

// RotateSigningKey makes a new signing key. Users must take the new subscription link (it carries the public key);
// clients with the old key refuse the subscription until they do.
func (m *Manager) RotateSigningKey() (*SubscriptionInfo, error) {
	var out *SubscriptionInfo
	err := m.Store.Update(func(st *store.State) error {
		if err := st.RotateSigningKey(); err != nil {
			return err
		}
		out = subscriptionInfo(st)
		return nil
	})
	return out, err
}

// OrderKeys lists the countries an order is set for, "" first.
func (i *SubscriptionInfo) OrderKeys() []string {
	keys := make([]string, 0, len(i.ProtocolOrder))
	for k := range i.ProtocolOrder {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}
