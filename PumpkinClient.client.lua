-- PumpkinClient.client.lua
-- Full client rewrite for the interactive Halloween carnival tycoon
-- Place in StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")

local CLICK_SOUND_ID = 0

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local ls = player:WaitForChild("leaderstats")
local pumpkins = ls:WaitForChild("Pumpkins")
local seasons = ls:WaitForChild("Seasons")

local PETS = HttpService:JSONDecode(ReplicatedStorage:WaitForChild("PetData").Value)
local PET_BY_ID = {}
for _, p in ipairs(PETS) do
    PET_BY_ID[p.id] = p
end

local V3 = Vector3.new
local C3 = Color3.fromRGB
local ORANGE = C3(255, 120, 20)
local PURPLE = C3(120, 60, 170)
local GREEN = C3(60, 160, 80)
local GOLD = C3(240, 160, 30)
local BLOOD = C3(190, 40, 50)
local BLUE = C3(60, 120, 200)
local GREY = C3(75, 70, 85)
local DARK = C3(25, 18, 35)
local LIGHT = C3(220, 205, 230)

local RARITY_COLORS = {
    Common = C3(190, 190, 200),
    Uncommon = C3(90, 210, 100),
    Rare = C3(80, 150, 255),
    Epic = C3(185, 95, 255),
    Legendary = C3(255, 190, 40),
}

---------------------------------------------------------------------
-- Base GUI
---------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "PumpkinUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local uiScale = Instance.new("UIScale")
uiScale.Parent = gui

local function updateScale()
    local cam = workspace.CurrentCamera
    if cam then
        uiScale.Scale = math.clamp(cam.ViewportSize.Y / 800, 0.55, 1)
    end
end
updateScale()
if workspace.CurrentCamera then
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

local function corner(inst, px)
    local c = Instance.new("UICorner")
    c.CornerRadius = px and UDim.new(0, px) or UDim.new(1, 0)
    c.Parent = inst
end

local function stroke(inst, thickness)
    local s = Instance.new("UIStroke")
    s.Thickness = thickness or 2
    s.Color = DARK
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = inst
    return s
end

local function mkLabel(parent, text, size, pos, font, color)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Text = text
    l.Size = size
    l.Position = pos or UDim2.new()
    l.Font = font or Enum.Font.GothamBold
    l.TextColor3 = color or Color3.new(1, 1, 1)
    l.TextScaled = true
    l.Parent = parent
    return l
end

local function mkButton(parent, color, size, order)
    local b = Instance.new("TextButton")
    b.Size = size
    b.BackgroundColor3 = color
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.FredokaOne
    b.TextScaled = true
    b.LayoutOrder = order or 0
    b.Parent = parent
    corner(b, 10)
    stroke(b)
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 5)
    pad.PaddingBottom = UDim.new(0, 5)
    pad.PaddingLeft = UDim.new(0, 8)
    pad.PaddingRight = UDim.new(0, 8)
    pad.Parent = b
    return b
end

local function setAffordable(btn, color, ok)
    btn.BackgroundColor3 = ok and color or GREY
    btn.TextTransparency = ok and 0 or 0.35
end

---------------------------------------------------------------------
-- Top HUD
---------------------------------------------------------------------
local counter = Instance.new("TextLabel")
counter.Size = UDim2.fromOffset(340, 64)
counter.AnchorPoint = Vector2.new(0.5, 0)
counter.Position = UDim2.new(0.5, 0, 0, 14)
counter.BackgroundColor3 = DARK
counter.BackgroundTransparency = 0.15
counter.TextColor3 = ORANGE
counter.Font = Enum.Font.Creepster
counter.TextScaled = true
counter.Parent = gui
corner(counter, 14)
stroke(counter, 3).Color = ORANGE

local info = mkLabel(gui, "", UDim2.fromOffset(520, 26), UDim2.new(0.5, -260, 0, 84))
local infoStroke = Instance.new("UIStroke")
infoStroke.Thickness = 2
infoStroke.Color = DARK
infoStroke.Parent = info

