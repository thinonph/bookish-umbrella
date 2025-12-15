--// Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

--// Ensure AirHub exists
getgenv().AirHub = getgenv().AirHub or {}

--// Public Movement State (UI reads this)
getgenv().AirHub.Movement = {
	WalkSpeed = 16,
	FlyEnabled = false,
	FlySpeed = 70,
	FlyKeybind = Enum.KeyCode.Z
}

local Movement = getgenv().AirHub.Movement

--// Internal State
local ActiveKeys = {}
local BodyVelocity = nil
local FlyConnection = nil
local InputBeganConn, InputEndedConn = nil, nil

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

--// Fly Control
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

	FlyConnection = RunService.Heartbeat:Connect(function()
		local cam = workspace.CurrentCamera
		local moveDir = GetMoveDirection(true)

		if moveDir.Magnitude > 0 then
			BodyVelocity.Velocity = cam.CFrame:VectorToWorldSpace(moveDir) * Movement.FlySpeed
		else
			BodyVelocity.Velocity = Vector3.zero
		end
	end)
end

local function DisableFly()
	if FlyConnection then
		FlyConnection:Disconnect()
		FlyConnection = nil
	end

	if BodyVelocity then
		BodyVelocity:Destroy()
		BodyVelocity = nil
	end

	local hum = GetHumanoid()
	if hum then
		hum.PlatformStand = false
	end
end

--// Input Handling
InputBeganConn = UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	ActiveKeys[input.KeyCode] = true

	if input.KeyCode == Movement.FlyKeybind then
		Movement.FlyEnabled = not Movement.FlyEnabled
	end
end)

InputEndedConn = UserInputService.InputEnded:Connect(function(input)
	ActiveKeys[input.KeyCode] = false
end)

--// Main Update Loop
RunService.RenderStepped:Connect(function()
	local hum = GetHumanoid()
	if hum then
		hum.WalkSpeed = Movement.WalkSpeed
	end

	if Movement.FlyEnabled then
		if not BodyVelocity then
			EnableFly()
		end
	else
		if BodyVelocity then
			DisableFly()
		end
	end
end)

--// Character Safety
LocalPlayer.CharacterAdded:Connect(function()
	task.wait(0.5)
	DisableFly()
end)

--// Public Functions (for unload / restart)
getgenv().AirHub.Movement.Functions = {}

function getgenv().AirHub.Movement.Functions:Exit()
	DisableFly()

	if InputBeganConn then
		InputBeganConn:Disconnect()
		InputBeganConn = nil
	end

	if InputEndedConn then
		InputEndedConn:Disconnect()
		InputEndedConn = nil
	end

	ActiveKeys = {}
end
