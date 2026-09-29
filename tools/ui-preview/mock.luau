--!nocheck
-- Roblox runtime mock (Lune). Enough of the engine to run Coach Academy client + server scripts
-- in one process: Instances validated against the real API dump, signals, task scheduler with
-- virtual time, RemoteEvents/Functions with serialization, TweenService, services.

local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local luau = require("@lune/luau")
local stdio = require("@lune/stdio")

local M = {}

local Color3, UDim, UDim2, Vector2, Vector3 = roblox.Color3, roblox.UDim, roblox.UDim2, roblox.Vector2, roblox.Vector3
local Enum = roblox.Enum
local nativeTypeof = typeof

local API_PATH = (debug.info(1, "s"):match("^(.*)/[^/]+$") or ".") .. "/cache/api.json"
local API = serde.decode("json", fs.readFile(API_PATH))
local CLASSES = API.classes

-- ============================================================
-- STATE
-- ============================================================
local world = {
	now = 0,
	epoch = 1790000000,
	errors = {},
	warnings = {},
	logs = {},
	remoteLog = {},
	queue = {},
	seq = 0,
	verbose = false,
}
M.world = world

local internal = setmetatable({}, { __mode = "k" })

local function isInstance(v)
	return type(v) == "table" and internal[v] ~= nil
end

local function typeofMock(v)
	if isInstance(v) then
		return "Instance"
	end
	if type(v) == "table" then
		local mt = getmetatable(v)
		if type(mt) == "table" and rawget(mt, "__mocktype") then
			return mt.__mocktype
		end
	end
	return nativeTypeof(v)
end
M.typeof = typeofMock

local function recordError(message)
	table.insert(world.errors, message)
	print("[ERROR] " .. message)
end

local function recordWarn(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring((select(i, ...)))
	end
	local message = table.concat(parts, " ")
	table.insert(world.warnings, message)
	print("[warn] " .. message)
	-- skriptu "sugauti" klaidos (pcall + warn) irgi yra klaidos
	if string.find(message, "nepavyko sukurti", 1, true) or string.find(message, "klaida", 1, true) then
		table.insert(world.errors, "(warn) " .. message)
	end
end

-- ============================================================
-- SCHEDULER
-- ============================================================
local cancelled = setmetatable({}, { __mode = "k" })

local function resume(co, ...)
	if cancelled[co] or coroutine.status(co) == "dead" then
		return
	end
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		recordError(tostring(err) .. "\n" .. debug.traceback(co))
	end
end

local function schedule(at, co, ...)
	world.seq += 1
	table.insert(world.queue, { time = at, seq = world.seq, co = co, args = table.pack(...) })
end

local task = {}
function task.spawn(fnOrThread, ...)
	local co = type(fnOrThread) == "thread" and fnOrThread or coroutine.create(fnOrThread)
	resume(co, ...)
	return co
end
function task.defer(fnOrThread, ...)
	local co = type(fnOrThread) == "thread" and fnOrThread or coroutine.create(fnOrThread)
	schedule(world.now, co, ...)
	return co
end
function task.delay(seconds, fnOrThread, ...)
	local co = type(fnOrThread) == "thread" and fnOrThread or coroutine.create(fnOrThread)
	schedule(world.now + (seconds or 0), co, ...)
	return co
end
function task.wait(seconds)
	local co = coroutine.running()
	local start = world.now
	schedule(world.now + math.max(seconds or 0, 1 / 60), co)
	coroutine.yield()
	return world.now - start
end
function task.cancel(co)
	cancelled[co] = true
end
function task.synchronize() end
function task.desynchronize() end
M.task = task

function M.advance(dt)
	local target = world.now + dt
	while true do
		local bestIndex, best = nil, nil
		for index, entry in ipairs(world.queue) do
			if entry.time <= target and (not best or entry.time < best.time or (entry.time == best.time and entry.seq < best.seq)) then
				bestIndex, best = index, entry
			end
		end
		if not best then
			break
		end
		table.remove(world.queue, bestIndex)
		world.now = math.max(world.now, best.time)
		resume(best.co, table.unpack(best.args, 1, best.args.n))
	end
	world.now = target
end

-- ============================================================
-- SIGNALS
-- ============================================================
local Signal = {}
Signal.__index = Signal
Signal.__mocktype = "RBXScriptSignal"

function Signal.new(name)
	return setmetatable({ name = name, handlers = {}, waiting = {} }, Signal)
end
function Signal:Connect(fn)
	local connection = setmetatable({ Connected = true }, { __mocktype = "RBXScriptConnection" })
	local entry = { fn = fn, connection = connection }
	table.insert(self.handlers, entry)
	connection.Disconnect = function()
		connection.Connected = false
		for index, candidate in ipairs(self.handlers) do
			if candidate == entry then
				table.remove(self.handlers, index)
				break
			end
		end
	end
	if self.onFirstConnect and #self.handlers == 1 then
		self.onFirstConnect(entry)
	end
	return connection
end
function Signal:Once(fn)
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		fn(...)
	end)
	return connection
end
function Signal:Wait()
	local co = coroutine.running()
	table.insert(self.waiting, co)
	return coroutine.yield()
end
function Signal:Fire(...)
	for _, entry in ipairs(table.clone(self.handlers)) do
		task.spawn(entry.fn, ...)
	end
	local waiting = self.waiting
	self.waiting = {}
	for _, co in ipairs(waiting) do
		resume(co, ...)
	end
end
M.Signal = Signal

-- ============================================================
-- TWEENINFO
-- ============================================================
local TweenInfo = {}
local tweenInfoMeta = { __mocktype = "TweenInfo" }
tweenInfoMeta.__index = tweenInfoMeta
function TweenInfo.new(time, style, direction, repeatCount, reverses, delayTime)
	return setmetatable({
		Time = time or 1,
		EasingStyle = style or Enum.EasingStyle.Quad,
		EasingDirection = direction or Enum.EasingDirection.Out,
		RepeatCount = repeatCount or 0,
		Reverses = reverses or false,
		DelayTime = delayTime or 0,
	}, tweenInfoMeta)
