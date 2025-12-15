--// Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

--// State
local FlyEnabled = false
local FlySpeed = 70
local WalkSpeed = 16
local FlyKeybind = Enum.KeyCode.Z

local ActiveKeys = {}
local FlyVelocity = nil
local FlyConnection = nil

--// Helpers
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

--// Input Tracking
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	ActiveKeys[input.KeyCode] = true

	if input.KeyCode == FlyKeybind then
		FlyEnabled = not FlyEnabled
	end
end)

UserInputService.InputEnded:Connect(function(input)
	ActiveKeys[input.KeyCode] = false
end)

--// Fly Logic
local function EnableFly()
	local hrp = GetHRP()
	local hum = GetHumanoid()
	if not hrp or not hum then return end

	if not FlyVelocity then
		FlyVelocity = Instance.new("BodyVelocity")
		FlyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
		FlyVelocity.Velocity = Vector3.zero
		FlyVelocity.Parent = hrp
	end

	hum.PlatformStand = true

	FlyConnection = RunService.Heartbeat:Connect(function()
		local cam = workspace.CurrentCamera
		local moveDir = GetMoveDirection(true)

		if moveDir.Magnitude > 0 then
			FlyVelocity.Velocity = cam.CFrame:VectorToWorldSpace(moveDir) * FlySpeed
		else
			FlyVelocity.Velocity = Vector3.zero
		end
	end)
end

local function DisableFly()
	if FlyConnection then
		FlyConnection:Disconnect()
		FlyConnection = nil
	end

	if FlyVelocity then
		FlyVelocity:Destroy()
		FlyVelocity = nil
	end

	local hum = GetHumanoid()
	if hum then
		hum.PlatformStand = false
	end
end

--// Update Loop
RunService.RenderStepped:Connect(function()
	local hum = GetHumanoid()
	if hum then
		hum.WalkSpeed = WalkSpeed
	end

	if FlyEnabled and not FlyVelocity then
		EnableFly()
	elseif not FlyEnabled and FlyVelocity then
		DisableFly()
	end
end)
