-- 唯一运行入口；无外部 require、原生 hook 或周期性磁盘扫描。
if _G.__PocketCampLoaded then return end
_G.__PocketCampLoaded=true
local status={version="1.0.0",phase="initializing"}
local controller,failure
local function persist()
    local ok,err=pcall(json.dump_file,"PocketCamp/status.json",status)
    if not ok then log.error("[Pocket Camp] Status write failed: "..tostring(err)) end
end
local function report(s)
    status.phase=s.phase;status.event=s.event;status.detail=s.detail
    status.calls=s.calls;status.completed=s.completed;status.cleanup_calls=s.cleanup_calls
    persist()
end
local function report_pad(s)
    -- 按键相位只用于输入判定，不逐帧写磁盘。
    if status.gamepad_available~=s.available or status.gamepad_error~=s.error then
        status.gamepad_available=s.available;status.gamepad_error=s.error;persist()
    end
end
local ok,err=pcall(function()
    local capture=Runtime.new()
    controller=Controller.new(capture,Gamepad.new(report_pad),report)
end)
if not ok then failure=tostring(err);status.phase="disabled";status.detail=failure;persist();log.error("[Pocket Camp] "..failure)
else log.info("[Pocket Camp] 1.0.0 loaded; F10 / tap L3") end
re.on_frame(function()
    if failure or not controller then return end
    local tick_ok,tick_err=pcall(controller.tick)
    if not tick_ok then
        failure=tostring(tick_err);status.phase="disabled";status.detail=failure;persist()
        log.error("[Pocket Camp] "..failure)
    end
end)
re.on_draw_ui(function()
    if imgui.tree_node("Pocket Camp") then
        imgui.text("Pocket Camp 1.0.0 | F10 / tap L3")
        imgui.text("State: "..status.phase)
        imgui.text("Close this overlay before using the shortcut.")
        imgui.text("Close the camp using its native Back / Leave command.")
        if status.detail then imgui.text(tostring(status.detail)) end
        if status.gamepad_error then imgui.text("Gamepad unavailable: "..status.gamepad_error) end
        imgui.tree_pop()
    end
end)
