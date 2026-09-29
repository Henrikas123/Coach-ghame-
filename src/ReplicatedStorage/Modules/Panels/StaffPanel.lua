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

local FOCUS_LT = {
	Power = "Jėga",
	Speed = "Greitis",
	Defense = "Gynyba",
	Conditioning = "Kondicija",
	Technique = "Technika",
}

local function percent(multiplier)
	return math.floor(math.abs(multiplier - 1) * 100 + 0.5)
end

-- Trumpas bonuso aprasas badge'ui is config lauku
local function bonusSummary(role)
	local parts = {}
	if role.trainingMultiplier and role.focus then
		if #role.focus >= 5 then
			table.insert(parts, string.format("+%d%% visos treniruotės", percent(role.trainingMultiplier)))
		else
			local names = {}
			for _, focus in ipairs(role.focus) do
				table.insert(names, FOCUS_LT[focus] or focus)
			end
			table.insert(parts, string.format("+%d%% %s", percent(role.trainingMultiplier), table.concat(names, ", ")))
		end
	end
	if role.fatigueRecoveryMultiplier then
		table.insert(parts, string.format("+%d%% atsigavimas", percent(role.fatigueRecoveryMultiplier)))
	end
	if role.moraleDriftMultiplier then
		table.insert(parts, string.format("+%d%% nuotaika", percent(role.moraleDriftMultiplier)))
	end
	if role.scoutCostMultiplier then
		table.insert(parts, string.format("-%d%% paieškos kaina", percent(role.scoutCostMultiplier)))
	end
	if role.fatigueGainMultiplier then
		table.insert(parts, string.format("-%d%% nuovargis", percent(role.fatigueGainMultiplier)))
	end
	return table.concat(parts, "  •  ")
end

function StaffPanel.create(Kit, State)
	local C = Kit.Colors

	local panel = Kit.createPanel({
		key = "Staff",
		title = "Personalas",
		subtitle = "Samdyk komandą — kiekvienas darbuotojas duoda bonusą",
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
		{ key = "team", caption = "KOMANDA" },
		{ key = "payroll", caption = "ATLYGINIMAI" },
		{ key = "runway", caption = "BIUDŽETO UŽTENKA" },
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

	Kit.sectionHeader({ parent = scroll, title = "Samdymas", hint = "Atlyginimai nurašomi kas " .. math.floor(StaffConfig.PayrollIntervalSeconds / 60) .. " min", order = 2, accent = C.steelBright })

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
			size = UDim2.new(1, 0, 0, 92),
			order = order,
		})
		local iconTile = Kit.create("Frame", {
			Name = "IconTile",
			BackgroundColor3 = C.bgCardLight,
			Size = UDim2.new(0, 52, 0, 52),
			Position = UDim2.new(0, 16, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			Parent = cardFrame,
		})
		Kit.corner(iconTile, 13)
		local iconStroke = Kit.stroke(iconTile, C.border, 1, 0.3)
		Kit.label({
			parent = iconTile,
			name = "Icon",
			text = ROLE_ICONS[roleId] or "👤",
			textSize = 24,
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 1, 0),
		})
		local nameLabel = Kit.label({
			parent = cardFrame,
			name = "Name",
			text = role.label,
			bold = true,
			textSize = 15,
			size = UDim2.new(1, -300, 0, 20),
			position = UDim2.new(0, 82, 0, 14),
		})
		Kit.label({
			parent = cardFrame,
			name = "Description",
			text = role.description or "",
			textSize = 12,
			color = C.textSecondary,
			size = UDim2.new(1, -300, 0, 16),
			position = UDim2.new(0, 82, 0, 36),
		})
		Kit.badge({
			parent = cardFrame,
			name = "Bonus",
			text = bonusSummary(role),
			color = C.steelBright,
			position = UDim2.new(0, 82, 0, 58),
		})
		local hiredBadge = Kit.badge({
			parent = cardFrame,
			name = "Hired",
			text = "✓ DIRBA",
			color = C.gold,
			solid = true,
			anchor = Vector2.new(1, 0),
			position = UDim2.new(1, -196, 0, 14),
		})
		Kit.label({
			parent = cardFrame,
			name = "Salary",
			text = string.format("Atlyginimas $%d / %d min", role.salary or 0, math.floor(StaffConfig.PayrollIntervalSeconds / 60)),
			textSize = 12,
			color = C.textSecondary,
			align = Enum.TextXAlignment.Right,
			size = UDim2.new(0, 170, 0, 14),
			position = UDim2.new(1, -16, 0, 16),
			anchor = Vector2.new(1, 0),
		})
		local actionButton = Kit.button({
			parent = cardFrame,
			name = "ActionButton",
			text = "Samdyti",
			variant = "gold",
			size = UDim2.new(0, 170, 0, 36),
			position = UDim2.new(1, -16, 1, -14),
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
	local legacyHeader = Kit.sectionHeader({ parent = scroll, title = "Kiti darbuotojai", hint = "Nebesamdomi, bet dar dirba", order = 50, accent = C.steelBright })
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
		summaryColumns.team.sub.Text = #staff == 0 and "Dar niekas nedirba" or "Pasamdyti darbuotojai"
		summaryColumns.payroll.value.Text = Kit.formatMoney(totalSalary)
		summaryColumns.payroll.sub.Text = string.format("kas %d min", minutes)
		if totalSalary > 0 then
			local cycles = math.floor(money / totalSalary)
			summaryColumns.runway.value.Text = cycles >= 100 and "100+ ciklų" or string.format("%d ciklų", cycles)
			summaryColumns.runway.value.TextColor3 = cycles < 3 and C.crimsonBright or (cycles < 10 and C.goldBright or C.textPrimary)
			summaryColumns.runway.sub.Text = cycles < 3 and "⚠ Trūkstant pinigų darbuotojai išeis" or string.format("≈ %d min atlyginimų", cycles * minutes)
		else
			summaryColumns.runway.value.Text = "—"
			summaryColumns.runway.value.TextColor3 = C.textPrimary
			summaryColumns.runway.sub.Text = "Nėra atlyginimų"
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
				entry.button.SetText(confirming and "Tikrai atleisti?" or "Atleisti")
			else
				local cost = entry.role.hireCost or 0
				entry.button.SetVariant("gold")
				if money >= cost then
					entry.button.SetEnabled(true)
					entry.button.SetText("Samdyti  •  " .. Kit.formatMoney(cost))
				else
					entry.button.SetEnabled(false)
					entry.button.SetText("Trūksta " .. Kit.formatMoney(cost - money))
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