end
M.TweenInfo = TweenInfo

-- ============================================================
-- CLASS REFLECTION
-- ============================================================
local function classChain(className)
	local chain = {}
	local name = className
	while name and CLASSES[name] do
		table.insert(chain, name)
		name = CLASSES[name].super
		if name == "<<<ROOT>>>" then
			break
		end
	end
	return chain
end

local propCache = {}
local function findProp(className, prop)
	propCache[className] = propCache[className] or {}
	local cached = propCache[className][prop]
	if cached ~= nil then
		return cached or nil
	end
	for _, name in ipairs(classChain(className)) do
		local info = CLASSES[name].props[prop]
		if info then
			propCache[className][prop] = info
			return info
		end
	end
	propCache[className][prop] = false
	return nil
end

local function hasEvent(className, eventName)
	for _, name in ipairs(classChain(className)) do
		if table.find(CLASSES[name].events, eventName) then
			return true
		end
	end
	return false
end

local function isA(className, target)
	for _, name in ipairs(classChain(className)) do
		if name == target then
			return true
		end
	end
	return false
end

-- Defaults (Instance.new values) for UI classes; other values fall back to Lune reflection.
local C = Color3.fromRGB
local DEFAULTS = {
	GuiObject = {
		AnchorPoint = Vector2.new(0, 0),
		AutomaticSize = Enum.AutomaticSize.None,
		BackgroundColor3 = C(163, 162, 165),
		BackgroundTransparency = 0,
		BorderColor3 = C(27, 42, 53),
		BorderSizePixel = 1,
		ClipsDescendants = false,
		LayoutOrder = 0,
		Position = UDim2.new(0, 0, 0, 0),
		Rotation = 0,
		Size = UDim2.new(0, 0, 0, 0),
		Visible = true,
		ZIndex = 1,
		Active = false,
		Selectable = false,
		SizeConstraint = Enum.SizeConstraint.RelativeXY,
		Interactable = true,
	},
	GuiBase2d = { AbsoluteSize = Vector2.new(0, 0), AbsolutePosition = Vector2.new(0, 0), AbsoluteRotation = 0 },
	TextLabel = {
		Text = "Label", TextSize = 8, TextColor3 = C(27, 42, 53), Font = Enum.Font.Legacy,
		TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = false, TextScaled = false, RichText = false, TextTransparency = 0,
		TextTruncate = Enum.TextTruncate.None, LineHeight = 1, TextStrokeTransparency = 1,
		TextStrokeColor3 = C(0, 0, 0), BackgroundColor3 = C(255, 255, 255),
	},
	TextButton = {
		Text = "Button", TextSize = 8, TextColor3 = C(27, 42, 53), Font = Enum.Font.Legacy,
		TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = false, TextScaled = false, RichText = false, TextTransparency = 0,
		TextTruncate = Enum.TextTruncate.None, LineHeight = 1, TextStrokeTransparency = 1,
		TextStrokeColor3 = C(0, 0, 0), AutoButtonColor = true, Modal = false, Selected = false,
		BackgroundColor3 = C(255, 255, 255), Active = true, Selectable = true,
	},
	TextBox = {
		Text = "", TextSize = 8, TextColor3 = C(27, 42, 53), Font = Enum.Font.Legacy,
		TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = false, TextScaled = false, RichText = false, TextTransparency = 0,
		TextTruncate = Enum.TextTruncate.None, LineHeight = 1, TextStrokeTransparency = 1,
		TextStrokeColor3 = C(0, 0, 0), PlaceholderText = "", PlaceholderColor3 = C(178, 178, 178),
		ClearTextOnFocus = true, TextEditable = true, MultiLine = false, BackgroundColor3 = C(255, 255, 255),
		Active = true, Selectable = true,
	},
	ImageLabel = { Image = "", ImageColor3 = C(255, 255, 255), ImageTransparency = 0, ScaleType = Enum.ScaleType.Stretch, BackgroundColor3 = C(255, 255, 255) },
	ImageButton = { Image = "", ImageColor3 = C(255, 255, 255), ImageTransparency = 0, ScaleType = Enum.ScaleType.Stretch, AutoButtonColor = true, BackgroundColor3 = C(255, 255, 255), Active = true },
	ScrollingFrame = {
		CanvasSize = UDim2.new(0, 0, 2, 0), CanvasPosition = Vector2.new(0, 0), ScrollBarThickness = 12,
		ScrollBarImageColor3 = C(0, 0, 0), ScrollBarImageTransparency = 0, ScrollingDirection = Enum.ScrollingDirection.XY,
		AutomaticCanvasSize = Enum.AutomaticSize.None, VerticalScrollBarInset = Enum.ScrollBarInset.None,
		HorizontalScrollBarInset = Enum.ScrollBarInset.None, ScrollingEnabled = true,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable, BackgroundColor3 = C(255, 255, 255), Active = true,
		TopImage = "rbxasset://textures/ui/Scroll/scroll-top.png", MidImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
		BottomImage = "rbxasset://textures/ui/Scroll/scroll-bottom.png",
		AbsoluteCanvasSize = Vector2.new(0, 0), AbsoluteWindowSize = Vector2.new(0, 0),
	},
	CanvasGroup = { GroupTransparency = 0, GroupColor3 = C(255, 255, 255) },
	UICorner = { CornerRadius = UDim.new(0, 8) },
	UIStroke = { Color = C(0, 0, 0), Thickness = 1, Transparency = 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Enabled = true, LineJoinMode = Enum.LineJoinMode.Round },
	UIGradient = {
		Color = roblox.ColorSequence.new(C(255, 255, 255)), Transparency = roblox.NumberSequence.new(0),
		Rotation = 0, Offset = Vector2.new(0, 0), Enabled = true,
	},
	UIPadding = { PaddingTop = UDim.new(0, 0), PaddingBottom = UDim.new(0, 0), PaddingLeft = UDim.new(0, 0), PaddingRight = UDim.new(0, 0) },
	UIListLayout = {
		FillDirection = Enum.FillDirection.Vertical, HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 0), Wraps = false,
	},
	UIGridLayout = {
		CellSize = UDim2.new(0, 100, 0, 100), CellPadding = UDim2.new(0, 5, 0, 5), FillDirection = Enum.FillDirection.Horizontal,
		FillDirectionMaxCells = 0, StartCorner = Enum.StartCorner.TopLeft, SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Left, VerticalAlignment = Enum.VerticalAlignment.Top,
	},
	UIScale = { Scale = 1 },
	UISizeConstraint = { MinSize = Vector2.new(0, 0), MaxSize = Vector2.new(math.huge, math.huge) },
	UITextSizeConstraint = { MinTextSize = 1, MaxTextSize = 100 },
	UIAspectRatioConstraint = { AspectRatio = 1, AspectType = Enum.AspectType.FitWithinMaxSize, DominantAxis = Enum.DominantAxis.Width },
	LayerCollector = { Enabled = true, ResetOnSpawn = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling },
	ScreenGui = { DisplayOrder = 0, IgnoreGuiInset = false },
	BillboardGui = { Enabled = true },
	BasePart = { Color = C(163, 162, 165), Material = Enum.Material.Plastic, Transparency = 0, Anchored = false, CanCollide = true },
	Camera = { ViewportSize = Vector2.new(1280, 720) },
	Player = { DisplayName = "Player", UserId = 1 },
	BaseScript = { Enabled = true, Disabled = false },
	ProximityPrompt = { Enabled = true, ActionText = "Interact", ObjectText = "" },
}

