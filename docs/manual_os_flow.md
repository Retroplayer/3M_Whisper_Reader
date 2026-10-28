# 3M Whisper Reader Owner's Manual: OS behavior mapped to ROM

**Primary evidence:** *Whisper Reader Personal Communications Data Terminal, Owner's Manual*, 3M Business Communications Products. The owner supplied an 87-page scanned copy. Page numbers here are the **printed manual page numbers**, not PDF viewer page numbers. This document summarizes behavior, rather than redistributing the copyrighted manual.

**ROM comparison:** original red U2 (0000h–0FFFh), green U3 (1000h–1FFFh), white U4 (2000h–2FFFh), in the assembled LEX-31 source. Code addresses below are grounded in those ROM bytes; behavioral explanations from the manual are marked as such.

## User-visible OS states and transitions

| State / activity | Entry from manual | Exits / submodes | Manual pages | Firmware evidence |
| --- | --- | --- | --- | --- |
| Cold start / authentication | Power on; enter Personal Access Password | Normal interactive interface; memory kill switch completely resets sensitive stored information | 19, 40, 66 | Boot at 0000h; compressed prompts; authentication implementation still to be traced |
| Online terminal | Connect phone; MODE switch ORIGINATE/ANSWER/WAIT, communications switch ACOUSTIC/TALK/DIRECT | Local editor, playback, indexing, DJ, send/save | 19, 26–27, 36–39 | UART receive at 18A9h/18DCh; TX at 1C98h; modem controls still being mapped |
| Local editor | SHIFT+LOCAL; select a one-character document label | Editing, playback, search, index, return via XIT | 21, 28–29, 75–82 | Document directory at 4593h–; editor control routines in U4 |
| Index | INDEX; list files by label and size with free-memory count | UP/DOWN select, CLR delete with confirmation, XIT | 30, 82 | Directory lookup at 1D14h; records are six bytes |
| Playback / review | ALL or arrow keys in ONLINE; ALL in editor | GO resumes, arrow freezes, XIT exits | 26, 28, 80 | Output buffering and document transmit routines, individual mode branches unresolved |
| Configuration | SHIFT+SET, CHG; option selection with arrows | XIT twice | 23, 25, 59–70 | Packed message interpreter at 08CBh; command dispatch at 0238h |
| Clock / alarm | SHIFT+SET; RIGHT once CLOCK or twice ALARM then CHG | Edit time/date/alarm; XIT twice | 23–24, 59, 71–72 | MM58167 window selected by port 47h bit 6; driver 0BCCh/0BE3h; calendar correction 0E75h |
| Calculator | SHIFT+CALC | XIT; CTL+CALC copies result into editor | 31, 85–89 | Dedicated command/mode handlers not yet semantically mapped |
| HELP | HLP, then function key; XIT; CTL+HLP bypass | Return to previous state via XIT | 11, 47 | Packed strings/phrase dictionary at 0939h–09D6h; help-data pointer lookup at 10E9h |
| DJ sign-on | DJ (or CTRL+DJ for sign-on only) during login | Portfolio processing, saved session output | 19–20, 46, 70 | Command 80h/C0h dispatch; hard-coded DOW1;; strings at 0543h; user credential buffers |

These are **user interface states**, not necessarily separate RAM modes. The precise numeric value in working-RAM state variable 4507h needs tracing against each handler.

## Normal file system: 20 one-character names

- The editor accepts a **single letter, numeral, or punctuation mark** as a file label (printed pp. 21, 75). Limit: **20 files** (p. 75).
- INDEX displays labels, file sizes, and available memory and can delete a file after confirmation (pp. 30, 82).
- ROM: count at 4593h; directory starting at 4598h with six-byte entries; lookup at 1D14h; search by ASCII file identifier; data blocks have address and length fields. The editor/document allocation code computes usable RAM from the boot-time probe.
- Do **not** treat all named services as normal one-character files. The manual calls the DJ received-session storage **memory "dj"**, which is not a normal one-character label. We have not established how it is implemented.

### Special file X — Dow Jones portfolio

- During DJ login the terminal accesses the user's portfolio from file \`X\` (printed p. 20).
- CTL+DJ signs on **without updating/processing the personal portfolio** (pp. 20, 46).
- The networking setting selects TYMNET or TELENET, and is specifically used by the DJ procedure (p. 70).
- ROM's built-in \`DOW1;;\` script and separate DJ/user-password prompts are consistent with this behavior. Exact authentication and X-file processing are not yet fully traced.

### Special file Y — ENQ automatic answer-back (confirmed ROM match)

