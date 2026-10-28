# LEX-31: MM58167 clock driver and NSC800 interrupt vectors

**Evidence:** original U2 `red_u2.bin` ROM bytes, 1980 National NSC800 Microprocessor Family Handbook and National MM58167 MM58167B datasheet. The ROM functions below are directly decoded; precise PCB traces/pin connections have not yet been measured.

## Discovery: port 47h bit 6 switches in MM58167 registers at 4000h–401Fh

The RTC has five address lines A0–A4 and 8-bit data. U2 firmware provides memory-mapped access to the RTC by temporarily setting bit 6 on shared output port `47h`:

```
0BED  DI
0BEE  LD A,(4000h)       ; saved port-47 shadow (ordinary working RAM)
0BF1  LD C,A             ; preserve value
0BF2  OR 40h             ; select RTC address window
0BF4  RET

0BE3  PUSH DE            ; RTC_WRITE_REGISTER, HL=4000h+register, B=value
0BE4  PUSH BC
0BE5  CALL 0BED
0BE8  OUT (47h),A
0BEA  LD (HL),B          ; RTC write
0BEB  JR 0BDB

0BCC  PUSH DE            ; RTC_READ_REGISTER, HL=4000h+register
0BCD  PUSH BC
0BCE  CALL 0BED
0BD1  OUT (47h),A
0BD3  LD DE,4014h       ; status-bit register (RTC address 14h)
0BD6  LD B,(HL)          ; read counter/status/clock RAM
0BD7  LD A,(DE)         ; RTC rollover status
0BD8  RRCA               ; put bit 0 in carry
0BD9  JR C,0BD6         ; retry if time incremented mid-read
0BDB  LD A,C
0BDC  OUT (47h),A       ; de-select RTC, restore original control value
0BDE  EI
0BDF  LD A,B            ; result
0BE0  POP BC
0BE1  POP DE
0BE2  RET
```

The check of `4014h` is a high-confidence identification: the MM58167's address `14h` is specifically its **rollover status bit** (see National datasheet Table III). Further, `0AE2h` reads `4002h` via this routine; MM58167 address `02h` is **seconds**. The low nibble is then tested for zero. This rules out these accesses being ordinary SRAM reads.

The same physical memory addresses are normally working RAM: e.g. `4000h` is the port-47 control shadow and `4011h` is used elsewhere as an OS variable. The RTC's registers are visible for a very short interval only, while port 47h bit 6 is set.

A practical implication for NVRAM expansion: the original SRAM and RTC are not simultaneously enabled over this range. Any replacement memory decoder must preserve this overlay behavior.

## RTC access table

The 13-byte table at `0C1Bh` is:

| List index | RTC register offset | MM58167 function | Saved at |
|---:|---:|---|---|
| 0 | 05h | Day of week | 4658h |
| 1 | 07h | Month | 4659h |
| 2 | 06h | Day of month | 465Ah |
| 3 | 0Ah | Alarm RAM — seconds | 465Bh |
| 4 | 09h | Alarm RAM — hundredths/tenths | 465Ch |
| 5 | 04h | Hours | 465Dh |
| 6 | 03h | Minutes | 465Eh |
| 7 | 02h | Seconds | 465Fh |
| 8 | 0Fh | Alarm RAM — month | 4660h |
| 9 | 0Ch | Alarm RAM — hours | 4661h |
| 10 | 0Bh | Alarm RAM — minutes | 4662h |
| 11 | 0Dh | Alarm RAM — day of week | 4663h |
| 12 | 0Eh | Alarm RAM — day of month | 4664h |

At `0BF5h`, the firmware loops over this table and calls `0BCCh`, copying the results into contiguous RAM beginning `4658h`. `0C28h/0C2Ch` perform the reverse write, with special handling for register 06h (day of month). This implies the clock UI holds an editable software copy and commits it to the RTC.

