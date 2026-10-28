// Package api is the server's management web API: JSON over HTTP with an
// OpenAPI 3 description (/openapi.json) and interactive docs (/docs). Every
// endpoint is a thin wrapper over server/manager and needs the bearer token.
package api

import (
	"bytes"
	"context"
	"crypto/subtle"
	"errors"
	"net/http"
	"reflect"
	"strings"
	"time"

	"github.com/danielgtaylor/huma/v2"
	"github.com/danielgtaylor/huma/v2/adapters/humachi"
	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"

	"github.com/NoobforAl/omnitun/server/logs"
	"github.com/NoobforAl/omnitun/server/manager"
)

// Options configures the API.
type Options struct {
	Manager *manager.Manager
	// Token returns the bearer token every /api/ request must carry. It is
	// called per request, so a rotated token revokes the old one at once;
	// returning "" rejects every request (API disabled).
	Token func() string
	// Reload restarts the VPN core so changes apply at once; the running
	// server also reloads by itself within seconds. Nil when no server runs
	// in this process.
	Reload func() error
	// Version is shown in the OpenAPI document.
	Version string
	// Log gets a fatal record (and an alert) when a handler panics; nil
	// leaves the panic to chi's recoverer, which prints it.
	Log *logs.Log
}

// AlertList is the alerts and how many of them are not acknowledged.
type AlertList struct {
	Unacknowledged int          `json:"unacknowledged" doc:"How many alerts are not acknowledged"`
	Alerts         []logs.Alert `json:"alerts" doc:"Newest first"`
}

// AckResult is the outcome of acknowledging alerts.
type AckResult struct {
	Acknowledged   int `json:"acknowledged" doc:"How many alerts changed"`
	Unacknowledged int `json:"unacknowledged" doc:"How many are left"`
}

// logsQuery is the input of GET /api/v1/logs.
type logsQuery struct {
	Level string    `query:"level" enum:"trace,debug,info,warn,error,fatal" doc:"Lowest level returned (default: everything)"`
	Since time.Time `query:"since" doc:"Only records at or after this time (RFC 3339)"`
	Limit int       `query:"limit" default:"200" minimum:"1" maximum:"5000" doc:"How many of the newest records"`
	Lines int       `query:"lines" minimum:"1" maximum:"5000" doc:"Deprecated: the older form. When set, the answer is that many text lines instead of records."`
	// textLines is true when lines was sent.
	textLines bool
}

// Resolve notes whether the older lines parameter was sent.
func (q *logsQuery) Resolve(ctx huma.Context) []error {
	q.textLines = ctx.Query("lines") != ""
	return nil
}

// Health is the liveness response.
type Health struct {
	OK bool `json:"ok"`
}

type secured = []map[string][]string

var bearer = secured{{"bearer": {}}}

// toHTTP maps manager errors to HTTP errors.
func toHTTP(err error) error {
	switch {
	case err == nil:
		return nil
	case errors.Is(err, manager.ErrNotFound):
		return huma.Error404NotFound(err.Error())
	case errors.Is(err, manager.ErrInvalid):
		return huma.Error422UnprocessableEntity(err.Error())
	case errors.Is(err, manager.ErrConflict):
		return huma.Error409Conflict(err.Error())
	}
	return huma.Error500InternalServerError(err.Error())
}

