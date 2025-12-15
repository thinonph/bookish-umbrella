-- Waddler Dev Visuals (safe, low-lag): Highlight + optional label
-- No Drawing API, no exploit-only mechanics.

--// Cache
local pcall, getgenv = pcall, getgenv
local mathfloor = math.floor

--// Launching checks
if not getgenv().Waddler or getgenv().Waddler.WallHack then return end

--// Services
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

--// Variables
local ServiceConnections = {}
local tracked = {}          -- [Model] = record
local freeHighlights = {}   -- pool
local freeGuis = {}         -- pool
local acc = 0

--// Helpers
local function getRoot(model)
	return model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
end

local function getHumanoid(model)
	return model:FindFirstChildOfClass("Humanoid")
end

local function isAlive(model)
	local hum = getHumanoid(model)
	return hum and hum.Health > 0
end

local function getDistance(model)
	local root = getRoot(model)
	local lpChar = LocalPlayer.Character
	local lpRoot = lpChar and getRoot(lpChar)
	if not root or not lpRoot then return math.huge end
	return (root.Position - lpRoot.Position).Magnitude
end

local function onScreen(worldPos)
	local v, ok = Camera:WorldToViewportPoint(worldPos)
	return ok and v.Z > 0
end

local function classify(model)
	local plr = Players:GetPlayerFromCharacter(model)
	if plr then return "Player", plr end
	if getHumanoid(model) then return "NPC", nil end
	return nil, nil
end

local function acquireHighlight()
	local h = table.remove(freeHighlights)
	if not h then h = Instance.new("Highlight") end
	return h
end

local function releaseHighlight(h)
	if not h then return end
	h.Adornee = nil
	h.Enabled = false
	h.Parent = nil
	table.insert(freeHighlights, h)
end

local function acquireBillboard(textSize)
	local gui = table.remove(freeGuis)
	if gui then return gui end

	gui = Instance.new("BillboardGui")
	gui.Name = "WaddlerDevLabel"
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Size = UDim2.fromOffset(220, 34)

	local tl = Instance.new("TextLabel")
	tl.Name = "Text"
	tl.BackgroundTransparency = 1
	tl.Size = UDim2.fromScale(1, 1)
	tl.Font = Enum.Font.GothamMedium
	tl.TextSize = textSize
	tl.TextColor3 = Color3.fromRGB(255, 255, 255)
	tl.TextStrokeTransparency = 0.6
	tl.TextXAlignment = Enum.TextXAlignment.Center
	tl.TextYAlignment = Enum.TextYAlignment.Center
	tl.Parent = gui

	return gui
end

local function releaseBillboard(gui)
	if not gui then return end
	gui.Adornee = nil
	gui.Enabled = false
	gui.Parent = nil
	table.insert(freeGuis, gui)
end

--// Environment
getgenv().Waddler.WallHack = {
	Settings = {
		Enabled = false,
		TeamCheck = false,
		AliveCheck = true,

		MaxDistance = 1500,
		UpdateHz = 12,
		DisableWhenOffscreen = true,

		ShowPlayers = true,
		ShowNPCs = true,
	},

	Visuals = {
		ChamsSettings = {
			Enabled = true,
			Color = Color3.fromRGB(255, 255, 255),
			Transparency = 0.75, -- FillTransparency
			OutlineTransparency = 1,
			DepthMode = Enum.HighlightDepthMode.Occluded,
		},

		LabelSettings = {
			Enabled = true,
			MaxDistance = 600,
			TextSize = 14,
			StudsOffset = Vector3.new(0, 3.2, 0),
			ShowHealth = true,
			ShowDistance = true,
		}
	}
}

local WH = getgenv().Waddler.WallHack

local function shouldTrack(model)
	if not WH.Settings.Enabled then return false end
	if not model or not model:IsA("Model") then return false end

	local kind, plr = classify(model)
	if not kind then return false end
	if kind == "Player" and not WH.Settings.ShowPlayers then return false end
	if kind == "NPC" and not WH.Settings.ShowNPCs then return false end

	if WH.Settings.TeamCheck and plr and plr.Team == LocalPlayer.Team then
		return false
	end

	if WH.Settings.AliveCheck and not isAlive(model) then
		return false
	end

	return true
end

local function untrack(model)
	local rec = tracked[model]
	if not rec then return end
	tracked[model] = nil

	for _, c in pairs(rec.Conn) do
		pcall(function() c:Disconnect() end)
	end

	releaseHighlight(rec.Highlight)
	releaseBillboard(rec.Label)
end

