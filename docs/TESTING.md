# Testing the scanner on macOS

Step-by-step procedure to validate the driver against the real Mustek ScanExpress
A3 USB 1200 Pro on macOS (Apple Silicon or Intel).

## 0. Build the backend (if not already done)

The build produces a self-contained tree in `./sane-install`:

```sh
brew install libusb autoconf automake libtool pkg-config autoconf-archive
./scripts/build-macos.sh
```

> If you previously built into a temp dir that got cleaned, just re-run the script.
> It is idempotent.

Set the install path used by the rest of this guide:

```sh
INST="$PWD/sane-install"
export SANE_CONFIG_DIR="$INST/etc/sane.d"
export DYLD_LIBRARY_PATH="$INST/lib:$INST/lib/sane"
```

## 1. Plug in and power on

Connect the USB cable, power on the scanner, wait ~10 s for the lamp to initialize.
Confirm macOS sees the USB device:

```sh
system_profiler SPUSBDataType | grep -i -A6 mustek
```

Expected: an entry with Vendor `0x055f`, Product `0x040b`. If absent, try another
port/cable and check the power.

## 2. Low-level detection

```sh
"$INST/bin/sane-find-scanner"
```

Expected:

```
found USB scanner (vendor=0x055f, product=0x040b) at ...
```

## 3. SANE detection (loads backend, selects the A3 model)

```sh
"$INST/bin/scanimage" -L
```

Expected:

```
device `mustek_usb2:...' is a Mustek ScanExpress A3 USB 1200 Pro flatbed scanner
```

## 4. Test scan (low resolution first - faster)

```sh
"$INST/bin/scanimage" --format=pnm --resolution 150 > ~/Desktop/test_scan.pnm
```

Open `~/Desktop/test_scan.pnm` in Preview.

## If anything fails: capture a debug log

```sh
export SANE_DEBUG_MUSTEK_USB2=5
"$INST/bin/scanimage" --format=pnm --resolution 150 \
  > ~/Desktop/test_scan.pnm 2> ~/Desktop/scan_debug.log
```

Send / inspect `~/Desktop/scan_debug.log`.

## Interpreting results

| Symptom | Likely cause | Next step |
|---|---|---|
| Correct image | Works | Move to AirSane integration (`docs/MACOS.md`), then upstream MR |
| `Asic_Open: no scanner found` with device plugged | Scanner not powered / not enumerated / held by another process | Re-check step 1; quit Image Capture and any vendor daemon |
| Cannot open USB device | macOS USB permissions | System Settings > Privacy & Security; ensure nothing else holds the device |
| Image wrong width / skewed | A3 sensor wider than the A4 defaults | Tune `wCCDPixelNumber_*` (`mustek_usb2_asic.c`) and `CCD_PIXEL_NUMBER` (`mustek_usb2_asic.h`); see `docs/REVERSE-ENGINEERING.md` |
| Colors / brightness off | AFE gain/offset calibration | Adjust AFE defaults (RE values in `docs/REVERSE-ENGINEERING.md`) |
| First scan fails after long idle | Lamp warming up | Retry once |

## Notes

- Enable backend logging at any time with `export SANE_DEBUG_MUSTEK_USB2=5`.
- `Asic_Open: no scanner found` with the scanner **unplugged** is expected and not an error.
