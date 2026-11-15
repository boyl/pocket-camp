-- Pocket Camp：菜单交给游戏，补齐野外入口缺失的角色退出收尾。
local M={version="1.0.0"}
function M.can_open(s)
    if s.quest_status~=2 or not s.player_type or s.player_type=="snow.player.PlayerLobbyBase" then return false,"Not in active quest" end
    if not s.quest_ui_present or s.quest_ui_state~=2 then return false,"Quest UI not ready" end
    if s.scene_id~=12 or s.additional_scene~=12 or s.camp_present or s.camp_open then return false,"A facility is already active" end
    if s.reframework_ui_open then return false,"Close REFramework first" end
    if not s.action_flags or s.action_flags.InTent.on~=false or (s.motion_node or ""):match("^tent%.") then return false,"Player has not left tent state" end
    return true
end
function M.new(capture, gamepad, publish)
    local state={version=M.version,phase="armed",calls=0,cleanup_calls=0,completed=0,events={}}
    local down=false
    local last_sample=0
    local active_q,owned_progress,previous_progress=nil,nil,nil
    local function record(kind,detail,s)
        state.event=kind;state.detail=detail
        publish(state)
    end
    local function release_context(restore)
        if not owned_progress then return end
        local current=sdk.get_managed_singleton("snow.gui.QuestUIManager")
        if restore and current and current:get_address()==active_q then
            local actual=current:get_field("_currentProgress")
            if actual and actual:get_address()==owned_progress:get_address() then
                current:set_field("_currentProgress",previous_progress)
            end
        end
        owned_progress:release()
        owned_progress,previous_progress,active_q=nil,nil,nil
    end
    local function activate()
        local s=capture()
        local valid,reason=M.can_open(s)
        if not valid then record("rejected",reason,s);return end
        local current=sdk.get_managed_singleton("snow.gui.QuestUIManager")
        local gm=sdk.get_managed_singleton("snow.gui.GuiManager")
        if not gm or gm:call("IsStartMenuAndSubmenuOpen()") or gm:call("isOpenTalkWindow()") or gm:call("isOpenItemBoxWindow()") then
            record("rejected","Close other menus first",s);return
        end
        active_q=current:get_address()
        previous_progress=current:get_field("_currentProgress")
        -- 仅作菜单完成信号，不注册场景传感器或调用依赖营地对象的构造函数。
        owned_progress=assert(sdk.create_instance("snow.access.Progress",true),"Progress allocation failed")
        owned_progress:add_ref()
        owned_progress:set_field("<Status>k__BackingField",2)
        state.before=s;state.phase="opening";state.started=os.clock();state.calls=state.calls+1
        record("call_activate","Private Progress for current quest, SceneId.Camp=0",s)
        current:call("activate(snow.access.Progress, snow.gui.QuestUIManager.SceneId)",owned_progress,0)
    end
    local instance={}
    local function finish_player(s)
        local current=sdk.get_managed_singleton("snow.gui.QuestUIManager")
        assert(current and current:get_address()==active_q and s.quest_status==2,"Quest changed during exit")
        state.phase="restoring";state.restore_started=os.clock()
        record("native_menu_closed","Checking player cleanup",s)
        local pm=sdk.get_managed_singleton("snow.player.PlayerManager")
        local player=assert(pm and pm:call("findMasterPlayer()"),"Player missing during exit")
        -- 换武器会更换玩家对象，必须重新获取本地主角，不复用打开前对象。
        if s.action_flags.InTent.on then
            player:get_field("<PlBaseActionFlags>k__BackingField"):call("off(System.UInt32)",s.action_flags.InTent.id)
            state.cleanup_calls=state.cleanup_calls+1
        end
        if (s.motion_node or ""):match("^tent%.") then
            player:call("resetMotionFsm()")
            state.cleanup_calls=state.cleanup_calls+1
        end
        record("player_cleanup_requested",nil,s)
    end
    function instance.tick()
        if owned_progress then
            local current=sdk.get_managed_singleton("snow.gui.QuestUIManager")
            if not current or current:get_address()~=active_q then
                release_context(false);state.phase="armed"
                record("quest_context_ended","Released old quest context without writing into new quest")
            end
        end
        local pressed=reframework:is_key_down(0x79)==true
        local edge=pressed and not down;down=pressed
        local ready=state.phase=="armed" or state.phase=="closed"
        local pad_edge=gamepad:poll(os.clock(),ready and not reframework:is_drawing_ui())
        if (edge or pad_edge) and ready then
            record("input_trigger",pad_edge and "gamepad_L3_short_release" or "keyboard_F10")
            local ok,err=pcall(activate)
            if not ok then state.phase="error";record("error",tostring(err)) end
        end
        if state.phase~="opening" and state.phase~="open" and state.phase~="restoring" then return end
        if os.clock()-last_sample<0.1 then return end
        last_sample=os.clock()
        local ok,s=pcall(capture)
        if not ok then state.phase="error";record("error",tostring(s));return end
        if state.phase=="opening" then
            if s.scene_id==0 and s.camp_present and s.camp_open then
                state.phase="open";record("native_menu_open",nil,s)
            elseif os.clock()-state.started>10 then
                state.phase="timeout";record("open_timeout","No automatic retry",s)
            end
        elseif state.phase=="open" and not s.camp_present and s.scene_id==12 and s.additional_scene==12 then
            local restored,err=pcall(finish_player,s)
            if not restored then state.phase="error";record("cleanup_error",tostring(err),s) end
        elseif state.phase=="restoring" and s.action_flags.InTent.on==false and not (s.motion_node or ""):match("^tent%.") then
            release_context(true)
            state.phase="closed";state.after=s
            state.completed=state.completed+1
            if state.before.position and s.position then
                local a,b=state.before.position,s.position
                state.distance=math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2)
            end
            record("player_exit_complete",nil,s)
        elseif state.phase=="restoring" and os.clock()-state.restore_started>5 then
            state.phase="error";record("cleanup_timeout","Player still in tent state; no automatic retry",s)
        end
    end
    function instance.ui()
        imgui.text(M.version.." / F10 or tap L3 / "..state.phase)
        imgui.text("Use the native Back/Leave command to close.")
    end
    record("armed","Repeated opening enabled after player exit completes",capture())
    return instance
end
return M
