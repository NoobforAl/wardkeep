//go:build windows

package winsvc

import (
	"crypto/md5" //nolint:gosec // G501: Wintun derives adapter GUIDs with MD5; not used for security
	"errors"
	"fmt"
	"net"
	"strings"
	"unsafe"

	"golang.org/x/sys/windows"
	"golang.org/x/sys/windows/registry"
	"golang.zx2c4.com/wireguard/windows/tunnel/winipcfg"

	"github.com/NoobforAl/omnitun/core/killswitch"
)

// CleanupSteps are the steps that remove what a crashed run left (see the list
// in cleanup.go). tunName is the TUN adapter's name. Run them only while no
// core is running: they remove the adapter.
func CleanupSteps(tunName string) []Step {
	return []Step{
		{Name: "kill switch rules", Run: func() (string, error) {
			// Dynamic sessions vanish with their process; this removes only
			// objects of ours that someone made persistent.
			return "", killswitch.Cleanup()
		}},
		{Name: "tunnel adapter", Run: func() (string, error) { return removeAdapter(tunName) }},
		{Name: "resolver cache", Run: func() (string, error) { return "", flushResolverCache() }},
	}
}

// WintunGUID is the identity sing-tun gives the Wintun adapter called name
// (tun_windows.go, generateGUIDByDeviceName): the MD5 of "wintun" + name,
// read as a GUID.
func WintunGUID(name string) windows.GUID {
	h := md5.New() //nolint:gosec // G401: must match sing-box's generateGUIDByDeviceName; not used for security
	h.Write([]byte("wintun"))
	h.Write([]byte(name))
	sum := h.Sum(nil)
	return *(*windows.GUID)(unsafe.Pointer(&sum[0])) //nolint:gosec // G103: a 16-byte MD5 sum read as a 16-byte GUID
}

// Adapter is a network device of the Wintun driver.
type Adapter struct {
	// InstanceID is the device's id in the device manager.
	InstanceID string
	// NetCfgInstanceID is the adapter's GUID, braces included.
	NetCfgInstanceID string
}

var deviceClassNet = windows.GUID{Data1: 0x4d36e972, Data2: 0xe325, Data3: 0x11ce, Data4: [8]byte{0xbf, 0xc1, 0x08, 0x00, 0x2b, 0xe1, 0x03, 0x18}}

// forEachNetDevice calls fn for every present network device with its
// hardware ids and driver GUID; fn returns true to stop.
func forEachNetDevice(fn func(devs windows.DevInfo, data *windows.DevInfoData, hardwareIDs []string, netCfg string) bool) error {
	devs, err := windows.SetupDiGetClassDevsEx(&deviceClassNet, "", 0, windows.DIGCF_PRESENT, 0, "")
	if err != nil {
		return err
	}
	defer devs.Close()
	for i := 0; ; i++ {
		data, err := devs.EnumDeviceInfo(i)
		if err != nil {
			if errors.Is(err, windows.ERROR_NO_MORE_ITEMS) {
				return nil
			}
			continue
		}
		var hw []string
		if v, err := windows.SetupDiGetDeviceRegistryProperty(devs, data, windows.SPDRP_HARDWAREID); err == nil {
			switch t := v.(type) {
			case []string:
				hw = t
			case string:
				hw = []string{t}
			}
		}
		netCfg := ""
		if key, err := windows.SetupDiOpenDevRegKey(devs, data, windows.DICS_FLAG_GLOBAL, 0, windows.DIREG_DRV, windows.KEY_READ); err == nil {
			k := registry.Key(key)
			netCfg, _, _ = k.GetStringValue("NetCfgInstanceId")
			k.Close()
		}
		if fn(devs, data, hw, netCfg) {
			return nil
		}
	}
}

func isWintun(hardwareIDs []string) bool {
	for _, id := range hardwareIDs {
		if strings.Contains(strings.ToLower(id), "wintun") {
			return true
		}
	}
	return false
}

// ListWintunAdapters lists the Wintun adapters on this machine. It only reads
// and needs no special rights.
func ListWintunAdapters() ([]Adapter, error) {
	var out []Adapter
	err := forEachNetDevice(func(devs windows.DevInfo, data *windows.DevInfoData, hw []string, netCfg string) bool {
		if isWintun(hw) {
			a := Adapter{NetCfgInstanceID: netCfg}
			if id, err := devs.DeviceInstanceID(data); err == nil {
				a.InstanceID = id
			}
			out = append(out, a)
		}
		return false
	})
	return out, err
}

// removeAdapter removes the Wintun adapter called name together with its
// addresses, routes and DNS settings. Only an adapter whose GUID is the one
// sing-tun derives from exactly this name is touched.
func removeAdapter(name string) (string, error) {
	var done []string
	var errs []error

	if ifc, err := net.InterfaceByName(name); err == nil {
		// Flush first: if the device cannot be removed, the adapter at least
		// stops carrying the VPN's routes and DNS.
		if luid, err := winipcfg.LUIDFromIndex(uint32(ifc.Index)); err == nil { //nolint:gosec // G115: interface indexes are positive 32-bit values
			for _, fam := range []winipcfg.AddressFamily{windows.AF_INET, windows.AF_INET6} {
				if err := luid.FlushRoutes(fam); err != nil {
					errs = append(errs, fmt.Errorf("flush routes: %w", err))
				}
				if err := luid.FlushIPAddresses(fam); err != nil {
					errs = append(errs, fmt.Errorf("flush addresses: %w", err))
				}
				if err := luid.FlushDNS(fam); err != nil {
					errs = append(errs, fmt.Errorf("flush DNS: %w", err))
				}
			}
			done = append(done, "flushed routes, addresses and DNS of "+name)
		}
	}

	want := WintunGUID(name).String()
	removed := false
	var removeErr error
	err := forEachNetDevice(func(devs windows.DevInfo, data *windows.DevInfoData, hw []string, netCfg string) bool {
		if !isWintun(hw) || !strings.EqualFold(netCfg, want) {
			return false
		}
		params := windows.RemoveDeviceParams{
			ClassInstallHeader: *windows.MakeClassInstallHeader(windows.DIF_REMOVE),
			Scope:              windows.DI_REMOVEDEVICE_GLOBAL,
		}
		if err := windows.SetupDiSetClassInstallParams(devs, data, &params.ClassInstallHeader, uint32(unsafe.Sizeof(params))); err != nil {
			removeErr = fmt.Errorf("remove adapter: %w", err)
		} else if err := windows.SetupDiCallClassInstaller(windows.DIF_REMOVE, devs, data); err != nil {
			removeErr = fmt.Errorf("remove adapter: %w", err)
		} else {
			removed = true
		}
		return true
	})
	if err != nil {
		errs = append(errs, fmt.Errorf("list network devices: %w", err))
	}
	if removeErr != nil {
		errs = append(errs, removeErr)
	}
	if removed {
		done = append(done, "removed the adapter "+name)
	}
	return strings.Join(done, "; "), errors.Join(errs...)
}

func flushResolverCache() error {
	dnsapi := windows.NewLazySystemDLL("dnsapi.dll")
	proc := dnsapi.NewProc("DnsFlushResolverCache")
	if err := proc.Find(); err != nil {
		return err
	}
	if r, _, _ := proc.Call(); r == 0 {
		return errors.New("DnsFlushResolverCache failed")
	}
	return nil
}
