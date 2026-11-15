-- 只读取入口门禁及退出收尾实际需要的原生状态。
local M={}
local function field(o,n) return o and o:get_field(n) end
local function scalar(v)
    if v==nil or type(v)=="number" or type(v)=="boolean" or type(v)=="string" then return v end
    local f=v:get_type_definition():get_field("value__")
    assert(f,"Unexpected enum representation")
    return f:get_data(v)
end
function M.new()
    local camp_type=assert(sdk.find_type_definition("snow.SnowSingletonBehaviorRoot`1<snow.gui.fsm.camp.GuiCampFsmManager>"),"Camp type missing")
    local camp_instance=assert(camp_type:get_field("_Instance"),"Camp instance field missing")
    local flags_type=assert(sdk.find_type_definition("snow.player.PlayerBase.PlBaseActionFlag"),"Player flags missing")
    local tent_flag=scalar(assert(flags_type:get_field("InTent")):get_data(nil))
    return function()
        local q=sdk.get_managed_singleton("snow.gui.QuestUIManager")
        local c=camp_instance:get_data(nil)
        local pm=sdk.get_managed_singleton("snow.player.PlayerManager")
        local qm=sdk.get_managed_singleton("snow.QuestManager")
        local p=pm and pm:call("findMasterPlayer()")
        local flags=field(p,"<PlBaseActionFlags>k__BackingField")
        local fsm=field(p,"_RefMotionFsm2")
        return {
            quest_status=scalar(field(qm,"_QuestStatus")),
            quest_ui_present=q~=nil,quest_ui_state=scalar(field(q,"_state")),
            scene_id=scalar(field(q,"_currentSceneId")),additional_scene=scalar(field(q,"_AdditionalSceneId")),
            camp_present=c~=nil,camp_open=c and c:call("isOpenCamp()") or false,
            player_type=p and p:get_type_definition():get_full_name() or nil,
            reframework_ui_open=reframework:is_drawing_ui(),
            action_flags={InTent={id=tent_flag,on=flags and flags:call("isOn(System.UInt32)",tent_flag) or false}},
            motion_node=fsm and fsm:call("getCurrentNodeName(System.UInt32)",0)
        }
    end
end
return M