- Configuration \`answer-back <on/off>\`: when on, the device responds to ASCII ENQ by transmitting the **entire contents of file Y** (printed p. 69).
- At **1B7Ah** ROM tests \`CP 05h\` (ASCII ENQ). After control/status tests it loads \`LD A,59h\` at **1B88h** (ASCII Y) and calls directory lookup at **1B8Ah** (\`CD 14 1D\`).
- This is a high-confidence semantic identification of the ENQ / Y-file answerback routine, not merely a guess from an ASCII constant.

### Special file Z — programmable end-of-line (confirmed ROM match)

- Configuration \`end-of-line-sequence <carriage-return / memory-Z-define>\`: when selected, ENTER sends a configured sequence from file Z. The manual says it can be up to 300 characters (p. 67).
- At **1C89h** the ROM processes carriage return (\`0Dh\`), checks configuration bit 2 of E, then loads \`LD A,5Ah\` at **1C8Eh** (ASCII Z) and calls directory lookup at **1C90h**.
- On success, it initializes a transfer using the selected document's pointer and length at **1CCCh**; otherwise falls back to transmitting CR.
- This identifies the significance of the previously mysterious Z lookup and shows document records are reusable by an OS communications feature.

## Transmission and receive processing

| User feature | Manual | ROM lead / verification |
| --- | --- | --- |
| SHIFT+SEND | Choose file, transmit using normal configured processing | Printer-style output path is separate; follow document sender and format interpreter |
| CTL+SEND | Send an **exact image** without special processing | The normal/RAW dispatch split must be located; do not assume which branch until traced |
| SHIFT+SAVE | Start capturing incoming online data to named file; press again to stop | Receive queue and directory/editor writer to be mapped |
| XON/XOFF | Configurable; XOFF pauses transmission and XON resumes | Receiver tests 13h at 1933h, updates pause flag 4517h; XON handling still to trace |
| Programmable pause | A file's format line may include \`PC = $\` to insert a delay at each '$' | Format-line parser and delay timer remain to be identified (pp. 50–51) |
| Programmable prompt | Format line may contain \`PX = +\`, specifying expected prompt | Locate input compare/wait loop (p. 52) |
| End-of-line memory-Z | In configured mode, ENTER transmits Z contents | Identified at 1C89h–1CCCh |
| Automatic answer-back | ENQ triggers file Y | Identified at 1B7Ah–1B96h |

The manual calls the first line of a file a special **FORMAT** line when it contains clauses; editing uses it for margin-warning settings and programmed pauses/prompts. That line is ordinary stored text, with an OS interpreter on transmission (pp. 29, 50–52, 78).

## Screen and annunciator behavior

- Main display is **40×1**, with a movable viewport over longer text; arrow keys move the cursor and *display window* independently (pp. 43–44, 76–80). A 40×2 firmware update must alter viewport logic, not merely HD44780 initialization.
- Manual p. 41–42 **positively identifies annunciator legends**: OPTIONS, ON LINE, LOCAL, MEMORY, CALCULATOR, LINE READY, SEND, SAVE, XOFF, PRINTER, LOW BATTERY, TRAFFIC, plus left/right/up/down edge indicators.
- MEMORY means at least one stored file exists; confirms mask \`0008h\` from ROM \`0A77h\` reading directory count at \`4593h\`.
- XOFF indicates transmission pause awaiting remote readiness. This supports the proposed \`2000h\` mask linked to \`4517h\`, but electrode-to-bit confirmation still requires hardware tracing.
- TRAFFIC indicates incoming or outgoing character activity; receive continues while editor is active, storing characters in the communications buffer and sounding a beep (pp. 41–42). This implies background communications processing while another UI mode owns the display.

## Memory retention and security

- Manual p. 12 explicitly describes **battery backup on memory** and states user configuration options are kept in nonvolatile storage.
- Manual p. 40 says the memory-kill switch erases **all** file data and Personal Access Password; it is intended for a lost password recovery.
- **Do not infer** from the owner's-manual wording that all SRAM can be swapped for NVRAM or that configuration is physically EEPROM. Identify the retention power rail and initialization pathways in hardware and the ROM.
- The presence of a stored directory in working RAM remains a key issue for selective NVRAM replacement.

## Manual gaps / remaining reverse engineering

1. No DB-37 PERIPHERALS pinout or documented CPU-bus expansion ABI is given in the examined owner instructions. The connector's decoder and \`C000h\` interrupt vector remain physical/firmware investigation tasks.
2. The owner manual does **not** describe an OS command to load and execute user Z80/NSC800 code from RAM. Absence of user documentation does not prove the capability is impossible; ROM analysis is required.
3. The exact function-key numeric keycodes and OS operating-mode indices are not printed in this manual.
4. The manual's communications service rules refer to a **modem** (300/110 baud) with AC/telephone modes; avoid assuming the DB-37 is that interface.
5. This manual is for the **3M Whisper Reader**. The inspected LEX-31 hardware/ROM matches major functions, but a firmware revision or customer-specific build could differ; record differences during power-on testing.

## Next source-level tasks

- Name and annotate \`1B7Ah–1B96h\` **ENQ_FILE_Y_ANSWERBACK** and \`1C89h–1CCCh\` **CR_FILE_Z_EOL_EXPANSION**.
- Trace both SHIFT+SEND and CTRL+SEND through the dispatcher; compare byte output paths to locate RAW vs formatted transfers.
- Locate parser for \`PC =\`, \`PX =\` and end-of-line handling; link format-line storage to six-byte directory entries.
- Trace file X and the special DJ received-data buffer to separate ordinary document storage from service-specific data.
- Trace HELP key dispatch through \`10E9h\` data table and the packed message decoder.
- Label GUI operating-mode transitions using the manual as semantic ground truth, keeping numeric RAM-mode assignments unverified until traced.