local luneDefaultsCache = {}
local function defaultFor(className, prop)
	for _, name in ipairs(classChain(className)) do
		local defaults = DEFAULTS[name]
		if defaults and defaults[prop] ~= nil then
			return defaults[prop]
		end
	end
	luneDefaultsCache[className] = luneDefaultsCache[className] or {}
	local cache = luneDefaultsCache[className]
	if cache[prop] == nil then
		local ok, value = pcall(function()
			return roblox.Instance.new(className)[prop]
		end)
		cache[prop] = ok and { value } or { nil }
	end
	return cache[prop][1]
end

local function checkType(className, prop, info, value)
	local ok
	local category, typeName = info.cat, info.type
	if category == "Primitive" then
		if typeName == "bool" then
			ok = type(value) == "boolean"
		elseif typeName == "string" then
			ok = type(value) == "string"
		else
			ok = type(value) == "number"
			if ok and (value ~= value) then
				error(string.format("Invalid property value %s.%s = NaN", className, prop), 3)
			end
		end
	elseif category == "DataType" then
		if typeName == "Content" or typeName == "ContentId" then
			ok = type(value) == "string" or nativeTypeof(value) == "Content"
		else
			ok = typeofMock(value) == typeName
		end
	elseif category == "Enum" then
		ok = nativeTypeof(value) == "EnumItem" and value.EnumType == Enum[typeName]
	elseif category == "Class" then
		ok = value == nil or (isInstance(value) and isA(internal[value].ClassName, typeName))
	else
		ok = true
	end
	if not ok then
		local got = typeofMock(value)
		if nativeTypeof(value) == "EnumItem" then
			got = tostring(value)
		end
		error(string.format("Unable to assign property %s.%s: %s expected, got %s", className, prop, typeName, got), 3)
	end
end

-- ============================================================
-- INSTANCES
-- ============================================================
local Instance = {}
local instanceMeta = {}
local classMethods = {} -- className -> { method = fn }
local specialGetters = {} -- className -> { prop = fn(self) }
local specialSetters = {} -- className -> { prop = fn(self, value) }
M.classMethods = classMethods
M.specialGetters = specialGetters
M.specialSetters = specialSetters

local function getSignal(self, name)
	local data = internal[self]
	data.signals[name] = data.signals[name] or Signal.new(name)
	return data.signals[name]
end
M.getSignal = getSignal

local function fullName(self)
	local parts = {}
	local current = self
	while current and isInstance(current) do
		local data = internal[current]
		if data.ClassName == "DataModel" then
			break
		end
		table.insert(parts, 1, data.Name)
		current = data.Parent
	end
	return table.concat(parts, ".")
end

local function setParent(self, newParent)
	local data = internal[self]
	if data.destroyed then
		error("The Parent property of " .. data.Name .. " is locked", 3)
	end
	if newParent ~= nil and not isInstance(newParent) then
		error("Parent must be an Instance", 3)
	end
	local current = newParent
	while current do
		if current == self then
			error("Attempt to set parent of " .. data.Name .. " to itself or descendant", 3)
		end
		current = internal[current].Parent
	end
	local oldParent = data.Parent
	if oldParent == newParent then
		return
	end
	if oldParent then
		local siblings = internal[oldParent].children
		local index = table.find(siblings, self)
		if index then
			table.remove(siblings, index)
		end
		getSignal(oldParent, "ChildRemoved"):Fire(self)
	end
	data.Parent = newParent
	if newParent then
		table.insert(internal[newParent].children, self)
		getSignal(newParent, "ChildAdded"):Fire(self)
		local ancestor = newParent
		while ancestor do
			local ancestorData = internal[ancestor]
			if ancestorData.signals.DescendantAdded then
				ancestorData.signals.DescendantAdded:Fire(self)
			end
			ancestor = ancestorData.Parent
		end
	end
	if data.signals.AncestryChanged then
		data.signals.AncestryChanged:Fire(self, newParent)
	end
	if data.changedSignals.Parent then
		data.changedSignals.Parent:Fire()
	end
