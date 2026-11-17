package control

import (
	"errors"
	"net/url"
	"regexp"
	"strconv"
	"strings"

	"github.com/NoobforAl/wardkeep/core/engine"
	"github.com/NoobforAl/wardkeep/core/importer"
	"github.com/NoobforAl/wardkeep/core/profile"
	"github.com/NoobforAl/wardkeep/core/subscription"
)

// badRequest is the error reply for a request whose values are wrong; an
// editor's problems keep their code and arguments, so the UI can translate them.
func badRequest(err error) *Error {
	if fe, ok := errors.AsType[*profile.FormError](err); ok {
		return &Error{Code: fe.Code, Message: err.Error(), Args: fe.Args}
	}
	return &Error{Code: CodeBadRequest, Message: err.Error()}
}

// maxImportDetails is how many reasons an import failure carries (a list of hundreds would only be noise).
const maxImportDetails = 10

// importFailure is importError for an import that came back with reasons for the entries that failed: they go
// along in Args["details"], one per line, so the UI can show why and not only that it failed.
func importFailure(err error, res *importer.Result) *Error {
	rpcErr := importError(err)
	if res != nil && len(res.Errors) > 0 {
		if rpcErr.Args == nil {
			rpcErr.Args = map[string]string{}
		}
		rpcErr.Args["details"] = strings.Join(res.Errors[:min(len(res.Errors), maxImportDetails)], "\n")
	}
	return rpcErr
}

// importError is the error reply for text that could not be imported.
func importError(err error) *Error {
	rpcErr := &Error{Code: CodeImportFailed, Message: err.Error()}
	var ue *importer.UnsupportedError
	var je *importer.JSONError
	var ns *importer.NoServerError
	switch {
	case errors.As(err, &je) && je.Found == "":
		rpcErr.Code = CodeImportJSONEnd
		rpcErr.Args = map[string]string{"line": strconv.Itoa(je.Line), "column": strconv.Itoa(je.Col)}
	case errors.As(err, &je):
		rpcErr.Code = CodeImportJSONSyntax
		rpcErr.Args = map[string]string{"line": strconv.Itoa(je.Line), "column": strconv.Itoa(je.Col), "found": je.Found}
	case errors.As(err, &ns):
		rpcErr.Code = CodeImportJSONNoServer
		rpcErr.Args = map[string]string{"found": ns.Found}
	case errors.Is(err, importer.ErrTooLarge):
		rpcErr.Code = CodeImportTooLarge
		rpcErr.Args = map[string]string{"limit": strconv.Itoa(importer.MaxTextSize >> 20)}
	case errors.Is(err, importer.ErrXrayServer):
		rpcErr.Code = CodeImportXrayServer
	case errors.Is(err, importer.ErrNoProfiles):
		rpcErr.Code = CodeImportNothing
	case errors.As(err, &ue):
		rpcErr.Code = CodeImportUnsupported
		rpcErr.Args = map[string]string{"scheme": ue.Scheme}
	case errors.Is(err, importer.ErrUnsupported):
		rpcErr.Code = CodeImportUnsupported
	}
	return rpcErr
}

// subscriptionError is the error reply for a subscription that could not be fetched.
func subscriptionError(err error) *Error {
	rpcErr := &Error{Code: CodeSubscriptionFailed, Message: withoutLink(err)}
	var he *subscription.HTTPError
	switch {
	case errors.Is(err, subscription.ErrAuth):
		rpcErr.Code = CodeAuthFailed
	case errors.As(err, &he):
		rpcErr.Code = CodeSubHTTP
		rpcErr.Args = map[string]string{"status": strconv.Itoa(he.Status)}
	case errors.Is(err, subscription.ErrTooLarge):
		rpcErr.Code = CodeSubTooLarge
	case errors.Is(err, subscription.ErrBadURL):
		rpcErr.Code = CodeSubBadURL
	case errors.Is(err, subscription.ErrUnsigned):
		rpcErr.Code = CodeSubUnsigned
	case errors.Is(err, subscription.ErrBadSignature):
		rpcErr.Code = CodeSubBadSignature
	case errors.Is(err, subscription.ErrStale):
		rpcErr.Code = CodeSubStale
	case errors.Is(err, subscription.ErrBadKey):
		rpcErr.Code = CodeSubBadKey
	default:
		// The download itself failed (no route, refused, timed out, bad certificate): the kind of failure
		// goes along so the app can say it in its language instead of showing the Go error.
		if reason := engine.ClassifyError(err); reason != "" {
			rpcErr.Args = map[string]string{"reason": reason}
		}
	}
	return rpcErr
}

// quoted matches a double-quoted piece of an error text, the way Go quotes what it echoes back (%q).
var quoted = regexp.MustCompile(`"(?:[^"\\]|\\.)*"`)

// withoutLink is err's text with the address of a failed request left out: a subscription link carries the
// user's token in its path or query, and it must not reach a message, a log or the screen. The request's own
// URL goes first; then every quoted piece goes too, because Go echoes other addresses in quotes as well, such
// as a redirect's Location header it could not parse ("/sub/<token>/%zz"), and those are as secret as the link.
func withoutLink(err error) string {
	text := err.Error()
	ue, ok := errors.AsType[*url.Error](err)
	if !ok {
		return text
	}
	if ue.URL != "" {
		text = strings.ReplaceAll(text, ue.URL, "<link>")
	}
	return quoted.ReplaceAllString(text, `"<link>"`)
}
