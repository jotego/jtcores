/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 21-11-2026 */

package picorom

// PicoROM packet protocol (firmware/pico_link.h) plus the event recorder,
// pause and pin-snapshot extensions of the jtkcpu diagnostic firmware
// (/nobackup/jtmisc/reverse/PicoROM, branch jtkcpu-1, firmware/README-jtkcpu.md)

import (
	"encoding/binary"
	"errors"
	"fmt"
)

const (
	pkt_write          = 6
	pkt_read           = 7
	pkt_read_data      = 8
	pkt_set_param      = 20
	pkt_get_param      = 21
	pkt_param          = 22
	pkt_param_error    = 23
	pkt_comms_start    = 80
	pkt_comms_end      = 81
	pkt_comms_data     = 82
	pkt_error          = 0xfe
	pkt_debug          = 0xff
	max_payload        = 36
	chunk              = 32
	event_ring_entries = 31
)

var ErrParam = errors.New("parameter not available")

// Link is an open connection to one PicoROM unit
type Link struct {
	Dev      UsbDevice
	usb      *usb_handle
	received []byte // CommsData bytes collected while waiting for other packets
}

// Open connects to the unit whose USB name is name
func Open(name string) (*Link, error) {
	devs, e := ListUsb(); if e != nil { return nil, e }
	for _, d := range devs {
		if d.Name == name { return OpenDevice(d) }
	}
	return nil, fmt.Errorf("PicoROM %q is not connected", name)
}

func OpenDevice(d UsbDevice) (*Link, error) {
	h, e := open_usb(d); if e != nil { return nil, e }
	l := &Link{Dev: d, usb: h}
	l.drain()
	return l, nil
}

func (l *Link) Close() { l.usb.close() }

func (l *Link) send(kind byte, payload []byte) error {
	if len(payload) > max_payload { return fmt.Errorf("payload of %d bytes", len(payload)) }
	pkt := append([]byte{kind, byte(len(payload))}, payload...)
	_, e := l.usb.bulk(ep_out, pkt, 1000)
	return e
}

func (l *Link) receive(timeout_ms int) (byte, []byte, error) {
	buf := make([]byte, 64)
	n, e := l.usb.bulk(ep_in, buf, timeout_ms); if e != nil { return 0, nil, e }
	if n < 2 || n != int(buf[1])+2 { return 0, nil, fmt.Errorf("malformed packet %x", buf[:n]) }
	if buf[0] == pkt_error { return 0, nil, fmt.Errorf("firmware error %q", buf[2:n]) }
	return buf[0], buf[2:n], nil
}

func (l *Link) drain() {
	for {
		_, _, e := l.receive(5); if e != nil { return }
	}
}

// expect waits for a packet of the given kind, keeping CommsData bytes
func (l *Link) expect(kind byte) ([]byte, error) {
	for k := 0; k < 32; k++ {
		got, data, e := l.receive(1000); if e != nil { return nil, e }
		switch {
		case got == kind: return data, nil
		case got == pkt_debug: continue
		case got == pkt_comms_data: l.received = append(l.received, data...)
		case got == pkt_param_error && (kind == pkt_param): return nil, ErrParam
		default: return nil, fmt.Errorf("expected packet %d, got %d: %q", kind, got, data)
		}
	}
	return nil, errors.New("too many unsolicited packets")
}

// Get reads a firmware parameter, such as name, build_config or addr_mask
func (l *Link) Get(name string) (string, error) {
	e := l.send(pkt_get_param, append([]byte(name), 0)); if e != nil { return "", e }
	data, e := l.expect(pkt_param); if e != nil { return "", fmt.Errorf("%s: %w", name, e) }
	return string(data), nil
}

// Set writes a parameter and returns the value reported back
func (l *Link) Set(name, value string) (string, error) {
	e := l.send(pkt_set_param, append([]byte(name+","+value), 0)); if e != nil { return "", e }
	data, e := l.expect(pkt_param); if e != nil { return "", fmt.Errorf("%s: %w", name, e) }
	return string(data), nil
}

