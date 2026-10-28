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
