# LEX-31 document transfer: SEND, CTL+SEND, PC/PX, and SAVE

**Basis:** Original 3×2732 EPROM bytes (U2 at 0000h, U3 at 1000h, U4 at 2000h), master annotated disassembly, and the 3M Whisper Reader Owner's Manual (printed pp. 21–22, 49–52, 67–69). Physical memory decoding and UART wiring still need board confirmation.

## Entry points and OS state

| Operation | Keycode / mode | ROM entry | Important RAM state |
| --- | --- | --- | --- |
| SHIFT+SEND: formatted file transmission | keycode 96h; modes 00h/03h | 1978h | 451Fh = 0 (normal); 451Bh pointer, 451Dh remaining |
| CTL+SEND: literal data transmission | keycode 99h; modes 00h/03h | 1973h → 1978h | 451Fh = FFh (bypass special format processing); 4521h pointer, 4523h remaining |
| SHIFT+SAVE: save incoming data | keycode 97h; mode 00h | 1A7Ch | 4514h = FFh while active; directory and allocation state below |

Command-table assignments above are extracted from the mode/key dispatcher at 0F7Dh–10BEh, not inferred from the key labels alone. A hardware matrix-to-legends mapping is still incomplete, but SEND/SAVE semantics match the owner's manual.

### Distinct transfer sources — 19A7h onward

The selected six-byte directory record is positioned at HL:

