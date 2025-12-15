--// Cache

local pcall, getgenv, next, setmetatable = pcall, getgenv, next, setmetatable

--// Launching checks

if not getgenv().AirHub or getgenv().AirHub.Movement then return end

--// Services

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

--// Variables

local ServiceConnections, ActiveKeys, BodyVelocity = {}, {}, nil

--// Environment

getgenv().AirHub.Movement = {
	Settings = {
		WalkSpeed = 16,

		FlyEnabled = false,
		FlySpeed = 70,
		FlyKeybind = Enum.KeyCode.Z
	}
}

local Environment = getgenv().AirHub.Movement

--// Core Functions

local function GetCharacter()
	return LocalPlayer.Character
end

local function GetHumanoid()
	local char = GetCharacter()
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function GetHRP()
	local char = GetCharacter()
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function GetMoveDirection(includeY)
	local dir = Vector3.zero

	if ActiveKeys[Enum.KeyCode.W] then dir += Vector3.new(0, 0, -1) end
	if ActiveKeys[Enum.KeyCode.S] then dir += Vector3.new(0, 0,  1) end
	if ActiveKeys[Enum.KeyCode.A] then dir += Vector3.new(-1, 0, 0) end
	if ActiveKeys[Enum.KeyCode.D] then dir += Vector3.new( 1, 0, 0) end

	if includeY then
		if ActiveKeys[Enum.KeyCode.Space] then dir += Vector3.new(0, 1, 0) end
		if ActiveKeys[Enum.KeyCode.LeftShift] then dir += Vector3.new(0, -1, 0) end
	end

	return dir.Magnitude > 0 and dir.Unit or Vector3.zero
end

local function EnableFly()
	local hrp = GetHRP()
	local hum = GetHumanoid()
	if not hrp or not hum then return end

	if not BodyVelocity then
		BodyVelocity = Instance.new("BodyVelocity")
		BodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
		BodyVelocity.Velocity = Vector3.zero
		BodyVelocity.Parent = hrp
	end

	hum.PlatformStand = true
end

local function DisableFly()
	if BodyVelocity then
		BodyVelocity:Destroy()
		BodyVelocity = nil
	end

	local hum = GetHumanoid()
	if hum then
		hum.PlatformStand = false
	end
end

local function Load()
	ServiceConnections.RenderSteppedConnection = RunService.RenderStepped:Connect(function()
		local hum = GetHumanoid()
		if hum then
			hum.WalkSpeed = Environment.Settings.WalkSpeed
		end

		if Environment.Settings.FlyEnabled then
			if not BodyVelocity then
				EnableFly()
			end

			local hrp = GetHRP()
			if hrp and BodyVelocity then
				local moveDir = GetMoveDirection(true)
				if moveDir.Magnitude > 0 then
					BodyVelocity.Velocity = Camera.CFrame:VectorToWorldSpace(moveDir) * Environment.Settings.FlySpeed
				else
					BodyVelocity.Velocity = Vector3.zero
				end
			end
		else
			if BodyVelocity then
				DisableFly()
			end
		end
	end)

	ServiceConnections.InputBeganConnection = UserInputService.InputBegan:Connect(function(Input, gp)
		if gp then return end
		if Input.UserInputType == Enum.UserInputType.Keyboard then
			ActiveKeys[Input.KeyCode] = true

			if Input.KeyCode == Environment.Settings.FlyKeybind then
				Environment.Settings.FlyEnabled = not Environment.Settings.FlyEnabled
			end
		end
	end)

	ServiceConnections.InputEndedConnection = UserInputService.InputEnded:Connect(function(Input)
		if Input.UserInputType == Enum.UserInputType.Keyboard then
			ActiveKeys[Input.KeyCode] = false
		end
	end)

	ServiceConnections.CharacterAddedConnection = LocalPlayer.CharacterAdded:Connect(function()
		DisableFly()
	end)
end

--// Functions

Environment.Functions = {}

function Environment.Functions:Exit()
	for _, v in next, ServiceConnections do
		pcall(function()
			v:Disconnect()
		end)
	end

	DisableFly()

	Environment.Functions = nil
	getgenv().AirHub.Movement = nil

	Load = nil; GetCharacter = nil; GetHumanoid = nil; GetHRP = nil; GetMoveDirection = nil
end

function Environment.Functions:Restart()
	for _, v in next, ServiceConnections do
		pcall(function()
			v:Disconnect()
		end)
	end

	DisableFly()
	ServiceConnections = {}
	ActiveKeys = {}

	Load()
end

function Environment.Functions:ResetSettings()
	Environment.Settings = {
		WalkSpeed = 16,

		FlyEnabled = false,
		FlySpeed = 70,
		FlyKeybind = Enum.KeyCode.Z
	}
end

setmetatable(Environment.Functions, {
	__newindex = warn
})

--// Load

Load()
