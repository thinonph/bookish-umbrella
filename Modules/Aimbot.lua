local pcall, getgenv, next, setmetatable, Vector2new, CFramenew, Color3fromRGB, Drawingnew, TweenInfonew, stringupper, mousemoverel = pcall, getgenv, next, setmetatable, Vector2.new, CFrame.new, Color3.fromRGB, Drawing.new, TweenInfo.new, string.upper, mousemoverel or (Input and Input.MouseMove)
--// Launching checks
if not getgenv().AirHub or getgenv().AirHub.Aimbot then return end
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
getgenv().AirHub.Aimbot = {
    Settings = {
        Enabled = true,
        TeamCheck = false,
        AliveCheck = true,
        WallCheck = false,
        Sensitivity = 0, -- Animation length (in seconds) before fully locking onto target
        ThirdPerson = false,
        ThirdPersonSensitivity = 3,
        TriggerKey = "MouseButton2",
        Toggle = false,
        LockPart = "Head",
        LockMode = "Closest" -- "Closest" or "Manual"
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
    Locked = nil, -- Current locked player (or manual target)
    ManualTarget = nil -- For manual selection
}
local Environment = getgenv().AirHub.Aimbot

--// Simple GUI for player list and controls using Drawing API
local Gui = {
    Background = Drawingnew("Square"),
    Title = Drawingnew("Text"),
    PlayerTexts = {}, -- Table of player name texts
    SelectedIndex = nil
}

Gui.Background.Size = Vector2new(200, 300)
Gui.Background.Position = Vector2new(10, 10)
Gui.Background.Color = Color3fromRGB(30, 30, 30)
Gui.Background.Transparency = 0.8
Gui.Background.Filled = true
Gui.Background.Visible = true

Gui.Title.Text = "AirHub Aimbot - Players"
Gui.Title.Size = 16
Gui.Title.Color = Color3fromRGB(255, 255, 255)
Gui.Title.Position = Vector2new(20, 15)
Gui.Title.Visible = true

local function UpdatePlayerList()
    -- Clear old texts
    for _, txt in ipairs(Gui.PlayerTexts) do
        txt:Remove()
    end
    Gui.PlayerTexts = {}

    local yOffset = 40
    local index = 1
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local txt = Drawingnew("Text")
            txt.Text = (Environment.ManualTarget == plr and "[SELECTED] " or "") .. plr.Name
            txt.Size = 14
            txt.Color = (Environment.ManualTarget == plr and Color3fromRGB(0, 255, 0) or Color3fromRGB(200, 200, 200))
            txt.Position = Vector2new(20, yOffset)
            txt.Visible = true
            table.insert(Gui.PlayerTexts, txt)

            yOffset = yOffset + 20
            index = index + 1
        end
    end
end

-- Toggle GUI visibility with a key (e.g., Insert)
UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.Insert then
        Gui.Background.Visible = not Gui.Background.Visible
        Gui.Title.Visible = Gui.Background.Visible
        for _, txt in ipairs(Gui.PlayerTexts) do
            txt.Visible = Gui.Background.Visible
        end
        if Gui.Background.Visible then UpdatePlayerList() end
    end
end)

-- Player selection via mouse click on list (approximate)
RunService.RenderStepped:Connect(function()
    if Gui.Background.Visible then
        local mousePos = UserInputService:GetMouseLocation()
        if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
            if mousePos.X >= Gui.Background.Position.X and mousePos.X <= Gui.Background.Position.X + Gui.Background.Size.X and
               mousePos.Y >= Gui.Background.Position.Y + 40 and mousePos.Y <= Gui.Background.Position.Y + Gui.Background.Size.Y then
                local clickedY = mousePos.Y - (Gui.Background.Position.Y + 40)
                local index = math.floor(clickedY / 20) + 1
                local playersList = {}
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= LocalPlayer then table.insert(playersList, plr) end
                end
                if playersList[index] then
                    Environment.ManualTarget = playersList[index]
                    Environment.Settings.LockMode = "Manual"
                    UpdatePlayerList()
                end
            end
        end
    end
end)

-- Update list on player added/removed
Players.PlayerAdded:Connect(UpdatePlayerList)
Players.PlayerRemoving:Connect(UpdatePlayerList)

--// Core Functions (unchanged mostly)
local function ConvertVector(Vector)
    return Vector2new(Vector.X, Vector.Y)
end

local function CancelLock()
    Environment.Locked = nil
    Environment.FOVCircle.Color = Environment.FOVSettings.Color
    UserInputService.MouseDeltaSensitivity = OriginalSensitivity
    if Animation then Animation:Cancel() end
end

