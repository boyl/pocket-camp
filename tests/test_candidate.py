"""离线验证快捷键与真实缺陷：界面关闭后残留帐篷坐姿。"""
from pathlib import Path
from lupa.lua54 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('package.preload["CampShortcutProbe.gamepad"]=function() return {new=function() return {poll=function() return false end} end} end')
source=Path(__file__).parents[1]/'reframework/autorun/CampShortcutProbe/candidate.lua'
lua.globals().candidate=lua.execute(source.read_text(encoding='utf-8'))
lua.execute('''
local function valid()
 return {quest_status=2,player_type="snow.player.DualBlades",quest_ui_present=true,quest_ui_state=2,
 scene_id=12,additional_scene=12,camp_present=false,camp_open=false,progress_status=3,
 progress_marker_present=true,progress_sensor_present=true,position={x=10,y=20,z=30},
 action_flags={InTent={id=23,on=false}},motion_node="wait.main",reframework_ui_open=false}
end
assert(candidate.can_open(valid()))
for _,change in ipairs({{quest_status=0},{quest_status=1},{quest_status=3},{quest_ui_present=false},
 {quest_ui_state=1},{scene_id=0},{additional_scene=1},{camp_present=true},{camp_open=true},
 {player_type="snow.player.PlayerLobbyBase"},{reframework_ui_open=true},
 {action_flags={InTent={id=23,on=true}}},{motion_node="tent.wait"}}) do
 local s=valid();for k,v in pairs(change) do s[k]=v end
 assert(not candidate.can_open(s),'Invalid state allowed')
end
clock=1;os.clock=function() return clock end
local report;json={dump_file=function(_,v) report=v end}
local pressed=false;reframework={is_key_down=function() return pressed end,is_drawing_ui=function() return false end}
local calls=0
local progress={get_address=function() return 22 end}
local stored_progress=progress
local q={get_address=function() return 11 end,get_field=function() return stored_progress end,
 set_field=function(_,name,value) assert(name=="_currentProgress");stored_progress=value end,
 call=function(_,signature,p,scene)
 assert(signature=="activate(snow.access.Progress, snow.gui.QuestUIManager.SceneId)")
 assert(p~=progress and scene==0);stored_progress=p;calls=calls+1
 end}
local gm={call=function() return false end}
local s=valid()
local off_calls,reset_calls=0,0
local flags={call=function(_,method,id)
 assert(method=="off(System.UInt32)" and id==23);off_calls=off_calls+1;s.action_flags.InTent.on=false
end}
local replacement_player={get_field=function() return flags end,call=function(_,method)
 assert(method=="resetMotionFsm()");reset_calls=reset_calls+1
end}
local pm={call=function(_,method) assert(method=="findMasterPlayer()");return replacement_player end}
local serial=100
sdk={create_instance=function(name,simplify)
 assert(name=="snow.access.Progress" and simplify==true);serial=serial+1;local id=serial
 return {get_address=function() return id end,add_ref=function() end,release=function() end,
 set_field=function(_,key,value) assert(key=="<Status>k__BackingField" and value==2) end}
end,get_managed_singleton=function(name)
 if name=="snow.gui.QuestUIManager" then return q
 elseif name=="snow.player.PlayerManager" then return pm else return gm end
end}
local function copy(t) local out={};for k,v in pairs(t) do out[k]=type(v)=="table" and copy(v) or v end;return out end
local function capture() return copy(s) end
local controller=candidate.new(capture)
pressed=true;controller.tick()
for i=1,100 do clock=clock+0.01;controller.tick() end
assert(calls==1,'Held key repeated native mutation')
s.scene_id=0;s.camp_present=true;s.camp_open=true
clock=3;controller.tick();assert(report.phase=='open')
s=valid();s.action_flags.InTent.on=true;s.motion_node="tent.sit";s.player_type="snow.player.LongSword"
clock=4;controller.tick()
assert(report.phase=='restoring','Menu disappearance incorrectly counted as completed exit')
assert(off_calls==1 and reset_calls==1,'Missing player state cleanup')
clock=4.2;controller.tick();assert(report.phase=='restoring','Tent motion still active')
assert(off_calls==1 and reset_calls==1,'Cleanup retried unexpectedly')
s.motion_node="wait.main";clock=4.5;controller.tick()
assert(report.phase=='closed' and report.distance==0 and report.completed==1)
assert(report.before.action_flags.InTent.on==false,'Before snapshot overwritten')
pressed=false;controller.tick();pressed=true;controller.tick();assert(calls==2,'Cannot reopen after complete exit')
local second=candidate.new(capture)
q.get_address=function() return 99 end
second.tick();assert(calls==3,'New quest object should be bound at opening time')
q.get_address=function() return 11 end
pressed=false;s=valid()
local repeated=candidate.new(capture)
for cycle=1,5 do
 pressed=false;repeated.tick();pressed=true;clock=clock+1;repeated.tick()
 s.scene_id=0;s.camp_present=true;s.camp_open=true;clock=clock+0.2;repeated.tick()
 s=valid();clock=clock+0.2;repeated.tick();clock=clock+0.2;repeated.tick()
 assert(report.phase=='closed' and report.completed==cycle,'Repeated open failed')
end
''')
print('PASS: invalid states blocked; key edge; recreated player cleanup once; sitting state not accepted as exit; repeat open')
