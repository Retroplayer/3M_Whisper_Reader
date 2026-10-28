# Experimental HD44780 40×2 initialization patch

Original: Hitachi H2572, 40×1, 5×10-dot characters; replacement: single-enable HD44780-compatible 40×2 module.

Original U2 code around `0643h` loops through command bytes at `0653h`, sending each through the LCD command writer `0760h` until the NUL terminator.

```z80
0643 LD HL,0653h
0646 LD A,(HL)
0647 OR A
0648 JR Z,0659h
064A LD (44F6h),A
064D CALL 0760h
0650 INC HL
0651 JR 0646h
0653 DB 34h,34h,01h,06h,0Eh,00h
```

**Only for a first test**, replace U2 offsets `0x653` and `0x654` (`34h`) with `38h` for 8-bit, 2-line, 5×8 initialization. Do not patch U3/U4.

```python
from pathlib import Path
import hashlib

original = Path("roms/original/red_u2.bin").read_bytes()
assert len(original) == 4096
assert hashlib.sha256(original).hexdigest() == "7ff2ab423b202d3755f8ffbe06c5804412252459ea7434f99c1ba4bce2020e14"
assert original[0x653:0x659] == bytes.fromhex("34 34 01 06 0E 00")
patched = bytearray(original)
patched[0x653] = 0x38
patched[0x654] = 0x38
Path("red_u2_40x2_TEST.bin").write_bytes(patched)
assert hashlib.sha256(patched).hexdigest() == "4448adeac699e5d47ab2d0875ace700e7171c30648e1c171c29adf07ce5dff1d"
```

**Limitations:** untested on physical hardware; this changes only the initialization, not the OS's one-line character viewport, DDRAM layout or editor. Preserve originals and use a spare EPROM / emulator.
