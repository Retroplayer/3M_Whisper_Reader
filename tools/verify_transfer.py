#!/usr/bin/env python3
"""Validate documented LEX-31 SEND/SAVE/format control flow from original EPROMs.

Usage: python3 tools/verify_transfer.py

Checks fixed instruction signatures, not physical UART behavior or runtime operation.
"""
from pathlib import Path

ROOT=Path(__file__).resolve().parent.parent
ROM=b"".join((ROOT/"roms"/"original"/n).read_bytes()
             for n in ("red_u2.bin","green_u3.bin","white_u4.bin"))
assert len(ROM)==12288

CASES={
    "send literal sets bypass":(0x1973,"3e ff 32 1f 45"),
    "normal send entry":(0x1978,"d7 22 6c 46"),
    "directory selects formatted/literal":(0x19B7,"3a 1f 45 b7 28 09"),
    "literal source pointer/count":(0x19BD,"ed 53 21 45 22 23 45"),
    "formatted invokes parser":(0x19C6,"cd 29 1a"),
    "format parser computes end pointer":(0x1A29,"19 22 2b 45 eb 7e fe 1b c0"),
    "format search for p":(0x1A39,"fe 70"),
    "format PC/PX option table":(0x1A75,"78 25 45 63 26 45 00"),
    "SAVE toggles active flag":(0x1A7C,"21 14 45 7e 36 00 b7"),
    "SAVE sets active flag":(0x1AD6,"3e ff 32 14 45"),
    "received prompt check":(0x18E0,"3a 25 45 a8 20 03 32 17 45"),
    "receive ENQ/Y":(0x1B7A,"fe 05"),
    "file Y selection":(0x1B88,"3e 59 cd 14 1d"),
    "SAVE staged line source":(0x1B34,"11 13 40"),
    "SAVE appends CR":(0x1B45,"36 0d c3 e4 1c"),
    "TX status gating":(0x1BFE,"db 5f cb 57 c8 cb 67 c0"),
    "literal bypass processing":(0x1C6D,"4f 3a 1f 45 b7 20 23"),
    "PC character comparison":(0x1C79,"3a 26 45 b7 28 18 b9 20 15"),
    "PC programmed timer":(0x1C82,"21 71 02 22 28 45 c9"),
    "CR special file Z":(0x1C89,"d7 cb 53 28 09 3e 5a cd 14 1d"),
    "transmit data port":(0x1C97,"79 d3 5b"),
    "selected record pointer":(0x1CD0,"23 23 5e 23 56 ed 53 21 45"),
    "document append length update":(0x1CE4,"2a 9c 45 23 22 9c 45"),
    "countdown decremented by periodic IRQ":(0x018E,"2a 28 45 7c b5 28 04 2b 22 28 45"),
}

for name,(address,hexbytes) in CASES.items():
    expected=bytes.fromhex(hexbytes)
    actual=ROM[address:address+len(expected)]
    if actual!=expected:
        raise SystemExit(f"FAIL {name} @ {address:04X}: {actual.hex(' ')} != {expected.hex(' ')}")
    print(f"PASS {address:04X}: {name}")
print(f"All {len(CASES)} original-ROM signatures matched.")
