"""3M Whisper Reader / LEX-31 functional bus model (research emulator).

CPU dependency: alewman/z80-python >=0.4.0 (MIT). This is NOT an electrical,
cycle-accurate, or complete NSC800 simulator. Unknown hardware is traced.
"""
from __future__ import annotations
from collections import deque
from dataclasses import dataclass
from pathlib import Path
import hashlib
import time
from datetime import datetime

BASE = Path(__file__).resolve().parent
FACTORY_SHA = '0b395efd163f70127adfdbd5b234e1f5ee5ff490c8e7386b5c7f5b9faa4b6b12'
ROMS = ('red_u2.bin','green_u3.bin','white_u4.bin')


def default_rom_files():
    """Locate untouched EPROMs in a standalone install or this repository."""
    for directory in (BASE / 'roms', BASE.parent / 'roms' / 'original'):
        files = tuple(directory / name for name in ROMS)
        if all(path.is_file() for path in files):
            return files
    raise FileNotFoundError(
        'Missing original ROM images. Copy red_u2.bin, green_u3.bin and '
        'white_u4.bin into emulator/roms/, or run from the complete '
        '3M_Whisper_Reader repository containing roms/original/. '
        'Original ROM data is never altered by this emulator.'
    )


def word(buf, addr):
    return (buf[addr] << 8) | buf[addr+1]


def put_word(buf, addr, val):
    buf[addr] = (val >> 8) & 255
    buf[addr+1] = val & 255


