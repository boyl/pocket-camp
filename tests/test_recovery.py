from pathlib import Path
from lupa.lua54 import LuaRuntime
root=Path(__file__).parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
check=lua.eval('function(s) local f,e=load(s); return f~=nil,e end')
for p in (root/'reframework').rglob('*.lua'):
    ok,error=check(p.read_text(encoding='utf-8'))
    assert ok,(str(p),error)
lua.globals().recovery=lua.execute((root/'reframework/autorun/CampShortcutProbe/recovery.lua').read_text(encoding='utf-8'))
lua.execute('''
local s={quest_status=2,scene_id=12,additional_scene=12,camp_present=false,camp_open=false,
 action_flags={InTent={id=23,on=true}},motion_node="tent.test"}
assert(recovery.allowed(s))
s.scene_id=0;assert(not recovery.allowed(s))
s.scene_id=12;s.motion_node="wait";assert(not recovery.allowed(s))
s.motion_node="tent.test"
local saved=nil;local calls=0
json={load_file=function(path)
 if path:find("request") then return {id="clear-tent-001"} else return saved end
end,dump_file=function(_,v) saved=v end}
local flags={call=function(_,method,id)
 assert(method=="off(System.UInt32)" and id==23);calls=calls+1
end}
local player={get_field=function() return flags end}
sdk={get_managed_singleton=function() return {call=function() return player end} end}
recovery.run(function() return s end)
recovery.run(function() return s end)
assert(calls==1 and saved.ok,'Recovery must run only once')
''')
print('PASS: Lua syntax; closed-tent guards; recovery exactly once')
