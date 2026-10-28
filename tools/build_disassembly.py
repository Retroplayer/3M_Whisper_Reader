#!/usr/bin/env python3
"""Create a byte-preserving, heavily annotated Z80/NSC800 disassembly of 3 LEX-31 2732 ROMs.

Conservative recursive CFG seeded by hardware vectors, firmware command handler table,
confirmed entrypoints and code xrefs. Unknown/undocumented opcodes and untraced bytes
are emitted as DB to avoid presenting accidental data as instructions.
"""
import csv, hashlib, re
from pathlib import Path
from collections import defaultdict, deque, Counter
from dataclasses import dataclass

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
OUTPUT_DIR=(ROOT/'firmware' if (ROOT/'firmware').is_dir() and not (HERE/'roms'/'original').is_dir() else HERE)
ROMNAMES=('red_u2.bin','green_u3.bin','white_u4.bin')
ROMHASH=('7ff2ab423b202d3755f8ffbe06c5804412252459ea7434f99c1ba4bce2020e14',
         '78540723234e94119dcac9ffc6a40561abd6d21cac1457739fb1a428f4d0d253',
         '3fa98fd04a6a2cabcae2c99b295f7d42374a4a1602d259771b2e5fbc7576d53a')
def read_original(name):
 for path in [ROOT/name,ROOT/'roms'/'original'/name,HERE/'roms'/'original'/name]:
  if path.exists():return path.read_bytes()
 raise FileNotFoundError(f'Cannot locate original ROM: {name}')
roms=[read_original(name) for name in ROMNAMES]
for b,expected in zip(roms,ROMHASH):
 assert len(b)==4096 and hashlib.sha256(b).hexdigest()==expected, 'Input ROM has changed'
B=b''.join(roms)
assert len(B)==0x3000
R=['B','C','D','E','H','L','(HL)','A']; P=['BC','DE','HL','SP']; P2=['BC','DE','HL','AF']; C=['NZ','Z','NC','C','PO','PE','P','M']; A=['ADD A,','ADC A,','SUB ','SBC A,','AND ','XOR ','OR ','CP ']

def H(v,width=2):return f'{v:0{width}X}h'
@dataclass
class Ins:
 pc:int; end:int; asm:str; target:int|None=None; kind:str='fall'; port:int|str|None=None; support:bool=True
 @property
 def raw(self):return B[self.pc:self.end]

