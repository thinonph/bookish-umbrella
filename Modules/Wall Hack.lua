--// Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer

--// Shortcuts
local Drawingnew = Drawing.new
local Vector2new = Vector2.new
local CFramenew = CFrame.new
local mathfloor = math.floor
local Vector3zero = Vector3.zero

--// Environment
local Environment = {
	Settings = {
		Enabled = true,
		TeamCheck = false,
		AliveCheck = true
	},
	Visuals = {
		ChamsSettings = {
			Enabled = true,
			EntireBody = true,
			Color = Color3.fromRGB(170, 0, 255),
			Transparency = 0.35,
			Thickness = 1,
			Filled = true
		},
		ESPSettings = {
			Enabled = true,
			TextSize = 13,
			TextFont = 2,
			TextColor = Color3.fromRGB(255, 255, 255),
			TextTransparency = 1,
			Outline = true,
			OutlineColor = Color3.fromRGB(0, 0, 0),
			DisplayName = true,
			DisplayHealth = true,
			DisplayDistance = true
		}
	}
}

--// Utilities
local function WorldToViewportPoint(pos)
	local v, onScreen = Camera:WorldToViewportPoint(pos)
	return v, onScreen
end

--// Player Cache
local PlayerCache = {}

local function GetPlayerTable(Player)
	if not PlayerCache[Player] then
		PlayerCache[Player] = {
			RigType = nil,
			Checks = { Alive = false, Team = false },
			Connections = {},
			Chams = {},
			ESP = nil
		}
	end
	return PlayerCache[Player]
end

--// Rig Detection
local function AssignRigType(Player)
	local PT = GetPlayerTable(Player)
	local Char = Player.Character
	if not Char then return end

	if Char:FindFirstChild("Torso") then
		PT.RigType = "R6"
	elseif Char:FindFirstChild("LowerTorso") then
		PT.RigType = "R15"
	end
end

--// Checks
local function InitChecks(Player)
	local PT = GetPlayerTable(Player)

	PT.Connections.Checks = RunService.RenderStepped:Connect(function()
		local Char = Player.Character
		local Hum = Char and Char:FindFirstChildOfClass("Humanoid")

		if Hum then
			PT.Checks.Alive = not Environment.Settings.AliveCheck or Hum.Health > 0
			PT.Checks.Team = not Environment.Settings.TeamCheck or Player.TeamColor ~= LocalPlayer.TeamColor
		else
			PT.Checks.Alive = false
			PT.Checks.Team = false
		end
	end)
end

--// Cham Utilities
local function CreateCham()
	local T = {}
	for i = 1, 6 do
		T["Quad"..i] = Drawingnew("Quad")
	end
	return T
end

local function UpdateCham(Part, Cham)
	local CF = Part.CFrame
	local S = Part.Size / 2
	local V = Environment.Visuals.ChamsSettings

	local _, onScreen = WorldToViewportPoint(CF.Position)
	if not onScreen or not V.Enabled then
		for i = 1, 6 do
			Cham["Quad"..i].Visible = false
		end
		return
	end

	local function Apply(Q)
		Q.Visible = true
		Q.Color = V.Color
		Q.Transparency = V.Transparency
		Q.Thickness = V.Thickness
		Q.Filled = V.Filled
	end

	local function P(x,y,z)
		local v = WorldToViewportPoint((CF * CFramenew(x,y,z)).Position)
		return Vector2new(v.X, v.Y)
	end

	-- Front
	Apply(Cham.Quad1)
	Cham.Quad1.PointA = P( S.X,  S.Y,  S.Z)
	Cham.Quad1.PointB = P( S.X, -S.Y,  S.Z)
	Cham.Quad1.PointC = P(-S.X, -S.Y,  S.Z)
	Cham.Quad1.PointD = P(-S.X,  S.Y,  S.Z)

	-- Back
	Apply(Cham.Quad2)
	Cham.Quad2.PointA = P( S.X,  S.Y, -S.Z)
	Cham.Quad2.PointB = P( S.X, -S.Y, -S.Z)
	Cham.Quad2.PointC = P(-S.X, -S.Y, -S.Z)
	Cham.Quad2.PointD = P(-S.X,  S.Y, -S.Z)

	-- Top
	Apply(Cham.Quad3)
	Cham.Quad3.PointA = P( S.X,  S.Y,  S.Z)
	Cham.Quad3.PointB = P( S.X,  S.Y, -S.Z)
	Cham.Quad3.PointC = P(-S.X,  S.Y, -S.Z)
	Cham.Quad3.PointD = P(-S.X,  S.Y,  S.Z)

	-- Bottom
	Apply(Cham.Quad4)
	Cham.Quad4.PointA = P( S.X, -S.Y,  S.Z)
	Cham.Quad4.PointB = P( S.X, -S.Y, -S.Z)
	Cham.Quad4.PointC = P(-S.X, -S.Y, -S.Z)
	Cham.Quad4.PointD = P(-S.X, -S.Y,  S.Z)

	-- Left
	Apply(Cham.Quad5)
	Cham.Quad5.PointA = P( S.X,  S.Y,  S.Z)
	Cham.Quad5.PointB = P( S.X, -S.Y,  S.Z)
	Cham.Quad5.PointC = P( S.X, -S.Y, -S.Z)
	Cham.Quad5.PointD = P( S.X,  S.Y, -S.Z)

	-- Right
	Apply(Cham.Quad6)
	Cham.Quad6.PointA = P(-S.X,  S.Y,  S.Z)
	Cham.Quad6.PointB = P(-S.X, -S.Y,  S.Z)
	Cham.Quad6.PointC = P(-S.X, -S.Y, -S.Z)
	Cham.Quad6.PointD = P(-S.X,  S.Y, -S.Z)
