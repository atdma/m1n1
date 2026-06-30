#!/bin/sh
# Host-side helper for catching an Apple Silicon target in m1n1 proxy mode.
# Intended to run on the second Mac, not on the target being booted.

set -eu

MODE="${MODE:-shell}"
M1N1_DIR="${M1N1_DIR:-$PWD/m1n1}"
IMAGE="${IMAGE:-$PWD/Image.gz}"
DTB="${DTB:-$PWD/t6040-j614s.dtb}"
BOOTARGS="${BOOTARGS:-earlycon console=ttySAC0,1500000 debug loglevel=8 initcall_debug root=/dev/ram0 rdinit=/init}"
PYTHON="${PYTHON:-python3}"
BAUD="${BAUD:-500000}"

find_proxy_dev() {
    for dev in /dev/cu.usbmodemP_01 /dev/cu.usbmodem*_01 /dev/cu.usbmodem*; do
        if [ -e "$dev" ]; then
            printf '%s\n' "$dev"
            return 0
        fi
    done
    return 1
}

find_secondary_dev() {
    for dev in /dev/cu.usbmodemP_03 /dev/cu.usbmodem*_03; do
        if [ -e "$dev" ]; then
            printf '%s\n' "$dev"
            return 0
        fi
    done
    return 1
}

if [ ! -d "$M1N1_DIR/proxyclient/tools" ]; then
    printf 'Missing m1n1 proxy tools: %s/proxyclient/tools\n' "$M1N1_DIR" >&2
    printf 'Set M1N1_DIR=/path/to/m1n1 or run from a directory containing ./m1n1.\n' >&2
    exit 1
fi

case "$MODE" in
    shell|linux)
        ;;
    *)
        printf 'MODE must be shell or linux, got: %s\n' "$MODE" >&2
        exit 1
        ;;
esac

if [ "$MODE" = "linux" ]; then
    if [ ! -f "$IMAGE" ]; then
        printf 'Missing Image.gz: %s\n' "$IMAGE" >&2
        exit 1
    fi
    if [ ! -f "$DTB" ]; then
        printf 'Missing DTB: %s\n' "$DTB" >&2
        exit 1
    fi
fi

printf 'Waiting for m1n1 USB proxy device on this host Mac...\n'
printf 'Boot the target Mac into the M4 Pro Linux diagnostic entry now.\n'
printf 'Press Ctrl-C here to stop waiting.\n\n'

proxy_dev=""
while [ -z "$proxy_dev" ]; do
    if proxy_dev="$(find_proxy_dev)"; then
        break
    fi
    sleep 1
done

secondary_dev=""
if secondary_dev="$(find_secondary_dev)"; then
    printf 'Secondary console candidate: %s\n' "$secondary_dev"
else
    printf 'Secondary console candidate: not found yet\n'
fi

printf 'Proxy device: %s\n' "$proxy_dev"
printf 'Mode: %s\n' "$MODE"

if [ "${OPEN_SECONDARY_CONSOLE:-0}" = "1" ] && [ -n "$secondary_dev" ]; then
    if command -v screen >/dev/null 2>&1; then
        printf 'Opening secondary console in a new Terminal window via screen...\n'
        osascript -e "tell application \"Terminal\" to do script \"screen $secondary_dev $BAUD\""
    else
        printf 'screen not found; skipping secondary console.\n'
    fi
fi

export M1N1DEVICE="$proxy_dev"

if [ "$MODE" = "shell" ]; then
    printf '\nStarting m1n1 proxy shell. Exit with Ctrl-D.\n\n'
    exec "$PYTHON" "$M1N1_DIR/proxyclient/tools/shell.py"
fi

printf '\nBooting Linux through m1n1 proxy.\n'
printf 'Image: %s\n' "$IMAGE"
printf 'DTB: %s\n' "$DTB"
printf 'Bootargs: %s\n\n' "$BOOTARGS"

exec "$PYTHON" "$M1N1_DIR/proxyclient/tools/linux.py" \
    "$IMAGE" \
    "$DTB" \
    -b "$BOOTARGS"