end

local baseMethods = {}
function baseMethods.IsA(self, className)
	return isA(internal[self].ClassName, className)
end
function baseMethods.FindFirstChild(self, name, recursive)
	for _, child in ipairs(internal[self].children) do
		if internal[child].Name == name then
			return child
		end
	end
	if recursive then
		for _, child in ipairs(internal[self].children) do
			local found = baseMethods.FindFirstChild(child, name, true)
			if found then
				return found
			end
		end
	end
	return nil
end
function baseMethods.FindFirstChildOfClass(self, className)
	for _, child in ipairs(internal[self].children) do
		if internal[child].ClassName == className then
			return child
		end
	end
	return nil
end
function baseMethods.FindFirstChildWhichIsA(self, className, recursive)
	for _, child in ipairs(internal[self].children) do
		if isA(internal[child].ClassName, className) then
			return child
		end
	end
	if recursive then
		for _, child in ipairs(internal[self].children) do
			local found = baseMethods.FindFirstChildWhichIsA(child, className, true)
			if found then
				return found
			end
		end
	end
	return nil
end
function baseMethods.FindFirstAncestor(self, name)
	local current = internal[self].Parent
	while current do
		if internal[current].Name == name then
			return current
		end
		current = internal[current].Parent
	end
	return nil
end
function baseMethods.FindFirstAncestorOfClass(self, className)
	local current = internal[self].Parent
	while current do
		if internal[current].ClassName == className then
			return current
		end
		current = internal[current].Parent
	end
	return nil
end
function baseMethods.FindFirstAncestorWhichIsA(self, className)
	local current = internal[self].Parent
	while current do
		if isA(internal[current].ClassName, className) then
			return current
		end
		current = internal[current].Parent
	end
	return nil
end
function baseMethods.WaitForChild(self, name, timeout)
	local found = baseMethods.FindFirstChild(self, name)
	if found then
		return found
	end
	local waited = 0
	local limit = timeout or 8
	while waited < limit do
		waited += task.wait(0.05)
		found = baseMethods.FindFirstChild(self, name)
		if found then
			return found
		end
	end
	if not timeout then
		recordWarn("Infinite yield possible on '" .. fullName(self) .. ":WaitForChild(\"" .. tostring(name) .. "\")'")
	end
	return nil
end
function baseMethods.GetChildren(self)
	return table.clone(internal[self].children)
end
function baseMethods.GetDescendants(self)
	local out = {}
	local function walk(node)
		for _, child in ipairs(internal[node].children) do
			table.insert(out, child)
			walk(child)
		end
	end
	walk(self)
	return out
end
function baseMethods.IsDescendantOf(self, ancestor)
	local current = internal[self].Parent
	while current do
		if current == ancestor then
			return true
		end
		current = internal[current].Parent
	end
	return false
end
function baseMethods.IsAncestorOf(self, descendant)
	return baseMethods.IsDescendantOf(descendant, self)
end
function baseMethods.ClearAllChildren(self)
	for _, child in ipairs(table.clone(internal[self].children)) do
		baseMethods.Destroy(child)
	end
end
function baseMethods.Destroy(self)
	local data = internal[self]
	if data.destroyed then
		return
	end
	for _, child in ipairs(table.clone(data.children)) do
		baseMethods.Destroy(child)
	end
	setParent(self, nil)
	data.destroyed = true
	if data.signals.Destroying then
		data.signals.Destroying:Fire()
	end
	for _, signal in pairs(data.signals) do
		signal.handlers = {}
	end
	for _, signal in pairs(data.changedSignals) do
		signal.handlers = {}
	end
end
function baseMethods.GetPropertyChangedSignal(self, prop)
	local data = internal[self]
	if prop ~= "Name" and prop ~= "Parent" and not findProp(data.ClassName, prop) then
		error(prop .. " is not a valid property name.", 2)
	end
	data.changedSignals[prop] = data.changedSignals[prop] or Signal.new("Changed:" .. prop)
	return data.changedSignals[prop]
end
function baseMethods.GetAttribute(self, name)
	return internal[self].attributes[name]
end
function baseMethods.SetAttribute(self, name, value)
	local data = internal[self]
	local changed = data.attributes[name] ~= value
	data.attributes[name] = value
	local signal = data.changedSignals["@" .. name]
	if changed and signal then
		signal:Fire()
	end
end
function baseMethods.GetAttributeChangedSignal(self, name)
	local data = internal[self]
	data.changedSignals["@" .. name] = data.changedSignals["@" .. name] or Signal.new("AttributeChanged:" .. name)
	return data.changedSignals["@" .. name]
end
function baseMethods.GetAttributes(self)
	return table.clone(internal[self].attributes)
end
function baseMethods.GetFullName(self)
	return fullName(self)
end
function baseMethods.GetTags(self)
	return {}
end
function baseMethods.HasTag()
	return false
end
function baseMethods.AddTag() end
function baseMethods.GetActor()
	return nil
end

local function findMethod(className, name)
	for _, cls in ipairs(classChain(className)) do
		local methods = classMethods[cls]
		if methods and methods[name] then
			return methods[name]
		end
	end
	return baseMethods[name]
end

local function findSpecial(tbl, className, name)
	for _, cls in ipairs(classChain(className)) do
		local entries = tbl[cls]
		if entries and entries[name] then
			return entries[name]
		end
	end
	return nil
end