local toast = Instance.new("TextLabel")
toast.Size = UDim2.fromOffset(520, 40)
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 0, 118)
toast.BackgroundColor3 = PURPLE
toast.BackgroundTransparency = 0.1
toast.TextColor3 = Color3.new(1, 1, 1)
toast.Font = Enum.Font.GothamBold
toast.TextScaled = true
toast.Visible = false
toast.Parent = gui
corner(toast, 10)
stroke(toast, 2)

local frenzyLabel = Instance.new("TextLabel")
frenzyLabel.Size = UDim2.fromOffset(340, 40)
frenzyLabel.AnchorPoint = Vector2.new(0.5, 0)
frenzyLabel.Position = UDim2.new(0.5, 0, 0, 164)
frenzyLabel.BackgroundColor3 = BLOOD
frenzyLabel.BackgroundTransparency = 0.1
frenzyLabel.TextColor3 = Color3.new(1, 1, 1)
frenzyLabel.Font = Enum.Font.FredokaOne
frenzyLabel.TextScaled = true
frenzyLabel.Visible = false
frenzyLabel.Parent = gui
corner(frenzyLabel, 10)
stroke(frenzyLabel, 2)

---------------------------------------------------------------------
-- Side columns
---------------------------------------------------------------------
local function makeColumn(anchorX, posX, align)
    local f = Instance.new("Frame")
    f.Size = UDim2.fromOffset(240, 0)
    f.AutomaticSize = Enum.AutomaticSize.Y
    f.AnchorPoint = Vector2.new(anchorX, 0.5)
    f.Position = UDim2.new(anchorX, posX, 0.5, 0)
    f.BackgroundTransparency = 1
    f.Parent = gui
    local l = Instance.new("UIListLayout")
    l.Padding = UDim.new(0, 8)
    l.HorizontalAlignment = align
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Parent = f
    return f
end

local rightCol = makeColumn(1, -12, Enum.HorizontalAlignment.Right)
local leftCol = makeColumn(0, 12, Enum.HorizontalAlignment.Left)

local upgradeBtn = mkButton(rightCol, GREEN, UDim2.fromOffset(240, 58), 1)
local buildBtn = mkButton(rightCol, PURPLE, UDim2.fromOffset(240, 58), 2)
local rebirthBtn = mkButton(rightCol, BLOOD, UDim2.fromOffset(240, 58), 3)

local petsBtn = mkButton(leftCol, PURPLE, UDim2.fromOffset(180, 54), 1)
local dailyBtn = mkButton(leftCol, GOLD, UDim2.fromOffset(180, 58), 2)
local codesBtn = mkButton(leftCol, BLUE, UDim2.fromOffset(180, 54), 3)
local shopBtn = mkButton(leftCol, ORANGE, UDim2.fromOffset(180, 54), 4)
petsBtn.Text = "🐾 Pets"
codesBtn.Text = "🏷️ Codes"
shopBtn.Text = "🛒 Shop"

---------------------------------------------------------------------
-- Modals
---------------------------------------------------------------------
local modals = {}
local function closeAll()
    for _, m in ipairs(modals) do
        m.Visible = false
    end
end

local function toggleModal(f)
    local v = not f.Visible
    closeAll()
    f.Visible = v
end

local function makeModal(title, w, h)
    local f = Instance.new("Frame")
    f.Size = UDim2.fromOffset(w, h)
    f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.Position = UDim2.fromScale(0.5, 0.46)
    f.BackgroundColor3 = DARK
    f.Visible = false
    f.Parent = gui
    corner(f, 16)
    stroke(f, 3).Color = ORANGE

    local t = mkLabel(f, title, UDim2.fromOffset(w - 100, 44), UDim2.fromOffset(20, 8), Enum.Font.Creepster, ORANGE)
    t.TextXAlignment = Enum.TextXAlignment.Left

    local x = mkButton(f, BLOOD, UDim2.fromOffset(40, 40), 0)
    x.Position = UDim2.new(1, -50, 0, 8)
    x.Text = "X"
    x.Activated:Connect(function()
        f.Visible = false
    end)

    table.insert(modals, f)
    return f
end

