import sys
sys.path.insert(0,'.')
from harness import Env
DOWN=0x1F; ENTER=0x0D; ESC=0x1B
keys=[DOWN, ENTER, ('shot','ui2'), DOWN, ('shot','ui3'), ENTER]
for n in ['sc2','sc5','sc6','sc7','sc8','scb','scc']:
    keys += [('shot','v_'+n), ord('n')]
keys += [ESC, ('shot','ui4'), ESC]
e=Env('../x86view.com','fs',keys)
e.run()
print('done',e.done,'exit',e.exit_code)
