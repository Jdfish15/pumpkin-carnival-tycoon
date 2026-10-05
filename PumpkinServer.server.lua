-- PumpkinServer.server.lua
-- Full Halloween carnival tycoon rewrite

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

-- ------------------------------------------------------------
-- CONFIGURATION
-- ------------------------------------------------------------
local GAMEPASS_2X = 0
local GAMEPASS_AUTO = 0
local PRODUCT_PUMPKIN_PACK = 0
local PRODUCT_LUCKY_EGG = 0
local MUSIC_ID = 0
local COLLECT_COOLDOWN = 0.08
local AUTO_CLICKS_PER_SEC = 3
local MAX_EQUIPPED = 3
local OFFLINE_CAP = 7200
local OFFLINE_RATE = 0.25
local MAX_PLOTS = 8
local PLOT_SPACING = 140
local GROUND_Y = 1

local CODES = {
    SPOOKY = { pumpkins = 5000 },
    HALLOWEEN = { egg = true },
    TRICKORTREAT = { pumpkins = 25000, egg = true },
}

local store = DataStoreService:GetDataStore("PumpkinCarnival_v2")

local V3 = Vector3.new
local C3 = Color3.fromRGB
local ORANGE = C3(255, 120, 20)
local PURPLE = C3(110, 60, 165)
local BLACK = C3(20, 16, 26)
local BONE = C3(236, 225, 205)
local YELLOW = C3(255, 210, 70)
local RED = C3(205, 40, 55)
local GREEN = C3(80, 160, 90)
local WOOD = C3(82, 58, 38)

local PETS = {
    { id = "ghost", name = "Ghost Pup", rarity = "Common", bonus = 0.05, weight = 38 },
    { id = "bat", name = "Baby Bat", rarity = "Common", bonus = 0.08, weight = 28 },
    { id = "cat", name = "Black Cat", rarity = "Uncommon", bonus = 0.15, weight = 15 },
    { id = "skelly", name = "Skelly", rarity = "Uncommon", bonus = 0.25, weight = 10 },
    { id = "mummy", name = "Mummy Mo", rarity = "Rare", bonus = 0.5, weight = 5 },
    { id = "frank", name = "Franky", rarity = "Rare", bonus = 0.75, weight = 2.5 },
    { id = "vampire", name = "Count Fang", rarity = "Epic", bonus = 1.5, weight = 1.2, lucky = 80 },
    { id = "dragon", name = "Pumpkin Dragon", rarity = "Legendary", bonus = 4, weight = 0.3, lucky = 20 },
}

local PET_BY_ID = {}
for _, pet in ipairs(PETS) do
    PET_BY_ID[pet.id] = pet
end

-- ------------------------------------------------------------
-- Remote setup
-- ------------------------------------------------------------
local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if remotesFolder then
    remotesFolder:Destroy()
end
remotesFolder = Instance.new("Folder")
remotesFolder.Name = "Remotes"
remotesFolder.Parent = ReplicatedStorage

local function remote(name)
    local r = Instance.new("RemoteEvent")
    r.Name = name
    r.Parent = remotesFolder
    return r
end

local CollectRemote = remote("Collect")
local UpgradeRemote = remote("Upgrade")
local BuildRemote = remote("Build")
local RebirthRemote = remote("Rebirth")
local PromptPurchase = remote("PromptPurchase")
local NotifyRemote = remote("Notify")
local PopupRemote = remote("Popup")
local HatchRemote = remote("Hatch")
local DailyRemote = remote("ClaimDaily")
local RedeemRemote = remote("RedeemCode")
local PetHatchedRemote = remote("PetHatched")
local RideActionRemote = remote("RideAction")
local StudioFxRemote = remote("StudioFx")

local petData = Instance.new("StringValue")
petData.Name = "PetData"
petData.Value = HttpService:JSONEncode(PETS)
petData.Parent = ReplicatedStorage

-- ------------------------------------------------------------
-- Lighting / atmosphere
-- ------------------------------------------------------------
Lighting.ClockTime = 0
Lighting.Brightness = 1.2
Lighting.GlobalShadows = true
Lighting.Ambient = C3(95, 72, 122)
Lighting.OutdoorAmbient = C3(95, 72, 122)
Lighting.FogColor = C3(35, 18, 52)
Lighting.FogStart = 200
Lighting.FogEnd = 900

local atmosphere = Instance.new("Atmosphere")
atmosphere.Density = 0.35
atmosphere.Offset = 0.25
atmosphere.Color = C3(130, 72, 160)
atmosphere.Decay = C3(60, 32, 90)
atmosphere.Glare = 0.05
atmosphere.Haze = 1.1
atmosphere.Parent = Lighting

local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.45
bloom.Size = 24
bloom.Threshold = 1.4
bloom.Parent = Lighting

-- Remove default baseplate / spawn
for _, name in ipairs({ "Baseplate", "SpawnLocation" }) do
    local obj = Workspace:FindFirstChild(name)
    if obj then
        obj:Destroy()
    end
end

local ground = Instance.new("Part")
ground.Name = "GraveyardGround"
ground.Anchored = true
ground.Size = V3(PLOT_SPACING * MAX_PLOTS + 400, 2, 500)
ground.Position = V3(PLOT_SPACING * (MAX_PLOTS - 1) / 2, -1, 0)
ground.Color = C3(30, 25, 38)
ground.Material = Enum.Material.Slate
ground.Parent = Workspace

-- ------------------------------------------------------------
-- Utility functions
-- ------------------------------------------------------------
local function part(parent, size, cf, color, material, shape)
    local p = Instance.new("Part")
    p.Anchored = true
    p.Size = size
    p.CFrame = cf
    p.Color = color
    p.Material = material or Enum.Material.SmoothPlastic
    if shape then
        p.Shape = shape
    end
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end

local function cyl(parent, radius, height, cf, color, material)
    return part(parent, V3(height, radius * 2, radius * 2), cf * CFrame.Angles(0, 0, math.rad(90)), color, material, Enum.PartType.Cylinder)
end

local function beam(parent, base, a, b, thickness, color, material)
    local wa, wb = base:PointToWorldSpace(a), base:PointToWorldSpace(b)
    local dir = wb - wa
    local up = math.abs(dir.Unit.Y) > 0.99 and V3(1, 0, 0) or V3(0, 1, 0)
    return part(parent, V3(thickness, thickness, dir.Magnitude), CFrame.lookAt((wa + wb) / 2, wb, up), color, material)
end

local function glow(p, color, range, brightness)
    local l = Instance.new("PointLight")
    l.Color = color or ORANGE
    l.Range = range or 18
    l.Brightness = brightness or 1.5
    l.Parent = p
    return l
