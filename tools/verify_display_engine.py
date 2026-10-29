#!/usr/bin/env python3
"""ROM-level regression checks for LEX-31 editor/view and playback code.

python3 tools/verify_display_engine.py

Checks original opcodes and source-of-truth ROM checksums. This verifies code
locations; it is NOT equivalent to dynamic Z80 execution or a hardware test.
"""
from pathlib import Path
import hashlib

ROOT=Path(__file__).resolve().parent.parent
NAMES=("red_u2.bin","green_u3.bin","white_u4.bin")
rom=b"".join((ROOT/"roms"/"original"/p).read_bytes() for p in NAMES)
assert len(rom)==0x3000
assert hashlib.sha256(rom).hexdigest()=="0b395efd163f70127adfdbd5b234e1f5ee5ff490c8e7386b5c7f5b9faa4b6b12"

# address, expected bytes, significant meaning
checks=[
 (0x22b6,"2a 83 45 22 8f 45","save logical horizontal column"),
 (0x22cb,"cd b6 22","previous DB was actually CALL 22B6h"),
 (0x233b,"2a 69 46 16 00 3a 04 40 5f 47 b7 ed 52 23","start=cursor-screen_column+1"),
 (0x2349,"af cf","LCD column zero"),
 (0x235b,"3e 20 cd 55 07","print space at editor cursor"),
 (0x2360,"3e 28 90 47","40 minus cursor column"),
 (0x2366,"ed 5b 94 45 ff","compare to document allocator end"),
 (0x2373,"7e cd 55 07","draw right-of-cursor character"),
 (0x2377,"3e 0d be","stop on carriage return"),
 (0x2384,"3a 04 40 3d cf","restore physical cursor"),
 (0x23d3,"21 04 40 3e 28 be","clamp visible column at 40"),
 (0x2466,"21 00 00 22 83 45","clear logical current-line column"),
 (0x249b,"e7 ff 37 3f c8","forward-step checks EOF with carry flags"),
 (0x24b0,"2a 69 46 ed 5b 9a 45 ff 37 c8","backward-step checks document beginning"),
 (0x24e2,"cd b0 24 c0 d8","left cursor movement via 24B0"),
 (0x2591,"e7 ff 28 29","down cursor movement checks end"),
 (0x25d7,"21 39 45 7e b7 36 00","up movement and line-transition flag"),
 (0x2689,"e5 ed 5b 69 46 2a 9a 45 ff","scan prior text for status arrows"),
 (0x26b3,"e5 ed 5b 69 46 2a 94 45 ff","scan subsequent text for status arrows"),
 (0x20c2,"01 00 00 11 63 40","receive-buffer playback source"),
 (0x20cf,"22 0e 45 32 09 45","playback source length/type"),
 (0x2125,"af 32 12 45 3c 32 11 45","playback segment count/active flag"),
 (0x214d,"fe 27 47","39-character playback threshold"),
 (0x21a6,"cd 14 22 b7 c8 fe 0d","rewind playback across CR"),
 (0x21c5,"2a 0e 45 eb 2a 0c 45","next playback byte from source"),
 (0x2214,"2a 0c 45 7c b5","previous playback character/index"),
 (0x06aa,"3a 02 40 fe 27","LCD stream right-edge scroll"),
 (0x0805,"06 13 3e 80","modal LCD save 20 character pairs"),
 (0x0830,"06 13 0e 26","modal LCD restore 20 character pairs"),
]
for address,hexbytes,label in checks:
    expected=bytes.fromhex(hexbytes)
    found=rom[address:address+len(expected)]
    if found!=expected:
        raise SystemExit(f"FAIL {label} @{address:04X}: got {found.hex(' ')}, expected {expected.hex(' ')}")
    print(f"PASS {address:04X} {label}")
print(f"All {len(checks)} display-engine signatures match original ROM images.")
