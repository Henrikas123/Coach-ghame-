-- ModuleScript: ReplicatedStorage/Modules/FighterAppearance
-- Every fighter gets a unique 3D look generated from their name: skin tone, shorts with trim,
-- gloves, boots, headband and hair. The same name always gives the same fighter.
--
-- The body is ReplicatedStorage.FighterRig: a plain R15 character built on the server by
-- ServerScriptService/FighterRigBuilder. To use a nicer body, put your own R15 rig named
-- "FighterRig" into ReplicatedStorage in Studio; the builder then leaves it alone.
--
-- The client clones the rig, puts it into a pose (joint maths, no physics), removes joints,
-- Humanoid and scripts, dresses it and shows it inside a ViewportFrame.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local FighterAppearance = {}

FighterAppearance.RigName = "FighterRig"

-- Optional face texture for every fighter ("rbxassetid://..."). Empty keeps the rig's own face.
FighterAppearance.FaceTexture = ""

local rgb = Color3.fromRGB

local SKIN = {
	rgb(255, 219, 178), rgb(240, 196, 150), rgb(224, 172, 118), rgb(198, 140, 92),
	rgb(164, 108, 70), rgb(128, 82, 52), rgb(96, 62, 40),
}
local SHORTS = {
	rgb(176, 28, 44), rgb(32, 72, 176), rgb(214, 168, 52), rgb(26, 26, 30), rgb(236, 236, 240),
	rgb(22, 128, 80), rgb(108, 50, 156), rgb(226, 112, 30), rgb(20, 138, 150), rgb(206, 72, 132),
}
local TRIM = { rgb(245, 245, 245), rgb(232, 190, 70), rgb(20, 20, 24), rgb(190, 196, 206) }
local GLOVES = {
	rgb(200, 24, 36), rgb(28, 70, 196), rgb(24, 24, 28), rgb(222, 176, 52), rgb(240, 240, 242), rgb(24, 140, 70),
}
local BOOTS = { rgb(22, 22, 26), rgb(240, 240, 242), rgb(170, 26, 38), rgb(28, 44, 110) }
local HEADBANDS = { rgb(200, 24, 36), rgb(240, 240, 242), rgb(24, 24, 28), rgb(222, 176, 52), rgb(28, 70, 196) }
local HAIR_COLORS = {
	rgb(24, 20, 18), rgb(24, 20, 18), rgb(58, 38, 24), rgb(108, 68, 38), rgb(206, 170, 96), rgb(140, 56, 28),
}
local HAIR_STYLES = { "bald", "buzz", "buzz", "short", "short", "mohawk", "bun", "afro" }

-- ============================================================
-- LOOK (deterministic from the name)
-- ============================================================
-- FNV-1a, 32 bit; the multiply is split so it stays exact in doubles
function FighterAppearance.hash(text)
	local h = 2166136261
	for i = 1, #text do
		h = bit32.bxor(h, string.byte(text, i))
		h = (bit32.lshift(h, 24) + h * 403) % 4294967296
	end
	return h
end