local petsModal = makeModal("🐾 Trick-or-Treat Pets", 560, 430)
local petBonusLabel = mkLabel(petsModal, "", UDim2.fromOffset(520, 26), UDim2.fromOffset(20, 54))
local grid = Instance.new("Frame")
grid.Size = UDim2.fromOffset(536, 216)
grid.Position = UDim2.fromOffset(12, 88)
grid.BackgroundTransparency = 1
grid.Parent = petsModal
local gl = Instance.new("UIGridLayout")
gl.CellSize = UDim2.fromOffset(125, 100)
gl.CellPadding = UDim2.fromOffset(8, 8)
gl.SortOrder = Enum.SortOrder.LayoutOrder
gl.Parent = grid

local petCards = {}
for i, pet in ipairs(PETS) do
    local card = Instance.new("Frame")
    card.BackgroundColor3 = C3(45, 32, 62)
    card.LayoutOrder = i
    card.Parent = grid
    corner(card, 10)
    local st = stroke(card, 2)
    st.Color = RARITY_COLORS[pet.rarity] or GREY

    local nameL = mkLabel(card, pet.name, UDim2.new(1, -8, 0.32, 0), UDim2.new(0, 4, 0, 4), Enum.Font.FredokaOne, RARITY_COLORS[pet.rarity])
    local rarL = mkLabel(card, pet.rarity, UDim2.new(1, -8, 0.18, 0), UDim2.new(0, 4, 0.34, 0), Enum.Font.GothamBold, Color3.new(1, 1, 1))
    local bonusL = mkLabel(card, "", UDim2.new(1, -8, 0.22, 0), UDim2.new(0, 4, 0.54, 0), Enum.Font.GothamBold, C3(255, 200, 120))
    local countL = mkLabel(card, "", UDim2.new(1, -8, 0.2, 0), UDim2.new(0, 4, 0.78, 0), Enum.Font.GothamBold, Color3.new(1, 1, 1))
    bonusL.Text = string.format("+%d%% earnings", math.floor(pet.bonus * 100 + 0.5))
    petCards[pet.id] = { card = card, name = nameL, count = countL }
end

local hatchBtn = mkButton(petsModal, ORANGE, UDim2.fromOffset(330, 62), 0)
hatchBtn.AnchorPoint = Vector2.new(0.5, 0)
hatchBtn.Position = UDim2.new(0.5, 0, 0, 318)
local petTip = mkLabel(petsModal, "Your best 3 pets are equipped automatically and follow you!", UDim2.fromOffset(520, 24), UDim2.fromOffset(20, 390), Enum.Font.Gotham, C3(200, 190, 220))

local shopModal = makeModal("🛒 Spooky Shop", 440, 390)
local shopList = Instance.new("Frame")
shopList.Size = UDim2.fromOffset(400, 300)
shopList.Position = UDim2.fromOffset(20, 66)
shopList.BackgroundTransparency = 1
shopList.Parent = shopModal
local sl = Instance.new("UIListLayout")
sl.Padding = UDim.new(0, 8)
sl.SortOrder = Enum.SortOrder.LayoutOrder
sl.Parent = shopList
local passBtn = mkButton(shopList, GOLD, UDim2.fromOffset(400, 66), 1)
local autoBtn = mkButton(shopList, BLUE, UDim2.fromOffset(400, 66), 2)
local packBtn = mkButton(shopList, ORANGE, UDim2.fromOffset(400, 66), 3)
local luckyBtn = mkButton(shopList, PURPLE, UDim2.fromOffset(400, 66), 4)

local codesModal = makeModal("🏷️ Redeem Code", 420, 230)
local codeBox = Instance.new("TextBox")
codeBox.Size = UDim2.fromOffset(360, 52)
codeBox.Position = UDim2.fromOffset(30, 72)
codeBox.BackgroundColor3 = C3(45, 32, 62)
codeBox.TextColor3 = Color3.new(1, 1, 1)
codeBox.PlaceholderText = "Enter code here"
codeBox.PlaceholderColor3 = C3(150, 140, 170)
codeBox.Text = ""
codeBox.ClearTextOnFocus = false
codeBox.Font = Enum.Font.FredokaOne
codeBox.TextScaled = true
codeBox.Parent = codesModal
corner(codeBox, 10)
stroke(codeBox, 2)
local redeemBtn = mkButton(codesModal, GREEN, UDim2.fromOffset(360, 52), 0)
redeemBtn.Position = UDim2.fromOffset(30, 140)
redeemBtn.Text = "Redeem"

