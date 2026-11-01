import sys
sys.path.insert(0,'.')
from harness import Env
DOWN=0x1F; UP=0x1E; ENTER=0x0D; ESC=0x1B
ver=int(sys.argv[1]) if len(sys.argv)>1 else 2
keys=[ord('a'), ('shot','a_root'), DOWN, ENTER, ('shot','a_pic'),
      DOWN, ENTER, ('shot','e_bad'), ESC,
      DOWN, ENTER, ('shot','v_sc3'), ESC,
      DOWN, ENTER, ('shot','v_192'), ESC]
keys += [DOWN]*8 + [ENTER, ('shot','v_raw'), ord('m'), ('shot','v_raw_m'), ord('r'), ('shot','v_raw_r'), ESC, ('shot','a_back')]
keys += [UP]*7 + [ord(' '), ('shot','ss1'), ('wait', 300), ('shot','ss2'), ord('1'), ('wait', 100), ('shot','ss3'), ord(' '), ('wait',400), ('shot','ss4'), ESC, ('shot','a_end'), ESC]
e=Env('../x86view.com','fs',keys)
e.setmsx(ver)
e.run()
print('done',e.done,'exit',e.exit_code)