local function track(model)
	if tracked[model] then return end
	if not shouldTrack(model) then return end

	local kind, plr = classify(model)

	local rec = {
		Model = model,
		Kind = kind,
		Player = plr,
		Highlight = nil,
		Label = nil,
		Conn = {},
	}
	tracked[model] = rec

	-- Highlight (chams-like, engine accelerated)
	if WH.Visuals.ChamsSettings.Enabled then
		local h = acquireHighlight()
		h.FillColor = WH.Visuals.ChamsSettings.Color
		h.FillTransparency = WH.Visuals.ChamsSettings.Transparency
		h.OutlineTransparency = WH.Visuals.ChamsSettings.OutlineTransparency
		h.DepthMode = WH.Visuals.ChamsSettings.DepthMode
		h.Adornee = model
		h.Enabled = true
		h.Parent = model
		rec.Highlight = h
	end

	-- Label (name/health/distance)
	if WH.Visuals.LabelSettings.Enabled then
		local gui = acquireBillboard(WH.Visuals.LabelSettings.TextSize)
		gui.MaxDistance = WH.Visuals.LabelSettings.MaxDistance
		gui.StudsOffset = WH.Visuals.LabelSettings.StudsOffset
		gui.Enabled = true
		gui.Parent = model

		local root = getRoot(model)
		gui.Adornee = root or model
		rec.Label = gui
	end

	rec.Conn.Ancestry = model.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			untrack(model)
		end
	end)
end

local function rescan()
	-- players
	if WH.Settings.ShowPlayers then
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LocalPlayer and p.Character then
				track(p.Character)
			end
		end
	end

	-- NPCs (one-time scan; new ones handled by DescendantAdded)
	if WH.Settings.ShowNPCs then
		for _, d in ipairs(workspace:GetDescendants()) do
			if d:IsA("Model") then
				local kind = classify(d)
				if kind == "NPC" then
					track(d)
				end
			end
		end
	end
end

-- Player lifecycle (event-driven)
ServiceConnections.PlayerAdded = Players.PlayerAdded:Connect(function(p)
	if p == LocalPlayer then return end
	ServiceConnections["Char_" .. p.UserId] = p.CharacterAdded:Connect(function(char)
		track(char)
	end)
end)

for _, p in ipairs(Players:GetPlayers()) do
	if p ~= LocalPlayer then
		ServiceConnections["Char_" .. p.UserId] = p.CharacterAdded:Connect(function(char)
			track(char)
		end)
	end
end

-- NPC lifecycle (event-driven)
ServiceConnections.DescendantAdded = workspace.DescendantAdded:Connect(function(d)
	if not WH.Settings.Enabled then return end
	if not WH.Settings.ShowNPCs then return end
	if d:IsA("Model") then
		local kind = classify(d)
		if kind == "NPC" then
			track(d)
		end
	end
end)

-- Throttled updater (labels + gating)
ServiceConnections.Heartbeat = RunService.Heartbeat:Connect(function(dt)
	if not WH.Settings.Enabled then
		-- If disabled, tear down visuals
		for model in pairs(tracked) do
			untrack(model)
		end
		return
	end

	acc += dt
	local interval = 1 / math.max(1, WH.Settings.UpdateHz)
	if acc < interval then return end
	acc = 0

	for model, rec in pairs(tracked) do
		if not model.Parent then
			untrack(model)
		else
			-- enforce AliveCheck without heavy loops
			if WH.Settings.AliveCheck and not isAlive(model) then
				untrack(model)
				continue
			end

			local root = getRoot(model)
			local dist = root and getDistance(model) or math.huge
			local within = dist <= WH.Settings.MaxDistance

			if rec.Highlight then
				rec.Highlight.Enabled = within and WH.Visuals.ChamsSettings.Enabled
			end

			if rec.Label then
				local labelOk = within and WH.Visuals.LabelSettings.Enabled and dist <= WH.Visuals.LabelSettings.MaxDistance
				if labelOk and WH.Settings.DisableWhenOffscreen and root then
					labelOk = onScreen(root.Position)
				end
				rec.Label.Enabled = labelOk

				if labelOk then
					local hum = getHumanoid(model)
					local hp = hum and mathfloor(hum.Health) or 0
					local mhp = hum and mathfloor(hum.MaxHealth) or 0

					local name = rec.Player and rec.Player.Name or model.Name
					local parts = { name }

					if WH.Visuals.LabelSettings.ShowDistance then
						parts[#parts+1] = ("[%dm]"):format(mathfloor(dist))
					end

					if WH.Visuals.LabelSettings.ShowHealth and mhp > 0 then
						parts[#parts+1] = ("%d/%d"):format(hp, mhp)
					end

					local tl = rec.Label:FindFirstChild("Text", true)
					if tl and tl:IsA("TextLabel") then
						tl.Text = table.concat(parts, "  ")
					end

					if root then
						rec.Label.Adornee = root
					end
				end
			end
		end
	end
end)

-- Optional initial scan when enabled later:
-- call rescan() yourself after setting Enabled = true.
WH.Rescan = rescan
WH.Track = track
WH.Untrack = untrack