end

--// Add Chams
local function AddChams(Player)
	local PT = GetPlayerTable(Player)

	local function UpdateRig()
		PT.Chams = {}

		if PT.RigType == "R6" then
			PT.Chams = {
				Head = {},
				Torso = {},
				["Left Arm"] = {},
				["Right Arm"] = {},
				["Left Leg"] = {},
				["Right Leg"] = {}
			}
		else
			PT.Chams = {
				Head = {},
				UpperTorso = {},
				LowerTorso = {},
				LeftUpperArm = {},
				LeftLowerArm = {},
				RightUpperArm = {},
				RightLowerArm = {},
				LeftUpperLeg = {},
				LeftLowerLeg = {},
				RightUpperLeg = {},
				RightLowerLeg = {}
			}
		end

		for _, v in next, PT.Chams do
			for i = 1, 6 do
				v["Quad"..i] = Drawingnew("Quad")
			end
		end
	end

	UpdateRig()
	local OldEntireBody = Environment.Visuals.ChamsSettings.EntireBody

	PT.Connections.Chams = RunService.RenderStepped:Connect(function()
		for PartName, Cham in next, PT.Chams do
			local Part = Player.Character and Player.Character:FindFirstChild(PartName)
			if Part then
				UpdateCham(Part, Cham)
			end
		end

		if Environment.Visuals.ChamsSettings.Enabled then
			if Environment.Visuals.ChamsSettings.EntireBody ~= OldEntireBody then
				UpdateRig()
				OldEntireBody = Environment.Visuals.ChamsSettings.EntireBody
			end
		end
	end)
end

--// Add ESP
local function AddESP(Player)
	local PT = GetPlayerTable(Player)
	PT.ESP = Drawingnew("Text")

	PT.Connections.ESP = RunService.RenderStepped:Connect(function()
		if not Environment.Settings.Enabled then
			PT.ESP.Visible = false
			return
		end

		local Char = Player.Character
		local Hum = Char and Char:FindFirstChildOfClass("Humanoid")
		local Root = Char and Char:FindFirstChild("HumanoidRootPart")
		local Head = Char and Char:FindFirstChild("Head")

		if not (Hum and Root and Head) then
			PT.ESP.Visible = false
			return
		end

		local Vec, OnScreen = WorldToViewportPoint(Head.Position)
		PT.ESP.Visible = OnScreen and PT.Checks.Alive and PT.Checks.Team

		if PT.ESP.Visible then
			PT.ESP.Position = Vector2new(Vec.X, Vec.Y - 15)
			PT.ESP.Center = true
			PT.ESP.Size = Environment.Visuals.ESPSettings.TextSize
			PT.ESP.Font = Environment.Visuals.ESPSettings.TextFont
			PT.ESP.Color = Environment.Visuals.ESPSettings.TextColor
			PT.ESP.Transparency = Environment.Visuals.ESPSettings.TextTransparency
			PT.ESP.Outline = Environment.Visuals.ESPSettings.Outline
			PT.ESP.OutlineColor = Environment.Visuals.ESPSettings.OutlineColor

			local Tool = Char:FindFirstChildOfClass("Tool")

			local Content = ""
			if Environment.Visuals.ESPSettings.DisplayName then
				Content = Player.DisplayName == Player.Name and Player.Name or Player.DisplayName.." {"..Player.Name.."}"
			end

			if Environment.Visuals.ESPSettings.DisplayHealth then
				Content = "("..mathfloor(Hum.Health)..") "..Content
			end

			if Environment.Visuals.ESPSettings.DisplayDistance then
				local Dist = (Root.Position - (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character.HumanoidRootPart.Position or Vector3zero)).Magnitude
				Content = Content.." ["..mathfloor(Dist).."]"
			end

			PT.ESP.Text = (Tool and "["..Tool.Name.."]\n" or "")..Content
		end
	end)
end

--// Init Player
local function InitPlayer(Player)
	AssignRigType(Player)
	InitChecks(Player)
	AddChams(Player)
	AddESP(Player)

	Player.CharacterAdded:Connect(function()
		repeat task.wait() until Player.Character
		AssignRigType(Player)
	end)
end

for _, P in next, Players:GetPlayers() do
	if P ~= LocalPlayer then
		InitPlayer(P)
	end
end

Players.PlayerAdded:Connect(function(P)
	if P ~= LocalPlayer then
		InitPlayer(P)
	end
end)