end

local function label(p, text, face, textColor)
    local sg = Instance.new("SurfaceGui")
    sg.Face = face or Enum.NormalId.Front
    sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    sg.PixelsPerStud = 50
    sg.Parent = p
    local t = Instance.new("TextLabel")
    t.Size = UDim2.fromScale(1, 1)
    t.BackgroundTransparency = 1
    t.Text = text
    t.TextScaled = true
    t.Font = Enum.Font.Creepster
    t.TextColor3 = textColor or ORANGE
    t.Parent = sg
    return t
end

local function miniPumpkin(parent, pos, size)
    local body = part(parent, V3(size, size, size), CFrame.new(pos + V3(0, size / 2, 0)), ORANGE, nil, Enum.PartType.Ball)
    part(parent, V3(size * 0.18, size * 0.3, size * 0.18), CFrame.new(pos + V3(0, size + 0.05, 0)), GREEN)
    local e = size * 0.16
    for _, x in ipairs({ -0.22, 0.22 }) do
        part(parent, V3(e, e, e * 0.6), CFrame.new(pos + V3(x * size, size * 0.58, size * 0.48)), YELLOW, Enum.Material.Neon)
    end
    part(parent, V3(size * 0.5, size * 0.12, e * 0.6), CFrame.new(pos + V3(0, size * 0.3, size * 0.5)), YELLOW, Enum.Material.Neon)
    glow(body, ORANGE, size * 4, 1.1)
    return body
end

local function puff(position)
    local p = Instance.new("Part")
    p.Anchored = true
    p.CanCollide = false
    p.Transparency = 1
    p.Size = V3(1, 1, 1)
    p.Position = position
    p.Parent = Workspace

    local emitter = Instance.new("ParticleEmitter")
    emitter.Color = ColorSequence.new(ORANGE)
    emitter.Size = NumberSequence.new(3, 0)
    emitter.Lifetime = NumberRange.new(0.8, 1.2)
    emitter.Speed = NumberRange.new(20, 40)
    emitter.SpreadAngle = Vector2.new(180, 180)
    emitter.LightEmission = 1
    emitter.Rate = 0
    emitter.Parent = p
    emitter:Emit(60)
    Debris:AddItem(p, 2.5)
end

-- ------------------------------------------------------------
-- Attraction definitions
-- ------------------------------------------------------------
local function buildBooth(m, cf)
    part(m, V3(8, 6, 6), cf * CFrame.new(0, 3, 0), PURPLE)
    local roof = part(m, V3(10, 1, 8), cf * CFrame.new(0, 6.5, 0), ORANGE)
    part(m, V3(4, 2.5, 0.3), cf * CFrame.new(0, 3.8, -3.1), BLACK)
    local sign = part(m, V3(7, 2, 0.4), cf * CFrame.new(0, 8, -3.6), BLACK)
    label(sign, "TICKETS", Enum.NormalId.Front)
    glow(roof, ORANGE, 18, 1.5)
end

local function buildCandy(m, cf)
    part(m, V3(9, 3, 4), cf * CFrame.new(0, 1.5, 0), RED)
    for _, x in ipairs({ -4.5, 4.5 }) do
        for _, z in ipairs({ -2, 2 }) do
            part(m, V3(0.5, 7, 0.5), cf * CFrame.new(x, 3.5, z), WOOD)
        end
    end
    for i = 0, 4 do
        part(m, V3(2, 0.6, 6), cf * CFrame.new(-4 + i * 2, 7.3, 0), (i % 2 == 0) and ORANGE or BLACK)
    end
    for _, x in ipairs({ -2.5, 0, 2.5 }) do
        part(m, V3(0.15, 1.5, 0.15), cf * CFrame.new(x, 3.8, -0.5), WOOD)
        part(m, V3(1.4, 1.4, 1.4), cf * CFrame.new(x, 4.9, -0.5), RED, Enum.Material.Glass, Enum.PartType.Ball)
    end
    local sign = part(m, V3(7, 1.6, 0.4), cf * CFrame.new(0, 8.6, -3.2), BLACK)
    label(sign, "CANDY APPLES", Enum.NormalId.Front)
    glow(sign, RED, 16, 1.2)
end

local function buildRingToss(m, cf)
    part(m, V3(11, 3, 4), cf * CFrame.new(0, 1.5, 0), PURPLE)
    part(m, V3(12, 5, 0.5), cf * CFrame.new(0, 5.5, 2.6), BLACK)
    for _, x in ipairs({ -5.5, 5.5 }) do
        part(m, V3(0.6, 9, 0.6), cf * CFrame.new(x, 4.5, 2.4), WOOD)
    end
    for i, x in ipairs({ -4, -2, 0, 2, 4 }) do
        cyl(m, 0.5, 2.2, cf * CFrame.new(x, 4.1, 0.5), (i % 2 == 0) and ORANGE or GREEN, Enum.Material.Glass)
    end
    local sign = part(m, V3(10, 2, 0.5), cf * CFrame.new(0, 9, 2.2), BLACK)
    label(sign, "RING TOSS", Enum.NormalId.Front)
    glow(sign, YELLOW, 16, 1.2)
end

local function buildCarousel(m, cf)
    cyl(m, 10, 0.8, cf * CFrame.new(0, 0.4, 0), BLACK)
    local spin = Instance.new("Model")
    spin.Name = "Spinner"
    spin.Parent = m
    local pole = part(spin, V3(1.2, 10, 1.2), cf * CFrame.new(0, 5.8, 0), WOOD)
    spin.PrimaryPart = pole
    cyl(spin, 10, 0.6, cf * CFrame.new(0, 1.1, 0), PURPLE)
    local roof = cyl(spin, 10.5, 0.8, cf * CFrame.new(0, 10.8, 0), ORANGE)
    cyl(spin, 6, 1.5, cf * CFrame.new(0, 11.9, 0), BLACK)
    for k = 0, 5 do
        local a = k * math.pi / 3
        local x, z = 7 * math.cos(a), 7 * math.sin(a)
        part(spin, V3(0.3, 8, 0.3), cf * CFrame.new(x, 5.4, z), BONE)
        part(spin, V3(1.2, 1.6, 3), cf * CFrame.new(x, 3.4, z) * CFrame.Angles(0, -a, 0), (k % 2 == 0) and BONE or ORANGE)
    end
    for k = 0, 11 do
        local a = k * math.pi / 6
        part(spin, V3(0.8, 0.8, 0.8), cf * CFrame.new(10.2 * math.cos(a), 10.3, 10.2 * math.sin(a)), YELLOW, Enum.Material.Neon, Enum.PartType.Ball)
    end
    local sign = part(m, V3(8, 2, 0.4), cf * CFrame.new(0, 2, -11.5), BLACK)
    label(sign, "CAROUSEL", Enum.NormalId.Front)
    glow(roof, YELLOW, 24, 1.5)
    return { model = spin, axis = "Y", speed = 0.85 }
