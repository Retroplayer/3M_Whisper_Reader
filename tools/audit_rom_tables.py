#!/usr/bin/env python3
"""Generate LEX-31 ROM/hardware cross-reference indexes from untouched EPROMs.

Run from repository root:
    python3 tools/audit_rom_tables.py

Outputs docs/{configuration_fields,hardware_io_xrefs,rom_table_atlas}.csv
The assembly source is a conservative, byte-preserving disassembly, not proof
that every code/data boundary is resolved. Unknown intervals remain unclaimed.
"""
import csv
import hashlib
import re
from collections import defaultdict
from pathlib import Path

BASE = Path(__file__).resolve().parent.parent
ROM_NAMES = ("red_u2.bin", "green_u3.bin", "white_u4.bin")
ROM = b"".join((BASE/"roms"/"original"/p).read_bytes() for p in ROM_NAMES)
assert len(ROM)==0x3000
assert hashlib.sha256(ROM).hexdigest()=="0b395efd163f70127adfdbd5b234e1f5ee5ff490c8e7386b5c7f5b9faa4b6b12"
ASM = (BASE/"firmware"/"LEX31_full_annotated.asm").read_text()
OUT = BASE/"docs"
OUT.mkdir(exist_ok=True)

SETTINGS = [
 ("terminal configuration",),
 ("parity","inhibit","error detection"),
 ("character data bits","modem speed"),
 ("duplex","control characters"),
 ("alpha keyboard","beeper"),
 ("end-of-line sequence",),
 ("transmit XON mode","transmit automatic mode"),
 ("login date/time","answer-back"),
 ("network selection","clock mode"),
]
assert list(ROM[0x1855:0x185e])==list(map(len,SETTINGS))
with (OUT/"configuration_fields.csv").open("w",newline="") as f:
    w=csv.writer(f)
    w.writerow(("group","option_in_group","setting","descriptor_rom","screen_offset",
                "value_text_index","config_bit_index","config_ram","config_bit","mask"))
    n=0
    for row,fields in enumerate(SETTINGS):
        for col,name in enumerate(fields):
            address=0x185e+3*n
            screen,text_id,index=ROM[address:address+3]
            w.writerow((row,col,name,f"{address:04X}",f"{screen:02X}",
                        f"{text_id:02X}",index,f"{0x4654+((index>>3)&3):04X}",
                        index&7,f"{1<<(index&7):02X}"))
            n+=1
    assert n==17 and 0x185e+3*n==0x1891

port_rows=[]
coverage=bytearray(0x3000)
for line in ASM.splitlines():
    m=re.match(r"^\s*(.*?)\s*; @([0-9A-F]{4})  ([0-9A-F]{2}(?: [0-9A-F]{2})*)",line)
    if not m:
        continue
    ins,addr,raw=m[1].strip(),int(m[2],16),bytes.fromhex(m[3])
    assert ROM[addr:addr+len(raw)]==raw
    for i in range(len(raw)):
        coverage[addr+i]+=1
    if not ins.startswith(("IN ","OUT ")):
        continue
    p=re.search(r"\(([0-9A-F]{2})h\)",ins)
    port=p[1] if p else ("(C)" if "(C)" in ins else "UNKNOWN")
    port_rows.append((port,f"{addr:04X}",ins,"byte-preserving annotated ROM"))
assert all(v==1 for v in coverage),"Annotated source has missing/duplicate byte addresses"
assert len(port_rows)==51,"Unexpected immediate port-access count"
with (OUT/"hardware_io_xrefs.csv").open("w",newline="") as f:
    w=csv.writer(f);w.writerow(("port_hex","rom_addr","instruction","source"))
    w.writerows(sorted(port_rows))

# End addresses are exclusive. Do not extend regions without proving contents.
TABLES=[
(0x0543,0x0565,"DJ communications strings","fixed NUL-separated text","U2","high"),
(0x0565,0x063d,"Keyboard three 72-entry maps","three x 72 bytes","U2","high"),
(0x0653,0x0659,"HD44780 initialization","six commands, NUL ending","U2","high"),
(0x066b,0x069b,"Original LCD CGRAM glyphs","four address bytes then 4 x 11 row bytes","U2","high"),
(0x0791,0x07b6,"LCD input character remapping","12 x (input,low output,high output) + NUL","U2","high"),
(0x0939,0x0945,"Packed UI common symbols","12-byte compact charset","U2","high"),
(0x0945,0x096c,"Packed UI extended symbols","39-byte extended charset","U2","high"),
(0x096c,0x09d6,"Packed UI phrase dictionary","NUL-separated common phrases","U2","high"),
(0x0bbf,0x0bcc,"RTC default BCD values","13-byte initialization record (19h,83h year)","U2","high"),
(0x0c1b,0x0c28,"RTC register ordering","13 one-byte MM58167 register indexes","U2","high"),
(0x0ce2,0x0d00,"Clock/calendar editing descriptors","mixed-width field descriptors (still needs complete parser trace)","U2","medium"),
(0x0e48,0x0e68,"Clock/alarm screen assembly descriptors","compact presentation data (not entirely decoded)","U2","medium"),
(0x0e68,0x0e75,"Month length lookup","13 bytes (sentinel and 12 BCD lengths)","U2","high"),
(0x0f7d,0x10bf,"OS command-mode dispatch","29 groups, 88 mode/handler entries","U2/U3","high"),
(0x10c0,0x10dc,"Secondary key handler pointers","nine 3-byte key+address triples + end","U3","high"),
(0x10dc,0x10e9,"Secondary key pointer table","four key+address triples + end; caller unresolved","U3","medium"),
(0x10e9,0x112f,"HELP key-to-message pointers","23 key+data-pointer triples + terminator","U3","high"),
(0x112f,0x163e,"Packed UI and help messages","nibble-coded variable-length records with padding","U3","high"),
(0x1855,0x185e,"Configuration row counts","nine counts; sum=17","U3","high"),
(0x185e,0x1891,"Configuration option descriptors","17 x (display offset,value text ID,config bit index)","U3","high"),
(0x1a75,0x1a7c,"PC/PX format-line parser options","two 3-byte option+RAM-pointer triples + NUL","U3","high"),
(0x298e,0x299b,"Calculator keyboard remap","count 06, then six (input ASCII, resulting calculator key) pairs","U4","high"),
]
with (OUT/"rom_table_atlas.csv").open("w",newline="") as f:
    w=csv.writer(f)
    w.writerow(("start_hex","end_exclusive_hex","size_bytes","name","encoding","rom","confidence"))
    for start,end,name,encoding,bank,confidence in TABLES:
        w.writerow((f"{start:04X}",f"{end:04X}",end-start,name,encoding,bank,confidence))
print(f"Verified {len(ROM)} ROM bytes, {len(port_rows)} I/O accesses, "
      f"{len(TABLES)} tables, {sum(map(len,SETTINGS))} settings")
