# Experimental 40×2 LCD ROM — functional editor-row test

A **real firmware patch**, with a byte-exact build script and annotated assembly. This is **not yet the completed native 40×2 operating system**; it does drive both rows during editor redraw.

## Changes from the factory firmware

| Address | Original bytes | New bytes | Purpose |
| --- | --- | --- | --- |
| \`0653h\` | \`34 34\` | \`38 38\` | 8-bit, two-line, 5×8 HD44780 initialization |
| \`0659h\` | \`21 6F 06\` | \`21 80 2F\` | Move original custom-glyph patterns to a new 5×8 table |
| \`0898h\` | \`06 0B\` | \`06 08\` | Send eight CGRAM rows per glyph |
| \`22CEh\` | \`CD 3B 23\` | \`CD A0 2E\` | Call new editor redraw wrapper |
| \`2EA0h–2EF3h\` | 84 zero bytes | New Z80 code | Row-2 renderer |
| \`2F80h–2F9Fh\` | 32 zero bytes | Custom glyph rows | Compatibility pattern data |

The original editor renderer at \`233Bh\` still draws **row 1**, with its original cursor and scrolling rules. The new wrapper then scans only within the selected document (start \`459Ah\`, length \`459Ch\`) to the next CR and draws **the next logical line** on row 2 using HD44780 DDRAM command \`C0h\`. It pads to 40 columns, restores the original row-1 DDRAM cursor from \`4002h\`, and preserves \`AF/BC/DE/HL\`.

This intentionally does not repurpose the document structure, introduce new working RAM, or alter the electrical interface. The ROM's low-level LCD functions \`0760h\` and \`0755h\` remain in use.

## Build

\`\`\`sh
python3 patches/40x2/build.py
\`\`\`

The builder checks the original 12,288-byte ROM SHA-256, verifies original opcode signatures and unused ROM padding, and writes separate U2/U3/U4 images plus the combined image under \`patches/40x2/output/\`. **Only U2 and U4 change; U3 remains unchanged.** Do not overwrite the original dumps.

- Factory SHA-256: \`0b395efd163f70127adfdbd5b234e1f5ee5ff490c8e7386b5c7f5b9faa4b6b12\`
- Patched SHA-256: \`c35c6717eae46a16f516c5e3ad5498670da4d0d83f47359ea877bead5192e60c\`

The first eight rows of each original custom glyph are retained; their shape may need improvement after seeing the real 5×8 screen.

## Test status

The matching downloadable restoration workpack contains an instruction-level Z80 test harness and already-built 2732 images. Nine simulated cases pass: empty file; single line; cursor on CR; short/long next line; long current line; blank next line; multiline traversal; and no reading into an adjacent file. Tests check 40 writes to addresses \`40h–67h\`, stack/register/flags restoration, and row-1 cursor restoration. All 84 injected instruction bytes also decode cleanly with the project's existing Z80 disassembler.

**Not tested on a physical LEX-31.** The test harness stubs the original first-row renderer and LCD bus routines; it is not a cycle-accurate model of the complete machine.

## Not finished

- This is **row-1 editor with row-2 preview**, not a movable two-row editor viewport; the cursor stays on row 1.
- Playback, HELP, configuration menus, modal screen save/restore, and general streaming output still use their existing 40×1 presentation routines.
- The 5×8 custom glyphs are truncated and may not look right.
- The real module's actual HD44780 compatibility, DDRAM addresses, timing, and backlight require hardware testing.

The patch is intentionally separate from [the annotated factory ROM](../../firmware/LEX31_full_annotated.asm), so subsequent 40×2 development can be reviewed and tested without losing the original source.