end

local function buildFerris(m, cf)
    local hubY, R, N = 18, 14, 16
    for _, z in ipairs({ -3, 3 }) do
        beam(m, cf, V3(-11, 0, z), V3(0, hubY, z), 1.1, PURPLE)
        beam(m, cf, V3(11, 0, z), V3(0, hubY, z), 1.1, PURPLE)
    end
    part(m, V3(0.9, 0.9, 7), cf * CFrame.new(0, hubY, 0), BONE)
    local spin = Instance.new("Model")
    spin.Name = "Wheel"
    spin.Parent = m
    local hub = part(spin, V3(2.6, 2.6, 2.6), cf * CFrame.new(0, hubY, 0), ORANGE, Enum.Material.Neon, Enum.PartType.Ball)
    spin.PrimaryPart = hub
    glow(hub, ORANGE, 30, 2)
    local pts = {}
    for k = 1, N do
        local a = (k - 1) * 2 * math.pi / N
        pts[k] = V3(R * math.cos(a), hubY + R * math.sin(a), 0)
    end
    for k = 1, N do
        beam(spin, cf, pts[k], pts[k % N + 1], 0.7, ORANGE)
        if k % 2 == 1 then
            beam(spin, cf, V3(0, hubY, 0), pts[k], 0.4, BONE)
            part(spin, V3(3, 3, 3), cf * CFrame.new(pts[k]), ((k // 2) % 2 == 0) and PURPLE or ORANGE)
        end
    end
    local sign = part(m, V3(9, 2, 0.4), cf * CFrame.new(0, 2, -6), BLACK)
    label(sign, "FERRIS WHEEL", Enum.NormalId.Front)
    return { model = spin, axis = "Z", speed = 0.32 }
end

local function buildHouse(m, cf)
    local wall = C3(70, 45, 95)
    local dark = C3(50, 35, 70)
    part(m, V3(22, 14, 16), cf * CFrame.new(0, 7, 0), wall)
    part(m, V3(24, 1, 18), cf * CFrame.new(0, 14.5, 0), BLACK)
    part(m, V3(18, 3, 14), cf * CFrame.new(0, 16.5, 0), dark)
    part(m, V3(12, 3, 10), cf * CFrame.new(0, 19.5, 0), BLACK)
    part(m, V3(6, 3, 6), cf * CFrame.new(0, 22.5, 0), dark)
    part(m, V3(3, 6, 3), cf * CFrame.new(7, 19, 3), BLACK)
    part(m, V3(4, 8, 0.4), cf * CFrame.new(0, 4, -8.1), BLACK)
    for _, x in ipairs({ -7, 7 }) do
        local w = part(m, V3(3.5, 4, 0.4), cf * CFrame.new(x, 9, -8.1), YELLOW, Enum.Material.Neon)
        glow(w, YELLOW, 14, 1.2)
    end
    local sign = part(m, V3(14, 2.5, 0.5), cf * CFrame.new(0, 12, -8.4), BLACK)
    label(sign, "HAUNTED HOUSE", Enum.NormalId.Front)
end

local function buildBigTop(m, cf)
    cyl(m, 14, 8, cf * CFrame.new(0, 4, 0), PURPLE)
    cyl(m, 14.6, 0.8, cf * CFrame.new(0, 8.4, 0), BLACK)
    local y = 9.3
    local topCyl
    for i, r in ipairs({ 13, 10, 7, 4 }) do
        topCyl = cyl(m, r, 3, cf * CFrame.new(0, y + 1.5, 0), (i % 2 == 1) and ORANGE or BLACK)
        y += 3
    end
    part(m, V3(0.4, 6, 0.4), cf * CFrame.new(0, y + 3, 0), BONE)
    part(m, V3(4, 2.5, 0.2), cf * CFrame.new(2.2, y + 5, 0), ORANGE)
    glow(topCyl, ORANGE, 30, 2)
    part(m, V3(7, 6, 0.5), cf * CFrame.new(0, 3, -13.6), BLACK)
    local sign = part(m, V3(11, 2.4, 0.5), cf * CFrame.new(0, 7.2, -14), BLACK)
    label(sign, "BIG TOP", Enum.NormalId.Front)
end

local ATTRACTIONS = {
    { name = "Ticket Booth", cost = 50, income = 1, build = buildBooth, kind = "booth" },
    { name = "Candy Apple Stand", cost = 250, income = 5, build = buildCandy, kind = "candy" },
    { name = "Ring Toss", cost = 1000, income = 20, build = buildRingToss, kind = "ringToss" },
    { name = "Spooky Carousel", cost = 5000, income = 100, build = buildCarousel, kind = "carousel" },
    { name = "Ferris Wheel", cost = 25000, income = 500, build = buildFerris, kind = "ferris" },
    { name = "Haunted House", cost = 100000, income = 2500, build = buildHouse, kind = "house" },
    { name = "Big Top Circus", cost = 500000, income = 15000, build = buildBigTop, kind = "bigTop" },
}

local SLOTS = {
    { x = -30, z = 40 },
    { x = 30, z = 40 },
    { x = -40, z = 10 },
    { x = 40, z = 10 },
    { x = -32, z = -28 },
    { x = 32, z = -28 },
    { x = 0, z = -40 },
}

-- ------------------------------------------------------------
-- Game data / economy
-- ------------------------------------------------------------
local sessions = {}
local lastCollect = {}
local playerPlot = {}
local plots = {}
local spinners = {}
local rideLookup = {}

local function pickPet(lucky)
    local function weightOf(p)
        if lucky then
            return p.lucky or 0
        end
        return p.weight
    end

    local total = 0
    for _, p in ipairs(PETS) do
        total += weightOf(p)
    end

    local roll = math.random() * total
    for _, p in ipairs(PETS) do
        local w = weightOf(p)
        if w > 0 then
            roll -= w
            if roll <= 0 then
                return p
            end
        end
    end
    return PETS[1]
end

local function recomputePets(d)
    local ids = {}
    for id, n in pairs(d.pets) do
        if PET_BY_ID[id] and n > 0 then
            table.insert(ids, id)
        end
    end

    table.sort(ids, function(a, b)
        return PET_BY_ID[a].bonus > PET_BY_ID[b].bonus
    end)

    local equipped, bonus = {}, 0
    for _, id in ipairs(ids) do
        for _ = 1, d.pets[id] do
            if #equipped >= MAX_EQUIPPED then break end
            table.insert(equipped, id)
            bonus += PET_BY_ID[id].bonus
        end
        if #equipped >= MAX_EQUIPPED then break end
    end

    d.equipped = equipped
    d.petBonus = bonus
end

local function eggCost(d)
    return math.floor(1500 * 2 ^ d.rebirths)
end

local function frenzyActive(d)
    return os.clock() < (d.frenzyUntil or 0)
end

local function dailyReadyAt(d)
    return (d.lastClaim or 0) + 82800
end

local function dailyDay(d)
    if d.lastClaim == 0 or os.time() - d.lastClaim > 172800 then
        return 1
    end
    return (d.streak % 7) + 1
end

local function mult(d)
    local m = (1 + d.rebirths) * (1 + d.petBonus)
    if d.has2x then
        m *= 2
    end
    if frenzyActive(d) then
        m *= 3
    end
    return m
end

local function clickPower(d)
    return math.max(1, math.floor((1 + d.level) * mult(d)))
end

local function incomePerSec(d)
    local total = 0
    for i = 1, d.built do
        total += ATTRACTIONS[i].income
    end
    if total == 0 then
        return 0
    end
    return math.max(1, math.floor(total * mult(d)))
end

local function upgradeCost(level)
    return math.floor(25 * 1.6 ^ level)
end

local function rebirthCost(rebirths)
    return math.floor(2000000 * 3 ^ rebirths)
end

local function packAmount(d)
    return math.max(500, incomePerSec(d) * 600)
end

local function notify(player, text)
    NotifyRemote:FireClient(player, text)
end

local function refresh(player)
    local d = sessions[player]
    if not d then return end

    local ls = player:FindFirstChild("leaderstats")
    if ls then
        ls.Pumpkins.Value = math.floor(d.pumpkins)
        ls.Seasons.Value = d.rebirths
    end

    local nextDef = ATTRACTIONS[d.built + 1]
    player:SetAttribute("PerClick", clickPower(d))
    player:SetAttribute("Income", incomePerSec(d))
    player:SetAttribute("UpgradeCost", upgradeCost(d.level))
    player:SetAttribute("Built", d.built)
    player:SetAttribute("TotalAttractions", #ATTRACTIONS)
    player:SetAttribute("NextName", nextDef and nextDef.name or "")
    player:SetAttribute("NextCost", nextDef and nextDef.cost or 0)
    player:SetAttribute("RebirthCost", rebirthCost(d.rebirths))
    player:SetAttribute("PackAmount", packAmount(d))
    player:SetAttribute("Has2x", d.has2x)
    player:SetAttribute("HasAuto", d.hasAuto)
    player:SetAttribute("EggCost", eggCost(d))
    player:SetAttribute("Pets", table.concat(d.equipped, ","))
    player:SetAttribute("PetBonus", d.petBonus)
    player:SetAttribute("DailyReadyAt", dailyReadyAt(d))
    player:SetAttribute("DailyDay", dailyDay(d))
    player:SetAttribute("FrenzyEnd", frenzyActive(d) and (Workspace:GetServerTimeNow() + (d.frenzyUntil - os.clock())) or 0)

    local counts = {}
    for id, n in pairs(d.pets) do
        table.insert(counts, id .. ":" .. n)
    end
    player:SetAttribute("PetCounts", table.concat(counts, ","))
end

local function save(player)
    local d = sessions[player]
    if not d then return end

    local payload = {
        pumpkins = d.pumpkins,
        level = d.level,
        built = d.built,
        rebirths = d.rebirths,
        pets = d.pets,
        lastClaim = d.lastClaim,
        streak = d.streak,
        codes = d.codes,
        lastSeen = os.time(),
    }

    for attempt = 1, 3 do
        local ok, err = pcall(function()
            store:SetAsync("u_" .. player.UserId, payload)
        end)
        if ok then
            return
        end
        warn("Save failed (attempt " .. attempt .. "): " .. tostring(err))
        task.wait(1)
    end
end

local function load(player)
    for attempt = 1, 3 do
        local ok, result = pcall(function()
            return store:GetAsync("u_" .. player.UserId)
        end)
        if ok then
            return true, result or {}
        end
        warn("Load failed (attempt " .. attempt .. "): " .. tostring(result))
        task.wait(1)
    end
    return false, nil
end

-- ------------------------------------------------------------
-- Plots and attractions
-- ------------------------------------------------------------
local function slotCFrame(plot, index)
    local s = SLOTS[index]
    return CFrame.new(plot.center + V3(s.x, GROUND_Y, s.z)) * CFrame.Angles(0, math.pi, 0)
end

local function buildBigPumpkin(plot)
    local model = Instance.new("Model")
    model.Name = "BigPumpkin"
    model.Parent = plot.model
    local center = plot.center + V3(0, GROUND_Y + 6, 15)
    local body = part(model, V3(12, 12, 12), CFrame.new(center), ORANGE, nil, Enum.PartType.Ball)
    model.PrimaryPart = body
    part(model, V3(1.6, 3, 1.6), CFrame.new(center + V3(0, 6.3, 0)), GREEN)
    for _, x in ipairs({ -2.4, 2.4 }) do
        part(model, V3(2, 2, 1), CFrame.new(center + V3(x, 1.5, math.sqrt(math.max(36 - x * x - 2.25, 0.01)) + 0.2)), YELLOW, Enum.Material.Neon)
    end
    part(model, V3(0.9, 0.9, 1), CFrame.new(center + V3(0, -0.2, 6 + 0.2)), YELLOW, Enum.Material.Neon)
    local mx = { -3.6, -1.8, 0, 1.8, 3.6 }
    local my = { -1.6, -2.6, -3.0, -2.6, -1.6 }
    for i = 1, 5 do
        part(model, V3(1.4, 1.2, 1), CFrame.new(center + V3(mx[i], my[i], math.sqrt(math.max(36 - (mx[i] * mx[i]) - (my[i] * my[i]), 0.01)) + 0.2)), YELLOW, Enum.Material.Neon)
    end
    glow(body, ORANGE, 30, 2)

    local cd = Instance.new("ClickDetector")
    cd.MaxActivationDistance = 100
    cd.Parent = body
    plot.clickDetector = cd

    local sv = Instance.new("NumberValue")
    sv.Value = 1
    sv.Parent = model
    sv.Changed:Connect(function(v)
        model:ScaleTo(v)
    end)
    plot.scaleValue = sv
end

local function createPlot(i)
    local center = V3((i - 1) * PLOT_SPACING, 0, 0)
    local plot = { index = i, center = center, owner = nil, bumping = false }

    local model = Instance.new("Model")
    model.Name = "Plot" .. i
    model.Parent = Workspace
    plot.model = model

    local folder = Instance.new("Folder")
    folder.Name = "Attractions"
    folder.Parent = model
    plot.attractions = folder

    part(model, V3(120, 2, 120), CFrame.new(center + V3(0, GROUND_Y - 1, 0)), C3(45, 32, 58), Enum.Material.Slate)
    part(model, V3(8, 0.2, 44), CFrame.new(center + V3(0, GROUND_Y + 0.1, 36)), C3(90, 70, 60), Enum.Material.Cobblestone)

    local spawn = Instance.new("SpawnLocation")
    spawn.Anchored = true
    spawn.Size = V3(8, 1, 8)
    spawn.Position = center + V3(0, GROUND_Y + 0.6, 50)
    spawn.Transparency = 1
    spawn.CanCollide = false
    spawn.Neutral = true
    spawn.Duration = 0
    spawn.Parent = model
    plot.spawn = spawn

    for _, x in ipairs({ -14, 14 }) do
        part(model, V3(1.5, 16, 1.5), CFrame.new(center + V3(x, GROUND_Y + 8, 28)), WOOD, Enum.Material.Wood)
    end
    local board = part(model, V3(30, 5, 1), CFrame.new(center + V3(0, GROUND_Y + 16, 28)), BLACK)
    plot.signLabel = label(board, "Free Plot", Enum.NormalId.Back, ORANGE)

    for _, z in ipairs({ 44, 36 }) do
        for _, x in ipairs({ -7, 7 }) do
            part(model, V3(1, 3, 1), CFrame.new(center + V3(x, GROUND_Y + 1.5, z)), BLACK)
            miniPumpkin(model, center + V3(x, GROUND_Y + 3, z), 3)
        end
    end

    local rng = Random.new(i * 7919)
    for _, side in ipairs({ -1, 1 }) do
        for _ = 1, 7 do
            local x = side * (52 + rng:NextNumber(0, 5))
            local z = rng:NextNumber(-44, 40)
            local base = CFrame.new(center + V3(x, GROUND_Y, z)) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0)
            local grey = C3(110, 110, 125)
            part(model, V3(3, 4, 1), base * CFrame.new(0, 2, 0), grey, Enum.Material.Slate)
            part(model, V3(1, 3, 3), base * CFrame.new(0, 4, 0) * CFrame.Angles(0, math.pi / 2, 0), grey, Enum.Material.Slate, Enum.PartType.Cylinder)
        end
        for _, z in ipairs({ -50, 50 }) do
            local pos = center + V3(side * 54, GROUND_Y, z)
            cyl(model, 1.2, 16, CFrame.new(pos + V3(0, 8, 0)), WOOD, Enum.Material.Wood)
            local base = CFrame.new(pos)
            beam(model, base, V3(0, 11, 0), V3(5, 17, 2), 0.7, WOOD, Enum.Material.Wood)
            beam(model, base, V3(0, 9, 0), V3(-5, 15, -2), 0.7, WOOD, Enum.Material.Wood)
            beam(model, base, V3(0, 13, 0), V3(-3, 19, 3), 0.6, WOOD, Enum.Material.Wood)
            beam(model, base, V3(0, 14, 0), V3(3, 20, -3), 0.6, WOOD, Enum.Material.Wood)
        end
    end

    buildBigPumpkin(plot)
    return plot
end

for i = 1, MAX_PLOTS do
    plots[i] = createPlot(i)
end

local function bump(plot)
    if plot.bumping then return end
    plot.bumping = true
    task.spawn(function()
        local up = TweenService:Create(plot.scaleValue, TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = 1.1 })
        up:Play()
        up.Completed:Wait()
        local down = TweenService:Create(plot.scaleValue, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = 1 })
        down:Play()
        down.Completed:Wait()
        plot.bumping = false
    end)
end

local function addPrompt(part, actionText, objectText, holdDuration, callback)
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = actionText
    prompt.ObjectText = objectText
    prompt.HoldDuration = holdDuration or 0.3
    prompt.MaxActivationDistance = 14
    prompt.RequiresLineOfSight = false
    prompt.Parent = part
    prompt.Triggered:Connect(function(player)
        callback(player)
    end)
    return prompt
end

local function createRideStation(plot, index, kind)
    local model = Instance.new("Model")
    model.Name = kind
    model.Parent = plot.attractions

    local base = part(model, V3(1, 1, 1), CFrame.new(plot.center + V3(0, GROUND_Y, 0)), C3(255, 255, 255))
    base.Transparency = 1
    base.CanTouch = false

    local stationInfo = {
        plot = plot,
        model = model,
        base = base,
        kind = kind,
        busy = {},
        spin = nil,
        seat = nil,
        ride = nil,
    }

    local def = ATTRACTIONS[index]
    if def and def.build then
        def.build(model, slotCFrame(plot, index))
    end

    local promptPart = model:FindFirstChildOfClass("Part") or base
    if promptPart then
        local promptText = def and def.name or "Ride"
        addPrompt(promptPart, "Play", promptText, 0.35, function(player)
            if stationInfo.kind == "ringToss" then
                local state = stationInfo.busy[player] or { score = 0, attempts = 0 }
                if state.attempts >= 5 then
                    return
                end
                state.attempts += 1
                stationInfo.busy[player] = state
                local success = math.random() < 0.58
                if success then
                    state.score += 1
                end
                local reward = state.score * 120 + math.random(40, 180)
                local msg = (success and "Nice toss!" or "Missed it!") .. " You have " .. state.score .. "/5.")
                notify(player, msg)
                if state.attempts >= 5 then
                    local paid = reward + (state.score >= 3 and 250 or 0)
                    local d = sessions[player]
                    if d then
                        d.pumpkins += paid
                        refresh(player)
                        notify(player, "🎯 Ring Toss cleared! +" .. paid .. " pumpkins")
                    end
                    stationInfo.busy[player] = nil
                end
                return
            elseif stationInfo.kind == "candy" then
                local d = sessions[player]
                if d then
                    local gain = math.random(100, 340) + math.max(40, incomePerSec(d) * 3)
                    d.pumpkins += gain
                    refresh(player)
                    notify(player, "🍬 Candy stand bonus! +" .. gain .. " pumpkins")
                    PopupRemote:FireClient(player, gain)
                    puff(player.Character and player.Character:GetPivot().Position or plot.center + V3(0, 6, 0))
                end
                return
            elseif stationInfo.kind == "carousel" then
                local char = player.Character
                if not char then return end
                local root = char:FindFirstChild("HumanoidRootPart")
                if not root then return end
                local seatModel = model:FindFirstChild("Seat") or model:FindFirstChild("CarSeat")
                if not seatModel then
                    local seat = Instance.new("Seat")
                    seat.Name = "Seat"
                    seat.Size = V3(2, 1.2, 2)
                    seat.CFrame = slotCFrame(plot, index) * CFrame.new(0, 3, 0)
                    seat.Parent = model
                    seatModel = seat
                end
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    humanoid:MoveTo(root.Position)
                    seatModel:Sit(humanoid)
                end
                local d = sessions[player]
                if d then
                    local bonus = math.max(180, incomePerSec(d) * 10)
                    task.delay(2.5, function()
                        if player.Parent and player.Character and player.Character:FindFirstChildOfClass("Humanoid") and player.Character:FindFirstChildOfClass("Humanoid").Sit then
                            d.pumpkins += bonus
                            refresh(player)
                            notify(player, "🎠 Carousel ride! +" .. bonus .. " pumpkins")
                            PopupRemote:FireClient(player, bonus)
                        end
                    end)
                end
                return
            elseif stationInfo.kind == "ferris" then
                local char = player.Character
                if not char then return end
                local root = char:FindFirstChild("HumanoidRootPart")
                if root then
                    root.CFrame = root.CFrame + Vector3.new(0, 0, -2)
                end
                local d = sessions[player]
                if d then
                    local bonus = math.max(500, incomePerSec(d) * 30)
                    d.pumpkins += bonus
                    refresh(player)
                    notify(player, "🎡 Ferris Wheel ride! +" .. bonus .. " pumpkins")
                    PopupRemote:FireClient(player, bonus)
                end
                return
            elseif stationInfo.kind == "house" then
                local d = sessions[player]
                if d then
                    local reward = math.random(350, 900) + incomePerSec(d) * 12
                    d.pumpkins += reward
                    refresh(player)
                    notify(player, "👻 Haunted house challenge! +" .. reward .. " pumpkins")
                    PopupRemote:FireClient(player, reward)
                end
                return
            elseif stationInfo.kind == "bigTop" then
                local d = sessions[player]
                if d then
                    local reward = math.random(750, 2200) + incomePerSec(d) * 25
                    d.pumpkins += reward
                    refresh(player)
                    notify(player, "🎪 Big Top show! +" .. reward .. " pumpkins")
                    PopupRemote:FireClient(player, reward)
                end
                return
            elseif stationInfo.kind == "booth" then
                local d = sessions[player]
                if d then
                    local reward = math.max(40, clickPower(d) * 8)
                    d.pumpkins += reward
                    refresh(player)
                    notify(player, "🎟️ Ticket booth payout! +" .. reward .. " pumpkins")
                    PopupRemote:FireClient(player, reward)
                end
                return
            end
        end)
    end

    rideLookup[model] = stationInfo
    return stationInfo
