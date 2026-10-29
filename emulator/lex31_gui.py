"""Tkinter debugger for the LEX-31 experimental emulator. Windows 10 / Python 3.11+."""
from __future__ import annotations
import argparse
import time
import csv
from pathlib import Path
import tkinter as tk
from tkinter import ttk, filedialog, messagebox
from lex31_machine import Machine, BASE
from lex31_keyboard import VirtualKeyboard, ui_keycode


class Window(tk.Tk):
    def __init__(self, rom=None, irq=True):
        super().__init__()
        self.title('LEX-31 / 3M Whisper Reader — Research Emulator v0.1.7')
        self.geometry('1160x930')
        self.minsize(960,750)
        self.rom=rom
        try:self.m=Machine(rom,periodic=irq)
        except RuntimeError as e:
            messagebox.showerror('Missing CPU library',str(e));self.destroy();return
        self.running=False
        self.batch=tk.IntVar(value=1500)
        self.break_entry=tk.StringVar()
        self.key_entry=tk.StringVar()
        self.input_entry=tk.StringVar()
        self.memory_addr=tk.StringVar(value='4000')
        self.irq_var=tk.BooleanVar(value=irq)
        self.second_row_var=tk.BooleanVar(value=self._experimental_two_row())
        self.battery_low_var=tk.BooleanVar(value=False)
        self.battery_beep_var=tk.BooleanVar(value=True)
        self._last_battery_beep=time.monotonic()
        self.trace_var=tk.BooleanVar(value=False)
        self.cpu_var=tk.StringVar()
        self.modes_var=tk.StringVar()
        with (BASE/'docs'/'symbols.csv').open(newline='') as f:
            self.symbols={int(row['address'],16):row['label'] for row in csv.DictReader(f)}
        self.lcd_title=tk.StringVar()
        self.status_var=tk.StringVar()
        self.guidance_var=tk.StringVar()
        self.input_feedback=tk.StringVar()
        self.mode_names={'00':'ONLINE (provisional)','01':'EDITOR','0B':'PASSWORD EDITOR'}
        self.old_events=0
        self.old_serial=0
        self.old_printer=0
        self._ui()
        # Physical XIT uses the OS special keycode 8Eh. Escape offers a
        # convenient keyboard equivalent without requiring matrix emulation.
        self.bind('<Escape>', lambda event: self.keyboard_key(0x8e))
        # Treat the PC Enter keys as keyboard input unless editing a debugger
        # field. On the SET screens the ROM expects CHG, not ASCII Return.
        self.bind('<Return>', self._physical_return)
        self.bind('<KP_Enter>', self._physical_return)
        self.after(1000,self._battery_timer)
        self.render()

    def _experimental_two_row(self):
        experimental=BASE/'roms'/'LEX31_40x2_experimental_combined.bin'
        return experimental.is_file() and self.m.rom==experimental.read_bytes()

    def _battery_timer(self):
        if not self.winfo_exists():return
        now=time.monotonic()
        if self.m.battery_low and self.battery_beep_var.get() and now-self._last_battery_beep>=10:
            self.bell()  # the owner's manual specifies a 10-second reminder
            self._last_battery_beep=now
        self.after(1000,self._battery_timer)

    def set_battery_low(self):
        self.m.battery_low=self.battery_low_var.get()
        self._last_battery_beep=time.monotonic()
        self.render()

    def set_second_row(self):
        if self.second_row_var.get():
            self.screen[1].pack(fill='x',pady=2,before=self.lcd_info_label)
        else:
            self.screen[1].pack_forget()
        self.render()

    def _ui(self):
        menubar=tk.Menu(self)
        m=tk.Menu(menubar,tearoff=0)
        m.add_command(label='Load combined 12 KiB ROM...',command=self.load_rom)
        m.add_command(label='Reset CPU / preserve battery-backed RAM + clock',command=lambda:self.reset(True))
        m.add_command(label='Cold start / clear RAM + clock',command=lambda:self.reset(False))
        m.add_command(label='Set RTC date/time from PC (preserve RAM)',command=self.sync_rtc)
        m.add_separator()
        m.add_command(label='Save 16 KiB RAM image...',command=self.save_ram)
        m.add_command(label='Load 16 KiB RAM image...',command=self.load_ram)
        m.add_separator();m.add_command(label='Exit',command=self.destroy)
        menubar.add_cascade(label='File',menu=m)
        self.config(menu=menubar)
        controls=ttk.Frame(self,padding=8);controls.pack(fill='x')
        self.run_button=ttk.Button(controls,text='Run',command=self.toggle_run);self.run_button.pack(side='left',padx=3)
        ttk.Button(controls,text='Step',command=self.step_one).pack(side='left',padx=3)
        ttk.Button(controls,text='Run 10k',command=lambda:self.run_n(10000)).pack(side='left',padx=3)
        ttk.Button(controls,text='Reset (retain RAM)',command=lambda:self.reset(True)).pack(side='left',padx=3)
        ttk.Checkbutton(controls,text='RSTC (~125 Hz, estimated)',variable=self.irq_var,command=self.set_irq).pack(side='left',padx=10)
        ttk.Checkbutton(controls,text='Trace instructions',variable=self.trace_var,command=self.set_trace).pack(side='left',padx=8)
        ttk.Label(controls,text='Steps/frame').pack(side='left')
        ttk.Spinbox(controls,from_=100,to=50000,increment=100,width=7,textvariable=self.batch).pack(side='left',padx=3)

        top=ttk.LabelFrame(self,text='Virtual character LCD — factory: 40×1',padding=12)
        top.pack(fill='x',padx=10,pady=5)
        self.screen=[]
        for i in range(2):
            label=tk.Label(top,text=' '*40,font=('Consolas',18,'bold'),fg='#bedf99',bg='#1c3528',anchor='w',padx=10,pady=7)
            label.pack(fill='x',pady=2)
            self.screen.append(label)
        self.lcd_info_label=ttk.Label(top,textvariable=self.lcd_title)
        self.lcd_info_label.pack(anchor='w',pady=2)
        ttk.Checkbutton(top,text='Show second LCD row (experimental firmware / debugger)',
                        variable=self.second_row_var,command=self.set_second_row).pack(anchor='w')
        if not self.second_row_var.get():self.screen[1].pack_forget()
        ttk.Label(top,textvariable=self.modes_var).pack(anchor='w')
        ttk.Label(top,textvariable=self.guidance_var,wraplength=1080).pack(anchor='w')
        ttk.Label(top,textvariable=self.status_var,wraplength=1080).pack(anchor='w')
        testing=ttk.Frame(top);testing.pack(anchor='w',pady=3)
        ttk.Checkbutton(testing,text='Simulate low battery (provisional port 43h bit 2)',
                        variable=self.battery_low_var,command=self.set_battery_low).pack(side='left')
        ttk.Checkbutton(testing,text='Beep every 10 seconds',
                        variable=self.battery_beep_var).pack(side='left',padx=12)

        keyboard_group=ttk.LabelFrame(self,text='Full LEX-31 keyboard (ROM-derived codes; one-shot Shift / CTL)',padding=4)
        keyboard_group.pack(fill='x',padx=10,pady=5)
        self.virtual_keyboard=VirtualKeyboard(keyboard_group,self.m.rom,self.keyboard_key)
        self.virtual_keyboard.pack(fill='x')

        k=ttk.LabelFrame(self,text='Text / serial input and raw translated-key injection',padding=6)
        k.pack(fill='x',padx=10,pady=4)
        row=ttk.Frame(k);row.pack(fill='x')
        ttk.Entry(row,textvariable=self.input_entry,width=40).pack(side='left',padx=3)
        ttk.Button(row,text='Queue text',command=self.queue_text).pack(side='left',padx=3)
        ttk.Button(row,text='Serial RX',command=self.queue_serial).pack(side='left',padx=3)
        ttk.Label(row,text='Hex OS key:').pack(side='left',padx=3)
        inp=ttk.Entry(row,textvariable=self.key_entry,width=7);inp.pack(side='left',padx=3)
        inp.bind('<Return>',lambda e:(self.queue_raw(), 'break')[1])
        ttk.Button(row,text='Send',command=self.queue_raw).pack(side='left',padx=3)
        ttk.Label(k,textvariable=self.input_feedback,wraplength=1100).pack(anchor='w',padx=4)
        ttk.Label(k,text='SET menu: arrow keys navigate; CHG selects/changes. Enter is a convenience alias. Press XIT twice to finish.',wraplength=1100).pack(anchor='w',padx=4)

        debug=ttk.LabelFrame(self,text='Debugger',padding=8);debug.pack(fill='x',padx=10,pady=5)
        ttk.Label(debug,textvariable=self.cpu_var,font=('Consolas',10)).pack(anchor='w')
        ctrl=ttk.Frame(debug);ctrl.pack(fill='x',pady=4)
        ttk.Label(ctrl,text='Breakpoint (hex):').pack(side='left')
        ttk.Entry(ctrl,textvariable=self.break_entry,width=10).pack(side='left',padx=4)
        ttk.Button(ctrl,text='Add',command=self.add_break).pack(side='left',padx=2)
        ttk.Button(ctrl,text='Clear',command=self.clear_break).pack(side='left',padx=2)
        self.break_label=ttk.Label(ctrl,text='None');self.break_label.pack(side='left',padx=8)
        ttk.Label(ctrl,text='RAM address:').pack(side='left',padx=6)
        ttk.Entry(ctrl,textvariable=self.memory_addr,width=8).pack(side='left')
        ttk.Button(ctrl,text='View',command=self.dump_memory).pack(side='left',padx=3)
        ttk.Button(ctrl,text='Save I/O log',command=self.save_log).pack(side='right',padx=3)

        tabs=ttk.Notebook(self);tabs.pack(fill='both',expand=True,padx=10,pady=7)
        self.logs={}
        for title in ('Events / I-O','Memory','Serial TX / printer','Instruction trace'):
            frame=ttk.Frame(tabs);tabs.add(frame,text=title)
            t=tk.Text(frame,font=('Consolas',10),wrap='none',height=13)
            y=ttk.Scrollbar(frame,orient='vertical',command=t.yview);t.configure(yscrollcommand=y.set)
            y.pack(side='right',fill='y');t.pack(fill='both',expand=True)
            self.logs[title]=t
        self.dump_memory()

    def append(self,name,txt,replace=False):
        t=self.logs[name]
        if replace:t.delete('1.0','end')
        t.insert('end',txt);t.see('end')
        if float(t.index('end-1c').split('.')[0])>1200:t.delete('1.0','200.0')

    def render(self):
        m=self.m
        for i in range(2):
            self.screen[i].configure(text=m.lcd.text(i),underline=m.lcd.cursor_column(i))
        self.lcd_title.set('LCD: %s | DDRAM address %02X | cursor %s | writes %d | RTC reads/writes %d'%(
            '40×2 experiment' if self.second_row_var.get() else '40×1 factory',
            m.lcd.address,'on' if m.lcd.cursor_on else 'off',m.lcd.data_writes,m.rtc.accesses))
        bit_names={0x0008:'MEMORY',0x0010:'RIGHT',0x0020:'DOWN',0x0040:'LEFT',0x0080:'UP',0x0200:'PRINTER',0x0400:'SEND?',0x0800:'LINE READY?',0x1000:'SAVE',0x2000:'XOFF',0x4000:'TRAFFIC'}
        active=[s for n,s in bit_names.items() if m.status_bits()&n]
        self.status_var.set('Status latch: %04X  %s (tentative bit labels, not proven LCD segments).  Battery: %s'%(
            m.status_bits(),', '.join(active) or 'none',
            'LOW [SIMULATION]' if m.battery_low else 'normal [simulated]'))
        mode=m.mem[0x4507]
        state='ALARM (XIT required)' if m.alarm_active else self.mode_names.get('%02X'%mode,'unmapped')
        self.modes_var.set('OS mode %02X (%s) | %s'%(mode,state,('HALTED: '+m.halt_reason) if m.halt_reason else 'active'))
        if m.alarm_active:
            guidance='CLOCK ALARM: press XIT (Esc) to dismiss. This is not a startup menu.'
        elif mode in (0x02,0x09):
            guidance='SET configuration: use all four arrows to navigate, CHG changes/confirms (Enter alias), XIT twice to finish. For CLOCK: Left/Right select item, Up/Down adjust.'
        elif mode == 0:
            guidance='ONLINE is normal idle. For EDITOR: click Shift, then CHG (LOCAL). For SETTINGS: Shift, then PW (SET). INDEX and HLP are also available.'
        else:
            guidance='Mode controls operate on the firmware key queue; XIT (Esc) normally exits a submode.'
        self.guidance_var.set(guidance)
        self.cpu_var.set(m.summary()+'    '+self.symbols.get(m.cpu.pc,'') )
        if m.event_total != self.old_events:
            delta=m.event_total-self.old_events
            self.append('Events / I-O','\n'.join(list(m.events)[-delta:])+'\n')
            self.old_events=m.event_total
        if len(m.serial_tx)!=self.old_serial or len(m.printer)!=self.old_printer:
            tx=bytes(m.serial_tx)
            stream=''.join(chr(b) if 32<=b<127 else ('\n' if b==13 else f'<{b:02X}>') for b in tx)
            printer=''.join(chr(b) if 32<=b<127 else ('\n' if b==13 else f'<{b:02X}>') for b in m.printer)
            self.append('Serial TX / printer','SERIAL:\n'+stream+'\n\nPRINTER:\n'+printer,True)
            self.old_serial=len(m.serial_tx)
            self.old_printer=len(m.printer)
        if m.trace_enabled and m.trace:self.append('Instruction trace','\n'.join(list(m.trace)[-120:])+'\n',True)
        self.break_label.configure(text=', '.join('%04X'%b for b in sorted(m.breakpoints)) or 'None')

    def tick(self):
        if not self.running:return
        try:total=max(100,min(50000,int(self.batch.get())))
        except (tk.TclError,ValueError):total=1500
        r=self.m.run(total)
        if r.reason!='step limit':self.running=False;self.run_button.configure(text='Run')
        self.render()
        if self.running:self.after(30,self.tick)

    def toggle_run(self):
        if self.running:self.running=False;self.run_button.configure(text='Run');return
        self.m.resume();self.running=True;self.run_button.configure(text='Pause');self.after(1,self.tick)

    def step_one(self):
        if self.running:return
        self.m.resume();self.m.step();self.render()

    def run_n(self,n):
        if self.running:return
        self.m.resume();self.m.run(n);self.render()

    def reset(self,preserve=False):
        self.running=False;self.run_button.configure(text='Run');self.m.reset(preserve_ram=preserve);self.battery_low_var.set(self.m.battery_low);self.old_events=0;self.old_serial=0;self.old_printer=0
        for t in self.logs.values():t.delete('1.0','end')
        self.input_feedback.set('')
        self.virtual_keyboard.release_modifiers()
        self.render();self.dump_memory()

    def sync_rtc(self):
        """Host-side time sync: writes RTC registers only, never the ROM."""
        self.m.rtc.set_datetime()
        self.m.event('RTC','synchronized calendar from PC local clock')
        self.input_feedback.set('RTC synchronized from PC date/time. Reenter CLOCK settings to refresh the displayed fields.')
        self.render()

    def _physical_return(self,event):
        # Let editable text fields consume Enter normally; the raw-key hex
        # field has its own Return binding which submits the typed raw code.
        if isinstance(event.widget,(tk.Entry,ttk.Entry,tk.Spinbox,ttk.Spinbox,tk.Text)):
            return None
        self.keyboard_key(0x0d)
        return 'break'

    def keyboard_key(self,n):
        """Keyboard UI path, preserving the ROM's unusual CHG-as-confirm UX."""
        mode=self.m.mem[0x4507]
        translated=ui_keycode(n,mode)
        self.key(translated)
        if translated != n:
            feedback=f'Enter -> CHG ({translated:02X}h) selects option in SET mode {mode:02X}h'
            self.input_feedback.set(feedback)
            return feedback
        return None

    def key(self,n):
        if not self.m.inject_key(n):
            self.input_feedback.set('Input was not queued; the ROM must initialize the keyboard queue first.')
            messagebox.showwarning('Queue unavailable','The OS must finish keyboard-queue initialization first. Run or step the CPU.')
        else:
            self.input_feedback.set('Queued OS key %02Xh. %s'%(n, 'Running CPU will consume it.' if self.running else 'CPU is paused; click Run or Run 10k to consume it.'))
        self.render()

    def queue_text(self):
        text=self.input_entry.get()
        for c in text:
            if not self.m.inject_key(ord(c) if ord(c)<128 else ord('?')):break
        self.render()

    def queue_serial(self):
        self.m.inject_serial(self.input_entry.get().encode('ascii', errors='replace'))
        self.render()

    def queue_raw(self):
        try:n=int(self.key_entry.get().replace('0x',''),16)
        except ValueError:messagebox.showerror('Keycode','Enter a hexadecimal byte, e.g. 80');return
        if not 0<=n<=255:messagebox.showerror('Keycode','Range 00–FF');return
        self.key(n)

    def set_irq(self):self.m.periodic_enabled=self.irq_var.get()
    def set_trace(self):self.m.trace_enabled=self.trace_var.get()

    def add_break(self):
        try:n=int(self.break_entry.get(),16)
        except ValueError:messagebox.showerror('Breakpoint','Enter a hex address');return
        if n<0 or n>65535:return
        self.m.breakpoints.add(n);self.render()
    def clear_break(self):self.m.breakpoints.clear();self.render()

    def dump_memory(self):
        try:a=int(self.memory_addr.get(),16)&0xffff
        except ValueError:return
        lines=[]
        for p in range(a,min(a+256,65536),16):
            block=[self.m.read(x) for x in range(p,min(p+16,65536))]
            lines.append(f'{p:04X}: '+''.join(f'{x:02X} ' for x in block)+' '+''.join(chr(x) if 32<=x<127 else '.' for x in block))
        self.append('Memory','\n'.join(lines)+'\n',True)

    def load_rom(self):
        p=filedialog.askopenfilename(title='Select combined 12 KiB ROM image',filetypes=[('Binary ROM','*.bin'),('All files','*.*')])
        if not p:return
        b=Path(p).read_bytes()
        if len(b)!=12288:messagebox.showerror('ROM size','Expected 12,288 bytes in U2-U3-U4 order');return
        irq=self.m.periodic_enabled
        self.m=Machine(b,periodic=irq)
        self.virtual_keyboard.set_rom(self.m.rom)
        self.second_row_var.set(self._experimental_two_row())
        self.set_second_row()
        self.battery_low_var.set(False)
        self.reset(False)

    def save_ram(self):
        p=filedialog.asksaveasfilename(defaultextension='.bin',filetypes=[('RAM image','*.bin')]);
        if p:Path(p).write_bytes(self.m.mem[0x4000:0x8000])

    def load_ram(self):
        p=filedialog.askopenfilename(filetypes=[('RAM image','*.bin')]);
        if not p:return
        b=Path(p).read_bytes()
        if len(b)!=16384:messagebox.showerror('Invalid image','Expected 16 KiB');return
        self.m.mem[0x4000:0x8000]=b;self.render()

    def save_log(self):
        p=filedialog.asksaveasfilename(defaultextension='.txt',filetypes=[('Text','*.txt')]);
        if p:Path(p).write_text('\n'.join(self.m.events)+'\n',encoding='utf-8')


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--rom',type=Path,help='Combined 12-KiB image, U2+U3+U4')
    ap.add_argument('--headless',action='store_true',help='Run without Tkinter and report CPU/LCD state')
    ap.add_argument('--steps',type=int,default=100000)
    ap.add_argument('--no-irq',action='store_true',help='Disable provisional RSTC injection')
    ap.add_argument('--trace',action='store_true')
    args=ap.parse_args()
    image=args.rom.read_bytes() if args.rom else None
    if args.headless:
        m=Machine(image,periodic=not args.no_irq)
        m.trace_enabled=args.trace
        res=m.run(args.steps)
        print(m.summary())
        print('Outcome:',res.reason,'steps:',res.steps)
        print('LCD row 1:',repr(m.lcd.text(0)))
        print('LCD row 2 (DDRAM diagnostic):',repr(m.lcd.text(1)))
        print('Status:',f'{m.status_bits():04X}')
        print('I/O events:')
        for l in list(m.events)[-30:]:print(l)
        return
    app=Window(image,irq=not args.no_irq)
    if app.winfo_exists():app.mainloop()


if __name__=='__main__':main()
