"""回归：未进帐篷的新狩猎任务也必须可呼出，不保留上一任务对象。"""
from pathlib import Path
from lupa.lua54 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.globals().candidate=lua.execute((Path(__file__).parents[1]/'reframework/autorun/CampShortcutProbe/candidate.lua').read_text(encoding='utf-8'))
lua.execute('''
local fresh={quest_status=2,player_type="snow.player.LongSword",quest_ui_present=true,quest_ui_state=2,
 scene_id=12,additional_scene=12,camp_present=false,camp_open=false,
 progress_marker_present=false,progress_sensor_present=false,
 action_flags={InTent={id=23,on=false}},motion_node="wait.main",reframework_ui_open=false}
local allowed,why=candidate.can_open(fresh)
assert(allowed,'Fresh hunt without tent visit was rejected: '..tostring(why))
package.preload["CampShortcutProbe.gamepad"]=function() return {new=function() return {poll=function() return false end} end} end
local now=0;os.clock=function() return now end
local key=false;reframework={is_key_down=function() return key end,is_drawing_ui=function() return false end}
local report;json={dump_file=function(_,v) report=v end}
local current=nil
local allocated,released,retained=0,0,0
local function manager(id,previous)
 local stored=previous
 return {get_address=function() return id end,get_field=function() return stored end,
 set_field=function(_,name,value) assert(name=='_currentProgress');stored=value end,
 call=function(_,name,p,scene)
 assert(name=='activate(snow.access.Progress, snow.gui.QuestUIManager.SceneId)' and scene==0)
 stored=p
 end}
end
local pm={call=function() return {} end}
sdk={get_managed_singleton=function(name)
 if name=='snow.gui.QuestUIManager' then return current
 elseif name=='snow.player.PlayerManager' then return pm else return {call=function() return false end} end
end,create_instance=function(name,simplify)
 assert(name=='snow.access.Progress' and simplify);allocated=allocated+1;local id=100+allocated
 return {add_ref=function() retained=retained+1 end,release=function() released=released+1 end,
 get_address=function() return id end,set_field=function(_,k,v) assert(k=='<Status>k__BackingField' and v==2) end}
end}
local function copy(t) local c={};for k,v in pairs(t) do c[k]=type(v)=='table' and copy(v) or v end;return c end
local controller=candidate.new(function() return copy(fresh) end)
local function frame() now=now+0.2;controller.tick() end
local function cycle(q)
 current=q;key=false;frame();key=true;frame()
 fresh.scene_id=0;fresh.camp_present=true;fresh.camp_open=true;frame()
 fresh.scene_id=12;fresh.camp_present=false;fresh.camp_open=false;frame();frame()
 assert(report.phase=='closed')
end
local first=manager(1,nil);cycle(first)
assert(first:get_field('_currentProgress')==nil,'Original nil progress not restored')
local previous={get_address=function() return 50 end}
local second=manager(2,previous);cycle(second)
assert(second:get_field('_currentProgress')==previous,'Original native progress not restored')
assert(allocated==2 and retained==2 and released==2,'Private Progress reference imbalance')
-- 打开中切换地图：只释放自己的引用，不改写新任务或恢复新玩家动作。
key=false;frame();key=true;frame()
local third=manager(3,previous);current=third;key=false;frame()
assert(report.phase=='armed' and third:get_field('_currentProgress')==previous)
assert(released==3,'Old quest request reference retained')
''')
print('PASS: fresh hunt; loading at title; two quest managers; original Progress restored; reference ownership; quest change while opening')