---------------------------------------------------------------------
-- Big pumpkin click button + floating text
---------------------------------------------------------------------
local clickBtn = Instance.new("TextButton")
clickBtn.Size = UDim2.fromOffset(170, 170)
clickBtn.AnchorPoint = Vector2.new(0.5, 1)
clickBtn.Position = UDim2.new(0.5, 0, 1, -20)
clickBtn.BackgroundColor3 = ORANGE
clickBtn.Text = "🎃"
clickBtn.TextScaled = true
clickBtn.Parent = gui
corner(clickBtn)
stroke(clickBtn, 5)

local clickSound
if CLICK_SOUND_ID ~= 0 then
    clickSound = Instance.new("Sound")
    clickSound.SoundId = "rbxassetid://" .. CLICK_SOUND_ID
    clickSound.Volume = 0.5
    clickSound.Parent = gui
end

local function pop()
    clickBtn.Size = UDim2.fromOffset(150, 150)
    TweenService:Create(
        clickBtn,
        TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Size = UDim2.fromOffset(170, 170) }
    ):Play()
end

local function floatText(text)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Text = text
    l.Font = Enum.Font.FredokaOne
    l.TextScaled = true
    l.TextColor3 = C3(255, 190, 80)
    l.Size = UDim2.fromOffset(120, 36)
    l.AnchorPoint = Vector2.new(0.5, 0.5)
    local x = math.random(-70, 70)
    l.Position = UDim2.new(0.5, x, 1, -230)
    l.Parent = gui
    local st = Instance.new("UIStroke")
    st.Thickness = 2
    st.Color = DARK
    st.Parent = l
    local ti = TweenInfo.new(0.8)
    TweenService:Create(l, ti, { Position = UDim2.new(0.5, x, 1, -310), TextTransparency = 1 }):Play()
    TweenService:Create(st, ti, { Transparency = 1 }):Play()
    Debris:AddItem(l, 0.9)
end

---------------------------------------------------------------------
-- Pet hatch popup
---------------------------------------------------------------------
local popup = Instance.new("Frame")
popup.Size = UDim2.fromOffset(380, 240)
popup.AnchorPoint = Vector2.new(0.5, 0.5)
popup.Position = UDim2.fromScale(0.5, 0.4)
popup.BackgroundColor3 = DARK
popup.Visible = false
popup.ZIndex = 10
popup.Parent = gui
corner(popup, 18)
local popupStroke = stroke(popup, 5)
local popupScale = Instance.new("UIScale")
popupScale.Parent = popup
local popupTitle = mkLabel(popup, "🥚 NEW PET!", UDim2.new(1, -20, 0.22, 0), UDim2.new(0, 10, 0.05, 0), Enum.Font.Creepster, ORANGE)
local popupName = mkLabel(popup, "", UDim2.new(1, -20, 0.3, 0), UDim2.new(0, 10, 0.3, 0), Enum.Font.FredokaOne)
local popupRarity = mkLabel(popup, "", UDim2.new(1, -20, 0.14, 0), UDim2.new(0, 10, 0.62, 0), Enum.Font.GothamBold)
local popupBonus = mkLabel(popup, "", UDim2.new(1, -20, 0.14, 0), UDim2.new(0, 10, 0.78, 0), Enum.Font.GothamBold, C3(255, 200, 120))
for _, l in ipairs({ popupTitle, popupName, popupRarity, popupBonus }) do
    l.ZIndex = 11
end