instanceMeta.__index = function(self, key)
	local data = internal[self]
	if key == "ClassName" then
		return data.ClassName
	elseif key == "Name" then
		return data.Name
	elseif key == "Parent" then
		return data.Parent
	end
	local getter = findSpecial(specialGetters, data.ClassName, key)
	if getter then
		return getter(self)
	end
	local method = findMethod(data.ClassName, key)
	if method then
		return method
	end
	if data.callbacks[key] ~= nil then
		return data.callbacks[key]
	end
	local info = findProp(data.ClassName, key)
	if info then
		if info.dep then
			world.deprecatedUse = world.deprecatedUse or {}
			world.deprecatedUse[data.ClassName .. "." .. key] = true
		end
		local value = data.props[key]
		if value == nil then
			value = defaultFor(data.ClassName, key)
		end
		return value
	end
	if hasEvent(data.ClassName, key) then
		return getSignal(self, key)
	end
	local child = baseMethods.FindFirstChild(self, key)
	if child then
		return child
	end
	error(string.format("%s is not a valid member of %s \"%s\"", tostring(key), data.ClassName, fullName(self)), 2)
end

local CALLBACKS = { OnServerInvoke = true, OnClientInvoke = true, OnInvoke = true }

instanceMeta.__newindex = function(self, key, value)
	local data = internal[self]
	if key == "Name" then
		if type(value) ~= "string" then
			error("Name must be a string", 2)
		end
		data.Name = value
		if data.changedSignals.Name then
			data.changedSignals.Name:Fire()
		end
		return
	elseif key == "Parent" then
		setParent(self, value)
		return
	elseif CALLBACKS[key] then
		data.callbacks[key] = value
		return
	end
	local setter = findSpecial(specialSetters, data.ClassName, key)
	if setter then
		setter(self, value)
		return
	end
	local info = findProp(data.ClassName, key)
	if not info then
		error(string.format("%s is not a valid member of %s \"%s\"", tostring(key), data.ClassName, fullName(self)), 2)
	end
	if info.ro and not data.allowReadOnly then
		error(string.format("Unable to assign property %s. Property is read only", key), 2)
	end
	checkType(data.ClassName, key, info, value)
	if info.dep then
		world.deprecatedUse = world.deprecatedUse or {}
		world.deprecatedUse[data.ClassName .. "." .. key] = true
	end
	local old = data.props[key]
	if old == nil then
		old = defaultFor(data.ClassName, key)
	end
	data.props[key] = value
	if old ~= value then
		if data.changedSignals[key] then
			data.changedSignals[key]:Fire()
		end
		if data.signals.Changed then
			data.signals.Changed:Fire(key)
		end
	end
end

instanceMeta.__tostring = function(self)
	return internal[self].Name
end

local NOT_CREATABLE = { DataModel = true, Players = true, Player = true, PlayerGui = true, Workspace = true }

function Instance.new(className, parent)
	if not CLASSES[className] then
		error("Unable to create an Instance of type \"" .. tostring(className) .. "\"", 2)
	end
	local tags = CLASSES[className].tags
	if table.find(tags, "NotCreatable") or table.find(tags, "Service") then
		error("Unable to create an Instance of type \"" .. className .. "\"", 2)
	end
	return M.rawInstance(className, parent)
end

function M.rawInstance(className, parent)
	local self = setmetatable({}, instanceMeta)
	internal[self] = {
		ClassName = className,
		Name = className,
		Parent = nil,
		props = {},
		children = {},
		signals = {},
		changedSignals = {},
		attributes = {},
		callbacks = {},
		id = 0,
	}
	world.seq += 1
	internal[self].id = world.seq
	if parent then
		setParent(self, parent)
	end
	return self
end

function M.setInternal(self, prop, value)
	internal[self].props[prop] = value
	local signal = internal[self].changedSignals[prop]
	if signal then
		signal:Fire()
	end
end
function M.getData(self)
	return internal[self]
end
M.isInstance = isInstance
M.Instance = Instance
M.findProp = findProp
M.isA = isA

-- ============================================================
-- SERIALIZATION (network copy)
-- ============================================================
local function deepCopy(value, seen)
	if type(value) ~= "table" or isInstance(value) then
		return value
	end
	local mt = getmetatable(value)
	if mt and rawget(mt, "__mocktype") then
		return value
	end
	seen = seen or {}
	if seen[value] then
		error("Cyclic table cannot be sent over the network")
	end
	seen[value] = true
	local out = {}
	for k, v in pairs(value) do
		if type(v) ~= "function" and type(v) ~= "thread" then
			out[k] = deepCopy(v, seen)
		end
	end
	seen[value] = nil
	return out
end

local function copyArgs(...)
	local packed = table.pack(...)
	for i = 1, packed.n do
		packed[i] = deepCopy(packed[i])
	end
	return packed
end

local NETWORK_DELAY = 0.03

-- RemoteEvent: queue client events until first OnClientEvent connection (like Roblox)
local function clientSignal(remote)
	local data = internal[remote]
	if not data.signals.OnClientEvent then
		local signal = Signal.new("OnClientEvent")
		data.pendingClient = {}
		signal.onFirstConnect = function(entry)
			local pending = data.pendingClient
			data.pendingClient = {}
			for _, args in ipairs(pending) do
				task.spawn(entry.fn, table.unpack(args, 1, args.n))
			end
		end
		data.signals.OnClientEvent = signal
	end
	return data.signals.OnClientEvent
end