`0B6Ch` resets/initializes the RTC using registers 10h (read interrupt status), 11h (interrupt control), 12h (reset counters), 13h (reset alarm RAM), 15h (GO), and 16h (standby interrupt control). The adjacent 13-byte table at `0BBFh` is an initial BCD value set. That initialization is called by firmware at `1EA4h`, on the system's state-initialization path, **not necessarily on every warm reset**.

The MM58167 has an interrupt output and a standby interrupt output, but the physical wiring of these lines to the NSC800 remains unproven.

## NSC800 hardware interrupt vectors, previously omitted by CFG disassembler

National's NSC800 handbook specifies three dedicated maskable restart lines:

| Hardware input | Fixed vector | Original bytes | Behavior |
|---|---:|---|---|
| RSTC | 002Ch | `C3 7E 01` | `JP 017Eh` — periodic keyboard/serial/status service |
| RSTB | 0034h | `C3 00 C0` | `JP C000h` — destination outside available ROM and documented 16 KB RAM |
| RSTA | 003Ch | `BD C9` | Midway through a software comparison routine: would execute `CP L; RET` if triggered; likely unused/masked |
| NMI | 0066h | `C3 66 00` | `JP 0066h` — infinite lock-up loop |
| INTR mode 1 | 0038h | `7A BC C0 7B BD C9` | Firmware uses the vector as a software `RST 38h` 16-bit comparison service; no general interrupt handling there |

**CPU interrupt mask discovered:** The NSC800 has a special **internal** interrupt control register at I/O port `BBh` (National datasheet, interrupt control section). The firmware writes `06h` to this register at `007Eh` during startup and again at `021Fh` before exiting the periodic service. `06h = 00000110b` enables **RSTC and RSTB**, and masks RSTA and INTR. At the start of the ISR (`0180h`) it writes `00h` to disable all four maskable interrupt sources. Thus the path to `C000h` is not dead code solely because the ROM otherwise lacks direct calls there: its **RSTB hardware source is explicitly unmasked**. Whether a device asserts RSTB and what hardware is mapped at C000h are still open questions.

This establishes that `017Eh` **is entered from the NSC800 RSTC interrupt vector**. It does not establish which physical device drives RSTC. In fact, its prologue and epilogue access I/O ports `BBh` and `63h`, and it does **not** read the MM58167 interrupt status at `4010h` during each service. That makes it unsafe to assert the RTC is the interrupt source without PCB evidence.

`JP C000h` is a concrete high-address firmware reference that was missed by the original disassembler. **RSTB is enabled in the ICR**, but there is no proof that usable ROM or RAM was present at C000h, or that any device actually asserts RSTB. Do not equate this with a general-purpose expansion-ROM loader.

## Practical driver ABI, from code

- `RTC_READ_REGISTER (0BCCh)`: input HL=`4000h + 5-bit offset`; output A=byte read; BC/DE restored; disables interrupts during transaction then uses `EI` on exit; HL preserved by shown routine.
- `RTC_WRITE_REGISTER (0BE3h)`: input HL=`4000h + 5-bit offset`, B=data; restores BC/DE, leaves A=data, uses `EI` on exit.
- `RTC_READ_TIME_BLOCK (0BF5h)`: copies 13 registers into `4658h..4664h` in firmware-defined order; clobbers IX, B, DE, HL, A. The RTC read helper itself restores BC/DE.
- `RTC_WRITE_TIME_BLOCK (0C28h)`: writes the 13 software values back to the RTC; modifies `44F9h` and potentially `4011h`.

**Caveat:** the use of unconditional `EI` means these functions are not safe to call from an interrupt-disabled critical section without preserving interrupt state. Expansion code must account for this.

## Source verification

Annotated assembly generated from original dumps, 4620 identified instruction starts, 8641 executable bytes / 3647 explicit data bytes. Reassembling with the repository's source verifier yields SHA-256 `0b395efd163f70127adfdbd5b234e1f5ee5ff490c8e7386b5c7f5b9faa4b6b12`, identical to the three concatenated original EPROMs. This verifies faithful source coverage, not every semantic interpretation.