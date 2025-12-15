--// Cache
local pcall, getgenv, next, setmetatable, Vector2new, CFramenew, Color3fromRGB, Drawingnew, TweenInfonew, stringupper, mousemoverel = pcall, getgenv, next, setmetatable, Vector2.new, CFrame.new, Color3.fromRGB, Drawing.new, TweenInfo.new, string.upper, mousemoverel or (Input and Input.MouseMove)
--// Launching checks
if not getgenv().Waddler or getgenv().Waddler.Aimbot then return end
--// Services
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
--// Variables
local RequiredDistance, Typing, Running, ServiceConnections, Animation, OriginalSensitivity = 2000, false, false, {}
--// Environment
getgenv().Waddler.Aimbot = {
    Settings = {
        Enabled = false,
        TeamCheck = false,
        AliveCheck = true,
        WallCheck = false,
        Sensitivity = 0,
        ThirdPerson = false,
        ThirdPersonSensitivity = 3,
        TriggerKey = "MouseButton2",
        Toggle = false,
        LockPart = "Head",
        StickyAim = false  -- New: Sticky Aim toggle (controlled from UI)
    },
    FOVSettings = {
        Enabled = true,
        Visible = true,
        Amount = 90,
        Color = Color3fromRGB(255, 255, 255),
        LockedColor = Color3fromRGB(255, 70, 70),
        Transparency = 0.5,
        Sides = 60,
        Thickness = 1,
        Filled = false
    },
    FOVCircle = Drawingnew("Circle")
}
local Environment = getgenv().Waddler.Aimbot

--// Core Functions
local function ConvertVector(Vector)
    return Vector2new(Vector.X, Vector.Y)
end

local function CancelLock()
    Environment.Locked = nil
    Environment.FOVCircle.Color = Environment.FOVSettings.Color
    UserInputService.MouseDeltaSensitivity = OriginalSensitivity
    if Animation then
        Animation:Cancel()
    end
end

local function IsValidTarget(Player)
    if Player == LocalPlayer then return false end
    if not Player.Character then return false end
    if not Player.Character:FindFirstChild(Environment.Settings.LockPart) then return false end
    if not Player.Character:FindFirstChildOfClass("Humanoid") then return false end
    if Environment.Settings.TeamCheck and Player.Team and LocalPlayer.Team and Player.Team == LocalPlayer.Team then return false end
    if Environment.Settings.AliveCheck and Player.Character:FindFirstChildOfClass("Humanoid").Health <= 0 then return false end
    if Environment.Settings.WallCheck then
        local obscuring = Camera:GetPartsObscuringTarget({Player.Character[Environment.Settings.LockPart].Position}, Player.Character:GetDescendants())
        if #obscuring > 0 then return false end
    end
    return true
end

local function GetClosestPlayer()
    -- Sticky Aim Logic: If enabled and we have a valid locked target → KEEP IT
    if Environment.Settings.StickyAim and Environment.Locked and IsValidTarget(Environment.Locked) then
        return
    end

    -- If current locked target is invalid → cancel lock
    if Environment.Locked and not IsValidTarget(Environment.Locked) then
        CancelLock()
    end

    -- Only search for a new target if:
    -- - StickyAim is OFF, OR
    -- - We have no current valid lock
    if not Environment.Settings.StickyAim or not Environment.Locked then
        RequiredDistance = Environment.FOVSettings.Enabled and Environment.FOVSettings.Amount or 2000
        local BestPlayer = nil

        for _, v in next, Players:GetPlayers() do
            if v ~= LocalPlayer and v.Character and v.Character:FindFirstChild(Environment.Settings.LockPart) and v.Character:FindFirstChildOfClass("Humanoid") then
                if Environment.Settings.TeamCheck and v.Team and LocalPlayer.Team and v.Team == LocalPlayer.Team then continue end
                if Environment.Settings.AliveCheck and v.Character:FindFirstChildOfClass("Humanoid").Health <= 0 then continue end
                if Environment.Settings.WallCheck then
                    local obscuring = Camera:GetPartsObscuringTarget({v.Character[Environment.Settings.LockPart].Position}, v.Character:GetDescendants())
                    if #obscuring > 0 then continue end
                end

                local Vector, OnScreen = Camera:WorldToViewportPoint(v.Character[Environment.Settings.LockPart].Position)
                Vector = ConvertVector(Vector)
                local Distance = (UserInputService:GetMouseLocation() - Vector).Magnitude

                if OnScreen and Distance < RequiredDistance then
                    RequiredDistance = Distance
                    BestPlayer = v
                end
            end
        end

        if BestPlayer then
            Environment.Locked = BestPlayer
        end
    end
end

