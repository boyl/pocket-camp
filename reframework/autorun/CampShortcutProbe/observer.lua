-- 只读观察：不拦截原生返回值，不改变玩家或营地状态。
local M={version="observer-013"}
local last_sample, sequence = 0, 0
local events, pending = {}, {}
local ignored_owners={}
local camp_instance=sdk.find_type_definition("snow.SnowSingletonBehaviorRoot`1<snow.gui.fsm.camp.GuiCampFsmManager>"):get_field("_Instance")
local transitions,last_signature={},nil
local function export_metadata()
    local report={version=M.version,types={}}
    for _,name in ipairs({"snow.CharacterBase","snow.access.Progress","snow.access.AccessManager",
        "snow.gui.fsm.camp.GuiCamp","snow.player.PlayerManager.MasterPlayerData",
        "snow.gui.fsm.GuiFsmBaseManager`1<snow.gui.fsm.camp.GuiCampFsmManager>",
        "snow.SnowSingletonBehaviorRoot`1<snow.gui.fsm.camp.GuiCampFsmManager>",
        "snow.gui.fsm.GuiFsmBaseManager","via.Component","via.Transform",
        "snow.player.PlayerQuestBase","snow.player.PlayerInput","snow.player.PlayerSequenceController",
        "snow.gui.fsm.camp.GuiCampFsmActionRoot","snow.gui.fsm.camp.GuiCampEndFsmAction",
        "snow.player.PlayerBase.NpcFacilityMotionState","snow.player.PlayerOverrideMotionType",
        "snow.player.PlayerAction","via.motion.MotionFsm2","snow.player.PlayerAction.PlStatus",
        "snow.player.PlayerBase.PlBaseActionFlag","snow.BitSetFlag`1<snow.player.PlayerBase.PlBaseActionFlag>",
        "snow.BitSetFlagBase","via.behaviortree.BehaviorTree","via.motion.MotionFsm2Layer",
        "via.hid.GamePad","via.hid.GamePadButton","via.hid.GamePadDevice"}) do
        local t=sdk.find_type_definition(name)
        local item={name=name,missing=t==nil,methods={},fields={}}
        if t then
            item.parent=t:get_parent_type() and t:get_parent_type():get_full_name() or nil
            for _,f in ipairs(t:get_fields()) do
                item.fields[#item.fields+1]={name=f:get_name(),type=f:get_type():get_full_name(),static=f:is_static()}
            end
            for _,m in ipairs(t:get_methods()) do
                local params,names={},m:get_param_names()
                for i,p in ipairs(m:get_param_types()) do params[#params+1]={name=names[i],type=p:get_full_name()} end
                item.methods[#item.methods+1]={name=m:get_name(),parameters=params,static=m:is_static(),returns=m:get_return_type():get_full_name()}
            end
        end
        report.types[#report.types+1]=item
    end
    json.dump_file("CampShortcutProbe/metadata-003.json",report)
    local methods={}
    for _,spec in ipairs({{"snow.player.PlayerAction","setToNormal(System.Single)"},{"snow.player.PlayerBase","resetMotionFsm()"},{"snow.gui.fsm.camp.GuiCampFsmManager","updateCampEndPlayerFlag()"},{"snow.gui.fsm.camp.GuiCampEndFsmAction","start(via.behaviortree.ActionArg)"}}) do
        local method=sdk.find_type_definition(spec[1]):get_method(spec[2])
        methods[#methods+1]={type=spec[1],signature=spec[2],address=tostring(method:get_function())}
    end
    json.dump_file("CampShortcutProbe/recovery-methods.json",methods)
    local progress_methods={}
    for _,signature in ipairs({".ctor(via.GameObject, via.GameObject)","receiveMethodHasFinished(snow.access.Progress.FsmNodeStatus)","clear()"}) do
        local method=assert(sdk.find_type_definition("snow.access.Progress"):get_method(signature),signature)
        progress_methods[#progress_methods+1]={type="snow.access.Progress",signature=signature,address=tostring(method:get_function())}
    end
    json.dump_file("CampShortcutProbe/progress-methods.json",progress_methods)
end
export_metadata()
local function field(o,n) return o and o:get_field(n) end
local function scalar(v)
    if v==nil or type(v)=="number" or type(v)=="boolean" or type(v)=="string" then return v end
    local f=v:get_type_definition():get_field("value__")
    if f then return f:get_data(v) end
    return v:get_type_definition():get_full_name()
end
local function capture()
    local q=sdk.get_managed_singleton("snow.gui.QuestUIManager")
    local c=camp_instance:get_data(nil)
    local pm=sdk.get_managed_singleton("snow.player.PlayerManager")
    local qm=sdk.get_managed_singleton("snow.QuestManager")
    local gm=sdk.get_managed_singleton("snow.gui.GuiManager")
    local p=pm and pm:call("findMasterPlayer()")
    local pos=p and p:call("get_Pos()")
    local progress=field(q,"_currentProgress")
    local result={version=M.version,time=os.clock(),quest_ui_present=q~=nil,camp_present=c~=nil,
        quest_ui_state=scalar(field(q,"_state")),scene_id=scalar(field(q,"_currentSceneId")),
        additional_scene=scalar(field(q,"_AdditionalSceneId")),
        progress_type=scalar(field(q,"_currentProgress")),
        camp_open=c and c:call("isOpenCamp()") or false,
        camp_menu=scalar(field(c,"<CampMenuState>k__BackingField")),
        camp_facility_state=scalar(field(c,"<FacilityCallState>k__BackingField")),
        quest_status=scalar(field(qm,"_QuestStatus")),quest_access=scalar(field(gm,"<QuestAccess>k__BackingField")),
        player_type=p and p:get_type_definition():get_full_name() or nil,
        weapon_type=scalar(field(p,"_playerWeaponType")),weapon_id=scalar(field(p,"_PlayerWeaponListID")),
        position=pos and {x=pos.x,y=pos.y,z=pos.z} or nil,
        progress_status=scalar(field(progress,"<Status>k__BackingField")),
        progress_marker_type=scalar(field(progress,"<MarkerOwnerType>k__BackingField")),
        progress_marker_present=field(progress,"<Marker>k__BackingField")~=nil,
        progress_sensor_present=field(progress,"<Sensor>k__BackingField")~=nil}
    result.reframework_ui_open=reframework:is_drawing_ui()
    result.player_input=scalar(field(p,"_isInput"))
    result.facility_motion=scalar(field(p,"<_NpcFacilityMotionState>k__BackingField"))
    result.override_motion=scalar(field(p,"<OverrideMotionSequence>k__BackingField"))
    result.disable_longjump=scalar(field(p,"<IsDisableLongJumpPlInput>k__BackingField"))
    result.disable_camera_combo=scalar(field(p,"<DisableCameraComboLock>k__BackingField"))
    result.gui_input_disabled=gm and gm:call("IsPlayerAllInputDisable()") or false
    result.gui_close_invalid=scalar(field(gm,"<IsInputInvalidGuiCloseFrame>k__BackingField"))
    local action=field(p,"<RefPlayerAction>k__BackingField")
    result.player_status=scalar(field(action,"PlayerStatus"))
    result.player_status_lower=scalar(field(action,"PlayerStatusLower"))
    local flags=field(p,"<PlBaseActionFlags>k__BackingField")
    local flagtype=sdk.find_type_definition("snow.player.PlayerBase.PlBaseActionFlag")
    result.action_flags={}
    for _,name in ipairs({"InTent","SittingTableOrBench","OverrideMotionMode","CookingNow"}) do
        local value=scalar(flagtype:get_field(name):get_data(nil))
        result.action_flags[name]={id=value,on=flags and flags:call("isOn(System.UInt32)",value) or false}
    end
    local fsm=field(p,"_RefMotionFsm2")
    result.motion_node=fsm and fsm:call("getCurrentNodeName(System.UInt32)",0)
    result.motion_node_id=fsm and fsm:call("getCurrentNodeID(System.UInt32)",0)
    local armor=field(p,"_PlayerArmorListID")
    result.armor_ids={}
    if armor then
        for i=0,math.min(armor:get_size(),5)-1 do result.armor_ids[#result.armor_ids+1]=scalar(armor:get_element(i)) end
    end
    return result
end
function M.snapshot(label)
    local s=capture();s.label=label
    json.dump_file("CampShortcutProbe/state.json",s)
    return s
end
function M.hook(label,args)
    if #pending>=64 then return end
    local owner=sdk.to_managed_object(args[2])
    local owner_type=owner and owner:get_type_definition():get_full_name() or "nil"
    local expected=label:match("activate") and "snow.gui.QuestUIManager" or "snow.gui.fsm.camp.GuiCampFsmManager"
    if owner_type~=expected then ignored_owners[owner_type]=(ignored_owners[owner_type] or 0)+1;return end
    local row={event=label,time=os.clock(),owner=owner_type}
    if label=="activate" then
        row.scene=sdk.to_int64(args[4]);local p=sdk.to_managed_object(args[3])
        row.progress_type=p and p:get_type_definition():get_full_name() or nil
    elseif label=="activateOnly" or label=="deactivate" or label=="deactivateOnly" then
        row.scene=sdk.to_int64(args[3])
    end
    pending[#pending+1]=row
end
package.loaded["CampShortcutProbe.candidate"]=nil
local candidate=require("CampShortcutProbe.candidate").new(capture)
function M.frame()
    candidate.tick()
    if os.clock()-last_sample<0.5 then return end
    last_sample=os.clock()
    local ok,err=pcall(function()
        local s=M.snapshot("periodic")
        local sig=table.concat({tostring(s.quest_status),tostring(s.quest_ui_state),tostring(s.scene_id),tostring(s.camp_present),tostring(s.camp_open),tostring(s.camp_menu),tostring(s.camp_facility_state),tostring(s.weapon_type),tostring(s.weapon_id)},"|")
        if sig~=last_signature then
            last_signature=sig;transitions[#transitions+1]=s
            if #transitions>256 then table.remove(transitions,1) end
            json.dump_file("CampShortcutProbe/transitions.json",transitions)
        end
        json.dump_file("CampShortcutProbe/ignored-hook-owners.json",ignored_owners)
        for _,row in ipairs(pending) do
            row.state=s;sequence=sequence+1;row.sequence=sequence
            events[#events+1]=row
            if #events>100 then table.remove(events,1) end
        end
        if #pending>0 then json.dump_file("CampShortcutProbe/events.json",events);pending={} end
    end)
    if not ok then
        json.dump_file("CampShortcutProbe/state.json",{version=M.version,error=tostring(err)})
        last_sample=os.clock()+10
    end
end
function M.ui() imgui.text(M.version);candidate.ui() end
return M
