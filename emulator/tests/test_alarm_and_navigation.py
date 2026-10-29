"""Regression tests for the spurious clock-alarm prompt and direct-entry controls.

These tests validate ROM bytes, device state, UI key bindings and debugger
logging without claiming a full CPU/OS integration test on physical hardware.
"""
import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lex31_machine import Machine, RTC, put_word
from test_machine import FakeCPU


class AlarmAndNavigationTests(unittest.TestCase):
    def new(self):
        return Machine(cpu_factory=FakeCPU, periodic=False)

    def test_alarm_prompt_is_genuine_firmware_alarm_handler(self):
        m=self.new()
        self.assertEqual(m.rom[0x0f61:0x0f64], bytes.fromhex('21 ba 11'))
        self.assertEqual(m.rom[0x0f70:0x0f72], bytes.fromhex('fe 8e'))
        self.assertEqual(m.rom[0x0f72:0x0f74], bytes.fromhex('20 f3'))

    def test_firmware_alarm_suppressed_when_rtc_off(self):
        # 0F41: LD A,(4660), 0F44: DEC A, 0F45: RET Z.
        m=self.new()
        self.assertEqual(m.rom[0x0f41:0x0f46], bytes.fromhex('3a 60 46 3d c8'))
        self.assertEqual(m.rtc.regs[0x0f], 1)
        self.assertEqual(RTC().regs[0x0f], 1)

    def test_alarm_debugger_logs_delivery_and_exit(self):
        m=self.new()
        m.cpu.pc=0x0f5e
        m.step()
        self.assertTrue(m.alarm_active)
        m.cpu.pc=0x0f70
        m.cpu.a=0x8e
        m.step()
        self.assertEqual(m.last_os_key, 0x8e)
        m.cpu.pc=0x0f74
        m.step()
        self.assertFalse(m.alarm_active)
        self.assertTrue(any('XIT accepted' in line for line in m.events))

    def test_main_dispatch_debugging(self):
        m=self.new()
        m.cpu.pc=0x00e8
        m.cpu.a=0x95
        m.step()
        self.assertTrue(any('main dispatcher received 95h' in line for line in m.events))

    def test_direct_entry_keycodes_against_real_rom(self):
        m=self.new()
        # Mode 00 byte following keycode, then little-endian entry address.
        assignments={
            0x95:0x223e,  # SHIFT+LOCAL -> editor
            0x93:0x163e,  # SHIFT+SET -> configuration
            0x8a:0x1f09,  # INDEX
            0x94:0x291a,  # SHIFT+CALC
        }
        table=m.rom
        index=0x0f7d
        mode_zero={}
        while index<0x10bf:
            key=table[index]
            if key==0:break
            count=table[index+1]
            index+=2
            for _ in range(count):
                mode,low,high=table[index:index+3]
                if mode==0:mode_zero[key]=low|(high<<8)
                index+=3
        for key,addr in assignments.items():
            self.assertEqual(mode_zero.get(key),addr, f'key {key:02X}')
        self.assertEqual(m.rom[0x0238:0x023a], bytes.fromhex('4f 3a'))
        self.assertEqual(m.rom[0x0241:0x0247], bytes.fromhex('21 e5 1f fe 90 28'))
        self.assertEqual(m.rom[0x0248:0x024e], bytes.fromhex('21 6b 0c fe 8b 28'))

    def test_queued_xit_does_not_synthetically_change_os_mode(self):
        m=self.new()
        put_word(m.mem,0x44af,0xffc0)
        self.assertTrue(m.inject_key(0x8e))
        self.assertEqual(m.mem[0x44b5],0x8e)
        self.assertEqual(m.mem[0x4507],0)


if __name__=='__main__': unittest.main()
