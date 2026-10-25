# FlClash private-protocol build

This repository links the maintained private protocol extensions into Android and Windows builds.

## Source linkage

The kernel is maintained in **`oh5uosnvh/clash-meta-mods`** on branch `mods`.
CI clones the selected kernel reference into `core/Clash.Meta` at build time.

| Feature | Source location | Integration |
|---|---|---|
| x365 (365VPN / efan) | clash-meta-mods: `transport/x365` + outbound/parser | kernel repo commit f87a52d2 |
| Blackstone private Clash `type: xhttp` | clash-meta-mods: `transport/blackstonexhttp` + outbound/parser | kernel repo commit f87a52d2 |
| ViewTurbo modified SS | `core/sing-shadowsocks2-viewturbo` (frozen snapshot) | `core/go.mod replace` |
| Shanlian (LightXtreme) AnyTLS | clash-meta-mods: `transport/anytls` + converter | kernel repo commit a7ee1b1a |

### Kernel update SOP

1. Update the maintained kernel branch.
2. Run the kernel and protocol test suites.
3. Dispatch the build workflow with the desired kernel reference.

The public `oh5uosnvh/FlClash` repository is not modified and contains none of these implementation details.

## Configuration

### x365

```yaml
proxies:
  - name: x365-hk
    type: vless
    server: bgp01.example.com
    port: 443
    uuid: "376aac10-754a-4b62-9855-6683c9adafce#x365"
    tls: true
    servername: updates.cdn-apple.com
    client-fingerprint: chrome
    network: xhttp
    reality-opts:
      public-key: BASE64URL_X25519_PUBLIC_KEY
      short-id: c7cb949d076c9e93
    xhttp-opts:
      host: updates.cdn-apple.com
      path: /hk
      mode: stream-one
    udp: true
```

Only a `type: vless` UUID ending in `#x365` selects the private X365 wire handshake. The suffix is stripped before authentication; API/UI type remains VLESS. Unmarked VLESS uses the official implementation. Standalone `type: x365` is not accepted.

### Blackstone VPN xhttp

The proxy type is exactly `xhttp`, as in the official decrypted Clash YAML. It is not renamed to `heysocks`.

```yaml
proxies:
  - name: Blackstone
    type: xhttp
    server: 101.116.156.114
    port: 40081
    gateway: af45.iotstacker.com:20244
    cipher: aes-128-ctr
    password: "KEY1:LENGTH_PREFIXED_KEY2"
    sess: 68_BYTE_HEX_SESSION
    # auth: TOKEN_HEX       # optional; overrides token embedded in password key2
    udp: true
    udp-over-tcp: true
```

The implementation also directly accepts official fields:

```yaml
    fake-net:
      tcp: 68_BYTE_HEX_SESSION
      udp: 68_BYTE_HEX_SESSION
    padding-len: 8-64
    network: xhttp
    tls: true
    servername: apple.com
    client-fingerprint: chrome
    xhttp-opts:
      host: apple.com
      path: /hEK8lz27
```

If `gateway` is absent, an official name ending `-gateway.host-port` is recognized. Explicit `gateway` is safer. The server-issued session/token can rotate; stale values will not authenticate.

### ViewTurbo

```yaml
proxies:
  - name: ViewTurbo
    type: ss
    server: 203.0.113.10
    port: 15889
    cipher: chacha20-ietf-poly1305
    password: "ACCOUNT_TOKEN#vt"
    udp: true
```

Only `#vt` selects ViewTurbo: the bare token is used for outer authentication and the verified fixed password is used for inner SS encryption. Unmarked passwords (including the old `#viewTurbo` suffix) use standard SS.

### FastUP

Keep `type: trojan` and append `#fastup` to the password. Only this suffix enables the private key derivation, Chrome default fingerprint and automatic h2mux. The suffix is removed before derivation. `mpw` without `#fastup` never activates FastUP; the node remains standard Trojan.

### Removed additions

The later `type: Blackstone` dynamic-config implementation and OIX Snell sources are removed. The original MG `type: xhttp` implementation above is intentionally retained, as is official standard XHTTP transport.

### Maintained client

The client includes the maintained UI integration and documented private extensions. Custom UI interactions are retained.

### Shanlian AnyTLS

Shanlian mode is explicit: only a valid 64-hex password ending in `#SL` uses the provider-compatible 32-byte preamble. Every unmarked or malformed value follows stock AnyTLS SHA-256 behavior.

```yaml
proxies:
  - name: Shanlian
    type: anytls
    server: 203.0.113.20
    port: 6573
    password: "ACCOUNT32HEX_TICKET28HEX_COUNTER4HEX#SL"
    sni: p3.byteimg.com
    client-fingerprint: chrome
    skip-cert-verify: true
    udp: true
```

For an `anytls://` share link, percent-encode the marker as `%23SL`; the converter also maps `fp=chrome` to `client-fingerprint: chrome`. Marked nodes default to Chrome when that field is omitted. The settings frame uses `client=sing-anytls/0.0.11`; ordinary AnyTLS retains Mihomo's original client metadata.

Because `#` starts a YAML comment, the password must be quoted. A stale provider-issued ticket will authenticate neither direct nor chained nodes.

## Build exactly the two requested targets

Run **Actions → manual-build → Run workflow → both**. The matrix builds only:

- Android arm64-v8a APK (debug-signing fallback when release secrets are absent)
- Windows amd64 portable ZIP (no Inno Setup installer)

The workflow runs source tests first and then scans packaged binaries for all private-protocol markers. Missing linkage fails the build instead of producing a false-success artifact.

## Local verification

```bash
(cd core/Clash.Meta && go test ./transport/anytls/... ./transport/x365 ./transport/blackstonexhttp ./adapter/outbound ./adapter ./common/convert)
(cd core/sing-shadowsocks2-viewturbo && go test ./...)
```

Core implementation details are in [`core/Clash.Meta/docs/private-protocols.md`](core/Clash.Meta/docs/private-protocols.md).