def decode(pc):
 """Documented Z80 instructions; unsupported or unusual prefixes stay as raw DB."""
 start=pc
 if not(0<=pc<len(B)):raise ValueError(pc)
 op=B[pc];pc+=1; x=op>>6;y=(op>>3)&7;z=op&7;p=y>>1;q=y&1
 target=None;kind='fall';port=None;support=True
 def b():
  nonlocal pc
  if pc>=len(B): raise IndexError
  v=B[pc];pc+=1;return v
 def w():return b()|(b()<<8)
 def rel():
  v=b();return (pc+(v if v<128 else v-256))&0xffff
 def hb():return H(b())
 def hw():return H(w(),4)
 if op==0xcb:
  v=b();xx=v>>6;yy=(v>>3)&7;zz=v&7
  asm=(['RLC','RRC','RL','RR','SLA','SRA','SLL','SRL'][yy]+' '+R[zz]) if xx==0 else (['BIT','RES','SET'][xx-1]+f' {yy},{R[zz]}')
  if xx==0 and yy==6:support=False # SLL undocumented
 elif op==0xed:
  v=b();xx=v>>6;yy=(v>>3)&7;zz=v&7;pp=yy>>1;qq=yy&1
  if xx==1:
   if zz==0: asm=f'IN {R[yy]},(C)' if yy!=6 else 'IN (C)';port='(C)';support=yy!=6
   elif zz==1:asm=f'OUT (C),{R[yy]}' if yy!=6 else 'OUT (C),0';port='(C)';support=yy!=6
   elif zz==2:asm=f'{"ADC" if qq else "SBC"} HL,{P[pp]}'
   elif zz==3:
    nn=hw();asm=f'LD {P[pp]},({nn})' if qq else f'LD ({nn}),{P[pp]}'
   elif zz==4:asm='NEG';support=v==0x44
   elif zz==5:asm='RETI' if qq else 'RETN';kind='ret';support=v in (0x45,0x4d)
   elif zz==6:asm=f'IM {[0,0,1,2,0,0,1,2][yy]}';support=v in (0x46,0x56,0x5e)
   else:
    ops=['LD I,A','LD R,A','LD A,I','LD A,R','RRD','RLD','', ''];asm=ops[yy];support=bool(asm)
  elif xx==2 and 4<=yy<=7 and zz<=3:
   names=[('LDI','CPI','INI','OUTI'),('LDD','CPD','IND','OUTD'),('LDIR','CPIR','INIR','OTIR'),('LDDR','CPDR','INDR','OTDR')]
   asm=names[yy-4][zz]
  else:asm=f'DB 0EDh,{H(v)}';support=False
 elif op in (0xdd,0xfd):
  ix='IX' if op==0xdd else 'IY'; v=b();xx=v>>6;yy=(v>>3)&7;zz=v&7;pp=yy>>1;qq=yy&1
  rr=["BC","DE",ix,"SP"]
  if v in (0x21,0x22,0x2a):
   adr=hw();asm={0x21:f'LD {ix},{adr}',0x22:f'LD ({adr}),{ix}',0x2a:f'LD {ix},({adr})'}[v]
  elif v in (0x23,0x2b):asm=f'{"INC" if v==0x23 else "DEC"} {ix}'
  elif v in (0x09,0x19,0x29,0x39):asm=f'ADD {ix},{rr[(v>>4)&3]}'
  elif v in (0xe1,0xe5,0xe3,0xe9,0xf9):
   asm={0xe1:f'POP {ix}',0xe5:f'PUSH {ix}',0xe3:f'EX (SP),{ix}',0xe9:f'JP ({ix})',0xf9:f'LD SP,{ix}'}[v]
   if v==0xe9:kind='indirect'
  elif v==0xcb:
   d=b();w2=b();xx2=w2>>6;bit=(w2>>3)&7;r=w2&7;dstr=f'{d-256 if d>=128 else d:+d}'
   if r!=6:support=False
   asm=(['RLC','RRC','RL','RR','SLA','SRA','SLL','SRL'][bit]+f' ({ix}{dstr})') if xx2==0 else (['BIT','RES','SET'][xx2-1]+f' {bit},({ix}{dstr})')
   if xx2==0 and bit==6:support=False
  elif (0x40<=v<=0x7f and v!=0x76 and (yy==6 or zz==6)) or (0x80<=v<=0xbf and zz==6) or v in (0x34,0x35,0x36):
   d=b();dstr=f'{d-256 if d>=128 else d:+d}';loc=f'({ix}{dstr})'
   if 0x40<=v<=0x7f:
    dest=loc if yy==6 else R[yy];src=loc if zz==6 else R[zz];asm=f'LD {dest},{src}'
   elif 0x80<=v<=0xbf:asm=A[yy]+loc
   elif v==0x36:asm=f'LD {loc},{hb()}'
   else:asm=f'{"INC" if v==0x34 else "DEC"} {loc}'
  else:
   # Several undocumented IXH/IYH/IXL/IYL and redundant prefixes possible.
   # We do not declare them code without a reliable decoder.
   asm=f'DB {H(op)},{H(v)}';support=False
 else:
  if x==0:
   if z==0:
    if y==0:asm='NOP'
    elif y==1:asm="EX AF,AF'"
    elif y==2:target=rel();asm=f'DJNZ {H(target,4)}';kind='cond'
    elif y==3:target=rel();asm=f'JR {H(target,4)}';kind='jump'
    else:target=rel();asm=f'JR {C[y-4]},{H(target,4)}';kind='cond'
   elif z==1:asm=f'LD {P[p]},{hw()}' if not q else f'ADD HL,{P[p]}'
   elif z==2:
    if p<2:asm=f'LD ({P[p]}),A' if not q else f'LD A,({P[p]})'
    else:
     nn=hw();rp='HL' if p==2 else 'A';asm=f'LD ({nn}),{rp}' if not q else f'LD {rp},({nn})'
   elif z==3:asm=f'{"INC" if not q else "DEC"} {P[p]}'
   elif z==4:asm=f'INC {R[y]}'
   elif z==5:asm=f'DEC {R[y]}'
   elif z==6:asm=f'LD {R[y]},{hb()}'
   else:asm=['RLCA','RRCA','RLA','RRA','DAA','CPL','SCF','CCF'][y]
  elif x==1:asm='HALT' if y==6 and z==6 else f'LD {R[y]},{R[z]}'
  elif x==2:asm=A[y]+R[z]
  else:
   if z==0:asm=f'RET {C[y]}';kind='condret'
   elif z==1:
    if not q:asm=f'POP {P2[p]}'
    else:asm=['RET','EXX','JP (HL)','LD SP,HL'][p];kind='ret' if p==0 else ('indirect' if p==2 else 'fall')
   elif z==2:target=w();asm=f'JP {C[y]},{H(target,4)}';kind='cond'
   elif z==3:
    if y==0:target=w();asm=f'JP {H(target,4)}';kind='jump'
    elif y==2:port=b();asm=f'OUT ({H(port)}),A'
    elif y==3:port=b();asm=f'IN A,({H(port)})'
    else:asm={4:'EX (SP),HL',5:'EX DE,HL',6:'DI',7:'EI'}[y]
   elif z==4:target=w();asm=f'CALL {C[y]},{H(target,4)}';kind='callcond'
   elif z==5:
    if not q:asm=f'PUSH {P2[p]}'
    else:
     if p!=0:asm=f'DB {H(op)}';support=False
     else:target=w();asm=f'CALL {H(target,4)}';kind='call'
   elif z==6:asm=A[y]+hb()
   else:target=y*8;asm=f'RST {H(target)}';kind='call'
 if not support:asm='DB '+','.join(H(t) for t in B[start:pc]) + f' ; unsupported prefix (decoded hint: {asm})'
 return Ins(start,pc,asm,target,kind,port,support)