classMethods.RemoteEvent = {
	FireServer = function(self, ...)
		local args = copyArgs(...)
		table.insert(world.remoteLog, { remote = self.Name, direction = "toServer", args = args })
		task.delay(NETWORK_DELAY, function()
			getSignal(self, "OnServerEvent"):Fire(M.localPlayer, table.unpack(args, 1, args.n))
		end)
	end,
	FireClient = function(self, player, ...)
		local args = copyArgs(...)
		table.insert(world.remoteLog, { remote = self.Name, direction = "toClient", args = args })
		task.delay(NETWORK_DELAY, function()
			local signal = clientSignal(self)
			if #signal.handlers == 0 then
				table.insert(internal[self].pendingClient, args)
			else
				signal:Fire(table.unpack(args, 1, args.n))
			end
		end)
	end,
	FireAllClients = function(self, ...)
		classMethods.RemoteEvent.FireClient(self, M.localPlayer, ...)
	end,
}
specialGetters.RemoteEvent = {
	OnClientEvent = function(self)
		return clientSignal(self)
	end,
}
classMethods.RemoteFunction = {
	InvokeServer = function(self, ...)
		local args = copyArgs(...)
		task.wait(NETWORK_DELAY)
		local waited = 0
		while not internal[self].callbacks.OnServerInvoke and waited < 10 do
			waited += task.wait(0.05)
		end
		local handler = internal[self].callbacks.OnServerInvoke
		if not handler then
			error("RemoteFunction " .. self.Name .. " has no OnServerInvoke")
		end
		local result = copyArgs(handler(M.localPlayer, table.unpack(args, 1, args.n)))
		task.wait(NETWORK_DELAY)
		return table.unpack(result, 1, result.n)
	end,
}

-- ============================================================
-- TWEENS
-- ============================================================
local activeTweens = setmetatable({}, { __mode = "k" }) -- instance -> { prop -> token }

classMethods.TweenService = {
	Create = function(_, instance, info, goals)
		if not isInstance(instance) then
			error("TweenService:Create expects an Instance", 2)
		end
		if typeofMock(info) ~= "TweenInfo" then
			error("TweenService:Create expects TweenInfo", 2)
		end
		for prop, value in pairs(goals) do
			local propInfo = findProp(internal[instance].ClassName, prop)
			if not propInfo then
				error("TweenService:Create no property named '" .. prop .. "' for object '" .. instance.Name .. "'", 2)
			end
			checkType(internal[instance].ClassName, prop, propInfo, value)
			local tweenable = { Primitive = true, DataType = true }
			if not tweenable[propInfo.cat] or propInfo.type == "bool" or propInfo.type == "string" then
				error("TweenService:Create property " .. prop .. " is not tweenable", 2)
			end
		end
		local tween = setmetatable({
			Instance = instance,
			TweenInfo = info,
			PlaybackState = Enum.PlaybackState.Begin,
		}, { __mocktype = "Instance" })
		tween.Completed = Signal.new("Completed")
		local token = {}
		function tween:Play()
			if (info.RepeatCount or 0) < 0 then
				-- begalinis ciklas (pvz. pulsavimas): perziurai paliekam pradine busena
				tween.PlaybackState = Enum.PlaybackState.Playing
				return
			end
			activeTweens[instance] = activeTweens[instance] or {}
			for prop in pairs(goals) do
				activeTweens[instance][prop] = token
			end
			tween.PlaybackState = Enum.PlaybackState.Playing
			task.delay(info.Time + (info.DelayTime or 0), function()
				if internal[instance].destroyed then
					return
				end
				local stillOwner = false
				for prop, value in pairs(goals) do
					if activeTweens[instance][prop] == token then
						instance[prop] = value
						stillOwner = true
					end
				end
				if stillOwner then
					tween.PlaybackState = Enum.PlaybackState.Completed
					tween.Completed:Fire(Enum.PlaybackState.Completed)
				end
			end)
		end
		function tween:Cancel()
			if activeTweens[instance] then
				for prop in pairs(goals) do
					if activeTweens[instance][prop] == token then
						activeTweens[instance][prop] = nil
					end
				end
			end
			tween.PlaybackState = Enum.PlaybackState.Cancelled
		end
		function tween:Pause()
			tween:Cancel()
		end
		function tween:Destroy() end
		return tween
	end,
}

-- ============================================================
-- SERVICES / DATAMODEL
-- ============================================================
-- Roblox Random (deterministinis LCG)
MockRandom = {}
MockRandom.__index = MockRandom
function MockRandom.new(seed)
	local self = setmetatable({}, MockRandom)
	self.state = math.floor(math.abs(seed or os.time())) % 2147483647
	if self.state == 0 then
		self.state = 1
	end
	return self
end
function MockRandom:_next()
	self.state = (self.state * 16807) % 2147483647
	return self.state / 2147483647
end
function MockRandom:NextNumber(minValue, maxValue)
	minValue, maxValue = minValue or 0, maxValue or 1
	return minValue + (maxValue - minValue) * self:_next()
end
function MockRandom:NextInteger(minValue, maxValue)
	return math.min(maxValue, minValue + math.floor((maxValue - minValue + 1) * self:_next()))
end

local game = M.rawInstance("DataModel")
internal[game].Name = "Game"
M.game = game

local services = {}
local function getService(name)
	if services[name] then
		return services[name]
	end
	if not CLASSES[name] then
		error("'" .. tostring(name) .. "' is not a valid Service name", 2)
	end
	local service = M.rawInstance(name, game)
	internal[service].Name = name
	services[name] = service
	return service
end
classMethods.DataModel = {
	GetService = function(_, name)
		return getService(name)
	end,
	FindService = function(_, name)
		return services[name]
	end,
	BindToClose = function() end,
	IsLoaded = function()
		return true
	end,
}
specialGetters.DataModel = {
	Workspace = function()
		return getService("Workspace")
	end,
	Loaded = function(self)
		return getSignal(self, "Loaded")
	end,
	PlaceId = function()
		return 0
	end,
	JobId = function()
		return "mock"
	end,
}
M.getService = getService

