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
        StickyAim = false
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
    FOVCircle = Drawingnew("Circle"),
    Locked = nil
}

local Aimbot = getgenv().Waddler.Aimbot  

local function GetKeyName(EnumValue)
    return string.match(tostring(EnumValue), "Enum%.UserInputType%.(.+)") 
        or string.match(tostring(EnumValue), "Enum%.KeyCode%.(.+)") 
        or "MouseButton2"
end

--// Core Functions
local function ConvertVector(Vector)
    return Vector2new(Vector.X, Vector.Y)
end

local function CancelLock()
    Aimbot.Locked = nil
    Aimbot.FOVCircle.Color = Aimbot.FOVSettings.Color
    UserInputService.MouseDeltaSensitivity = OriginalSensitivity
    if Animation then Animation:Cancel() end
end

local function IsValidTarget(Player)
    if Player == LocalPlayer then return false end
    if not Player.Character then return false end
    if not Player.Character:FindFirstChild(Aimbot.Settings.LockPart) then return false end
    if not Player.Character:FindFirstChildOfClass("Humanoid") then return false end
    if Aimbot.Settings.TeamCheck and Player.Team and LocalPlayer.Team and Player.Team == LocalPlayer.Team then return false end
    if Aimbot.Settings.AliveCheck and Player.Character:FindFirstChildOfClass("Humanoid").Health <= 0 then return false end
    if Aimbot.Settings.WallCheck then
        local obscuring = Camera:GetPartsObscuringTarget({Player.Character[Aimbot.Settings.LockPart].Position}, Player.Character:GetDescendants())
        if #obscuring > 0 then return false end
    end
    return true
end

local function GetClosestPlayer()
    if Aimbot.Settings.StickyAim and Aimbot.Locked and IsValidTarget(Aimbot.Locked) then
        return
    end
    if Aimbot.Locked and not IsValidTarget(Aimbot.Locked) then
        CancelLock()
    end
    if not Aimbot.Settings.StickyAim or not Aimbot.Locked then
        RequiredDistance = Aimbot.FOVSettings.Enabled and Aimbot.FOVSettings.Amount or 2000
        local BestPlayer = nil
        for _, v in next, Players:GetPlayers() do
            if IsValidTarget(v) then
                local Vector, OnScreen = Camera:WorldToViewportPoint(v.Character[Aimbot.Settings.LockPart].Position)
                Vector = ConvertVector(Vector)
                local Distance = (UserInputService:GetMouseLocation() - Vector).Magnitude
                if OnScreen and Distance < RequiredDistance then
                    RequiredDistance = Distance
                    BestPlayer = v
                end
            end
        end
        if BestPlayer then
            Aimbot.Locked = BestPlayer
        end
    end
end

local function Load()
    OriginalSensitivity = UserInputService.MouseDeltaSensitivity

    ServiceConnections.RenderSteppedConnection = RunService.RenderStepped:Connect(function()
        -- FOV Circle
        if Aimbot.FOVSettings.Enabled and Aimbot.Settings.Enabled then
            Aimbot.FOVCircle.Radius = Aimbot.FOVSettings.Amount
            Aimbot.FOVCircle.Thickness = Aimbot.FOVSettings.Thickness
            Aimbot.FOVCircle.Filled = Aimbot.FOVSettings.Filled
            Aimbot.FOVCircle.NumSides = Aimbot.FOVSettings.Sides
            Aimbot.FOVCircle.Color = Aimbot.FOVSettings.Color
            Aimbot.FOVCircle.Transparency = Aimbot.FOVSettings.Transparency
            Aimbot.FOVCircle.Visible = Aimbot.FOVSettings.Visible
            Aimbot.FOVCircle.Position = Vector2new(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y)
        else
            Aimbot.FOVCircle.Visible = false
        end

        if Running and Aimbot.Settings.Enabled then
            GetClosestPlayer()
            if Aimbot.Locked and IsValidTarget(Aimbot.Locked) then
                if Aimbot.Settings.ThirdPerson then
                    local Vector = Camera:WorldToViewportPoint(Aimbot.Locked.Character[Aimbot.Settings.LockPart].Position)
                    mousemoverel((Vector.X - UserInputService:GetMouseLocation().X) * Aimbot.Settings.ThirdPersonSensitivity,
                                 (Vector.Y - UserInputService:GetMouseLocation().Y) * Aimbot.Settings.ThirdPersonSensitivity)
                else
                    if Aimbot.Settings.Sensitivity > 0 then
                        Animation = TweenService:Create(Camera, TweenInfonew(Aimbot.Settings.Sensitivity, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
                            {CFrame = CFramenew(Camera.CFrame.Position, Aimbot.Locked.Character[Aimbot.Settings.LockPart].Position)})
                        Animation:Play()
                    else
                        Camera.CFrame = CFramenew(Camera.CFrame.Position, Aimbot.Locked.Character[Aimbot.Settings.LockPart].Position)
                    end
                    UserInputService.MouseDeltaSensitivity = 0
                end
                Aimbot.FOVCircle.Color = Aimbot.FOVSettings.LockedColor
            else
                CancelLock()
            end
        end
    end)

    -- Input Handling (supports dynamic TriggerKey)
    ServiceConnections.InputBeganConnection = UserInputService.InputBegan:Connect(function(Input)
        if Typing then return end
        local triggerName = Aimbot.Settings.TriggerKey
        local success, isTrigger = pcall(function()
            if Input.UserInputType == Enum.UserInputType.Keyboard then
                return Input.KeyCode.Name == triggerName
            else
                return Input.UserInputType.Name == triggerName
            end
        end)
        if success and isTrigger then
            if Aimbot.Settings.Toggle then
                Running = not Running
                if not Running then CancelLock() end
            else
                Running = true
            end
        end
    end)

    ServiceConnections.InputEndedConnection = UserInputService.InputEnded:Connect(function(Input)
        if Typing or Aimbot.Settings.Toggle then return end
        local triggerName = Aimbot.Settings.TriggerKey
        local success, isTrigger = pcall(function()
            if Input.UserInputType == Enum.UserInputType.Keyboard then
                return Input.KeyCode.Name == triggerName
            else
                return Input.UserInputType.Name == triggerName
            end
        end)
        if success and isTrigger then
            Running = false
            CancelLock()
        end
    end)
end


ServiceConnections.TypingStartedConnection = UserInputService.TextBoxFocused:Connect(function() Typing = true end)
ServiceConnections.TypingEndedConnection = UserInputService.TextBoxFocusReleased:Connect(function() Typing = false end)

--// Public Functions
Aimbot.Functions = {}

function Aimbot.Functions:Exit()
    for _, v in next, ServiceConnections do v:Disconnect() end
    Aimbot.FOVCircle:Remove()
    getgenv().Waddler.Aimbot = nil
end

function Aimbot.Functions:Restart()
    for _, v in next, ServiceConnections do v:Disconnect() end
    Load()
end

function Aimbot.Functions:ResetSettings()
   
end

setmetatable(Aimbot.Functions, {__newindex = warn})

--// Load the aimbot
Load()