// Read copies length bytes of the ROM image starting at offset
func (l *Link) Read(offset, length int) ([]byte, error) {
	data := make([]byte, 0, length)
	for len(data) < length {
		pos := offset + len(data)
		n := min(chunk, length-len(data))
		req := binary.LittleEndian.AppendUint32(nil, uint32(pos))
		e := l.send(pkt_read, append(req, byte(n))); if e != nil { return nil, e }
		b, e := l.expect(pkt_read_data); if e != nil { return nil, e }
		if len(b) != n+4 || binary.LittleEndian.Uint32(b) != uint32(pos) {
			return nil, errors.New("readback offset/length mismatch")
		}
		data = append(data, b[4:]...)
	}
	return data, nil
}

// Write stores data in the volatile ROM image at offset
func (l *Link) Write(offset int, data []byte) error {
	for k := 0; k < len(data); k += chunk {
		end := min(k+chunk, len(data))
		pkt := binary.LittleEndian.AppendUint32(nil, uint32(offset+k))
		e := l.send(pkt_write, append(pkt, data[k:end]...)); if e != nil { return e }
	}
	_, e := l.Get("status") // request/response fence: all writes processed
	return e
}

// CommsStart opens a communications session at physical address base
func (l *Link) CommsStart(base int) error {
	if base%1024 != 0 { return fmt.Errorf("comms base 0x%x is not 1 KiB aligned", base) }
	e := l.send(pkt_comms_start, binary.LittleEndian.AppendUint32(nil, uint32(base))); if e != nil { return e }
	return l.expect_ack("comms start")
}

func (l *Link) CommsEnd() error {
	e := l.send(pkt_comms_end, nil); if e != nil { return e }
	return l.expect_ack("comms end")
}

func (l *Link) expect_ack(what string) error {
	k, b, e := l.receive(1000); if e != nil { return e }
	if k != pkt_debug { return fmt.Errorf("%s response %d: %q", what, k, b) }
	return nil
}

// Send passes host bytes to the CPU side of the communications window
func (l *Link) Send(data []byte) error { return l.send(pkt_comms_data, data) }

// Poll collects the bytes the CPU sent since the last poll
func (l *Link) Poll() ([]byte, error) {
	first := len(l.received)
	e := l.send(pkt_comms_data, nil); if e != nil { return nil, e }
	_, e = l.Get("status"); if e != nil { return nil, e }
	return l.received[first:], nil
}

type Event struct {
	Sequence int    `json:"sequence"`
	Address  int    `json:"address"`
	TimeUs   uint32 `json:"time_us"`
}

type EventSnapshot struct {
	Session        bool    `json:"session"` // the window holds a communications header
	Active         bool    `json:"active"`
	Count          int     `json:"count"`
	DroppedBytes   uint32  `json:"dropped_bytes"`
	LastEventUs    uint32  `json:"last_event_us"`
	CaptureStopped bool    `json:"capture_stopped"`
	Events         []Event `json:"events"`
}

// Events reads the diagnostic firmware's event ring at the session base
func (l *Link) Events(base int) (EventSnapshot, error) {
	for try := 0; try < 20; try++ {
		b, e := l.Read(base, 0x200); if e != nil { return EventSnapshot{}, e }
		if string(b[:4]) != "PICO" { return EventSnapshot{}, nil } // Session false
		count := int(binary.LittleEndian.Uint32(b[32:]))
		again, e := l.Read(base+32, 4); if e != nil { return EventSnapshot{}, e }
		if int(binary.LittleEndian.Uint32(again)) != count { continue }
		s := EventSnapshot{
			Session:        true,
			Active:         binary.LittleEndian.Uint32(b[4:]) != 0,
			Count:          count,
			DroppedBytes:   binary.LittleEndian.Uint32(b[36:]),
			LastEventUs:    binary.LittleEndian.Uint32(b[40:]),
			CaptureStopped: binary.LittleEndian.Uint32(b[44:]) != 0,
		}
		for i := max(0, count-event_ring_entries); i < count; i++ {
			at := 0x104 + (i%event_ring_entries)*8
			s.Events = append(s.Events, Event{Sequence: i,
				Address: int(binary.LittleEndian.Uint32(b[at:])),
				TimeUs:  binary.LittleEndian.Uint32(b[at+4:])})
		}
		return s, nil
	}
	return EventSnapshot{}, errors.New("no stable event snapshot")
}
