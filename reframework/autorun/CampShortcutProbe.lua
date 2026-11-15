-- 原生帐篷快捷入口：第一阶段只读元数据，不调用游戏业务方法。
local VERSION = "observer-004"
local TYPES = {
    "snow.gui.QuestUIManager", "snow.gui.GuiManager",
    "snow.gui.fsm.camp.GuiCampFsmManager",
    "snow.gui.fsm.camp.GuiCampStartSettingFsmAction",
    "snow.gui.fsm.camp.GuiCampEndFsmAction",
    "snow.gui.fsm.camp.GuiCampInitPlayerStatusFsmAction",
    "snow.gui.fsm.camp.GuiCampCheckPlayerEquipChangedFsmAction",
    "snow.gui.fsm.camp.GuiCampAdditionalFacilityFsmAction",
    "snow.player.PlayerManager", "snow.player.PlayerBase",
    "snow.QuestManager", "snow.data.EquipDataManager",
    "snow.CharacterBase", "snow.access.Progress", "snow.access.AccessManager",
    "snow.gui.fsm.camp.GuiCamp", "snow.player.PlayerManager.MasterPlayerData",
    "snow.gui.fsm.GuiFsmBaseManager`1<snow.gui.fsm.camp.GuiCampFsmManager>",
    "snow.gui.QuestUIManager.State", "snow.gui.GuiManager.QuestAccessType",
}
local started, done, failure = os.clock(), false, nil
local function typename(t) return t and t:get_full_name() or "nil" end
local function metadata(name)
    local t = sdk.find_type_definition(name)
    if not t then return { name=name, missing=true } end
    local r={name=name,parent=typename(t:get_parent_type()),fields={},methods={}}
    for _, f in ipairs(t:get_fields()) do
        local info={name=f:get_name(),type=typename(f:get_type()),static=f:is_static()}
        r.fields[#r.fields+1]=info
    end
    for _, m in ipairs(t:get_methods()) do
        local params,names={},m:get_param_names()
        for i,p in ipairs(m:get_param_types()) do
            params[#params+1]={name=names[i],type=typename(p)}
        end
        r.methods[#r.methods+1]={name=m:get_name(),returns=typename(m:get_return_type()),static=m:is_static(),parameters=params}
    end
    local obj=sdk.get_managed_singleton(name)
    r.singleton_present=obj~=nil
    return r
end
local function export()
    local report={version=VERSION,types={},gameplay_calls=0,writes=0}
    for _,name in ipairs(TYPES) do report.types[#report.types+1]=metadata(name) end
    json.dump_file("CampShortcutProbe/metadata.json",report)
    log.info("[CampShortcutProbe] "..VERSION.." metadata exported; gameplay calls=0")
end
local observer, last_poll, last_id = nil, 0, nil
local function load_observer()
    package.loaded["CampShortcutProbe.observer"]=nil
    observer=require("CampShortcutProbe.observer")
    log.info("[CampShortcutProbe] observer module loaded "..observer.version)
end
local hooks={
    {"snow.gui.QuestUIManager","activate(snow.access.Progress, snow.gui.QuestUIManager.SceneId)","activate"},
    {"snow.gui.QuestUIManager","activateOnly(snow.gui.QuestUIManager.SceneId)","activateOnly"},
    {"snow.gui.QuestUIManager","deactivate(snow.gui.QuestUIManager.SceneId)","deactivate"},
    {"snow.gui.QuestUIManager","deactivateOnly(snow.gui.QuestUIManager.SceneId)","deactivateOnly"},
    {"snow.gui.fsm.camp.GuiCampFsmManager","openCamp()","openCamp"},
    {"snow.gui.fsm.camp.GuiCampFsmManager","closeCamp()","closeCamp"},
    {"snow.gui.fsm.camp.GuiCampFsmManager","updateCampEndPlayerFlag()","updateCampEndPlayerFlag"},
    {"snow.gui.fsm.camp.GuiCampFsmManager","checkPlayerEquipChanged()","checkPlayerEquipChanged"},
}
load_observer()
local hook_metadata={}
for _,spec in ipairs(hooks) do
    local method=assert(sdk.find_type_definition(spec[1]):get_method(spec[2]),spec[2])
    local label=spec[3]
    hook_metadata[#hook_metadata+1]={type=spec[1],signature=spec[2],address=tostring(method:get_function())}
    sdk.hook(method,function(args)
        if observer then observer.hook(label,args) end
    end,nil)
end
json.dump_file("CampShortcutProbe/hooks.json",hook_metadata)
re.on_frame(function()
    if observer then observer.frame() end
    if os.clock()-last_poll>=0.5 then
        last_poll=os.clock()
        local request=json.load_file("CampShortcutProbe/control.json")
        if request and request.id~=last_id then
            last_id=request.id
            local ok,err=pcall(function()
                if request.action=="reload" then load_observer()
                elseif request.action=="metadata" then export()
                elseif request.action=="snapshot" then observer.snapshot(request.id)
                else error("Unsupported research command") end
            end)
            json.dump_file("CampShortcutProbe/control-result.json",{id=last_id,ok=ok,error=not ok and tostring(err) or nil})
        end
    end
    if done or os.clock()-started<5 then return end
    done=true
    local ok,err=pcall(export)
    if not ok then failure=tostring(err);log.error("[CampShortcutProbe] "..failure) end
end)
re.on_draw_ui(function()
    if imgui.tree_node("Camp Shortcut - research") then
        imgui.text(VERSION.." / read-only metadata")
        if observer then observer.ui() end
        imgui.text(failure or (done and "Export complete" or "Waiting"))
        if imgui.button("Export metadata again") then
            local ok,err=pcall(export)
            failure=not ok and tostring(err) or nil
        end
        imgui.tree_pop()
    end
end)
