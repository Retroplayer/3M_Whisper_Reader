# LEX-31 / 3M Whisper Reader — Windows emulator (v0.1.7 preview)

**Early-access, experimental software.** This is a functional Z80-based emulator/debugger running the **unmodified original ROMs** of the 3M Whisper Reader / Lexicon LEX-31. It is not cycle-accurate and several devices and applications remain provisional. Reports of working and broken features are welcome.

## Quick start (Windows 10/11)

1. Download/clone the **whole repository** (the ROM dumps are in `roms/original/`).
2. Install **Python 3.11+** and enable the `py` launcher. Tkinter is included in ordinary Python.org Windows installers.
3. Open the `emulator` folder and double-click `START_EMULATOR.bat`. It creates a local virtual environment and installs the `z80-python` CPU core on its first run.
4. Click **Run**. Use the photographed virtual keyboard to navigate the original OS. If the CPU is paused, a queued key won't be processed until you resume.

For command-line usage:

```sh
python -m pip install -r emulator/requirements.txt
python emulator/lex31_gui.py
python emulator/lex31_gui.py --headless --steps 150000
```

Run `python -m unittest discover -s emulator/tests -v` for CPU-independent regression tests.

### Standalone use and ROM files

The application looks for `emulator/roms/red_u2.bin`, `green_u3.bin`, and `white_u4.bin`; if absent, it uses the **existing repository** copies at `roms/original/`. It concatenates these in U2+U3+U4 order. Alternatively pass `--rom path/to/combined_12KiB.bin`. The factory ROM SHA-256 is `0b395efd163f70127adfdbd5b234e1f5ee5ff490c8e7386b5c7f5b9faa4b6b12`.

The emulator does **not** write to these ROM files or modify firmware bytes. It models the hardware in Python. For 40×2 experimentation, consult the separate `patches/40x2` research directory.

## Key usage

- **Shift → CHG**: LOCAL / editor. **Shift → PW**: SET / configuration. **Shift → GO**: CALC. **Shift → XIT**: SEND. **Shift → CLR**: SAVE.
- In the SET menus, **CHG** selects and **XIT twice** leaves/saves. PC Enter works as a convenience alias for CHG only in those menus; normal Enter still generates `0Dh`.
- The clock-setting screen uses arrow keys to choose/change fields — numeric typing is not supported by the original ROM.
- Shift/CTL on the virtual keyboard are one-shot buttons. The OS receives translated key codes via its RAM queue (not a raw matrix electrical simulation).

## Current coverage and limitations

- Factory 40×1 HD44780-like LCD model, underline cursor, scrolling, preliminary status output; glyph pixels and blink not exact.
- RTC initialized to host local date/time and advances with elapsed time; **alarm comparator/interrupts are incomplete**. File menu can resynchronize RTC to PC.
- RAM retention across warm reset; cold start resets the RAM and the RTC.
- Selectable simulated low battery. I/O port mapping is **hypothetical**, not a board-verified electrical pin assignment.
- Serial, modem, printer, status annunciator bits and peripheral timings are still incomplete. NSC800-specific interrupts/bus timing may differ from the `z80-python` core.
- Tests mostly use a fake CPU and mocked device time; they do not establish complete application compatibility on Windows.

## Bug reports

Use the repo's [Issues](https://github.com/Retroplayer/3M_Whisper_Reader/issues). Include your Windows/Python version, emulator version (0.1.7), original or custom ROM, reproduction steps, what the display says, and the **Events / I-O** tail from the GUI (omit any personal information). If a feature differs from a real device, include a reference to the page of the owner's manual and/or a photograph.

Development notes, disassembly, memory maps and hardware research live in the main repository. Contributions and hardware verification are welcome. No license is asserted by this preview; the repository owner should select one before accepting code contributions.