classMethods.Workspace = {
	GetServerTimeNow = function()
		return world.epoch + world.now
	end,
}
classMethods.GuiService = {
	GetGuiInset = function()
		return Vector2.new(0, M.topInset or 58), Vector2.new(0, 0)
	end,
}
classMethods.ContentProvider = {
	PreloadAsync = function(_, items, callback)
		for _, item in ipairs(items or {}) do
			task.wait(0.05)
			if callback then
				callback(typeof(item) == "string" and item or "rbxasset://mock", Enum.AssetFetchStatus.Success)
			end
		end
	end,
}
classMethods.ReplicatedFirst = {
	RemoveDefaultLoadingScreen = function()
		world.defaultLoadingRemoved = true
	end,
	IsFinishedReplicating = function()
		return true
	end,
}
world.coreGui = {}
classMethods.StarterGui = {
	SetCoreGuiEnabled = function(_, coreType, enabled)
		world.coreGui[coreType.Name] = enabled
	end,
	GetCoreGuiEnabled = function(_, coreType)
		return world.coreGui[coreType.Name] ~= false
	end,
	SetCore = function() end,
	GetCore = function()
		return nil
	end,
}
classMethods.Sound = {
	Play = function(self)
		world.soundsPlayed = world.soundsPlayed or {}
		table.insert(world.soundsPlayed, self.Name)
	end,
	Stop = function() end,
	Pause = function() end,
	Resume = function() end,
}
classMethods.RunService = {
	BindToRenderStep = function() end,
	UnbindFromRenderStep = function() end,
	IsStudio = function()
		return false
	end,
	IsServer = function()
		return true
	end,
	IsClient = function()
		return true
	end,
	IsRunning = function()
		return true
	end,
}
specialGetters.UserInputService = {
	TouchEnabled = function()
		return M.touchEnabled == true
	end,
	KeyboardEnabled = function()
		return M.touchEnabled ~= true
	end,
	MouseEnabled = function()
		return M.touchEnabled ~= true
	end,
	GamepadEnabled = function()
		return false
	end,
}
classMethods.DataStoreService = {
	GetDataStore = function()
		error("DataStoreService: mock -- not available (like an unpublished place)")
	end,
}
classMethods.Players = {
	GetPlayers = function()
		return { M.localPlayer }
	end,
	GetUserThumbnailAsync = function(_, userId)
		task.wait(0.1)
		return "rbxthumb://type=AvatarHeadShot&id=" .. tostring(userId) .. "&w=150&h=150", true
	end,
	GetPlayerFromCharacter = function()
		return nil
	end,
}
specialGetters.Players = {
	LocalPlayer = function()
		return M.localPlayer
	end,
}
specialGetters.Player = {
	UserId = function(self)
		return internal[self].userId or 1
	end,
	DisplayName = function(self)
		return internal[self].displayName or internal[self].Name
	end,
	Character = function()
		return nil
	end,
}
classMethods.TextBox = {
	CaptureFocus = function(self)
		getSignal(self, "Focused"):Fire()
	end,
	ReleaseFocus = function(self, submitted)
		getSignal(self, "FocusLost"):Fire(submitted == true, nil)
	end,
	IsFocused = function()
		return false
	end,
}
classMethods.TextService = {
	FilterStringAsync = function(_, text)
		task.wait(0.05)
		return setmetatable({
			GetNonChatStringForBroadcastAsync = function()
				return text
			end,
			GetNonChatStringForUserAsync = function()
				return text
			end,
		}, { __mocktype = "Instance" })
	end,
}
classMethods.ContextActionService = {
	BindAction = function() end,
	BindActionAtPriority = function() end,
	UnbindAction = function() end,
}
classMethods.HttpService = {
	JSONEncode = function(_, value)
		return serde.encode("json", value)
	end,
	JSONDecode = function(_, text)
		return serde.decode("json", text)
	end,
	GenerateGUID = function()
		world.seq += 1
		return "{MOCK-GUID-" .. world.seq .. "}"
	end,
}

-- ============================================================
-- SCRIPT EXECUTION
-- ============================================================
local moduleCache = {}
local sharedG = {}
M.sharedG = sharedG

local function makeEnv(scriptInstance, context)
	local env = {}
	env.script = scriptInstance
	env.game = game
	env.Game = game
	env.workspace = getService("Workspace")
	env.Workspace = env.workspace
	env.Instance = Instance
	env.Color3 = Color3
	env.UDim = UDim
	env.UDim2 = UDim2
	env.Vector2 = Vector2
	env.Vector3 = Vector3
	env.Enum = Enum
	env.CFrame = roblox.CFrame
	env.ColorSequence = roblox.ColorSequence
	env.ColorSequenceKeypoint = roblox.ColorSequenceKeypoint
	env.NumberSequence = roblox.NumberSequence
	env.NumberSequenceKeypoint = roblox.NumberSequenceKeypoint
	env.NumberRange = roblox.NumberRange
	env.Rect = roblox.Rect
	env.BrickColor = roblox.BrickColor
	env.Font = roblox.Font
	env.TweenInfo = TweenInfo
	env.Random = MockRandom
	env.task = task
	env.wait = task.wait
	env.delay = task.delay
	env.spawn = task.defer
	env.tick = function()
		return world.epoch + world.now
	end
	env.time = function()
		return world.now
	end
	env.elapsedTime = env.time
	env.typeof = typeofMock
	env._G = sharedG
	env.shared = sharedG
	env.os = {
		time = function(t)
			if t then
				return os.time(t)
			end
			return world.epoch + math.floor(world.now)
		end,
		clock = function()
			return world.now
		end,
		date = os.date,
		difftime = os.difftime,
	}
	env.print = function(...)
		if world.verbose then
			print("[" .. context .. "]", ...)
		end
		local parts = {}
		for i = 1, select("#", ...) do
			parts[i] = tostring((select(i, ...)))
		end
		table.insert(world.logs, "[" .. context .. "] " .. table.concat(parts, " "))
	end
	env.warn = function(...)
		recordWarn("[" .. context .. "]", ...)
	end
	env.require = function(target)
		if not isInstance(target) or internal[target].ClassName ~= "ModuleScript" then
			error("Attempted to call require with invalid argument(s).", 2)
		end
		local cached = moduleCache[target]
		if cached then
			if cached.loading then
				error("Requested module was required recursively", 2)
			end
			return cached.value
		end
		cached = { loading = true }
		moduleCache[target] = cached
		local source = internal[target].props.Source or ""
		local chunk = luau.load(source, {
			debugName = fullName(target),
			environment = makeEnv(target, context),
			injectGlobals = false,
		})
		local results = table.pack(chunk())
		if results.n ~= 1 then
			error("Module code did not return exactly one value (" .. fullName(target) .. ")", 2)
		end
		cached.value = results[1]
		cached.loading = false
		return cached.value
	end
	local base = {
		assert = assert, error = error, getmetatable = getmetatable, setmetatable = setmetatable,
		ipairs = ipairs, pairs = pairs, next = next, pcall = pcall, xpcall = xpcall, select = select,
		tonumber = tonumber, tostring = tostring, type = type, rawequal = rawequal, rawget = rawget,
		rawset = rawset, rawlen = rawlen, unpack = table.unpack, newproxy = newproxy,
		math = math, string = string, table = table, coroutine = coroutine, utf8 = utf8, bit32 = bit32,
		buffer = buffer, debug = debug, gcinfo = gcinfo,
	}
	return setmetatable(env, { __index = base })
