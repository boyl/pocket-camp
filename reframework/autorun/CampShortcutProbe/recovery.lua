-- 限定本次已确认的残留状态，一次性清除自有实验留下的 InTent。
local M={}
function M.allowed(s,reset)
    return s.quest_status==2 and s.scene_id==12 and s.additional_scene==12
        and not s.camp_present and not s.camp_open
        and s.action_flags and s.action_flags.InTent.on==(not reset)
        and type(s.motion_node)=="string" and s.motion_node:match("^tent%.")~=nil
end
function M.run(capture)
    local req=json.load_file("CampShortcutProbe/recovery-request.json")
    local old=json.load_file("CampShortcutProbe/recovery-result.json")
    if not req or (req.id~="clear-tent-001" and req.id~="reset-motion-002") or (old and old.id==req.id) then return end
    local reset=req.id=="reset-motion-002"
    local result={id=req.id,calls=0,before=capture()}
    -- 先写接收记录，异常或重载均不重复写入。
    json.dump_file("CampShortcutProbe/recovery-result.json",result)
    if not M.allowed(result.before,reset) then result.error="Recovery state no longer matches"
    else
        local ok,err=pcall(function()
            local pm=sdk.get_managed_singleton("snow.player.PlayerManager")
            local player=pm:call("findMasterPlayer()")
            result.calls=1
            if reset then
                player:call("resetMotionFsm()")
            else
                local flags=player:get_field("<PlBaseActionFlags>k__BackingField")
                flags:call("off(System.UInt32)",result.before.action_flags.InTent.id)
            end
            result.after=capture()
        end)
        result.ok=ok;result.error=not ok and tostring(err) or nil
    end
    json.dump_file("CampShortcutProbe/recovery-result.json",result)
end
return M
