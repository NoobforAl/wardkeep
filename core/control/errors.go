package control

import (
	"errors"
	"strconv"
	"strings"

	"github.com/NoobforAl/omnitun/core/importer"
	"github.com/NoobforAl/omnitun/core/profile"
	"github.com/NoobforAl/omnitun/core/subscription"
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
	e := importError(err)
	if res != nil && len(res.Errors) > 0 {
		if e.Args == nil {
			e.Args = map[string]string{}
		}
		e.Args["details"] = strings.Join(res.Errors[:min(len(res.Errors), maxImportDetails)], "\n")
	}
	return e
}

// importError is the error reply for text that could not be imported.
func importError(err error) *Error {
	e := &Error{Code: CodeImportFailed, Message: err.Error()}
	var ue *importer.UnsupportedError
	var je *importer.JSONError
	var ns *importer.NoServerError
	switch {
	case errors.As(err, &je) && je.Found == "":
		e.Code = CodeImportJSONEnd
		e.Args = map[string]string{"line": strconv.Itoa(je.Line), "column": strconv.Itoa(je.Col)}
	case errors.As(err, &je):
		e.Code = CodeImportJSONSyntax
		e.Args = map[string]string{"line": strconv.Itoa(je.Line), "column": strconv.Itoa(je.Col), "found": je.Found}
	case errors.As(err, &ns):
		e.Code = CodeImportJSONNoServer
		e.Args = map[string]string{"found": ns.Found}
	case errors.Is(err, importer.ErrTooLarge):
		e.Code = CodeImportTooLarge
		e.Args = map[string]string{"limit": strconv.Itoa(importer.MaxTextSize >> 20)}
	case errors.Is(err, importer.ErrXrayServer):
		e.Code = CodeImportXrayServer
	case errors.Is(err, importer.ErrNoProfiles):
		e.Code = CodeImportNothing
	case errors.As(err, &ue):
		e.Code = CodeImportUnsupported
		e.Args = map[string]string{"scheme": ue.Scheme}
	case errors.Is(err, importer.ErrUnsupported):
		e.Code = CodeImportUnsupported
	}
	return e
}

// subscriptionError is the error reply for a subscription that could not be fetched.
func subscriptionError(err error) *Error {
	e := &Error{Code: CodeSubscriptionFailed, Message: err.Error()}
	var he *subscription.HTTPError
	switch {
	case errors.Is(err, subscription.ErrAuth):
		e.Code = CodeAuthFailed
	case errors.As(err, &he):
		e.Code = CodeSubHTTP
		e.Args = map[string]string{"status": strconv.Itoa(he.Status)}
	case errors.Is(err, subscription.ErrTooLarge):
		e.Code = CodeSubTooLarge
	case errors.Is(err, subscription.ErrBadURL):
		e.Code = CodeSubBadURL
	case errors.Is(err, subscription.ErrUnsigned):
		e.Code = CodeSubUnsigned
	case errors.Is(err, subscription.ErrBadSignature):
		e.Code = CodeSubBadSignature
	case errors.Is(err, subscription.ErrBadKey):
		e.Code = CodeSubBadKey
	}
	return e
}
