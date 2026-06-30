# M4 Pro m1n1 host debug kit

This directory is for catching the `Mac16,8` / `J614sAP` M4 Pro diagnostic boot in `m1n1` proxy mode from a second Mac or Linux host.

The target Mac's diagnostic ESP has been changed so `m1n1/boot-linux-direct.bin` is now proxy-only m1n1, not the direct Linux payload. The expected next boot is therefore `m1n1` proxy mode, not Linux.

## Files

- `host-m1n1-catch-and-boot.sh`: host-side helper script.
- `Image.gz`: diagnostic Linux kernel image.
- `t6040-j614s.dtb`: matching M4 Pro/J614s device tree.

## Hardware setup

1. Use a second Mac or Linux machine as the host.
2. Shut down the M4 target Mac.
3. Connect host and target with a data-capable USB-C cable.
4. Use a Thunderbolt/USB-C port on the M4 target.
5. Keep the target connected to power if possible.

## Prepare the host

Clone this repo on the host:

```sh
git clone https://github.com/atdma/m1n1.git
cd m1n1
```

If Python dependencies are missing, install the proxyclient requirements:

```sh
python3 -m pip install --user -r proxyclient/requirements.txt
```

Make the helper executable:

```sh
chmod +x host-m4pro-debug/host-m1n1-catch-and-boot.sh
```

On Linux, if `/dev/ttyACM*` exists but the script cannot open it, add your user
to the relevant serial device group or run the helper with `sudo -E`. Common
groups are `dialout`, `uucp`, or `plugdev`.

## First test: catch m1n1 proxy shell

Run this on the host:

```sh
cd m1n1
M1N1_DIR="$PWD" MODE=shell ./host-m4pro-debug/host-m1n1-catch-and-boot.sh
```

The script will wait for the m1n1 USB serial device. For a bounded diagnostic
retry with periodic status output, use:

```sh
M1N1_DIR="$PWD" WAIT_TIMEOUT=120 WAIT_LOG_INTERVAL=5 MODE=shell \
  ./host-m4pro-debug/host-m1n1-catch-and-boot.sh
```

Expected device names:

- macOS: `/dev/cu.usbmodemP_01` and `/dev/cu.usbmodemP_03`
- Linux: `/dev/ttyACM0` and `/dev/ttyACM1`

If auto-detection picks the wrong device, set it explicitly:

```sh
M1N1DEVICE=/dev/ttyACM0 M1N1SECDEVICE=/dev/ttyACM1 \
M1N1_DIR="$PWD" MODE=shell ./host-m4pro-debug/host-m1n1-catch-and-boot.sh
```

Now boot the target Mac:

1. Hold power until Startup Options appears.
2. Select `M4 Pro Linux diagnostic`.
3. Boot it.

Expected host-side result:

```text
Proxy device: /dev/cu.usbmodemP_01
Mode: shell
Starting m1n1 proxy shell.
```

Exit the shell with `Ctrl-D`.

## Optional secondary console

To open or print instructions for the secondary m1n1 console:

```sh
cd m1n1
M1N1_DIR="$PWD" OPEN_SECONDARY_CONSOLE=1 MODE=shell ./host-m4pro-debug/host-m1n1-catch-and-boot.sh
```

## Second test: boot Linux tethered

Only do this after `MODE=shell` works.

Run this on the host:

```sh
cd m1n1
M1N1_DIR="$PWD" \
IMAGE="$PWD/host-m4pro-debug/Image.gz" \
DTB="$PWD/host-m4pro-debug/t6040-j614s.dtb" \
MODE=linux \
./host-m4pro-debug/host-m1n1-catch-and-boot.sh
```

Then boot the target into `M4 Pro Linux diagnostic` again.

The helper runs:

```sh
python3 proxyclient/tools/linux.py \
  host-m4pro-debug/Image.gz \
  host-m4pro-debug/t6040-j614s.dtb \
  -b 'earlycon console=ttySAC0,1500000 debug loglevel=8 initcall_debug root=/dev/ram0 rdinit=/init'
```

## Linux host notes

Install dependencies with your distro package manager if needed:

```sh
sudo apt install python3 python3-pip git screen
```

or:

```sh
sudo dnf install python3 python3-pip git screen
```

Then install Python requirements:

```sh
python3 -m pip install --user -r proxyclient/requirements.txt
```

If permissions block `/dev/ttyACM0`, either run:

```sh
sudo -E M1N1_DIR="$PWD" MODE=shell ./host-m4pro-debug/host-m1n1-catch-and-boot.sh
```

or add your user to the serial device group and log out/in:

```sh
sudo usermod -aG dialout "$USER"
```

## If no USB device appears

On macOS, check:

```sh
ls /dev/cu.usbmodem*
```

On Linux, check:

```sh
ls /dev/ttyACM*
dmesg | tail -50
```

If nothing appears:

1. Try a different USB-C cable.
2. Try a different USB-C/TB port on the target.
3. Confirm the target booted `M4 Pro Linux diagnostic`, not macOS.
4. Wait 20-30 seconds after selecting the diagnostic entry.
5. If the target still bootloops with no USB device, m1n1 may be crashing before USB proxy setup.

## Results to record

Record which case happened:

1. `MODE=shell` works and gives a m1n1 shell.
2. USB modem devices appear, but `shell.py` errors.
3. No USB modem devices appear and the target still bootloops.
4. `MODE=linux` starts printing kernel logs.
5. `MODE=linux` reboots or hangs, with the last visible log line.