end

local function buildAttraction(plot, index, withEffect)
    plot.attractions:ClearAllChildren()
    local station = createRideStation(plot, index, ATTRACTIONS[index].kind)
    if withEffect then
        puff(plot.center + V3(0, 6, 0))
    end
    return station
end

-- ------------------------------------------------------------
-- Golden pumpkin and passive economy
-- ------------------------------------------------------------
local function spawnGolden(player, d)
    local plot = playerPlot[player]
    if not plot or d.golden then return end

    local x = (math.random() < 0.5 and -1 or 1) * math.random(8, 22)
    local z = math.random(-15, 5)
    local pos = plot.center + V3(x, GROUND_Y + 5, z)

    local gp = part(Workspace, V3(4, 4, 4), CFrame.new(pos), C3(255, 200, 40), Enum.Material.Neon, Enum.PartType.Ball)
    gp.Name = "GoldenPumpkin"
    gp.CanCollide = false
    glow(gp, C3(255, 210, 80), 28, 3)

    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.fromOffset(200, 40)
    bb.StudsOffset = V3(0, 4, 0)
    bb.AlwaysOnTop = true
    bb.Parent = gp

    local txt = Instance.new("TextLabel")
    txt.Size = UDim2.fromScale(1, 1)
    txt.BackgroundTransparency = 1
    txt.Text = "⭐ GOLDEN PUMPKIN! ⭐"
    txt.TextScaled = true
    txt.Font = Enum.Font.FredokaOne
    txt.TextColor3 = C3(255, 220, 90)
    txt.Parent = bb

    local cd = Instance.new("ClickDetector")
    cd.MaxActivationDistance = 150
    cd.Parent = gp

    d.golden = gp
    notify(player, "🌟 A GOLDEN PUMPKIN appeared on your plot! Click it fast!")

    local claimed = false
    cd.MouseClick:Connect(function(clicker)
        if clicker ~= player or claimed then return end
        claimed = true
        d.golden = nil
        gp:Destroy()
        if math.random() < 0.3 then
            d.frenzyUntil = os.clock() + 30
            refresh(player)
            notify(player, "🔥 CANDY FRENZY! x3 earnings for 30 seconds!")
        else
            local amount = math.max(250, incomePerSec(d) * 45 + clickPower(d) * 40)
            d.pumpkins += amount
            refresh(player)
            notify(player, "🌟 Golden Pumpkin bonus: +" .. amount .. " pumpkins!")
            PopupRemote:FireClient(player, amount)
        end
    end)

    task.delay(25, function()
        if gp.Parent then
            gp:Destroy()
        end
        if d.golden == gp then
            d.golden = nil
        end
    end)
