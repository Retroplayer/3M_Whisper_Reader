#!/usr/bin/env python3
"""LEX-31 nibble-packed message decoder (ROM: 08CBh/08F7h/0925h).

Usage:
  python3 tools/decode_messages.py 0x112F
  python3 tools/decode_messages.py --list
ROMs must be in roms/original/.
"""
import argparse
from pathlib import Path
import re

BASE=Path(__file__).resolve().parent.parent
NAMES=("red_u2.bin","green_u3.bin","white_u4.bin")
ROM=b"".join((BASE/"roms"/"original"/name).read_bytes() for name in NAMES)
assert len(ROM)==0x3000, "Expected 3 x 4 KiB EPROM images"
CHARS=ROM[0x0939:0x096c]
PHRASES=ROM[0x096c:0x09d6].split(b"\x00")

def decode(addr, max_bytes=256):
    """Return expanded string, address after encoded data, consumed nibbles."""
    p=addr
    high=True
    text=[]
    count=0
    def read_nibble():
        nonlocal p,high,count
        if p >= len(ROM) or p-addr >= max_bytes:
            raise ValueError("No terminator or ROM boundary reached")
        v=(ROM[p]>>4) if high else (ROM[p]&15)
        if not high: p+=1
        high=not high
        count+=1
        return v
    while True:
        n=read_nibble()
        if n==12: # terminator
            if not high: p+=1
            return "".join(text),p,count
        if n<12:
            text.append(chr(CHARS[n]))
        else:
            nxt=read_nibble()
            if n==15 and nxt>=7:
                text.append(PHRASES[nxt-7].decode("latin-1"))
            else:
                text.append(chr(CHARS[(n-13)*16+nxt+12]))

def refs(source):
    lines=source.read_text().splitlines()
    pattern=re.compile(r"^\s*LD HL,([0-9A-F]{4})h.*?; @([0-9A-F]{4})\b")
    known=("RST 30h","CALL loc_003F","CALL loc_08CB",
           "CALL loc_09F0","CALL loc_0045","JP loc_0045")
    for i,line in enumerate(lines):
        m=pattern.search(line)
        if not m: continue
        p=int(m.group(1),16)
        if not 0x1100<=p<0x3000: continue
        following=" ".join(t.split(";")[0].strip() for t in lines[i+1:i+5])
        if not any(k in following for k in known):continue
        try:
            txt,end,nibbles=decode(p)
        except (ValueError,IndexError):continue
        if txt.isprintable():
            yield int(m.group(2),16),p,txt

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument("address",nargs="?",type=lambda x:int(x,0))
    ap.add_argument("--list",action="store_true")
    args=ap.parse_args()
    if args.address is not None:
        print(repr(decode(args.address)[0]))
    if args.list:
        asm=BASE/"firmware"/"LEX31_full_annotated.asm"
        for caller,p,msg in refs(asm):
            print("%04X -> %04X: %s"%(caller,p,msg))

if __name__=="__main__": main()