\`\`\`z80
19A7 PUSH BC
19A8 INC HL
19A9 INC HL
19AA LD E,(HL)       ; record +2/+3: start pointer
19AB INC HL
19AC LD D,(HL)
19AD INC HL
19AE LD A,(HL)
19AF INC HL
19B0 OR (HL)         ; test record +4/+5: length
...
19B7 LD A,(451Fh)
19BA OR A
19BB JR Z,19C6h     ; 0 = formatted path
19BD LD (4521h),DE  ; literal pointer
19C1 LD (4523h),HL  ; literal byte count
...
19C6 CALL 1A29h     ; parse normal file's optional format line
19CB LD (451Bh),HL  ; payload begins after optional header
19CE LD DE,(452Bh)  ; saved end pointer
19D2 EX DE,HL
19D4 SBC HL,DE      ; formatted payload byte count
19D6 LD (451Dh),HL
\`\`\`

This confirms the directory record's two 16-bit fields are *start pointer* and *stored length*. It also proves literal SEND and formatted SEND use separate source pointers/counts but share the transmitter.

### Parser — 1A29h, 1A66h, 1A75h

\`\`\`z80
1A29 ADD HL,DE       ; HL = file end (input HL=length, DE=start)
1A2A LD (452Bh),HL
1A2D EX DE,HL       ; HL = file start
1A2E LD A,(HL)
1A2F CP 1Bh         ; format line exists only if first byte is ESC
1A31 RET NZ
...
1A39 CP 70h         ; seek 'p' (ASCII normalized to lowercase by 0051h)
...
1A75 DB 78h,25h,45h,63h,26h,45h,00h
     ; x → 4525h, c → 4526h, then zero terminator
\`\`\`

After \`p\`, code at 1A43h searches the two-entry table for \`x\` or \`c\`. At 1A5Ch it demands an equals sign (\`3Dh\`) after the option name, then stores the following character into the selected RAM variable at 1A63h via \`LD (BC),A\`. The parser reads until CR or stored end pointer. The manual describes \`PC=$\` (programmable pause character) and \`PX=+\` (programmable prompt character) on the first FORMAT line (pp. 50–52). The clauses are four characters long, excluding the separating spaces.

**Therefore:**
- \`4525h\` = \`PX\` expected prompt / continue character. The RX path compares it with the received character at \`18E0h–18E6h\` and, when equal, clears TX hold flag \`4517h\`.
- \`4526h\` = \`PC\` programmed pause character. The TX path compares at \`1C79h–1C80h\`. When matched, it **does not send the character**; it loads \`0271h\` (625 decimal) into countdown \`4528h\`, then returns.
- \`4528h\` is decremented by the periodic interrupt service at \`018Eh–0196h\`. That service only invokes the TX pump once the timer reaches zero. The manual specifies a nominal five-second pause, implying a nominal 125-Hz countdown; the actual interrupt frequency and quartz/dividers still need hardware verification.

### Literal SEND bypass is explicit

\`\`\`z80
1973 LD A,FFh
1975 LD (451Fh),A
...
1C6D LD C,A
1C6E LD A,(451Fh)
1C71 OR A
1C72 JR NZ,1C97h   ; bypass PC and CR->Z transformations
\`\`\`

Formatted mode checks PC at \`1C79h\`, and may replace outgoing CR with the contents of special file Z at \`1C89h–1CCCh\`. Literal mode jumps directly to the hardware-byte output at \`1C97h–1C98h\` (port 5Bh). The later CR/XOFF/flow-control handling remains possible even for literal mode, so **literal** should not be interpreted as bypassing all physical serial settings or flow control.

### OS scheduling and transmit API

The NSC800 periodic routine at \`017Eh\` reads the countdown at \`4528h\`; when zero it calls \`1BFEh\`. The TX pump tests communication status port \`5Fh\` and software hold \`4517h\`, draws from queue \`4464h\` or either file source, and writes to \`5Bh\`. The regular main loop is **not** required to busy-wait each outgoing byte.

\`451Fh\` also manages completion: once no bytes remain and the queue drains, the OS main loop at \`011Eh–0138h\` clears the transfer-mode flag.

## SAVE: file creation and receive path

1. SAVE handler \`1A7Ch\` reads and clears \`4514h\`. If already active (negative / FFh), it takes the stop/flush path to \`1B1Fh\`.
2. When starting, it prompts for a one-character label using \`1B01h\` and calls \`1E05h\` to look up or create the directory entry. Overwrite/confirmation paths are present around \`1AA2h–1AD3h\`.
3. At \`1AD6h\`, \`4514h\` is set to \`FFh\`. The status update routine at \`0A8Ah\` reflects this with **indicator mask 1000h**; this is a strong software identification of the **SAVE** annunciator, though LCD electrode wiring is not yet traced.
4. Received characters enter through port \`5Bh\` at \`18DCh\`, into the receive software queue at \`18F2h–18FDh\`. The main loop calls \`1B4Ah\` at \`011Eh\` to consume queued characters.
5. \`1B4Ah–1BFDh\` interprets characters, updates the LCD and stages received lines. Notably, \`1BD2h–1BF9h\` reads a display-line span into the scratch buffer at \`4013h\`.
6. \`1B1Fh\` copies staged bytes from \`4013h\` to the active document end at \`(4594h)\`, writes a \`0Dh\` terminator, and calls \`1CE4h\` to update record length (\`459Ch\`), storage cursor (\`4594h\`), and free space (\`4596h\`).

**Limitation:** The way the receiver stages long physical display lines and flushes complete logical records needs further control-flow tracing; do not assume this API captures arbitrary binary data intact. SAVE is a *text capture* feature.

## Related special-file services

- File **Y**: ENQ \`05h\` detected at \`1B7Ah\`; \`1B88h\` selects ASCII Y and uses the same document transmission infrastructure (manual p. 69).
- File **Z**: on CR during formatted SEND, \`1C8Eh\` looks up ASCII Z and transmits its stored contents instead of CR (manual p. 67).
- DJ uses file **X** for personal portfolio, while receiving DJ session data under a separately named service memory (manual p. 20); this is not necessarily an ordinary one-character directory record.

## Working-RAM ABI (observed)

| Address | Meaning |
| --- | --- |
| \`4514h\` | SAVE capture active flag (FFh) |
| \`4517h\` | TX hold/pause (also XOFF and prompt waiting) |
| \`451Fh\` | Transmission mode: zero formatted, FFh literal, other intermediate states |
| \`451Bh–451Ch\` | Formatted transfer current source pointer |
| \`451Dh–451Eh\` | Formatted transfer remaining count |
| \`4521h–4522h\` | Literal/redirected document current source pointer |
| \`4523h–4524h\` | Literal/redirected document remaining count |
| \`4525h\` | PX prompt character (default 11h XON) |
| \`4526h\` | PC pause character (startup default FFh: inactive) |
| \`4528h–4529h\` | Countdown timer (0271h for programmed PC pause) |
| \`452Bh–452Ch\` | File end pointer during formatted SEND setup |
| \`4592h\` | Active selected file identifier / transfer state |
| \`4593h\` | Number of files, maximum 20 |
| \`4594h–4595h\` | Current document-space end/allocator cursor |
| \`4596h–4597h\` | Available document space |
| \`4598h\` | First six-byte directory record |
| \`459Ch–459Dh\` | First record's length field (current file while selected at front of directory) |

The directory is moved/reordered during file selection, so do not treat \`459Ch\` as an absolute global field for all possible document records.

## Implications for removable mass storage

The strongest hooks are *file-level* operations, not raw UART replacement:

- Directory: lookup \`1D14h\`, create/select \`1E05h\`, delete/reorganize \`1E5Ah\`, indexed listing \`1F5Fh\`.
- File data: known in-memory address/length per six-byte record; byte-append service \`1CE4h\`; file-payload TX streams via a pointer and remaining count.
- Built-in serial transfer already supports a literal file image without the special FORMAT interpreter. A removable-storage controller could initially use file import/export through that path, subject to UART framing and text limitations.
- Native, larger-than-RAM file storage would require an OS patch to redirect the directory/file API or provide a new command/extension mechanism, especially as the existing editor assumes memory-resident files. No arbitrary RAM-code loader is yet proven.

## Evidence and reproducibility

Use \`python3 tools/verify_transfer.py\` to check the key control-flow opcode bytes directly against the preserved original ROMs. Source labels are documented in \`firmware/LEX31_full_annotated.asm\`.

**Remaining unknowns:** exact keyboard matrix-to-key legend assignments, the serial hardware's RTS/CTS wiring, handling of embedded NUL/nonprintable characters through SAVE, and whether special-format text is honored in every communications mode.
