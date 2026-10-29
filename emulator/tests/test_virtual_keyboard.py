"""ROM-based keyboard translation and pictured key coverage checks."""
import sys
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from lex31_keyboard import KEYS_BY_ID, KEY_ROWS, INVALID_CODE, translated_keycode, VirtualKeyboard, ui_keycode, CONFIG_SELECT_MODES
from lex31_machine import Machine
from test_machine import FakeCPU


class KeyboardMappingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.rom=Machine(cpu_factory=FakeCPU).rom

    def test_all_three_layers_are_rom_slices(self):
        for layer,offset in [('plain',0),('ctl',72),('shift',144)]:
            for row in KEY_ROWS:
                for spec in row:
                    if spec.group<0:
                        continue
                    self.assertEqual(translated_keycode(self.rom,spec.id,layer),
                                     self.rom[0x565+offset+8*spec.group+spec.bit])

    def test_every_pictured_key_present(self):
        self.assertEqual([len(row) for row in KEY_ROWS],[12,13,12,13,12,11])
        self.assertEqual(len(KEYS_BY_ID),73)
        for name in ('DJ','LINE','WORD','LABEL','ALL','SEARCH','INDEX','CLOCK',
                     'CTL','SHIFT-L','SHIFT-R','HLP','ESC','RUB','SPACE',
                     'PW','GO','CHG','XIT','CLR','ENTER'):
            self.assertIn(name,KEYS_BY_ID)

    def test_special_codes(self):
        expected={
            ('DJ','plain'):0x80,('DJ','ctl'):0xc0,
            ('LINE','plain'):0x81,('WORD','plain'):0x82,
            ('LABEL','plain'):0x83,('ALL','plain'):0x88,
            ('SEARCH','plain'):0x89,('INDEX','plain'):0x8a,
            ('CLOCK','plain'):0x8b,('HLP','plain'):0x90,
            ('XIT','plain'):0x8e,('XIT','shift'):0x96,
            ('CHG','plain'):0x8d,('CHG','shift'):0x95,
            ('GO','plain'):0x8c,('GO','shift'):0x94,
            ('PW','plain'):0x98,('PW','shift'):0x93,
            ('CLR','plain'):0x8f,('CLR','shift'):0x97,
            ('RUB','plain'):0x91,('RUB','shift'):0x92,
            ('ENTER','plain'):0x0d,('ENTER','shift'):0x0a,
            ('LEFT','plain'):0x87,('RIGHT','plain'):0x84,
            ('UP','plain'):0x86,('DOWN','plain'):0x85,
            ('ESC','plain'):0x1b,('ESC','shift'):0xff,
            ('1','plain'):ord('1'),('1','shift'):ord('!'),
            ('A','plain'):ord('a'),('A','shift'):ord('A'),
            ('A','ctl'):1,('@','ctl'):0,
            ('1','ctl'):INVALID_CODE,
        }
        for (name,layer),code in expected.items():
            self.assertEqual(translated_keycode(self.rom,name,layer),code,(name,layer))

    def test_enter_confirm_alias_matches_real_rom_config_dispatch(self):
        # Read the *actual* command table; no invented mode/key assumptions.
        handlers={}
        pos=0x0f7d
        while pos<0x10bf:
            key=self.rom[pos]
            if key==0:
                break
            count=self.rom[pos+1]
            pos+=2
            for _ in range(count):
                mode,lo,hi=self.rom[pos:pos+3]
                handlers[(key,mode)]=lo | (hi<<8)
                pos+=3
        self.assertEqual(CONFIG_SELECT_MODES, frozenset((0x02,0x09)))
        self.assertEqual(handlers[(0x8d,0x02)],0x166c)
        self.assertEqual(handlers[(0x8d,0x09)],0x1792)
        self.assertNotIn((0x0d,0x02),handlers)
        self.assertNotIn((0x0d,0x09),handlers)
        self.assertEqual(translated_keycode(self.rom,'ENTER','plain'),0x0d)
        self.assertEqual(translated_keycode(self.rom,'CHG','plain'),0x8d)
        for mode in (2,9):
            self.assertEqual(ui_keycode(0x0d,mode),0x8d)
            self.assertEqual(ui_keycode(0x8d,mode),0x8d)
        for mode in (0,1,3,4,8,10,11):
            self.assertEqual(ui_keycode(0x0d,mode),0x0d)
        self.assertEqual(ui_keycode(0x0a,2),0x0a)  # Shift+Enter: line feed

    def test_gui_enter_delivery_in_both_settings_screens(self):
        # Exercise GUI routing without a display server or optional Z80 core.
        from types import SimpleNamespace
        from lex31_gui import Window
        delivered=[]
        feedback=[]
        stub=SimpleNamespace(
            m=SimpleNamespace(mem=bytearray(65536)),
            key=lambda code: delivered.append(code),
            input_feedback=SimpleNamespace(set=lambda msg: feedback.append(msg))
        )
        for mode in (0x02,0x09):
            stub.m.mem[0x4507]=mode
            detail=Window.keyboard_key(stub,0x0d)
            self.assertEqual(delivered[-1],0x8d)
            self.assertIn('Enter -> CHG',detail)
        stub.m.mem[0x4507]=1
        self.assertIsNone(Window.keyboard_key(stub,0x0d))
        self.assertEqual(delivered[-1],0x0d)
        self.assertEqual(delivered,[0x8d,0x8d,0x0d])

    def test_modifier_latch_and_undefined_code(self):
        # Exercise the event handler without requiring a running X server.
        keyb=VirtualKeyboard.__new__(VirtualKeyboard)
        keyb.rom=self.rom
        keyb.layer='plain'
        keyb.send=lambda code: emitted.append(code)
        keyb.report=lambda msg: None
        keyb.info=type('Feedback',(),{'set':lambda self,msg:None})()
        keyb._update_modifiers=lambda: None
        emitted=[]
        keyb.press('SHIFT-L'); keyb.press('CHG')
        self.assertEqual(emitted,[0x95]);self.assertEqual(keyb.layer,'plain')
        keyb.press('CTL');keyb.press('DJ')
        self.assertEqual(emitted,[0x95,0xc0]);self.assertEqual(keyb.layer,'plain')
        keyb.press('CTL');keyb.press('1')
        self.assertEqual(emitted,[0x95,0xc0]);self.assertEqual(keyb.layer,'plain')
        keyb.press('SHIFT-R');keyb.press('XIT')
        self.assertEqual(emitted,[0x95,0xc0,0x96])


if __name__=='__main__':unittest.main()
