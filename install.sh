#!/usr/bin/env bash
#
# cando1 — server setup.
#
# Installs the cando1 binary, applies the network tuning that the tunnel
# needs, and opens the menu so you can install the license and create the
# tunnel.
#
# The binary is distributed by the publisher, so point this script at it:
#
#   # a file you copied to the server
#   sudo bash install.sh ./cando1-linux-amd64
#
#   # or a URL you were given
#   sudo bash install.sh https://example.com/private/cando1-linux-amd64
#
# It can also pick up the binary sitting next to the script, or one named by
# CANDO1_BINARY. Re-running it upgrades in place.
#
# Knobs:
#   CANDO1_BINARY=path|url   where to get the binary
#   CANDO1_BIN_DIR=/usr/local/bin
#   CANDO1_BBR=0             skip the network tuning
set -euo pipefail

BIN_DIR="${CANDO1_BIN_DIR:-/usr/local/bin}"
BIN="${BIN_DIR}/cando1"
DO_BBR="${CANDO1_BBR:-1}"
SRC="${1:-${CANDO1_BINARY:-}}"
DIST_REPO="${CANDO1_DIST_REPO:-meran77777/cando1-dist}"

C_RESET='\033[0m'; C_G='\033[32m'; C_Y='\033[33m'; C_R='\033[31m'; C_B='\033[1;36m'
info() { printf "${C_B}==>${C_RESET} %s\n" "$*"; }
ok()   { printf "${C_G}  ok${C_RESET} %s\n" "$*"; }
warn() { printf "${C_Y}  ! ${C_RESET} %s\n" "$*" >&2; }
die()  { printf "${C_R}error:${C_RESET} %s\n" "$*" >&2; exit 1; }

SUDO=""
ensure_root() {
  if [ "$(id -u)" -ne 0 ]; then
    command -v sudo >/dev/null 2>&1 || die "run as root, or install sudo"
    SUDO="sudo"
    info "Some steps need root; you may be prompted for your password."
  fi
}

# --- find the binary ---------------------------------------------------------
TMP=""
cleanup() { [ -n "$TMP" ] && rm -f "$TMP" 2>/dev/null || true; }
trap cleanup EXIT

arch_name() {
  case "$(uname -m)" in
    x86_64|amd64)       echo "amd64" ;;
    aarch64|arm64)      echo "arm64" ;;
    armv7l|armv7|armhf) echo "armv7" ;;
    armv6l|armv6)       echo "armv6" ;;
    i386|i686)          echo "386" ;;
    riscv64)            echo "riscv64" ;;
    ppc64le)            echo "ppc64le" ;;
    s390x)              echo "s390x" ;;
    *)                  echo "" ;;
  esac
}

locate_binary() {
  [ "$(uname -s)" = "Linux" ] || warn "this script targets Linux"
  local arch; arch="$(arch_name)"
  [ -n "$arch" ] || warn "unrecognised CPU: $(uname -m)"

  # Nothing given: look beside the script, else download from the release.
  if [ -z "$SRC" ]; then
    local here; here="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
    for cand in "${here}/cando1-linux-${arch}" "${here}/cando1"; do
      if [ -n "$here" ] && [ -f "$cand" ]; then SRC="$cand"; break; fi
    done
  fi
  if [ -z "$SRC" ]; then
    [ -n "$arch" ] || die "unsupported CPU: $(uname -m)"
    SRC="https://github.com/${DIST_REPO}/releases/latest/download/cando1-linux-${arch}"
    info "no binary given; using the latest release"
  fi

  case "$SRC" in
    http://*|https://*)
      command -v curl >/dev/null 2>&1 || die "curl is needed to download the binary"
      info "downloading ${SRC}"
      TMP="$(mktemp)"
      curl -fsSL --retry 3 -o "$TMP" "$SRC" || die "could not download ${SRC}"
      # Verify the checksum when one is published next to the binary.
      if command -v sha256sum >/dev/null 2>&1 \
         && curl -fsSL --retry 3 -o "${TMP}.sha256" "${SRC}.sha256" 2>/dev/null \
         && [ -s "${TMP}.sha256" ]; then
        want="$(awk '{print $1}' "${TMP}.sha256" | head -1)"
        got="$(sha256sum "$TMP" | awk '{print $1}')"
        [ "$want" = "$got" ] || die "checksum mismatch (want $want, got $got) — refusing to install"
        ok "checksum verified"
        rm -f "${TMP}.sha256"
      fi
      SRC="$TMP"
      ;;
    *)
      [ -f "$SRC" ] || die "no such file: $SRC"
      ;;
  esac

  # An HTML error page or a truncated download must not be installed.
  head -c 4 "$SRC" | grep -qa 'ELF' || die "$SRC is not a Linux binary (a download error page?)"
  ok "binary looks valid"
}

install_binary() {
  $SUDO mkdir -p "$BIN_DIR"
  $SUDO install -m 0755 "$SRC" "$BIN"
  ok "installed $BIN"
  # Refuse to continue if it cannot run here (wrong architecture).
  "$BIN" version >/dev/null 2>&1 || die "$BIN will not run on this server — wrong CPU architecture?"
}

# --- network tuning ----------------------------------------------------------
apply_bbr() {
  [ "$DO_BBR" = "1" ] || { warn "skipping network tuning (CANDO1_BBR=0)"; return; }
  [ "$(uname -s)" = "Linux" ] || return 0
  info "enabling BBR congestion control + tuned buffers"
  $SUDO tee /etc/sysctl.d/99-cando1.conf >/dev/null <<'SYSCTL'
# cando1 network tuning
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# Buffers for long, fast links
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.rmem_default = 4194304
net.core.wmem_default = 4194304
net.ipv4.tcp_rmem = 4096 131072 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.udp_rmem_min = 16384
net.ipv4.udp_wmem_min = 16384

# Latency and stability
net.ipv4.tcp_notsent_lowat = 131072
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_fastopen = 3
net.core.netdev_max_backlog = 65536
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
fs.file-max = 2097152
SYSCTL
  $SUDO modprobe tcp_bbr 2>/dev/null || true
  $SUDO sysctl --system >/dev/null 2>&1 || true
  local cc; cc="$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo '?')"
  if [ "$cc" = "bbr" ]; then
    ok "BBR active"
  else
    warn "congestion control is '$cc' (the kernel may be older than 4.9)"
  fi
}

finish() {
  echo
  info "installed:"
  "$BIN" version 2>/dev/null || true
  echo
  echo "  This server's id (needed to get a license):"
  echo "    $("$BIN" id 2>/dev/null || echo '?')"
  echo
  if ! "$BIN" license >/dev/null 2>&1; then
    echo "  Next: send that id to your supplier, then run"
    echo "    cando1 license add <key>"
  fi
  echo "  Then run 'cando1' to create the tunnel."
  echo
  if [ -t 0 ] && [ -t 1 ]; then
    cleanup
    exec "$BIN"
  fi
}

main() {
  info "cando1 setup"
  ensure_root
  locate_binary
  install_binary
  apply_bbr
  finish
}

main "$@"
