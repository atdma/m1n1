#!/bin/sh
# Host-side helper for catching an Apple Silicon target in m1n1 proxy mode.
# Intended to run on a second Mac or Linux host, not on the target being booted.

set -eu

MODE="${MODE:-shell}"
M1N1_DIR="${M1N1_DIR:-$PWD/m1n1}"
IMAGE="${IMAGE:-$PWD/Image.gz}"
DTB="${DTB:-$PWD/t6040-j614s.dtb}"
BOOTARGS="${BOOTARGS:-earlycon console=ttySAC0,1500000 debug loglevel=8 initcall_debug root=/dev/ram0 rdinit=/init}"
PYTHON="${PYTHON:-python3}"
BAUD="${BAUD:-500000}"
HOST_OS="$(uname -s)"

find_proxy_dev() {
    if [ -n "${M1N1DEVICE:-}" ] && [ -e "$M1N1DEVICE" ]; then
        printf '%s\n' "$M1N1DEVICE"
        return 0
    fi

    case "$HOST_OS" in
        Darwin)
            candidates="/dev/cu.usbmodemP_01 /dev/cu.usbmodem*_01 /dev/cu.usbmodem*"
            ;;
        Linux)
            candidates="/dev/ttyACM0 /dev/ttyACM2 /dev/ttyACM*"
            ;;
        *)
            candidates="/dev/cu.usbmodemP_01 /dev/cu.usbmodem*_01 /dev/cu.usbmodem* /dev/ttyACM0 /dev/ttyACM2 /dev/ttyACM*"
            ;;
    esac

    for dev in $candidates; do
        if [ -e "$dev" ]; then
            printf '%s\n' "$dev"
            return 0
        fi
    done
    return 1
}

find_secondary_dev() {
    if [ -n "${M1N1SECDEVICE:-}" ] && [ -e "$M1N1SECDEVICE" ]; then
        printf '%s\n' "$M1N1SECDEVICE"
        return 0
    fi

    case "$HOST_OS" in
        Darwin)
            candidates="/dev/cu.usbmodemP_03 /dev/cu.usbmodem*_03"
            ;;
        Linux)
            candidates="/dev/ttyACM1 /dev/ttyACM3"
            ;;
        *)
            candidates="/dev/cu.usbmodemP_03 /dev/cu.usbmodem*_03 /dev/ttyACM1 /dev/ttyACM3"
            ;;
    esac

    for dev in $candidates; do
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

printf 'Host OS: %s\n' "$HOST_OS"
printf 'Waiting for m1n1 USB proxy device on this host...\n'
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
    if [ "$HOST_OS" = "Darwin" ] && command -v osascript >/dev/null 2>&1 && command -v screen >/dev/null 2>&1; then
        printf 'Opening secondary console in a new Terminal window via screen...\n'
        osascript -e "tell application \"Terminal\" to do script \"screen $secondary_dev $BAUD\""
    elif command -v screen >/dev/null 2>&1; then
        printf 'Open a second terminal and run:\n'
        printf '  screen %s %s\n' "$secondary_dev" "$BAUD"
    elif command -v picocom >/dev/null 2>&1; then
        printf 'Open a second terminal and run:\n'
        printf '  picocom --omap crlf --imap lfcrlf -b %s %s\n' "$BAUD" "$secondary_dev"
    else
        printf 'screen/picocom not found; skipping secondary console helper.\n'
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