def generate_source():
    # Known literal data regions: no speculative disassembly may cross these.
    DATA=[(0x066b,0x069b,'LCD_CGRAM_BOOT'),(0x0791,0x07b6,'LCD_CHAR_REMAP'),(0x0ce2,0x0d00,'RTC_FIELD_DESCRIPTORS'),(0x0e48,0x0e68,'RTC_SCREEN_LAYOUT'),(0x1855,0x1891,'CONFIG_DESCRIPTORS'),(0x298e,0x299b,'CALCULATOR_REMAP'),(0x0543,0x0565,'DJ_DIAL_STRINGS'),(0x0565,0x063d,'KEYBOARD_TABLES'),(0x0653,0x0659,'LCD_INIT_TABLE'),(0x0bbf,0x0bcc,'RTC_INIT_BCD_VALUES'),(0x0c1b,0x0c28,'RTC_REGISTER_SEQUENCE'),(0x0e68,0x0e75,'MONTH_LENGTH_TABLE'),(0x0939,0x096c,'PACKED_CHARSET'),(0x096c,0x09d6,'PACKED_PHRASES'),(0x1a75,0x1a7c,'SEND_FORMAT_OPTION_TABLE'),(0x0f7d,0x10c0,'COMMAND_TABLE'),(0x10c0,0x112f,'SECONDARY_LOOKUP_TABLES'),(0x112f,0x163e,'PACKED_UI_DATA')]
    data_mask=set()
    for x,y,_ in DATA:data_mask.update(range(x,y))
    # Known entry points verified in earlier disassembly work, may represent subroutines rather than unique code areas.
    NAMES={
     0x0000:'RESET_ENTRY',0x0030:'RST30_DISPLAY_PACKED_ROM_MESSAGE',0x002c:'NSC800_RSTC_PERIODIC_VECTOR',0x0034:'NSC800_RSTB_C000_VECTOR',0x0066:'NSC800_NMI_LOCKUP_VECTOR',0x0010:'RST10_LOAD_POINTERS',0x0018:'RST18_LCD_SERVICE',0x0020:'RST20_DOCUMENT_POINTERS',0x0028:'RST28_SET_INDICATOR',0x0038:'RST38_COMPARE_HL_DE',
     0x00e3:'OS_MAIN_LOOP',0x017e:'PERIODIC_SERVICE',0x01e7:'AUX_OUTPUT_SERVICE',0x0214:'AUX_SEND_CHAR',0x0238:'OS_COMMAND_LOOKUP',
     0x0288:'QUEUE_HANDLER_A',0x02d8:'QUEUE_HANDLER_B',0x035a:'KEY_SCAN',0x03aa:'KEY_TABLE_INDEX',0x03c6:'KEY_TRANSLATE_EVENT',
     0x04ad:'CHECKSUM_DOCUMENT_DIRECTORY',0x04ba:'CHECKSUM_PERSISTENT_SETTINGS',0x04c1:'DJ_ALT_SHORTCUT',0x04c6:'DJ_SHORTCUT',0x063d:'LCD_INIT_START',0x069e:'LCD_CHAR_OUTPUT',
     0x0742:'LCD_READ',0x0755:'LCD_TRANSLATE_OUTPUT',0x0760:'LCD_COMMAND',0x076c:'LCD_CONTROL_SHADOW',0x077d:'LCD_TRANSLATION',
     0x07e6:'LCD_SAVE_MODAL_SCREEN',0x0828:'LCD_RESTORE_MODAL_SCREEN',0x0867:'LCD_MAIN_INIT',0x08cb:'DECODE_PACKED_MESSAGE',0x0925:'PACKED_READ_NIBBLE',0x09f0:'PACKED_MESSAGE_TO_RAM_4013',0x0885:'LCD_WAIT_READY',0x0896:'LCD_PATTERN_LOAD',0x0a34:'STATUS_SET_MASK',0x0a4a:'STATUS_CLEAR_MASK',
     0x0a77:'STATUS_REFRESH_DOCUMENTS',0x0a9a:'STATUS_REFRESH_ALL',0x0af2:'OUTPUT_MODE_KEY',0x0b0c:'AUX_QUEUE_OUTPUT',0x0b46:'AUX_OUTPUT_STRING',0x0b5d:'AUX_OUTPUT_RULE',
     0x1792:'CONFIG_APPLY_OPTION_CHANGE',0x1753:'CONFIG_FIND_OPTION',0x1839:'CONFIG_BIT_TEST',0x1973:'SEND_LITERAL_ENTRY',0x1978:'SEND_SELECT_FILE',0x19a7:'SEND_START_SELECTED_RECORD',0x19c6:'SEND_FORMATTED_SETUP',0x1a29:'PARSE_FILE_FORMAT_LINE',0x1a66:'READ_NEXT_FORMAT_BYTE',0x1a7c:'SAVE_TOGGLE_AND_SELECT_FILE',0x1b1f:'SAVE_APPEND_STAGED_LINE',0x1b4a:'PROCESS_RECEIVED_QUEUE_EVENT',0x1bfe:'SERIAL_TX_PUMP',0x1c6d:'SEND_PROCESS_NEXT_CHARACTER',0x1ce4:'DOCUMENT_APPEND_UPDATE_LENGTH',0x1b7a:'ONLINE_ENQ_Y_ANSWERBACK',0x1c89:'SEND_CR_WITH_OPTIONAL_Z_FILE',0x0b6c:'RTC_RESET_AND_INITIALIZE',0x0b94:'RTC_REFRESH_DISPLAY_VALUES',0x0bcc:'RTC_READ_REGISTER',0x0bdb:'RTC_END_ACCESS',0x0be3:'RTC_WRITE_REGISTER',0x0bed:'RTC_SELECT_BANK',0x0bf5:'RTC_READ_TIME_BLOCK',0x0c28:'RTC_WRITE_TIME_BLOCK',0x0c2c:'RTC_WRITE_FIELDS',0x0d00:'RTC_INCREMENT_DATE_FIELD',0x0e75:'RTC_VALIDATE_CALENDAR_DATE',0x0ef6:'RTC_TEST_BCD_LEAP_YEAR',0x0f11:'STATUS_DIRECTION_INDICATOR',0x18a9:'SERIAL_RECEIVE_SERVICE',0x18ab:'SERIAL_READ_STATUS',0x18dc:'SERIAL_READ_CHAR',
     0x1932:'SERIAL_XOFF_PATH',0x1c13:'TX_DEQUEUE',0x1c98:'SERIAL_SEND_CHAR',0x1ccc:'DOCUMENT_TX_INIT',
     0x1d14:'DOCUMENT_DIRECTORY_LOOKUP',0x1d32:'DIRECTORY_READ_ENTRY',0x1e80:'DOCUMENT_POOL_INIT',0x1f5f:'DIRECTORY_INDEX_TO_ADDRESS',
     0x21df:'AUX_OUTPUT_MEMORY',0x24b0:'EDITOR_UPDATE_POSITION',
    }
    # Entries from the packed command table (29 command groups, all handlers)
    command_entries=[]
    pos=0x0f7d
    while pos<0x10c0 and B[pos]:
     key=B[pos]; n=B[pos+1]; start=pos;pos+=2
     assert 1<=n<=12,(hex(start),n)
     for i in range(n):
      mode=B[pos];handler=B[pos+1]|(B[pos+2]<<8);pos+=3
      assert 0<=handler<0x3000,(hex(start),hex(handler))
      command_entries.append((start,key,mode,handler))
    assert pos==0x10bf and B[pos]==0 and len(command_entries)==88,(hex(pos),len(command_entries))

    SEEDS=set(range(0,0x40,8)) | {v for v in NAMES if v<0x3000} | {h for _,_,_,h in command_entries}
    SEEDS|={0x1fe5,0x0c6b,0x00f2,0x002c,0x0034,0x0066} # direct special routes
    SEEDS={v for v in SEEDS if v not in data_mask}

    # Recursive code discovery, protect already-discovered instructions and known data.
    seen={};bybyte={}; refs=defaultdict(set); failures=[]; queue=deque(sorted(SEEDS)); queued=set(queue)
    while queue:
     pc=queue.popleft()
     while pc<0x3000:
      if pc in seen or pc in data_mask or pc in bybyte:break
      try:inst=decode(pc)
      except (IndexError,KeyError) as ex:failures.append((pc,str(ex)));break
      if inst.end>0x3000 or any(p in data_mask or p in bybyte for p in range(pc,inst.end)):
       failures.append((pc,'crosses data or existing decoded instruction'));break
      seen[pc]=inst
      for a in range(pc,inst.end):bybyte[a]=pc
      if inst.target is not None and 0<=inst.target<0x3000:
       refs[inst.target].add(pc)
       if inst.target not in queued and inst.target not in data_mask:
        queued.add(inst.target);queue.append(inst.target)
      if inst.kind in ('ret','jump','indirect') or inst.asm=='HALT' or not inst.support:break
      pc=inst.end

    # Named labels can point to unknown/alternate entry points; track and exclude those that land mid-instruction.
    labels={p:NAMES.get(p,f'loc_{p:04X}') for p in set(refs)|set(NAMES)|set(SEEDS) if p not in data_mask and p not in bybyte or p in seen}
    # prevent target labels from landing inside an instruction
    labels={p:s for p,s in labels.items() if p not in bybyte or p in seen}
    if len(set(labels.values()))<len(labels):raise RuntimeError('duplicate label')

    def fmtbytes(bb):return ','.join(H(x) for x in bb)

    def symbol_target(ins):
     if ins.target is None or ins.target not in labels:return ins.asm
     return re.sub(r'\b'+f'{ins.target:04X}'+r'h\b',labels[ins.target],ins.asm)

    # Verified hardware comments, conservative about physical mapping.
    COMMENT={
     0x0000:'CPU reset entry; U2 appears mapped at 0000h',
     0x0002:'Early output to port 47h (shared display/keyboard control)',
     0x000b:'Stack pointer set to 4800h; OS working-RAM layout must be reviewed for conflicts',
     0x0074:'Cold-clear volatile working RAM 4000h..4591h by LDDR zero-copy; retained directory and settings remain intact',
     0x007e:'Write 06h to NSC800 internal interrupt control at BBh: enables RSTC and RSTB, masks RSTA/INTR',
     0x0180:'Write 00h to NSC800 internal interrupt control at BBh: masks all sources during service',
     0x021f:'Write 06h to NSC800 internal interrupt control at BBh: re-enable RSTC and RSTB',
     0x0010:'RST 10h loads HL and DE from saved OS pointers',
     0x0020:'RST 20h retrieves document-memory pointers',
     0x0028:'RST 28h enters 16-bit status-mask set function',
     0x0030:'RST 30h: clear LCD, expand nibble-packed ROM string from HL into 4013h, then display',
     0x002c:'NSC800 RSTC vector (002Ch) jumps to 017Eh periodic service; enabled by OUT (BBh),06h',
     0x0034:'NSC800 RSTB vector (0034h) jumps to C000h; enabled by OUT (BBh),06h; destination external/banked UNKNOWN',
     0x0066:'NSC800 NMI vector (0066h) loops to itself; NMI is not serviceable in this firmware configuration',
     0x0038:'RST 38h performs 16-bit compare, not a conventional IRQ handler',
     0x00e8:'Resolve keycode and mode into handler pointer in HL',
     0x00f1:'Dispatcher performs computed JP (HL); no general-purpose RAM loader proven',
     0x017e:'RSTC interrupt service: disables CPU interrupts via BBh=00, services keyboard/serial/timers then restores BBh=06; source not traced',
     0x0238:'Mode-dependent command lookup, data table at 0F7Dh (crosses U2/U3 boundary)',
     0x035a:'Keyboard scan; port 47h is shared with display control',
     0x04c1:'DJ variant: alters communications flag then enters common shortcut',
     0x04c6:'DJ macro path; strings at 0543h include DOW1;;',
     0x063d:'HD44780 initialization driven from command bytes at 0653h',
     0x0760:'Command transfer to HD44780-compatible LCD',
     0x076c:'Shadow output port 47h, also touched by keyboard scanner',
     0x0867:'HD44780 driver initialization/service',
     0x08cb:'Decode nibble-packed message in HL to RAM at DE: 0-B common chars, C terminator, D-F extensions/F7-FE phrase tokens',
     0x0925:'Get next four-bit message symbol; alternate high and low nibbles, state at 4508h',
     0x09f0:'Set DE=4013h and decode a packed ROM message from HL',
     0x0885:'Poll bit 7 through port 4Bh: consistent with HD44780 busy flag',
     0x0a34:'OR H/L into shadows at 4007h/4006h; output to 4Fh/53h; status indicator candidate',
     0x0a4a:'Complement H/L and AND out bits from status shadow registers',
     0x0a77:'Document count at 4593h governs mask 0008h; candidate MEMORY indicator',
     0x0a9a:'Periodic refresh of firmware status indicators',
     0x04ad:'XOR check 4593h..460Fh with checksum stored at 4610h; update checksum on return',
     0x04ba:'XOR check 4611h..4656h with checksum stored at 4657h',
     0x07e6:'Modal display save reads original 40-cell LCD screen, 20 pairs, stack holds characters',
     0x0828:'Modal display restore writes 20 LCD character pairs; requires 40x2 update',
     0x1792:'Config menu option change toggles retained-RAM bit selected by descriptor at 185Eh and refreshes 4657h checksum via 04BAh',
     0x1753:'Find one of 17 configuration option descriptors at 185Eh using 9 group counts starting at 1855h',
     0x1839:'Select config bit in retained RAM 4654h..4656h from third descriptor byte, output mask and toggled value',
     0x0898:'Write 11 bytes per original 5x10 custom CGRAM character',
     0x0830:'Restore 40 LCD character cells in 20 pairs (B=13h loop)',
     0x0b5d:'40 ASCII hyphens and CR emitted to auxiliary channel: printer-style formatting',
     0x1973:'CTL+SEND sets 451Fh=FFh bypassing format-line and special processing; manual p49',
     0x1978:'SHIFT+SEND selects named file; keycode 96h; literal 99h joins here',
     0x19a7:'File entry +2 pointer +4 length; literal to 4521/4523, formatted to 451B/451D',
     0x19c6:'Formatted SEND parse optional leading ESC header, then send payload',
     0x1a29:'Parse ESC prefix format clauses pX=char -> 4525h, pC=char -> 4526h',
     0x1a75:'Seven-byte option table: x 4525h, c 4526h, 00 sentinel',
     0x1a7c:'SHIFT+SAVE start/stop receive-to-file; active flag 4514h=FFh',
     0x1b1f:'Append staged line at RAM 4013h to document at 4594h; update length/free via 1CE4h',
     0x1b4a:'Main-loop receive queue consumer: ENQ/Y, screen, SAVE',
     0x1bfe:'Periodic transmitter tests port 5Fh and pause flag 4517h',
     0x1c6d:'Literal bypasses PC/Z transform; formatted uses pause 4526h and file Z on CR',
     0x1ce4:'Update active document length/free pointer/available space after byte append',
     0x1b7a:'ENQ (ASCII 05h) online answer-back handler: checks configuration, looks up special file Y (59h) at 1B88h; 3M manual p.69',
     0x1b88:'Special answer-back file identifier Y=59h, directory lookup at 1B8Ah; 3M manual p.69',
     0x1c89:'CR-dependent end-of-line expansion: when configured look up file Z (5Ah) and transmit its content instead of CR; manual p.67',
     0x1c8e:'Special end-of-line file identifier Z=5Ah, directory lookup at 1C90h; manual p.67',
     0x0b6c:'RTC initialization: read interrupt status at 4010h, disable interrupts at 4011h, reset counters/RAM at 4012h/4013h, write time and GO at 4015h',
     0x0b94:'Read clock; if current month (4659h) < saved month (4664h, RTC RAM 0Eh), increment year through RTC_INCREMENT_DATE_FIELD in mode 3',
     0x0bcc:'MM58167 RTC register READ (HL=4000h+register): switches bus, reads, polls 4014h bit0 for rollover, restores bank and EI',
     0x0bdb:'Restore original port 47h bus control, enable interrupts, return RTC byte in A',
     0x0be3:'MM58167 RTC register WRITE (HL=4000h+register, B=value): briefly select bus then write, restore bus',
     0x0bed:'Save port 47h shadow from 4000h, OR 40h to enable RTC address window, mask interrupts during transaction',
     0x0bf5:'Read 13 RTC registers specified at 0C1Bh into buffer 4658h; mixed counters and alarm RAM',
     0x0c28:'Write clock data from RAM buffer to RTC using table at 0C1Bh',
     0x0c2c:'Common RTC write loop through register-address table',
     0x0d00:'Increment selected BCD clock field; mode 3 uses two-byte BCD year at 465Bh/465Ch; called on December to January month rollover',
     0x0e75:'Clamp calendar days to month length; February 28/29 selection tests BCD year modulo four at 0EF6h',
     0x0ef6:'Leap year test on BCD low year at 465Ch; result AND 03h is zero for multiples of four',
     0x18ab:'Communications status poll, port 5Fh; UART electrical mapping not verified',
     0x1ccc:'Document transfer setup: loads data pointer and length from directory entry',
     0x1e80:'Initialize document pool at 4800h and compute usable RAM size',
    }
    # Special table/data descriptions for readable source, also includes true byte layout.
    DATA_LABELS={0x0543:'DJ_SCRIPT_DATA',0x0565:'KB_NORMAL_TABLE',0x05ad:'KB_ALT_TABLE',0x05f5:'KB_SHIFT_TABLE',0x066b:'LCD_CGRAM_BOOT_TABLE',0x0791:'LCD_CHARACTER_REMAP_TABLE',0x0ce2:'RTC_FIELD_DESCRIPTOR_TABLE',0x0e48:'RTC_SCREEN_LAYOUT_TABLE',0x1855:'CONFIGURATION_DESCRIPTOR_TABLE',0x298e:'CALCULATOR_KEY_REMAP_TABLE',0x0653:'LCD_INIT_COMMANDS',0x0bbf:'RTC_INITIAL_VALUES',0x0c1b:'RTC_REGISTER_LIST',0x0e68:'MONTH_LENGTHS_BCD',0x0f7d:'COMMAND_DISPATCH_TABLE',0x10bf:'COMMAND_TABLE_TERMINATOR',0x0939:'PACKED_COMMON_CHARACTERS',0x0945:'PACKED_EXTENDED_CHARACTERS',0x096c:'PACKED_COMMON_PHRASES',0x10c0:'AUX_KEY_DISPATCH_TABLE',0x10dc:'AUX_KEY_DISPATCH_TABLE_2',0x10e9:'HELP_DATA_KEY_POINTERS',0x112f:'OS_VERSION_MESSAGE'}
    # Subdivide packed command table into readable entries, and keyboard map into scan rows.
    groupstarts={}
    modestarts={}
    for start,key,mode,handler in command_entries:
     groupstarts[start]=(key,B[start+1])
     # Each group begins with two bytes and is followed by [mode][address lo][address hi] triples.
     group_mode_no=sum(1 for a,k,m,h in command_entries if a==start and (k,m,h)<(key,mode,handler))
     i=next(i for i,(a,k,m,h) in enumerate(command_entries) if a==start and k==key and m==mode and h==handler)
     idx=sum(1 for a,_,_,_ in command_entries[:i] if a==start)
     modestarts[start+2+3*idx]=(key,mode,handler)

    LABEL_ANNOT={
     0x0543:'NUL-terminated connection scripts containing DOW1;; (the exact service protocol is not yet decoded)',
     0x0565:'First keycode layer: 72 entries, nine groups of eight',
     0x05ad:'Second keycode layer: 72 entries',
     0x05f5:'Third keycode layer: 72 entries',
     0x0653:'HD44780 command table; original 34h,34h,01h,06h,0Eh,00h',
     0x066b:'Four CGRAM start addresses followed by four 11-byte patterns for original 5x10 HD44780',
     0x0791:'Twelve three-byte LCD character remaps and NUL terminator',
     0x0ce2:'Clock edit field descriptors, record format not fully decoded',
     0x0e48:'Calendar/alarm screen presentation descriptors',
     0x1855:'Nine config row sizes totaling 17, then 17 three-byte descriptors from 185Eh',
     0x298e:'Calculator remapping: 06 then six typed-character/result pairs q/w/e/r/i/t',
     0x0bbf:'13-byte default BCD data values for MM58167 registers, copied through 0C2Ch',
     0x0c1b:'13 MM58167 register offsets: 05 07 06 0A 09 04 03 02 0F 0C 0B 0D 0E',
     0x0e68:'Month length table (BCD); February permits 29 until leap-year validation',
     0x0f7d:'Packed keycode/mode/target records; U2/U3 boundary bisects this table',
     0x10bf:'Zero terminator for 29 groups and 88 command-mode mappings',
     0x0939:'Nibble code 0-B common character dictionary; codes >=D use extension table at 0945h',
     0x0945:'Extended character dictionary used by two-nibble codes D/E/F',
     0x096c:'NUL-separated phrase expansions for F7-FE, including press XIT when done',
     0x10c0:'Nine keycode, 16-bit ROM handler pointer triples (0 terminator); used at 2986h and JP (HL) at 298Dh',
     0x10dc:'Four keycode, 16-bit pointer triples, 0 terminator; caller not located',
     0x10e9:'23 keycode, 16-bit ROM data pointer triples; used at 2003h as data, not executed',
     0x1a75:'Two 3-byte format option records and NUL: x->4525h, c->4526h',
     0x112f:'Compressed message v2.1, referenced by boot and version display paths',
    }
    labels.update({p:name for p,name in DATA_LABELS.items() if p not in bybyte or p in seen})

    # Auto-data detection: code is only emitted if discovered as executable. Group undecoded bytes into DBs.
    # Split DB at code labels, boundaries, page boundaries and known data tables.
    data_boundaries=set([0x1000,0x2000,0x3000])|set(DATA_LABELS)|{lo for lo,_,_ in DATA}|{hi for _,hi,_ in DATA}|set(labels)|set(groupstarts)|set(modestarts)|{start+8*k for start in (0x0565,0x05ad,0x05f5) for k in range(9)}
    output=[]
    for bank in range(3):
     lo=bank*4096;hi=lo+4096
     out=[f'; {ROMNAMES[bank]} SHA256={ROMHASH[bank]}',f'ORG {H(lo,4)}',f'; ---- {ROMNAMES[bank]} start {H(lo,4)} ----','']
     pc=lo
     while pc<hi:
      if pc in labels:
       nm=labels[pc]
       out.append(nm+':'+('  ; '+LABEL_ANNOT[pc] if pc in LABEL_ANNOT else ''))
       if pc in COMMENT:out.append('    ; '+COMMENT[pc])
       cmds=sorted({(k,m) for _,k,m,h in command_entries if h==pc})
       if cmds:out.append('    ; Dispatched for keycode/mode: '+', '.join(f'{k:02X}/{m:02X}' for k,m in cmds))
      if pc in seen:
       ins=seen[pc];mn=symbol_target(ins)
       cm=''
       if ins.pc in COMMENT and ins.pc not in labels:cm=COMMENT[ins.pc]
       if ins.pc==0x04c1:cm+=' (alternate DJ keycode C0h)'
       if ins.pc==0x04c6:cm+=' (normal DJ keycode 80h)'
       if not ins.support:cm+=' (raw bytes preserve undocumented opcode)'
       out.append(f'    {mn:<42} ; @{pc:04X}  {ins.raw.hex(" ").upper():<18}'+('  '+cm if cm else ''))
       pc=ins.end;continue
      # any uncovered bytes, including known data; preserve exact binary using DB
      start=pc; chunk=[]
      wanted=16
      if start in groupstarts:wanted=2
      elif start in modestarts:wanted=3
      elif 0x0f7d<=start<0x10c0:wanted=min([b-start for b in data_boundaries if b>start]+[16])
      elif 0x0565<=start<0x063d:wanted=8
      while pc<hi and pc not in seen and (pc==start or pc not in data_boundaries) and len(chunk)<wanted:
       chunk.append(B[pc]);pc+=1
      if pc==start:raise RuntimeError(f'no progress at {pc:X}')
      desc=''
      if start in DATA_LABELS:desc=LABEL_ANNOT.get(start,'')
      if start in groupstarts:
       key,n=groupstarts[start];desc+=f' COMMAND {key:02X}h: {n} mode(s)'
      elif start in modestarts:
       key,mode,dest=modestarts[start];desc+=f' COMMAND {key:02X}h mode {mode:02X}h -> {NAMES.get(dest,labels.get(dest, f"{dest:04X}h"))}'
      elif 0x0565<=start<0x063d:
       layer=(start-0x0565)//72; group=((start-0x0565)%72)//8
       desc+=f' layer {layer}, scan group {group}'

      # printable ASCII hints only, not promise strings; avoid garbage runs
      asci=''.join(chr(c) if 32<=c<127 else '.' for c in chunk)
      if sum(32<=c<127 for c in chunk)>=5:desc+=f' |{asci}|'
      out.append(f'    DB {fmtbytes(chunk):<40} ; @{start:04X}  {bytes(chunk).hex(" ").upper()}'+('  '+desc if desc else ''))
     out.append('')
     output+=out
     output+=['']

    header=['; Lexicon LEX-31 / 3M Whisper Reader — ANNOTATED FULL ROM SOURCE',
     '; Original binary: 3 x 2732 (U2 red / U3 green / U4 white), 12 KiB',
     '; Z80/NSC800 instruction format. Address locations are inferred from code; verify PCB decoder.',
     '; Generated source has exact coverage of every byte. Executable regions use Z80 mnemonics;',
     '; unproven/undocumented regions use DB to preserve original ROM without pretending to know code.',
     '; Addresses and original bytes after each line allow precise cross-checking.',
     '; IMPORTANT: Byte exact source coverage checked by the accompanying validation script;',
     '; independent assembly by a third-party Z80 assembler has not yet been run.',
     '; Hardware labels identify firmware behavior, not connector/pin assignments.',
     '',
     'PORT_LCD_CONTROL       EQU 047h  ; shared with keyboard scanner and RTC bank switch (bit 6)',
     'RTC_WINDOW_BASE        EQU 04000h ; MM58167 5-bit registers visible while port 47h bit 6 is asserted',
     'RTC_REG_IRQ_STATUS     EQU 04010h ; reading acknowledges MM58167 interrupt',
     'RTC_REG_IRQ_CONTROL    EQU 04011h ; interrupt enable mask',
     'RTC_REG_ROLLOVER       EQU 04014h ; bit 0 set when clock rolled over during read',
     'RTC_REG_GO             EQU 04015h ; restart clock counters',
     'PORT_LCD_READ          EQU 04Bh  ; HD44780 busy/data read candidate',
     'PORT_STATUS_HI         EQU 04Fh  ; shadow 4007h',
     'PORT_STATUS_LO         EQU 053h  ; shadow 4006h',
     'PORT_COMM_DATA         EQU 05Bh  ; firmware communication byte',
     'PORT_COMM_STATUS       EQU 05Fh  ; communications status/control',
     'PORT_AUX_OUTPUT        EQU 0D7h  ; printer-style output; DB-37 not confirmed',
     'PORT_NS800_ICR          EQU 0BBh  ; CPU internal interrupt control register: bit1 RSTC, bit2 RSTB',
     'RAM_STATUS_LO_SHADOW   EQU 04006h',
     'RAM_STATUS_HI_SHADOW   EQU 04007h',
     'RAM_COMMAND_MODE       EQU 04507h',
     'RAM_DOCUMENT_COUNT     EQU 04593h',
     'RAM_DOCUMENT_DIRECTORY EQU 04598h',
     'RAM_DOCUMENT_START     EQU 04800h',
     '',
     '; Notes: some Z80 assemblers treat certain undocumented prefixes differently.',
     '; Verify with compare_sources.py before burning any EPROM.',
     '']
    full='\n'.join(header+output)
    (OUTPUT_DIR/'LEX31_full_annotated.asm').write_text(full)

    # A byte-level audit that uses the actual generated source annotations and verifies
    # every address exactly once, plus disassembler length checks for code.
    proof=bytearray(0x3000);defined=set();bad=[];inst_bytes=0;db_bytes=0;inst_count=0
    for ln in full.splitlines():
     m=re.search(r'; @([0-9A-F]{4})  ([0-9A-F ]+)(?:  |$)',ln)
     if not m:continue
     start=int(m.group(1),16);raw=bytes.fromhex(m.group(2).strip())
     if start+len(raw)>len(B):bad.append(f'past end {start:X}');continue
     if any(k in defined for k in range(start,start+len(raw))):bad.append(f'duplicate {start:X}')
     proof[start:start+len(raw)]=raw;defined.update(range(start,start+len(raw)))
     if re.match(r'\s+DB\b',ln):db_bytes+=len(raw)
     else:inst_bytes+=len(raw);inst_count+=1
    assert not bad and len(defined)==0x3000 and proof==B,(bad,len(defined),proof==B)
    (OUTPUT_DIR/'LEX31_verified_combined.bin').write_bytes(proof)
    # Per-ROM images extracted from reconstructed source for binary comparison
    for i,n in enumerate(ROMNAMES):(OUTPUT_DIR/f'{n[:-4]}_rebuilt.bin').write_bytes(proof[i*4096:(i+1)*4096])

    with (OUTPUT_DIR/'ROM_cross_references.csv').open('w',newline='') as f:
     w=csv.writer(f);w.writerow(['target','target_label','source','instruction','reachable'])
     for target in sorted(refs):
      for source in sorted(refs[target]):w.writerow([f'{target:04X}',labels.get(target,''),f'{source:04X}',seen[source].asm,'yes'])
    with (OUTPUT_DIR/'ROM_io_references.csv').open('w',newline='') as f:
     w=csv.writer(f);w.writerow(['address','port','direction_or_operand','instruction','qualification'])
     for pc,i in sorted(seen.items()):
      if i.port is not None:w.writerow([f'{pc:04X}',f'{i.port:02X}' if isinstance(i.port,int) else i.port,'read' if i.asm.startswith('IN ') else 'write' if i.asm.startswith('OUT ') else 'unknown',i.asm,'physical decode unresolved'])
    with (OUTPUT_DIR/'ROM_handler_index.csv').open('w',newline='') as f:
     w=csv.writer(f);w.writerow(['keycode','mode','handler','source_ROM','disassembled_entry'])
     for start,key,mode,addr in command_entries:w.writerow([f'{key:02X}',f'{mode:02X}',f'{addr:04X}',f'U{2+addr//4096}',addr in seen])

    with (OUTPUT_DIR/'ROM_RAM_access_index.csv').open('w',newline='') as f:
     w=csv.writer(f);w.writerow(['instruction_address','referenced_RAM_address','mnemonic','qualification'])
     for pc,ins in sorted(seen.items()):
      for m in re.finditer(r'(?<![\w])([4-7][0-9A-F]{3})h',ins.asm):
       addr=int(m.group(1),16)
       if addr>=0x4000:w.writerow([f'{pc:04X}',f'{addr:04X}',ins.asm,'may be pointer constant, verify runtime'])

    print(f'ROM bytes: {len(B)}, decoded code bytes: {inst_bytes} ({inst_bytes*100/len(B):.1f}%), undecoded/data bytes {db_bytes}, code instructions {inst_count}, jump destinations {len(refs)}, entrypoints {len(SEEDS)}')
    print('SHA256',hashlib.sha256(proof).hexdigest());print('Decode issues',len(failures),'first few',failures[:30]);print('Output',OUTPUT_DIR/'LEX31_full_annotated.asm')

if __name__ == "__main__":
    generate_source()
