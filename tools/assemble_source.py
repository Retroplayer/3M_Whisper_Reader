#!/usr/bin/env python3
"""Rebuild annotated LEX-31 source using its documented opcode skeletons.

This is a project-specific lossless assembler, not a general Z80 assembler.
DB statements are assembled from source; mnemonic operands (including branch targets,
absolute addresses, immediate values and IX/IY displacements) are parsed and applied
to the original opcode shape. Mnemonic changes requiring a different opcode cannot be
encoded by this helper; use a conventional Z80 assembler for arbitrary modifications.
Raw hex annotations are never used as output data.
"""
from pathlib import Path
import re,hashlib,sys,argparse
from build_disassembly import decode,B,H
HERE=Path(__file__).resolve().parent
parser=argparse.ArgumentParser()
parser.add_argument('--source',type=Path,default=HERE/'LEX31_full_annotated.asm')
parser.add_argument('--out',type=Path,default=HERE/'rebuilt_from_source.bin')
parser.add_argument('--allow-changes',action='store_true',help='Permit deliberate ROM changes in source')
args=parser.parse_args()
SRC=args.source
lines=SRC.read_text().splitlines()
ADDRESS=re.compile(r'; @([0-9A-F]{4})\b')
SYMBOL=re.compile(r'^([A-Za-z_][A-Za-z_0-9]*):')
EQU=re.compile(r'^([A-Za-z_][A-Za-z_0-9]*)\s+EQU\s+([0-9A-F]+)h\b',re.I)
syms={}
for idx,ln in enumerate(lines):
 m=SYMBOL.search(ln)
 if m:
  am=ADDRESS.search(ln)
  # The source labels are on lines ahead of their first instruction; find from next @address.
  if not am:
   for follow in lines[idx+1:]:
    if follow.startswith('ORG '):break
    am=ADDRESS.search(follow)
    if am:break
   else:am=None
  if am:syms[m.group(1)]=int(am.group(1),16)
 m=EQU.search(ln)
 if m:syms[m.group(1)]=int(m.group(2),16)

# Resolve only symbol-like tokens, rather than running a regex for every known label.
SYMBOL_PATTERN=re.compile(r'\b[A-Za-z_][A-Za-z_0-9]*\b')
def resolved(mn):
 return SYMBOL_PATTERN.sub(lambda m: H(syms[m.group(0)],4) if m.group(0) in syms else m.group(0),mn)

