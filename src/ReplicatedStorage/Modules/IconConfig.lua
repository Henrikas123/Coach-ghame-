--[[
	IconConfig
	HUD icons. PNG files are in the repository folder assets/icons/ (gold line icons, 256x256).
	Upload them to Roblox (Studio: View > Asset Manager > Bulk Import, or Creator Hub > Decals)
	and paste the image id into `image` ("rbxassetid://1234567890").
	While `image` is empty the emoji is shown instead, so the HUD always works.
]]

local IconConfig = {}

IconConfig.Icons = {
	Profile = { image = "", emoji = "👤", file = "profile.png" },
	Academy = { image = "", emoji = "🏛", file = "academy.png" },
	Staff = { image = "", emoji = "👥", file = "staff.png" },
	Scout = { image = "", emoji = "🔎", file = "scout.png" },
	Sponsor = { image = "", emoji = "🤝", file = "sponsor.png" },
	Tournament = { image = "", emoji = "🏆", file = "tournament.png" },
	Phone = { image = "", emoji = "📱", file = "phone.png" },
	Money = { image = "", emoji = "💰", file = "money.png" },
	Belt = { image = "", emoji = "🥇", file = "belt.png" },
	Glove = { image = "", emoji = "🥊", file = "glove.png" },
}

-- Creates an ImageLabel (uploaded icon) or an emoji TextLabel inside `parent`
function IconConfig.make(parent, name, props)
	local def = IconConfig.Icons[name] or { emoji = "•" }
	props = props or {}
	local icon
	if type(def.image) == "string" and def.image ~= "" then
		icon = Instance.new("ImageLabel")
		icon.Image = def.image
		icon.ImageColor3 = props.color or Color3.new(1, 1, 1)
		icon.ScaleType = Enum.ScaleType.Fit
	else
		icon = Instance.new("TextLabel")
		icon.Text = def.emoji
		icon.TextSize = props.textSize or 20
		icon.Font = Enum.Font.Gotham
		icon.TextColor3 = Color3.new(1, 1, 1)
	end
	icon.Name = props.name or "Icon"
	icon.BackgroundTransparency = 1
	icon.Size = props.size or UDim2.new(0, 22, 0, 22)
	icon.Position = props.position or UDim2.new()
	icon.AnchorPoint = props.anchor or Vector2.new(0, 0)
	icon.ZIndex = props.zIndex or 1
	icon.Parent = parent
	return icon
end

return IconConfig
