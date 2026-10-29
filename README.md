# 3M Whisper Reader / Lexicon LEX-31

Reverse engineering and restoration of an early-1980s portable terminal, based on the owner's hardware inspection and three EPROM dumps. **The assembly analysis is provisional and not yet a complete reverse engineering.**

## Examined hardware

| Device | Observed component |
|---|---|
| CPU | NSC800 (Z80-compatible instructions; multiplexed AD0–AD7) |
| SRAM | 8 × OKI MSM5128, 2 KiB each, 16 KiB total |
| Firmware | 3 × 2732 UV EPROMs, 4 KiB each |
| Main LCD | Hitachi H2572, 40×1, HD44780 + HD44100 drivers |
| Status display | Custom annunciator LCD |
| UART | INS6402 |
| Modem | TI TMS99532 |
| RTC | National Semiconductor MM58167 |
| Expansion | DB-37 labeled PERIPHERALS; several CPU-connected lines observed, pinout unknown |

## Original ROM inventory

The board socket positions and colored dots were recorded before dumping.

| Filename | Socket | Tentative address | SHA-256 |
|---|---|---|---|
| `red_u2.bin` | U2, red | 0000–0FFF | `7ff2ab423b202d3755f8ffbe06c5804412252459ea7434f99c1ba4bce2020e14` |
| `green_u3.bin` | U3, green | 1000–1FFF | `78540723234e94119dcac9ffc6a40561abd6d21cac1457739fb1a428f4d0d253` |
| `white_u4.bin` | U4, white | 2000–2FFF | `3fa98fd04a6a2cabcae2c99b295f7d42374a4a1602d259771b2e5fbc7576d53a` |

Combined U2 → U3 → U4: `0b395efd163f70127adfdbd5b234e1f5ee5ff490c8e7386b5c7f5b9faa4b6b12`. Each original image is 4096 bytes. Memory placement is inferred from executable code, not yet confirmed at the physical address decoder.

## Firmware analysis (work in progress)

- Boot/RAM sizing: reset at `0000h`; memory probing from `4800h`; OS variables in `4000h–47FFh`; document pool apparently begins `4800h`.
- Main LCD: command, data and busy/status paths around `0742h–0895h`, ports `47h`/`4Bh`. Port `47h` also participates in keyboard scanning.
- Custom status LCD: shadow registers `4006h/4007h`, output ports `53h/4Fh`, 16-bit set/clear masks at `0A34h/0A4Ah`; individual legends not all verified.
- Keyboard: three 72-entry tables starting `0565h`; 29 command groups and 88 mode-handler entries; handler dispatch at `0238h` and indirect `JP (HL)` at `00F1h`. The DJ key invokes a scripted communications sequence containing `DOW1;;`.
- Documents: six-byte record directory around `4592h`; transmission code uses record pointer and length. Details remain provisional.
- UART/modem: possible software interface via ports `5Bh/5Fh`, exact board connectivity unverified.
- Auxiliary/printer-style output: software at `01E7h/0214h` uses port `D7h`; not yet physically proven to connect to DB-37.
- MM58167 RTC: chip identified on hardware, firmware register base and interrupt source **not determined**.
- No confirmed OS-supported arbitrary RAM-code loader or expansion-ROM protocol yet.

## 40×2 LCD experiment

The original H2572 is a 40×1 HD44780 display. An HD44780-compatible single-enable 40×2 replacement is intended. A preliminary, **untested** U2 EPROM patch changes function-set bytes at offsets `0653h` and `0654h` from `34h` to `38h`. It changes initialization only, **not** the text editor's one-line viewport.

## Project rules

Preserve original EPROM dumps unchanged. Keep factory-confirmed, byte-verified and hypothesized conclusions distinct. Do not assign DB-37 pin functions or claim a RAM program loader without physical or firmware evidence.


## Annotated firmware source and reproducible builds

- [Master annotated disassembly](firmware/LEX31_full_annotated.asm): all 12,288 ROM bytes represented as traced instructions or explicit data. 4,617 instruction starts currently discovered; unresolved code/data remains clearly marked.
- [Original ROMs](roms/original/): untouched red U2, green U3, and white U4 EPROM dumps.
- [Disassembly generator](tools/build_disassembly.py): reconstructs labels, code/data and cross-reference tables from the originals.
- [Source reassembler](tools/assemble_source.py): specialized source-to-ROM rebuild verifier, not a full generic Z80 assembler.

From the repository root, with Python 3:

```sh
python3 tools/assemble_source.py
# Regenerate working disassembly from the ROMs (overwrites generated firmware source):
python3 tools/build_disassembly.py
```

The reassembler has been tested to reproduce the three factory EPROM images **byte-for-byte**. Hand-edited source should be kept on a branch or in a separate file before regenerating. The single-enable 40×2 LCD initialization experiment changes only the two `34h` bytes at `LCD_INIT_COMMANDS` (`0653h` and `0654h`) to `38h`; it is not hardware-tested and does not add a two-line editor. The project source package supplied in the ChatGPT restoration conversation includes this test image and further research notes.