def bcd(n):
    n %= 100
    return ((n // 10) << 4) | n % 10


def cpu_register_pairs(cpu):
    """Read 16-bit Z80 register pairs using z80-python's public 8-bit registers.

    z80-python >= 0.4 exposes A, F, B, C, D, E, H and L separately.  F is a
    FlagsView (convert with int()); BC/DE/HL are *not* public CPU attributes.
    This helper also works with the FakeCPU used in device regression tests.
    """
    bc = ((cpu.b & 0xff) << 8) | (cpu.c & 0xff)
    de = ((cpu.d & 0xff) << 8) | (cpu.e & 0xff)
    hl = ((cpu.h & 0xff) << 8) | (cpu.l & 0xff)
    return int(cpu.f) & 0xff, bc, de, hl


class LCD:
    """HD44780-compatible *functional* DDRAM/CGRAM, busy flag assumed clear.

    Port 47h selects command/read/write mode; port 4Bh carries the byte.
    Refer to U2 0742h-077Ch. Not a signal/timing simulation.
    """
    def __init__(self): self.reset()

    def reset(self):
        self.ddram = bytearray(b' ' * 128)
        self.cgram = bytearray(64)
        self.address = 0
        self.in_cgram = False
        self.mode = 0
        self.entry_inc = True
        self.display_on = True
        self.two_lines = False
        self.cursor_on = False
        self.blink_on = False
        self.display_shift = 0
        self.command_history = deque(maxlen=60)
        self.data_writes = 0

    def select(self, value): self.mode = value & 0x30

    def write(self, value):
        value &= 255
        if self.mode == 0x20: self.data(value)
        elif self.mode == 0x00: self.command(value)
        # Other combinations are read modes; a write there is ignored.

    def read(self):
        if self.mode == 0x10: return self.address & 0x7f  # busy flag always 0
        if self.mode == 0x30:
            x = self.cgram[self.address & 63] if self.in_cgram else self.ddram[self.address & 127]
            self.bump()
            return x
        return 0xff

    def bump(self): self.address = (self.address + (1 if self.entry_inc else -1)) & (63 if self.in_cgram else 127)

    def command(self, value):
        self.command_history.append(value)
        if value & 0x80:
            self.in_cgram = False
            self.address = value & 0x7f
        elif value & 0x40:
            self.in_cgram = True
            self.address = value & 0x3f
        elif value & 0x20: self.two_lines = bool(value & 0x08)
        elif value & 0x10:
            if value & 0x08:
                # HD44780 S/C=1 shifts the visible window rather than DDRAM.
                self.display_shift = (self.display_shift + (-1 if value & 0x04 else 1)) % 40
            else:
                self.address = (self.address + (1 if value & 0x04 else -1)) & 0x7f
        elif value & 0x08:
            self.display_on = bool(value & 0x04)
            self.cursor_on = bool(value & 0x02)
            self.blink_on = bool(value & 0x01)
        elif value & 0x04: self.entry_inc = bool(value & 0x02)
        elif value == 0x02: self.in_cgram=False; self.address=0; self.display_shift=0
        elif value == 0x01: self.ddram[:] = b' '*128; self.in_cgram=False; self.address=0; self.display_shift=0

    def data(self,value):
        if self.in_cgram: self.cgram[self.address & 63] = value & 31
        else: self.ddram[self.address & 127] = value
        self.bump()
        self.data_writes += 1

    # LEX-31 ROM table at 0791h deliberately sends these five lowercase
    # descenders to the Japanese HD44780 CGROM, where the 5x10 font provides
    # a descending glyph. They are NOT unrecognized/display-error bytes.
    # A Unicode-capable PC display can render the letters directly.
    DESCENDERS = {0xE7: 'g', 0xEA: 'j', 0xF0: 'p', 0xF1: 'q', 0xF9: 'y'}

    @classmethod
    def display_glyph(cls, value):
        if value in cls.DESCENDERS:
            return cls.DESCENDERS[value]
        if 0x20 <= value < 0x7f:
            return chr(value)
        # 00h-07h are programmable CGRAM glyphs, not ASCII text. Keep an
        # explicit placeholder until pixel-level CGRAM drawing is provided.
        return '•' if value < 8 else '·'

    def text(self, row=0, cols=40):
        if not self.display_on:
            return ' ' * cols
        start = 0 if row == 0 else 0x40
        # Display shift changes what is visible, not the DDRAM contents.
        # It wraps within the 40-column bank of this terminal's LCD.
        return ''.join(self.display_glyph(self.ddram[start + ((i + self.display_shift) % 40)])
                       for i in range(cols))

    def cursor_column(self, row=0, cols=40):
        """Visible underline-column or -1 if disabled/outside the active row."""
        if not self.display_on or not self.cursor_on or self.in_cgram:
            return -1
        start = 0 if row == 0 else 0x40
        address = self.address - start
        if not 0 <= address < 40:
            return -1
        col = (address - self.display_shift) % 40
        return col if col < cols else -1


class RTC:
    """Wall-clock-driven MM58167 counter/register approximation.

    NSC MM58167 register map: BCD counters at 00h-07h, alarm RAM at 08h-0Fh,
    interrupt status/control at 10h/11h, rollover flag at 14h. The unmodified
    LEX-31 ROM repurposes battery-backed RTC RAM 0Ah (century) and 09h (year)
    to hold its four-digit calendar year in BCD (factory table 0BBFh: 19 83).
    Timekeeping progresses on reads/writes using a monotonic clock. There is
    no autonomous year counter in the physical RTC; firmware handles year
    rollover. No external IRQ, alarm comparator or exact chip timing.
    """
    MONTH_DAYS=(31,28,31,30,31,30,31,31,30,31,30,31)

    def __init__(self, clock=None, initial_datetime=None):
        self.clock=clock if clock is not None else time.monotonic
        self._last=self.clock()
        self._fraction=0.0
        self.regs=bytearray(32)
        self.accesses=0
        # Preserved from prior releases, avoids inadvertent factory alarm
        # behavior; 0Fh is actually alarm-RAM MONTH, not an alarm-enable bit.
        self.regs[0x0f]=1
        # New hardware gets its starting calendar from the host, rather than
        # exposing an invalid 0000 year and requiring thousands of Up presses.
        # This updates emulated RTC/RAM registers ONLY; the ROM is unchanged.
        self.set_datetime(initial_datetime)

    def set_datetime(self, dt=None):
        """Seed the emulated RTC from the PC calendar or a test datetime.

        LEX-31 firmware stores century/year in the MM58167's spare RTC RAM
        locations 0Ah/09h. The weekday counter uses Sunday=1, Saturday=7,
        as confirmed by the original ROM factory date (1983-01-01 -> 07h).
        Deliberately preserve alarm/configuration RAM outside the calendar.
        """
        if dt is None:
            dt=datetime.now()  # PC's local date/time, not container UTC on Windows
        self._last=self.clock()
        self._fraction=dt.microsecond/1_000_000.0
        self.regs[0]=((dt.microsecond//1000)%10)<<4
        self.regs[1]=bcd(dt.microsecond//10000)
        self.regs[2]=bcd(dt.second)
        self.regs[3]=bcd(dt.minute)
        self.regs[4]=bcd(dt.hour)
        self.regs[5]=1 + ((dt.weekday()+1)%7)  # Sun=1, Mon=2, ... Sat=7
        self.regs[6]=bcd(dt.day)
        self.regs[7]=bcd(dt.month)
        self.regs[0x0a]=bcd(dt.year//100)
        self.regs[0x09]=bcd(dt.year%100)

    @staticmethod
    def _dec(x):
        return 10*((x>>4)&15)+(x&15)

    def _tick(self, elapsed):
        if elapsed<=0:return
        old_second=min(59,self._dec(self.regs[2]))
        old_minute=min(59,self._dec(self.regs[3]))
        old_hour=min(23,self._dec(self.regs[4]))
        new_secs=old_hour*3600+old_minute*60+old_second+elapsed
        days,seconds=divmod(new_secs,86400)
        hours,seconds=divmod(seconds,3600)
        minutes,seconds=divmod(seconds,60)
        self.regs[2]=bcd(seconds)
        self.regs[3]=bcd(minutes)
        self.regs[4]=bcd(hours)
        if days:
            dow=self.regs[5]&7
            self.regs[5]=1+((max(1,dow)-1+days)%7)
            day=max(1,min(31,self._dec(self.regs[6])))
            month=max(1,min(12,self._dec(self.regs[7])))
            # RTC has no year counter; the original ROM uses 09h/0Ah in
            # battery-backed RAM to maintain the year and leap-day rules.
            while days:
                left=self.MONTH_DAYS[month-1]-day
                if days<=left:
                    day+=days;days=0
                else:
                    days-=left+1;day=1;month=1+(month%12)
            self.regs[6]=bcd(day)
            self.regs[7]=bcd(month)

    def _sync(self):
        now=self.clock()
        elapsed=max(0.0, now-self._last)
        self._last=now
        self._fraction+=elapsed
        ticks=int(self._fraction)
        self._fraction-=ticks
        if ticks:self._tick(ticks)
        # 01h holds tenths/hundredths BCD; 00h milliseconds, high nibble.
        hund=int(self._fraction*100+1e-8)
        self.regs[1]=bcd(hund)
        self.regs[0]=((int(self._fraction*1000)%10)<<4)

    def read(self,addr):
        self.accesses+=1
        self._sync()
        idx=addr&31
        if idx==0x14:return 0 # no asynchronous bus-rollover within one read
        if idx==0x10:
            status=self.regs[0x10]
            self.regs[0x10]=0   # interrupt status read clears latch
            return status
        return self.regs[idx]

    def write(self,addr,value):
        self.accesses+=1
        self._sync()
        idx=addr&31
        if idx in (0x12,0x13):
            # Counter reset (12h) and alarm RAM reset (13h).
            begin,end=(0,8) if idx==0x12 else (8,16)
            self.regs[begin:end]=b'\x00'*(end-begin)
            self._fraction=0.0
        elif idx==0x15:  # GO command: restart fractional second timing
            self._fraction=0.0
        elif idx==0x14:  # rollover is read only
            return
        else:
            self.regs[idx]=value&255
            if idx==0x01:
                self._fraction=min(0.99,self._dec(value)/100.0)
            if idx==0x10:self.regs[0x10]=0 # status is read-only


@dataclass
class RunResult:
    steps: int
    cycles: int
    reason: str


class Machine:
    def __init__(self, rom=None, cpu_factory=None, periodic=True, interval=16000):
        if rom is None:
            rom=b''.join(path.read_bytes() for path in default_rom_files())
        if len(rom)!=0x3000: raise ValueError('Expected a combined 12,288-byte U2+U3+U4 image')
        self.rom=bytes(rom)
        if cpu_factory is None:
            try: from z80_python import Z80CPU
            except ImportError as e:
                raise RuntimeError('Z80 CPU core missing. Run START_EMULATOR.bat, or: py -3.11 -m pip install "z80-python>=0.4,<0.5"') from e
            cpu_factory=Z80CPU
        self.cpu_factory=cpu_factory
        self.periodic_enabled=periodic
        self.interrupt_period=max(1000,int(interval))
        self.breakpoints=set()
        self.trace_enabled=False
        self.trace=deque(maxlen=1000)
        self.events=deque(maxlen=500)
        self.event_counts={}
        self.event_total=0
        self.reset()

    @property
    def is_original(self):return hashlib.sha256(self.rom).hexdigest()==FACTORY_SHA

    def event(self,kind,msg,unique=False):
        k=(kind,msg)
        self.event_counts[k]=self.event_counts.get(k,0)+1
        if not unique or self.event_counts[k]==1:
            self.events.append(f'{self.cycles:>10} {kind:<6} {msg}')
            self.event_total+=1

    def reset(self, preserve_ram=False):
        retained=getattr(self,'mem',None)
        retained_rtc=getattr(self,'rtc',None) if preserve_ram else None
        retained_battery=getattr(self,'battery_low',False)
        self.mem=bytearray(65536)
        self.mem[:0x3000]=self.rom
        if preserve_ram and retained is not None:self.mem[0x4000:0x8000]=retained[0x4000:0x8000]
        self.lcd=LCD()
        self.rtc=retained_rtc if retained_rtc is not None else RTC()
        self.battery_low=retained_battery
        self.ports=bytearray(256)
        self.icr=0
        self.serial_rx=deque()
        self.serial_tx=bytearray()
        self.printer=bytearray()
        self.cycles=0
        self.steps=0
        self.next_irq=self.interrupt_period
        self.halt_reason=None
        self.alarm_active=False
        self.last_os_key=None
        self.events.clear();self.event_counts.clear();self.trace.clear();self.event_total=0
        self.cpu=self.cpu_factory(self.read,self.write,read_port=self.port_in,write_port=self.port_out)
        self.event('RESET','ROM original' if self.is_original else 'custom ROM image')

    def read(self,addr):
        addr &= 0xffff
        if 0x4000<=addr<0x4020 and (self.ports[0x47]&0x40):
            return self.rtc.read(addr)
        if 0<=addr<0x3000 or 0x4000<=addr<0x8000:return self.mem[addr]
        return 0xff

    def write(self,addr,value):
        addr &= 0xffff;value &=255
        if 0x4000<=addr<0x4020 and self.ports[0x47]&0x40:
            self.rtc.write(addr,value);return
        if 0x4000<=addr<0x8000:
            self.mem[addr]=value;return
        if addr<0x3000:self.event('ROM','ignored write %04X=%02X'%(addr,value),unique=True)

    def port_in(self,port):
        port&=255
        if port==0x47:return 0xff   # no key pressed on unmodeled raw matrix
        if port==0x4b:return self.lcd.read()
        if port==0x4f:return 0x04   # provisional printer-status input, see 01FAh
        if port==0x53:return self.ports[port]
        if port==0x5b:return self.serial_rx.popleft() if self.serial_rx else 0
        if port==0x5f:
            # bit 2 TX ready, bit 3 RX ready; bit 4=0 carrier available
            return 0x04 | (0x08 if self.serial_rx else 0)
        if port==0xd7:return 0x01   # printer ready
        if port==0x63:return 0
        if port==0x43:
            # Firmware samples *inverted* bits 2/3 to set status mask 8000h.
            # Actual board's battery-comparator pin has NOT been traced.
            # This is a selectable research hypothesis, not a proven pinout.
            return 0x08 if self.battery_low else 0x0c
        self.event('IN','unmapped port %02X'%port,unique=True)
        return 0xff

    def port_out(self,port,value):
        port&=255;value&=255
        self.ports[port]=value
        if port==0x47:self.lcd.select(value)
        elif port==0x4b:self.lcd.write(value)
        elif port in (0x4f,0x53):pass
        elif port==0x57:self.event('OUT','keyboard/status 57h=%02X'%value,unique=True)
        elif port==0x5b:self.serial_tx.append(value)
        elif port==0x5f:pass  # serial control shadow; electrical behavior unresolved
        elif port==0xd7:self.printer.append(value)
        elif port==0xbb:self.icr=value
        elif port==0x63:pass # unknown system/power latch
        else:self.event('OUT','unmapped port %02X=%02X'%(port,value),unique=True)

    def inject_key(self,value):
        """Insert *translated* keycode into the OS's queue; skips physical scanner.

        Queue at 44ADh, base+8 byte ring area: first 2 bytes count (big endian),
        next 2 bytes negative capacity (-64), next 2 read pointer, next 2
        write pointer, then 64 bytes at 44B5h. See 0288h and 02D8h.
        """
        value&=255
        count=word(self.mem,0x44ad)
        cap=word(self.mem,0x44af)
        if cap != 0xffc0:
            self.event('KEY','keyboard queue not initialized yet (cap %04X)'%cap,unique=True)
            return False
        if count>=64:self.event('KEY','keyboard queue full');return False
        idx=word(self.mem,0x44b3) % 64
        self.mem[0x44b5+idx]=value
        put_word(self.mem,0x44b3,(idx+1)%64)
        put_word(self.mem,0x44ad,count+1)
        self.event('KEY','injected OS key %02X'%value)
        return True

    def inject_serial(self,data):
        self.serial_rx.extend(data)
        self.event('RX','queued %d bytes'%len(data))

    def _periodic(self):
        # Approximation: NSC800 RSTC does not use conventional Z80 IM0/1/2.
        # Deliver direct vector 002Ch when ICR bit1 enabled and interrupts live.
        if not self.periodic_enabled or not (self.icr & 2) or not self.cpu.iff1:return
        if getattr(self.cpu,'_ei_delay',0):return
        pc=self.cpu.pc & 0xffff
        sp=(self.cpu.sp-2)&0xffff
        self.write(sp,pc&255);self.write((sp+1)&0xffff,(pc>>8)&255)
        self.cpu.sp=sp
        self.cpu.pc=0x002c
        self.cpu.iff1=False
        self.cpu.iff2=False
        self.event('IRQ','RSTC -> 002Ch',unique=True)

    def step(self):
        if self.halt_reason:return RunResult(0,0,self.halt_reason)
        pc=self.cpu.pc&65535
        if pc in self.breakpoints:
            self.halt_reason='breakpoint at %04X'%pc
            return RunResult(0,0,self.halt_reason)
        if pc>=0x8000:
            self.halt_reason='execution outside known ROM/RAM at %04X'%pc
            self.event('TRAP',self.halt_reason)
            return RunResult(0,0,self.halt_reason)
        if 0x3000<=pc<0x4000:
            self.halt_reason='execution in unmapped region %04X'%pc
            self.event('TRAP',self.halt_reason)
            return RunResult(0,0,self.halt_reason)
        if self.trace_enabled:
            flags,bc,de,hl=cpu_register_pairs(self.cpu)
            self.trace.append('%06d %04X %02X  AF=%02X%02X BC=%04X DE=%04X HL=%04X SP=%04X'%(
                self.steps,pc,self.read(pc),self.cpu.a,flags,bc,de,hl,self.cpu.sp))
        # Diagnostic hooks: verified from the unmodified ROM.  XIT at 8Eh is
        # caught directly inside the alarm dialog, not by the mode-00
        # command table (which contains no 8Eh entry).
        if pc==0x0f5e and not self.alarm_active:
            self.alarm_active=True
            self.event('ALARM','entered clock-alarm XIT prompt at 0F5Eh')
        elif pc==0x0f70:
            self.last_os_key=self.cpu.a&0xff
            self.event('KEY','alarm handler received %02Xh'%self.last_os_key)
        elif pc==0x0f74 and self.alarm_active:
            self.alarm_active=False
            self.event('ALARM','XIT accepted, restoring prior screen')
        elif pc==0x00e8:
            self.last_os_key=self.cpu.a&0xff
            self.event('KEY','main dispatcher received %02Xh in mode %02Xh'%(
                self.last_os_key,self.mem[0x4507]))
        try:t=self.cpu.step()
        except Exception as e:
            self.halt_reason='CPU error at %04X: %s'%(pc,e)
            self.event('ERROR',self.halt_reason)
            return RunResult(0,0,self.halt_reason)
        self.cycles+=t;self.steps+=1
        if self.cycles>=self.next_irq:
            self.next_irq=self.cycles+self.interrupt_period
            self._periodic()
        return RunResult(1,t,'ok')

    def run(self,limit=50000):
        start=self.cycles;n=0;reason='step limit'
        for _ in range(limit):
            r=self.step()
            if r.reason!='ok':reason=r.reason;break
            n+=1
        return RunResult(n,self.cycles-start,reason)

    def resume(self):self.halt_reason=None

    def ram_dump(self,start=0x4000,length=256):
        return bytes(self.mem[start:start+length])

    def summary(self):
        c=self.cpu
        flags,bc,de,hl=cpu_register_pairs(c)
        return (f'PC={c.pc:04X} SP={c.sp:04X} AF={c.a:02X}{flags:02X} '
                f'BC={bc:04X} DE={de:04X} HL={hl:04X} '
                f'IX={c.ix:04X} IY={c.iy:04X} IFF={int(c.iff1)} '
                f'ICR={self.icr:02X} steps={self.steps} cycles={self.cycles}')

    def status_bits(self):return (self.ports[0x4f]<<8)|self.ports[0x53]