local popupToken = 0
remotes.PetHatched.OnClientEvent:Connect(function(id)
    local pet = PET_BY_ID[id]
    if not pet then return end
    local col = RARITY_COLORS[pet.rarity] or Color3.new(1, 1, 1)
    popupToken += 1
    local token = popupToken
    popupName.Text = pet.name
    popupName.TextColor3 = col
    popupRarity.Text = pet.rarity:upper()
    popupRarity.TextColor3 = col
    popupBonus.Text = string.format("+%d%% earnings", math.floor(pet.bonus * 100 + 0.5))
    popupStroke.Color = col
    popupScale.Scale = 0.2
    popup.Visible = true
    TweenService:Create(popupScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
    task.delay(3, function()
        if popupToken == token then
            popup.Visible = false
        end
    end)
end)

---------------------------------------------------------------------
-- Formatting / state sync
---------------------------------------------------------------------
local function fmt(n)
    local suffixes = { "", "K", "M", "B", "T", "Qa" }
    local i = 1
    while n >= 1000 and i < #suffixes do
        n /= 1000
        i += 1
    end
    if i == 1 then
        return tostring(math.floor(n))
    end
    return string.format("%.1f%s", n, suffixes[i])
end

local function fmtTime(s)
    s = math.max(0, math.floor(s))
    return string.format("%02d:%02d:%02d", s // 3600, (s % 3600) // 60, s % 60)
end

local function parseCounts()
    local counts = {}
    local s = player:GetAttribute("PetCounts") or ""
    for entry in string.gmatch(s, "[^,]+") do
        local id, n = string.match(entry, "(.+):(%d+)")
        if id then
            counts[id] = tonumber(n)
        end
    end
    return counts
end

local function updateDaily()
    local readyAt = player:GetAttribute("DailyReadyAt") or 0
    local day = player:GetAttribute("DailyDay") or 1
    local left = readyAt - workspace:GetServerTimeNow()
    if left <= 0 then
        dailyBtn.Text = "🎁 Daily Day " .. day .. "\nCLAIM NOW!"
        setAffordable(dailyBtn, GOLD, true)
    else
        dailyBtn.Text = "🎁 Daily Reward\n" .. fmtTime(left)
        setAffordable(dailyBtn, GOLD, false)
    end
end

local function update()
    local p = pumpkins.Value
    local perClick = player:GetAttribute("PerClick") or 1
    local income = player:GetAttribute("Income") or 0
    local upCost = player:GetAttribute("UpgradeCost") or 25
    local built = player:GetAttribute("Built") or 0
    local total = player:GetAttribute("TotalAttractions") or 7
    local nextName = player:GetAttribute("NextName") or ""
    local nextCost = player:GetAttribute("NextCost") or 0
    local reCost = player:GetAttribute("RebirthCost") or 2000000
    local eggCost = player:GetAttribute("EggCost") or 1500
    local petBonus = player:GetAttribute("PetBonus") or 0
    local s = seasons.Value

    counter.Text = "🎃 " .. fmt(p)
    info.Text = string.format("+%s/click   +%s/sec   Attractions %d/%d   Season %d", fmt(perClick), fmt(income), built, total, s + 1)

    upgradeBtn.Text = "Bigger Pumpkins\n" .. fmt(upCost) .. " 🎃"
    setAffordable(upgradeBtn, GREEN, p >= upCost)

    if built < total then
        buildBtn.Text = "Build: " .. nextName .. "\n" .. fmt(nextCost) .. " 🎃"
        setAffordable(buildBtn, PURPLE, p >= nextCost)
    else
        buildBtn.Text = "Carnival complete! 🎪"
        setAffordable(buildBtn, PURPLE, false)
    end

    if built >= total then
        rebirthBtn.Text = "New Season (x" .. (s + 2) .. ")\n" .. fmt(reCost) .. " 🎃"
        setAffordable(rebirthBtn, BLOOD, p >= reCost)
    else
        rebirthBtn.Text = "New Season\nBuild everything first"
        setAffordable(rebirthBtn, BLOOD, false)
    end

    petBonusLabel.Text = string.format("Equipped pets give +%d%% earnings", math.floor(petBonus * 100 + 0.5))
    hatchBtn.Text = "Hatch Egg 🥚\n" .. fmt(eggCost) .. " 🎃"
    setAffordable(hatchBtn, ORANGE, p >= eggCost)

    local counts = parseCounts()
    for id, c in pairs(petCards) do
        local n = counts[id] or 0
        c.count.Text = n > 0 and ("Owned x" .. n) or "???"
        c.card.BackgroundTransparency = n > 0 and 0 or 0.45
    end

    passBtn.Text = player:GetAttribute("Has2x") and "2x Pumpkins: OWNED ✅" or "2x Pumpkins (Robux)\nDoubles clicks AND income!"
    autoBtn.Text = player:GetAttribute("HasAuto") and "Auto Clicker: OWNED ✅" or "Auto Clicker (Robux)\nFree clicks every second!"
    packBtn.Text = "Pumpkin Pack (Robux)\n+" .. fmt(player:GetAttribute("PackAmount") or 500) .. " 🎃 instantly"
    luckyBtn.Text = "Lucky Egg (Robux)\nGuaranteed Epic or Legendary pet!"

    updateDaily()
end

pumpkins.Changed:Connect(update)
seasons.Changed:Connect(update)
for _, attr in ipairs({
    "PerClick", "Income", "UpgradeCost", "Built", "TotalAttractions",
    "NextName", "NextCost", "RebirthCost", "PackAmount", "Has2x", "HasAuto",
    "EggCost", "PetBonus", "PetCounts", "DailyReadyAt", "DailyDay",
}) do
    player:GetAttributeChangedSignal(attr):Connect(update)
end
update()

-- 4x per second: daily countdown + frenzy banner
task.spawn(function()
    while true do
        local fe = player:GetAttribute("FrenzyEnd") or 0
        local left = fe - workspace:GetServerTimeNow()
        if left > 0 then
            frenzyLabel.Visible = true
            frenzyLabel.Text = string.format("🔥 CANDY FRENZY x3 - %ds", math.ceil(left))
        else
            frenzyLabel.Visible = false
        end
        updateDaily()
        task.wait(0.25)
    end
end)

---------------------------------------------------------------------
-- Button actions
---------------------------------------------------------------------
clickBtn.Activated:Connect(function()
    pop()
    floatText("+" .. fmt(player:GetAttribute("PerClick") or 1))
    if clickSound then clickSound:Play() end
    remotes.Collect:FireServer()
end)

upgradeBtn.Activated:Connect(function() remotes.Upgrade:FireServer() end)
buildBtn.Activated:Connect(function() remotes.Build:FireServer() end)
rebirthBtn.Activated:Connect(function() remotes.Rebirth:FireServer() end)
hatchBtn.Activated:Connect(function() remotes.Hatch:FireServer() end)
dailyBtn.Activated:Connect(function() remotes.ClaimDaily:FireServer() end)

petsBtn.Activated:Connect(function() toggleModal(petsModal) end)
shopBtn.Activated:Connect(function() toggleModal(shopModal) end)
codesBtn.Activated:Connect(function() toggleModal(codesModal) end)

passBtn.Activated:Connect(function() remotes.PromptPurchase:FireServer("pass") end)
autoBtn.Activated:Connect(function() remotes.PromptPurchase:FireServer("auto") end)
packBtn.Activated:Connect(function() remotes.PromptPurchase:FireServer("pack") end)
luckyBtn.Activated:Connect(function() remotes.PromptPurchase:FireServer("lucky") end)

redeemBtn.Activated:Connect(function()
    remotes.RedeemCode:FireServer(codeBox.Text)
    codeBox.Text = ""
end)

remotes.Popup.OnClientEvent:Connect(function(amount)
    floatText("+" .. fmt(amount))
end)

local toastId = 0
remotes.Notify.OnClientEvent:Connect(function(text)
    toastId += 1
    local id = toastId
    toast.Text = text
    toast.Visible = true
    task.delay(4, function()
        if toastId == id then
            toast.Visible = false
        end
    end)
end)

---------------------------------------------------------------------
-- Pet followers
---------------------------------------------------------------------
local BALL = Enum.PartType.Ball
local NEON = Enum.Material.Neon
local BLACKC = C3(15, 12, 20)

local function mkPart(parent, size, cf, color, material, shape)
    local p = Instance.new("Part")
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.Size = size
    p.CFrame = cf
    p.Color = color
    p.Material = material or Enum.Material.SmoothPlastic
    if shape then
        p.Shape = shape
    end
    p.Parent = parent
    return p
end

local function eyes(m, y, z, spread, size, color, material)
    for _, s in ipairs({ -1, 1 }) do
        mkPart(m, V3(size, size, size), CFrame.new(s * spread, y, z), color, material, BALL)
    end
end

local PET_BUILDERS = {}

PET_BUILDERS.ghost = function(m)
    local body = mkPart(m, V3(2, 2, 2), CFrame.new(), C3(240, 240, 255), nil, BALL)
    body.Transparency = 0.1
    m.PrimaryPart = body
    eyes(m, 0.2, -0.85, 0.4, 0.35, BLACKC)
    mkPart(m, V3(0.5, 0.3, 0.2), CFrame.new(0, -0.35, -0.92), BLACKC)
end

PET_BUILDERS.bat = function(m)
    local body = mkPart(m, V3(1.4, 1.4, 1.4), CFrame.new(), C3(60, 35, 90), nil, BALL)
    m.PrimaryPart = body
    for _, s in ipairs({ -1, 1 }) do
        mkPart(m, V3(1.8, 0.12, 1), CFrame.new(s * 1.2, 0.2, 0.2) * CFrame.Angles(0, 0, s * math.rad(-20)), C3(40, 25, 60))
        mkPart(m, V3(0.25, 0.4, 0.2), CFrame.new(s * 0.35, 0.8, 0), C3(60, 35, 90))
    end
    eyes(m, 0.15, -0.6, 0.25, 0.22, C3(255, 40, 40), NEON)
end

PET_BUILDERS.cat = function(m)
    local body = mkPart(m, V3(1.8, 1.8, 1.8), CFrame.new(), C3(25, 25, 30), nil, BALL)
    m.PrimaryPart = body
    for _, s in ipairs({ -1, 1 }) do
        mkPart(m, V3(0.5, 0.5, 0.25), CFrame.new(s * 0.5, 0.85, 0) * CFrame.Angles(0, 0, math.rad(45)), C3(25, 25, 30))
    end
    eyes(m, 0.15, -0.78, 0.35, 0.3, C3(255, 230, 60), NEON)
    mkPart(m, V3(0.2, 0.15, 0.15), CFrame.new(0, -0.05, -0.88), C3(255, 140, 160))
    mkPart(m, V3(0.2, 0.2, 1.2), CFrame.new(0, -0.2, 1.1), C3(25, 25, 30))
end

PET_BUILDERS.skelly = function(m)
    local head = mkPart(m, V3(1.9, 1.9, 1.9), CFrame.new(), C3(235, 230, 215), nil, BALL)
    m.PrimaryPart = head
    eyes(m, 0.15, -0.78, 0.4, 0.5, BLACKC)
    mkPart(m, V3(0.9, 0.18, 0.2), CFrame.new(0, -0.45, -0.82), BLACKC)
end

PET_BUILDERS.mummy = function(m)
    local body = mkPart(m, V3(1.8, 1.8, 1.8), CFrame.new(), C3(215, 200, 160), nil, BALL)
    m.PrimaryPart = body
    for _, y in ipairs({ -0.4, -0.1, 0.2 }) do
        local r = math.sqrt(0.81 - y * y) + 0.03
        mkPart(m, V3(0.14, r * 2, r * 2), CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90)), C3(175, 160, 120), nil, Enum.PartType.Cylinder)
    end
    eyes(m, 0.45, -0.72, 0.3, 0.28, BLACKC)
