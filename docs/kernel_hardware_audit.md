# LEX-31 kernel, hardware and firmware-table audit

**Date:** 2026-10-28. **Source of truth:** three original 2732 EPROM dumps, red U2 + green U3 + white U4, concatenated at 0000h–2FFFh (12,288 bytes), SHA-256 \`0b395efd163f70127adfdbd5b234e1f5ee5ff490c8e7386b5c7f5b9faa4b6b12\`. Firmware byte and instruction addresses refer to [master assembly](../firmware/LEX31_full_annotated.asm). User-visible behavior is cross-checked against the **3M Whisper Reader Owner's Manual** (owner's scan). **This is an audit, not a claim that the electrical schematic or every unknown byte is understood.**

## Overall OS structure

1. **Reset:** \`0000h\` disables interrupts; \`0002h\` initializes port \`47h\`; \`000Bh\` puts SP at \`4800h\`.
2. **Clear volatile working state:** \`0069h–0078h\` writes zero at \`4591h\`, then uses \`LDDR\` with \`BC=0591h\` to clear \`4000h–4590h\`. The persistent directory/config blocks are deliberately *outside* that clear.
3. **Hardware and RAM probe:** \`007Ah\` reads \`63h\`; \`007Eh\` writes \`06h\` to NSC800 ICR at \`BBh\`; \`00A1h\` tests consecutive RAM bytes beginning at \`4800h\` with \`AAh/55h\`, restoring the original byte each time; \`4665h\` captures the detected boundary. **This is a destructive-if-unmapped RAM probe on a machine with unknown expansion decoding, so external hardware should never be mapped into the probe's path until investigated.**
4. **Retained-RAM validation:** \`04ADh\` calculates the XOR checksum for \`4593h–460Fh\`, checksum at \`4610h\`; \`04BAh\` calculates XOR for \`4611h–4656h\`, checksum at \`4657h\`. On mismatch the startup code invokes the corresponding initialization routines. A persistent configuration stored here need not imply EEPROM.
5. **Device initialization:** \`063Dh\` sends HD44780 initialization table at \`0653h\` and writes four custom CGRAM patterns through \`0896h\`. \`0B6Ch\` initializes the MM58167, including its auxiliary RAM/registers.
6. **Authentication:** \`013Ah\` checks the Personal Access Password against RAM \`462Fh\`. The invalid-password path prints a message, writes \`01h\` to port \`63h\`, disables interrupts, and loops at \`0156h\`. Other power-control effects of port \`63h\` are not electrically established.
7. **Foreground OS:** \`00E3h\` polls the keyboard event queue (\`0491h\`), resolves a command and active mode (\`0238h\`), executes the selected handler by \`JP (HL)\` at \`00F1h\`, services incoming characters (\`1B4Ah\`), and cleans up completed transfers. \`4507h\` is the command-mode selector.
8. **Background interrupt service:** hardware **RSTC** vector \`002Ch\` enters \`017Eh\`. It scans keyboard, polls serial receive, refreshes status lamps, decrements transfer timer \`4528h\`, pumps transmit (\`1BFEh\` when ready), handles auxiliary/printer output, and restores \`BBh=06h\`. Hardware **RSTB** vector \`0034h\` jumps to **\`C000h\`** (unmapped/owner unverified).

### ROM-facing kernel calls

| Entry | Verified firmware-level behavior | In/out requirements |
| --- | --- | --- |
| RST \`08h\` | Set main display cursor/DDRAM address via \`0879h\` | A = cursor address |
| RST \`10h\` | Load two 16-bit OS configuration/state words | HL = [4654h], DE = [4656h] |
| RST \`18h\` | Reset/clear primary LCD through \`0867h\` | display changed |
| RST \`20h\` | Retrieve document pointers | DE = [4594h], HL = [4669h] |
| RST \`28h\` | Set a 16-bit annunciator mask through \`0A34h\` | HL = mask |
| RST \`30h\` | Display nibble-packed ROM text through \`08CBh\`; scratch RAM \`4013h\` | HL = ROM message address |
| RST \`38h\` | Compare HL and DE (upper bytes first) | flags; detailed ABI still to audit |

These are **partial calling conventions**, not a completed ABI: register clobbers, stack use, flags, reentrancy and interrupt safety are outstanding.

## Complete *immediate-port* access inventory

A code scan of the annotated instruction entries found **51 immediate IN/OUT instructions at 11 port addresses**. That does *not* count memory-mapped RTC accesses or possible indirect \`IN/OUT (C)\` instructions in unresolved code. [Per-instruction cross-reference CSV](hardware_io_xrefs.csv).

| Port | Instructions | Firmware use | Electrical conclusion |
| --- | ---: | --- | --- |
| \`43h\` | 2 | Two status reads at \`0ACEh\` and \`2072h\`; masks bits 2–3 | Input bits observed; which physical switches/alarms is unknown |
| \`47h\` | 11 | Keyboard scan, LCD control; bit 6 temporarily switches in RTC memory window (\`0BEDh\`) | Shared control latch and input path; physical decode unknown |
| \`4Bh\` | 9 | Main LCD data reads/writes and busy polling | HD44780-facing software interface, connection details untraced |
| \`4Fh\` | 4 | Upper annunciator output; also input bits checked by printer/output logic | Shared status/data functions; not only LCD |
| \`53h\` | 1 | Lower annunciator output latch | Status/control |
| \`57h\` | 2 | Write in keyboard special-state/release paths (\`03F9h\`, \`0426h\`) | Physical output function unresolved; do not call it a beeper without tracing |
| \`5Bh\` | 3 | Character RX/TX at \`18BDh\`, \`18DCh\`, \`1C98h\` | Likely UART-facing data bus; INS6402 chip-select unverified |
| \`5Fh\` | 7 | Communications status and configuration, including port write at \`182Fh\` | UART/modem control; status-bit-to-chip mapping not confirmed |
| \`63h\` | 5 | Read on startup/ISR exit, writes on access-denied and timeout/state paths | Strongly associated with system/interrupt/power state, exact function unknown |
| \`BBh\` | 3 | NSC800 **internal** Interrupt Control Register; values 00h,06h | Confirmed by National Semiconductor NSC800 handbook |
| \`D7h\` | 4 | Read ready bit 0, output buffered characters, CR/LF and printer-style formatting | Auxiliary/printer character interface; DB-37 linkage unproven |

The physical device list known so far: **NSC800** CPU; eight **OKI MSM5128** 2K×8 SRAM devices; three **2732** EPROMs; main **Hitachi H2572** HD44780/HD44100 display; custom segmented annunciator LCD; **INS6402** UART; **TMS99532** Bell-103-compatible modem; **MM58167** RTC; keyboard matrix; acoustic/direct telephone interfaces; beeper/output control; battery/power-control circuitry; printer-style output hardware; DB-37 PERIPHERALS connector. A part's presence in the hardware inventory **does not** prove the corresponding CPU pin/port wiring.

### Hardware-specific driver entries

- **NSC800:** ICR \`BBh\`, hardware RSTC at \`002Ch\`, RSTB at \`0034h\`, NMI \`0066h\` loops to itself. The \`C000h\` destination is a real absolute jump, but physical decoding and whether anything is installed there are unknown.
- **MM58167 RTC:** \`0BEDh\` asserts \`47h\` bit 6, temporarily overlays its registers on \`4000h+\`register number. Read \`0BCCh\`, write \`0BE3h\`, restore latch \`0BDBh\`. RTC register list at \`0C1Bh\`. BCD year held in RTC auxiliary RAM, with rollover and leap-year code at \`0B94h\`, \`0D00h\` and \`0EF6h\`.
- **Main LCD:** controller initialization \`063Dh\` and \`0653h\`; glyph transfer \`0896h\`; commands/data/busy \`0742h–0895h\`; input character substitution at \`0791h\`. Screen save/restore at \`07E6h–0857h\` hardcodes 40 characters.
- **Annunciators:** shadow words \`4006h/4007h\`, bit operations \`0A34h/0A4Ah\`; indicator \`0008h\` is MEMORY (directory count), \`1000h\` is SAVE (flag \`4514h\`), \`2000h\` is XOFF/pause (flag \`4517h\`, likely legend). Other mask-to-legend mappings remain unverified electrically.
- **Keyboard:** scanner \`035Ah\` through \`47h\`; three 72-byte translation layers at \`0565h\`; event queue and command-mode lookup at \`0238h\`; six calculator-character remaps at \`298Eh\`.
- **UART/modem:** RX \`18A9h\`/\`18DCh\`; TX \`1BFEh\`/\`1C98h\`; config write \`182Fh\`. The observed **TMS99532** modem is Bell 103-compatible 0–300 bps FSK and has dedicated originate/answer and carrier-detect pins, but their exact board connections are not established. The user manual offers 110/300 communications modes; distinguishing UART clock generation from modem switching still requires schematic tracing.
- **Printer/auxiliary:** queue \`0B0Ch\`, ready/status \`01EFh\`, physical character output \`0214h\`, print divider \`0B5Dh\`. Output mask \`0200h\` involved. The output is a likely printer channel, not proven identical to the DB-37.
- **Power and switches:** \`63h\`, \`43h\`, and some inputs on \`4Fh\` have documented ROM accesses, but **no credible pinout** can yet be assigned to memory-kill, modem mode, communications mode, battery sensing, or beeper solely from software.

Primary silicon references:
- [National NSC800 Microprocessor Family Handbook](https://www.bitsavers.org/components/national/_dataBooks/1981_National_NSC800_Microprocessor_Family_Handbook.pdf)
- [National MM58167 RTC datasheet](https://dtsheet.com/doc/81393/nsc-mm58167bn)
- [Texas Instruments TMS99532 Preliminary Data Manual (October 1982)](https://www.bitsavers.org/components/ti/TMS9900/TMS99532_Preliminary_Data_Manual_198210.pdf)
- [Intersil HD-6402 datasheet, pin/function-compatible UART reference](https://dtsheet.com/doc/160362/intersil-hd-6402)

## Memory and persistence

| Address | Meaning | Modification implication |
| --- | --- | --- |
| \`0000h–2FFFh\` | Three 4-KiB firmware EPROMs, inferred mapping | Use bank-aware builds; dispatch table crosses U2/U3 at 1000h |
| \`3000h–3FFFh\` | Decoder not determined | **Do not assume free RAM/ROM** |
| \`4000h–4591h\` | Cold-cleared live working RAM | Safe for *temporary* state only if allocations and stack are respected |
| \`4592h–4610h\` | Document metadata and checksum; directory at 4598h, 6-byte records | Preserve across reboot, update XOR checksum at 4610h |
| \`4611h–4657h\` | Saved configuration/credentials + XOR checksum | Preserve and update checksum at 4657h after edits |
| \`4658h+\` | RTC scratch, more operating state | Do not assume nonvolatile or unused |
| \`4800h+\` | Document pool (dynamic RAM probe); SP initially 4800h | Editor uses directly addressable RAM, not a disk abstraction |
| \`C000h\` | Enabled RSTB vector target | Physical map and code availability **unknown** |

The system has physical 16 KiB of SRAM from eight MSM5128s, but the match between each *socket* and address segment is **not** verified. Do not infer one specific SRAM chip is "the work RAM" before checking decoder and chip-select nets.

## Tables we can identify and potentially modify

The [ROM table atlas](rom_table_atlas.csv) records 22 boundaries with encoding and confidence. The most actionable high-confidence tables are:

| ROM address | Purpose | Format / cautions |
| --- | --- | --- |
| \`0543h\` | Dow Jones login strings | NUL-separated ASCII; keep space and terminators intact |
| \`0565h\` | Keyboard mapping | Three 72-byte layers |
| \`0653h\` | HD44780 initialization | \`34 34 01 06 0E 00\` |
| \`066Bh\` | 4 custom LCD characters | four CGRAM starts \`00 10 20 30\` followed by 4×11 row bytes; 5×10 assumptions |
| \`0791h\` | LCD character translation | 12 input/output pairs encoded as 3-byte records, then NUL |
| \`0939h–09D5h\` | Packed UI dictionary | Common/extended symbol alphabets and NUL-separated phrase library |
| \`0BBFh\`, \`0C1Bh\` | RTC initial date and register order | two 13-byte arrays |
| \`0E48h\`, \`0E68h\` | Calendar layout and month lengths | month table includes 29-day February; validation adjusts for leap years |
| \`0F7Dh–10BEh\` | Main command dispatcher | Keycode + operating-mode + handler pointer; packed, crosses EPROM bank |
| \`10C0h\`, \`10DCh\` | Secondary key/pointer tables | 9 and 4 entries; second table's caller unresolved |
| \`10E9h\` | HELP key-to-data pointers | 23 entries |
| \`112Fh–163Dh\` | Packed OS messages, version \`v2.1\` | Variable-length; do not arbitrarily extend in place |
| \`1855h\` | Configuration menu counts | Nine bytes, counts \`01 03 02 02 02 01 02 02 02\` |
| \`185Eh\` | **All 17 config descriptors** | 3 bytes: screen offset, option-value phrase ID, config bit index |
| \`1A75h\` | Format-line PC/PX options | \`78 25 45 63 26 45 00\`: x->4525h, c->4526h |
| \`298Eh\` | Calculator key remaps | \`06\`, then 6 (typed key, calculator key) pairs |

Three-byte configuration descriptors are decoded in [configuration_fields.csv](configuration_fields.csv). The third byte is a bit number used by \`1839h\`: \`4654h + ((index>>3)&3)\` and bit \`index&7\`. For example:
- **parity:** \`1861h\`, index 2 ⇒ \`4654h\` bit 2
- **modem speed:** \`186Dh\`, index 4 ⇒ \`4654h\` bit 4
- **beeper:** \`1879h\`, index 17 ⇒ \`4656h\` bit 1
- **file-Z EOL mode:** \`187Ch\`, index 18 ⇒ \`4656h\` bit 2
- **network choice:** \`188Bh\`, index 21 ⇒ \`4656h\` bit 5

The descriptor's second byte selects a text pair in the option-message library; it is **not** the stored value itself. The first byte selects its position in the generated line. The table relies on existing UI code and fixed size; expanding the number of menu fields requires code and layout changes, not just appending records.

### Original 40×1 LCD to 40×2 dependencies

- \`0653h\`: function-set initialization (initial test change already made).
- \`066Bh–069Ah\`, \`0896h\`: original CGRAM uses four 11-row 5×10-oriented patterns at offsets \`00/10/20/30\`. A 5×8 two-line display has a different pattern layout; this needs an explicit code and pattern-table patch.
- \`07E6h–0857h\`: modal LCD save/restore reads and restores 40 characters as 20 pairs (\`B=13h\`).
- The editor cursor/viewport logic (multiple routines) assumes one 40-character line; two-line editing is a larger change. Do **not** claim the two-byte initialization patch implements it.

## What remains unverified

1. **DB-37 pinout, address/data bus exposure, chip-select decoder, and power/GND assignments.** The owner's observation of CPU-connected pins is evidence to investigate, not a ready-to-use wiring diagram.
2. Mapping of address ranges \`3000h–3FFFh\`, \`8000h–FFFFh\`, especially \`C000h\`, and whether RSTB actually fires on production units.
3. Hardware signal mapping for \`43h\`, \`57h\`, \`63h\`, modem mode switches, phone jack electronics, printer connector and beeper.
4. Full semantics and boundaries of the calendar descriptor table at \`0CE2h\`, screen assembly at \`0E48h\`, and secondary pointer table at \`10DCh\`.
5. Complete handler ABI / call graph; exception and interrupt semantics when executing code from RAM.
6. Source editability: the current \`assemble_source.py\` verifies byte-preserving assembly and same-size patches, **not full relocation of arbitrary Z80 instructions**. Changes increasing ROM code/table sizes will need a proper assembler, linker, bank layout, and cross-ROM address audit.

**Immediate next reverse-engineering decisions:** trace DB-37 continuity against NSC800 signals and any decode ICs; fully label the power/status ports; reconstruct config defaults and their checksum updates; trace OS handler mode transitions; prove or disprove a firmware-supported RAM loader/expansion-ROM interface.
