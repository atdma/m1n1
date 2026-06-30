# M4 Pro m1n1 host debug kit

This directory is for catching the `Mac16,8` / `J614sAP` M4 Pro diagnostic boot in `m1n1` proxy mode from a second Mac.

The target Mac's diagnostic ESP has been changed so `m1n1/boot-linux-direct.bin` is now proxy-only m1n1, not the direct Linux payload. The expected next boot is therefore `m1n1` proxy mode, not Linux.

## Files

- `host-m1n1-catch-and-boot.sh`: host-side helper script.
- `Image.gz`: diagnostic Linux kernel image.
- `t6040-j614s.dtb`: matching M4 Pro/J614s device tree.

## Hardware setup

1. Use a second Mac as the host.
2. Shut down the M4 target Mac.
3. Connect host and target with a data-capable USB-C cable.
4. Use a Thunderbolt/USB-C port on the M4 target.
5. Keep the target connected to power if possible.

## Prepare the host Mac

Clone this repo on the second Mac:

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

## First test: catch m1n1 proxy shell

Run this on the host Mac:

```sh
cd m1n1
M1N1_DIR="$PWD" MODE=shell ./host-m4pro-debug/host-m1n1-catch-and-boot.sh
```

The script will wait for `/dev/cu.usbmodem*`.

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

To open the secondary m1n1 console in another Terminal window:

```sh
cd m1n1
M1N1_DIR="$PWD" OPEN_SECONDARY_CONSOLE=1 MODE=shell ./host-m4pro-debug/host-m1n1-catch-and-boot.sh
```

## Second test: boot Linux tethered

Only do this after `MODE=shell` works.

Run this on the host Mac:

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

## If no USB device appears

On the host Mac, check:

```sh
ls /dev/cu.usbmodem*
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