// New returns the API handler.
func New(opts Options) http.Handler {
	router := chi.NewRouter()
	if opts.Log != nil {
		router.Use(recoverer(opts.Log))
	} else {
		router.Use(middleware.Recoverer)
	}

	version := opts.Version
	if version == "" {
		version = "1.0.0"
	}
	cfg := huma.DefaultConfig("Wardkeep Server API", version)
	cfg.Info.Description = "Manage an Wardkeep server: protocols, users and share links. " +
		"Send the token printed by `omnitun-server api token` as `Authorization: Bearer <token>`."
	cfg.Components.SecuritySchemes = map[string]*huma.SecurityScheme{
		"bearer": {Type: "http", Scheme: "bearer"},
	}
	humaAPI := humachi.New(router, cfg)
	humaAPI.UseMiddleware(authenticate(humaAPI, opts.Token))

	mgr := opts.Manager
	type body[T any] struct{ Body T }

	huma.Register(humaAPI, huma.Operation{
		OperationID: "health", Method: http.MethodGet, Path: "/health", Summary: "Liveness check (no token needed)",
	}, func(ctx context.Context, _ *struct{}) (*body[Health], error) {
		return &body[Health]{Body: Health{OK: true}}, nil
	})

	huma.Register(humaAPI, huma.Operation{
		OperationID: "get-server", Method: http.MethodGet, Path: "/api/v1/server", Summary: "Server summary", Security: bearer,
	}, func(ctx context.Context, _ *struct{}) (*body[*manager.ServerInfo], error) {
		info, err := mgr.Server()
		return &body[*manager.ServerInfo]{Body: info}, toHTTP(err)
	})

	huma.Register(humaAPI, huma.Operation{
		OperationID: "set-ipv6", Method: http.MethodPut, Path: "/api/v1/server/ipv6", Security: bearer,
		Summary: "Switch IPv6 inside the tunnels on or off (users import their configs and links again)",
	}, func(ctx context.Context, in *struct {
		Body struct {
			Enabled bool `json:"enabled"`
		}
	}) (*body[*manager.ServerInfo], error) {
		info, err := mgr.SetIPv6(in.Body.Enabled)
		return &body[*manager.ServerInfo]{Body: info}, toHTTP(err)
	})

	huma.Register(humaAPI, huma.Operation{
		OperationID: "list-protocols", Method: http.MethodGet, Path: "/api/v1/protocols", Summary: "List protocols", Security: bearer,
	}, func(ctx context.Context, _ *struct{}) (*body[[]manager.ProtocolInfo], error) {
		list, err := mgr.Protocols()
		return &body[[]manager.ProtocolInfo]{Body: list}, toHTTP(err)
	})

	huma.Register(humaAPI, huma.Operation{
		OperationID: "patch-protocol", Method: http.MethodPatch, Path: "/api/v1/protocols/{key}",
		Summary: "Enable, disable or change the port of a protocol", Security: bearer,
	}, func(ctx context.Context, in *struct {
		Key  string `path:"key" doc:"Protocol key, e.g. trojan"`
		Body manager.ProtocolPatch
	}) (*body[*manager.ProtocolInfo], error) {
		p, err := mgr.SetProtocol(in.Key, in.Body)
		return &body[*manager.ProtocolInfo]{Body: p}, toHTTP(err)
	})

	huma.Register(humaAPI, huma.Operation{
		OperationID: "list-users", Method: http.MethodGet, Path: "/api/v1/users", Summary: "List users", Security: bearer,
	}, func(ctx context.Context, _ *struct{}) (*body[[]manager.UserInfo], error) {
		list, err := mgr.Users()
		return &body[[]manager.UserInfo]{Body: list}, toHTTP(err)
	})

	huma.Register(humaAPI, huma.Operation{
		OperationID: "create-user", Method: http.MethodPost, Path: "/api/v1/users", Summary: "Create a user",
		DefaultStatus: http.StatusCreated, Security: bearer,
	}, func(ctx context.Context, in *struct{ Body manager.NewUser }) (*body[*manager.UserInfo], error) {
		u, err := mgr.AddUser(in.Body)
		return &body[*manager.UserInfo]{Body: u}, toHTTP(err)
	})

	type userPath struct {
		Name string `path:"name" doc:"User name"`
	}

	huma.Register(humaAPI, huma.Operation{
		OperationID: "get-user", Method: http.MethodGet, Path: "/api/v1/users/{name}", Summary: "Get a user", Security: bearer,
	}, func(ctx context.Context, in *userPath) (*body[*manager.UserInfo], error) {
		u, err := mgr.User(in.Name)
		return &body[*manager.UserInfo]{Body: u}, toHTTP(err)
	})

	huma.Register(humaAPI, huma.Operation{
		OperationID: "patch-user", Method: http.MethodPatch, Path: "/api/v1/users/{name}",
		Summary: "Enable, disable, set expiry, quota or note", Security: bearer,
	}, func(ctx context.Context, in *struct {
		Name string `path:"name" doc:"User name"`
		Body manager.UserPatch
	}) (*body[*manager.UserInfo], error) {
		u, err := mgr.UpdateUser(in.Name, in.Body)
		return &body[*manager.UserInfo]{Body: u}, toHTTP(err)
	})

	huma.Register(humaAPI, huma.Operation{
		OperationID: "delete-user", Method: http.MethodDelete, Path: "/api/v1/users/{name}", Summary: "Delete a user",
		DefaultStatus: http.StatusNoContent, Security: bearer,
	}, func(ctx context.Context, in *userPath) (*struct{}, error) {
		return nil, toHTTP(mgr.DeleteUser(in.Name))
	})

	huma.Register(humaAPI, huma.Operation{
		OperationID: "reset-user", Method: http.MethodPost, Path: "/api/v1/users/{name}/reset",
		Summary: "Issue new credentials (old links stop working)", Security: bearer,
	}, func(ctx context.Context, in *userPath) (*body[*manager.UserInfo], error) {
		u, err := mgr.ResetUser(in.Name)
		return &body[*manager.UserInfo]{Body: u}, toHTTP(err)
	})

	huma.Register(humaAPI, huma.Operation{
		OperationID: "reset-user-usage", Method: http.MethodPost, Path: "/api/v1/users/{name}/usage/reset",
		Summary: "Restart this month's traffic count and unblock the user (lifetime totals stay)", Security: bearer,
	}, func(ctx context.Context, in *userPath) (*body[*manager.UserInfo], error) {
		u, err := mgr.ResetUsage(in.Name)
		return &body[*manager.UserInfo]{Body: u}, toHTTP(err)
	})

	huma.Register(humaAPI, huma.Operation{
		OperationID: "get-user-links", Method: http.MethodGet, Path: "/api/v1/users/{name}/links",
		Summary: "Share links and subscription URL", Security: bearer,
	}, func(ctx context.Context, in *userPath) (*body[*manager.LinkSet], error) {
		set, err := mgr.Links(in.Name)
		return &body[*manager.LinkSet]{Body: set}, toHTTP(err)
	})

	huma.Register(humaAPI, huma.Operation{
		OperationID: "get-user-file", Method: http.MethodGet, Path: "/api/v1/users/{name}/files/{proto}",
		Summary: "The user's config file for a protocol (OpenVPN .ovpn, WireGuard .conf)", Security: bearer,
	}, func(ctx context.Context, in *struct {
		Name  string `path:"name" doc:"User name"`
		Proto string `path:"proto" doc:"Protocol key, e.g. wireguard or openvpn-udp"`
	}) (*struct {
		ContentType        string `header:"Content-Type"`
		ContentDisposition string `header:"Content-Disposition"`
		Body               []byte
	}, error) {
		filename, text, err := mgr.File(in.Name, in.Proto)
		if err != nil {
			return nil, toHTTP(err)
		}
		return &struct {
			ContentType        string `header:"Content-Type"`
			ContentDisposition string `header:"Content-Disposition"`
			Body               []byte
		}{ContentType: "application/octet-stream", ContentDisposition: `attachment; filename="` + filename + `"`, Body: []byte(text)}, nil
	})

	huma.Register(humaAPI, huma.Operation{
		OperationID: "get-user-ovpn", Method: http.MethodGet, Path: "/api/v1/users/{name}/ovpn/{proto}",
		Summary: "The user's OpenVPN config file", Security: bearer,
	}, func(ctx context.Context, in *struct {
		Name  string `path:"name" doc:"User name"`
		Proto string `path:"proto" enum:"udp,tcp"`
	}) (*struct {
		ContentType string `header:"Content-Type"`
		Body        []byte
	}, error) {
		text, err := mgr.OVPN(in.Name, in.Proto)
		if err != nil {
			return nil, toHTTP(err)
		}
		return &struct {
			ContentType string `header:"Content-Type"`
			Body        []byte
		}{ContentType: "application/x-openvpn-profile", Body: []byte(text)}, nil
	})

	registry := humaAPI.OpenAPI().Components.Schemas
	huma.Register(humaAPI, huma.Operation{
		OperationID: "get-logs", Method: http.MethodGet, Path: "/api/v1/logs", Security: bearer,
		Summary: "The newest records of the server log (oldest first)",
		Description: "One record per entry: time, level, source, msg and, where they apply, target (the protocol or inbound), " +
			"op, conn, user, code, err, notify (nothing handled it: it is also an alert), caller and stack. " +
			"`level`, `since` and `limit` filter them. The older `lines` parameter answers that many text lines instead.",
		Responses: map[string]*huma.Response{"200": {
			Description: "Records (or text lines, with `lines`)",
			Content: map[string]*huma.MediaType{"application/json": {Schema: &huma.Schema{OneOf: []*huma.Schema{
				registry.Schema(reflect.TypeFor[[]logs.Record](), true, "records"),
				registry.Schema(reflect.TypeFor[[]string](), true, "lines"),
			}}}},
		}},
	}, func(ctx context.Context, in *logsQuery) (*body[any], error) {
		if in.textLines {
			lines, err := mgr.Logs(in.Lines)
			return &body[any]{Body: lines}, toHTTP(err)
		}
		records, err := mgr.LogRecords(manager.LogQuery{Level: in.Level, Since: in.Since, Limit: in.Limit})
		return &body[any]{Body: records}, toHTTP(err)
	})

	huma.Register(humaAPI, huma.Operation{
		OperationID: "list-alerts", Method: http.MethodGet, Path: "/api/v1/alerts", Security: bearer,
		Summary: "Failures nothing handled (a protocol that stopped or did not start, a certificate not renewed, a panic), newest first",
		Description: "Kept in the data directory (the newest 200), so a restart keeps them. " +
			"The same failure (target and code) within an hour is one alert with a count.",
	}, func(ctx context.Context, _ *struct{}) (*body[AlertList], error) {
		list, err := mgr.Alerts()
		if err != nil {
			return nil, toHTTP(err)
		}
		return &body[AlertList]{Body: AlertList{Unacknowledged: unacknowledged(list), Alerts: list}}, nil
	})

	huma.Register(humaAPI, huma.Operation{
		OperationID: "ack-alerts", Method: http.MethodPost, Path: "/api/v1/alerts/ack", Security: bearer,
		Summary: "Acknowledge alerts by id, or all of them",
	}, func(ctx context.Context, in *struct {
		Body struct {
			IDs []string `json:"ids,omitempty" required:"false" doc:"The alert ids"`
			All bool     `json:"all,omitempty" required:"false" doc:"Acknowledge every alert"`
		}
	}) (*body[AckResult], error) {
		changed, err := mgr.AckAlerts(in.Body.IDs, in.Body.All)
		if err != nil {
			return nil, toHTTP(err)
		}
		list, err := mgr.Alerts()
		return &body[AckResult]{Body: AckResult{Acknowledged: changed, Unacknowledged: unacknowledged(list)}}, toHTTP(err)
	})

	huma.Register(humaAPI, huma.Operation{
		OperationID: "get-logging", Method: http.MethodGet, Path: "/api/v1/logging", Security: bearer,
		Summary: "The log level and whether alerts are collected",
	}, func(ctx context.Context, _ *struct{}) (*body[manager.LoggingInfo], error) {
		info, err := mgr.Logging()
		return &body[manager.LoggingInfo]{Body: info}, toHTTP(err)
	})

	huma.Register(humaAPI, huma.Operation{
		OperationID: "set-logging", Method: http.MethodPatch, Path: "/api/v1/logging", Security: bearer,
		Summary:     "Change the log level (trace, debug, info, warn, error or default) or switch alerts on or off; a running server applies it within seconds",
		Description: "Warning: " + logs.LevelWarning + ".",
	}, func(ctx context.Context, in *struct{ Body manager.LoggingPatch }) (*body[manager.LoggingInfo], error) {
		info, err := mgr.SetLogging(in.Body)
		return &body[manager.LoggingInfo]{Body: info}, toHTTP(err)
	})

	huma.Register(humaAPI, huma.Operation{
		OperationID: "get-certificate", Method: http.MethodGet, Path: "/api/v1/certificate",
		Summary: "Where the TLS certificate comes from (self-signed or ACME) and when it expires", Security: bearer,
	}, func(ctx context.Context, _ *struct{}) (*body[*manager.CertInfo], error) {
		c, err := mgr.Certificate()
		return &body[*manager.CertInfo]{Body: c}, toHTTP(err)
	})

	huma.Register(humaAPI, huma.Operation{
		OperationID: "enable-acme", Method: http.MethodPut, Path: "/api/v1/certificate/acme",
		Summary: "Get a real certificate for a domain (Let's Encrypt by default); the domain becomes the public address", Security: bearer,
	}, func(ctx context.Context, in *struct{ Body manager.ACMEPatch }) (*body[*manager.CertInfo], error) {
		c, err := mgr.EnableACME(in.Body)
		return &body[*manager.CertInfo]{Body: c}, toHTTP(err)
	})

	huma.Register(humaAPI, huma.Operation{
		OperationID: "use-self-signed", Method: http.MethodDelete, Path: "/api/v1/certificate/acme",
		Summary: "Go back to the self-signed certificate", Security: bearer,
	}, func(ctx context.Context, _ *struct{}) (*body[*manager.CertInfo], error) {
		c, err := mgr.UseSelfSigned()
		return &body[*manager.CertInfo]{Body: c}, toHTTP(err)
	})

	huma.Register(humaAPI, huma.Operation{
		OperationID: "import-xray", Method: http.MethodPost, Path: "/api/v1/import/xray",
		Summary: "Import users (UUIDs, passwords, Reality identity) from an Xray/V2Ray server config", Security: bearer,
		MaxBodyBytes: 4 << 20,
	}, func(ctx context.Context, in *struct {
		Body struct {
			Config  string                    `json:"config" doc:"The server config.json as text" minLength:"2"`
			Options manager.ImportXrayOptions `json:"options" required:"false" doc:"host, name and adopt_reality; optional"`
		}
	}) (*body[*manager.ImportXrayResult], error) {
		res, err := mgr.ImportXray(in.Body.Config, in.Body.Options)
		return &body[*manager.ImportXrayResult]{Body: res}, toHTTP(err)
	})

	huma.Register(humaAPI, huma.Operation{
		OperationID: "download-backup", Method: http.MethodGet, Path: "/api/v1/backup",
		Summary: "Download a backup (.tar.gz) of the state, keys and certificates; it holds every secret", Security: bearer,
	}, func(ctx context.Context, _ *struct{}) (*struct {
		ContentType        string `header:"Content-Type"`
		ContentDisposition string `header:"Content-Disposition"`
		Body               []byte
	}, error) {
		var buf bytes.Buffer
		if err := mgr.Backup(&buf); err != nil {
			return nil, toHTTP(err)
		}
		return &struct {
			ContentType        string `header:"Content-Type"`
			ContentDisposition string `header:"Content-Disposition"`
			Body               []byte
		}{ContentType: "application/gzip", ContentDisposition: `attachment; filename="omnitun-server-backup.tar.gz"`, Body: buf.Bytes()}, nil
	})

	huma.Register(humaAPI, huma.Operation{
		OperationID: "reload", Method: http.MethodPost, Path: "/api/v1/reload",
		Summary: "Restart the VPN core now (it also reloads by itself within seconds)", Security: bearer,
		DefaultStatus: http.StatusNoContent,
	}, func(ctx context.Context, _ *struct{}) (*struct{}, error) {
		if opts.Reload == nil {
			return nil, huma.Error501NotImplemented("the VPN core does not run in this process")
		}
		if err := opts.Reload(); err != nil {
			return nil, huma.Error500InternalServerError(err.Error())
		}
		return nil, nil
	})

	return router
}

