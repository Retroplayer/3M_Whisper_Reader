"""ROM-backed LEX-31 year register and PC-clock initialization regressions."""
import sys
import unittest
from datetime import datetime
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from lex31_machine import Machine, RTC
from test_machine import FakeCPU


class ClockStartupTests(unittest.TestCase):
    def test_factory_rom_year_layout_is_1983_in_spare_rtc_ram(self):
        machine = Machine(cpu_factory=FakeCPU)
        self.assertTrue(machine.is_original)
        # ROM 0BBFh defines RTC initialization fields in the 0C1Bh mapping:
        # 05h weekday, 07h month, 06h day, 0Ah century, 09h year.
        self.assertEqual(machine.rom[0x0bbf:0x0bbf+5],bytes([7,1,1,0x19,0x83]))
        self.assertEqual(machine.rom[0x0c1b:0x0c1b+5],bytes([5,7,6,10,9]))

    def test_cold_clock_seeds_bcd_2026_and_correct_weekday(self):
        dt=datetime(2026,10,29,17,49,23,420000)  # Thursday
        rtc=RTC(clock=lambda:100.0,initial_datetime=dt)
        self.assertEqual([rtc.read(a) for a in (2,3,4,5,6,7,10,9)],
                         [0x23,0x49,0x17,5,0x29,0x10,0x20,0x26])
        self.assertEqual(rtc.read(1),0x42)
        self.assertEqual(rtc.regs[0x0f],1)

    def test_emulated_hardware_bus_exposes_initialized_year(self):
        m=Machine(cpu_factory=FakeCPU)
        m.port_out(0x47,0x40)  # clock RAM bank selected by firmware
        century=m.read(0x400a)
        year=m.read(0x4009)
        self.assertEqual(RTC._dec(century)*100+RTC._dec(year),datetime.now().year)
        m.port_out(0x47,0)
        self.assertEqual(m.read(0x400a),m.mem[0x400a])  # regular RAM when unbanked

    def test_saturday_1983_is_day_7_in_factory_rtc(self):
        rtc=RTC(clock=lambda:100.0,initial_datetime=datetime(1983,1,1))
        self.assertEqual([rtc.regs[a] for a in (5,6,7,10,9)],[7,1,1,0x19,0x83])

    def test_sync_does_not_clear_year_alarm_or_nonclock_ram(self):
        m=Machine(cpu_factory=FakeCPU)
        m.mem[0x4510]=0x57
        m.rtc.regs[0x0f]=0x66
        m.rtc.set_datetime(datetime(2037,5,6,1,2,3))
        self.assertEqual([m.rtc.read(a) for a in (10,9,7,6,4,3,2)],
                         [0x20,0x37,0x05,0x06,0x01,0x02,0x03])
        self.assertEqual(m.rtc.regs[0x0f],0x66)
        self.assertEqual(m.mem[0x4510],0x57)
        self.assertTrue(m.is_original)

    def test_warm_reset_retains_manual_year_cold_reset_uses_pc_year(self):
        m=Machine(cpu_factory=FakeCPU)
        m.rtc.write(10,0x19)
        m.rtc.write(9,0x84)
        rtc=m.rtc
        m.reset(preserve_ram=True)
        self.assertIs(m.rtc,rtc)
        self.assertEqual([m.rtc.regs[10],m.rtc.regs[9]],[0x19,0x84])
        m.reset(preserve_ram=False)
        self.assertIsNot(m.rtc,rtc)
        year=RTC._dec(m.rtc.regs[10])*100+RTC._dec(m.rtc.regs[9])
        self.assertEqual(year,datetime.now().year)

    def test_clock_runs_without_autoincrementing_software_year(self):
        t=[20.0]
        rtc=RTC(clock=lambda:t[0],initial_datetime=datetime(2026,12,31,23,59,59))
        t[0]+=2
        self.assertEqual([rtc.read(a) for a in (2,3,4,6,7)],
                         [0x01,0x00,0x00,0x01,0x01])
        # Year counter belongs to the original firmware, not MM58167 hardware.
        self.assertEqual([rtc.regs[10],rtc.regs[9]],[0x20,0x26])

if __name__ == '__main__':
    unittest.main()
