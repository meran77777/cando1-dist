# cando1

Prebuilt binaries and the installer for **cando1** — a high-performance,
DPI-resistant tunnel. The source is proprietary and is not published here;
this repository only distributes the ready-to-run binaries.

Each server needs its own license. See **License** below.

## Install

On the server (Ubuntu/Debian, any CPU), as root:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/meran77777/cando1-dist/main/install.sh)
```

This downloads the binary for the server's architecture from the latest
release, installs it to `/usr/local/bin/cando1`, applies the network tuning,
and opens the menu.

Re-running it upgrades in place.

## License

Use requires a valid license issued for the specific server. On the server:

```bash
cando1 id                     # prints this server's id
```

Send that id to your supplier to receive a license key, then:

```bash
cando1 license add <key>
```

The tunnel will not start without a valid license.

## Manual download

Grab the binary for your architecture from the
[latest release](https://github.com/meran77777/cando1-dist/releases/latest),
verify its `.sha256`, and install it:

```bash
install -m 0755 cando1-linux-amd64 /usr/local/bin/cando1
```
