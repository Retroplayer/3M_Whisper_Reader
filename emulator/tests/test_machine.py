"""Device-level tests run without z80-python; no claim of full ROM boot."""
import unittest
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from lex31_machine import Machine, LCD, BASE, word, put_word

class FakeCPU:
    def __init__(self,rd,wr,*,read_port,write_port):
        self.rd=rd;self.wr=wr;self.inport=read_port;self.outport=write_port
        self.pc=0;self.sp=0x4800
        self.a=self._f=self.b=self.c=self.d=self.e=self.h=self.l=0
        self.bc=self.de=self.hl=self.ix=self.iy=0
        self.iff1=self.iff2=False
        self._ei_delay=0
    @property
    def f(self):return self._f
    def step(self):self.pc=(self.pc+1)&0xffff;return 4

class FlagsViewStub:
    """Mimic the public z80-python flag API, including absent __format__."""
    def __init__(self, value):
        self.value = value
    def __int__(self):
        return self.value


class StrictRegisterCPU(FakeCPU):
    """Expose the *actual* z80-python register API, not invented word pairs."""
    def __init__(self, rd, wr, *, read_port, write_port):
        super().__init__(rd, wr, read_port=read_port, write_port=write_port)
        del self.bc, self.de, self.hl
        self.a, self.b, self.c = 0x12, 0x34, 0x56
        self.d, self.e, self.h, self.l = 0x78, 0x9A, 0xBC, 0xDE
        self._f = 0xA5
    @property
    def f(self):
        return FlagsViewStub(self._f)


