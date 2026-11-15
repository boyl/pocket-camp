-- 本机已确认的 via.hid 接口；使用最近活动设备，不固定控制器编号。
local M={}
function M.short_press(max_seconds)
    local phase,started,device="blocked",0,nil
    return function(now,key,pressed,conflict,enabled)
        if key~=device then device=key;phase="blocked" end
        if not enabled or not key or conflict then phase="blocked";return false,phase end
        local neutral=not pressed
        if phase=="blocked" then if neutral then phase="idle" end
        elseif phase=="idle" then
            if pressed then started=now;phase="holding" end
        elseif phase=="holding" then
            if now-started>=max_seconds then phase="blocked"
            elseif neutral then phase="idle";return true,phase end
        end
        return false,phase
    end
end
function M.new(publish)
    local state={version="gamepad-002",binding="Tap L3 (release within 0.4s); L3+R3 excluded",available=false}
    local advance=M.short_press(0.4)
    local singleton,padtype,buttons
    local ok,err=pcall(function()
        padtype=assert(sdk.find_type_definition("via.hid.GamePad"),"GamePad type missing")
        singleton=assert(sdk.get_native_singleton("via.hid.GamePad"),"GamePad singleton missing")
        local enum=assert(sdk.find_type_definition("via.hid.GamePadButton"))
        buttons={}
        for _,name in ipairs({"LStickPush","RStickPush"}) do
            buttons[name]=assert(enum:get_field(name),name):get_data(nil)
        end
        state.available=true
    end)
    if not ok then state.error=tostring(err) end
    publish(state)
    local last_phase=nil
    return {poll=function(_,now,enabled)
        if not state.available then return false end
        local event,phase,device
        local read_ok,read_err=pcall(function()
            device=sdk.call_native_func(singleton,padtype,"get_LastInputDevice()")
            local function down(name) return device and device:call("isDown(via.hid.GamePadButton)",buttons[name])==true end
            event,phase=advance(now,device and tostring(device:get_address()),down("LStickPush"),down("RStickPush"),enabled)
        end)
        if not read_ok then
            state.available=false;state.error=tostring(read_err)
            publish(state)
            return false
        end
        if phase~=last_phase or event then
            last_phase=phase;state.phase=phase;state.triggered=event;state.time=now
            state.device=device and tostring(device:get_address()) or nil
            publish(state)
        end
        return event==true
    end}
end
return M
