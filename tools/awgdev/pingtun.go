package main

import (
	"encoding/binary"
	"log"
	"os"

	"github.com/amnezia-vpn/amneziawg-go/tun"
)

// pingTun is a fake TUN device that answers ICMP echo requests to any address.
type pingTun struct {
	replies chan []byte
	events  chan tun.Event
	closed  chan struct{}
}

func newPingTun() *pingTun {
	t := &pingTun{replies: make(chan []byte, 64), events: make(chan tun.Event, 1), closed: make(chan struct{})}
	t.events <- tun.EventUp
	return t
}

func (t *pingTun) File() *os.File           { return nil }
func (t *pingTun) MTU() (int, error)        { return 1280, nil }
func (t *pingTun) Name() (string, error)    { return "pingtun", nil }
func (t *pingTun) Events() <-chan tun.Event { return t.events }
func (t *pingTun) BatchSize() int           { return 1 }

func (t *pingTun) Read(bufs [][]byte, sizes []int, offset int) (int, error) {
	select {
	case p := <-t.replies:
		sizes[0] = copy(bufs[0][offset:], p)
		return 1, nil
	case <-t.closed:
		return 0, os.ErrClosed
	}
}

// Write receives packets from the peer and queues echo replies.
func (t *pingTun) Write(bufs [][]byte, offset int) (int, error) {
	for _, b := range bufs {
		pkt := b[offset:]
		if len(pkt) < 28 || pkt[0]>>4 != 4 || pkt[9] != 1 {
			continue // not IPv4 ICMP
		}
		ihl := int(pkt[0]&0x0f) * 4
		if len(pkt) < ihl+8 || pkt[ihl] != 8 {
			continue // not an echo request
		}
		reply := append([]byte(nil), pkt...)
		copy(reply[12:16], pkt[16:20]) // swap addresses
		copy(reply[16:20], pkt[12:16])
		reply[8] = 64 // TTL
		reply[10], reply[11] = 0, 0
		binary.BigEndian.PutUint16(reply[10:], checksum(reply[:ihl]))
		reply[ihl] = 0 // echo reply
		reply[ihl+2], reply[ihl+3] = 0, 0
		binary.BigEndian.PutUint16(reply[ihl+2:], checksum(reply[ihl:]))
		log.Printf("ping from %d.%d.%d.%d", pkt[12], pkt[13], pkt[14], pkt[15])
		select {
		case t.replies <- reply:
		default:
		}
	}
	return len(bufs), nil
}

func (t *pingTun) Close() error {
	close(t.closed)
	close(t.events)
	return nil
}

func checksum(b []byte) uint16 {
	var sum uint32
	for i := 0; i+1 < len(b); i += 2 {
		sum += uint32(binary.BigEndian.Uint16(b[i:]))
	}
	if len(b)%2 == 1 {
		sum += uint32(b[len(b)-1]) << 8
	}
	for sum>>16 != 0 {
		sum = sum&0xffff + sum>>16
	}
	return ^uint16(sum)
}
