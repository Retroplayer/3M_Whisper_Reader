# LEX-31 OS architecture — research notes

Source: original 2732 dumps from red U2, green U3, white U4; address placement inferred from call references. These are reverse-engineering hypotheses unless described as byte-verified.

## ROM entry points

| Address | Observed function |
|---|---|
| `0000h` | Reset: disable interrupts, initialize port 47h, stack at 4800h |
| `0010h` | RST 10h: load HL from (4654h), DE from (4656h) |
| `0018h` | RST 18h: jump to display routine at 0867h |
| `0020h` | RST 20h: load storage pointers from (4594h) and (4669h) |
| `0028h` | RST 28h: jump to indicator set routine 0A34h |
| `0038h` | RST 38h: 16-bit compare, HL versus DE |
| `017Eh` | Periodic service: keyboard, serial, indicator, timer update |
| `0238h` | Mode-dependent keycode command resolver |

### Main loop execution convention

```z80
00E8 CALL 0238h      ; Resolve handler
00EB JR NC,00F5h     ; No handler
00ED LD DE,00E3h     ; OS-loop continuation
00F0 PUSH DE
00F1 JP (HL)         ; Execute chosen handler
```

The dispatcher contains 29 command groups and 88 mode/handler entries. Currently decoded targets point into main ROM. The indirect jump **does not establish** support for arbitrary RAM execution. An extension hook would need to respect this calling convention, stack use, OS variables, and interrupt state.

## RAM

- `4000h–47FFh`: working-RAM variables, buffered I/O, state and document directory.
- `4800h`: document storage starts here in initialization code at `1E86h`.
- `4593h`: number of document directory entries.
- `4594h`: document space pointer.
- `4596h`: calculated available storage.
- `4598h` onward: 6-byte directory records.
- `4665h`: detected upper RAM boundary.

The firmware probes writable RAM dynamically. A ROM placed in a socket normally populated by SRAM may simply terminate RAM detection; this is **not proof** of a boot/option-ROM protocol. Do not make every RAM chip nonvolatile until cold-boot and retained-state handling is verified: the document directory is in the working region.

## Outstanding questions

1. Where are all hardware initialization and interrupt dispatch paths?
2. Which I/O ports select the MM58167 RTC?
3. Can data received through serial communications be loaded into RAM as executable bytes?
4. What is the OS ABI for hardware calls (register input/output, clobbers, carry/error semantics)?
5. Which DB-37 lines expose the NSC800 bus and which address ranges could be decoded externally?
6. Is the customer-option UV EPROM in the German example a table, code, or a customer-specific main-ROM modification?

No unsupported pinout or OS loader should be assumed.


## Kernel-facing ROM services (additional disassembly)

The ROM dedicates several NSC800/Z80 restart vectors to callable OS services. These are actual instruction entrypoints; register preservation still needs a complete ABI audit.

| Entry | ROM operation | Parameters/results identified |
| --- | --- | --- |
| \`RST 08h\` (\`0008h\`) | Jump to \`0879h\`, set LCD logical cursor state and send DDRAM address | Input A is cursor address, ORed with \`80h\` for HD44780 command |
| \`RST 10h\` (\`0010h\`) | Read 16-bit OS state registers | Output HL = \`(4654h)\`, DE = \`(4656h)\` |
| \`RST 18h\` (\`0018h\`) | Reset/clear text LCD viewport via \`0867h\` | Altered display/cursor state |
| \`RST 20h\` (\`0020h\`) | Read document pointers | Output DE = \`(4594h)\`, HL = \`(4669h)\` |
| \`RST 28h\` (\`0028h\`) | Set bits in software indicator shadows and hardware output latches through \`0A34h\` | Input HL = 16-bit set mask |
| \`RST 30h\` (\`0030h\`) | Display nibble-compressed ROM message | Input HL = compressed text address; scratch buffer \`4013h\` |
| \`RST 38h\` (\`0038h\`) | Compare 16-bit HL against DE and set flags | \`CP H\` followed by \`CP L\` if upper bytes match; do not treat as full ordering compare without further flags audit |

**Important:** NSC800 hardware interrupts are fixed at \`002Ch\` (RSTC) and \`0034h\` (RSTB), separate from these software restart services. Interrupt control \`OUT (BBh),06h\` enables both. The RSTB entry jumps to \`C000h\`, but no loaded code or external memory map at that location has been established.

### Packed-text OS UI

- \`08CBh\`: nibble-packed message decoder, using character tables \`0939h\`/\`0945h\` and eight shared phrases beginning \`096Ch\`.
- \`0925h\`: reads alternating high and low four-bit symbols, tracking nibble state at \`4508h\`.
- \`09F0h\`: sets \`DE=4013h\` and starts decoding text pointed to by HL.
- The boot path displays the ROM's version string \`v2.1\` at \`112Fh\`; command menus and help messages use the same compressed-text interface.
- In the Dow Jones path, UI prompts select \`djns pwd\` (ROM \`1134h\`, RAM string \`4611h\`) or \`user pwd\` (ROM \`113Bh\`, RAM string \`462Fh\`). Distinct on-device credential buffers are proven; remote authentication behavior remains to be traced.

### Additional lookup tables and code-execution restrictions

A simpler lookup at \`027Bh\` uses three-byte entries \`[keycode, little-endian pointer]\`. It serves several purposes:

- \`10C0h–10DBh\`: nine executable function pointers, called from \`2986h\` then executed through \`JP (HL)\` at \`298Dh\`.
- \`10DCh–10E8h\`: four similar entries, direct caller not yet found.
- \`10E9h–112Eh\`: 23 *data pointers*, selected at \`2003h\`. The caller reads \`(HL)\` at \`200Bh\` rather than jumping to it.

Ten known \`JP (HL)\` instructions have been checked; their traced callers use the OS command resolver or these ROM tables. **No generic arbitrary-RAM program loader has yet been demonstrated.** The only verified jump beyond the standard ROM+RAM map is the interrupt vector \`JP C000h\`; the physical bus decoder still needs tracing.

See [OS message decoding and dispatch analysis](OS_message_and_dispatch_analysis.md), [message index](LEX31_OS_messages.csv), and [message decoder](../tools/decode_messages.py).
