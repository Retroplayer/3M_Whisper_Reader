"""Clickable LEX-31 keyboard layout and ROM-backed translated keycodes.

Key locations/legends were transcribed from the owner's keyboard photograph.
Keycodes are looked up from the ORIGINAL ROM translator's 3 x 72 byte table
(0565h-063Ch); these are not guessed PC scan codes. This does not claim the
physical keyboard's matrix traces were independently verified.

The emulator injects the translated code into the OS key queue. Modifier keys
are one-shot mouse-click latches, so Shift -> LOCAL performs Shift+LOCAL.
"""
from __future__ import annotations
from dataclasses import dataclass
import tkinter as tk

TABLE_START = 0x0565
LAYER_LENGTH = 72
LAYERS = {"plain": 0, "ctl": 1, "shift": 2}
INVALID_CODE = 0xFE

# ROM command table (0F7Dh–10BEh): the configuration selector (mode 02h)
# and configuration options screen (mode 09h) both dispatch CHG (8Dh),
# *not* carriage return (0Dh). This is a GUI usability alias only; the
# keyboard's original translation and the loaded ROM are unchanged.
CONFIG_SELECT_MODES = frozenset((0x02, 0x09))


def ui_keycode(code: int, os_mode: int) -> int:
    """Translate PC/virtual Enter to the actual CHG selection command in SET.

    Call only for normal GUI keyboard input, never the raw key debugger,
    so a researcher can still inject genuine 0Dh into any firmware mode.
    """
    code &= 0xff
    return 0x8d if code == 0x0d and os_mode in CONFIG_SELECT_MODES else code


@dataclass(frozen=True)
class KeySpec:
    id: str
    label: str
    group: int = -1
    bit: int = -1
    secondary: str = ""
    palette: str = "normal"


def key(name, group, bit, second='', color='normal'):
    return KeySpec(name, name, group, bit, second, color)


def modifier(name, label):
    return KeySpec(name, label, -1, -1, '', 'modifier')


# Pictured key arrangement, not electrical matrix order.
# Each (group, bit) resolves through the ROM's keyboard translation table.
KEY_ROWS = (
    (
        key('LEFT',8,7,'','arrow'), key('UP',8,6,'','arrow'),
        key('DOWN',8,5,'','arrow'), key('RIGHT',8,4,'','arrow'),
        key('DJ',8,0,'','dj'), key('LINE',8,1,'','orange'),
        key('WORD',8,2,'','orange'), key('LABEL',8,3,'','yellow'),
        key('ALL',5,3,'','yellow'), key('SEARCH',4,2,'','yellow'),
        key('INDEX',5,1,'','yellow'), key('CLOCK',4,0,'','yellow'),
    ),
    (
        key('1',0,4,'!'), key('2',1,4,'"'), key('3',2,4,'#'),
        key('4',3,4,'$'), key('5',4,4,'%'), key('6',5,4,'&'),
        key('7',6,4,"'"), key('8',7,4,'('), key('9',0,3,')'),
        key('0',1,3,''), key('-',2,3,'='), key('[',3,3,'{'),
        key(']',4,3,'}'),
    ),
    (
        key('Q',0,5),key('W',1,5),key('E',2,5),key('R',3,5),
        key('T',4,5),key('Y',5,5),key('U',6,5),key('I',7,5),
        key('O',0,2),key('P',1,2),key('@',2,2,'`'),
        key('ENTER',3,2,'LINE FEED','enter'),
    ),
    (
        modifier('CTL','CTL'),key('A',1,6),key('S',2,6),
        key('D',3,6),key('F',4,6),key('G',5,6),key('H',6,6),
        key('J',7,6),key('K',0,1),key('L',1,1),
        key(';',2,1,'+'),key(':',3,1,'*'),key('\\',4,1,'|'),
    ),
    (
        modifier('SHIFT-L','Shift'),key('Z',1,7),key('X',2,7),
        key('C',3,7),key('V',4,7),key('B',5,7),key('N',6,7),
        key('M',7,7),key(',',0,0,'<'),key('.',1,0,'>'),
        key('/',2,0,'?'),modifier('SHIFT-R','Shift'),
    ),
    (
        key('HLP',7,0,'','special'),key('^',7,1,'~'),
        key('_',7,2,'DEL'),key('ESC',7,3,'BREAK','special'),
        key('RUB',6,0,'PRINT','rub'),key('SPACE',6,1),
        key('PW',6,2,'SET','special'),key('GO',6,3,'CALC','go'),
        key('CHG',3,0,'LOCAL','special'),key('XIT',5,2,'SEND','special'),
        key('CLR',5,0,'SAVE','special'),
    ),
)

KEYS_BY_ID = {spec.id: spec for row in KEY_ROWS for spec in row}


def translated_keycode(rom: bytes, name: str, layer: str = 'plain') -> int:
    """Return the actual byte read by firmware's ROM-based key translator."""
    if layer not in LAYERS:
        raise ValueError(f'Unknown keyboard layer: {layer}')
    spec = KEYS_BY_ID[name]
    if spec.group < 0:
        raise ValueError('Modifiers do not themselves produce a keycode')
    address = TABLE_START + LAYER_LENGTH * LAYERS[layer] + 8 * spec.group + spec.bit
    if len(rom) <= address:
        raise ValueError('ROM does not contain the complete keyboard table')
    return rom[address]


