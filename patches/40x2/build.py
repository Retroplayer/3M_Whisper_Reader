#!/usr/bin/env python3
"""Build the experimental 40x2 LEX-31 firmware, keeping original ROMs untouched.

Run from the repository root: python3 patches/40x2/build.py
The full source and instruction-level tests are included in the associated
LEX31_40x2_functional_test.zip project archive.
"""
from pathlib import Path
import hashlib

BASE=Path(__file__).resolve().parents[2]
ORIG=BASE/"roms"/"original"
names=("red_u2.bin","green_u3.bin","white_u4.bin")
factory=b"".join((ORIG/n).read_bytes() for n in names)
assert len(factory)==12288
assert hashlib.sha256(factory).hexdigest()=="0b395efd163f70127adfdbd5b234e1f5ee5ff490c8e7386b5c7f5b9faa4b6b12"

# Byte-exact machine code assembled at 2EA0h. See module.asm.
code=bytes.fromhex("""
CD 3B 23 F5 C5 D5 E5 2A 9A 45 ED 5B
9C 45 19 EB 2A 69 46 7C BA 20 04 7D
BB 28 09 7E FE 0D 28 03 23 18 F0 23
3E C0 CD 60 07 06 28 7C BA 20 04 7D
BB 28 0D 7E FE 0D 28 08 CD 55 07 23
10 ED 18 07 3E 20 CD 55 07 10 F9 3A
02 40 F6 80 CD 60 07 E1 D1 C1 F1 C9
""")
glyphs=bytes.fromhex("""
1E 10 1C 10 1E 07 08 06
1C 12 12 12 1C 01 01 01
00 10 08 04 02 01 00 00
00 04 04 0E 0E 0E 1F 04
""")
assert len(code)==84 and len(glyphs)==32
original_glyphs=b"".join(factory[0x066F+i*11:0x066F+i*11+8] for i in range(4))
assert original_glyphs==glyphs

rom=bytearray(factory)
def patch(addr,expected,replacement):
    expected=bytes.fromhex(expected);replacement=bytes.fromhex(replacement)
    assert len(expected)==len(replacement)
    assert factory[addr:addr+len(expected)]==expected
    rom[addr:addr+len(expected)]=replacement

patch(0x0653,"34 34","38 38")       # HD44780 8-bit 2-line 5x8
patch(0x0659,"21 6F 06","21 80 2F") # glyph source at 2F80h
patch(0x0898,"06 0B","06 08")       # 8 glyph rows
patch(0x22CE,"CD 3B 23","CD A0 2E") # hook editor's LCD redraw
assert factory[0x2EA0:0x2EA0+len(code)]==bytes(len(code))
assert factory[0x2F80:0x2F80+len(glyphs)]==bytes(len(glyphs))
rom[0x2EA0:0x2EA0+len(code)]=code
rom[0x2F80:0x2F80+len(glyphs)]=glyphs

assert hashlib.sha256(rom).hexdigest()=="c35c6717eae46a16f516c5e3ad5498670da4d0d83f47359ea877bead5192e60c"

out=BASE/"patches"/"40x2"/"output"
out.mkdir(exist_ok=True)
for i,name in enumerate(("U2_red_40x2.bin","U3_green_original.bin","U4_white_40x2.bin")):
    (out/name).write_bytes(rom[i*4096:(i+1)*4096])
(out/"LEX31_40x2_experimental_combined.bin").write_bytes(rom)
print("PATCH VERIFIED:",hashlib.sha256(rom).hexdigest())
print("U2 and U4 changed, U3 unchanged. Outputs:",out)