end

PET_BUILDERS.frank = function(m)
    local head = mkPart(m, V3(1.7, 1.7, 1.7), CFrame.new(), C3(110, 180, 90))
    m.PrimaryPart = head
    mkPart(m, V3(1.8, 0.4, 1.8), CFrame.new(0, 0.95, 0), C3(30, 30, 35))
    for _, s in ipairs({ -1, 1 }) do
        mkPart(m, V3(0.5, 0.3, 0.3), CFrame.new(s * 1.0, -0.1, 0), C3(150, 150, 160), nil, Enum.PartType.Cylinder)
        mkPart(m, V3(0.3, 0.3, 0.1), CFrame.new(s * 0.4, 0.25, -0.87), C3(255, 230, 60), NEON)
    end
    mkPart(m, V3(0.9, 0.12, 0.1), CFrame.new(0, -0.45, -0.86), BLACKC)
end

PET_BUILDERS.vampire = function(m)
    local body = mkPart(m, V3(1.8, 1.8, 1.8), CFrame.new(), C3(60, 20, 70), nil, BALL)
    m.PrimaryPart = body
    mkPart(m, V3(2, 1.4, 0.15), CFrame.new(0, -0.1, 0.95), C3(170, 25, 40))
    eyes(m, 0.2, -0.78, 0.35, 0.28, C3(255, 40, 40), NEON)
    for _, s in ipairs({ -1, 1 }) do
        mkPart(m, V3(0.12, 0.3, 0.1), CFrame.new(s * 0.18, -0.45, -0.82), Color3.new(1, 1, 1))
    end
    local light = Instance.new("PointLight")
    light.Color = C3(180, 80, 255)
    light.Range = 8
    light.Parent = body