end

-- ------------------------------------------------------------
-- Player setup / progress
-- ------------------------------------------------------------
local function claimPlot(player)
    for _, plot in ipairs(plots) do
        if not plot.owner then
            plot.owner = player
            playerPlot[player] = plot
            plot.signLabel.Text = player.DisplayName .. "'s Carnival"
            return plot
        end
    end
end

local function teleportToPlot(player)
    local plot = playerPlot[player]
    local char = player.Character
    if plot and char then
        char:PivotTo(CFrame.new(plot.center + V3(0, GROUND_Y + 4, 50)))
    end
end

local function onPlayerAdded(player)
    player.CharacterAdded:Connect(function(char)
        if playerPlot[player] then
            if char:WaitForChild("HumanoidRootPart", 5) then
                teleportToPlot(player)
            end
        end
    end)

    local ok, saved = load(player)
    if not player.Parent then return end
    if not ok then
        player:Kick("Couldn't load your data. Please rejoin.")
        return
    end

    local ls = Instance.new("Folder")
    ls.Name = "leaderstats"
    ls.Parent = player

    local pv = Instance.new("NumberValue")
    pv.Name = "Pumpkins"
    pv.Parent = ls

    local sv = Instance.new("IntValue")
    sv.Name = "Seasons"
    sv.Parent = ls

    local has2x = false
    if GAMEPASS_2X ~= 0 then
        local success, owns = pcall(function()
            return MarketplaceService:UserOwnsGamePassAsync(player.UserId, GAMEPASS_2X)
        end)
        has2x = success and owns or false
    end

    local hasAuto = false
    if GAMEPASS_AUTO ~= 0 then
        local success, owns = pcall(function()
            return MarketplaceService:UserOwnsGamePassAsync(player.UserId, GAMEPASS_AUTO)
        end)
        hasAuto = success and owns or false
    end

    sessions[player] = {
        pumpkins = saved.pumpkins or 0,
        level = saved.level or 0,
        built = math.clamp(saved.built or 0, 0, #ATTRACTIONS),
        rebirths = saved.rebirths or 0,
        has2x = has2x,
        hasAuto = hasAuto,
        pets = saved.pets or {},
        lastClaim = saved.lastClaim or 0,
        streak = saved.streak or 0,
        codes = saved.codes or {},
        frenzyUntil = 0,
        nextGolden = os.clock() + math.random(60, 120),
        equipped = {},
        petBonus = 0,
        golden = nil,
        offlineSeconds = saved.lastSeen and math.clamp(os.time() - saved.lastSeen, 0, OFFLINE_CAP) or 0,
    }
    recomputePets(sessions[player])

    local plot = claimPlot(player)
    if not plot then
        player:Kick("Server is full - please join another server.")
        return
    end

    for i = 1, sessions[player].built do
        buildAttraction(plot, i, false)
    end

    player.RespawnLocation = plot.spawn
    teleportToPlot(player)
    refresh(player)

    local current = sessions[player]
    local earned = 0
    if current.offlineSeconds > 60 then
        earned = math.floor(incomePerSec(current) * current.offlineSeconds * OFFLINE_RATE)
    end

    if earned > 0 then
        current.pumpkins += earned
        refresh(player)
        notify(player, "💤 Welcome back! Your carnival earned " .. earned .. " pumpkins while you were away!")
    elseif os.time() >= dailyReadyAt(current) then
        notify(player, "🎁 Your daily reward is ready! Tap Daily Reward on the left.")
    else
        notify(player, "🎃 Welcome! Click the giant pumpkin to build your carnival!")
    end
end

local function onPlayerRemoving(player)
    save(player)
    local plot = playerPlot[player]
    if plot then
        plot.owner = nil
        plot.signLabel.Text = "Free Plot"
        plot.attractions:ClearAllChildren()
        playerPlot[player] = nil
    end
    sessions[player] = nil
    lastCollect[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, p in ipairs(Players:GetPlayers()) do
    task.spawn(onPlayerAdded, p)
end

-- ------------------------------------------------------------
-- Ride spin animation / carnival atmosphere
-- ------------------------------------------------------------
RunService.Heartbeat:Connect(function(dt)
    for i = #spinners, 1, -1 do
        local s = spinners[i]
        if not s.model:IsDescendantOf(Workspace) then
            table.remove(spinners, i)
        else
            s.angle += s.speed * dt
            if s.axis == "Y" then
                s.model:PivotTo(s.base * CFrame.Angles(0, s.angle, 0))
            else
                s.model:PivotTo(s.base * CFrame.Angles(0, 0, s.angle))
            end
        end
    end
end)

local function registerSpinner(model, axis, speed)
    local spin = {
        model = model,
        axis = axis,
        speed = speed,
        base = model:GetPivot(),
        angle = 0,
    }
    table.insert(spinners, spin)
    return spin
end

local function addSpinnerIfNeeded(station)
    local model = station.model:FindFirstChild("Spinner") or station.model:FindFirstChild("Wheel")
    if model then
        local axis = station.kind == "ferris" and "Z" or "Y"
        local speed = station.kind == "ferris" and 0.32 or 0.85
        if not station.spinner then
            station.spinner = registerSpinner(model, axis, speed)
        end
    end
end

-- When attractions are built, attach spinner models if any
local function ensureRideSpin(station)
    if station.kind == "carousel" then
        addSpinnerIfNeeded(station)
    elseif station.kind == "ferris" then
        addSpinnerIfNeeded(station)
    end
end

-- ------------------------------------------------------------
-- Gameplay / collection
-- ------------------------------------------------------------
local function collect(player, fromWorld)
    local d = sessions[player]
    if not d then return end

    local now = os.clock()
    if lastCollect[player] and now - lastCollect[player] < COLLECT_COOLDOWN then
        return
    end
    lastCollect[player] = now

    local amount = clickPower(d)
    d.pumpkins += amount
    refresh(player)

    local plot = playerPlot[player]
    if plot then
        bump(plot)
    end

    if fromWorld then
        PopupRemote:FireClient(player, amount)
    end
end

CollectRemote.OnServerEvent:Connect(function(player)
    collect(player, false)
end)

for _, plot in ipairs(plots) do
    if plot.clickDetector then
        plot.clickDetector.MouseClick:Connect(function(clicker)
            if plot.owner == clicker then
                collect(clicker, true)
            end
        end)
    end
end

-- ------------------------------------------------------------
-- Build / upgrade / rebirth actions
-- ------------------------------------------------------------
UpgradeRemote.OnServerEvent:Connect(function(player)
    local d = sessions[player]
    if not d then return end
    local cost = upgradeCost(d.level)
    if d.pumpkins >= cost then
        d.pumpkins -= cost
        d.level += 1
        refresh(player)
    end
end)

BuildRemote.OnServerEvent:Connect(function(player)
    local d, plot = sessions[player], playerPlot[player]
    if not d or not plot then return end
    local index = d.built + 1
    local def = ATTRACTIONS[index]
    if not def or d.pumpkins < def.cost then return end

    d.pumpkins -= def.cost
    d.built = index
    local station = buildAttraction(plot, index, true)
    ensureRideSpin(station)
    refresh(player)
    notify(player, "🎪 Built: " .. def.name .. "! +" .. math.floor(def.income * mult(d)) .. " pumpkins/sec")
end)

RebirthRemote.OnServerEvent:Connect(function(player)
    local d, plot = sessions[player], playerPlot[player]
    if not d or not plot then return end
    if d.built < #ATTRACTIONS then return end
    if d.pumpkins < rebirthCost(d.rebirths) then return end

    d.pumpkins = 0
    d.level = 0
    d.built = 0
    d.rebirths += 1
    plot.attractions:ClearAllChildren()
    refresh(player)
    notify(player, "🌙 A new Halloween season begins! Everything earns x" .. string.format("%.1f", mult(d)) .. " now!")
    save(player)
end)

-- ------------------------------------------------------------
-- Pet logic / daily rewards / codes
-- ------------------------------------------------------------
local function grantPet(player, d, pet)
    d.pets[pet.id] = (d.pets[pet.id] or 0) + 1
    recomputePets(d)
    refresh(player)
    PetHatchedRemote:FireClient(player, pet.id)
    if pet.rarity == "Legendary" then
        NotifyRemote:FireAllClients("⭐ " .. player.DisplayName .. " hatched a LEGENDARY " .. pet.name .. "!")
    end
end

local lastHatch = {}
HatchRemote.OnServerEvent:Connect(function(player)
    local d = sessions[player]
    if not d then return end
    local now = os.clock()
    if lastHatch[player] and now - lastHatch[player] < 0.4 then return end
    lastHatch[player] = now

    local cost = eggCost(d)
    if d.pumpkins < cost then
        notify(player, "🥚 Not enough pumpkins for an egg yet!")
        return
    end

    d.pumpkins -= cost
    grantPet(player, d, pickPet(false))
end)

DailyRemote.OnServerEvent:Connect(function(player)
    local d = sessions[player]
    if not d then return end
    local now = os.time()
    if now < dailyReadyAt(d) then return end

    local day = dailyDay(d)
    d.streak = day
    d.lastClaim = now

    local amount = math.max(500, incomePerSec(d) * 120 * day)
    d.pumpkins += amount
    refresh(player)

    if day == 7 then
        notify(player, "🎁 Day 7 bonus! +" .. amount .. " pumpkins AND a free Lucky Egg!")
        grantPet(player, d, pickPet(true))
    else
        notify(player, "🎁 Day " .. day .. " reward: +" .. amount .. " pumpkins! Come back tomorrow (day 7 = free Lucky Egg)!")
    end
    save(player)
end)

local lastCode = {}
RedeemRemote.OnServerEvent:Connect(function(player, code)
    local d = sessions[player]
    if not d then return end
    if typeof(code) ~= "string" or #code > 30 then return end

    local now = os.clock()
    if lastCode[player] and now - lastCode[player] < 1 then return end
    lastCode[player] = now

    local cleaned = string.upper((code:gsub("%s", "")))
    local reward = CODES[cleaned]
    if not reward then
        notify(player, "❌ Invalid code")
        return
    end

    if d.codes[cleaned] then
        notify(player, "You already redeemed that code!")
        return
    end

    d.codes[cleaned] = true
    if reward.pumpkins then
        d.pumpkins += reward.pumpkins
    end
    refresh(player)
    notify(player, "✅ Code redeemed!" .. (reward.pumpkins and (" +" .. reward.pumpkins .. " pumpkins") or "") .. (reward.egg and " + free Lucky Egg!" or ""))
    if reward.egg then
        grantPet(player, d, pickPet(true))
    end
    save(player)
end)

Players.PlayerRemoving:Connect(function(player)
    lastHatch[player] = nil
    lastCode[player] = nil
end)

-- ------------------------------------------------------------
-- Monetization
-- ------------------------------------------------------------
PromptPurchase.OnServerEvent:Connect(function(player, kind)
    if kind == "pass" and GAMEPASS_2X ~= 0 then
        MarketplaceService:PromptGamePassPurchase(player, GAMEPASS_2X)
    elseif kind == "auto" and GAMEPASS_AUTO ~= 0 then
        MarketplaceService:PromptGamePassPurchase(player, GAMEPASS_AUTO)
    elseif kind == "pack" and PRODUCT_PUMPKIN_PACK ~= 0 then
        MarketplaceService:PromptProductPurchase(player, PRODUCT_PUMPKIN_PACK)
    elseif kind == "lucky" and PRODUCT_LUCKY_EGG ~= 0 then
        MarketplaceService:PromptProductPurchase(player, PRODUCT_LUCKY_EGG)
    end
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
    local d = sessions[player]
    if not purchased or not d then return end
    if GAMEPASS_2X ~= 0 and passId == GAMEPASS_2X then
        d.has2x = true
        refresh(player)
        notify(player, "✨ 2x Pumpkins unlocked! Thank you!")
    elseif GAMEPASS_AUTO ~= 0 and passId == GAMEPASS_AUTO then
        d.hasAuto = true
        refresh(player)
        notify(player, "🤖 Auto Clicker unlocked! Free clicks every second!")
    end
end)

MarketplaceService.ProcessReceipt = function(info)
    local player = Players:GetPlayerByUserId(info.PlayerId)
    local d = player and sessions[player]
    if not d then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    if PRODUCT_PUMPKIN_PACK ~= 0 and info.ProductId == PRODUCT_PUMPKIN_PACK then
        local amount = packAmount(d)
        d.pumpkins += amount
        refresh(player)
        save(player)
        notify(player, "🎃 Pumpkin Pack delivered! +" .. amount)
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end

    if PRODUCT_LUCKY_EGG ~= 0 and info.ProductId == PRODUCT_LUCKY_EGG then
        grantPet(player, d, pickPet(true))
        save(player)
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end

    return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- ------------------------------------------------------------
-- Passive loop
-- ------------------------------------------------------------
task.spawn(function()
    while true do
        task.wait(1)
        for player, d in pairs(sessions) do
            d.pumpkins += incomePerSec(d)
            if d.hasAuto then
                d.pumpkins += clickPower(d) * AUTO_CLICKS_PER_SEC
            end

            if os.clock() >= d.nextGolden and not d.golden and playerPlot[player] then
                d.nextGolden = os.clock() + math.random(60, 140)
                spawnGolden(player, d)
            end

            refresh(player)
        end
    end
end)

-- Music
if MUSIC_ID ~= 0 then
    local music = Instance.new("Sound")
    music.Name = "SpookyMusic"
    music.SoundId = "rbxassetid://" .. MUSIC_ID
    music.Looped = true
    music.Volume = 0.4
    music.Parent = game:GetService("SoundService")
    music:Play()
end

game:BindToClose(function()
    for player in pairs(sessions) do
        task.spawn(save, player)
    end
    task.wait(3)
end)