PALETTE = {
    'normal':('#e8e2cb','#171717'),
    'special':('#99998c','#ffffff'),
    'arrow':('#42a94e','#101f14'),
    'dj':('#215fd0','#ffffff'),
    'orange':('#fa7136','#171717'),
    'yellow':('#e9db3d','#171717'),
    'enter':('#1963c2','#ffffff'),
    'rub':('#e84e20','#ffffff'),
    'go':('#a8dd2d','#101f14'),
    'modifier':('#97978b','#ffffff'),
}


class VirtualKeyboard(tk.Frame):
    """Mouse-clickable representation of all 73 pictured key positions (plus modifiers)."""

    def __init__(self, master, rom: bytes, send, report=None):
        super().__init__(master,bg='#202124',padx=5,pady=5)
        self.rom = bytes(rom)
        self.send = send
        self.report = report or (lambda message: None)
        self.layer = 'plain'
        self.modifier_buttons = {'shift': [],'ctl': []}
        self.info = tk.StringVar(value='Click Shift or CTL, then a key. Modifiers release after one key.')
        self._build()
        self._update_modifiers()

    def set_rom(self,rom):
        self.rom = bytes(rom)
        self.layer = 'plain'
        self._update_modifiers()

    def _build(self):
        for rownum, keyrow in enumerate(KEY_ROWS):
            row = tk.Frame(self,bg='#202124')
            row.pack(fill='x',pady=2)
            for spec in keyrow:
                cell = tk.Frame(row,bg='#202124',padx=2)
                cell.pack(side='left',fill='x',expand=True)
                face,fg=PALETTE[spec.palette]
                if rownum == 0:
                    # Original function strip: narrow colored key faces.
                    label = {'LEFT':'◀','UP':'▲','DOWN':'▼','RIGHT':'▶'}.get(spec.id,spec.label)
                else:
                    label = 'SPACE' if spec.id=='SPACE' else spec.label
                above = spec.secondary if spec.secondary else ' '
                tk.Label(cell,text=above,font=('Arial',7),height=1,
                         fg='#d0d0c9' if above.strip() else '#202124',
                         bg='#202124').pack(fill='x')
                button=tk.Button(cell,text=label,fg=fg,bg=face,activebackground='#ffffff',
                                 activeforeground='#171717',font=('Arial',9,'bold'),
                                 height=1,bd=2,relief='raised',
                                 command=lambda s=spec:self.press(s.id))
                button.pack(fill='x')
                button.bind('<Enter>',lambda event,s=spec:self._hover(s))
                if spec.id.startswith('SHIFT'):
                    self.modifier_buttons['shift'].append(button)
                elif spec.id=='CTL':
                    self.modifier_buttons['ctl'].append(button)
        foot=tk.Frame(self,bg='#202124');foot.pack(fill='x',pady=(4,0))
        tk.Label(foot,textvariable=self.info,fg='#d9e7cb',bg='#202124',
                 anchor='w',font=('Consolas',9)).pack(side='left',fill='x',expand=True)
        tk.Button(foot,text='Release Shift / CTL',font=('Arial',9),
                  command=self.release_modifiers).pack(side='right')

    def _hover(self,spec):
        if spec.group<0:
            self.info.set(f'{spec.label}: select/release one-shot modifier (currently {self.layer.upper()})')
            return
        codes = []
        for layer in LAYERS:
            code = translated_keycode(self.rom,spec.id,layer)
            codes.append(f'{layer.upper()}={code:02X}h'+ (' (not assigned)' if code==INVALID_CODE else ''))
        self.info.set(f'{spec.label}: '+', '.join(codes))

    def _update_modifiers(self):
        for layer,buttons in self.modifier_buttons.items():
            for b in buttons:
                if self.layer == layer:
                    b.configure(relief='sunken',bg='#b5c7ee',fg='#151f35')
                else:
                    face,fg=PALETTE['modifier'];b.configure(relief='raised',bg=face,fg=fg)

    def release_modifiers(self):
        self.layer='plain'
        self._update_modifiers()
        self.info.set('Modifiers released. Plain key layer is active.')

    def press(self, name):
        if name=='CTL':
            self.layer='plain' if self.layer=='ctl' else 'ctl'
            self._update_modifiers()
            self.info.set('CTL '+('selected for next key' if self.layer=='ctl' else 'released'))
            return
        if name.startswith('SHIFT'):
            self.layer='plain' if self.layer=='shift' else 'shift'
            self._update_modifiers()
            self.info.set('Shift '+('selected for next key' if self.layer=='shift' else 'released'))
            return
        layer=self.layer
        code=translated_keycode(self.rom,name,layer)
        self.release_modifiers()
        if code==INVALID_CODE:
            message=f'{layer.upper()}+{name} has no mapping in the ROM keyboard table (FEh).'
        else:
            gui_message=self.send(code)
            message=f'{name} ({layer.upper()}) -> translated firmware key {code:02X}h'
            if gui_message:
                message += f' ({gui_message})'
        self.info.set(message)
        self.report(message)
