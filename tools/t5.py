import sys
sys.path.insert(0,'.')
from harness import Env
ESC=0x1B
def run(args, keys, shots=None):
    e=Env('../x86view.com','fs',keys)
    a=(' '+args).encode()
    e.m.memory[0x80]=len(a); e.m.memory[0x81:0x81+len(a)]=a
    e.run()
    return e
print('--- file arg')
run('PIC\\SUNSET.SC7',[('shot','arg_view'),ESC,('shot','arg_back'),ESC])
print('--- dir arg')
run('PIC',[('shot','arg_dir'),ESC])
print('--- help')
run('/?',[])
print('--- drive+file')
run('A:\\PIC\\SUNSET.SC8',[('shot','arg_sc8'),ESC,ESC])
print('--- bad name')
run('NOFILE.XYZ',[('shot','arg_bad'),ESC])