end

PET_BUILDERS.dragon = function(m)
    local body = mkPart(m, V3(2.4, 2.4, 2.4), CFrame.new(), ORANGE, nil, BALL)
    m.PrimaryPart = body
    local head = mkPart(m, V3(1.5, 1.5, 1.5), CFrame.new(0, 0.8, -1.2), ORANGE, nil, BALL)
    for _, s in ipairs({ -1, 1 }) do
        mkPart(m, V3(2.4, 0.15, 1.4), CFrame.new(s * 1.9, 0.7, 0.4) * CFrame.Angles(0, 0, s * math.rad(-15)), C3(150, 40, 20))
        mkPart(m, V3(0.2, 0.6, 0.2), CFrame.new(s * 0.45, 1.7, -1.2), BLACKC)
        mkPart(m, V3(0.3, 0.3, 0.3), CFrame.new(s * 0.4, 1.0, -1.85), C3(255, 240, 80), NEON, BALL)
    end
    mkPart(m, V3(0.4, 0.4, 1.8), CFrame.new(0, -0.3, 1.7), C3(200, 70, 20))
    local light = Instance.new("PointLight")
    light.Color = ORANGE
    light.Range = 14
    light.Brightness = 2
    light.Parent = body
    local fire = Instance.new("ParticleEmitter")
    fire.Color = ColorSequence.new(C3(255, 170, 40), C3(255, 60, 20))
    fire.Size = NumberSequence.new(0.8, 0)
    fire.Lifetime = NumberRange.new(0.5, 0.9)
    fire.Speed = NumberRange.new(2, 4)
    fire.Rate = 18
    fire.LightEmission = 1
    fire.Parent = head
