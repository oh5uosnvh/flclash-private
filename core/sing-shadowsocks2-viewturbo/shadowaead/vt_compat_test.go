package shadowaead

import (
	"bytes"
	C "github.com/metacubex/sing-shadowsocks2/cipher"
	"github.com/metacubex/sing-shadowsocks2/internal/legacykey"
	"github.com/metacubex/sing-shadowsocks2/internal/shadowio"
	M "github.com/metacubex/sing/common/metadata"
	"io"
	"strings"
	"testing"
)

type responseConn struct {
	memoryConn
	reader io.Reader
}

func (c *responseConn) Read(p []byte) (int, error) { return c.reader.Read(p) }

func TestViewTurboPasswordSeparation(t *testing.T) {
	for _, tc := range []struct {
		password, token, kdf string
		enabled              bool
	}{
		{"user-token#vt", "user-token", vtKDFPassword, true},
		{"old-value#viewTurbo", "", "old-value#viewTurbo", false},
		{"mixed#VT", "mixed", vtKDFPassword, true},
		{"ordinary", "", "ordinary", false},
	} {
		m, err := NewMethod("chacha20-ietf-poly1305", C.MethodOptions{Password: tc.password})
		if err != nil {
			t.Fatal(err)
		}
		if m.vtOn != tc.enabled || m.vtAuthToken != tc.token || !bytes.Equal(m.key, legacykey.Key([]byte(tc.kdf), 32)) {
			t.Fatal("password/token separation failed")
		}
	}
	if _, err := NewMethod("aes-128-gcm", C.MethodOptions{Password: "#vt"}); err == nil {
		t.Fatal("empty user token accepted")
	}
}

func TestViewTurboWireMatchesStandardSS(t *testing.T) {
	for _, early := range []bool{false, true} {
		m, err := NewMethod("chacha20-ietf-poly1305", C.MethodOptions{Password: "current-user-token#vt"})
		if err != nil {
			t.Fatal(err)
		}
		base := &responseConn{reader: strings.NewReader("HTTP/1.1 200 OK\r\n\r\n")}
		destination := M.ParseSocksaddrHostPort("example.com", 443)
		var conn io.ReadWriteCloser
		if early {
			conn = m.DialEarlyConn(base, destination)
		} else {
			conn, err = m.DialConn(base, destination)
			if err != nil {
				t.Fatal(err)
			}
		}
		if _, err = conn.Write([]byte("payload")); err != nil {
			t.Fatal(err)
		}
		wire := append([]byte(nil), base.Bytes()...)
		end := bytes.Index(wire, []byte("\r\n\r\n")) + 4
		if end < 24 || end > 64 {
			t.Fatal("bad prefix")
		}
		authLen := len(m.vtAuthToken) + 28
		auth := wire[end : end+authLen]
		auth[1] = ^auth[1]
		if !bytes.HasPrefix(auth, []byte(m.vtAuthToken+":")) {
			t.Fatal("wrong auth token")
		}
		ss := wire[end+authLen:]
		key := make([]byte, 32)
		salt := append([]byte(nil), ss[:32]...)
		salt[0] ^= 0xff
		legacykey.Kdf(legacykey.Key([]byte(vtKDFPassword), 32), salt, key)
		aead, err := m.constructor(key)
		if err != nil {
			t.Fatal(err)
		}
		reader := shadowio.NewReader(bytes.NewReader(ss[32:]), aead)
		dest, err := M.SocksaddrSerializer.ReadAddrPort(reader)
		if err != nil {
			t.Fatalf("standard SS decrypt failed (early=%v): %v", early, err)
		}
		if dest != destination {
			t.Fatal("destination mismatch")
		}
		body := make([]byte, 7)
		if _, err = io.ReadFull(reader, body); err != nil || string(body) != "payload" {
			t.Fatal("payload mismatch", err)
		}
	}
}

func TestViewTurboRejectsBadHTTP(t *testing.T) {
	for _, response := range []string{strings.Repeat("A", 8192)} {
		conn := &memoryConn{}
		conn.Buffer.WriteString(response)
		if err := vtSkipHTTPHeader(conn); err == nil {
			t.Fatal("invalid response accepted")
		}
	}
}