local function GetClosestPlayer()
    if not Environment.Locked then
        RequiredDistance = (Environment.FOVSettings.Enabled and Environment.FOVSettings.Amount or 2000)
        local closestPlr = nil
        for _, v in next, Players:GetPlayers() do
            if v ~= LocalPlayer and v.Character and v.Character:FindFirstChild(Environment.Settings.LockPart) and v.Character:FindFirstChildOfClass("Humanoid") then
                if Environment.Settings.TeamCheck and v.TeamColor == LocalPlayer.TeamColor then continue end
                if Environment.Settings.AliveCheck and v.Character:FindFirstChildOfClass("Humanoid").Health <= 0 then continue end
                if Environment.Settings.WallCheck and #Camera:GetPartsObscuringTarget({v.Character[Environment.Settings.LockPart].Position}, v.Character:GetDescendants()) > 0 then continue end
                local Vector, OnScreen = Camera:WorldToViewportPoint(v.Character[Environment.Settings.LockPart].Position)
                Vector = ConvertVector(Vector)
                local Distance = (UserInputService:GetMouseLocation() - Vector).Magnitude
                if Distance < RequiredDistance and OnScreen then
                    RequiredDistance = Distance
                    closestPlr = v
                end
            end
        end
        Environment.Locked = closestPlr
    elseif Environment.Locked and Environment.Locked.Character and Environment.Locked.Character:FindFirstChild(Environment.Settings.LockPart) then
        local Vector = ConvertVector(Camera:WorldToViewportPoint(Environment.Locked.Character[Environment.Settings.LockPart].Position))
        if (UserInputService:GetMouseLocation() - Vector).Magnitude > RequiredDistance then
            CancelLock()
        end
    else
        CancelLock()
    end
end

local function GetTarget()
    if Environment.Settings.LockMode == "Manual" then
        return Environment.ManualTarget
    else
        return Environment.Locked
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
            if Environment.Settings.LockMode == "Closest" then
                GetClosestPlayer()
            end
            local target = GetTarget()
            if target and target.Character and target.Character:FindFirstChild(Environment.Settings.LockPart) then
                if Environment.Settings.ThirdPerson then
                    local Vector = Camera:WorldToViewportPoint(target.Character[Environment.Settings.LockPart].Position)
                    mousemoverel((Vector.X - UserInputService:GetMouseLocation().X) * Environment.Settings.ThirdPersonSensitivity, (Vector.Y - UserInputService:GetMouseLocation().Y) * Environment.Settings.ThirdPersonSensitivity)
                else
                    if Environment.Settings.Sensitivity > 0 then
                        Animation = TweenService:Create(Camera, TweenInfonew(Environment.Settings.Sensitivity, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {CFrame = CFramenew(Camera.CFrame.Position, target.Character[Environment.Settings.LockPart].Position)})
                        Animation:Play()
                    else
                        Camera.CFrame = CFramenew(Camera.CFrame.Position, target.Character[Environment.Settings.LockPart].Position)
                    end
                    UserInputService.MouseDeltaSensitivity = 0
                end
                Environment.FOVCircle.Color = Environment.FOVSettings.LockedColor
            else
                CancelLock()
            end
        end
    end)

    -- Input handling remains the same
    ServiceConnections.InputBeganConnection = UserInputService.InputBegan:Connect(function(Input)
        if not Typing then
            pcall(function()
                if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode == Enum.KeyCode[stringupper(Environment.Settings.TriggerKey)] or Input.UserInputType == Enum.UserInputType[Environment.Settings.TriggerKey] then
                    if Environment.Settings.Toggle then
                        Running = not Running
                        if not Running then CancelLock() end
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
                if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode == Enum.KeyCode[stringupper(Environment.Settings.TriggerKey)] or Input.UserInputType == Enum.UserInputType[Environment.Settings.TriggerKey] then
                    Running = false
                    CancelLock()
                end
            end)
        end
    end)
end

--// Typing Check (unchanged)
ServiceConnections.TypingStartedConnection = UserInputService.TextBoxFocused:Connect(function() Typing = true end)
ServiceConnections.TypingEndedConnection = UserInputService.TextBoxFocusReleased:Connect(function() Typing = false end)

--// Functions (added mode switch example)
Environment.Functions = {}
function Environment.Functions:Exit()
    for _, v in next, ServiceConnections do v:Disconnect() end
    Environment.FOVCircle:Remove()
    Gui.Background:Remove()
    Gui.Title:Remove()
    for _, txt in ipairs(Gui.PlayerTexts) do txt:Remove() end
    getgenv().AirHub.Aimbot = nil
end

function Environment.Functions:Restart()
    for _, v in next, ServiceConnections do v:Disconnect() end
    Load()
end

-- Example to switch to closest mode
function Environment.Functions:SetClosestMode()
    Environment.Settings.LockMode = "Closest"
    Environment.ManualTarget = nil
    UpdatePlayerList()
end

setmetatable(Environment.Functions, {__newindex = warn})

--// Load
Load()
UpdatePlayerList() -- Initial list