end

local petFolder = Instance.new("Folder")
petFolder.Name = "ClientPets"
petFolder.Parent = workspace

local rigs = {}
local OFFSETS = { V3(-3, 0, 3.5), V3(3, 0, 3.5), V3(0, 0, 6.5) }

local function clearRig(plr)
    local r = rigs[plr]
    if r then
        for _, m in ipairs(r.models) do
            m:Destroy()
        end
        rigs[plr] = nil
    end
end

local function syncRig(plr)
    local attr = plr:GetAttribute("Pets") or ""
    local r = rigs[plr]
    if r and r.ids == attr then
        return r
    end
    clearRig(plr)
    local models = {}
    for id in string.gmatch(attr, "[^,]+") do
        local m = Instance.new("Model")
        m.Name = id
        local builder = PET_BUILDERS[id]
        if builder then
            builder(m)
        end
        if m.PrimaryPart then
            m.Parent = petFolder
            table.insert(models, m)
        else
            m:Destroy()
        end
    end
    r = { ids = attr, models = models, fresh = true }
    rigs[plr] = r
    return r
end

RunService.RenderStepped:Connect(function(dt)
    local t = os.clock()
    for _, plr in ipairs(Players:GetPlayers()) do
        local char = plr.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root then
            local r = syncRig(plr)
            for i, m in ipairs(r.models) do
                local off = OFFSETS[i] or OFFSETS[3]
                local bob = 1.2 + math.sin(t * 3 + i * 2) * 0.35
                local target = root.CFrame * CFrame.new(off + V3(0, bob, 0))
                if r.fresh then
                    m:PivotTo(target)
                else
                    m:PivotTo(m:GetPivot():Lerp(target, math.clamp(dt * 8, 0, 1)))
                end
            end
            r.fresh = false
        else
            clearRig(plr)
        end
    end
end)

Players.PlayerRemoving:Connect(clearRig)
