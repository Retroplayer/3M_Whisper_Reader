"""Optional GUI smoke test (requires a display / xvfb, no optional CPU core)."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import lex31_gui
from test_machine import FakeCPU
from lex31_machine import Machine

old=lex31_gui.Machine
lex31_gui.Machine=lambda rom=None,periodic=True:old(rom,cpu_factory=FakeCPU,periodic=periodic)
app=lex31_gui.Window()
app.update_idletasks()
app.update()
assert not app.second_row_var.get()
assert not app.screen[1].winfo_ismapped()
app.m.lcd.select(0)
app.m.lcd.write(0x0e)
app.m.lcd.write(0x80)
app.m.lcd.select(0x20)
app.m.lcd.write(ord('H'))
app.render()
app.update()
assert int(app.screen[0]['underline'])==1
app.second_row_var.set(True)
app.set_second_row()
app.update()
assert app.screen[1].winfo_ismapped()
app.second_row_var.set(False)
app.set_second_row()
app.update()
app.battery_low_var.set(True)
app.set_battery_low()
app.update()
assert app.m.battery_low
assert app.m.port_in(0x43)==0x08
app.reset(True)
app.update()
assert app.m.battery_low
app.reset(False)
app.update()
assert app.m.battery_low # battery input stays external to RAM
# New menu command must resync only RTC, without touching OS RAM or ROM.
app.m.mem[0x4520]=0x5a
app.m.rtc.write(10,0x00)
app.m.rtc.write(9,0x00)
app.sync_rtc()
from datetime import datetime
from lex31_machine import RTC
assert RTC._dec(app.m.rtc.regs[10])*100 + RTC._dec(app.m.rtc.regs[9]) == datetime.now().year
assert app.m.mem[0x4520] == 0x5a
assert app.m.is_original
app.screenshot_ready=True
app.destroy()
print('GUI smoke test passed')
