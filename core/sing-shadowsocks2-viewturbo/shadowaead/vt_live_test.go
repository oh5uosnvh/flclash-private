package shadowaead

import (
	"bufio"
	"bytes"
	"crypto/rand"
	"encoding/json"
	C "github.com/metacubex/sing-shadowsocks2/cipher"
	"github.com/metacubex/sing-shadowsocks2/internal/legacykey"
	"github.com/metacubex/sing-shadowsocks2/internal/shadowio"
	M "github.com/metacubex/sing/common/metadata"
	"io"
	"net"
	"os"
	"strings"
	"testing"
	"time"
)

func TestViewTurboLiveComparison(t *testing.T) {
	path := os.Getenv("VT_LIVE_CONFIG")
	if path == "" {
		t.Skip("explicit live configuration required")
	}
	data, _ := os.ReadFile(path)
	var n struct{ Cipher, Password, Address string }
	if err := json.Unmarshal(data, &n); err != nil {
		t.Fatal(err)
	}
	raw := strings.TrimSuffix(strings.TrimSuffix(n.Password, "#vt"), "#viewTurbo")
	for _, mode := range []string{"neko", "document", "neko-standard-salt", "neko-fixed-kdf"} {
		t.Run(mode, func(t *testing.T) {
			c, err := net.DialTimeout("tcp", n.Address, 5*time.Second)
			if err != nil {
				t.Log("tcp", err)
				return
			}
			defer c.Close()
			c.SetDeadline(time.Now().Add(7 * time.Second))
			token, kdf, flip := vtToken, raw, true
			if mode == "document" {
				token, kdf, flip = raw, "password", false
			}
			if mode == "neko-standard-salt" {
				flip = false
			}
			if mode == "neko-fixed-kdf" {
				kdf = "password"
			}
			m, err := NewMethod(n.Cipher, C.MethodOptions{Password: kdf})
			if err != nil {
				t.Fatal(err)
			}
			if _, err = c.Write(vtPrefix()); err != nil {
				t.Log("prefix", err)
				return
			}
			if _, err = c.Write(vtAuthPacket(token)); err != nil {
				t.Log("auth", err)
				return
			}
			salt := make([]byte, m.keySaltLength)
			rand.Read(salt)
			key := make([]byte, m.keySaltLength)
			legacykey.Kdf(m.key, salt, key)
			a, _ := m.constructor(key)
			if flip {
				salt[0] = ^salt[0]
			}
			var payload bytes.Buffer
			M.SocksaddrSerializer.WriteAddrPort(&payload, M.ParseSocksaddrHostPort("www.gstatic.com", 80))
			payload.WriteString("GET /generate_204 HTTP/1.1\r\nHost: www.gstatic.com\r\nConnection: close\r\n\r\n")
			if _, err = c.Write(salt); err != nil {
				t.Log("salt", err)
				return
			}
			w := shadowio.NewWriter(c, a, nil, MaxPacketSize)
			if _, err = w.Write(payload.Bytes()); err != nil {
				t.Log("write", err)
				return
			}
			if err = vtSkipHTTPHeader(c); err != nil {
				t.Log("outer-response", err)
				return
			}
			if _, err = io.ReadFull(c, salt); err != nil {
				t.Log("response-salt", err)
				return
			}
			legacykey.Kdf(m.key, salt, key)
			a, _ = m.constructor(key)
			r := shadowio.NewReader(c, a)
			line, err := bufio.NewReader(r).ReadString('\n')
			if err != nil {
				t.Log("decrypt", err)
				return
			}
			t.Log("SUCCESS", strings.TrimSpace(line))
		})
	}
}