local function Load()
    OriginalSensitivity = UserInputService.MouseDeltaSensitivity

    ServiceConnections.RenderSteppedConnection = RunService.RenderStepped:Connect(function()
        if Environment.FOVSettings.Enabled and Environment.Settings.Enabled then
            Environment.FOVCircle.Radius = Environment.FOVSettings.Amount
            Environment.FOVCircle.Thickness = Environment.FOVSettings.Thickness
            Environment.FOVCircle.Filled = Environment.FOVSettings.Filled
            Environment.FOVCircle.NumSides = Environment.FOVSettings.Sides
            Environment.FOVCircle.Color = Environment.FOVSettings.Color
            Environment.FOVCircle.Transparency = Environment.FOVSettings.Transparency
            Environment.FOVCircle.Visible = Environment.FOVSettings.Visible
            Environment.FOVCircle.Position = Vector2new(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y)
        else
            Environment.FOVCircle.Visible = false
        end

        if Running and Environment.Settings.Enabled then
            GetClosestPlayer()

            if Environment.Locked then
                if not IsValidTarget(Environment.Locked) then
                    CancelLock()
                else
                    if Environment.Settings.ThirdPerson then
                        local Vector = Camera:WorldToViewportPoint(Environment.Locked.Character[Environment.Settings.LockPart].Position)
                        mousemoverel((Vector.X - UserInputService:GetMouseLocation().X) * Environment.Settings.ThirdPersonSensitivity,
                                     (Vector.Y - UserInputService:GetMouseLocation().Y) * Environment.Settings.ThirdPersonSensitivity)
                    else
                        if Environment.Settings.Sensitivity > 0 then
                            Animation = TweenService:Create(Camera, TweenInfonew(Environment.Settings.Sensitivity, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
                                {CFrame = CFramenew(Camera.CFrame.Position, Environment.Locked.Character[Environment.Settings.LockPart].Position)})
                            Animation:Play()
                        else
                            Camera.CFrame = CFramenew(Camera.CFrame.Position, Environment.Locked.Character[Environment.Settings.LockPart].Position)
                        end
                        UserInputService.MouseDeltaSensitivity = 0
                    end
                    Environment.FOVCircle.Color = Environment.FOVSettings.LockedColor
                end
            end
        end
    end)

    ServiceConnections.InputBeganConnection = UserInputService.InputBegan:Connect(function(Input)
        if not Typing then
            pcall(function()
                local trigger = Environment.Settings.TriggerKey
                local isKey = Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode == Enum.KeyCode[string.upper(trigger)]
                local isMouse = Input.UserInputType == Enum.UserInputType[trigger]
                if isKey or isMouse then
                    if Environment.Settings.Toggle then
                        Running = not Running
                        if not Running then
                            CancelLock()
                        end
                    else
                        Running = true
                    end
                end
            end)
        end
    end)

    ServiceConnections.InputEndedConnection = UserInputService.InputEnded:Connect(function(Input)
        if not Typing and not Environment.Settings.Toggle then
            pcall(function()
                local trigger = Environment.Settings.TriggerKey
                local isKey = Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode == Enum.KeyCode[string.upper(trigger)]
                local isMouse = Input.UserInputType == Enum.UserInputType[trigger]
                if isKey or isMouse then
                    Running = false
                    CancelLock()
                end
            end)
        end
    end)
end

--// Typing Check
ServiceConnections.TypingStartedConnection = UserInputService.TextBoxFocused:Connect(function()
    Typing = true
end)
ServiceConnections.TypingEndedConnection = UserInputService.TextBoxFocusReleased:Connect(function()
    Typing = false
end)

--// Functions
Environment.Functions = {}
function Environment.Functions:Exit()
    for _, v in next, ServiceConnections do
        v:Disconnect()
    end
    Environment.FOVCircle:Remove()
    getgenv().Waddler.Aimbot.Functions = nil
    getgenv().Waddler.Aimbot = nil
end

function Environment.Functions:Restart()
    for _, v in next, ServiceConnections do
        v:Disconnect()
    end
    Load()
end

function Environment.Functions:ResetSettings()
    Environment.Settings = {
        Enabled = false,
        TeamCheck = false,
        AliveCheck = true,
        WallCheck = false,
        Sensitivity = 0,
        ThirdPerson = false,
        ThirdPersonSensitivity = 3,
        TriggerKey = "MouseButton2",
        Toggle = false,
        LockPart = "Head",
        StickyAim = false
    }
    Environment.FOVSettings = {
        Enabled = true,
        Visible = true,
        Amount = 90,
        Color = Color3fromRGB(255, 255, 255),
        LockedColor = Color3fromRGB(255, 70, 70),
        Transparency = 0.5,
        Sides = 60,
        Thickness = 1,
        Filled = false
    }
end

setmetatable(Environment.Functions, {__newindex = warn})

--// Load
Load()
