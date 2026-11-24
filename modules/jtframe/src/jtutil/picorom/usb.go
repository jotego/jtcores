/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 21-11-2026 */

package picorom

// Linux usbfs transport for PicoROM units. It needs no cgo and no libusb:
// devices are found through sysfs and bulk transfers go through ioctl.

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"unsafe"

	"golang.org/x/sys/unix"
)

const (
	usb_vendor  = "2e8a"
	usb_product = "000a"
	ep_out      = 0x01
	ep_in       = 0x81
	// _IOWR('U', 2, struct usbdevfs_bulktransfer) on 64-bit Linux
	usbdevfs_bulk = 0xC0185502
	// _IOR('U', 15, unsigned int) and _IOR('U', 16, unsigned int)
	usbdevfs_claim   = 0x8004550F
	usbdevfs_release = 0x80045510
)

var sysfs_usb = "/sys/bus/usb/devices"

var ErrTimeout = errors.New("USB timeout")

// USB serial reported by PicoROM firmware: "<chip id>:<unit name>"
type UsbDevice struct {
	Serial string `json:"serial"`
	Name   string `json:"name"`
	Bus    int    `json:"bus"`
	Dev    int    `json:"dev"`
}

type usb_bulk struct {
	ep      uint32
	length  uint32
	timeout uint32
	_       uint32
	data    uintptr
}

type usb_handle struct {
	file *os.File
}

// ListUsb returns the PicoROM units visible on the USB bus
func ListUsb() ([]UsbDevice, error) {
	entries, e := os.ReadDir(sysfs_usb); if e != nil { return nil, e }
	var found []UsbDevice
	for _, each := range entries {
		dir := filepath.Join(sysfs_usb, each.Name())
		if read_sysfs(dir, "idVendor") != usb_vendor || read_sysfs(dir, "idProduct") != usb_product {
			continue
		}
		bus, _ := strconv.Atoi(read_sysfs(dir, "busnum"))
		dev, _ := strconv.Atoi(read_sysfs(dir, "devnum"))
		serial, name, _ := strings.Cut(read_sysfs(dir, "serial"), ":")
		found = append(found, UsbDevice{Serial: serial, Name: name, Bus: bus, Dev: dev})
	}
	return found, nil
}

func read_sysfs(dir, file string) string {
	data, e := os.ReadFile(filepath.Join(dir, file)); if e != nil { return "" }
	return strings.TrimSpace(string(data))
}

func open_usb(dev UsbDevice) (*usb_handle, error) {
	path := fmt.Sprintf("/dev/bus/usb/%03d/%03d", dev.Bus, dev.Dev)
	f, e := os.OpenFile(path, os.O_RDWR, 0); if e != nil {
		return nil, fmt.Errorf("cannot open %s (%s): %w. Check the udev rule for %s:%s",
			dev.Name, path, e, usb_vendor, usb_product)
	}
	h := &usb_handle{file: f}
	var iface uint32
	e = h.ioctl(usbdevfs_claim, unsafe.Pointer(&iface)); if e != nil {
		f.Close()
		return nil, fmt.Errorf("cannot claim %s: %w (is another program using it?)", dev.Name, e)
	}
	return h, nil
}

func (h *usb_handle) close() {
	var iface uint32
	h.ioctl(usbdevfs_release, unsafe.Pointer(&iface))
	h.file.Close()
}

func (h *usb_handle) ioctl(req uintptr, arg unsafe.Pointer) error {
	fd := h.file.Fd()
	_, _, errno := unix.Syscall(unix.SYS_IOCTL, fd, req, uintptr(arg))
	if errno != 0 { return errno }
	return nil
}

func (h *usb_handle) bulk(ep uint32, buf []byte, timeout_ms int) (int, error) {
	fd := h.file.Fd() // before taking addresses: Fd may grow the stack
	t := usb_bulk{ep: ep, length: uint32(len(buf)), timeout: uint32(timeout_ms),
		data: uintptr(unsafe.Pointer(&buf[0]))}
	n, _, errno := unix.Syscall(unix.SYS_IOCTL, fd, usbdevfs_bulk, uintptr(unsafe.Pointer(&t)))
	runtime.KeepAlive(buf)
	if errno == unix.ETIMEDOUT { return 0, ErrTimeout }
	if errno != 0 { return 0, errno }
	return int(n), nil
}
