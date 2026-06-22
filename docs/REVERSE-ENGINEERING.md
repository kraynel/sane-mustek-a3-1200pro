# Reverse engineering notes - Mustek ScanExpress A3 USB 1200 Pro

How the device-specific parameters for the A3 1200 Pro were recovered, so the work is
reproducible and reviewable.

## Hardware

- USB: VendorID `0x055f`, ProductID `0x040b`.
- Controller: **SQ113** (Sunplus / Service & Quality), the same family the SANE
  `mustek_usb2` backend already targets for the BearPaw 2448TA Pro (`055f:0409`).
- Optical resolutions: **75 / 150 / 300 / 600 / 1200 dpi** (X and Y) - confirmed by RE.

## Source material

Three artifacts of the old vendor driver were analyzed:

| Artifact | Contents | Verdict |
|---|---|---|
| macOS `.pkg` | Mach-O `ppc` + `i386` bundles | Dead on modern macOS (no 32-bit/PPC runtime). RE cross-reference only. |
| Linux `.deb` (`libsane_1.0.19-1_i386`) | `libsane-mustek_usb2.so.1.0.19` (ELF 32 i386) | **Primary source.** A Mustek-modified `mustek_usb2` that already hard-codes the A3 parameters. |
| Windows `setup.exe` | proprietary driver | Not needed; kept as a fallback for USB capture validation. |

Key realization: the vendor Linux `.so` is **not** the generic upstream `mustek_usb2`
(which only knows the BearPaw). It is a Mustek fork that already references
`ScanExpress A3 USB 1200 Pro` / `600 Pro` and contains the A3 motor/AFE/shading logic.
It is stripped, but compiled with debug traces, so every function name and parameter
format-string survives as a literal. Because it derives from a backend whose source is
public, the work is **differential**: compare to the known source and extract only the
deltas.

## Tooling

- **Ghidra 12.x** with the [GhidraMCP](https://github.com/LaurieWired/GhidraMCP) plugin,
  driven over its local HTTP API (`decompile_function`, `disassemble_function`,
  `xrefs_to`, `strings`, `data`, `segments`).
- `radare2`, `llvm-objdump`, `nm` for cross-checks.
- Ghidra loads the image at base `0x10000`, so Ghidra addresses = radare2 addresses + 0x10000.

## Findings

### Architecture maps 1:1 to upstream

- `FUN_00016810` = `Mustek_SendData(chip, reg, data)` - the ASIC register write primitive
  (proved by its debug string `"Mustek_SendData: Enter. reg=%x,data=%x"`). reg in EDX,
  data in ECX (regparm3).
- `FUN_000165f0` = a related data/table write primitive.
- `FUN_00015750` = debug logger.
- The whole binary is a clone of upstream `mustek_usb2` with A3 parameters substituted.

### Delta 1: the model is hard-wired to "1200 Pro"

`sane_mustek_usb2_open` calls `IsResolution600` (Ghidra @ `0x18d10`), which **always
returns 0** (= 1200). The 600-override block is never executed. So this binary *is* the
A3 1200 Pro firmware path - unambiguous, no model probing.

### Delta 2: resolution / CCD constants (in `.data`)

Default (1200 Pro) values at Ghidra `0x389e2`, little-endian `u16` pairs:

| Address | dword | u16 LE | meaning |
|---|---|---|---|
| 0x389e2 | 025804B0 | 1200, 600 | X resolutions |
| 0x389e6 | 0096012C | 300, 150 | X resolutions |
| 0x389ea | 0000004B | 75 | X resolution min |
| 0x389ee | 025804B0 | 1200, 600 | Y resolutions |
| 0x389f2 | 0096012C | 300, 150 | Y resolutions |
| 0x389f6 | 0000004B | 75 | Y resolution min |

=> supported resolutions: **75 / 150 / 300 / 600 / 1200 dpi**.

### Delta 3: default AFE gains / offsets (`InitTiming` = `FUN_00015b50`)

Posted before calibration:

| chip offset | value | meaning |
|---|---|---|
| +0xd8 | 0x28 (40) | gain R |
| +0xd9 | 0x28 (40) | gain G |
| +0xda | 0x28 (40) | gain B |
| +0xdb | 0x78 (120) | offset ch1 |
| +0xdc | 0x28 (40) | offset ch2 |
| +0xdd | 0x32 (50) | offset ch3 |
| +0xe0 / +0xe4 / +0xe8 | 0 / 1 / 1 | offset sign flags |

`Asic_SetAFEGainOffset` (`FUN_00016f10`) writes AFE registers `0x04/0x06/0x08`, then
`0x0a-0x0b / 0x0c-0x0d / 0x0e-0x0f` depending on the sign flags, using those chip fields.

### Other decoded functions

- `Asic_SetMotorType` (`FUN_00015ac0`): trivial, sets the `isMotorMove` flag (chip+0x114).
- `LLFSetMotorCurrentAndPhase` (`FUN_00019920`): motor phase tables computed via sin/cos on
  pi/16..pi/8 angles (1/8 and 1/16 microstepping). Pure logic, identical to upstream.
- Reflective `SetupScan` (`FUN_0001d8b0`): `wNowMotorDPI = 1200` hard-coded, resolution
  threshold `param_3 < 0x259` (601), `wCCD_PixelNumber` read from chip+0xc2 (high res) /
  chip+0xd6 (low res), `BackTrackFixSpeedStep = 20`, `TotalStep = Height*1200/YRes + 2`.

## Open items (to validate against real hardware)

- The exact CCD pixel count for the A3 sensor (wider than the A4 BearPaw). Upstream uses
  `wCCDPixelNumber_1200 = 11250`, `wCCDPixelNumber_600 = 7500`,
  `CCD_PIXEL_NUMBER = 21600` for the A4 BearPaw. The A3 sensor spans a wider bed; these
  need confirmation by a real scan (or a Windows USB capture).
- Whether the default AFE values above are sufficient, or calibration overrides them.
