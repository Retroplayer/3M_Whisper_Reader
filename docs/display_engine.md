# LEX-31 display engine: completed source-level editor and playback trace

**ROM basis:** Original three 2732 dumps, red U2 at 0000h–0FFFh, green U3 at 1000h–1FFFh, white U4 at 2000h–2FFFh. This is a **static source-level reconstruction**, not a hardware-in-the-loop test. User-visible keyboard semantics cross-check the 3M *Whisper Reader Owner's Manual* pp. 28–29, 43–44, 75–82.

## 1. Fundamental model: a document is not a sequence of fixed screen pages

The editor operates on one byte-addressed, CR-delimited stream in RAM. The selected document's six-byte directory entry is moved to the front for editing. The editor exposes:

| RAM | Meaning supported by instructions |
| --- | --- |
| \`459Ah–459Bh\` | Start pointer of selected document (directory entry +2) |
| \`459Ch–459Dh\` | Selected document's stored byte count (directory +4) |
| \`4594h–4595h\` | Current end of allocated document space |
| \`4669h–466Ah\` | Absolute document cursor pointer, a RAM address, **not** a relative integer line number |
| \`4004h\` | Visible 1-based cursor column used by redraw; clamped at 40 |
| \`4583h–4584h\` | Logical character position on the current CR-delimited line; can exceed 40 |
| \`458Fh–4590h\` | Saved/preferred logical column used when moving vertically |
| \`4582h\` | Five-position text-entry counter; reset when crossing CR |
| \`4539h\` | CR/line-transition flag; controls redraw and vertical-navigation edge cases |
| \`453Bh\` | Vertical-movement edge/short-line flag |
| \`4591h\` | Saved physical cursor column (or 01h at logical beginning of line) |
| \`4002h\` | Separate low-level HD44780 display position; NOT the editor's document pointer |

**Important:** \`4594h\` is the allocation end in this RAM-managed file system, so the editor must not be mistaken for an external-file/page-cache abstraction. An add-on mass-storage implementation would need a different document backing mechanism.

## 2. Renderer, 233Bh–2389h: one line, derived from cursor position

Entry at \`233Bh\` (reached from edit-loop at \`22CEh\`). Inputs: cursor document address \`(4669h)\`, 1-based physical column \`(4004h)\`. Output: complete 40-cell LCD redraw with cursor.

Pseudocode following exact instructions:

\`\`\`text
ptr   = *(word 4669h)
col   = *(byte 4004h)             # 1..40
start = ptr - col + 1              # 233Bh–2348h
lcd.set_DDRAM(0)                   # 2349h–234Ah
for i = 0 .. col-2:               # 234Bh–2355h
    lcd.write(translated(*start++))
lcd.write(' ')                     # 235Bh–235Dh: cursor placeholder
remaining = 40 - col               # 2360h–2364h
while remaining > 0:
    if start == *(word 4594h): break
    if *(byte 4539h) != 0: break
    ch = *start
    lcd.write(translated(ch))
    if ch == CR: break
    start += 1
    remaining -= 1
write spaces until end of row      # 237Fh–2391h
lcd.set_DDRAM(col-1)               # 2384h–2388h
\`\`\`

Note that the physical cell at the cursor is drawn as a space before the cursor is moved back into place. Preceding characters come from document RAM, while content to the right is drawn up to CR, allocation end, or width. This explains why editing long lines requires moving a *viewport* rather than allocating another screen page. The exact LCD output translation is handled by \`0755h/077Dh\`.

The editor loop at \`22CBh\` first calls \`22B6h\` to preserve the logical horizontal column in \`458Fh\` and save the visual column to \`4591h\`, then draws the window at \`233Bh\` and evaluates margin warnings at \`22FFh\`.

## 3. Text insertion and cursor state

- \`2392h–23D0h\` handles new byte insertion. It tests space available, shifts the data tail with \`LDDR\` when inserting in the middle, writes the byte, then calls \`23D0h\` to update the directory's length and free space through \`1CE4h\`.
- \`23D3h–23F2h\` advances logical position \`4583h\` and absolute cursor \`4669h\`. \`4004h\` advances only while below \`28h\` (40), leaving a long logical line horizontally scrollable. \`4582h\` is decremented and reset to five when it reaches zero.
- Insertion of CR takes a special branch at \`23C5h–23CDh\` to reset line context at \`2466h\`.
- The editor's advance (\`249Bh\`) returns flags with special meaning: **C=1** after consuming a byte; **C=0, Z=1** at document end; after a successful advance **Z=1** if the consumed byte was CR. This is why callers distinguish \`RET NC\` and \`RET NZ\`.

## 4. Arrow and SHIFT+arrow commands — decoded from the mode-01 command table

The mode-01 dispatcher at \`0F7Dh–10BEh\` identifies eight navigation variants. The actual physical keys have been correlated with the owner's manual functions; table codes are the firmware's internal keycodes.

| Movement | Keycode | Entry | Confirmed operation |
| --- | --- | --- | --- |
| Right | \`84h\` | \`245Eh\` | Advance one document byte via \`249Bh\`; reset line context on CR |
| Left | \`87h\` | \`24E2h\` | Retreat via \`24B0h\`; perform extra repositioning when crossing a CR |
| Down | \`85h\` | \`2591h\` | Scan forward to next CR, move to next logical line, then approach saved logical column |
| Up | \`86h\` | \`25D7h\` | Locate previous CR boundary/line and approach saved logical column |
| SHIFT+Right | \`C4h\` | \`24AAh\` | Advance to next CR/end-of-line boundary |
| SHIFT+Left | \`C7h\` | \`24F4h\` | Retreat to previous CR/start-of-line boundary |
| SHIFT+Down | \`C5h\` | \`2523h\` | Jump to end of selected document, reposition into last line |
| SHIFT+Up | \`C6h\` | \`2434h\` | Jump to start of selected document |

The exact cursor *visual placement* at the boundary after CR is mediated by the \`4539h\` and \`453Bh\` state flags. Do not model it as simply switching from row 0 to row 1 of an LCD: it is a RAM-stream cursor with line scanning. The firmware does **not** maintain an array of line-address pointers or page objects.

### Vertical movement maintains a preferred horizontal position

At \`22B6h\`, each main editing cycle saves \`4583h\` to \`458Fh\`. Then:

- **Down** (\`2591h\`) consumes bytes with \`249Bh\` until CR/end, resets the logical and visual columns, and advances on the new line until \`4583h\` reaches the saved preferred value \`458Fh\` or a line boundary. It marks short-line behavior at \`453Bh\`.
- **Up** (\`25D7h\`) searches backward across CR boundaries using \`24B0h\`, \`24FEh\`, \`4539h\`, and \`453Bh\`, then reuses the preferred-column positioning path.

The actual per-character horizontal window position is 1..40; logical-column \`4583h\` is a separate 16-bit value.

## 5. The four status arrows — ROM-derived mask mapping

\`2689h\` scans *behind* the cursor in the selected document and \`26B3h\` scans *ahead*, checking for carriage returns and the document boundaries. The editor at \`22DBh–22ECh\` assembles and writes the mask via \`RST 28h\` and \`STATUS_CLEAR_MASK\`.

| Bit | Indicator | Conditions |
| --- | --- | --- |
| \`0010h\` | RIGHT | More text to the right on current logical line |
| \`0020h\` | DOWN | Another logical line exists below |
| \`0040h\` | LEFT | Text exists left of cursor on current line |
| \`0080h\` | UP | Another logical line exists above |

This mapping is **strongly verified by software control flow and matches the manual's legend explanations**. It is not yet an electrode-pin map for the custom glass.

## 6. LCD hardware scroll is distinct from editor navigation

At \`069Eh\` the ordinary LCD character-writer checks \`4002h\`. When it reaches \`27h\` (39), the code at \`06AAh–06D6h\` moves the visible DDRAM characters across the display using controller reads/writes, copying 38 cells and leaving room for incoming output. This is for streaming character output; it does not change the stored document cursor \`4669h\`.

At \`07E6h–0857h\`, the OS saves/restores a *40-cell* modal LCD screen on the CPU stack. It reads 20 character pairs and restores 20 pairs through HD44780 writes. This is used to enter temporary screens/help/configuration and return to the previous view.

## 7. Playback/review pages are a separate renderer

\`20B4h\` selects document playback; \`20C2h\` selects receive-buffer playback.

| RAM | Playback meaning |
| --- | --- |
| \`450Ah\` | Source base address (selected file or receive buffer) |
| \`450Ch\` | Current byte index in source |
| \`450Eh\` | Source byte count |
| \`4509h\` | Nonzero = file source; zero = receive buffer |
| \`4512h\` | Characters displayed in current presentation segment |
| \`4511h\` | Playback-active flag |
| \`4510h\` | Playback paused/frozen/command state |
| \`4513h\` | Previous-line traversal counter (set to three at \`2172h\`) |

\`2125h–216Fh\` renders printable characters using \`LCD_CHAR_OUTPUT\`, handles CR boundaries, and at a displayed count of \`27h\` (39) enters a pause/delay/key-check path. The output remains 40 columns, but presentation uses a 39-character threshold, leaving room for cursor/continuation state.

\`21C5h\` retrieves the next playable byte from the selected source. In receive-buffer mode it uses the ring-buffer addressing helper at \`2201h\`; file mode walks the stored file data. \`2214h\` traverses backwards, skipping nonprintable bytes. At \`21A6h\` the code counts backward across **three CR boundaries** before resuming playback. This is a logical-line navigation mechanism, not a fixed-byte page offset.

Automatic playback's exact delay in seconds is hardware-dependent; it uses \`26ECh\` busy-wait plus event polling and does not implement a stored page-index table.

## 8. Packed HELP messages are paged separately

The packed-message engine at \`08CBh\` and the partial decoder at \`08ACh\` supply help text by segments. The HELP UI at \`1FE5h–2055h\` uses a separate page/segment counter and direction indicators via \`0A14h\`. This is *not* the editor viewport and should remain a distinct subsystem in a modified firmware.

## 9. Practical 40×2 firmware architecture

The existing editor has **one logical stream cursor**, not two independent line cursors. To display two logical lines, preserve the original document model and add a second-row renderer using a CR scan:

1. Derive the first visible logical line from the current cursor and its horizontal viewport offset.
2. Render the current line using the same 40-column clipping and cursor model.
3. Find the next CR boundary (without changing \`4669h\`) and render the next logical line on row 2.
4. Set the active HD44780 DDRAM row address with \`RS=0\` commands, while keeping the logical cursor position independent of physical DDRAM addresses.
5. On up/down, choose whether the document cursor remains on the first or second visible row; only scroll the two-row viewport when crossing the visible window.
6. Extend modal save/restore (\`07E6h–0857h\`) and playback/help output as distinct modules. Do not assume that rewriting the editor renderer automatically updates these other screens.

This **is not a finished two-line firmware patch**: it is the replacement strategy justified by the reconstructed routines. Memory allocation, register preservation, free ROM space, and calling conventions must be handled before implementation. The initial two-byte \`34h->38h\` LCD initialization experiment only selects the new controller mode.

## 10. Verification status

- Control-flow routines and all four arrow masks: grounded in original ROM bytes and the user's 3M manual.
- Main renderer's pointer arithmetic and all exit conditions: fully traced at source level.
- Playback source/cursor/count state: traced; runtime timings not calibrated.
- LCD modal save/restore: source verified, *physically* untested.
- Full insertion/deletion edge cases and TAB behavior: not completely emulated; do not claim exhaustive runtime correctness.
- The physical 40×2 controller and custom annunciator pinouts: not electrically tested.
- Original ROM bytes must remain unchanged; run [source rebuild](../tools/assemble_source.py) and [display-engine verification](../tools/verify_display_engine.py) after editing.


### Exact HELP page-selection mechanics

A further trace resolves the previously generic "paged HELP" description:

- \`2003h–200Dh\` looks up a key at \`10E9h\` and reads the first byte of the selected record as **C = number of HELP pages**, then stores the pointer to its compressed text at \`4503h\`.
- \`2013h\` starts the page counter at **B = 1**. The display loop \`2016h–2021h\` clears the screen, sets \`HL=(4503h)\`, sets \`DE=4013h\`, calls \`08ACh\` with \`B-1\`, and then prints the resulting decoded page.
- The compressed-message skip routine \`08ACh–08C8h\` steps over that many preceding packed-string terminators (nibble code \`0Ch\`) before decoding the desired page. It does **not** slice a fixed 40-byte page from an ASCII string.
- \`2024h–2026h\` calls \`0A14h\` with the current page B and total C to set previous/next-page arrow indicators.
- Key-dispatch handlers at \`2045h–2049h\` and \`204Eh–2053h\` adjust the page number within the valid range; another handler returns to the HELP key selection.
- \`2055h–206Fh\` can send all pages through the auxiliary character-output channel by iteratively decoding each page to \`4013h\`.

Thus HELP uses **packed variable-length message pages**, entirely separate from both the editor's logical CR-delimited lines and playback's 39-character presentation segments. Modifying the HELP content or adding a 40×2 HELP interface requires updating the page decoder/UI, not the document editor's cursor handler.
