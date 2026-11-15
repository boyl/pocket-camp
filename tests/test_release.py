"""对最终单文件执行原核心回归、无模块冷启动与跨任务集成测试。"""
from pathlib import Path
from lupa.lua54 import LuaRuntime
import runpy
root=Path(__file__).parents[1]
bundle=(root/'release-build/reframework/autorun/PocketCamp.lua').read_text(encoding='utf-8')
prefix=bundle.split('-- ENTRY\n')[0]
LuaRuntime().execute('assert(load(...))',bundle)
# 复用先前故障测试的断言，执行制品中实际内嵌模块；只适配依赖注入。
for name, module in [('test_candidate.py','Controller'),('test_task_scope.py','Controller'),('test_gamepad.py','Gamepad')]:
    text=(root/'tests'/name).read_text(encoding='utf-8')
    if module=='Controller':
        adapter='''\nlocal original=Controller.new
Controller.new=function(capture)
 return original(capture,{poll=function() return false end},function(s) json.dump_file('test',s) end)
end
return Controller'''
    else:
        adapter='''\nlocal original=Gamepad.new
Gamepad.new=function() return original(function(s) json.dump_file('test',s) end) end
return Gamepad'''
    class RuntimeProxy:
        def __init__(self,**kwargs): self.inner=LuaRuntime(**kwargs)
        def globals(self): return self.inner.globals()
        def execute(self,code,*args):
            if code.startswith('-- 原生入口验证：') or code.startswith('-- 本机已确认的 via.hid'):
                code=prefix+adapter
            return self.inner.execute(code,*args)
    text=text.replace('from lupa.lua54 import LuaRuntime','')
    exec(compile(text,str(root/'tests'/name),'exec'),{'__file__':str(root/'tests'/name),'LuaRuntime':RuntimeProxy})
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
now=0;os.clock=function() return now end
key=false;overlay=false;local reports={}
json={dump_file=function(path,s)
 assert(path=='PocketCamp/status.json','Unexpected diagnostic output: '..path)
 status={};for k,v in pairs(s) do status[k]=v end;reports[#reports+1]=status
end}
log={info=function() end,error=function(e) error(e) end}
reframework={is_key_down=function() return key end,is_drawing_ui=function() return overlay end}
frames={};re={on_frame=function(f) frames[#frames+1]=f end,on_draw_ui=function(f) draw=f end}
require=function() error('External require is forbidden') end
q=nil;p=nil;camp=nil;quest=0;created=0;released=0
local node='wait.main';local tent=false
local flags={call=function(_,m)
 if m=='isOn(System.UInt32)' then return tent end
 assert(m=='off(System.UInt32)');tent=false
end}
local fsm={call=function() return node end}
player={get_type_definition=function() return {get_full_name=function() return 'snow.player.LongSword' end} end,
 get_field=function(_,name)
 if name=='<PlBaseActionFlags>k__BackingField' then return flags end
 if name=='_RefMotionFsm2' then return fsm end
 end,call=function(_,m) assert(m=='resetMotionFsm()');node='wait.main' end}
function manager(id)
 local fields={_state=2,_currentSceneId=12,_AdditionalSceneId=12}
 return {get_address=function() return id end,get_field=function(_,n) return fields[n] end,
 set_field=function(_,n,v) fields[n]=v end,
 call=function(_,m,progress,scene)
 assert(m=='activate(snow.access.Progress, snow.gui.QuestUIManager.SceneId)' and scene==0)
 assert(fields._currentProgress==nil,'Should start without a tent visit')
 fields._currentProgress=progress;fields._currentSceneId=0
 camp={call=function() return true end};tent=true;node='tent.sit'
 end}
end
sdk={get_managed_singleton=function(n)
 if n=='snow.gui.QuestUIManager' then return q end
 if n=='snow.player.PlayerManager' then return {call=function() return p end} end
 if n=='snow.QuestManager' then return {get_field=function() return quest end} end
 if n=='snow.gui.GuiManager' then return {call=function() return false end} end
end,find_type_definition=function(n)
 if n=='via.hid.GamePad' then return nil end
 return {get_field=function(_,name)
 if name=='_Instance' then return {get_data=function() return camp end} end
 if name=='InTent' then return {get_data=function() return 23 end} end
 end}
end,create_instance=function(n,raw)
 assert(n=='snow.access.Progress' and raw);created=created+1;local id=100+created
 return {get_address=function() return id end,add_ref=function() end,
 release=function() released=released+1 end,set_field=function(_,n,v) assert(n=='<Status>k__BackingField' and v==2) end}
end}
function frame() now=now+0.2;for _,f in ipairs(frames) do f() end end
''')
lua.execute(bundle)
lua.execute('''
assert(status.phase=='armed' and status.gamepad_available==false)
assert(#frames==1)
key=true;frame();assert(status.event=='rejected' and created==0,'Title must reject')
for i=1,2 do
 q=manager(i);p=player;quest=2
 key=false;frame();key=true;frame();frame()
 assert(status.phase=='open')
 camp=nil;q:set_field('_currentSceneId',12)
 frame();frame()
 assert(status.completed==i and status.phase=='closed')
 assert(q:get_field('_currentProgress')==nil and created==released)
end
''')
lua.execute(bundle)
lua.execute('assert(#frames==1,"Duplicate callbacks")')
print('PASS: final single-file syntax; title startup; no external modules; F10 fallback; fresh hunts; cleanup; duplicate load guard')
