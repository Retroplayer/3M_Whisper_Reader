# LEX-31 I/O and peripheral map (work in progress)

**Warning:** These are firmware I/O operands and candidate software roles. Physical chip-select and DB-37 connectivity have **not** been verified by tracing the PCB.

| Port | Firmware observation | Relevant code |
|---|---|---|
| `43h` | Hardware status inputs used by indicator update | `0A9Ah+` |
| `47h` | Shared control/keyboard scan outputs and reads; shadow at `4000h` | `035Ah`, `076Ch` |
| `4Bh` | Main LCD data/status input, bit 7 polled as busy flag | `0742h–0895h` |
| `4Fh` | Indicator/status control shadow `4007h` and hardware bit tests | `0A34h`, `0A4Ah` |
| `53h` | Indicator control shadow `4006h` | `0A34h`, `0A4Ah` |
| `57h` | Special keyboard/control-code path | keyboard event processing |
| `5Bh` | Incoming/outgoing serial-oriented character data | `18DCh`, `1C98h` |
| `5Fh` | Serial/communications control and status | `18ABh`, `1932h` |
| `63h` | Initialization/communications context, meaning unknown | early startup |
| `BBh` | Accessed by periodic servicing code | `017Eh` |
| `D7h` | Buffered auxiliary/printer-like character channel; ready bit 0 | `01E7h`, `0214h` |

## Known chips

- CPU: National Semiconductor NSC800 (multiplexed AD0–AD7).
- UART: INS6402; precise decoded port and wiring not established.
- Modem: TI TMS99532; UART-to-modem path expected, not yet traced.
- RTC: National MM58167; register address and chip select not established.
- Display: Hitachi H2572 using HD44780; separate annunciator LCD on two 8-bit status shadows.

## Driver observations

- HD44780 command/output and busy polling are grouped around `0742h–0895h`.
- `0A34h` sets masked indicator bits; `0A4Ah` clears them. Mask `0008h` is conditioned on document-directory count and is a candidate for MEMORY legend; `2000h` tracks a transmission hold state and may match XOFF.
- The printer-like channel outputs text, CR/LF and 40-hyphen separators and shares text with display output, but no evidence proves it uses the DB-37.
- DB-37 has several owner-observed direct NSC800 lines. It may expose multiplexed bus signals, but **no safe connector pinout is available**.

## Required hardware verification

Trace NSC800 AD0–AD7, ALE, A8–A15, RD, WR, IO/M, WAIT, BREQ/BACK and reset to the DB-37 and decode logic. Check which I/O accesses activate MM58167 CS and UART controls. Do not connect external hardware until pin numbering and power rails are verified.
