# Plan to upstream into SANE

This repo is a staging ground. The end goal is to add the Mustek ScanExpress A3 USB
1200 Pro to the upstream SANE `mustek_usb2` backend at
<https://gitlab.com/sane-project/backends>.

## Why the current patch is not yet upstream-ready

The patch in `patches/` takes the minimal route: it **repurposes** the single hard-coded
model (`mustek_A2nu2_model`) and the global `ProductID` from the BearPaw 2448TA Pro to the
A3 1200 Pro. That is fine for a dedicated build, but upstream must keep supporting the
BearPaw. A clean contribution needs **dual-model support**.

## Required changes for a clean merge request

1. **Keep both ProductIDs.** `attach_one_scanner` / `Asic_Open` in `mustek_usb2_asic.c`
   currently calls `sanei_usb_find_devices(VendorID, ProductID, ...)` with a single global
   `ProductID = 0x0409`. Make it probe both `0x0409` and `0x040b` (loop or two calls), and
   remember which one matched.

2. **Two `Scanner_Model` instances.** Add a `mustek_a3_1200pro_model` next to
   `mustek_A2nu2_model` in `mustek_usb2.c`, differing in:
   - `model` string,
   - `x_size` / `y_size` (A3 297x420 mm vs A4),
   - resolutions are identical (75-1200), confirmed by RE.
   Select the right one when copying into `s->model` (currently `mustek_usb2.c:~2103`),
   based on the matched ProductID.

3. **CCD geometry per model.** The A3 sensor is wider than the A4 BearPaw. Once validated,
   parametrize `wCCDPixelNumber_1200` / `wCCDPixelNumber_600` (`mustek_usb2_asic.c:~2256`)
   and `CCD_PIXEL_NUMBER` (`mustek_usb2_asic.h:~350`) per model rather than `#define`.

4. **`.desc` entry.** Already added in the patch: a second `:model` block with
   `:usbid "0x055f" "0x040b"`. Set `:status` to `:basic` or `:good` only after a confirmed
   real scan.

5. **Manpage.** Update `doc/sane-mustek_usb2.man` to list the new model.

## Process

1. Validate a real scan on hardware (this is the gating requirement; SANE will not accept
   a `:good` status without it).
2. Implement the dual-model refactor above on a branch off current upstream.
3. Open a merge request on the SANE GitLab. Reference this repo and
   `docs/REVERSE-ENGINEERING.md` for provenance of the constants.
4. Sign-off / DCO and GPL-2.0-or-later, matching the backend.

## Provenance / legal

The constants were extracted from the vendor's own GPL-incompatible binary **for
interoperability**, and re-expressed against the GPL backend they were derived from. The
backend itself is already GPL-2.0-or-later (Copyright Mustek; Henning Meier-Geinitz). All
additions here are under the same license.