func unacknowledged(list []logs.Alert) int {
	count := 0
	for _, alert := range list {
		if !alert.Acknowledged {
			count++
		}
	}
	return count
}

// recoverer answers 500 to a request whose handler panicked and writes the
// panic to the server log (a fatal record and an alert).
func recoverer(log *logs.Log) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			defer func() {
				if value := recover(); value != nil {
					if value == http.ErrAbortHandler {
						panic(value)
					}
					log.LogPanic(value, "api", "request")
					w.WriteHeader(http.StatusInternalServerError)
				}
			}()
			next.ServeHTTP(w, r)
		})
	}
}

// authenticate rejects requests to secured operations without the token.
func authenticate(humaAPI huma.API, current func() string) func(huma.Context, func(huma.Context)) {
	return func(ctx huma.Context, next func(huma.Context)) {
		if len(ctx.Operation().Security) == 0 {
			next(ctx)
			return
		}
		got, ok := strings.CutPrefix(ctx.Header("Authorization"), "Bearer ")
		token := ""
		if current != nil {
			token = current()
		}
		if !ok || token == "" || subtle.ConstantTimeCompare([]byte(got), []byte(token)) != 1 {
			ctx.SetHeader("WWW-Authenticate", "Bearer")
			huma.WriteErr(humaAPI, ctx, http.StatusUnauthorized, "a valid bearer token is required")
			return
		}
		next(ctx)
	}
}
