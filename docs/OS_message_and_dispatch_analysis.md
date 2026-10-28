# LEX-31 firmware — compressed UI messages, ROM dispatch tables, and extension constraints

Source: the owner's three untouched 2732 EPROM dumps, U2 (red), U3 (green), U4 (white). Byte assignments assume the previously inferred contiguous mapping U2=0000h, U3=1000h, U4=2000h. This report distinguishes firmware facts from physical-hardware hypotheses.

## High-level OS service: `RST 30h` — show packed ROM message

- `0030h` performs `JR 003Eh`.
- `003Eh` calls `RST 18h`, which resets the existing LCD text view via `0867h`.
- `003Fh` calls `09F0h`, setting `DE=4013h` and entering the message decoder at `08CBh`.
- `0042h` jumps to `09D7h`, which NUL-terminates the scratch string and displays bytes through `069Eh`.

**Calling convention:** `HL` points to a nibble-packed message in the ROM; display buffer begins at `4013h`. The routine modifies registers and the display, so it is not safe to call while assuming scratch RAM or the LCD cursor is preserved.

### Packed format (derived from executable code at `08CBh`, `08F7h`, `0925h`)

Each byte stores two four-bit codes, high nibble first. `0925h` alternates high/low nibble consumption, tracking its state in `4508h`. Codes `0`–`B` index the twelve most common characters in the table at `0939h`. Code `C` ends the packed message. Codes `D`,`E`,`F` consume a second nibble to index the extended character table beginning at `0945h`. `F7`–`FE` expand NUL-terminated common phrases from `096Ch` (eight phrases, including `press XIT when done` and ` configuration `). The packed message decoder writes expanded bytes through `(DE)` and increments `DE`.

The independent Python decoder `tools/decode_messages.py` documents the encoding and extracts messages from the ROM. It does **not** attempt to identify executable code from arbitrary packed bytes.

## Confirmed UI strings recovered (examples)

| ROM offset | Text |
| --- | --- |
| `112Fh` | `v2.1` |
| `1149h` | `violation` |
| `11C2h` | `factory reset` |
| `11DEh` | `terminal configuration` |
| `1134h` | `djns pwd ` |
| `113Bh` | `user pwd ` |
| `1142h` | `search =>` |
| `1302h` | `directory full` |
| `1327h` | `are you sure (y or n)?` |
| `1336h` | `index==> label=  size=      free=     ` |
| `1388h` | `already sending memory " "` |
| `152Ah` | `set mode==> configuration  clock  alarm` |
| `162Bh` | `help ==> select key press XIT when done` |

The reset path loads the `v2.1` message at `00D9h` before invoking display routine `0045h`. Thus **v2.1 is the ROM's own displayed version string**. At `2711h`/`271Ch`, two branches load the messages `djns pwd` and `user pwd`, then select RAM source strings `4611h` and `462Fh`, respectively. Those strings are copied to the display/text-input working area at `403Bh`. This supports two separately stored online-service credentials; it does not establish how or whether the password is transmitted or obscured at the user interface.

A fuller message index is in `docs/LEX31_OS_messages.csv`. Multiple references to the same message address are expected.

## Second-level dispatch tables: not all pointer tables contain code

The main mode/key dispatcher at `0238h` uses the packed table `0F7Dh–10BFh`, returning handler addresses in HL and carry set on success. Multiple modal loops at `00F1h`, `0CD3h`, `1668h`, `16E5h`, `1F33h`, `2033h`, `2184h`, `22FEh`, `2763h` execute the returned address through `JP (HL)`.

Two other tables have been identified:

- `10C0h–10DBh`: nine triples `keycode, handler_low, handler_high`, NUL terminated. Called at `2986h`/`2989h` using simple lookup routine `027Bh`, then `JP (HL)` at `298Dh`. **These are executable routine addresses** (e.g. `2B->2A1Ch`, `79->29E9h`).
- `10DCh–10E8h`: four triples of the same shape, terminated by a zero; no confirmed code reference yet.
- `10E9h–112Eh`: 23 triples `keycode, pointer_low, pointer_high`, terminated by zero. Looked up at `2003h`/`2006h`; returned `HL` is **read as data** (`LD C,(HL)` at `200Bh`, `LD (4503h),HL` at `200Dh`). These entries point to ROM data/menus around `1396h–15FDh`, and are *not* an execution dispatcher.

The distinction is important for any replacement firmware: the same generic lookup routine `027Bh` can return either a code pointer or a data pointer depending on its caller.

## `C000h` and RAM-code execution: what is actually supported?

The NSC800 RSTB vector at `0034h` is a direct `JP C000h`; startup code at `007Eh` writes `06h` to the NSC800 internal interrupt-mask port `BBh`, enabling RSTB and RSTC. The RSTB line's physical source, memory decoding at C000h, and the presence of external memory remain unknown. No other confirmed direct call/jump to C000h appears in the known ROM code. This is a potential external execution hook **only if** memory actually responds at C000h and a device asserts RSTB. It is not evidence of a bootable ROM scanner or general RAM program loader.

Ten `JP (HL)` opcodes were found in the reconstructed source at `00F1h`, `0CD3h`, `1668h`, `16E5h`, `1F33h`, `2033h`, `2184h`, `22FEh`, `2763h`, and `298Dh`. Nine directly use OS command lookup; `298Dh` uses main lookup or the simple table at 10C0h. None of those paths currently demonstrates loading an executable payload from the document RAM. This negative evidence is limited to the analyzed paths and does not prove no other mechanism exists.

## Hardware and extension considerations

The system's stock 16 KiB SRAM occupies a proposed map `4000h–7FFFh`, with the first 2 KiB serving as OS variables/document metadata and remaining space serving text. The MM58167 RTC is temporarily overlaid onto `4000h–401Fh` by setting port `47h` bit 6. An NVRAM or expansion decoder must not collide with that overlay.

Expansion options to investigate next are hardware decoding of `C000h`, exact NSC800 RSTB pin wiring, use of bus signals on DB-37, and firmware ABI of I/O service calls. All need actual board traces or source-grounded evidence before claiming compatibility.