class Tests(unittest.TestCase):
    def new(self):return Machine(cpu_factory=FakeCPU)
    def test_factory_rom(self):
        m=self.new()
        self.assertTrue(m.is_original)
        self.assertEqual(m.read(0),0xf3)
        self.assertEqual(m.read(0x1000),m.rom[0x1000])
        self.assertEqual(m.read(0x2fff),m.rom[-1])
    def test_rom_protection_and_ram_probe(self):
        m=self.new();m.write(0,0);self.assertEqual(m.read(0),0xf3)
        m.write(0x8000,0xaa);self.assertEqual(m.read(0x8000),0xff)
        m.write(0x4800,0xaa);self.assertEqual(m.read(0x4800),0xaa)
    def test_rtc_banked_over_ram(self):
        m=self.new();m.write(0x4011,0xab)
        m.port_out(0x47,0x40);m.write(0x4011,0x07)
        self.assertEqual(m.rtc.regs[0x11],0x07)
        m.port_out(0x47,0);self.assertEqual(m.read(0x4011),0xab)
    def test_rtc_rollover_status_stable(self):
        m=self.new();m.port_out(0x47,0x40)
        self.assertEqual(m.read(0x4014)&1,0)
    def test_lcd_command_and_data(self):
        m=self.new();m.port_out(0x47,0);m.port_out(0x4b,0x38)
        self.assertTrue(m.lcd.two_lines)
        m.port_out(0x4b,0xc0)
        m.port_out(0x47,0x20)
        for x in b'HELLO':m.port_out(0x4b,x)
        self.assertTrue(m.lcd.text(1).startswith('HELLO'))
        m.port_out(0x47,0);m.port_out(0x4b,0xc0)
        m.port_out(0x47,0x30)
        self.assertEqual(m.port_in(0x4b),ord('H'))
    def test_lcd_descenders_match_hd44780_rom_translation(self):
        # LEX-31 U2 ROM 0791h maps g/j/p/q/y to E7/EA/F0/F1/F9.
        lcd=LCD()
        lcd.ddram[:len(b'Factor\xf9')]=b'Factor\xf9'
        self.assertTrue(lcd.text().startswith('Factory'))
        lcd.ddram[:len(b'\xf0ress "xit"')]=b'\xf0ress "xit"'
        self.assertTrue(lcd.text().startswith('press "xit"'))
        lcd.ddram[:5]=bytes([0xe7,0xea,0xf0,0xf1,0xf9])
        self.assertTrue(lcd.text().startswith('gjpqy'))
        self.assertEqual(LCD.display_glyph(0x02),'•')

    def test_xit_keycode_in_documented_rom(self):
        # Dispatch table for keycode 8Eh: mode 01 (editor) -> 2400h;
        # 06 (help) -> 204Bh. 91h is RUB/backspace and must NOT be used.
        m=self.new()
        rom=m.rom
        self.assertEqual(rom[0x109f], 0x8e)
        self.assertIn(bytes([0x01,0x00,0x24]), rom[0x109f:0x10c0])
        self.assertIn(bytes([0x06,0x4b,0x20]), rom[0x109f:0x10c0])
        self.assertEqual(rom[0x0fce], 0x91)
        self.assertIn(bytes([0x01,0x40,0x25]), rom[0x0fce:0x0fdc])
        put_word(m.mem,0x44af,0xffc0)
        self.assertTrue(m.inject_key(0x8e))
        self.assertEqual(m.mem[0x44b5],0x8e)

    def test_lcd_cgram(self):
        lcd=LCD();lcd.select(0);lcd.write(0x40);lcd.select(0x20);lcd.write(0x1e)
        self.assertEqual(lcd.cgram[0],0x1e)
    def test_status_latches(self):
        m=self.new();m.port_out(0x4f,0x21);m.port_out(0x53,0x88)
        self.assertEqual(m.status_bits(),0x2188)
    def test_printer_and_uart(self):
        m=self.new();m.port_out(0xd7,0x41);m.port_out(0x5b,0x42)
        self.assertEqual(m.printer,b'A');self.assertEqual(m.serial_tx,b'B')
        m.inject_serial(b'Z');self.assertEqual(m.port_in(0x5f)&8,8)
        self.assertEqual(m.port_in(0x5b),ord('Z'))
    def test_queue_injection_and_wrap(self):
        m=self.new();self.assertFalse(m.inject_key(0x41))
        put_word(m.mem,0x44af,0xffc0)
        for n in range(64):self.assertTrue(m.inject_key(n))
        self.assertFalse(m.inject_key(0xfe))
        self.assertEqual(word(m.mem,0x44ad),64)
        self.assertEqual(word(m.mem,0x44b3),0)
        self.assertEqual(m.mem[0x44b5],0)
        self.assertEqual(m.mem[0x44b5+63],63)
    def test_reset_retain_ram(self):
        m=self.new();m.mem[0x4593]=0x07;m.reset(preserve_ram=True)
        self.assertEqual(m.mem[0x4593],7);m.reset();self.assertEqual(m.mem[0x4593],0)
    def test_breakpoint_and_unknown_execution(self):
        m=self.new();m.breakpoints.add(0)
        self.assertEqual(m.step().steps,0)
        m.breakpoints.clear();m.resume();m.cpu.pc=0xc000
        self.assertIn('outside known',m.step().reason)
    def test_periodic_vector_stack(self):
        m=self.new();m.icr=6;m.cpu.pc=0x1a2b;m.cpu.sp=0x4800;m.cpu.iff1=True
        m._periodic();self.assertEqual(m.cpu.pc,0x2c)
        self.assertEqual(m.cpu.sp,0x47fe)
        self.assertEqual(m.read(0x47fe),0x2b)
        self.assertEqual(m.read(0x47ff),0x1a)
    def test_z80_python_public_api_summary(self):
        """Regression: FlagsView is not format-able and BC/DE/HL don't exist."""
        m=Machine(cpu_factory=StrictRegisterCPU)
        status=m.summary()
        for part in ('AF=12A5','BC=3456','DE=789A','HL=BCDE'):
            self.assertIn(part, status)
        self.assertEqual(m.cpu.pc, 0)

    def test_z80_python_public_api_instruction_trace(self):
        m=Machine(cpu_factory=StrictRegisterCPU)
        m.trace_enabled=True
        self.assertEqual(m.step().steps, 1)
        self.assertTrue(m.trace)
        self.assertIn('AF=12A5 BC=3456 DE=789A HL=BCDE', m.trace[0])

    def test_headless_can_step(self):
        m=self.new();res=m.run(100)
        self.assertEqual(res.steps,100);self.assertEqual(m.cpu.pc,100)

if __name__=='__main__':unittest.main()
