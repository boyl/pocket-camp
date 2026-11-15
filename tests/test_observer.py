"""观察器回归：共享底层函数的无关调用不能淹没帐篷事件。"""
from pathlib import Path
from lupa.lua54 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
written={}
package.preload["CampShortcutProbe.candidate"]=function() return {new=function() return {tick=function() end} end} end
clock=1
reframework={is_drawing_ui=function() return false end}
os.clock=function() return clock end
json={dump_file=function(path,value) written[path]=value end}
local singleton_field={get_data=function() return nil end}
local meta={get_field=function() return singleton_field end,
    get_method=function() return {get_function=function() return "mock-function" end} end,
    get_parent_type=function() return nil end,
    get_fields=function() return {} end,get_methods=function() return {} end}
sdk={find_type_definition=function() return meta end,
    get_managed_singleton=function() return nil end,
    to_managed_object=function(v) return v end,to_int64=function(v) return v end}
function owner(name)
    return {get_type_definition=function()
        return {get_full_name=function() return name end}
    end}
end
''')
source = Path(__file__).parents[1] / 'reframework/autorun/CampShortcutProbe/observer.lua'
lua.globals().observer = lua.execute(source.read_text(encoding='utf-8'))
lua.execute('''
local unrelated=owner("snow.gui.GuiCommonHeadMessage")
for i=1,5000 do observer.hook("openCamp",{[2]=unrelated}) end
observer.hook("activate",{[2]=owner("snow.gui.QuestUIManager"),[3]=owner("snow.access.Progress"),[4]=0})
observer.hook("deactivateOnly",{[2]=owner("snow.gui.QuestUIManager"),[3]=0})
observer.frame()
local events=assert(written["CampShortcutProbe/events.json"])
assert(#events==2,"共享函数的无关事件污染有效日志")
assert(events[1].event=="activate" and events[1].scene==0)
assert(events[1].progress_type=="snow.access.Progress")
assert(events[2].event=="deactivateOnly" and events[2].scene==0)
assert(written["CampShortcutProbe/ignored-hook-owners.json"]["snow.gui.GuiCommonHeadMessage"]==5000)
assert(#written["CampShortcutProbe/transitions.json"]==1)
clock=2;observer.frame()
assert(#written["CampShortcutProbe/transitions.json"]==1,"相同状态重复写入转换记录")
''')
print('PASS: 5000 shared-hook calls filtered; native activation/deactivation retained; unchanged state deduplicated')