## Document-transfer reverse engineering

The firmware's SEND / CTL+SEND / SAVE and \`PC\`/\`PX\` controls are traced in [document transfer analysis](docs/document_transfer.md). Important verified entry points: \`1973h\` literal-send bypass, \`1978h\` regular SEND, \`1A29h\` FORMAT-line parser, \`1A75h\` \`PC\`/\`PX\` RAM-variable table, \`1A7Ch\` SAVE toggle, and \`1B1Fh\` saved-line append. A 24-signature [ROM regression checker](tools/verify_transfer.py) validates these references against the original dumps. Run with \`python3 tools/verify_transfer.py\`.

This knowledge is integrated into [the annotated disassembly](firmware/LEX31_full_annotated.asm) and the [disassembly generator](tools/build_disassembly.py). Normal SEND and literal SEND deliberately use different source pointer/count pairs but share the same low-level output driver.


## Firmware-wide kernel and hardware audit (October 2026)

- [Kernel, I/O hardware, memory map and modifiable ROM tables](docs/kernel_hardware_audit.md)
- [Complete immediate I/O instruction cross-references](docs/hardware_io_xrefs.csv): 51 accesses across 11 port addresses (including NSC800's internal BBh)
- [ROM table atlas](docs/rom_table_atlas.csv): 22 explicitly identified data intervals, with boundaries and confidence
- [Configuration descriptor and RAM-bit index](docs/configuration_fields.csv): all 17 configurable fields in nine menu groups
- [Reproducible ROM audit script](tools/audit_rom_tables.py)

The discovered option-descriptor table is at \`1855h–1890h\` and the config editor changes stored bits at \`4654h–4656h\` through \`1792h\`, then updates a retained-RAM XOR checksum at \`4657h\`. Original 40×1 LCD initialization includes four custom CGRAM patterns, and temporary screen save/restore assumes 40 cells; both require specific work for the planned 40×2 display.

Rebuild the CSV indexes using \`python3 tools/audit_rom_tables.py\`. All physical hardware pin mappings, expansion memory decoding, and RAM-code loading remain work in progress; do not treat this software audit as a board schematic.


## Editor viewport, scrolling and playback (source-level reconstruction)

The [display engine analysis](docs/display_engine.md) traces the 40-cell editor renderer (\`233Bh\`), all eight normal/SHIFT arrow handlers, the 1-based visual cursor, CR-delimited line navigation, four central arrow annunciator bits, and the independent playback renderer (\`2125h\`). The [annotated assembly](firmware/LEX31_full_annotated.asm) names these routines, including the actual \`CALL 22B6h\` at \`22CBh\` that earlier disassembly versions mistakenly left as \`DB\`.

The original ROM's four arrow masks are \`0010h\` RIGHT, \`0020h\` DOWN, \`0040h\` LEFT, \`0080h\` UP. Text is stored as a linear CR-delimited byte stream, **not** 40-column pages. The editor cursor (\`4669h\`), visible 1–40 column (\`4004h\`), logical column (\`4583h\`), and preferred vertical-navigation column (\`458Fh\`) are separate state variables. The playback engine and modal HELP screens have separate paging and presentation logic.

Run \`python3 tools/verify_display_engine.py\` to check 29 byte-accurate instruction signatures against the preserved original EPROMs. The 40×2 upgrade is **not yet a complete firmware patch**; the two-row rendering strategy and all currently identified dependent routines are documented.

## Experimental 40×2 editor ROM

A [reproducible 40×2 test patch](patches/40x2/README.md), [annotated Z80 module](patches/40x2/module.asm), and [byte-exact builder](patches/40x2/build.py) are available without changing the original firmware. The patch selects HD44780 2-line/5×8 mode, adapts custom CGRAM loading, retains the factory row-1 editor renderer, and draws the next document line onto row 2. The supplied workpack includes nine instruction-level tests; it has **not been tested on physical hardware** and does **not yet** implement full two-row scrolling, HELP, or playback.

## Experimental Windows emulator (v0.1.7 preview)

A runnable, **early-access** emulation/debugging build is available in [`emulator/`](emulator/README.md). It executes the original, unmodified ROM images from [`roms/original/`](roms/original/) using a Z80-compatible Python CPU core and provisional hardware models.

On Windows 10/11, download/clone the repository, install Python 3.11+, then run `emulator/START_EMULATOR.bat`. You can use the photo-based virtual keyboard, 40×1 LCD window, RTC, and diagnostic log. The clock initializes from your PC. The serial/modem, alarm IRQ, annunciator and hardware timing models are incomplete; this is **not** a full hardware-accuracy claim. See the [emulator instructions and limitations](emulator/README.md).

To help find bugs, please [open an issue](https://github.com/Retroplayer/3M_Whisper_Reader/issues) with the steps to reproduce, screen output, emulator version and relevant log entries. The public preview ships with 42 CPU-independent regression tests; use `python -m unittest discover -s emulator/tests -v` from the repository root.
