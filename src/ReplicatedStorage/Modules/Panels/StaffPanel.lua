--[[
	StaffPanel
	Personalo samdymas ir valdymas: 5 darbuotoju tipai (StaffConfig.Order), kiekvienas duoda
	% bonusa. Rodo komandos suvestine, atlyginimus ir leidzia samdyti / atleisti (su patvirtinimu).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local StaffConfig = require(Modules:WaitForChild("StaffConfig"))

local StaffPanel = {}

local ROLE_ICONS = {
	AssistantCoach = "📋",
	StrengthCoach = "🏋️",
	SpeedCoach = "⚡",
	Physio = "🩺",
	MentalCoach = "🧠",
	TalentScout = "🔭",
	NutritionCoach = "🥗",
}

-- Aprasyme paryskinamas bonuso dydis ("+10%", "-30%"), kad jis butu matomas is karto
local function highlightBonus(text, hex)
	local escaped = (text or ""):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
	return (escaped:gsub("([%+%-]%d+%%)", '<font color="' .. hex .. '"><b>%1</b></font>'))
end

-- Kiek laiko uzteks biudzeto atlyginimams (ne "ciklais" -- zaidejui aiskiau laikas)
local function runwayText(cycles, intervalSeconds)
	if cycles >= 100 then
		return "8+ h"
	end
	local minutes = cycles * intervalSeconds // 60
	if minutes >= 60 then
		local rest = minutes % 60
		return rest == 0 and string.format("%d h", minutes // 60) or string.format("%d h %d min", minutes // 60, rest)
	end
	return string.format("%d min", minutes)
end

function StaffPanel.create(Kit, State)
	local C = Kit.Colors

	local panel = Kit.createPanel({
		key = "Staff",
		title = "Staff",
		subtitle = "Build your team — every hire gives a bonus",
		icon = "👥",
		accent = "steel",
		maxSize = Vector2.new(760, 560),
	})

	local scroll = Kit.scroll({
		parent = panel.Body,
		name = "Content",
		size = UDim2.new(1, -8, 1, -10),
		paddingTop = 16,
		paddingBottom = 20,
		paddingLeft = 20,
		paddingRight = 8,
		spacing = 12,
	})
	Kit.scrollFade(scroll)

	-- ========================================================
	-- SUVESTINE
	-- ========================================================
	local summary = Kit.card({
		parent = scroll,
		name = "Summary",
		size = UDim2.new(1, 0, 0, 88),
		order = 1,
		strokeColor = C.steelBright,
		strokeTransparency = 0.55,
	})
	local summaryColumns = {}
	for index, def in ipairs({
		{ key = "team", caption = "TEAM" },
		{ key = "payroll", caption = "SALARIES" },
		{ key = "runway", caption = "BUDGET LASTS" },
	}) do
		local column = Kit.create("Frame", {
			Name = "Col_" .. def.key,
			BackgroundTransparency = 1,
			Size = UDim2.new(1 / 3, 0, 1, 0),
			Position = UDim2.new((index - 1) / 3, 0, 0, 0),
			Parent = summary,
		})
		Kit.padding(column, 16, 16, 14, 18)
		Kit.label({
			parent = column,
			name = "Caption",
			text = def.caption,
			bold = true,
			textSize = 12,
			color = C.textSecondary,
			size = UDim2.new(1, 0, 0, 14),
		})
		local value = Kit.label({
			parent = column,
			name = "Value",
			text = "-",
			bold = true,
			textSize = 22,
			size = UDim2.new(1, 0, 0, 26),
			position = UDim2.new(0, 0, 0, 18),
		})
		local sub = Kit.label({
			parent = column,
			name = "Sub",
			text = "",
			textSize = 12,
			color = C.textSecondary,
			size = UDim2.new(1, 0, 0, 14),
			position = UDim2.new(0, 0, 1, -14),
		})
		summaryColumns[def.key] = { value = value, sub = sub }
	end
	-- separatoriai tarp stulpeliu (column turi padding, todel dedame i summary)
	for index = 1, 2 do
		Kit.create("Frame", {
			Name = "Divider" .. index,
			BackgroundColor3 = C.border,
			BackgroundTransparency = 0.3,
			Size = UDim2.new(0, 1, 1, -28),
			Position = UDim2.new(index / 3, 0, 0, 14),
			Parent = summary,
		})
	end

	Kit.sectionHeader({ parent = scroll, title = "Hiring", order = 2, accent = C.steelBright })

	-- ========================================================
	-- DARBUOTOJU KORTELES
	-- ========================================================
	local roleCards = {}
	local confirmFire = {} -- roleId -> laikas, iki kada laukiama patvirtinimo
	local render -- forward (apibrezta zemiau)

	local function buildRoleCard(roleId, order, parent)
		local role = StaffConfig.Roles[roleId]
		if not role then
			return nil
		end
		local cardFrame, cardStroke = Kit.card({
			parent = parent,
			name = "Role_" .. roleId,
			size = UDim2.new(1, 0, 0, 76),
			order = order,
		})
		local iconTile = Kit.create("Frame", {
			Name = "IconTile",
			BackgroundColor3 = C.bgCardLight,
			Size = UDim2.new(0, 48, 0, 48),
			Position = UDim2.new(0, 16, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			Parent = cardFrame,
		})
		Kit.corner(iconTile, 12)
		local iconStroke = Kit.stroke(iconTile, C.border, 1, 0.3)
		Kit.label({
			parent = iconTile,
			name = "Icon",
			text = ROLE_ICONS[roleId] or "👤",
			textSize = 22,
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 1, 0),
		})
		-- Vardas + "Dirba" zenklelis vienoje eiluteje (zenklelis iskart uz vardo)
		local nameRow = Kit.create("Frame", {
			Name = "NameRow",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -290, 0, 22),
			Position = UDim2.new(0, 78, 0, 14),
			Parent = cardFrame,
		})
		Kit.list(nameRow, 8, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
		local nameLabel = Kit.label({
			parent = nameRow,
			name = "Name",
			text = role.label,
			bold = true,
			textSize = 15,
			size = UDim2.new(0, 0, 0, 20),
			autoSize = Enum.AutomaticSize.X,
			order = 1,
		})
		nameLabel.TextTruncate = Enum.TextTruncate.None
		local hiredBadge = Kit.badge({
			parent = nameRow,
			name = "Hired",
			text = "✓ Hired",
			color = C.gold,
			solid = true,
			height = 20,
			order = 2,
		})
		Kit.label({
			parent = cardFrame,
			name = "Description",
			text = highlightBonus(role.description, "#608EBC"), -- steelBright
			rich = true,
			textSize = 12,
			color = C.textSecondary,
			size = UDim2.new(1, -290, 0, 16),
			position = UDim2.new(0, 78, 0, 44),
		})
		Kit.label({
			parent = cardFrame,
			name = "Salary",
			text = string.format("Salary $%d / %d min", role.salary or 0, math.floor(StaffConfig.PayrollIntervalSeconds / 60)),
			textSize = 12,
			color = C.textSecondary,
			align = Enum.TextXAlignment.Right,
			size = UDim2.new(0, 170, 0, 14),
			position = UDim2.new(1, -16, 0, 10),
			anchor = Vector2.new(1, 0),
		})
		local actionButton = Kit.button({
			parent = cardFrame,
			name = "ActionButton",
			text = "Hire",
			variant = "gold",
			size = UDim2.new(0, 170, 0, 34),
			position = UDim2.new(1, -16, 1, -10),
			anchor = Vector2.new(1, 1),
			textSize = 13,
		})
		local entry = {
			roleId = roleId,
			role = role,
			card = cardFrame,
			stroke = cardStroke,
			iconStroke = iconStroke,
			name = nameLabel,
			hired = hiredBadge,
			button = actionButton,
		}
		actionButton.Instance.Activated:Connect(function()
			if not actionButton.IsEnabled() then
				return
			end
			local isHired = table.find(State.get().staff or {}, roleId) ~= nil
			if isHired then
				local now = os.clock()
				if confirmFire[roleId] and confirmFire[roleId] > now then
					confirmFire[roleId] = nil
					State.fire("FireStaffRequest", roleId)
				else
					confirmFire[roleId] = now + 3
					render()
					task.delay(3.05, function()
						if panel.IsOpen then
							render()
						end
					end)
				end
			else
				State.fire("HireStaffRequest", roleId)
			end
		end)
		roleCards[roleId] = entry
		return entry
	end

	for index, roleId in ipairs(StaffConfig.Order) do
		buildRoleCard(roleId, 10 + index, scroll)
	end

	-- Anksciau pasamdyti darbuotojai, kuriu nebera samdymo sarase (pvz. SpeedCoach, MentalCoach)
	local legacyHeader = Kit.sectionHeader({ parent = scroll, title = "Other staff", hint = "No longer for hire, still working", order = 50, accent = C.steelBright })
	local legacyEntries = {}
	for roleId in pairs(StaffConfig.Roles) do
		if not table.find(StaffConfig.Order, roleId) then
			legacyEntries[roleId] = buildRoleCard(roleId, 60, scroll)
		end
	end

	-- ========================================================
	-- ATVAIZDAVIMAS
	-- ========================================================
	render = function()
		local s = State.get()
		local staff = s.staff or {}
		local money = s.money or 0
		local now = os.clock()

		local totalSalary = 0
		for _, roleId in ipairs(staff) do
			local role = StaffConfig.Roles[roleId]
			totalSalary += role and role.salary or 0
		end
		local minutes = math.floor(StaffConfig.PayrollIntervalSeconds / 60)
		summaryColumns.team.value.Text = string.format("%d / %d", #staff, #StaffConfig.Order)
		summaryColumns.team.sub.Text = #staff == 0 and "Nobody hired yet" or "Staff hired"
		summaryColumns.payroll.value.Text = Kit.formatMoney(totalSalary)
		summaryColumns.payroll.sub.Text = string.format("every %d min", minutes)
		if totalSalary > 0 then
			local cycles = math.floor(money / totalSalary)
			summaryColumns.runway.value.Text = runwayText(cycles, StaffConfig.PayrollIntervalSeconds)
			summaryColumns.runway.value.TextColor3 = cycles < 3 and C.crimsonBright or (cycles < 10 and C.goldBright or C.textPrimary)
			summaryColumns.runway.sub.Text = cycles < 3 and "⚠ Staff quit if you can't pay" or "of salaries covered"
		else
			summaryColumns.runway.value.Text = "—"
			summaryColumns.runway.value.TextColor3 = C.textPrimary
			summaryColumns.runway.sub.Text = "No salaries"
		end

		local anyLegacy = false
		for roleId, entry in pairs(roleCards) do
			local isHired = table.find(staff, roleId) ~= nil
			local isLegacy = legacyEntries[roleId] ~= nil
			if isLegacy then
				entry.card.Visible = isHired
				anyLegacy = anyLegacy or isHired
			end
			entry.hired.Visible = isHired
			entry.stroke.Color = isHired and C.gold or C.border
			entry.stroke.Transparency = isHired and 0.3 or 0.45
			entry.iconStroke.Color = isHired and C.gold or C.border
			if isHired then
				local confirming = confirmFire[roleId] and confirmFire[roleId] > now
				entry.button.SetVariant(confirming and "crimson" or "ghost")
				entry.button.SetEnabled(true)
				entry.button.SetText(confirming and "Really fire?" or "Fire")
			else
				local cost = entry.role.hireCost or 0
				entry.button.SetVariant("gold")
				if money >= cost then
					entry.button.SetEnabled(true)
					entry.button.SetText("Hire  •  " .. Kit.formatMoney(cost))
				else
					entry.button.SetEnabled(false)
					entry.button.SetText("Need " .. Kit.formatMoney(cost - money))
				end
			end
		end
		legacyHeader.Visible = anyLegacy
	end

	local queued = false
	local function queueRender()
		if not panel.IsOpen or queued then
			return
		end
		queued = true
		task.defer(function()
			queued = false
			render()
		end)
	end
	State.subscribe("staff", queueRender)
	State.subscribe("money", queueRender)
	State.onMessage("staff", function(message)
		if panel.IsOpen then
			panel.Toast(message)
		end
	end)

	panel.OnOpen(function()
		render()
		State.refresh()
	end)

	return panel
end

return StaffPanel
