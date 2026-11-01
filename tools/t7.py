import sys, random
sys.path.insert(0,'.')
from harness import Env
seed=int(sys.argv[1]) if len(sys.argv)>1 else 1
random.seed(seed)
pool=[0x1F]*14+[0x1E]*6+[0x0D]*5+[0x1B]*1+[0x20]*2+[ord(c) for c in 'adrmnp12345']+[0x1D,0x1C,0x0B,ord('['),ord(']'),0x08]
keys=[random.choice(pool) for _ in range(4000)]
k2=[]
for k in keys:
    k2.append(k)
    if random.random()<0.04: k2.append(('wait',random.randrange(10,400)))
e=Env('../x86view.com','fs',k2)
ver=random.choice([1,2,3]); e.setmsx(ver)
code=open('../x86view.com','rb').read()
restarts=0
while e.keys and restarts<200:
    e.run(8000000)
    if e.exit_code is not None and e.keys:
        restarts+=1
        e.done=False; e.exit_code=None; e.cwd=''
        e.m.memory[0x8000:0xB100]=bytes(0xB100-0x8000)
        e.m.memory[0x100:0x100+len(code)]=code
        e.m.pc=0x100; e.m.sp=0xDBF0; e.handles.clear()
    else: break
print('seed',seed,'ver',ver,'consumed',len(k2)-len(e.keys),'restarts',restarts,'spmin',hex(getattr(e,'spmin',0)),'bad',e.vdp.log_bad[:3],'pc',hex(e.m.pc),'left',len(e.keys))
