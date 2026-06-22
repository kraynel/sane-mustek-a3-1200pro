# Using the scanner on macOS

## 1. Build the backend

```sh
brew install libusb autoconf automake libtool pkg-config autoconf-archive
./scripts/build-macos.sh
```

This produces a self-contained tree in `./sane-install`.

## 2. Command-line scanning

```sh
export SANE_CONFIG_DIR="$PWD/sane-install/etc/sane.d"
export DYLD_LIBRARY_PATH="$PWD/sane-install/lib:$PWD/sane-install/lib/sane"

./sane-install/bin/sane-find-scanner        # expect: found USB scanner 0x055f:0x040b
./sane-install/bin/scanimage -L             # expect: ScanExpress A3 USB 1200 Pro
./sane-install/bin/scanimage --format=pnm --resolution 300 > test.pnm
```

### USB permissions

macOS may require the process to be allowed to access the USB device. If `sane-find-scanner`
sees the device but `scanimage` cannot open it, check that nothing else (Image Capture,
a vendor daemon) is holding the device, and that your terminal has been granted the needed
access under System Settings > Privacy & Security.

## 3. Native integration via AirSane (optional)

[AirSane](https://github.com/SimulPiscator/AirSane) publishes SANE scanners over Apple
AirScan, so the device shows up in **Image Capture**, **Preview**, and the system scan UI
without using the command line.

Point AirSane at the SANE install built here (set `SANE_CONFIG_DIR` /
`DYLD_LIBRARY_PATH` as above so it loads this backend), then run the AirSane server.
See the AirSane macOS README for the launchd/service setup.

## Troubleshooting

- Enable backend logging: `export SANE_DEBUG_MUSTEK_USB2=5` before `scanimage`.
- `Asic_Open: no scanner found` with the scanner unplugged is expected.
- Wrong image width / skew at a given resolution usually means the CCD pixel-count
  constants need tuning for the A3 sensor - see `docs/REVERSE-ENGINEERING.md`, "Open items".