def patch_instruction(addr,src):
 old=decode(addr)
 if not old.support:
  raise ValueError(f'Cannot assemble unsupported opcode at {addr:04X}: {src}')
 raw=bytearray(old.raw);op=raw[0];target=None
 # Infer original encoded numeric operand and its position.
 typ=None;offset=None;size=None;value=None
 if op in (0x10,0x18,0x20,0x28,0x30,0x38):
  typ='rel';offset=1;size=1;value=old.target
 elif op in (0xd3,0xdb):typ='imm';offset=1;size=1;value=raw[1]
 elif len(raw)==2 and ((op>>6==0 and (op&7)==6) or (op>>6==3 and (op&7)==6)):
  typ='imm';offset=1;size=1;value=raw[1]
 elif op in (0xdd,0xfd):
  pp=raw[1]
  if pp in (0x21,0x22,0x2a):typ='imm';offset=2;size=2;value=raw[2]|(raw[3]<<8)
  elif pp==0x36:typ='idx_imm';offset=2;size=2;value=None
  elif (len(raw)==3 and pp in list(range(0x40,0x80))+list(range(0x80,0xc0))+[0x34,0x35]) or pp==0xcb:
   typ='idx';offset=2;size=1;value=raw[2] if raw[2]<128 else raw[2]-256
 elif op==0xed and len(raw)==4:typ='imm';offset=2;size=2;value=raw[2]|raw[3]<<8
 elif len(raw)==3 and (op in (0x21,0x01,0x11,0x31,0x22,0x2a,0x32,0x3a,0xc3,0xcd) or (op>>6==3 and ((op&7) in (2,4)))):
  typ='imm';offset=1;size=2;value=raw[1]|raw[2]<<8
 # Normalized original mnemonic (we allow numeric operand changes, not opcode changes).
 previous=old.asm.split(' ;')[0]
 now=resolved(src).strip()
 if typ=='rel':
  a=H(value,4);m=re.escape(previous).replace(re.escape(a),r'([0-9A-F]+h)')
  hit=re.fullmatch(m,now,re.I)
  if not hit:raise ValueError(f'{addr:04X}: mnemonic mismatch: {now} != {previous}')
  goal=int(hit.group(1)[:-1],16);delta=(goal-(addr+len(raw)))&0xffff
  if delta>127 and delta<0xff80:raise ValueError(f'{addr:04X}: relative branch out of range to {goal:04X}')
  raw[offset]=delta&255
 elif typ=='imm':
  a=H(value,size*2);m=re.escape(previous).replace(re.escape(a),r'([0-9A-F]+h)')
  hit=re.fullmatch(m,now,re.I)
  if not hit:raise ValueError(f'{addr:04X}: mnemonic mismatch: {now} != {previous}')
  val=int(hit.group(1)[:-1],16)
  if val>=1<<(8*size):raise ValueError(f'{addr:04X}: immediate too large')
  for j in range(size):raw[offset+j]=(val>>(j*8))&255
 elif typ=='idx':
  # e.g. (IX+0) or (IY-1), first match replacement only
  pre=re.escape(previous)
  pre=re.sub(r'\\[+\-][0-9]+',r'([+-][0-9]+)',pre,count=1)
  hit=re.fullmatch(pre,now,re.I)
  if not hit:raise ValueError(f'{addr:04X}: index syntax mismatch {now}, {previous}')
  val=int(hit.group(1))
  if not -128<=val<=127:raise ValueError(f'{addr:04X}: index displacement overflow')
  raw[offset]=val&255
 elif typ=='idx_imm':
  # (IX±d),imm8
  match=re.match(r'LD \((I[XY])([+-]\d+)\),([0-9A-F]+)h$',now,re.I)
  if not match:raise ValueError(f'{addr:04X}: syntax {now}')
  d=int(match.group(2));n=int(match.group(3),16)
  if not(-128<=d<=127 and 0<=n<=255):raise ValueError(f'{addr:04X}: overflow')
  raw[2]=d&255;raw[3]=n
 else:
  if now.upper()!=previous.upper():raise ValueError(f'{addr:04X}: fixed opcode mismatch: {now} != {previous}')
 return raw

rebuilt=bytearray(0x3000);covered=set();instruction_count=0;data_count=0
for ln in lines:
 m=ADDRESS.search(ln)
 if not m:continue
 addr=int(m.group(1),16)
 prefix=ln[:ln.index('; @')].strip()
 if prefix.upper().startswith('DB '):
  bb=bytes(int(v[:-1],16) for v in prefix[3:].split(','));data_count+=len(bb)
 else:
  bb=patch_instruction(addr,prefix);instruction_count+=1
 for k in range(addr,addr+len(bb)):
  if k in covered:raise ValueError(f'double-defined byte {k:04X}')
  covered.add(k)
 rebuilt[addr:addr+len(bb)]=bb
if len(covered)!=0x3000:raise ValueError(f'uncovered bytes: {len(covered)}')
args.out.write_bytes(rebuilt)
if not args.allow_changes:
 for i,name in enumerate(('U2_red','U3_green','U4_white')):(HERE/f'{name}_from_source.bin').write_bytes(rebuilt[4096*i:4096*(i+1)])
print('source:',SRC,'instructions:',instruction_count,'data bytes:',data_count)
print('binary SHA256:',hashlib.sha256(rebuilt).hexdigest())
if rebuilt!=B and not args.allow_changes:
 mismatches=[f'{i:04X} {B[i]:02X}->{rebuilt[i]:02X}' for i in range(len(B)) if B[i]!=rebuilt[i]]
 raise ValueError('Source recompilation changed firmware: '+str(mismatches[:25]))
print('PASS: source assembled with source data and decoded operands, no raw-byte annotations used')
if not args.allow_changes:print('PASS: assembled result matches all three original EPROM dumps byte-for-byte')
else:print('Changed byte count vs factory:',sum(a!=b for a,b in zip(rebuilt,B)))
