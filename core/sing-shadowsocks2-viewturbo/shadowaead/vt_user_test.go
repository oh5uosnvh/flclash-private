package shadowaead

import (
	"bytes"
	C "github.com/metacubex/sing-shadowsocks2/cipher"
	"github.com/metacubex/sing-shadowsocks2/internal/legacykey"
	"testing"
)

func TestUserTokenUsesFixedKDFAndIndependentAuth(t *testing.T) {
	for _, token := range []string{"test-user-one", "test-user-two-longer"} {
		m, err := NewMethod("aes-128-gcm", C.MethodOptions{Password: token + "#vt"})
		if err != nil {
			t.Fatal(err)
		}
		if !m.vtOn || m.vtAuthToken != token {
			t.Fatal("token not selected")
		}
		if !bytes.Equal(m.key, legacykey.Key([]byte("password"), 16)) {
			t.Fatal("wrong KDF")
		}
		auth := vtAuthPacket(m.vtAuthToken)
		auth[1] = ^auth[1]
		if !bytes.HasPrefix(auth, []byte(token+":")) {
			t.Fatal("wrong authentication")
		}
	}
	if _, err := NewMethod("aes-128-gcm", C.MethodOptions{Password: "#vt"}); err == nil {
		t.Fatal("empty token accepted")
	}
	ordinary, err := NewMethod("aes-128-gcm", C.MethodOptions{Password: "ordinary"})
	if err != nil || ordinary.vtOn || !bytes.Equal(ordinary.key, legacykey.Key([]byte("ordinary"), 16)) {
		t.Fatal("ordinary SS changed")
	}
}
