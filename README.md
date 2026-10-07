<p align="center">
  <img src="assets/logo.svg" alt="cando1" width="160">
</p>

<h1 align="center">cando1</h1>

<p align="center">
  <b>A fast, stable, DPI-resistant tunnel between two servers — with a guided setup and built-in service management.</b>
</p>

<p align="center">
  <a href="https://t.me/cando1tunnel">📣 t.me/cando1tunnel</a> ·
  <a href="#english">English</a> · <a href="#فارسی">فارسی</a> ·
  <a href="LICENSE">License</a>
</p>

---

<a id="english"></a>

## Install

This is commercial software: the binary is distributed by the publisher and
a license is needed for the server users connect to (usually the Iran server).

On each server (Ubuntu/Debian, any architecture):

```bash
curl -fsSL https://raw.githubusercontent.com/meran77777/cando1-dist/main/install.sh | sudo bash
```

The installer downloads the prebuilt binary from
[cando1-dist](https://github.com/meran77777/cando1-dist) (checksum verified),
enables BBR and the low-latency network settings, and prints the server ID
needed for the license.
Re-running it upgrades in place.

### Manual download

Grab the binary for your architecture from the
[latest release](https://github.com/meran77777/cando1-dist/releases/latest),
verify its `.sha256`, and install it:

```bash
install -m 0755 cando1-linux-amd64 /usr/local/bin/cando1
```

## License

Only the server users connect to needs a license, valid for a set period:
the one with the public ports or the VPN gateway, usually the Iran server.
The other side (abroad) needs none, so it can be replaced at any time, and
one licensed Iran server can connect to any number of abroad servers. The
rule follows what a server does, not how it is labelled. On the Iran server:

```bash
cando1 id            # prints this server's id, e.g. ASE2-YTWF-TF6R-7WUH
```

Send that id to the publisher, who issues a license key for it, then:

```bash
cando1 license add CANDO1-...
cando1 license       # shows what it covers and when it expires
```

A license is tied to the one server it was issued for and stops working when
it expires; the tunnel will not start without a valid one, and warns for the
last week before expiry. The key is checked offline, so no license server
has to be reachable. It is stored at `/etc/cando1/license.key`, or set
`CANDO1_LICENSE` in the environment instead.

If a server's clock is badly wrong the license can look expired — see the
clock note under Diagnostics.

## Set up a tunnel in two steps

**1. On either server**, run `cando1` and choose **New tunnel**. Six short
questions: where this server is (Iran / abroad), which side connects,
transport, ports, and the address. Everything else has good defaults.

```
  ╭──────────────────────────────────────────────────────────────╮
  │  CANDO1  ·  tunnel manager                             v2.0  │
  ╰──────────────────────────────────────────────────────────────╯
   host 203.0.113.7  ·  tunnels run as systemd services

  ── Tunnels ─────────────────────────────────────────────────────
   ● ir-tls-443    Iran   tls  listen :443        3 link(s) · ping 41 ms

   1  New tunnel      guided setup in six short steps
   2  Import key      set up this server from a connection key
   3  Manage tunnels  status · logs · ports · restart · delete
   4  Tools           network tuning · connection test · token
   5  Help            how the tunnel works
```

**2. On the other server**, paste the one-line key it prints:

```bash
cando1 import cando1://eyJtIjoicmV2ZXJzZSIs...
```

That's all. Both configs come from the same key, so tokens, transports and
ports can never mismatch. The tunnel is installed as a system service: it
starts on boot, reconnects by itself, and restarts if anything fails.

## How it works

Users connect to a port on the **Iran** server (entry) and arrive at the same
port on the **abroad** server (exit), e.g. your Xray/V2Ray inbound.

| Direction | Who connects | When to use |
|---|---|---|
| **Reverse** *(recommended)* | abroad → Iran | Iran only listens; robust on most networks |
| **Direct** | Iran → abroad | when outgoing connections from Iran work better |

Ports are always managed on the Iran server. Adding a port there needs no
change on the abroad server.

Port syntax: `443`, `443,8443`, `2080-2090`, `8443=443` (Iran 8443 → abroad
443), `2053=10.0.0.5:2053` (another host). UDP ports (WireGuard, Hysteria,
OpenVPN-UDP, DNS) are supported over every transport.

## VPN gateway (Cisco / OpenVPN on the Iran server)

When a VPN such as Cisco AnyConnect (ocserv) runs on the Iran server — for
example because its RADIUS is reachable only from inside Iran — choose
**VPN users' internet** in step 4 of the setup. The VPN keeps running on the
Iran server exactly as it is: users still connect to it there, and login
(RADIUS), accounting and client IPs are unchanged. Only its users' internet
traffic (TCP and UDP, including DNS) goes through the tunnel and leaves from the
abroad server.

| VPN | Interfaces |
|---|---|
| Cisco AnyConnect (ocserv) | `vpns+` |
| OpenVPN | `tun+` |
| WireGuard | `wg+` |
| L2TP / PPTP | `ppp+` |

Traffic to private addresses and to the Iran server itself stays local. Linux
only; needs `iptables` and `iproute2` on the Iran server (the rules are added
when the tunnel starts and removed when it stops). Give the VPN a public DNS
server (for ocserv: `dns = 1.1.1.1`) so name lookups also go abroad.

## Transports

| | Best for |
|---|---|
| **TLS** | Default. Browser-identical TLS handshake (uTLS). Balanced speed and stealth. |
| **KCP** | Lowest ping and best speed on lossy links (UDP + forward error correction). Needs UDP between the servers. |
| **WSS** | WebSocket over TLS — put the abroad server behind Cloudflare. |
| **WS** | Plain WebSocket, for a CDN that terminates TLS. |
| **TCP** | Raw TCP with obfuscation. Least overhead. |

## Speed, ping and stability

- **Heartbeat + fast failover.** Every link is pinged twice a second. A link that
  goes silent (a path that drops packets without closing) is replaced within
  ~12 s instead of the minutes TCP would take. Busy links are never mistaken
  for dead ones.
- **Load-aware link selection.** Each new connection goes to the least busy
  link; a link with clearly degraded latency is avoided. A large download on
  one link does not raise the ping of connections on the others.
- **No queue build-up.** Tunnel sockets limit unsent kernel data
  (`TCP_NOTSENT_LOWAT`), so interactive traffic isn't stuck behind megabytes
  of bulk data. BBR is enabled by the installer (menu: Tools → Optimize network).
- **Zero-RTT streams.** Opening a connection through the tunnel costs no extra
  round trip; many connections share a few long-lived, multiplexed links.
- **UDP without head-of-line blocking.** Each UDP flow has its own queue, so a
  new or slow flow never delays the others.
- **Self-healing.** A public port that is busy doesn't take the tunnel down —
  it is retried every 10 s. If the tunnel itself ever stops, it is restarted
  with backoff; under systemd it also survives crashes and reboots.

Measure it yourself: `cando1 diag` prints throughput, latency, and latency
*while a bulk transfer runs* for your tunnel, and **Tools → Path test**
compares every transport between your two servers.

## Security and anti-probing

- Client-speaks-first handshake with HMAC proofs and no cleartext markers;
  the server stays silent to anyone without the token.
- Mutual authentication: a man-in-the-middle cannot impersonate the server,
  even with a self-signed certificate.
- Replay protection (nonce cache) with a ±5 min clock tolerance.
- Optional `fallback_addr` (tcp/tls): unauthenticated visitors are served by a
  real web server of your choice instead of a silent port.
- In direct mode the abroad server only dials whitelisted targets
  (`127.0.0.1:*` by default).

**Avoiding a filtered IP:** a self-signed certificate on a bare IP is easy to
spot for active probers. On hostile networks, prefer **WSS behind Cloudflare**
(the setup asks, and switches certificate verification on), or a real domain
with a real certificate (`[server.tls] cert/key`).

## Command line

```
cando1                          menu
cando1 import <key> [--name N]  set up this server from a key
cando1 list                     tunnels and their state
cando1 status  <name>           ping, links, traffic, uptime
cando1 start|stop|restart <name>
cando1 logs    <name>
cando1 id                       print this server's id (for a license)
cando1 license [add <key>]      show or install the license
cando1 diag   [name]            diagnostics report (see below)
cando1 run <name> | -c <file>   run in the foreground
cando1 gen-token | version | help
```

### Capacity

Users share a few multiplexed connections (up to 32). Each connection has
one receive budget, and a user whose device stops reading — an app in the
background, a phone that went away — holds part of it until the tunnel gives
up on that user after a minute. The client opens connections as demand grows
and retires the extras when it falls; once all are busy, new users share the
least-loaded one. Well over a hundred users on one connection must stop
reading within the same minute before it stalls, and a stalled connection is
replaced automatically (`cando1 diag` reports it as such, not as a route
problem). Connections that end on either side are released at once on both
servers.

Measured over an emulated 1 Gbit route at 80 ms round trip:

| parallel connections | throughput |
|---|---|
| 1 | 71 Mbit/s |
| 8 | 491 Mbit/s |
| 16 | 1000 Mbit/s |
| 32 | 1920 Mbit/s |

A single connection is limited by its window (`max_stream_buffer`, 768 KB)
over the link's round trip: raising it makes one transfer faster but lets
fewer stalled users fill a connection. Reaching 1 Gbit also needs CPU for
encryption — roughly 2.5 CPU-seconds per GB across both servers, so a 2-core
server will not sustain it.

### Speed control

A speed test or a big download can push a route past what it carries. The
queue that builds up then delays every other user's packets. Automatic speed
control is on by default and prevents this. The tunnel measures its own ping
twice a second. When the ping rises above the route's normal level, it holds
bulk transfers just below the rate that actually gets through, and it lets go
again once the route clears. The first 512 KB of every connection is never
held back, so browsing, chat and games stay fast.

On an emulated 40 Mbit/s route, ping during a download dropped from ~300 ms to
~50 ms, while the download kept ~95% of its speed.

A fixed maximum can be added on top (menu → tunnel → **Speed limit**, or
`max_mbps` in the config). Set it on both servers, since each one limits the
data it sends. `auto_limit = false` turns automatic control off.

### Diagnostics

Run `cando1 diag` on the **tunnel client** (the abroad server in reverse
mode, the Iran server in direct mode). It opens its own test connections
next to the running tunnel and measures both machines at once: idle ping,
throughput in each direction, ping *while* data flows, CPU and TCP
retransmissions on both servers, and kernel network settings. It ends with a
list of findings, including which programs use the CPU and a suggested
speed limit. Paste the whole output when reporting a problem. The other
server must run v2.0.2 or newer.

Tunnels live in `/etc/cando1/tunnels/<name>.toml` (root) or
`~/.config/cando1/tunnels/` (non-root); `CANDO1_HOME` overrides it. Services
are `cando1@<name>` (`journalctl -u cando1@<name>`). Without systemd, tunnels
run as background processes with a self-rotating log.

Configs are plain TOML files and can be edited by hand. Unknown keys are
reported as warnings so typos don't go unnoticed. Configs from older versions
keep working.

---

<a id="فارسی"></a>

<div dir="rtl">

# cando1 — تونل سریع، پایدار و ضد DPI

📣 کانال اطلاع‌رسانی: [t.me/cando1tunnel](https://t.me/cando1tunnel)

## نصب

روی هر دو سرور (اوبونتو/دبیان، هر معماری):

</div>

```bash
curl -fsSL https://raw.githubusercontent.com/meran77777/cando1-dist/main/install.sh | sudo bash
```

<div dir="rtl">

نصب‌کننده نسخهٔ آمادهٔ برنامه را (با بررسی checksum) دانلود می‌کند، BBR و تنظیمات کم‌تأخیر شبکه را فعال می‌کند و منو را باز می‌کند.

## لایسنس

فقط سروری که کاربران به آن وصل می‌شوند لایسنس می‌خواهد، یعنی سروری که پورت‌ها یا گیت‌وی VPN روی آن است؛ معمولاً **سرور ایران**. سرور خارج لایسنس لازم ندارد، پس هر وقت خواستید عوضش کنید؛ با یک لایسنس ایران به هر تعداد سرور خارج وصل شوید. روی سرور ایران:

</div>

```bash
cando1 id                      # شناسهٔ سرور برای خرید لایسنس
cando1 license add CANDO1-...  # نصب لایسنس
cando1 license                 # وضعیت و تاریخ انقضا
```

<div dir="rtl">

## راه‌اندازی تونل در دو قدم

**۱. روی یکی از سرورها** دستور `cando1` را بزنید و **New tunnel** را انتخاب کنید. فقط شش سؤال کوتاه: این سرور کجاست (ایران / خارج)، کدام طرف وصل می‌شود، نوع ترنسپورت، پورت‌ها و آدرس. بقیه تنظیمات پیش‌فرض مناسب دارند.

**۲. روی سرور دیگر** کلید یک‌خطی‌ای را که چاپ شده وارد کنید:

</div>

```bash
cando1 import cando1://eyJtIjoicmV2ZXJzZSIs...
```

<div dir="rtl">

تمام. هر دو کانفیگ از همان یک کلید ساخته می‌شوند، پس توکن، ترنسپورت و پورت‌ها هیچ‌وقت ناهماهنگ نمی‌شوند. تونل به‌صورت سرویس سیستم نصب می‌شود: با بالا آمدن سرور اجرا می‌شود، خودش دوباره وصل می‌شود و در صورت هر خطا ری‌استارت می‌شود.

## نحوهٔ کار

کاربران به پورتی روی سرور **ایران** وصل می‌شوند و به همان پورت روی سرور **خارج** (مثلاً اینباند Xray) می‌رسند.

- **Reverse (پیشنهادی):** سرور خارج به ایران وصل می‌شود؛ ایران فقط گوش می‌دهد.
- **Direct:** سرور ایران به خارج وصل می‌شود.

پورت‌ها همیشه روی سرور ایران مدیریت می‌شوند و اضافه کردن پورت نیازی به تغییر روی سرور خارج ندارد.

نوشتن پورت‌ها: `443` ، `443,8443` ، `2080-2090` ، `8443=443` (پورت 8443 ایران ← 443 خارج). پورت‌های UDP (وایرگارد، Hysteria، OpenVPN-UDP، DNS) روی همهٔ ترنسپورت‌ها پشتیبانی می‌شوند.

## گیت‌وی VPN (سیسکو / OpenVPN روی سرور ایران)

اگر یک VPN مثل سیسکو (ocserv) روی سرور ایران اجرا می‌شود (مثلاً چون رادیوس فقط از داخل ایران در دسترس است)، در قدم ۴ راه‌اندازی گزینهٔ **VPN users' internet** را انتخاب کنید. خود VPN بدون هیچ تغییری روی ایران می‌ماند: کاربرها همان‌جا وصل می‌شوند و لاگین (رادیوس)، حساب‌داری مصرف و IP کاربرها دست نمی‌خورد. فقط ترافیک اینترنت کاربرها (TCP و UDP، از جمله DNS) از تونل می‌گذرد و از سرور خارج بیرون می‌رود.

اینترفیس‌ها: سیسکو `vpns+` ، OpenVPN `tun+` ، وایرگارد `wg+` ، L2TP/PPTP `ppp+`.

ترافیک به آدرس‌های خصوصی و به خود سرور ایران محلی می‌ماند. فقط لینوکس؛ روی سرور ایران `iptables` و `iproute2` لازم است (قوانین با روشن شدن تونل اضافه و با خاموش شدن حذف می‌شوند). DNS کاربرها را یک DNS عمومی بگذارید (در ocserv: `dns = 1.1.1.1`) تا جست‌وجوی نام‌ها هم از خارج انجام شود.

## ترنسپورت‌ها

- **TLS:** پیش‌فرض؛ دست‌دهی TLS دقیقاً مثل مرورگر. تعادل سرعت و پنهان‌کاری.
- **KCP:** کمترین پینگ و بیشترین سرعت روی لینک‌های پرافت (UDP + تصحیح خطا). نیاز به باز بودن UDP بین دو سرور.
- **WSS:** وب‌سوکت روی TLS؛ برای قرار دادن سرور خارج پشت کلادفلر.
- **WS:** وب‌سوکت ساده، برای CDN ای که TLS را خودش انجام می‌دهد.
- **TCP:** TCP خام با مبهم‌سازی؛ کمترین سربار.

## سرعت، پینگ و پایداری

- **ضربان (heartbeat) و جایگزینی سریع:** هر لینک هر ۲ ثانیه پینگ می‌شود. لینکی که بی‌صدا قطع شده باشد ظرف حدود ۱۲ ثانیه جایگزین می‌شود، نه چند دقیقه.
- **انتخاب هوشمند لینک:** هر اتصال جدید روی کم‌بارترین لینک می‌رود و لینکی که تأخیرش به‌وضوح بد شده کنار گذاشته می‌شود؛ یک دانلود سنگین پینگ بقیه را بالا نمی‌برد.
- **بدون صف‌شدن داده:** داده‌های ارسال‌نشده در کرنل محدود می‌شوند تا ترافیک تعاملی پشت دانلودها گیر نکند. BBR هم فعال می‌شود.
- **UDP بدون گیر کردن جریان‌ها:** هر جریان UDP صف جداگانه دارد.
- **خودترمیم:** اگر یک پورت عمومی اشغال باشد کل تونل از کار نمی‌افتد و آن پورت هر ۱۰ ثانیه دوباره امتحان می‌شود. اگر تونل متوقف شود خودکار دوباره اجرا می‌شود.

## جلوگیری از فیلتر شدن آی‌پی

گواهی self-signed روی آی‌پی خالی برای پروب‌های فعال قابل تشخیص است. در شبکه‌های سخت‌گیر از **WSS پشت کلادفلر** استفاده کنید (در مراحل راه‌اندازی پرسیده می‌شود) یا دامنه و گواهی واقعی بگذارید. گزینهٔ `fallback_addr` هم بازدیدکننده‌های ناشناس را به یک وب‌سرور واقعی می‌فرستد.

## دستورات

</div>

```
cando1                          منو
cando1 import <key>             راه‌اندازی این سرور با کلید
cando1 list                     فهرست تونل‌ها و وضعیت
cando1 status  <name>           پینگ، لینک‌ها، ترافیک
cando1 start|stop|restart <name>
cando1 logs    <name>
```

<div dir="rtl">

کانفیگ‌ها در مسیر `/etc/cando1/tunnels/` ذخیره می‌شوند و سرویس هر تونل `cando1@<name>` است.

</div>

## License

Proprietary. Use requires a valid per-server license key — see [LICENSE](LICENSE)
and the **License** section above.
