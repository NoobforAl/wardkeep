// Package logs keeps the server's log in server.log in the data directory
// (rotated at 4 MB, one old file kept), so the CLI, the TUI and the web API
// can show what the running server logged.
package logs

import (
	"bufio"
	"bytes"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
	"time"
	"unicode"
)

const (
	fileName = "server.log"
	// maxSize is when the file is rotated.
	maxSize = 4 << 20
)

var ansi = regexp.MustCompile(`\x1b\[[0-9;]*m`)

// clean makes text safe to print on a terminal: colour codes are removed and
// every control or invisible formatting character (ESC, BEL, backspace, the
// C1 range, bidi overrides, zero-width marks) is dropped, so a user name or a
// request header logged by the server cannot move the cursor, rewrite the
// screen or disguise a line. With collapse, runs of whitespace become one space.
func clean(s string, collapse bool) string {
	s = ansi.ReplaceAllString(s, "")
	var b strings.Builder
	space := false
	for _, r := range s {
		switch {
		case unicode.IsSpace(r) && !collapse:
			if r == ' ' {
				b.WriteByte(' ')
			}
		case unicode.IsSpace(r):
			space = true
		case unicode.IsControl(r) || unicode.Is(unicode.Cf, r):
		default:
			if space && b.Len() > 0 {
				b.WriteByte(' ')
			}
			space = false
			b.WriteRune(r)
		}
	}
	return b.String()
}

// Log is an append-only log file.
type Log struct {
	dir string

	mu   sync.Mutex
	f    *os.File
	size int64
	now  func() time.Time
}

// Open prepares the log in dir; the file is created on the first write.
func Open(dir string) *Log { return &Log{dir: dir, now: time.Now} }

func (l *Log) path() string { return filepath.Join(l.dir, fileName) }

func (l *Log) openLocked() error {
	if l.f != nil {
		return nil
	}
	if err := os.MkdirAll(l.dir, 0o700); err != nil {
		return err
	}
	f, err := os.OpenFile(l.path(), os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o600)
	if err != nil {
		return err
	}
	fi, err := f.Stat()
	if err != nil {
		f.Close()
		return err
	}
	l.f, l.size = f, fi.Size()
	return nil
}

func (l *Log) rotateLocked() {
	l.f.Close()
	l.f = nil
	os.Remove(l.path() + ".1")
	os.Rename(l.path(), l.path()+".1")
}

// Write appends one line: "2026-10-16 18:00:00 LEVEL message". Colour codes
// are removed and line breaks inside the message become spaces.
func (l *Log) Write(level, message string) {
	if l == nil {
		return
	}
	line := fmt.Sprintf("%s %-5s %s\n", l.now().Format("2006-01-02 15:04:05"), strings.ToUpper(clean(level, true)), clean(message, true))
	l.mu.Lock()
	defer l.mu.Unlock()
	if l.openLocked() != nil {
		return
	}
	if l.size+int64(len(line)) > maxSize {
		l.rotateLocked()
		if l.openLocked() != nil {
			return
		}
	}
	n, _ := io.WriteString(l.f, line)
	l.size += int64(n)
}

// Close releases the file.
func (l *Log) Close() {
	l.mu.Lock()
	defer l.mu.Unlock()
	if l.f != nil {
		l.f.Close()
		l.f = nil
	}
}

// Tail returns the last n lines of the log in dir (oldest first), reading the
// rotated file too when the current one is short. A missing log is empty.
func Tail(dir string, n int) ([]string, error) {
	if n <= 0 {
		return []string{}, nil
	}
	lines := []string{}
	for _, name := range []string{fileName, fileName + ".1"} { // newest first
		part, err := tailFile(filepath.Join(dir, name), n-len(lines))
		if err != nil {
			if os.IsNotExist(err) {
				continue
			}
			return nil, err
		}
		lines = append(part, lines...)
		if len(lines) >= n {
			break
		}
	}
	return lines, nil
}

// tailFile returns the last n lines of the file, read from its end so the cost
// is that of the lines asked for, not of a log that rotates at several MB.
func tailFile(path string, n int) ([]string, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	fi, err := f.Stat()
	if err != nil {
		return nil, err
	}
	var (
		buf   []byte
		pos   = fi.Size()
		chunk = int64(64 << 10)
	)
	for pos > 0 {
		step := min(chunk, pos)
		pos -= step
		block := make([]byte, step+int64(len(buf)))
		if _, err := f.ReadAt(block[:step], pos); err != nil && err != io.EOF {
			return nil, err
		}
		copy(block[step:], buf)
		buf = block
		// n lines need n+1 line breaks before them (the one ending the previous
		// line), not counting one that ends the file.
		if bytes.Count(bytes.TrimSuffix(buf, []byte{'\n'}), []byte{'\n'}) > n {
			break
		}
		chunk *= 2
	}
	if pos > 0 { // the first line of buf is a piece of a longer one
		if i := bytes.IndexByte(buf, '\n'); i >= 0 {
			buf = buf[i+1:]
		}
	}
	var lines []string
	sc := bufio.NewScanner(bytes.NewReader(buf))
	sc.Buffer(make([]byte, 64<<10), 1<<20)
	for sc.Scan() {
		lines = append(lines, sc.Text())
	}
	if len(lines) > n {
		lines = lines[len(lines)-n:]
	}
	for i, l := range lines {
		lines[i] = clean(l, false) // also covers a log written by something else
	}
	return lines, nil
}
