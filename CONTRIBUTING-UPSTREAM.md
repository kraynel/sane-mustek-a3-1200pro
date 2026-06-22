# Plan to upstream into SANE

This repo is a staging ground. The end goal is to add the Mustek ScanExpress A3 USB
1200 Pro to the upstream SANE `mustek_usb2` backend at
<https://gitlab.com/sane-project/backends>.

## What the patch already does (upstream-friendly)

The patch in `patches/` adds the A3 1200 Pro **alongside** the BearPaw 2448TA Pro, without
removing or breaking the existing model. Concretely:

- `mustek_usb2_asic.c`: replaces the single global `ProductID` with a list of supported
  product IDs (`0x0409`, `0x040b`). `Asic_Open` probes each one; `attach_one_scanner`
  records the matched product ID via `sanei_usb_get_vendor_product_byname` into
  `MustekUSB2_DetectedProductID`.
- `mustek_usb2.c`: adds a second `Scanner_Model` (`mustek_a3_1200pro_model`, A3 bed size,
  same resolutions) and a `mustek_usb2_select_model()` helper that returns the model for the
  detected product ID (falling back to the BearPaw). It is used where the model name and the
  model struct are consumed.
- `doc/descriptions/mustek_usb2.desc`: adds a second `:model` entry with
  `:usbid "0x055f" "0x040b"`, `:status :basic`.

## What still gates a clean merge request

1. **A confirmed real scan.** SANE will not accept `:status :good` without it. This is the
   main blocker. Once validated, bump the `.desc` status.

2. **Per-model CCD geometry, if needed.** The A3 sensor is wider than the A4 BearPaw.
   Upstream uses `wCCDPixelNumber_1200 = 11250`, `wCCDPixelNumber_600 = 7500`
   (`mustek_usb2_asic.c`) and `CCD_PIXEL_NUMBER = 21600` (`mustek_usb2_asic.h`) for the A4.
   If real scans come out wrong-width or skewed, these must become per-model values keyed
   on the detected product ID rather than `#define`s. (The current patch leaves them at the
   A4 values as a starting point.)

3. **Manpage.** Update `doc/sane-mustek_usb2.man` to list the new model.

## Process

1. Validate a real scan on hardware (gating requirement).
2. If geometry is off, parametrize the CCD constants per model and re-test.
3. Rebase onto current upstream, open a merge request on the SANE GitLab. Reference this
   repo and `docs/REVERSE-ENGINEERING.md` for the provenance of the constants.
4. DCO sign-off, GPL-2.0-or-later (matches the backend).

## Provenance / legal

The constants were extracted from the vendor's own binary **for interoperability**, and
re-expressed against the GPL backend they were derived from. The backend is already
GPL-2.0-or-later (Copyright Mustek; Henning Meier-Geinitz). All additions are under the
same license.
