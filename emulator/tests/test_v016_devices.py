"""Regression for the v0.1.6 LCD/RTC/battery and GUI manual-alignment work."""
import sys
import unittest
from datetime import datetime
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lex31_machine import Machine, LCD, RTC, bcd
from test_machine import FakeCPU


class ManualAlignmentTests(unittest.TestCase):
    def test_single_line_display_and_underlined_cursor(self):
        lcd=LCD()
        lcd.select(0)
        lcd.write(0x0e) # display on, underline cursor on, blink off
        lcd.write(0x82) # DDRAM column 2
        lcd.select(0x20)
        lcd.write(ord('A'))
        self.assertEqual(lcd.cursor_column(),3)
        self.assertEqual(lcd.cursor_column(1),-1)
        self.assertEqual(lcd.text(0)[2],'A')
        lcd.select(0)
        lcd.write(0x0c) # display on, cursor disabled
        self.assertEqual(lcd.cursor_column(),-1)
        lcd.write(0x08) # display off
        self.assertEqual(lcd.text(0),' '*40)

    def test_display_shift_does_not_modify_ddram(self):
        lcd=LCD()
        lcd.ddram[0]=ord('X')
        lcd.select(0)
        lcd.write(0x18) # shift window to the right
        self.assertEqual(lcd.ddram[0],ord('X'))
        self.assertEqual(lcd.text(0)[39],'X')
        lcd.write(0x02) # return home clears window shift
        self.assertEqual(lcd.text(0)[0],'X')

    def test_rtc_ticks_and_day_month_rollover(self):
        t=[100.0]
        rtc=RTC(clock=lambda:t[0], initial_datetime=datetime(2026, 1, 1))
        for addr,value in [(2,0x58),(3,0x59),(4,0x23),(5,0x07),(6,0x31),(7,0x01)]:
            rtc.write(addr,value)
        t[0]+=3.4
        self.assertEqual([rtc.read(a) for a in (2,3,4,5,6,7)],
                         [0x01,0x00,0x00,0x01,0x01,0x02])
        self.assertEqual(rtc.read(1),0x40)
        self.assertEqual(rtc.read(0x14),0)

    def test_rtc_interrupt_controls_are_separate_from_alarm_ram(self):
        rtc=RTC(clock=lambda:0.0)
        self.assertEqual(rtc.regs[0x0f],1)  # existing firmware guard
        rtc.write(0x11,0x80)
        self.assertEqual(rtc.read(0x11),0x80)
        rtc.write(0x10,0xff)
        self.assertEqual(rtc.read(0x10),0) # status read-only
        rtc.write(0x13,0)
        self.assertEqual(rtc.read(0x0f),0)

    def test_battery_input_is_default_inactive_not_stuck_on(self):
        m=Machine(cpu_factory=FakeCPU)
        self.assertEqual(m.port_in(0x43)&0x0c,0x0c)
        m.battery_low=True
        self.assertEqual(m.port_in(0x43)&0x0c,0x08)
        m.reset(preserve_ram=True)
        self.assertTrue(m.battery_low)

    def test_battery_backed_ram_and_clock_preserved_on_warm_reset(self):
        m=Machine(cpu_factory=FakeCPU)
        m.mem[0x4720]=0x57
        m.rtc.write(2,0x12)
        before=m.rtc
        m.reset(preserve_ram=True)
        self.assertEqual(m.mem[0x4720],0x57)
        self.assertIs(m.rtc,before)
        m.reset(preserve_ram=False)
        self.assertEqual(m.mem[0x4720],0)
        self.assertIsNot(m.rtc,before)

if __name__=='__main__':unittest.main()
