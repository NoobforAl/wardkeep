package logs

import (
	"bufio"
	"bytes"
	"fmt"
	"math/rand/v2"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"
)

// tailReference is the plain way to do it: read both files whole and keep the
// last n lines. Tail must give the same lines without reading them all.
func tailReference(dir string, n int) []string {
	var lines []string
	for _, name := range []string{fileName + ".1", fileName} {
		data, err := os.ReadFile(filepath.Join(dir, name))
		if err != nil {
			continue
		}
		sc := bufio.NewScanner(bytes.NewReader(data))
		sc.Buffer(make([]byte, 64<<10), 1<<20)
		for sc.Scan() {
			lines = append(lines, clean(sc.Text(), false))
		}
	}
	if len(lines) > n {
		lines = lines[len(lines)-n:]
	}
	if lines == nil {
		lines = []string{}
	}
	return lines
}

func TestTailMatchesReadingEverythingAtOnce(t *testing.T) {
	rng := rand.New(rand.NewPCG(1, 2))
	line := func(i int) string {
		return fmt.Sprintf("%05d %s", i, strings.Repeat("y", rng.IntN(300)))
	}
	build := func(count int, ending string, sep string) []byte {
		var b strings.Builder
		for i := range count {
			b.WriteString(line(i))
			if i < count-1 {
				b.WriteString(sep)
			}
		}
		if count > 0 {
			b.WriteString(ending)
		}
		return []byte(b.String())
	}
	cases := []struct {
		name         string
		old, current []byte
	}{
		{"empty", nil, nil},
		{"one line, no newline", nil, []byte("only")},
		{"one line", nil, []byte("only\n")},
		{"blank lines", nil, []byte("a\n\n\nb\n\n")},
		{"crlf", nil, build(50, "\r\n", "\r\n")},
		{"short", nil, build(20, "\n", "\n")},
		{"no final newline", nil, build(900, "", "\n")},
		{"spans several chunks", nil, build(3000, "\n", "\n")},
		{"with a rotated file", build(1500, "\n", "\n"), build(40, "\n", "\n")},
		{"only a rotated file", build(300, "\n", "\n"), nil},
		{"long lines", nil, []byte(strings.Repeat(strings.Repeat("z", 70000)+"\n", 6))},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			dir := tempDir(t)
			if c.old != nil {
				os.WriteFile(filepath.Join(dir, fileName+".1"), c.old, 0o600)
			}
			if c.current != nil {
				os.WriteFile(filepath.Join(dir, fileName), c.current, 0o600)
			}
			for _, n := range []int{1, 2, 3, 19, 20, 21, 50, 200, 1000, 1499, 1500, 1501, 4000} {
				got, err := Tail(dir, n)
				if err != nil {
					t.Fatal(err)
				}
				if want := tailReference(dir, n); !slices.Equal(got, want) {
					t.Fatalf("Tail(%d): %d lines, want %d (first %q, want %q)", n, len(got), len(want), first(got), first(want))
				}
			}
		})
	}
}

func first(s []string) string {
	if len(s) == 0 {
		return ""
	}
	return s[0]
}
