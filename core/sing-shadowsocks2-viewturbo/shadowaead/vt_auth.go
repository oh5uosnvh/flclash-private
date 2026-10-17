package shadowaead

import (
	"fmt"
	"io"
	"math/rand"
	"net"
	"strings"
)

// viewTurbo 魔改握手常量 (逆向自 ViewTurbo 1.17.0 viewturbocore)
const vtToken = "2n6LtY0nIPV2hACRnAd7ALchE2tekEcb"

var vtMagic = "#viewTurbo"

var vtLetters = []byte("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")

func vtRandAlpha(n int) []byte {
	b := make([]byte, n)
	for i := 0; i < n; i++ {
		b[i] = vtLetters[rand.Intn(len(vtLetters))]
	}
	return b
}

func parseViewTurboPassword(password string) (string, string, bool) {
	for _, marker := range []string{vtMagic, "#vt"} {
		if len(password) >= len(marker) && strings.EqualFold(password[len(password)-len(marker):], marker) {
			return password[:len(password)-len(marker)], vtToken, true
		}
	}
	return password, "", false
}

// vtPrefix HTTP obfs 前缀: 20~60 随机字母 + \r\n\r\n
func vtPrefix() []byte {
	n := 20 + rand.Intn(41)
	return append(vtRandAlpha(n), '\r', '\n', '\r', '\n')
}

// vtAuthPacket token 认证包: token + ":" + 随机27字母, 发送前 buf[1] 按位取反, 恒定 60 字节
func vtAuthPacket(token string) []byte {
	b := make([]byte, 0, len(token)+1+27)
	b = append(b, token...)
	b = append(b, ':')
	b = append(b, vtRandAlpha(27)...)
	if len(b) > 1 {
		b[1] = ^b[1]
	}
	return b
}

// vtSkipHTTPHeader 服务端下行以明文 HTTP 头开头 (HTTP/1.1 200 OK ... \r\n\r\n), 之后紧跟标准 SS 的 salt.
// 读取并丢弃直到 \r\n\r\n 结束, 让后续 readResponse 从 salt 开始对齐.
func vtSkipHTTPHeader(conn net.Conn) error {
	buf1 := make([]byte, 1)
	state := 0 // 匹配 \r\n\r\n
	// 上限保护, 避免异常流量死循环
	for i := 0; i < 8192; i++ {
		if _, err := io.ReadFull(conn, buf1); err != nil {
			return err
		}
		c := buf1[0]
		switch state {
		case 0:
			if c == '\r' {
				state = 1
			}
		case 1:
			if c == '\n' {
				state = 2
			} else if c == '\r' {
				state = 1
			} else {
				state = 0
			}
		case 2:
			if c == '\r' {
				state = 3
			} else {
				state = 0
			}
		case 3:
			if c == '\n' {
				return nil
			} else if c == '\r' {
				state = 1
			} else {
				state = 0
			}
		}
	}
	return fmt.Errorf("viewTurbo: HTTP response header exceeds 8192 bytes")
}
