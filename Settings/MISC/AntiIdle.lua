local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer

local function PreventIdle()
    local Camera = workspace.CurrentCamera
    if not Camera then return end

    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new(0, 0))
    
    VirtualUser:Button2Down(Vector2.new(0, 0), Camera.CFrame)
    task.wait(0.1)
    VirtualUser:Button2Up(Vector2.new(0, 0), Camera.CFrame)
end

LocalPlayer.Idled:Connect(function()
    pcall(PreventIdle)
end)
