package winsvc

import (
	"os"
	"path/filepath"
	"slices"
	"testing"
)

func TestAncestorDirs(t *testing.T) {
	root := filepath.VolumeName(os.TempDir()) + string(filepath.Separator)
	cases := []struct {
		file string
		want []string
	}{
		{filepath.Join(root, "a", "b", "f.exe"), []string{filepath.Join(root, "a", "b"), filepath.Join(root, "a"), root}},
		{filepath.Join(root, "f.exe"), []string{root}},
		{filepath.Join(root, "Program Files", "Omnitun", "omnitun-svc.exe"), []string{filepath.Join(root, "Program Files", "Omnitun"), filepath.Join(root, "Program Files"), root}},
	}
	for _, c := range cases {
		if got := ancestorDirs(c.file); !slices.Equal(got, c.want) {
			t.Errorf("ancestorDirs(%s) = %v, want %v", c.file, got, c.want)
		}
	}
	// Every chain ends at a root, which is its own parent.
	for _, f := range []string{filepath.Join(root, "x", "y", "z", "f.exe"), root + "f"} {
		got := ancestorDirs(f)
		last := got[len(got)-1]
		if filepath.Dir(last) != last {
			t.Errorf("chain of %s does not end at a root: %v", f, got)
		}
	}
}

// The folders above the source matter for what they let others do to the
// folder below: delete or rename it, rewrite its list, take it over. Adding
// entries (the default on a drive root) does not.
func TestWritersOfAncestor(t *testing.T) {
	const (
		addSubfolder = 0x4
		addFile      = 0x2
		read         = 0x001200A9
	)
	cases := []struct {
		name    string
		owner   string
		entries []aceEntry
		want    []string
	}{
		{"drive root: users may add folders", sidSystem, []aceEntry{
			{SID: sidSystem, Mask: genericAll}, {SID: sidAdministrators, Mask: genericAll},
			{SID: usersSID, Mask: addSubfolder}, {SID: usersSID, Mask: addFile},
			{SID: usersSID, Mask: genericAll, Flags: aceInheritOnly},
		}, nil},
		{"users can delete children", sidSystem, []aceEntry{{SID: usersSID, Mask: fileDeleteChild}}, []string{usersSID}},
		{"users can delete it", sidSystem, []aceEntry{{SID: usersSID, Mask: accessDelete}}, []string{usersSID}},
		{"users can rewrite the list", sidSystem, []aceEntry{{SID: usersSID, Mask: accessWriteDAC}}, []string{usersSID}},
		{"users can take ownership", sidSystem, []aceEntry{{SID: usersSID, Mask: accessWriteOwner}}, []string{usersSID}},
		{"full control", sidSystem, []aceEntry{{SID: userSID, Mask: genericAll}}, []string{userSID}},
		{"owned by a user", userSID, []aceEntry{{SID: usersSID, Mask: read}}, []string{userSID}},
		{"read only", sidAdministrators, []aceEntry{{SID: usersSID, Mask: read}}, nil},
		{"deny is not access", sidSystem, []aceEntry{{SID: usersSID, Mask: genericAll, Deny: true}}, nil},
	}
	for _, c := range cases {
		if got := writersOfAncestor(c.owner, c.entries); !slices.Equal(got, c.want) {
			t.Errorf("%s: %v, want %v", c.name, got, c.want)
		}
	}
	// The same entries on the folder that holds the program are stricter.
	if got := writersOf(sidSystem, []aceEntry{{SID: usersSID, Mask: addFile}}); !slices.Equal(got, []string{usersSID}) {
		t.Errorf("adding files to the program's own folder must count: %v", got)
	}
}
