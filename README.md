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
