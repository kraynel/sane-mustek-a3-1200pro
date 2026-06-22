# SANE driver for the Mustek ScanExpress A3 USB 1200 Pro

A SANE backend patch that adds support for the **Mustek ScanExpress A3 USB 1200 Pro**
flatbed scanner (USB ID `055f:040b`, SQ113 chipset), with build instructions for
**modern macOS** (Apple Silicon / Intel) where the scanner has had no working driver
for over a decade.

> Status: **experimental**. The driver builds and loads as a native SANE backend.
> Hardware acquisition is being validated. See [Status](#status) below.

## Why this exists

The A3 USB 1200 Pro lost vendor driver support years ago. The proprietary macOS
driver shipped only `ppc`/`i386` binaries, which cannot run on any macOS release since
Catalina (no 32-bit / PPC runtime). The official SANE `mustek_usb2` backend targets the
same SQ113 chip but only declares the Mustek BearPaw 2448TA Pro (`055f:0409`).

This project reverse-engineered the vendor's Linux SANE backend (a Mustek-modified
`mustek_usb2` that already contained the A3 parameters) to extract the device-specific
constants, and applies them to the current upstream `mustek_usb2` backend. The full
reverse-engineering write-up is in [`docs/REVERSE-ENGINEERING.md`](docs/REVERSE-ENGINEERING.md).

## What this repo contains

- `patches/` - a patch against upstream `sane-backends` adding the A3 1200 Pro.
- `scripts/build-macos.sh` - one-shot build of a patched SANE on macOS (Homebrew).
- `docs/` - the reverse-engineering notes and the extracted hardware parameters.

It does **not** vendor a copy of the SANE source. You build against upstream
`sane-backends` with the patch applied.

## Quick start (macOS)

```sh
# Prerequisites (Homebrew)
brew install libusb autoconf automake libtool pkg-config autoconf-archive

# Build a patched SANE into ./sane-install
./scripts/build-macos.sh

# Plug in and power on the scanner, then:
./sane-install/bin/sane-find-scanner          # should show 0x055f:0x040b
./sane-install/bin/scanimage -L               # should list "ScanExpress A3 USB 1200 Pro"
./sane-install/bin/scanimage --format=pnm > test.pnm
```

Full step-by-step test procedure: [`docs/TESTING.md`](docs/TESTING.md).
To expose the scanner to native macOS apps (Image Capture, Preview) over AirScan,
see [`docs/MACOS.md`](docs/MACOS.md).

## Linux

The same patch applies to upstream `sane-backends` on Linux. Apply
`patches/0001-add-mustek-a3-usb-1200-pro.patch`, then build SANE as usual.
The reverse-engineered vendor backend was originally a Linux `.deb`, so Linux is the
lowest-risk target.

## Status

| Item | State |
|---|---|
| Backend builds (arm64 macOS) | done |
| Backend loads / initializes under SANE | done |
| USB enumeration of `055f:040b` | done (logic), pending real device |
| Dual-model support (keeps BearPaw 2448TA) | **done** - detects PID, selects model |
| Real scan (image acquisition) | **pending hardware validation** |
| Color / resolution calibration | pending |

## Relationship to upstream SANE

The goal is to upstream this into the SANE project once validated on real hardware.
This repo is the staging ground: it documents the work and lets owners of the scanner
use it today. See [`CONTRIBUTING-UPSTREAM.md`](CONTRIBUTING-UPSTREAM.md) for the plan
to turn this into a clean merge request.

## License

GPL-2.0-or-later, matching the SANE `mustek_usb2` backend it derives from. See
[`COPYING`](COPYING).

The `mustek_usb2` backend is:
- Copyright (C) 2000-2005 Mustek.
- Copyright (C) 2001-2005 Henning Meier-Geinitz.

The A3 1200 Pro additions in this repo are contributed under the same license.