function FighterAppearance.look(name)
	name = tostring(name or "?")
	local function roll(salt)
		return FighterAppearance.hash(name .. "|" .. salt)
	end
	local function pick(list, salt)
		return list[roll(salt) % #list + 1]
	end
	local hair = pick(HAIR_STYLES, "hair")
	return {
		skin = pick(SKIN, "skin"),
		shorts = pick(SHORTS, "shorts"),
		trim = pick(TRIM, "trim"),
		gloves = pick(GLOVES, "gloves"),
		boots = pick(BOOTS, "boots"),
		headband = (roll("band") % 100 < 55) and pick(HEADBANDS, "bandc") or nil,
		hair = hair,
		hairColor = pick(HAIR_COLORS, "hairc"),
		southpaw = roll("stance") % 5 == 0,
	}
end

-- ============================================================
-- POSES (angles in radians, in the parent part's axes: X pitch, Y yaw, Z roll; the rig faces -Z)
-- ============================================================
local POSES = {
	guard = {
		Root = { 0, -0.38, 0 },
		Waist = { -0.1, -0.08, 0 },
		Neck = { -0.1, 0.3, 0 },
		LeftShoulder = { 0.9, 0.3, 0.05 },
		LeftElbow = { 1.4, 0, 0 },
		RightShoulder = { 0.5, 0.35, -0.3 },
		RightElbow = { 2.05, 0, 0 },
		LeftHip = { 0.28, 0.12, -0.1 },
		LeftKnee = { -0.38, 0, 0 },
		LeftAnkle = { 0.1, 0, 0 },
		RightHip = { -0.22, 0.25, 0.12 },
		RightKnee = { -0.15, 0, 0 },
		RightAnkle = { 0.2, 0, 0 },
	},
	victory = {
		Waist = { 0.1, 0, 0 },
		Neck = { 0.22, 0, 0 },
		LeftShoulder = { 0.15, 0, -2.55 },
		LeftElbow = { 0.45, 0, 0 },
		RightShoulder = { 0.15, 0, 2.55 },
		RightElbow = { 0.45, 0, 0 },
		LeftHip = { 0, 0, -0.12 },
		RightHip = { 0, 0, 0.12 },
	},
}

-- southpaw = the pose mirrored left/right
local function mirrorPose(pose)
	local out = {}
	for jointName, angles in pairs(pose) do
		local target = jointName
		if string.sub(jointName, 1, 4) == "Left" then
			target = "Right" .. string.sub(jointName, 5)
		elseif string.sub(jointName, 1, 5) == "Right" then
			target = "Left" .. string.sub(jointName, 6)
		end
		out[target] = { angles[1], -angles[2], -angles[3] }
	end
	return out
end

-- ============================================================
-- RIG -> POSED STATUE
-- ============================================================
local function rotationOnly(cf)
	return cf - cf.Position
end

local function applyPose(model, pose)
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if not root then
		return false
	end
	local joints, welds = {}, {}
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("JointInstance") and item.Part0 and item.Part1 then
			table.insert(joints, item)
		elseif item:IsA("WeldConstraint") and item.Part0 and item.Part1 then
			table.insert(welds, item)
		end
	end
	local placed = { [root] = root.CFrame }
	local progress = true
	while progress do
		progress = false
		for _, joint in ipairs(joints) do
			local part0, part1 = joint.Part0, joint.Part1
			if placed[part0] and not placed[part1] then
				local turn = CFrame.new()
				local angles = pose[joint.Name]
				if angles then
					local axes = rotationOnly(joint.C0)
					turn = axes:Inverse() * CFrame.fromEulerAnglesYXZ(angles[1], angles[2], angles[3]) * axes
				end
				placed[part1] = placed[part0] * joint.C0 * turn * joint.C1:Inverse()
				progress = true
			elseif placed[part1] and not placed[part0] then
				placed[part0] = placed[part1] * joint.C1 * joint.C0:Inverse()
				progress = true
			end
		end
		for _, weld in ipairs(welds) do
			local part0, part1 = weld.Part0, weld.Part1
			if placed[part0] and not placed[part1] then
				placed[part1] = placed[part0] * part0.CFrame:ToObjectSpace(part1.CFrame)
				progress = true
			end
		end
	end
	for part, cf in pairs(placed) do
		part.CFrame = cf
	end
	return true
end

local STRIP = { "LuaSourceContainer", "JointInstance", "WeldConstraint", "Humanoid", "BodyColors", "Clothing", "ShirtGraphic", "Sound", "ForceField" }

local function strip(model)
	for _, item in ipairs(model:GetDescendants()) do
		if item.Parent then
			for _, className in ipairs(STRIP) do
				if item:IsA(className) then
					item:Destroy()
					break
				end
			end
		end
	end
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
			item.CastShadow = false
		end
	end
end

local rigCache = {} -- pose key -> posed, stripped model (never parented)

local function findRig(timeout)
	local rig = ReplicatedStorage:FindFirstChild(FighterAppearance.RigName)
	if not rig and timeout and timeout > 0 then
		rig = ReplicatedStorage:WaitForChild(FighterAppearance.RigName, timeout)
	end
	if rig and rig:IsA("Model") then
		return rig
	end
	return nil
end

local function posedRig(poseName, southpaw, timeout)
	local key = poseName .. (southpaw and "|S" or "")
	if rigCache[key] then
		return rigCache[key]
	end
	local rig = findRig(timeout)
	if not rig then
		return nil
	end
	if rigCache[key] then -- another caller finished while we waited
		return rigCache[key]
	end
	rig.Archivable = true -- a rig placed in Studio might not be; Clone() returns nil then
	local model = rig:Clone()
	if not model then
		return nil
	end
	local pose = POSES[poseName] or POSES.guard
	if southpaw then
		pose = mirrorPose(pose)
	end
	if not applyPose(model, pose) then
		model:Destroy()
		return nil
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	strip(model)
	if root then
		root.Transparency = 1
		model.PrimaryPart = root
		model:PivotTo(CFrame.new())
	end
	rigCache[key] = model
	return model
end

-- ============================================================
-- DRESSING
-- ============================================================
local BODY_ROLE = {
	Head = "skin", UpperTorso = "skin", Torso = "skin",
	LeftUpperArm = "skin", RightUpperArm = "skin", LeftLowerArm = "skin", RightLowerArm = "skin",
	LeftHand = "skin", RightHand = "skin", ["Left Arm"] = "skin", ["Right Arm"] = "skin",
	LowerTorso = "shorts", LeftUpperLeg = "shorts", RightUpperLeg = "shorts",
	["Left Leg"] = "shorts", ["Right Leg"] = "shorts",
	LeftLowerLeg = "skin", RightLowerLeg = "skin",
	LeftFoot = "boots", RightFoot = "boots",
}

local function addPart(model, props)
	local part = Instance.new("Part")
	part.Name = props.name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Color = props.color
	part.Size = props.size
	part.CFrame = props.cframe
	if props.shape == "ellipsoid" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	elseif props.shape == "cylinder" then
		part.Shape = Enum.PartType.Cylinder
	elseif props.shape == "ball" then
		part.Shape = Enum.PartType.Ball
	end
	part.Parent = model
	return part
end

local UPRIGHT_CYLINDER = CFrame.Angles(0, 0, math.pi / 2) -- Cylinder axis is X; turn it to Y

local function dressGloves(model, look)
	for _, side in ipairs({ "Left", "Right" }) do
		local hand = model:FindFirstChild(side .. "Hand") or model:FindFirstChild(side .. " Arm")
		if hand then
			local isArm = hand.Name == side .. " Arm"
			local width = math.max(hand.Size.X, hand.Size.Z)
			local tip = isArm and -(hand.Size.Y * 0.5) or 0
			hand.Color = look.skin
			addPart(model, {
				name = side .. "Glove",
				shape = "ellipsoid",
				color = look.gloves,
				size = Vector3.new(width * 1.08, width * 1.22, width * 1.14),
				cframe = hand.CFrame * CFrame.new(0, tip - width * 0.38, -width * 0.04),
			})
			addPart(model, {
				name = side .. "Cuff",
				shape = "cylinder",
				color = look.trim,
				size = Vector3.new(width * 0.34, width * 1.06, width * 1.06),
				cframe = hand.CFrame * CFrame.new(0, tip + width * 0.2, 0) * UPRIGHT_CYLINDER,
			})
			if not isArm then
				hand.Transparency = 1
			end
		end
	end
end

local function dressShorts(model, look)
	local lower = model:FindFirstChild("LowerTorso")
	if lower then
		addPart(model, {
			name = "Waistband",
			color = look.trim,
			size = Vector3.new(lower.Size.X * 1.05, math.max(0.14, lower.Size.Y * 0.4), lower.Size.Z * 1.1),
			cframe = lower.CFrame * CFrame.new(0, lower.Size.Y * 0.32, 0),
		})
	end
	for _, side in ipairs({ "Left", "Right" }) do
		local leg = model:FindFirstChild(side .. "UpperLeg")
		if leg then
			local outward = side == "Left" and -1 or 1
			addPart(model, {
				name = side .. "Stripe",
				color = look.trim,
				size = Vector3.new(0.05, leg.Size.Y * 0.86, leg.Size.Z * 0.34),
				cframe = leg.CFrame * CFrame.new(outward * (leg.Size.X * 0.5 + 0.02), leg.Size.Y * 0.04, 0),
			})
			addPart(model, {
				name = side .. "Hem",
				color = look.trim,
				size = Vector3.new(leg.Size.X * 1.06, 0.1, leg.Size.Z * 1.06),
				cframe = leg.CFrame * CFrame.new(0, -leg.Size.Y * 0.44, 0),
			})
		end
		local shin = model:FindFirstChild(side .. "LowerLeg")
		if shin then
			addPart(model, {
				name = side .. "Boot",
				color = look.boots,
				size = Vector3.new(shin.Size.X * 1.05, shin.Size.Y * 0.42, shin.Size.Z * 1.05),
				cframe = shin.CFrame * CFrame.new(0, -shin.Size.Y * 0.3, 0),
			})
		end
	end
end

local function dressHead(model, look)
	local head = model:FindFirstChild("Head")
	if not head then
		return
	end
	local size = head.Size
	local width = math.max(size.X, size.Z)
	local hair = look.hair
	if hair == "buzz" or hair == "bun" then
		addPart(model, {
			name = "Hair",
			shape = "ellipsoid",
			color = look.hairColor,
			size = Vector3.new(size.X * 1.03, size.Y * 0.62, size.Z * 1.05),
			cframe = head.CFrame * CFrame.new(0, size.Y * 0.2, size.Z * 0.03),
		})
		if hair == "bun" then
			addPart(model, {
				name = "HairBun",
				shape = "ball",
				color = look.hairColor,
				size = Vector3.new(width * 0.36, width * 0.36, width * 0.36),
				cframe = head.CFrame * CFrame.new(0, size.Y * 0.46, size.Z * 0.36),
			})
		end
	elseif hair == "short" then
		addPart(model, {
			name = "Hair",
			shape = "ellipsoid",
			color = look.hairColor,
			size = Vector3.new(size.X * 1.08, size.Y * 0.72, size.Z * 1.1),
			cframe = head.CFrame * CFrame.new(0, size.Y * 0.24, size.Z * 0.05),
		})
	elseif hair == "afro" then
		addPart(model, {
			name = "Hair",
			shape = "ellipsoid",
			color = look.hairColor,
			size = Vector3.new(size.X * 1.34, size.Y * 1.0, size.Z * 1.34),
			cframe = head.CFrame * CFrame.new(0, size.Y * 0.32, size.Z * 0.08),
		})
	elseif hair == "mohawk" then
		addPart(model, {
			name = "Hair",
			color = look.hairColor,
			size = Vector3.new(size.X * 0.2, size.Y * 0.32, size.Z * 1.0),
			cframe = head.CFrame * CFrame.new(0, size.Y * 0.5, size.Z * 0.04),
		})
	end
	if look.headband then
		addPart(model, {
			name = "Headband",
			shape = "cylinder",
			color = look.headband,
			size = Vector3.new(size.Y * 0.2, width * (hair == "afro" and 1.36 or 1.08), width * (hair == "afro" and 1.36 or 1.08)),
			cframe = head.CFrame * CFrame.new(0, size.Y * 0.2, 0) * UPRIGHT_CYLINDER,
		})
		for index, tilt in ipairs({ -0.35, 0.2 }) do
			addPart(model, {
				name = "HeadbandTail" .. index,
				color = look.headband,
				size = Vector3.new(0.14, size.Y * 0.46, 0.04),
				cframe = head.CFrame * CFrame.new(size.X * 0.1 * index, 0, size.Z * 0.56) * CFrame.Angles(0.35, 0, tilt),
			})
		end
	end
	if FighterAppearance.FaceTexture ~= "" then
		local face = head:FindFirstChildWhichIsA("Decal")
		if face then
			face.Texture = FighterAppearance.FaceTexture
		end
	end
end

local function bounds(model)
	local minV, maxV = nil, nil
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency < 0.99 then
			local half = part.Size * 0.5
			for _, sx in ipairs({ -1, 1 }) do
				for _, sy in ipairs({ -1, 1 }) do
					for _, sz in ipairs({ -1, 1 }) do
						local point = part.CFrame * Vector3.new(half.X * sx, half.Y * sy, half.Z * sz)
						if minV then
							minV = Vector3.new(math.min(minV.X, point.X), math.min(minV.Y, point.Y), math.min(minV.Z, point.Z))
							maxV = Vector3.new(math.max(maxV.X, point.X), math.max(maxV.Y, point.Y), math.max(maxV.Z, point.Z))
						else
							minV, maxV = point, point
						end
					end
				end
			end
		end
	end
	return minV or Vector3.new(-1, -3, -1), maxV or Vector3.new(1, 2, 1)
end

-- also the widest reach from the turning axis (Y through the pivot), for steady framing while spinning
local function measure(model)
	local minV, maxV = bounds(model)
	local radius = 0
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency < 0.99 then
			local half = part.Size * 0.5
			for _, sx in ipairs({ -1, 1 }) do
				for _, sz in ipairs({ -1, 1 }) do
					local point = part.CFrame * Vector3.new(half.X * sx, 0, half.Z * sz)
					radius = math.max(radius, math.sqrt(point.X * point.X + point.Z * point.Z))
				end
			end
		end
	end
	model:SetAttribute("BoundsMin", minV)
	model:SetAttribute("BoundsMax", maxV)
	model:SetAttribute("Radius", radius > 0 and radius or 2)
end

local dressedCache = {}
local dressedCount = 0

-- A posed, dressed fighter model (a fresh clone each call). Yields while the rig replicates.
-- Returns nil when there is no rig (the viewport then shows initials).
function FighterAppearance.build(name, poseName, timeout)
	name = tostring(name or "?")
	poseName = poseName or "guard"
	local key = poseName .. "|" .. name
	local template = dressedCache[key]
	if not template then
		local look = FighterAppearance.look(name)
		local base = posedRig(poseName, look.southpaw, timeout or 20)
		if not base then
			return nil
		end
		template = dressedCache[key]
		if not template then
			template = base:Clone()
			for _, part in ipairs(template:GetDescendants()) do
				if part:IsA("BasePart") then
					local role = BODY_ROLE[part.Name]
					if role then
						part.Color = look[role]
						part.Material = Enum.Material.SmoothPlastic
					end
				end
			end
			dressShorts(template, look)
			dressGloves(template, look)
			dressHead(template, look)
			measure(template)
			template.Name = "Fighter"
			if dressedCount > 60 then
				table.clear(dressedCache)
				dressedCount = 0
			end
			dressedCache[key] = template
			dressedCount += 1
		end
	end
	return template:Clone()
end

-- ============================================================
-- VIEWPORT
-- ============================================================
local FIT = {
	-- full body with a little air; portrait = head, gloves and chest
	full = { margin = 1.08 },
	portrait = { margin = 1.0, halfHeight = 1.05, halfWidth = 1.45, drop = 0.25 },
}

local function initialsOf(name)
	local letters = {}
	for word in string.gmatch(tostring(name or "?"), "[^%s%.]+") do
		table.insert(letters, utf8.char(utf8.codepoint(word, 1)))
		if #letters == 2 then
			break
		end
	end
	return string.upper(table.concat(letters))
end

-- props: parent, name (fighter), size, position, anchor, zIndex, order, frameName, corner (UDim),
--        mode ("full" | "portrait"), pose ("guard" | "victory"), yaw (degrees, + turns toward screen right),
--        spin (degrees per second), idle (breathing bob), draggable, ambient, lightColor, lightDirection
-- Returns a handle: { Instance, SetFighter(name, pose), SetYaw(deg), Model() }
function FighterAppearance.viewport(props)
	local frame = Instance.new("ViewportFrame")
	frame.Name = props.frameName or "Fighter3D"
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Size = props.size or UDim2.fromScale(1, 1)
	frame.Position = props.position or UDim2.new()
	frame.AnchorPoint = props.anchor or Vector2.new(0, 0)
	frame.ZIndex = props.zIndex or 1
	frame.LayoutOrder = props.order or 0
	frame.Ambient = props.ambient or rgb(128, 118, 116)
	frame.LightColor = props.lightColor or rgb(255, 238, 214)
	frame.LightDirection = props.lightDirection or Vector3.new(-0.5, -0.75, 0.65)
	frame.Active = props.draggable == true
	if props.corner then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = props.corner
		corner.Parent = frame
	end

	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = frame
	frame.CurrentCamera = camera

	local mode = FIT[props.mode or "full"] and (props.mode or "full") or "full"
	local state = {
		name = props.name,
		pose = props.pose or "guard",
		yaw = math.rad(props.yaw or 12),
		autoYaw = props.yaw == nil and not props.spin,
		spin = math.rad(props.spin or 0),
		model = nil,
		token = 0,
		dragging = false,
		resumeAt = 0,
	}
	local fallback = nil

	local function showFallback(visible)
		if visible and not fallback then
			fallback = Instance.new("TextLabel")
			fallback.Name = "Initials"
			fallback.BackgroundTransparency = 1
			fallback.Size = UDim2.fromScale(1, 1)
			fallback.Font = Enum.Font.GothamBlack
			fallback.TextScaled = true
			fallback.TextColor3 = rgb(240, 200, 90)
			fallback.ZIndex = frame.ZIndex
			local limit = Instance.new("UITextSizeConstraint")
			limit.MaxTextSize = 40
			limit.Parent = fallback
			fallback.Parent = frame
		end
		if fallback then
			fallback.Visible = visible
			fallback.Text = initialsOf(state.name)
		end
	end

	local function aspect()
		local absolute = frame.AbsoluteSize
		if absolute.X > 1 and absolute.Y > 1 then
			return absolute.X / absolute.Y
		end
		local size = frame.Size
		if size.X.Offset > 0 and size.Y.Offset > 0 then
			return size.X.Offset / size.Y.Offset
		end
		return 0.75
	end

	local function frameCamera()
		local model = state.model
		if not model then
			return
		end
		local tanV = math.tan(math.rad(camera.FieldOfView) / 2)
		local tanH = tanV * aspect()
		local fit = FIT[mode]
		local target, halfHeight, halfWidth, depth
		if mode == "portrait" then
			local head = model:FindFirstChild("Head")
			local headPos = head and head.CFrame.Position or Vector3.new(0, 1.5, 0)
			target = headPos - Vector3.new(0, fit.drop, 0)
			halfHeight, halfWidth, depth = fit.halfHeight, fit.halfWidth, 1.2
		elseif state.spin ~= 0 or props.draggable then
			-- turning: one framing that fits every angle
			local minV = model:GetAttribute("BoundsMin") or Vector3.new(-1, -3, -1)
			local maxV = model:GetAttribute("BoundsMax") or Vector3.new(1, 2, 1)
			local radius = model:GetAttribute("Radius") or 2.5
			target = Vector3.new(0, (minV.Y + maxV.Y) / 2, 0)
			-- only the gloves reach this far, and only at some angles: frame for most of it
			halfHeight, halfWidth, depth = (maxV.Y - minV.Y) / 2, radius * 0.9, radius
		else
			-- the model is already turned: measure what the camera really sees
			local minV, maxV = bounds(model)
			target = (minV + maxV) / 2
			halfHeight = (maxV.Y - minV.Y) / 2
			halfWidth = (maxV.X - minV.X) / 2
			depth = maxV.Z - minV.Z
		end
		-- head and feet sit near the middle depth; only the gloves reach toward the camera (sides)
		local distance = math.max(halfHeight / tanV, halfWidth / tanH + depth / 2) * fit.margin
		-- camera sits on the fighter's front (-Z) and looks toward +Z
		local pitch = 0
		local look = Vector3.new(0, math.sin(pitch), math.cos(pitch))
		camera.CFrame = CFrame.new(target - look * distance) * CFrame.fromEulerAnglesYXZ(pitch, math.pi, 0)
	end

	-- positive yaw turns the fighter toward screen right (the camera looks along +Z, so screen right is -X)
	local function placeModel(bob)
		local model = state.model
		if model then
			model:PivotTo(CFrame.new(0, bob or 0, 0) * CFrame.Angles(0, state.yaw, 0))
		end
	end

	local function load()
		if state.autoYaw then
			-- southpaws stand mirrored: turn them the other way so both show their face and gloves
			state.yaw = math.rad(FighterAppearance.look(state.name).southpaw and -12 or 12)
		end
		state.token += 1
		local token = state.token
		if state.model then
			state.model:Destroy()
			state.model = nil
		end
		task.spawn(function()
			local ok, model = pcall(FighterAppearance.build, state.name, state.pose)
			if token ~= state.token or not frame.Parent then
				if ok and model then
					model:Destroy()
				end
				return
			end
			if not ok or not model then
				if not ok then
					warn("FighterAppearance: " .. tostring(model))
				end
				showFallback(true)
				return
			end
			showFallback(false)
			state.model = model
			placeModel()
			frameCamera()
			model.Parent = frame
		end)
	end

	frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(frameCamera)

	local connections = {}
	if state.spin ~= 0 or props.idle or props.draggable then
		local clock = 0
		table.insert(connections, RunService.RenderStepped:Connect(function(dt)
			if not state.model or not frame.Visible then
				return
			end
			clock += dt
			if state.spin ~= 0 and not state.dragging and clock >= state.resumeAt then
				state.yaw = (state.yaw + state.spin * dt) % (math.pi * 2)
			end
			placeModel(props.idle and math.sin(clock * 2.4) * 0.05 or 0)
		end))
	end
	if props.draggable then
		local lastX = nil
		frame.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				state.dragging = true
				lastX = input.Position.X
			end
		end)
		table.insert(connections, UserInputService.InputChanged:Connect(function(input)
			if not state.dragging then
				return
			end
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				if lastX then
					state.yaw += math.rad((input.Position.X - lastX) * 0.6)
				end
				lastX = input.Position.X
			end
		end))
		table.insert(connections, UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				if state.dragging then
					state.dragging = false
					state.resumeAt = 0
				end
				lastX = nil
			end
		end))
	end
	frame.Destroying:Connect(function()
		state.token += 1
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
	end)

	frame.Parent = props.parent
	if state.name then
		load()
	end

	local handle = { Instance = frame }
	function handle.SetFighter(name, poseName)
		poseName = poseName or state.pose
		if name == state.name and poseName == state.pose and (state.model or fallback) then
			return
		end
		state.name = name
		state.pose = poseName
		if fallback then
			fallback.Text = initialsOf(name)
		end
		load()
	end
	function handle.SetYaw(degrees)
		state.autoYaw = false
		state.yaw = math.rad(degrees)
		placeModel()
		frameCamera()
	end
	function handle.Model()
		return state.model
	end
	return handle
end

-- Build the posed rigs ahead of time so the first panel opens without a hitch
function FighterAppearance.warmup()
	task.spawn(function()
		posedRig("guard", false, 30)
		posedRig("guard", true, 30)
	end)
end

return FighterAppearance