end

function M.runScript(scriptInstance, context)
	local source = internal[scriptInstance].props.Source or ""
	local chunk = luau.load(source, {
		debugName = fullName(scriptInstance),
		environment = makeEnv(scriptInstance, context),
		injectGlobals = false,
	})
	task.spawn(chunk)
end

function M.requireFrom(moduleInstance, context)
	return makeEnv(moduleInstance, context or "client").require(moduleInstance)
end

-- ============================================================
-- INTERACTION HELPERS
-- ============================================================
function M.click(instance)
	getSignal(instance, "MouseEnter"):Fire(0, 0)
	getSignal(instance, "MouseButton1Down"):Fire(0, 0)
	getSignal(instance, "MouseButton1Up"):Fire(0, 0)
	getSignal(instance, "MouseButton1Click"):Fire()
	getSignal(instance, "Activated"):Fire(nil, 1)
	getSignal(instance, "MouseLeave"):Fire(0, 0)
end

function M.hover(instance)
	getSignal(instance, "MouseEnter"):Fire(0, 0)
end

function M.findPath(root, path)
	local current = root
	for part in string.gmatch(path, "[^/]+") do
		current = baseMethods.FindFirstChild(current, part, true)
		if not current then
			error("findPath: '" .. part .. "' not found in path " .. path)
		end
	end
	return current
end

-- ============================================================
-- DUMP FOR RENDERER
-- ============================================================
local RENDER_PROPS = {
	"Visible", "Position", "Size", "AnchorPoint", "BackgroundColor3", "BackgroundTransparency", "BorderSizePixel",
	"ClipsDescendants", "LayoutOrder", "ZIndex", "Rotation", "AutomaticSize",
	"Text", "TextColor3", "TextSize", "Font", "TextXAlignment", "TextYAlignment", "TextWrapped", "TextTruncate",
	"TextScaled", "RichText", "TextTransparency", "LineHeight", "TextStrokeTransparency", "TextStrokeColor3",
	"PlaceholderText", "PlaceholderColor3",
	"Image", "ImageColor3", "ImageTransparency", "ScaleType",
	"CanvasSize", "CanvasPosition", "AutomaticCanvasSize", "ScrollBarThickness", "ScrollBarImageColor3",
	"ScrollBarImageTransparency", "VerticalScrollBarInset", "ScrollingDirection",
	"GroupTransparency",
	"Enabled", "DisplayOrder", "IgnoreGuiInset", "ZIndexBehavior",
	"CornerRadius", "Color", "Thickness", "Transparency", "ApplyStrokeMode", "Offset",
	"PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight",
	"FillDirection", "HorizontalAlignment", "VerticalAlignment", "SortOrder", "Padding", "Wraps",
	"CellSize", "CellPadding", "FillDirectionMaxCells", "StartCorner",
	"Scale", "MinSize", "MaxSize", "MinTextSize", "MaxTextSize", "AspectRatio", "AspectType", "DominantAxis",
}

local function serializeValue(value)
	local kind = typeofMock(value)
	if kind == "UDim2" then
		return { t = "UDim2", xs = value.X.Scale, xo = value.X.Offset, ys = value.Y.Scale, yo = value.Y.Offset }
	elseif kind == "UDim" then
		return { t = "UDim", s = value.Scale, o = value.Offset }
	elseif kind == "Vector2" then
		return { t = "Vector2", x = value.X, y = value.Y }
	elseif kind == "Color3" then
		return { t = "Color3", r = value.R, g = value.G, b = value.B }
	elseif kind == "EnumItem" then
		return value.Name
	elseif kind == "ColorSequence" then
		local out = { t = "ColorSequence", k = {} }
		for _, kp in ipairs(value.Keypoints) do
			table.insert(out.k, { kp.Time, kp.Value.R, kp.Value.G, kp.Value.B })
		end
		return out
	elseif kind == "NumberSequence" then
		local out = { t = "NumberSequence", k = {} }
		for _, kp in ipairs(value.Keypoints) do
			table.insert(out.k, { kp.Time, kp.Value })
		end
		return out
	elseif kind == "number" then
		if value == math.huge then
			return 1e9
		end
		return value
	elseif kind == "string" or kind == "boolean" then
		return value
	end
	return nil
end

function M.dump(root)
	local function node(instance)
		local data = internal[instance]
		local props = {}
		for _, prop in ipairs(RENDER_PROPS) do
			if findProp(data.ClassName, prop) then
				local ok, value = pcall(function()
					return instance[prop]
				end)
				if ok and value ~= nil then
					props[prop] = serializeValue(value)
				end
			end
		end
		local children = {}
		for _, child in ipairs(data.children) do
			table.insert(children, node(child))
		end
		return { c = data.ClassName, n = data.Name, p = props, ch = children }
	end
	return node(root)
end

return M
