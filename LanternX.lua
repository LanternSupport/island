local repo = "https://raw.githubusercontent.com/LanternSupport/LanternLib/main/"

local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles

local Window = Library:CreateWindow({
    Title = "LanternX - Islands by : Butidontknow :)",
    Center = true,
    AutoShow = true,
    Resizable = true,
    ShowCustomCursor = false,
    UnlockMouseWhileOpen = true,
    NotifySide = "Right",
    TabPadding = 6,
    MenuFadeTime = 0.5
})

local Tabs = {
    Main = Window:AddTab("Main"),
    Farming = Window:AddTab("Farming"),
    Vending = Window:AddTab("Vending"),
    Building = Window:AddTab("Building"),
    Players = Window:AddTab("Players"),
    Settings = Window:AddTab("Settings")
}

-- ==========================================
-- [ MAIN TAB ]
-- ==========================================
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local StartTime = os.time()

local NET = ReplicatedStorage:FindFirstChild("_NetManaged", true)
if not NET then
    task.spawn(function()
        while not NET do
            NET = ReplicatedStorage:FindFirstChild("_NetManaged", true)
            task.wait(1)
        end
    end)
end

-- ==========================================
-- [ ANTI-CHEAT CONFIGURATION ]
-- ==========================================
local LanternAntiCheat = {
    HitBlock   = { Key = "Xoeoxuqilfgenamojfjmj", Bypass = "\a\240\159\164\163\240\159\164\161\a\n\a\n\a\nohIstskUiftvgjy" },
    PlaceBlock = { Key = "uwhiHAMdjExWka",        Bypass = "\a\240\159\164\163\240\159\164\161\a\n\a\n\a\nffEgdldU" },
    Harvest    = { Key = "dZnpyRtxna",            Bypass = "\a\240\159\164\163\240\159\164\161\a\n\a\n\a\nsDahbvdxZludavlcoipDDMYasPlcm" },
    HitMob     = { Key = "IucpoZdgwp",            Bypass = "\a\240\159\164\163\240\159\164\161\a\n\a\n\a\nefmmgivC" }
}


local CONFIG = {
    HARVEST_RANGE = 35,
    PLANT_RANGE = 45,
    AURA_RANGE_SQ = 2500,
    TWEEN_MAX_RANGE_SQ = 360000,
    HIT_COOLDOWN = 0.2,
    CACHE_POLL_RATE = 1.5,
    GRID_SNAP = 3,
    PLACEMENT_REACH = 12,

    -- [ CENTRAL DELAYS & SPEEDS ]
    TIMBER_HIT_DELAY = 0.05,       -- ความเร็วฟันต้นไม้ (Timber)
    MINING_HIT_DELAY = 0.05,       -- ความเร็วตีแร่ (Mining)
    PLANT_DELAY = 0.1,             -- ดีเลย์ระหว่างบล็อกสำหรับปลูก (Planting)
    PLOW_DELAY = 0.05,             -- ดีเลย์ระหว่างบล็อกสำหรับพรวนดิน (Plowing)
    
    -- Vending
    VENDING_ACTION_DELAY = 0.05,   -- ดีเลย์เปิด / ปิด / ทำรายการตู้ขายของ
    VENDING_SNIPE_DELAY = 0.01,    -- ลูปสแกน Snipe ตู้ขายของ
    
    -- Building
    BUILD_BATCH_DELAY = 0.15,      -- ดีเลย์การวางบล็อกเป็นชุด
    BUILD_FLIGHT_DELAY = 0.15,     -- ดีเลย์การวางบล็อกขณะลอยตัว / เคลื่อนที่
    BUILD_DESTROY_DELAY = 0.23,    -- ดีเลย์การทุบทำลายบล็อกปกติ
    BUILD_CYCLE_REST_DELAY = 0.5   -- ดีเลย์พักรอบ Anti-Rate Limit (ทุกๆ 41 บล็อก)
}

-- ==========================================
-- [ CENTRAL MOVEMENT SYSTEM ]
-- ==========================================
local LanternMovement = {
    Speed = 25,
    HoverHeight = 5,
    IsWorking = false,
    CurrentTween = nil,
    NoclipConn = nil,
    CurrentTargetPos = nil
}

function LanternMovement.Cancel()
    LanternMovement.IsWorking = false
    LanternMovement.CurrentTargetPos = nil
    if LanternMovement.CurrentTween then
        pcall(function() LanternMovement.CurrentTween:Cancel() end)
        LanternMovement.CurrentTween = nil
    end
    if LanternMovement.NoclipConn then
        pcall(function() LanternMovement.NoclipConn:Disconnect() end)
        LanternMovement.NoclipConn = nil
        pcall(function()
            local char = LocalPlayer and LocalPlayer.Character
            if char and typeof(char) == "Instance" and char.GetChildren then
                for _, part in ipairs(char:GetChildren()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                        part.CanCollide = true
                    end
                end
            end
        end)
    end
    pcall(function()
        local hrp = LocalPlayer and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local bv = hrp:FindFirstChild("LanternUniversalBV")
            if bv then bv:Destroy() end
        end
    end)
end

function LanternMovement.MoveTo(targetPos, speed, lookAtPos)
    speed = speed or LanternMovement.Speed
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    LanternMovement.IsWorking = true

    if not LanternMovement.NoclipConn then
        LanternMovement.NoclipConn = RunService.Stepped:Connect(function()
            if LanternMovement.IsWorking and LocalPlayer.Character then
                for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        part.CanCollide = false
                    end
                end
            end
        end)
    end

    local bv = hrp:FindFirstChild("LanternUniversalBV")
    if not bv then
        bv = Instance.new("BodyVelocity", hrp)
        bv.Name = "LanternUniversalBV"
        bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
        bv.Velocity = Vector3.new(0, 0, 0)
    end

    -- ป้องกันการสร้าง Tween ใหม่รัวๆ ถ้าเป้าหมายยังเป็นที่เดิม
    if LanternMovement.CurrentTargetPos and (LanternMovement.CurrentTargetPos - targetPos).Magnitude < 2 then
        if lookAtPos then
            hrp.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(lookAtPos.X, hrp.Position.Y, lookAtPos.Z))
        end
        return LanternMovement.CurrentTween
    end
    LanternMovement.CurrentTargetPos = targetPos

    local adjustedTarget = targetPos + Vector3.new(0, LanternMovement.HoverHeight, 0)
    local dist = (adjustedTarget - hrp.Position).Magnitude
    local timeToTravel = math.max(dist / speed, 0.05)

    if LanternMovement.CurrentTween then
        pcall(function() LanternMovement.CurrentTween:Cancel() end)
    end

    local info = TweenInfo.new(timeToTravel, Enum.EasingStyle.Linear)
    
    local targetCFrame = CFrame.new(adjustedTarget)
    if lookAtPos then
        targetCFrame = CFrame.lookAt(adjustedTarget, Vector3.new(lookAtPos.X, adjustedTarget.Y, lookAtPos.Z))
    else
        targetCFrame = targetCFrame * (hrp.CFrame - hrp.CFrame.Position)
    end
    
    LanternMovement.CurrentTween = TweenService:Create(hrp, info, {CFrame = targetCFrame})
    LanternMovement.CurrentTween:Play()
    
    return LanternMovement.CurrentTween
end


-- ==========================================
-- [ CENTRAL NETWORK & REMOTES REGISTRY ]
-- ==========================================
local LanternNetwork = {
    ErrorCount = 0
}

local LanternRemotes = {
    -- Farming
    HarvestCrop   = "CLIENT_HARVEST_CROP_REQUEST",
    PlaceBlock    = "CLIENT_BLOCK_PLACE_REQUEST",
    PlowBlock     = "CLIENT_PLOW_BLOCK_REQUEST",
    WaterBlock    = "CLIENT_WATER_BLOCK",
    FertilizeBlock= "CLIENT_FERTILIZE_BLOCK",
    Dig           = "client_request_21",

    -- Blocks & Combat
    HitBlock      = "CLIENT_BLOCK_HIT_REQUEST",
    HitMob        = "fLafXsVXagmlXhlc/UlpaomJfNzwc",
    CatchBug      = "itiDaqymcktboxbelgrtdltbxkGPYLsgme/pgrlnhwvwHfhhwEpgySomypbwcnqhbcqVw",

    -- Fishing
    FishCast      = "bybFwzowayukxnCeCx/ecxnnzkznjuFaqtmlrjrov",
    FishWin       = "bybFwzowayukxnCeCx/iNxxqhXmhuflLjt",
    FishFinish    = "bybFwzowayukxnCeCx/ilmIfpmuwieupafcjj",

    -- Vending Machines
    VendingOpen       = "deGzdggahhjo/qkXeOxsmwiafothorpqogpS",
    VendingEdit       = "deGzdggahhjo/yceVHErjjNihyeXjwKeyzfnyrwmcnaWnCo",
    VendingClose      = "deGzdggahhjo/QaardducNrilqsmxdiotkewau",
    VendingCloseSnipe = "deGzdggahhjo/ifzkjsqjzFvJn",
    VendingDeposit    = "deGzdggahhjo/ggzImj",
    VendingWithdraw   = "deGzdggahhjo/ytaJiyomainKgxefgrkF",
    VendingMode       = "deGzdggahhjo/rLPziSaNkyol",
    VendingBuy        = "deGzdggahhjo/dfiQxh"
}

function LanternNetwork.GetRemote(remoteName)
    if not NET then
        NET = ReplicatedStorage:FindFirstChild("_NetManaged", true)
    end
    local actualName = LanternRemotes[remoteName] or remoteName
    return NET and NET:FindFirstChild(actualName)
end

function LanternNetwork.Log(level, system, msg)
    local prefix = string.format("[LanternX - %s] [%s]", system, level)
    if level == "ERROR" then
        LanternNetwork.ErrorCount = LanternNetwork.ErrorCount + 1
        warn(prefix .. " " .. tostring(msg))
        if Library and Library.Notify then Library:Notify(string.format("[%s] Error: %s", system, tostring(msg)), 5) end
    elseif level == "INFO" then
        print(prefix .. " " .. tostring(msg))
    elseif level == "DEBUG" then
        warn(prefix .. " " .. tostring(msg))
    end
end

function LanternNetwork.SafeFire(system, remote, ...)
    if not remote then 
        LanternNetwork.Log("ERROR", system, "Remote is nil")
        return false 
    end
    local args = {...}
    local success, err = pcall(function()
        remote:FireServer(unpack(args))
    end)
    if not success then
        LanternNetwork.Log("ERROR", system, "FireServer Failed: " .. tostring(err))
    end
    return success
end

function LanternNetwork.SafeInvoke(system, remote, ...)
    if not remote then 
        LanternNetwork.Log("ERROR", system, "Remote is nil")
        return false, "Remote is nil"
    end
    local args = {...}
    local success, err = pcall(function()
        return remote:InvokeServer(unpack(args))
    end)
    if not success then
        LanternNetwork.Log("ERROR", system, "InvokeServer Failed: " .. tostring(err))
    end
    return success, err
end

function LanternNetwork.HitBlock(HitRemote, block, part)
    if not block then return false end
    part = part or block:FindFirstChildWhichIsA("BasePart") or block
    
    local args = { { [LanternAntiCheat.HitBlock.Key] = LanternAntiCheat.HitBlock.Bypass, part = part, block = block, norm = Vector3.new(0,1,0), pos = Vector3.new(0,0,0) } }
    task.spawn(function()
        LanternNetwork.SafeInvoke("HitBlock", HitRemote, unpack(args))
    end)
    return true
end

function LanternNetwork.PlaceBlock(PlaceRemote, cframe, blockType)
    task.spawn(function()
        LanternNetwork.SafeInvoke("PlaceBlock", PlaceRemote, {
            [LanternAntiCheat.PlaceBlock.Key] = LanternAntiCheat.PlaceBlock.Bypass,
            cframe = cframe,
            blockType = blockType,
            upperBlock = false
        })
    end)
    return true
end

function LanternNetwork.HitMob(HitRemote, mob)
    if not mob then return false end
    task.spawn(function()
        LanternNetwork.SafeFire("HitMob", HitRemote, "6164F31F-7600-48E7-866C-7229FEA1FDE1", {
            {
                hitUnit = mob,
                [LanternAntiCheat.HitMob.Key] = LanternAntiCheat.HitMob.Bypass
            }
        })
    end)
    return true
end

function LanternNetwork.Harvest(HarvestRemote, block)
    if not block then return false end
    task.spawn(function()
        LanternNetwork.SafeInvoke("Harvest", HarvestRemote, {
            [LanternAntiCheat.Harvest.Key] = LanternAntiCheat.Harvest.Bypass,
            player = LocalPlayer,
            model = block
        })
    end)
    return true
end

function LanternNetwork.Plow(PlowRemote, block)
    if not block then return false end
    task.spawn(function()
        LanternNetwork.SafeInvoke("Plow", PlowRemote, {
            ["block"] = block
        })
    end)
    return true
end

function LanternNetwork.WaterBlock(WaterRemote, block)
    if not block then return false end
    task.spawn(function()
        LanternNetwork.SafeInvoke("WaterBlock", WaterRemote, {
            block = block
        })
    end)
    return true
end

function LanternNetwork.Dig(DigRemote, block, shovelType)
    if not block then return false end
    task.spawn(function()
        LanternNetwork.SafeInvoke("Dig", DigRemote, {
            block = block,
            shovelType = shovelType or "shovel"
        })
    end)
    return true
end

function LanternNetwork.FishCast(castRemote, guid, playerLocation, direction, strength)
    if not castRemote then return false end
    task.spawn(function()
        LanternNetwork.SafeFire("FishCast", castRemote, guid, {
            {
                playerLocation = playerLocation,
                direction = direction,
                strength = strength or 1.06427796681722005
            }
        })
    end)
    return true
end

function LanternNetwork.FishWin(winRemote)
    if not winRemote then return false end
    task.spawn(function()
        LanternNetwork.SafeFire("FishWin", winRemote, {
            success = true
        })
    end)
    return true
end

function LanternNetwork.FishFinish(finishRemote, guid)
    if not finishRemote then return false end
    task.spawn(function()
        LanternNetwork.SafeFire("FishFinish", finishRemote, guid, { {} })
    end)
    return true
end

LanternNetwork.Vending = {}

function LanternNetwork.Vending.Open(remote, guid, machine)
    if not remote or not machine then return false end
    task.spawn(function()
        LanternNetwork.SafeFire("VendingOpen", remote, guid, { { vendingMachine = machine } })
    end)
    return true
end

function LanternNetwork.Vending.Edit(remote, guid, machine)
    if not remote or not machine then return false end
    task.spawn(function()
        LanternNetwork.SafeFire("VendingEdit", remote, guid, { { vendingMachine = machine } })
    end)
    return true
end

function LanternNetwork.Vending.Mode(remote, guid, machine, mode, price)
    if not remote or not machine then return false end
    task.spawn(function()
        LanternNetwork.SafeFire("VendingMode", remote, guid, { { mode = mode, vendingMachine = machine, player_tracking_category = "join_from_web", transactionPrice = price } })
    end)
    return true
end

function LanternNetwork.Vending.Deposit(remote, guid, machine, amount)
    if not remote or not machine then return false end
    task.spawn(function()
        LanternNetwork.SafeFire("VendingDeposit", remote, guid, { { vendingMachine = machine, player_tracking_category = "join_from_web", amount = amount } })
    end)
    return true
end

function LanternNetwork.Vending.Withdraw(remote, guid, machine, amount)
    if not remote or not machine then return false end
    task.spawn(function()
        LanternNetwork.SafeFire("VendingWithdraw", remote, guid, { { vendingMachine = machine, player_tracking_category = "join_from_web", amount = amount } })
    end)
    return true
end

function LanternNetwork.Vending.Close(remote, machine)
    if not remote or not machine then return false end
    task.spawn(function()
        LanternNetwork.SafeFire("VendingClose", remote, { vendingMachine = machine })
    end)
    return true
end

function LanternNetwork.Vending.Buy(remote, guid, machine, tool, amount)
    if not remote or not machine or not tool then return false end
    task.spawn(function()
        LanternNetwork.SafeFire("VendingBuy", remote, guid, { { vendingMachine = machine, player_tracking_category = "join_from_web", tool = tool, amount = amount } })
    end)
    return true
end

local function getblocksfolder()
    local pIsland = LocalPlayer:GetAttribute("island")
    if pIsland then
        local island = workspace:FindFirstChild("Islands") and workspace:FindFirstChild("Islands"):FindFirstChild(pIsland .. "-island")
        if island then
            local b = island:FindFirstChild("Blocks")
            if b then return b end
        end
    end
    local islands = workspace:FindFirstChild("Islands")
    if islands then
        for _, island in ipairs(islands:GetChildren()) do
            local b = island:FindFirstChild("Blocks")
            if b then return b end
        end
    end
    return workspace:FindFirstChild("Blocks") or (workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Blocks"))
end

local function filledcheck(Position)
    local Parts = workspace:FindPartsInRegion3(Region3.new(Position - Vector3.new(0.1,0.1,0.1), Position + Vector3.new(0.1,0.1,0.1)), nil, 50)
    for _, v in ipairs(Parts) do
        local parent = v.Parent
        if parent and parent.Name == "Blocks" then return true end
        if parent and parent.Parent and parent.Parent.Name == "Blocks" then return true end
    end
    return false
end

local CropMap = {
    ["Berry Bush"] = "berryBush",
    ["Blackberry Bush"] = "blackberryBush",
    ["Blueberry Bush"] = "blueberryBush",
    ["Cactus"] = "cactus",
    ["Candy Cane"] = "candyCane",
    ["Carrot"] = "carrot",
    ["Chili Pepper"] = "chiliPepper",
    ["Cranberry Bush"] = "cranberryBush",
    ["Crystalline Ivy"] = "crystallineIvy",
    ["Dragonfruit"] = "dragonfruit",
    ["Grape"] = "grape",
    ["Melon"] = "melon",
    ["Onion"] = "onion",
    ["Optuntia"] = "optuntia",
    ["Pineapple"] = "pineapple",
    ["Potato"] = "potato",
    ["Pumpkin"] = "pumpkin",
    ["Radish"] = "radish",
    ["Raspberry Bush"] = "raspberryBush",
    ["Rice"] = "rice",
    ["Seaweed"] = "seaweed",
    ["Spinach"] = "spinach",
    ["Spirit"] = "spiritCrop",
    ["Starfruit"] = "starfruit",
    ["Strawberry Bush"] = "strawberryBush",
    ["Tomato"] = "tomato",
    ["Vine Stem"] = "vineStem",
    ["Void Parasite"] = "voidParasite",
    ["Wheat"] = "wheat"
}

local FarmingSettings = { 
    SelectedCrop = "Wheat", 
    AutoHarvest = false, 
    AutoPlant = false, 
    AutoPlow = false, 
    AutoUnplow = false, 
    AutoWaterSoil = false, 
    AutoFertilize = false }
local HarvestThread, PlantThread, PlowThread, UnplowThread, WaterSoilThread, FertilizeThread = nil, nil, nil, nil, nil, nil

-- ==========================================
-- [ CENTRAL BLOCK CACHE SYSTEM ]
-- ==========================================
_G.LanternCache = {
    Trees = {}, Rocks = {}, WildRocks = {}, Soil = {}, Grass = {}, Flowers = {}, Crops = {}
}

task.spawn(function()
    while true do
        if true then
            local tTrees, tRocks, tWildRocks, tSoil, tGrass, tFlowers, tCrops = {}, {}, {}, {}, {}, {}, {}
            local blocks = getblocksfolder()
            if blocks then
                for _, block in ipairs(blocks:GetChildren()) do
                    local name = string.lower(block.Name)
                    if string.find(name, "tree", 1, true) then table.insert(tTrees, block)
                    elseif string.find(name, "rock", 1, true) and name ~= "naturalrock1" then table.insert(tRocks, block)
                    elseif name == "soil" then table.insert(tSoil, block)
                    elseif name == "grass" or name == "tallgrass" or name == "naturalrock1" then table.insert(tGrass, block)
                    elseif string.find(name, "fertile", 1, true) then table.insert(tFlowers, block)
                    else table.insert(tCrops, block) end
                end
            end
            local wild = workspace:FindFirstChild("WildernessBlocks")
            if wild then
                for _, block in ipairs(wild:GetChildren()) do
                    if string.find(string.lower(block.Name), "rock", 1, true) then table.insert(tWildRocks, block) end
                end
            end
            _G.LanternCache.Trees = tTrees
            _G.LanternCache.Rocks = tRocks
            _G.LanternCache.WildRocks = tWildRocks
            _G.LanternCache.Soil = tSoil
            _G.LanternCache.Grass = tGrass
            _G.LanternCache.Flowers = tFlowers
            _G.LanternCache.Crops = tCrops
        end
        task.wait(CONFIG.CACHE_POLL_RATE)
    end
end)


-- ==========================================
-- [ SHARED UTILITIES ]
-- ==========================================
local function getClosestTarget(folder, filterFunc, hrp, maxDist)
    local closestDist, closestTarget = maxDist * maxDist, nil
    if not hrp or not folder then return nil end
    local pos = hrp.Position
    for _, v in ipairs(folder:GetChildren()) do
        if filterFunc(v) then
            local tPos = v:IsA("Model") and v:GetPivot().Position or v.Position
            local d = tPos - pos
            local distSq = d.X*d.X + d.Y*d.Y + d.Z*d.Z
            if distSq < closestDist then
                closestDist = distSq
                closestTarget = v
            end
        end
    end
    return closestTarget
end

local function ManageHarvestThread()
    if FarmingSettings.AutoHarvest then
        if not HarvestThread then
            HarvestThread = task.spawn(function()
                while FarmingSettings.AutoHarvest do
                    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if hrp and NET then
                        local actualName = string.lower(CropMap[FarmingSettings.SelectedCrop] or "wheat")
                        pcall(function()
                            local HarvestRemote = LanternNetwork.GetRemote("HarvestCrop")
                            if HarvestRemote then
                                for _, block in ipairs(_G.LanternCache.Crops) do
                                    if not FarmingSettings.AutoHarvest then break end
                                    if block and block.Parent and string.lower(block.Name) == actualName then
                                        if block:FindFirstChild("stage-3") then
                                            local bp = block:FindFirstChildWhichIsA("BasePart")
                                            if bp then
                                                local d = bp.Position - hrp.Position
                                                if math.abs(d.X) <= CONFIG.HARVEST_RANGE and math.abs(d.Z) <= CONFIG.HARVEST_RANGE and math.abs(d.Y) <= CONFIG.HARVEST_RANGE then
                                                    if not block:GetAttribute("HarvestAttempted") then
                                                        block:SetAttribute("HarvestAttempted", true)
                                                        task.spawn(function()
                                                            LanternNetwork.Harvest(HarvestRemote, block)
                                                            task.wait(CONFIG.CACHE_POLL_RATE)
                                                            if block and block.Parent then block:SetAttribute("HarvestAttempted", nil) end
                                                        end)
                                                        task.wait(0.1)
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end)
                    end
                    task.wait(0.1)
                end
                HarvestThread = nil
            end)
        end
    else
        if HarvestThread then task.cancel(HarvestThread) HarvestThread = nil end
    end
end

local function ManagePlantThread()
    if FarmingSettings.AutoPlant then
        if not PlantThread then
            PlantThread = task.spawn(function()
                while FarmingSettings.AutoPlant do
                    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if hrp and NET then
                        local actualName = CropMap[FarmingSettings.SelectedCrop] or "wheat"
                        local isBerry = string.find(string.lower(actualName), "bush") ~= nil
                        pcall(function()
                            local PlaceRemote = LanternNetwork.GetRemote("PlaceBlock")
                            if PlaceRemote then
                                local targetCache = isBerry and _G.LanternCache.Grass or _G.LanternCache.Soil
                                local placeOff = Vector3.new(0, 3, 0)
                                for _, v2 in ipairs(targetCache) do
                                    if not FarmingSettings.AutoPlant then break end
                                    if v2 and v2.Parent then
                                        local pos = v2:IsA("Model") and v2:GetPivot().Position or v2.Position
                                        if (pos - hrp.Position).Magnitude <= CONFIG.PLANT_RANGE and not filledcheck(pos + placeOff) then
                                            if not v2:GetAttribute("PlantAttempted") then
                                                v2:SetAttribute("PlantAttempted", true)
                                                task.spawn(function()
                                                    pcall(function() LanternNetwork.PlaceBlock(PlaceRemote, CFrame.new(pos + placeOff), actualName) end)
                                                    task.wait(5)
                                                    if v2 and v2.Parent then v2:SetAttribute("PlantAttempted", nil) end
                                                end)
                                                task.wait(CONFIG.PLANT_DELAY)
                                            end
                                        end
                                    end
                                end
                            end
                        end)
                    end
                    task.wait(CONFIG.PLANT_DELAY)
                end
                PlantThread = nil
            end)
        end
    else
        if PlantThread then task.cancel(PlantThread) PlantThread = nil end
    end
end

local PlowUnplowThread = nil
local function ManagePlowUnplowThread()
    if FarmingSettings.AutoPlow or FarmingSettings.AutoUnplow then
        if not PlowUnplowThread then
            PlowUnplowThread = task.spawn(function()
                while FarmingSettings.AutoPlow or FarmingSettings.AutoUnplow do
                    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if hrp and NET then
                        pcall(function()
                            local PlowRemote = LanternNetwork.GetRemote("PlowBlock")
                            if PlowRemote then
                                if FarmingSettings.AutoPlow then
                                    for _, v2 in ipairs(_G.LanternCache.Grass) do
                                        if v2 and v2.Parent and v2.Name == "grass" then
                                            local pos = v2:IsA("Model") and v2:GetPivot().Position or v2.Position
                                             if (pos - hrp.Position).Magnitude <= CONFIG.PLANT_RANGE then
                                                LanternNetwork.Plow(PlowRemote, v2)
                                                task.wait(CONFIG.PLOW_DELAY)
                                            end
                                        end
                                    end
                                end
                                if FarmingSettings.AutoUnplow then
                                    for _, v2 in ipairs(_G.LanternCache.Soil) do
                                        if v2 and v2.Parent and v2.Name == "soil" then
                                            local pos = v2:IsA("Model") and v2:GetPivot().Position or v2.Position
                                            if (pos - hrp.Position).Magnitude <= CONFIG.PLANT_RANGE then
                                                LanternNetwork.Plow(PlowRemote, v2)
                                                task.wait(CONFIG.PLOW_DELAY)
                                            end
                                        end
                                    end
                                end
                            end
                        end)
                    end
                    task.wait(0.5)
                end
                PlowUnplowThread = nil
            end)
        end
    else
        if PlowUnplowThread then task.cancel(PlowUnplowThread) PlowUnplowThread = nil end
    end
end

local function ManageWaterSoilThread()
    if FarmingSettings.AutoWaterSoil then
        if not WaterSoilThread then
            WaterSoilThread = task.spawn(function()
                local lastWatered = {}
                while FarmingSettings.AutoWaterSoil do
                    local char = LocalPlayer.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    if hrp and NET then
                        local tool = char:FindFirstChildWhichIsA("Tool")
                        local isHoldingWateringCan = tool and string.find(string.lower(tool.Name), "watering")
                        if isHoldingWateringCan then
                            local HitRemote = LanternNetwork.GetRemote("WaterBlock")
                            if HitRemote then
                                for _, block in ipairs(_G.LanternCache.Soil) do
                                    if block and block.Parent and block.Name == "soil" then
                                        local wateredObj = block:FindFirstChild("Watered")
                                        if not wateredObj or (wateredObj:IsA("BoolValue") and not wateredObj.Value) then
                                            local pos = block:IsA("Model") and block:GetPivot().Position or block.Position
                                            if (pos - hrp.Position).Magnitude <= CONFIG.PLANT_RANGE then
                                                local now = tick()
                                                if now - (lastWatered[block] or 0) > 1.5 then
                                                    lastWatered[block] = now
                                                    LanternNetwork.WaterBlock(HitRemote, block)
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    task.wait(0.2)
                end
                WaterSoilThread = nil
            end)
        end
    else
        if WaterSoilThread then task.cancel(WaterSoilThread) WaterSoilThread = nil end
    end
end

local function ManageFertilizeThread()
    if FarmingSettings.AutoFertilize then
        if not FertilizeThread then
            FertilizeThread = task.spawn(function()
                local lastFertilized = {}
                while FarmingSettings.AutoFertilize do
                    local char = LocalPlayer.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    if hrp and NET then
                        local tool = char:FindFirstChildWhichIsA("Tool")
                        local isHoldingFertilizer = tool and string.find(string.lower(tool.Name), "fertilizer")
                        if isHoldingFertilizer then
                            local HitRemote = LanternNetwork.GetRemote("FertilizeBlock")
                            if HitRemote then
                                for _, block in ipairs(_G.LanternCache.Soil) do
                                    if block and block.Parent and block.Name == "soil" then
                                        local fertObj = block:FindFirstChild("Fertilized")
                                        if not fertObj or (fertObj:IsA("IntValue") and fertObj.Value == 0) or (fertObj:IsA("NumberValue") and fertObj.Value == 0) then
                                            local pos = block:IsA("Model") and block:GetPivot().Position or block.Position
                                            if (pos - hrp.Position).Magnitude <= CONFIG.PLANT_RANGE then
                                                local now = tick()
                                                if now - (lastFertilized[block] or 0) > 1.5 then
                                                    lastFertilized[block] = now
                                                    LanternNetwork.WaterBlock(HitRemote, block)
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    task.wait(0.2)
                end
                FertilizeThread = nil
            end)
        end
    else
        if FertilizeThread then task.cancel(FertilizeThread) FertilizeThread = nil end
    end
end

local AutoWaterSettings = { Enabled = false }
local AutoWaterThread = nil
local function ManageWaterThread()
    if AutoWaterSettings.Enabled then
        if not AutoWaterThread then
            AutoWaterThread = task.spawn(function()
                local lastWatered = {}
                while AutoWaterSettings.Enabled do
                    local char = LocalPlayer.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    if hrp and NET then
                        local tool = char:FindFirstChildWhichIsA("Tool")
                        if tool and string.find(string.lower(tool.Name), "watering") then
                            local HitRemote = LanternNetwork.GetRemote("WaterBlock")
                            if HitRemote then
                                for _, block in ipairs(_G.LanternCache.Flowers) do
                                    if block and block.Parent then
                                        local pos = block:IsA("Model") and block:GetPivot().Position or block.Position
                                        if (pos - hrp.Position).Magnitude <= CONFIG.PLANT_RANGE then
                                            local now = tick()
                                            if now - (lastWatered[block] or 0) > 1 then
                                                lastWatered[block] = now
                                                LanternNetwork.WaterBlock(HitRemote, block)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    task.wait(0.2)
                end
                AutoWaterThread = nil
            end)
        end
    else
        if AutoWaterThread then task.cancel(AutoWaterThread) AutoWaterThread = nil end
    end
end

local AutoDigSettings = { Enabled = false, Targets = {["pileSnow"] = true} }
local AutoDigThread = nil
local function ManageAutoDig()
    if AutoDigSettings.Enabled then
        if not AutoDigThread then
            AutoDigThread = task.spawn(function()
                local lastDug = 0
                while AutoDigSettings.Enabled do
                    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if hrp and NET then
                        local DigRemote = LanternNetwork.GetRemote("Dig")
                        local wildernessBlocks = workspace:FindFirstChild("WildernessBlocks")
                        if DigRemote and wildernessBlocks then
                            local closestDist, closestBlock, currentPos = math.huge, nil, hrp.Position
                            for _, block in ipairs(wildernessBlocks:GetChildren()) do
                                if AutoDigSettings.Targets[block.Name] then
                                    local pos = block:IsA("Model") and block:GetPivot().Position or block.Position
                                    local distSq = (pos - currentPos).Magnitude
                                    if distSq < closestDist then closestDist = distSq; closestBlock = {block = block, pos = pos} end
                                end
                            end
                            if closestBlock then
                                local targetPos = closestBlock.pos
                                local dist = (targetPos - hrp.Position).Magnitude
                                if dist > 8 then
                                    LanternMovement.MoveTo(targetPos)
                                else
                                    if tick() - lastDug > (CONFIG.HIT_COOLDOWN or 0.3) then
                                        lastDug = tick()
                                        pcall(function()
                                            local foundShovel = "shovel"
                                            local char = LocalPlayer.Character
                                            if char then for _, item in ipairs(char:GetChildren()) do if item:IsA("Tool") and string.find(string.lower(item.Name), "shovel") then foundShovel = item.Name break end end end
                                            if foundShovel == "shovel" then
                                                local bp = LocalPlayer:FindFirstChild("Backpack")
                                                if bp then for _, item in ipairs(bp:GetChildren()) do if item:IsA("Tool") and string.find(string.lower(item.Name), "shovel") then foundShovel = item.Name break end end end
                                            end
                                            LanternNetwork.Dig(DigRemote, closestBlock.block, foundShovel)
                                        end)
                                        task.wait(0.2)
                                    end
                                end
                            else
                                LanternMovement.Cancel()
                            end
                        end
                    end
                    task.wait(0.1)
                end
                AutoDigThread = nil
            end)
        end
    else
        if AutoDigThread then task.cancel(AutoDigThread) AutoDigThread = nil end
        LanternMovement.Cancel()
    end
end

local GrassRockSettings = { Enabled = false, IsWorking = false }
local GrassRockThread = nil
local function ManageGrassRockThread()
    if GrassRockSettings.Enabled then
        if not GrassRockThread then
            GrassRockThread = task.spawn(function()
                local lastHit = 0
                while GrassRockSettings.Enabled do
                    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if hrp and NET then
                        local HitRemote = LanternNetwork.GetRemote("HitBlock")
                        if HitRemote then
                            local closestDist, closestBlock, hitPart, targetPos = math.huge, nil, nil, nil
                            for _, block in ipairs(_G.LanternCache.Grass) do
                                if block and block.Parent then
                                    local name = string.lower(block.Name)
                                    if name == "tallgrass" or name == "naturalrock1" then
                                        local pos = block:IsA("Model") and (block.PrimaryPart and block.PrimaryPart.Position or block:GetPivot().Position) or block:IsA("BasePart") and block.Position
                                        if pos then
                                            local dist = (pos - hrp.Position).Magnitude
                                            if dist < closestDist then
                                                closestDist = dist
                                                closestBlock = block
                                                hitPart = block:FindFirstChildWhichIsA("BasePart") or block
                                                targetPos = pos
                                            end
                                        end
                                    end
                                end
                            end
                            
                            if closestBlock and targetPos then
                                GrassRockSettings.IsWorking = true
                                local dist = (targetPos - hrp.Position).Magnitude
                                if dist > 8 then
                                    LanternMovement.MoveTo(targetPos)
                                else
                                    if tick() - lastHit > (CONFIG.HIT_COOLDOWN or 0.3) then
                                        lastHit = tick()
                                        LanternNetwork.HitBlock(HitRemote, closestBlock, hitPart)
                                    end
                                end
                            else
                                GrassRockSettings.IsWorking = false
                                LanternMovement.Cancel()
                            end
                        end
                    end
                    task.wait(0.1)
                end
                GrassRockThread = nil
            end)
        end
    else
        if GrassRockThread then task.cancel(GrassRockThread) GrassRockThread = nil end
        LanternMovement.Cancel()
    end
end

local function getentitiesfolders()
    local folders = {}
    local islandsFolder = workspace:FindFirstChild("Islands")
    if islandsFolder then
        for _, islandFolder in ipairs(islandsFolder:GetChildren()) do
            local ents = islandFolder:FindFirstChild("Entities")
            if ents then table.insert(folders, ents) end
        end
    end
    local ents = workspace:FindFirstChild("Entities")
    if ents then table.insert(folders, ents) end
    local wild = workspace:FindFirstChild("WildernessBlocks")
    if wild then
        local wildEnts = wild:FindFirstChild("Entities")
        if wildEnts then table.insert(folders, wildEnts) end
    end
    local wildIsland = workspace:FindFirstChild("WildernessIsland")
    if wildIsland then
        local wildIslandEnts = wildIsland:FindFirstChild("Entities")
        if wildIslandEnts then table.insert(folders, wildIslandEnts) end
    end
    return folders
end

local CatchSettings = { AutoSpirit = false, AutoAnimal = false, AutoBee = false, AutoFirefly = false, IsCatching = false }
local CatchThread = nil
local function ManageCatchThread()
    if CatchSettings.AutoSpirit or CatchSettings.AutoAnimal or CatchSettings.AutoBee or CatchSettings.AutoFirefly then
        if not CatchThread then
            CatchThread = task.spawn(function()
                local HttpService = game:GetService("HttpService")
                local lastSwing = 0
                while CatchSettings.AutoSpirit or CatchSettings.AutoAnimal or CatchSettings.AutoBee or CatchSettings.AutoFirefly do
                    local char = LocalPlayer.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    if hrp and NET then
                        local tool = char:FindFirstChildWhichIsA("Tool")
                        local isHoldingNet = tool and string.find(string.lower(tool.Name), "net")
                        
                        if not isHoldingNet then
                            local backpack = LocalPlayer:FindFirstChild("Backpack")
                            if backpack then
                                for _, item in ipairs(backpack:GetChildren()) do
                                    if item:IsA("Tool") and string.find(string.lower(item.Name), "net") then
                                        local hum = char:FindFirstChild("Humanoid")
                                        if hum and hum.Health > 0 then
                                            pcall(function() hum:EquipTool(item) end)
                                            tool = item
                                            isHoldingNet = true
                                            break
                                        end
                                    end
                                end
                            end
                        end
                        
                        if isHoldingNet then
                            local CatchRemote = LanternNetwork.GetRemote("CatchBug")
                            if CatchRemote then
                                local folders = getentitiesfolders()
                                local closestDist, closestTarget = math.huge, nil
                                
                                for _, folder in ipairs(folders) do
                                    for _, v in ipairs(folder:GetChildren()) do
                                        local n = string.lower(v.Name)
                                        local isTarget = false
                                        if CatchSettings.AutoSpirit and string.find(n, "spirit") then isTarget = true end
                                        if CatchSettings.AutoAnimal and (string.find(n, "frog") or string.find(n, "rabbit")) then isTarget = true end
                                        if CatchSettings.AutoBee and string.find(n, "bee") then isTarget = true end
                                        if CatchSettings.AutoFirefly and string.find(n, "firefly") then isTarget = true end
                                        
                                        if isTarget then
                                            local pos = v:IsA("Model") and (v.PrimaryPart and v.PrimaryPart.Position or v:GetPivot().Position) or v:IsA("BasePart") and v.Position
                                            if pos then
                                                local dist = (pos - hrp.Position).Magnitude
                                                if dist < closestDist then
                                                    closestDist = dist
                                                    closestTarget = {obj = v, pos = pos}
                                                end
                                            end
                                        end
                                    end
                                end
                                
                                if closestTarget then
                                    CatchSettings.IsCatching = true
                                    local targetPos = closestTarget.pos
                                    local dist = (targetPos - hrp.Position).Magnitude
                                    
                                    if dist > 8 then
                                        LanternMovement.MoveTo(targetPos)
                                    else
                                        if tick() - lastSwing > (CONFIG.HIT_COOLDOWN or 0.3) then
                                            lastSwing = tick()
                                            local guid = HttpService:GenerateGUID(false)
                                            LanternNetwork.SafeFire("BugCatch", CatchRemote, guid, { { entity = closestTarget.obj } })
                                        end
                                    end
                                else
                                    CatchSettings.IsCatching = false
                                    LanternMovement.Cancel()
                                end
                            end
                        end
                    end
                    task.wait(0.1)
                end
                CatchThread = nil
            end)
        end
    else
        if CatchThread then task.cancel(CatchThread) CatchThread = nil end
        CatchSettings.IsCatching = false
        LanternMovement.Cancel()
    end
end

local TimberSettings = { 
    SelectedTree = "All", 
    TreeAura = false, 
    TweenToTree = false, 
    TreeTween = nil }
local TreeTypes = { "All", "Oak", "Pine", "Birch", "Maple", "Hickory", "Spirit", "Cherry Blossom" }

local function isTargetTree(name, selected)
    name = string.lower(name)
    
    local isCherry = string.find(name, "cherry") ~= nil
    local isOak = string.match(name, "^tree%d*$") ~= nil or string.find(name, "oak") ~= nil
    local isPine = string.find(name, "pine") ~= nil
    local isBirch = string.find(name, "birch") ~= nil
    local isMaple = string.find(name, "maple") ~= nil
    local isHickory = string.find(name, "hickory") ~= nil
    local isSpirit = string.find(name, "spirit") ~= nil

    if selected == "All" then 
        return isCherry or isOak or isPine or isBirch or isMaple or isHickory or isSpirit
    end

    if selected == "Cherry Blossom" then return isCherry end
    if selected == "Oak" then return isOak end
    return string.find(name, string.lower(selected)) ~= nil
end


local function isMagicWeapon(toolName)
    local tName = toolName:lower()
    return tName:find("spellbook") or tName:find("staff") or tName:find("scepter") or tName:find("tome") or tName:find("grimoire") or tName:find("magic")
end

local function getTargetPosition(v)
    if v:IsA("Model") then
        if v.PrimaryPart then return v.PrimaryPart.Position end
        local part = v:FindFirstChildWhichIsA("BasePart")
        if part then return part.Position end
    elseif v:IsA("BasePart") then
        return v.Position
    end
end

local TreeThread = nil
local lastTreeHitTime = 0

local function ManageTreeThread()
    if TimberSettings.TreeAura or TimberSettings.TweenToTree then
        if not TreeThread then
            TreeThread = task.spawn(function()
                while TimberSettings.TreeAura or TimberSettings.TweenToTree do
                    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if hrp and NET then
                        pcall(function()
                            local HitRemote = LanternNetwork.GetRemote("HitBlock")
                            if HitRemote then
                                local currentPos = hrp.Position
                                local maxDistSq = TimberSettings.TweenToTree and CONFIG.TWEEN_MAX_RANGE_SQ or CONFIG.AURA_RANGE_SQ
                                local closestDist, closestTree, hitPart = maxDistSq, nil, nil
                                
                                for _, block in ipairs(_G.LanternCache.Trees) do
                                    if block and block.Parent then
                                        if isTargetTree(block.Name, TimberSettings.SelectedTree) then
                                            local pos = getTargetPosition(block)
                                            if pos then
                                                local distSq = (pos - currentPos).Magnitude ^ 2
                                                if distSq < closestDist then
                                                    local trunk = block:FindFirstChild("trunk") or block:FindFirstChild("MeshPart") or block:FindFirstChildWhichIsA("BasePart")
                                                    if trunk then closestDist = distSq; closestTree = block; hitPart = trunk end
                                                end
                                            end
                                        end
                                    end
                                end

                                if closestTree and hitPart then
                                    local treePos = getTargetPosition(closestTree)
                                    if TimberSettings.TweenToTree and treePos then
                                        local dist = (treePos - currentPos).Magnitude
                                        if dist > 8 then
                                            LanternMovement.MoveTo(treePos)
                                        else
                                            if os.clock() - lastTreeHitTime >= CONFIG.HIT_COOLDOWN then
                                                task.spawn(function() LanternNetwork.HitBlock(HitRemote, closestTree, hitPart) end)
                                                lastTreeHitTime = os.clock()
                                            end
                                        end
                                    else
                                        if os.clock() - lastTreeHitTime >= CONFIG.HIT_COOLDOWN then
                                            task.spawn(function() LanternNetwork.HitBlock(HitRemote, closestTree, hitPart) end)
                                            lastTreeHitTime = os.clock()
                                        end
                                    end
                                else
                                    if TimberSettings.TweenToTree then
                                        LanternMovement.Cancel()
                                    end
                                end
                            end
                        end)
                    end
                    task.wait(CONFIG.TIMBER_HIT_DELAY)
                end
                TreeThread = nil
            end)
        end
    else
        if TreeThread then task.cancel(TreeThread) TreeThread = nil end
        LanternMovement.Cancel()
    end
end

local MiningSettings = { 
    SelectedRock = {["All"] = true}, 
    TargetArea = "Wilderness (Public)", 
    RockAura = false, 
    TweenToRock = false, 
    RockTween = nil }
local RockTypes = { "All", "Amethyst Stone", "Void Stone", "Andesite" , "Basalt" , "Clay", "Coal", "Copper", "Diamond", "Diamond Enchanted", "Diorite", "Electrite", "Emerald", "Gold", "Granite", "Ice", "Iron", "Marble", "Obsidian", "Opal", "Prismarine", "Sandstone", "Red Sandstone", "Slate", "Stone" }
local RockNameMap = { 
    ["Amethyst Stone"] = "rockAmethyst",
    ["Void Stone"] = "rockAmethystStone",
    ["Andesite"] = "rockAndesite",
    ["Basalt"] = "rockBasalt",
    ["Clay"] = "rockClay",
    ["Coal"] = "rockCoal",
    ["Copper"] = "rockCopper",
    ["Diamond"] = "rockDiamond",
    ["Diamond Enchanted"] = "rockDiamondEnchanted",
    ["Diorite"] = "rockDiorite",
    ["Electrite"] = "rockElectrite",
    ["Emerald"] = "rockEmerald",
    ["Gold"] = "rockGold",
    ["Granite"] = "rockGranite",
    ["Ice"] = "rockIce",
    ["Iron"] = "rockIron",
    ["Marble"] = "rockMarble",
    ["Obsidian"] = "rockObsidian",
    ["Opal"] = "rockOpal",
    ["Prismarine"] = "rockPrismarine",
    ["Sandstone"] = "rockSandstone",
    ["Red Sandstone"] = "rockSandstoneRed",
    ["Slate"] = "rockSlate",
    ["Stone"] = "rockStone" }

local function isTargetRock(name, selected)
    if type(selected) == "table" then
        if selected["All"] then
            for k, matchName in pairs(RockNameMap) do
                if k == "Amethyst Stone" then
                    if string.find(name, matchName) ~= nil and not string.find(name, "rockAmethystStone") then return true end
                else
                    if string.find(name, matchName) ~= nil then return true end
                end
            end
            return false
        end
        for k, v in pairs(selected) do
            if v then
                local matchName = RockNameMap[k]
                if matchName then
                    if k == "Amethyst Stone" then
                        if string.find(name, matchName) ~= nil and not string.find(name, "rockAmethystStone") then return true end
                    else
                        if string.find(name, matchName) ~= nil then return true end
                    end
                end
            end
        end
        return false
    end
    if selected == "All" then
        for k, matchName in pairs(RockNameMap) do
            if k == "Amethyst Stone" then
                if string.find(name, matchName) ~= nil and not string.find(name, "rockAmethystStone") then return true end
            else
                if string.find(name, matchName) ~= nil then return true end
            end
        end
        return false
    end
    local matchName = RockNameMap[selected]
    if not matchName then return false end
    if selected == "Amethyst Stone" then
        return string.find(name, matchName) ~= nil and not string.find(name, "rockAmethystStone")
    else
        return string.find(name, matchName) ~= nil
    end
end

local RockThread = nil
local lastRockHitTime = 0

local function ManageRockThread()
    if MiningSettings.RockAura or MiningSettings.TweenToRock then
        if not RockThread then
            RockThread = task.spawn(function()
                while MiningSettings.RockAura or MiningSettings.TweenToRock do
                    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if hrp and NET then
                        pcall(function()
                            local HitRemote = LanternNetwork.GetRemote("HitBlock")
                            if HitRemote then
                                local currentPos = hrp.Position
                                local maxDistSq = MiningSettings.TweenToRock and CONFIG.TWEEN_MAX_RANGE_SQ or CONFIG.AURA_RANGE_SQ
                                local closestDist, closestRock, hitPart = maxDistSq, nil, nil
                                
                                local targetCache = MiningSettings.TargetArea == "Private Island" and _G.LanternCache.Rocks or _G.LanternCache.WildRocks
                                for _, block in ipairs(targetCache) do
                                    if block and block.Parent then
                                        if string.find(block.Name, "rock", 1, true) then
                                            if isTargetRock(block.Name, MiningSettings.SelectedRock) then
                                                local pos = getTargetPosition(block)
                                                if pos then
                                                    local distSq = (pos - currentPos).Magnitude ^ 2
                                                    if distSq < closestDist then
                                                        local bp = block:IsA("BasePart") and block or block:FindFirstChildWhichIsA("BasePart")
                                                        if bp then closestDist = distSq; closestRock = block; hitPart = bp end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end

                                if closestRock and hitPart then
                                    local rockPos = getTargetPosition(closestRock)
                                    if MiningSettings.TweenToRock and rockPos then
                                        local dist = (rockPos - currentPos).Magnitude
                                        if dist > 8 then
                                            LanternMovement.MoveTo(rockPos)
                                        else
                                            if os.clock() - lastRockHitTime >= CONFIG.HIT_COOLDOWN then
                                                task.spawn(function() LanternNetwork.HitBlock(HitRemote, closestRock, hitPart) end)
                                                lastRockHitTime = os.clock()
                                            end
                                        end
                                    else
                                        if os.clock() - lastRockHitTime >= CONFIG.HIT_COOLDOWN then
                                            task.spawn(function() LanternNetwork.HitBlock(HitRemote, closestRock, hitPart) end)
                                            lastRockHitTime = os.clock()
                                        end
                                    end
                                else
                                    if MiningSettings.TweenToRock then
                                        LanternMovement.Cancel()
                                    end
                                end
                            end
                        end)
                    end
                    task.wait(CONFIG.MINING_HIT_DELAY)
                end
                RockThread = nil
            end)
        end
    else
        if RockThread then task.cancel(RockThread) RockThread = nil end
        LanternMovement.Cancel()
    end
end

local MobTypes = { "Slime", "Skeleton Pirate", "Angry Crab", "Buffalkor", "Rock Mimic", "Wizard Lizard", "Skorp", "Magma Blob", "Magma Golem", "Void Hound" }
local BossTypes = { "Slime King", "Slime Queen", "Kor", "Wizard Boss", "Bhaa", "Infernal Dragon", "Fhanhorn", "Void Serpent" }
local MonsterNameMap = { 
    ["Slime"] = "slime", 
    ["Skeleton Pirate"] = "skeletonPirate", 
    ["Angry Crab"] = "crab", ["Buffalkor"] = "buffalkor", 
    ["Rock Mimic"] = "rockmimic", 
    ["Wizard Lizard"] = "wizardlizard", 
    ["Skorp"] = "skorp", 
    ["Magma Blob"] = "magmablob", 
    ["Magma Golem"] = "magmagolem", 
    ["Void Hound"] = "voiddog", 
    ["Slime King"] = "slimeking", 
    ["Slime Queen"] = "slimequeen", 
    ["Kor"] = "golem", 
    ["Wizard Boss"] = "wizardboss", 
    ["Bhaa"] = "desertboss", 
    ["Infernal Dragon"] = "dragon", 
    ["Fhanhorn"] = "deerboss", 
    ["Void Serpent"] = "voidserpent" }
local BossSpawnMap = { 
    ["Slime King"] = "slime_king_spawn", 
    ["Slime Queen"] = "slime_queen_spawn", 
    ["Kor"] = "golem_spawn", 
    ["Wizard Boss"] = "wizard_boss_spawn", 
    ["Bhaa"] = "desert_boss_spawn", 
    ["Infernal Dragon"] = "dragon_boss_spawn", 
    ["Fhanhorn"] = "deer_boss_spawn", 
    ["Void Serpent"] = "void_serpent_spawn" }

local MonsterSettings = { 
    SelectedMob = "Slime", 
    SelectedBoss = "Slime King", 
    MonsterAura = false, 
    TweenToMob = false, 
    TweenToBoss = false, 
    AutoEquip = false, 
    LastWeapon = nil, 
    TweenMaxDistance = 1500, 
    MonsterTween = nil }
local MonsterThread = nil
local MonsterNoclipConn = nil

local function ManageMonsterThread()
    local isFarmingMob = MonsterSettings.TweenToMob
    local isFarmingBoss = MonsterSettings.TweenToBoss
    local isAura = MonsterSettings.MonsterAura
    if isAura or isFarmingMob or isFarmingBoss then        if not MonsterThread then
            MonsterThread = task.spawn(function()
                local lastHit = 0
                local lastTweenPos = nil
                while MonsterSettings.MonsterAura or MonsterSettings.TweenToMob or MonsterSettings.TweenToBoss do
                    local char = LocalPlayer.Character
                    if char then
                        local currentTool = char:FindFirstChildWhichIsA("Tool")
                        if currentTool then MonsterSettings.LastWeapon = currentTool.Name
                        elseif MonsterSettings.AutoEquip and MonsterSettings.LastWeapon then
                            local backpack = LocalPlayer:FindFirstChild("Backpack")
                            local toolToEquip = backpack and backpack:FindFirstChild(MonsterSettings.LastWeapon)
                            local hum = char:FindFirstChild("Humanoid")
                            if toolToEquip and hum and hum.Health > 0 then pcall(function() hum:EquipTool(toolToEquip) end) end
                        end
                    end
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    if hrp and NET then
                        local entities = workspace:FindFirstChild("Entities")
                        local wildIsland = workspace:FindFirstChild("WildernessIsland")
                        local wildEntities = wildIsland and wildIsland:FindFirstChild("Entities")
                        pcall(function()
                            local HitRemote = LanternNetwork.GetRemote("HitMob")
                            if HitRemote then
                                local currentPos = hrp.Position
                                local maxDistSq = (MonsterSettings.TweenToMob or MonsterSettings.TweenToBoss) and (MonsterSettings.TweenMaxDistance * MonsterSettings.TweenMaxDistance) or CONFIG.AURA_RANGE_SQ
                                local closestDist, closestMob, hitPart = maxDistSq, nil, nil
                                local mobList = {}
                                if entities then for _, v in ipairs(entities:GetChildren()) do table.insert(mobList, v) end end
                                if wildEntities then for _, v in ipairs(wildEntities:GetChildren()) do table.insert(mobList, v) end end
                                local targetSetting = MonsterSettings.TweenToBoss and MonsterSettings.SelectedBoss or MonsterSettings.SelectedMob
                                local searchName1 = MonsterNameMap[targetSetting]:lower()
                                local searchName2 = targetSetting:lower():gsub("%s", "")
                                local function isValidTarget(mobInst)
                                    if not mobInst then return false end
                                    local cName = mobInst.Name:lower():gsub("_", "")
                                    local isMatch = cName:find(searchName1) or cName:find(searchName2)
                                    if isMatch and MonsterSettings.TweenToMob and not MonsterSettings.TweenToBoss then
                                        if targetSetting == "Slime" then if cName:find("king") or cName:find("queen") then return false end end
                                    end
                                    return isMatch
                                end
                                    for _, mob in ipairs(mobList) do
                                        local hum = mob:FindFirstChild("Humanoid")
                                        local mobHrp = mob:FindFirstChild("HumanoidRootPart")
                                        if hum and hum.Health > 0 and mobHrp then
                                            if isValidTarget(mob) then
                                                local d = mobHrp.Position - currentPos
                                                local distSq = d.X*d.X + d.Y*d.Y + d.Z*d.Z
                                                if distSq < closestDist then closestDist = distSq; closestMob = mob; hitPart = mobHrp end
                                            end
                                        end
                                    end

                                if not closestMob and MonsterSettings.TweenToBoss then
                                    local bossKey = MonsterSettings.SelectedBoss
                                    local spawnPartName = BossSpawnMap[bossKey]
                                    if spawnPartName then
                                        local spawnPart = nil
                                        local spawnPrefabs = workspace:FindFirstChild("spawnPrefabs")
                                        local wildTriggers = spawnPrefabs and spawnPrefabs:FindFirstChild("WildEventTriggers")
                                        spawnPart = wildTriggers and wildTriggers:FindFirstChild(spawnPartName)
                                        if not spawnPart then
                                            for _, v in ipairs(workspace:GetDescendants()) do
                                                if v.Name:lower() == spawnPartName:lower() then if v:IsA("BasePart") or v:IsA("Model") then spawnPart = v break end end
                                            end
                                        end
                                        if spawnPart then
                                            local spPos = spawnPart:IsA("Model") and spawnPart:GetPivot().Position or spawnPart.Position
                                            local TargetPos = spPos + Vector3.new(0, 3, 0)
                                            local dist = (TargetPos - currentPos).Magnitude
                                            if dist > 6 then
                                                if not lastTweenPos or (lastTweenPos - TargetPos).Magnitude > 2 then
                                                    lastTweenPos = TargetPos
                                                    LanternMovement.MoveTo(TargetPos, 23)
                                                end
                                            else
                                                local Prompt = spawnPart:FindFirstChildOfClass("ProximityPrompt", true)
                                                if Prompt and Prompt.Enabled then fireproximityprompt(Prompt) task.wait(0.5) end
                                            end
                                            
                                        end
                                    end
                                elseif closestMob and hitPart then
                                    if MonsterSettings.TweenToMob or MonsterSettings.TweenToBoss then
                                        local mobPos = hitPart.Position
                                        local targetSetting = MonsterSettings.TweenToBoss and MonsterSettings.SelectedBoss or MonsterSettings.SelectedMob
                                        local customOffsets = { 
                                            ["Slime"] = -12, 
                                            ["Skeleton Pirate"] = -15, 
                                            ["Angry Crab"] = -12, 
                                            ["Buffalkor"] = -12, 
                                            ["Rock Mimic"] = -12, 
                                            ["Wizard Lizard"] = -22, 
                                            ["Skorp"] = -12, 
                                            ["Magma Blob"] = 51.5, 
                                            ["Magma Golem"] = -30, 
                                            ["Void Hound"] = -12, 
                                            ["Slime King"] = -12, 
                                            ["Slime Queen"] = -12, 
                                            ["Kor"] = 12, 
                                            ["Wizard Boss"] = -22, 
                                            ["Bhaa"] = -12, 
                                            ["Infernal Dragon"] = 50, 
                                            ["Fhanhorn"] = -12, 
                                            ["Void Serpent"] = -12 }
                                        local YO = customOffsets[targetSetting] or -11
                                        local targetPos = mobPos + Vector3.new(0, YO, 0)
                                        local dist = (targetPos - currentPos).Magnitude
                                        if dist > 4 then
                                            if not lastTweenPos or (lastTweenPos - targetPos).Magnitude > 2 then
                                                lastTweenPos = targetPos
                                                local isMagic = false
                                                local tool = char:FindFirstChildWhichIsA("Tool")
                                                if tool then
                                                    isMagic = isMagicWeapon(tool.Name)
                                                end
                                                LanternMovement.MoveTo(targetPos, 23, isMagic and mobPos or nil)
                                            end
                                        end
                                        
                                    end
                                    if tick() - lastHit > 0.5 then
                                        lastHit = tick()
                                        task.spawn(function()
                                            pcall(function()
                                                local char = LocalPlayer.Character
                                                local tool = char and char:FindFirstChildWhichIsA("Tool")
                                                local isMagic = tool and isMagicWeapon(tool.Name) or false
                                                if tool and not isMagic then tool:Activate() end
                                                pcall(function()
                                                    local vim = game:GetService("VirtualInputManager")
                                                    local camera = workspace.CurrentCamera
                                                    if closestMob and closestMob:FindFirstChild("HumanoidRootPart") then
                                                        local targetPos = closestMob.HumanoidRootPart.Position
                                                        if isMagic then
                                                            local screenPos, onScreen = camera:WorldToViewportPoint(targetPos)
                                                            if not onScreen then camera.CFrame = CFrame.lookAt(camera.CFrame.Position, targetPos) screenPos, onScreen = camera:WorldToViewportPoint(targetPos) end
                                                            if onScreen then
                                                                vim:SendMouseButtonEvent(screenPos.X, screenPos.Y, 0, true, game, 0)
                                                                task.wait(0.05)
                                                                vim:SendMouseButtonEvent(screenPos.X, screenPos.Y, 0, false, game, 0)
                                                            end
                                                        else
                                                            vim:SendKeyEvent(true, Enum.KeyCode.ButtonR2, false, game)
                                                            task.wait(0.05)
                                                            vim:SendKeyEvent(false, Enum.KeyCode.ButtonR2, false, game)
                                                        end
                                                    end
                                                end)
                                                LanternNetwork.HitMob(HitRemote, closestMob)
                                            end)
                                        end)
                                    end
                                else
                                    LanternMovement.Cancel()
                                end
                            end
                        end)
                    end
                    task.wait(0.2)
                end
            end)
        end
    else
        LanternMovement.Cancel()
        if MonsterThread then task.cancel(MonsterThread) MonsterThread = nil end
    end
end

local FishingSettings = { AutoFishing = false }
local FishingThread = nil
local function ManageFishingThread()
    if FishingSettings.AutoFishing then
        if not FishingThread then
            FishingThread = task.spawn(function()
                local currentCastGuid = nil
                local lastCastTime = 0
                while FishingSettings.AutoFishing do
                    local isMinigameActive = false
                    local pgui = LocalPlayer:FindFirstChild("PlayerGui")
                    local actionbar = pgui and pgui:FindFirstChild("ActionBarScreenGui") and pgui.ActionBarScreenGui:FindFirstChild("ActionBar")
                    if actionbar then
                        local minigame = actionbar:FindFirstChild("Minigame", true)
                        if minigame and minigame.Visible ~= false then
                            isMinigameActive = true
                            pcall(function()
                                local winRemote = LanternNetwork.GetRemote("FishWin")
                                if winRemote then LanternNetwork.FishWin(winRemote) end
                                local finishRemote = LanternNetwork.GetRemote("FishFinish")
                                if finishRemote then
                                    local guid = currentCastGuid or HttpService:GenerateGUID(false)
                                    LanternNetwork.FishFinish(finishRemote, guid)
                                end
                            end)
                            pcall(function()
                                local current = minigame
                                while current and current.Parent and current.Parent.Name ~= "RoactTree" do current = current.Parent end
                                if current and current.Parent then
                                    local roactTree = current.Parent
                                    local node2 = roactTree:FindFirstChild("2")
                                    if node2 then node2:Destroy() end
                                    current.Visible = false
                                    task.wait(0.1)
                                    current:Destroy()
                                end
                            end)
                            pcall(function()
                                local char = LocalPlayer.Character
                                local hum = char and char:FindFirstChild("Humanoid")
                                if hum then hum.Jump = true hum:ChangeState(Enum.HumanoidStateType.Jumping) end
                            end)
                            lastCastTime = 0 
                            task.wait(1)
                        end
                        pcall(function()
                            local gameOver = actionbar:FindFirstChild("GameOverScreen")
                            if gameOver then gameOver.Visible = false gameOver:Destroy() end
                        end)
                    end
                    if not isMinigameActive then
                        local char = LocalPlayer.Character
                        local hrp = char and char:FindFirstChild("HumanoidRootPart")
                        local tool = char and char:FindFirstChildWhichIsA("Tool")
                        local isHoldingRod = tool and tool.Name:lower():find("rod")
                        if isHoldingRod and hrp and (tick() - lastCastTime > 10) then
                            local closest = nil
                            local minDist = 150
                            for _, v in ipairs(workspace:GetDescendants()) do
                                if v.Name == "fishShadow" or v.Name == "fishShadowSpirit" then
                                    local pos = v:IsA("BasePart") and v.Position or (v:IsA("Model") and v.PrimaryPart and v.PrimaryPart.Position)
                                    if pos then
                                        local d = (pos - hrp.Position).Magnitude
                                        if d < minDist then minDist = d closest = pos end
                                    end
                                end
                            end
                            if not closest then closest = hrp.Position + (hrp.CFrame.LookVector * 15) end
                            if closest then
                                local guid = HttpService:GenerateGUID(false)
                                currentCastGuid = guid
                                local dir = (closest - hrp.Position).Unit
                                pcall(function()
                                    local castRemote = LanternNetwork.GetRemote("FishCast")
                                    if castRemote then LanternNetwork.FishCast(castRemote, guid, hrp.Position, dir, 1.06427796681722005) end
                                end)
                                lastCastTime = tick()
                            end
                        end
                    end
                    task.wait(0.1)
                end
                FishingThread = nil
            end)
        end
    else
        if FishingThread then task.cancel(FishingThread) FishingThread = nil end
    end
end

local VendingSettings = {
    SnipeItem = "",
    MaxPrice = 0,
    ScanRadius = 60,
    BuyAnyItem = false,
    AutoSnipe = false,
    ActionCoinAmount = 1000,
    ActionMode = 1,
    ActionPrice = 10,
    MaintenanceBypass = false,
    ClickSet = false,
    ClickWithdraw = false,
    AutoSnipePrice = 10
}

local VendingThread = nil
local MaintenanceConns = {}
local clickToSetConnection = nil

local REMOTES = {
    open = LanternRemotes.VendingOpen,
    edit = LanternRemotes.VendingEdit,
    close = LanternRemotes.VendingClose,
    closeSnipe = LanternRemotes.VendingCloseSnipe,
    deposit = LanternRemotes.VendingDeposit,
    withdraw = LanternRemotes.VendingWithdraw,
    mode = LanternRemotes.VendingMode,
    buy = LanternRemotes.VendingBuy
}



local function ApplyVendingConfig(V)
    task.spawn(function()
        local Guid = HttpService:GenerateGUID(false)
        LanternNetwork.Vending.Open(LanternNetwork.GetRemote(REMOTES.open), Guid, V)
        task.wait(CONFIG.VENDING_ACTION_DELAY)
        LanternNetwork.Vending.Edit(LanternNetwork.GetRemote(REMOTES.edit), Guid, V)
        task.wait(CONFIG.VENDING_ACTION_DELAY)
        if VendingSettings.ClickSet then
            LanternNetwork.Vending.Mode(LanternNetwork.GetRemote(REMOTES.mode), Guid, V, VendingSettings.ActionMode, VendingSettings.ActionPrice)
            task.wait(CONFIG.VENDING_ACTION_DELAY)
            local amount = VendingSettings.ActionCoinAmount
            local playerCoins = tonumber(LocalPlayer:GetAttribute("Coins")) or 0
            local cb = V:FindFirstChild("CoinBalance")
            local space = 5000000000 - (cb and cb.Value or 0)
            local dep = math.min(amount, space, playerCoins)
            if dep > 0 then
                LanternNetwork.Vending.Deposit(LanternNetwork.GetRemote(REMOTES.deposit), Guid, V, dep)
                task.wait(CONFIG.VENDING_ACTION_DELAY)
            end
        end
        if VendingSettings.ClickWithdraw then
            local cb = V:FindFirstChild("CoinBalance")
            local wd = cb and cb.Value or 0
            if wd > 0 then
                LanternNetwork.Vending.Withdraw(LanternNetwork.GetRemote(REMOTES.withdraw), Guid, V, wd)
                task.wait(CONFIG.VENDING_ACTION_DELAY)
            end
        end
        LanternNetwork.Vending.Close(LanternNetwork.GetRemote(REMOTES.close), V)
    end)
end

local function ToggleClickToSetVending(enabled)
    local Mouse = LocalPlayer:GetMouse()
    if enabled then
        if not clickToSetConnection then
            clickToSetConnection = Mouse.Button1Down:Connect(function()
                local target = Mouse.Target
                if target then
                    local vMachine = nil
                    local current = target
                    while current and current ~= workspace do
                        if current.Name:lower():find("vendingmachine") then vMachine = current break end
                        current = current.Parent
                    end
                    if not vMachine then
                        local blocks = getblocksfolder()
                        if blocks then
                            local closestDist = math.huge
                            for _, v in ipairs(blocks:GetChildren()) do
                                if v.Name:lower():find("vendingmachine") then
                                    local pos = v:IsA("Model") and (v.PrimaryPart and v.PrimaryPart.Position or v:GetPivot().Position) or v:IsA("BasePart") and v.Position
                                    if pos then
                                        local d = (pos - target.Position).Magnitude
                                        if d < 10 and d < closestDist then closestDist = d; vMachine = v end
                                    end
                                end
                            end
                        end
                    end
                    if vMachine then
                        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            local pos = vMachine:IsA("Model") and (vMachine.PrimaryPart and vMachine.PrimaryPart.Position or vMachine:GetPivot().Position) or vMachine:IsA("BasePart") and vMachine.Position
                            if pos then
                                local dist = (pos - hrp.Position).Magnitude
                                if dist <= VendingSettings.ScanRadius then ApplyVendingConfig(vMachine) end
                            end
                        end
                    end
                end
            end)
        end
    else
        if clickToSetConnection then clickToSetConnection:Disconnect(); clickToSetConnection = nil end
    end
end

local function ApplyMaintenanceBypass(vm)
    if not VendingSettings.MaintenanceBypass then return end
    if not (vm and vm.Parent) then return end
    if MaintenanceConns[vm] then return end
    local conns = {}
    local ue = vm:FindFirstChild("UserEditing")
    if ue and ue:IsA("ObjectValue") then
        if ue.Value ~= nil then ue.Value = nil end
        table.insert(conns, ue.Changed:Connect(function() if ue.Value ~= nil then ue.Value = nil end end))
    end
    local maint = vm:FindFirstChild("Maintenance")
    if maint and maint:IsA("BoolValue") then
        if maint.Value ~= false then maint.Value = false end
        table.insert(conns, maint.Changed:Connect(function() if maint.Value ~= false then maint.Value = false end end))
    end
    MaintenanceConns[vm] = conns
end

local function ToggleMaintenanceBypass(enabled)
    VendingSettings.MaintenanceBypass = enabled
    if enabled then
        local blocks = getblocksfolder()
        if blocks then for _, v in ipairs(blocks:GetChildren()) do if v.Name:lower():find("vendingmachine") then ApplyMaintenanceBypass(v) end end end
    else
        for _, conns in pairs(MaintenanceConns) do for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end end
        MaintenanceConns = {}
    end
end

local VendingESPThread = nil
local activeESPs = {}

local function ManageVendingESPThread()
    if VendingSettings.ESPToggle then
        if not VendingESPThread then
            VendingESPThread = task.spawn(function()
                while VendingSettings.ESPToggle do
                    local char = LocalPlayer.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    local blocksFolder = nil
                    local pIsland = LocalPlayer:GetAttribute("island")
                    if pIsland then
                        local island = workspace:FindFirstChild("Islands") and workspace.Islands:FindFirstChild(pIsland .. "-island")
                        if island then blocksFolder = island:FindFirstChild("Blocks") end
                    end
                    if not blocksFolder then blocksFolder = getblocksfolder() end
                    
                    local foundBlocks = {}
                    
                    if hrp and blocksFolder then
                        for _, V in ipairs(blocksFolder:GetChildren()) do
                            local nameLower = V.Name:lower()
                            local isVending = nameLower:find("vendingmachine")
                            local isChest = nameLower:find("chest")
                            
                            if isVending or isChest then
                                local pos = V:IsA("Model") and (V.PrimaryPart and V.PrimaryPart.Position or V:GetPivot().Position) or V:IsA("BasePart") and V.Position
                                if pos and (pos - hrp.Position).Magnitude <= 12 then
                                    foundBlocks[V] = true
                                    
                                    local gui = activeESPs[V]
                                    if not gui then
                                        gui = Instance.new("BillboardGui")
                                        gui.Name = "LanternESP"
                                        gui.Size = UDim2.new(0, 200, 0, 75)
                                        gui.StudsOffset = Vector3.new(0, isVending and 8 or 2.5, 0)
                                        gui.AlwaysOnTop = true
                                        
                                        local textLabel = Instance.new("TextLabel")
                                        textLabel.Size = UDim2.new(1, 0, 1, 0)
                                        textLabel.BackgroundTransparency = 1
                                        textLabel.TextStrokeTransparency = 0.5
                                        textLabel.TextColor3 = isVending and Color3.fromRGB(0, 255, 255) or Color3.fromRGB(255, 255, 0)
                                        textLabel.TextScaled = false
                                        textLabel.TextSize = 16
                                        textLabel.Font = Enum.Font.SourceSansBold
                                        textLabel.Parent = gui
                                        
                                        pcall(function() gui.Parent = game:GetService("CoreGui") end)
                                        if not gui.Parent then gui.Parent = LocalPlayer:FindFirstChild("PlayerGui") end
                                        gui.Adornee = V:IsA("Model") and V.PrimaryPart or V
                                        
                                        activeESPs[V] = gui
                                    end
                                    
                                    local text = ""
                                    if isVending then
                                        local itemCount = 0
                                        local contents = V:FindFirstChild("SellingContents")
                                        if contents then
                                            for _, item in ipairs(contents:GetChildren()) do
                                                local amtObj = item:FindFirstChild("Amount") or item:FindFirstChild("Value")
                                                itemCount = itemCount + (amtObj and amtObj.Value or 1)
                                            end
                                        end
                                        local cb = V:FindFirstChild("CoinBalance")
                                        local coinBalance = cb and cb.Value or 0
                                        text = string.format("Item : %d\nCoin : %d", itemCount, coinBalance)
                                    else
                                        local itemCount = 0
                                        local contents = V:FindFirstChild("Contents")
                                        if contents then
                                            for _, item in ipairs(contents:GetChildren()) do
                                                local amtObj = item:FindFirstChild("Amount") or item:FindFirstChild("Value")
                                                itemCount = itemCount + (amtObj and amtObj.Value or 1)
                                            end
                                        end
                                        text = string.format("%s\nItem : %d", V.Name, itemCount)
                                    end
                                    
                                    if gui and gui:FindFirstChild("TextLabel") then
                                        gui.TextLabel.Text = text
                                    end
                                end
                            end
                        end
                    end
                    
                    for block, gui in pairs(activeESPs) do
                        if not foundBlocks[block] or not block.Parent then
                            if gui then gui:Destroy() end
                            activeESPs[block] = nil
                        end
                    end
                    
                    task.wait(0.1)
                end
                VendingESPThread = nil
            end)
        end
    else
        if VendingESPThread then task.cancel(VendingESPThread) VendingESPThread = nil end
        for block, gui in pairs(activeESPs) do
            if gui then gui:Destroy() end
        end
        table.clear(activeESPs)
    end
end

local AutoSniperThread = nil
local function ManageAutoSniperThread()
    if VendingSettings.AutoSnipe or VendingSettings.BuyTargetItem then
        if not AutoSniperThread then
            AutoSniperThread = task.spawn(function()
                while VendingSettings.AutoSnipe or VendingSettings.BuyTargetItem do
                    pcall(function()
                        local blocks = nil
                        local pIsland = LocalPlayer:GetAttribute("island")
                        if pIsland then
                            local island = workspace:FindFirstChild("Islands") and workspace.Islands:FindFirstChild(pIsland .. "-island")
                            if island then blocks = island:FindFirstChild("Blocks") end
                        end
                        if not blocks then blocks = getblocksfolder() end
                        local char = LocalPlayer.Character
                        local hrp = char and char:FindFirstChild("HumanoidRootPart")
                        if blocks and hrp then
                            local playerCoins = tonumber(LocalPlayer:GetAttribute("Coins")) or 0
                            local targets = {}
                            
                            for _, V in ipairs(blocks:GetChildren()) do
                                if V.Name:lower():find("vendingmachine") then
                                    local pos = V:IsA("Model") and (V.PrimaryPart and V.PrimaryPart.Position or V:GetPivot().Position) or V:IsA("BasePart") and V.Position
                                    if pos then
                                        local dist = (pos - hrp.Position).Magnitude
                                        if dist <= (VendingSettings.Radius or 60) then
                                            table.insert(targets, V)
                                        end
                                    end
                                end
                            end
                            
                            for _, V in ipairs(targets) do
                                local mode = V:GetAttribute("mode") or V:GetAttribute("Mode")
                                if mode == nil then local mc = V:FindFirstChild("mode") or V:FindFirstChild("Mode") if mc then mode = mc.Value end end
                                
                                if mode == 0 then
                                    local price = V:GetAttribute("Price") or V:GetAttribute("TransactionPrice")
                                    if price == nil then local pc = V:FindFirstChild("Price") or V:FindFirstChild("TransactionPrice") if pc then price = pc.Value end end
                                    
                                    if price and price > 0 then
                                        local contents = V:FindFirstChild("SellingContents")
                                        if contents then
                                            local itemsToBuy = contents:GetChildren()
                                            if #itemsToBuy > 0 then
                                                local boughtSomething = false
                                                local Guid = HttpService:GenerateGUID(false)
                                                for _, itemToBuy in ipairs(itemsToBuy) do
                                                    if playerCoins < price then break end
                                                    
                                                    local itemName = itemToBuy.Name
                                                    local wantToBuy = false
                                                    
                                                    if VendingSettings.AutoSnipe and price <= (VendingSettings.AutoSnipePrice or 10) then
                                                        wantToBuy = true
                                                    end
                                                    
                                                    if VendingSettings.BuyTargetItem and VendingSettings.SnipeBuyItem and itemName == VendingSettings.SnipeBuyItem and price <= (VendingSettings.MaxPrice or 0) then
                                                        wantToBuy = true
                                                    end
                                                    
                                                    if wantToBuy then
                                                        local amtObj = itemToBuy:FindFirstChild("Amount") or itemToBuy:FindFirstChild("Value")
                                                        local available = amtObj and amtObj.Value or 0
                                                        if available > 0 then
                                                            local amtToBuy = math.min(available, math.floor(playerCoins / price))
                                                            if amtToBuy > 0 then
                                                                if not boughtSomething then
                                                                    LanternNetwork.Vending.Open(LanternNetwork.GetRemote(REMOTES.open), Guid, V)
                                                                    task.wait(CONFIG.VENDING_ACTION_DELAY)
                                                                    boughtSomething = true
                                                                end
                                                                LanternNetwork.Vending.Buy(LanternNetwork.GetRemote(REMOTES.buy), Guid, V, itemToBuy, amtToBuy)
                                                                playerCoins = playerCoins - (price * amtToBuy)
                                                                task.wait(CONFIG.VENDING_ACTION_DELAY)
                                                            end
                                                        end
                                                    end
                                                end
                                                if boughtSomething then
                                                    LanternNetwork.Vending.Close(LanternNetwork.GetRemote(REMOTES.closeSnipe), V)
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end)
                    
                    task.wait(CONFIG.VENDING_SNIPE_DELAY)
                end
                AutoSniperThread = nil
            end)
        end
    else
        if AutoSniperThread then task.cancel(AutoSniperThread) AutoSniperThread = nil end
    end
end

-- ==========================================
-- [ BUILDING SYSTEM BACKEND ]
-- ==========================================
local BuildSettings = { ShowBox = false, BlueprintMode = false, Rotation = 0, Clipboard = {}, IsWorking = false, Conn = nil, SavedBlueprintMode = false, SavedRotation = 0, BlueprintData = {}, SavedConn = nil }
local SelectionPart, SelectionBox, SelectionHandles, BlueprintFolder = nil, nil, nil, nil
local BlueprintPart, BlueprintBox, BlueprintHandles = nil, nil, nil
local SavedBlueprintPart, SavedBlueprintBox, SavedBlueprintHandles, SavedBlueprintFolder = nil, nil, nil, nil


local BlueprintDir = "LanternLib/Blueprints"
if isfolder and not isfolder(BlueprintDir) then makefolder(BlueprintDir) end

local function GetSavedBlueprints()
    local files = {}
    if isfolder and isfolder(BlueprintDir) then
        for _, file in ipairs(listfiles(BlueprintDir)) do
            if file:match("%.json$") then
                local filename = file:match("([^/\\]+)%.json$")
                if filename then table.insert(files, filename) end
            end
        end
    end
    return files
end

local function SaveBlueprint(name)
    if not name or name == "" then
        Library:Notify("Please enter a blueprint name!", 3)
        return
    end
    if #BuildSettings.Clipboard == 0 then
        Library:Notify("Clipboard is empty! Copy something first.", 3)
        return
    end
    
    local serialized = {}
    for _, item in ipairs(BuildSettings.Clipboard) do
        table.insert(serialized, {
            name = item.name,
            x = item.offset.X,
            y = item.offset.Y,
            z = item.offset.Z,
            rx = item.rx or 0,
            ry = item.ry or 0,
            rz = item.rz or 0
        })
    end
    
    local success, encoded = pcall(function() return HttpService:JSONEncode(serialized) end)
    if success then
        writefile(BlueprintDir .. "/" .. name .. ".json", encoded)
        Library:Notify("Blueprint '" .. name .. "' saved successfully!", 3)
    else
        Library:Notify("Failed to encode blueprint.", 3)
    end
end

local function LoadBlueprint(name)
    local path = BlueprintDir .. "/" .. name .. ".json"
    if not isfile(path) then
        Library:Notify("Blueprint file not found!", 3)
        return
    end
    
    local success, content = pcall(function() return readfile(path) end)
    if not success or not content then
        Library:Notify("Failed to read blueprint file.", 3)
        return
    end
    
    local success2, decoded = pcall(function() return HttpService:JSONDecode(content) end)
    if not success2 or type(decoded) ~= "table" then
        Library:Notify("Failed to decode blueprint JSON.", 3)
        return
    end
    
    BuildSettings.BlueprintData = {}
    for _, item in ipairs(decoded) do
        if item.name and item.x and item.y and item.z then
            table.insert(BuildSettings.BlueprintData, {
                name = item.name,
                offset = Vector3.new(item.x, item.y, item.z),
                rx = item.rx or 0,
                ry = item.ry or 0,
                rz = item.rz or 0
            })
        end
    end
    Library:Notify("Blueprint '" .. name .. "' loaded successfully!", 3)
end

local function getBuildBlocksFolder()
    local pIsland = LocalPlayer:GetAttribute("island")
    if pIsland then
        local island = workspace:FindFirstChild("Islands") and workspace.Islands:FindFirstChild(pIsland .. "-island")
        if island then
            local b = island:FindFirstChild("Blocks")
            if b then return b end
        end
    end
    return getblocksfolder()
end

local function InitSelectionVisuals()
    if not SelectionPart then
        SelectionPart = Instance.new("Part")
        SelectionPart.Name = "LanternX_SelectionPart"
        SelectionPart.Anchored = true
        SelectionPart.CanCollide = false
        SelectionPart.Transparency = 0.8
        SelectionPart.Color = Color3.fromRGB(0, 150, 255)
        SelectionPart.Size = Vector3.new(CONFIG.GRID_SNAP, CONFIG.GRID_SNAP, CONFIG.GRID_SNAP)
        
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local blocksFolder = getBuildBlocksFolder()
        if hrp and blocksFolder then
            local currentPos = hrp.Position
            local closestDist = math.huge
            local closestBlock = nil
            for _, block in ipairs(blocksFolder:GetChildren()) do
                local bpos = block:IsA("Model") and block:GetPivot().Position or block.Position
                local dist = (bpos - currentPos).Magnitude
                if dist < closestDist then closestDist = dist; closestBlock = bpos end
            end
            if closestBlock then SelectionPart.Position = closestBlock
            else SelectionPart.Position = Vector3.new(math.floor(currentPos.X/3 + 0.5)*3, math.floor(currentPos.Y/3 + 0.5)*3, math.floor(currentPos.Z/3 + 0.5)*3) end
        end
        SelectionPart.Parent = workspace
        
        SelectionBox = Instance.new("SelectionBox")
        SelectionBox.Adornee = SelectionPart
        SelectionBox.Color3 = Color3.fromRGB(0, 150, 255)
        SelectionBox.LineThickness = 0.05
        SelectionBox.Parent = SelectionPart
        
        SelectionHandles = Instance.new("Handles")
        SelectionHandles.Style = Enum.HandlesStyle.Resize
        SelectionHandles.Faces = Faces.new(Enum.NormalId.Top, Enum.NormalId.Bottom, Enum.NormalId.Left, Enum.NormalId.Right, Enum.NormalId.Front, Enum.NormalId.Back)
        SelectionHandles.Adornee = SelectionPart
        SelectionHandles.Parent = LocalPlayer:FindFirstChild("PlayerGui") or game:GetService("CoreGui")
        
        local initialSize, initialCFrame
        SelectionHandles.MouseButton1Down:Connect(function()
            initialSize = SelectionPart.Size
            initialCFrame = SelectionPart.CFrame
        end)
        
        SelectionHandles.MouseDrag:Connect(function(face, distance)
            local snappedDist = math.floor(distance / CONFIG.GRID_SNAP + 0.5) * CONFIG.GRID_SNAP
            if snappedDist == 0 then return end
            
            local deltaSize = Vector3.new()
            local deltaPos = Vector3.new()
            
            if face == Enum.NormalId.Top then deltaSize = Vector3.new(0, snappedDist, 0); deltaPos = Vector3.new(0, snappedDist/2, 0)
            elseif face == Enum.NormalId.Bottom then deltaSize = Vector3.new(0, snappedDist, 0); deltaPos = Vector3.new(0, -snappedDist/2, 0)
            elseif face == Enum.NormalId.Right then deltaSize = Vector3.new(snappedDist, 0, 0); deltaPos = Vector3.new(snappedDist/2, 0, 0)
            elseif face == Enum.NormalId.Left then deltaSize = Vector3.new(snappedDist, 0, 0); deltaPos = Vector3.new(-snappedDist/2, 0, 0)
            elseif face == Enum.NormalId.Back then deltaSize = Vector3.new(0, 0, snappedDist); deltaPos = Vector3.new(0, 0, snappedDist/2)
            elseif face == Enum.NormalId.Front then deltaSize = Vector3.new(0, 0, snappedDist); deltaPos = Vector3.new(0, 0, -snappedDist/2)
            end
            
            local newSize = initialSize + deltaSize
            if newSize.X >= 3 and newSize.Y >= 3 and newSize.Z >= 3 then
                SelectionPart.Size = newSize
                SelectionPart.CFrame = initialCFrame * CFrame.new(deltaPos)
            end
        end)
    end
end

local mouseUnlockConn = nil
local function ToggleSelectionBox(visible)
    BuildSettings.ShowBox = visible
    if visible then

        InitSelectionVisuals()
        if SelectionPart then 
            SelectionPart.Size = Vector3.new(CONFIG.GRID_SNAP, CONFIG.GRID_SNAP, CONFIG.GRID_SNAP) 
            
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local blocksFolder = getBuildBlocksFolder()
            if hrp and blocksFolder then
                local currentPos = hrp.Position
                local closestDist = math.huge
                local closestBlock = nil
                for _, block in ipairs(blocksFolder:GetChildren()) do
                    local bpos = block:IsA("Model") and block:GetPivot().Position or block.Position
                    local dist = (bpos - currentPos).Magnitude
                    if dist < closestDist then closestDist = dist; closestBlock = bpos end
                end
                
                if closestBlock then 
                    SelectionPart.Position = closestBlock
                else 
                    SelectionPart.Position = Vector3.new(math.round(currentPos.X/3)*3, math.round(currentPos.Y/3)*3, math.round(currentPos.Z/3)*3) 
                end
            end
            SelectionPart.Parent = workspace
        end
        if SelectionHandles then SelectionHandles.Parent = LocalPlayer:FindFirstChild("PlayerGui") or game:GetService("CoreGui") end
        
        if not mouseUnlockConn then
            local UserInputService = game:GetService("UserInputService")
            mouseUnlockConn = RunService.RenderStepped:Connect(function()
                if BuildSettings.ShowBox and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
                    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
                    UserInputService.MouseIconEnabled = true
                end
            end)
        end
    else
        if SelectionPart then SelectionPart.Parent = nil end
        if SelectionHandles then SelectionHandles.Parent = nil end
        if mouseUnlockConn then
            mouseUnlockConn:Disconnect()
            mouseUnlockConn = nil
        end
    end
end
local function InitBlueprintVisuals()
    if not BlueprintPart then
        BlueprintPart = Instance.new("Part")
        BlueprintPart.Name = "LanternX_BlueprintPart"
        BlueprintPart.Anchored = true
        BlueprintPart.CanCollide = false
        BlueprintPart.Transparency = 0.8
        BlueprintPart.Color = Color3.fromRGB(0, 255, 100) -- Green for Blueprint
        BlueprintPart.Size = Vector3.new(CONFIG.GRID_SNAP, CONFIG.GRID_SNAP, CONFIG.GRID_SNAP)
        
        BlueprintBox = Instance.new("SelectionBox")
        BlueprintBox.Adornee = BlueprintPart
        BlueprintBox.Color3 = Color3.fromRGB(0, 255, 100)
        BlueprintBox.LineThickness = 0.05
        BlueprintBox.Parent = BlueprintPart
        
        BlueprintHandles = Instance.new("Handles")
        BlueprintHandles.Style = Enum.HandlesStyle.Movement
        BlueprintHandles.Faces = Faces.new(Enum.NormalId.Top, Enum.NormalId.Bottom, Enum.NormalId.Left, Enum.NormalId.Right, Enum.NormalId.Front, Enum.NormalId.Back)
        BlueprintHandles.Adornee = BlueprintPart
        
        local initialPos
        BlueprintHandles.MouseButton1Down:Connect(function()
            initialPos = BlueprintPart.Position
        end)
        
        BlueprintHandles.MouseDrag:Connect(function(face, distance)
            local snappedDist = math.floor(distance / CONFIG.GRID_SNAP + 0.5) * CONFIG.GRID_SNAP
            if snappedDist == 0 then return end
            
            local deltaPos = Vector3.new()
            if face == Enum.NormalId.Top then deltaPos = Vector3.new(0, snappedDist, 0)
            elseif face == Enum.NormalId.Bottom then deltaPos = Vector3.new(0, -snappedDist, 0)
            elseif face == Enum.NormalId.Right then deltaPos = Vector3.new(snappedDist, 0, 0)
            elseif face == Enum.NormalId.Left then deltaPos = Vector3.new(-snappedDist, 0, 0)
            elseif face == Enum.NormalId.Back then deltaPos = Vector3.new(0, 0, snappedDist)
            elseif face == Enum.NormalId.Front then deltaPos = Vector3.new(0, 0, -snappedDist)
            end
            
            BlueprintPart.Position = initialPos + deltaPos
        end)
    end
end

local function UpdateBlueprint()
    if not BlueprintFolder then return end
    BlueprintFolder:ClearAllChildren()
    if not BuildSettings.BlueprintMode then return end
    if not BlueprintPart then return end
    
    local center = BlueprintPart.Position
    local rad = math.rad(BuildSettings.Rotation)
    local cosR = math.floor(math.cos(rad) + 0.5)
    local sinR = math.floor(math.sin(rad) + 0.5)
    
    for _, item in ipairs(BuildSettings.Clipboard) do
        local rx = item.offset.X * cosR - item.offset.Z * sinR
        local rz = item.offset.X * sinR + item.offset.Z * cosR
        local finalOffset = Vector3.new(rx, item.offset.Y, rz)
        
        local p = Instance.new("Part")
        p.Size = Vector3.new(3,3,3)
        p.Anchored = true
        p.CanCollide = false
        p.Transparency = 0.5
        p.Color = Color3.new(0, 1, 1)
        p.CFrame = CFrame.new(center + finalOffset) * CFrame.Angles(0, rad, 0) * CFrame.Angles(item.rx or 0, item.ry or 0, item.rz or 0)
        p.Parent = BlueprintFolder
    end
end

local function ToggleBlueprintMode(visible)
    BuildSettings.BlueprintMode = visible
    if visible then
        InitBlueprintVisuals()
        if BlueprintPart then 
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local blocksFolder = getBuildBlocksFolder()
            if hrp and blocksFolder then
                local currentPos = hrp.Position
                local closestDist = math.huge
                local closestBlock = nil
                for _, block in ipairs(blocksFolder:GetChildren()) do
                    local bpos = block:IsA("Model") and block:GetPivot().Position or block.Position
                    local dist = (bpos - currentPos).Magnitude
                    if dist < closestDist then closestDist = dist; closestBlock = bpos end
                end
                
                if closestBlock then 
                    BlueprintPart.Position = closestBlock
                else 
                    BlueprintPart.Position = Vector3.new(math.round(currentPos.X/3)*3, math.round(currentPos.Y/3)*3, math.round(currentPos.Z/3)*3) 
                end
            end
            BlueprintPart.Parent = workspace
        end
        if BlueprintHandles then BlueprintHandles.Parent = LocalPlayer:FindFirstChild("PlayerGui") or game:GetService("CoreGui") end
        
        if not BlueprintFolder then BlueprintFolder = Instance.new("Folder", workspace) BlueprintFolder.Name = "LanternX_Blueprint" end
        UpdateBlueprint()
        if BlueprintPart then
            if BuildSettings.Conn then BuildSettings.Conn:Disconnect() end
            BuildSettings.Conn = BlueprintPart:GetPropertyChangedSignal("Position"):Connect(UpdateBlueprint)
        end
    else
        if BlueprintPart then BlueprintPart.Parent = nil end
        if BlueprintHandles then BlueprintHandles.Parent = nil end
        if BlueprintFolder then BlueprintFolder:ClearAllChildren() end
        if BuildSettings.Conn then BuildSettings.Conn:Disconnect() BuildSettings.Conn = nil end
    end
end

local function InitSavedBlueprintVisuals()
    if not SavedBlueprintPart then
        SavedBlueprintPart = Instance.new("Part")
        SavedBlueprintPart.Name = "LanternX_SavedBlueprintPart"
        SavedBlueprintPart.Anchored = true
        SavedBlueprintPart.CanCollide = false
        SavedBlueprintPart.Transparency = 0.8
        SavedBlueprintPart.Color = Color3.fromRGB(255, 150, 0) -- Orange for Saved Blueprint
        SavedBlueprintPart.Size = Vector3.new(CONFIG.GRID_SNAP, CONFIG.GRID_SNAP, CONFIG.GRID_SNAP)
        
        SavedBlueprintBox = Instance.new("SelectionBox")
        SavedBlueprintBox.Adornee = SavedBlueprintPart
        SavedBlueprintBox.Color3 = Color3.fromRGB(255, 150, 0)
        SavedBlueprintBox.LineThickness = 0.05
        SavedBlueprintBox.Parent = SavedBlueprintPart
        
        SavedBlueprintHandles = Instance.new("Handles")
        SavedBlueprintHandles.Style = Enum.HandlesStyle.Movement
        SavedBlueprintHandles.Faces = Faces.new(Enum.NormalId.Top, Enum.NormalId.Bottom, Enum.NormalId.Left, Enum.NormalId.Right, Enum.NormalId.Front, Enum.NormalId.Back)
        SavedBlueprintHandles.Adornee = SavedBlueprintPart
        
        local initialPos
        SavedBlueprintHandles.MouseButton1Down:Connect(function()
            initialPos = SavedBlueprintPart.Position
        end)
        
        SavedBlueprintHandles.MouseDrag:Connect(function(face, distance)
            local snappedDist = math.floor(distance / CONFIG.GRID_SNAP + 0.5) * CONFIG.GRID_SNAP
            if snappedDist == 0 then return end
            
            local deltaPos = Vector3.new()
            if face == Enum.NormalId.Top then deltaPos = Vector3.new(0, snappedDist, 0)
            elseif face == Enum.NormalId.Bottom then deltaPos = Vector3.new(0, -snappedDist, 0)
            elseif face == Enum.NormalId.Right then deltaPos = Vector3.new(snappedDist, 0, 0)
            elseif face == Enum.NormalId.Left then deltaPos = Vector3.new(-snappedDist, 0, 0)
            elseif face == Enum.NormalId.Back then deltaPos = Vector3.new(0, 0, snappedDist)
            elseif face == Enum.NormalId.Front then deltaPos = Vector3.new(0, 0, -snappedDist)
            end
            
            SavedBlueprintPart.Position = initialPos + deltaPos
        end)
    end
end

local function UpdateSavedBlueprint()
    if not SavedBlueprintFolder then return end
    SavedBlueprintFolder:ClearAllChildren()
    if not BuildSettings.SavedBlueprintMode then return end
    if not SavedBlueprintPart then return end
    
    local center = SavedBlueprintPart.Position
    local rad = math.rad(BuildSettings.SavedRotation)
    local cosR = math.floor(math.cos(rad) + 0.5)
    local sinR = math.floor(math.sin(rad) + 0.5)
    
    for _, item in ipairs(BuildSettings.BlueprintData) do
        local rx = item.offset.X * cosR - item.offset.Z * sinR
        local rz = item.offset.X * sinR + item.offset.Z * cosR
        local finalOffset = Vector3.new(rx, item.offset.Y, rz)
        
        local p = Instance.new("Part")
        p.Size = Vector3.new(3,3,3)
        p.Anchored = true
        p.CanCollide = false
        p.Transparency = 0.5
        p.Color = Color3.fromRGB(255, 150, 0)
        p.CFrame = CFrame.new(center + finalOffset) * CFrame.Angles(0, rad, 0) * CFrame.Angles(item.rx or 0, item.ry or 0, item.rz or 0)
        p.Parent = SavedBlueprintFolder
    end
end

local BlueprintTrackerUI = nil
local function UpdateBlueprintTrackerUI(visible)
    if BlueprintTrackerUI then BlueprintTrackerUI:Destroy(); BlueprintTrackerUI = nil end
    if not visible then return end
    
    local cg = game:GetService("CoreGui")
    local gui = Instance.new("ScreenGui")
    gui.Name = "LanternX_BlueprintTracker"
    gui.Parent = LocalPlayer:FindFirstChild("PlayerGui") or cg
    gui.ResetOnSpawn = false
    
    local frame = Instance.new("Frame", gui)
    frame.Size = UDim2.new(0, 260, 0, 320)
    frame.Position = UDim2.new(1, -280, 0.5, -160)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    frame.BorderColor3 = Color3.fromRGB(0, 0, 0)
    frame.BorderSizePixel = 1
    frame.Active = true
    frame.Draggable = true
    
    local inlineBorder = Instance.new("Frame", frame)
    inlineBorder.Size = UDim2.new(1, -2, 1, -2)
    inlineBorder.Position = UDim2.new(0, 1, 0, 1)
    inlineBorder.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    inlineBorder.BorderColor3 = Color3.fromRGB(45, 45, 45)
    inlineBorder.BorderSizePixel = 1
    
    local topAccent = Instance.new("Frame", inlineBorder)
    topAccent.Size = UDim2.new(1, 0, 0, 2)
    topAccent.Position = UDim2.new(0, 0, 0, 0)
    topAccent.BackgroundColor3 = Color3.fromRGB(255, 0, 0) -- Red Accent
    pcall(function() topAccent.BackgroundColor3 = Library.AccentColor or Color3.fromRGB(255, 0, 0) end)
    topAccent.BorderSizePixel = 0
    
    local title = Instance.new("TextLabel", inlineBorder)
    title.Size = UDim2.new(1, -10, 0, 25)
    title.Position = UDim2.new(0, 5, 0, 2)
    title.BackgroundTransparency = 1
    title.Text = "Blueprint Materials"
    title.TextColor3 = Color3.new(1,1,1)
    title.Font = Enum.Font.Code
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    
    local line = Instance.new("Frame", inlineBorder)
    line.Size = UDim2.new(1, -10, 0, 1)
    line.Position = UDim2.new(0, 5, 0, 28)
    line.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    line.BorderSizePixel = 0
    
    local scroll = Instance.new("ScrollingFrame", inlineBorder)
    scroll.Size = UDim2.new(1, -10, 1, -35)
    scroll.Position = UDim2.new(0, 5, 0, 30)
    scroll.BackgroundTransparency = 1
    scroll.ScrollBarThickness = 2
    scroll.ScrollBarImageColor3 = Color3.fromRGB(255, 0, 0)
    pcall(function() scroll.ScrollBarImageColor3 = Library.AccentColor or Color3.fromRGB(255, 0, 0) end)
    
    local list = Instance.new("UIListLayout", scroll)
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Padding = UDim.new(0, 5)
    
    local req = {}
    local total = 0
    for _, item in ipairs(BuildSettings.BlueprintData) do
        req[item.name] = (req[item.name] or 0) + 1
        total = total + 1
    end
    
    local allLabel = Instance.new("TextLabel", scroll)
    allLabel.Size = UDim2.new(1, 0, 0, 16)
    allLabel.BackgroundTransparency = 1
    allLabel.Text = "Block ALL : " .. total
    allLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
    allLabel.Font = Enum.Font.Code
    allLabel.TextSize = 14
    allLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local function GetInv(name)
        local c = 0
        local function ch(p)
            if not p then return end
            for _, i in ipairs(p:GetChildren()) do
                if string.lower(i.Name) == string.lower(name) then
                    local a = i:FindFirstChild("Amount") or i:FindFirstChild("Value")
                    c = c + (a and a.Value or 1)
                end
            end
        end
        ch(LocalPlayer:FindFirstChild("Backpack"))
        if LocalPlayer.Character then ch(LocalPlayer.Character) end
        return c
    end
    
    for name, reqAmt in pairs(req) do
        local invAmt = GetInv(name)
        local color = invAmt >= reqAmt and Color3.fromRGB(150, 255, 150) or Color3.fromRGB(255, 150, 150)
        
        local l = Instance.new("TextLabel", scroll)
        l.Size = UDim2.new(1, -5, 0, 14)
        l.BackgroundTransparency = 1
        l.Text = "- " .. name .. " : [" .. invAmt .. "] / [" .. reqAmt .. "]"
        l.TextColor3 = color
        l.Font = Enum.Font.Code
        l.TextSize = 13
        l.TextXAlignment = Enum.TextXAlignment.Left
    end
    
    list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scroll.CanvasSize = UDim2.new(0, 0, 0, list.AbsoluteContentSize.Y)
    end)
    
    BlueprintTrackerUI = gui
end

local function ToggleSavedBlueprintMode(visible)
    BuildSettings.SavedBlueprintMode = visible
    UpdateBlueprintTrackerUI(visible)
    if visible then
        InitSavedBlueprintVisuals()
        if SavedBlueprintPart then 
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local blocksFolder = getBuildBlocksFolder()
            if hrp and blocksFolder then
                local currentPos = hrp.Position
                local closestDist = math.huge
                local closestBlock = nil
                for _, block in ipairs(blocksFolder:GetChildren()) do
                    local bpos = block:IsA("Model") and block:GetPivot().Position or block.Position
                    local dist = (bpos - currentPos).Magnitude
                    if dist < closestDist then closestDist = dist; closestBlock = bpos end
                end
                
                if closestBlock then 
                    SavedBlueprintPart.Position = closestBlock
                else 
                    SavedBlueprintPart.Position = Vector3.new(math.round(currentPos.X/3)*3, math.round(currentPos.Y/3)*3, math.round(currentPos.Z/3)*3) 
                end
            end
            SavedBlueprintPart.Parent = workspace
        end
        if SavedBlueprintHandles then SavedBlueprintHandles.Parent = LocalPlayer:FindFirstChild("PlayerGui") or game:GetService("CoreGui") end
        
        if not SavedBlueprintFolder then SavedBlueprintFolder = Instance.new("Folder", workspace) SavedBlueprintFolder.Name = "LanternX_SavedBlueprint" end
        UpdateSavedBlueprint()
        if SavedBlueprintPart then
            if BuildSettings.SavedConn then BuildSettings.SavedConn:Disconnect() end
            BuildSettings.SavedConn = SavedBlueprintPart:GetPropertyChangedSignal("Position"):Connect(UpdateSavedBlueprint)
        end
    else
        if SavedBlueprintPart then SavedBlueprintPart.Parent = nil end
        if SavedBlueprintHandles then SavedBlueprintHandles.Parent = nil end
        if SavedBlueprintFolder then SavedBlueprintFolder:ClearAllChildren() end
        if BuildSettings.SavedConn then BuildSettings.SavedConn:Disconnect() BuildSettings.SavedConn = nil end
    end
end

local function RotateBlueprint()
    BuildSettings.Rotation = (BuildSettings.Rotation + 90) % 360
    UpdateBlueprint()
end

local function RotateSavedBlueprint()
    BuildSettings.SavedRotation = (BuildSettings.SavedRotation + 90) % 360
    UpdateSavedBlueprint()
end

local function AutoFillArea()
    if not SelectionPart or not SelectionPart.Parent then return end
    
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local tool = char:FindFirstChildWhichIsA("Tool")
    if not tool then
        Library:Notify("Please equip a block in your hand first!", 3)
        return
    end
    local targetBlock = tool.Name
    
    BuildSettings.IsWorking = true
    local size = SelectionPart.Size
    local pos = SelectionPart.Position
    local min = pos - (size / 2)
    local max = pos + (size / 2)
    local PlaceRemote = LanternNetwork.GetRemote("PlaceBlock")
    if not PlaceRemote then BuildSettings.IsWorking = false; return end
    
    task.spawn(function()
        local blocksFolder = getBuildBlocksFolder()
        local blockMap = {}
        if blocksFolder then
            for _, b in ipairs(blocksFolder:GetChildren()) do
                local bpos = b:IsA("Model") and b:GetPivot().Position or b.Position
                local key = math.round(bpos.X).."_"..math.round(bpos.Y).."_"..math.round(bpos.Z)
                blockMap[key] = true
            end
        end
        
        local pending = {}
        for x = min.X + 1.5, max.X - 1.5, 3 do
            for y = min.Y + 1.5, max.Y - 1.5, 3 do
                for z = min.Z + 1.5, max.Z - 1.5, 3 do
                    local key = math.round(x).."_"..math.round(y).."_"..math.round(z)
                    if not blockMap[key] then
                        table.insert(pending, {pos = Vector3.new(x, y, z), done = false})
                    end
                end
            end
        end
        
        local startPos = hrp.Position
        local center = SelectionPart.Position
        local dirX = startPos.X > center.X and -1 or 1
        local dirZ = startPos.Z > center.Z and -1 or 1
        
        table.sort(pending, function(a, b)
            if math.abs(a.pos.Y - b.pos.Y) > 1 then return a.pos.Y < b.pos.Y end
            if math.abs(a.pos.X - b.pos.X) > 1 then return a.pos.X * dirX < b.pos.X * dirX end
            return a.pos.Z * dirZ < b.pos.Z * dirZ
        end)
        
        while BuildSettings.IsWorking do
            local hasPending = false
            local nextTarget = nil
            for _, p in ipairs(pending) do
                if not p.done then
                    hasPending = true
                    nextTarget = p
                    break
                end
            end
            
            if not hasPending then break end
            
            local dist = (nextTarget.pos - hrp.Position).Magnitude
            if dist > CONFIG.PLACEMENT_REACH then
                local tw = LanternMovement.MoveTo(nextTarget.pos)
                if not tw then tw = {PlaybackState = Enum.PlaybackState.Completed, Cancel = function() end} end
                
                while tw.PlaybackState == Enum.PlaybackState.Playing and BuildSettings.IsWorking do
                    task.wait(CONFIG.BUILD_FLIGHT_DELAY)
                    local placeCount = 0
                    for _, otherP in ipairs(pending) do
                        if not otherP.done and (otherP.pos - hrp.Position).Magnitude <= CONFIG.PLACEMENT_REACH then
                            local cframe = CFrame.new(otherP.pos)
                            task.spawn(function() pcall(function() LanternNetwork.PlaceBlock(PlaceRemote, cframe, targetBlock) end) end)
                            otherP.done = true
                            placeCount = placeCount + 1
                            if placeCount >= 10 then break end
                        end
                    end
                    if nextTarget.done then tw:Cancel(); break end
                end
            else
                local placeCount = 0
                for _, otherP in ipairs(pending) do
                    if not otherP.done and (otherP.pos - hrp.Position).Magnitude <= CONFIG.PLACEMENT_REACH then
                        local cframe = CFrame.new(otherP.pos)
                        task.spawn(function() pcall(function() LanternNetwork.PlaceBlock(PlaceRemote, cframe, targetBlock) end) end)
                        otherP.done = true
                        placeCount = placeCount + 1
                        if placeCount >= 15 then break end
                    end
                end
                if placeCount > 0 then task.wait(CONFIG.BUILD_BATCH_DELAY) end
            end
        end
        BuildSettings.IsWorking = false
        LanternMovement.Cancel()
    end)
end

local function DestroyArea()
    if not SelectionPart or not SelectionPart.Parent then return end
    BuildSettings.IsWorking = true
    local HitRemote = LanternNetwork.GetRemote("HitBlock")
    if not HitRemote then BuildSettings.IsWorking = false; return end
    local blocksFolder = getBuildBlocksFolder()
    local size = SelectionPart.Size
    local pos = SelectionPart.Position
    local min = pos - (size / 2)
    local max = pos + (size / 2)
    
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then BuildSettings.IsWorking = false; return end
    
    task.spawn(function()
        local initialBlocks = {}
        for _, block in ipairs(blocksFolder:GetChildren()) do
            local bpos = block:IsA("Model") and block:GetPivot().Position or block.Position
            if bpos.X >= min.X - 0.5 and bpos.X <= max.X + 0.5 and bpos.Y >= min.Y - 0.5 and bpos.Y <= max.Y + 0.5 and bpos.Z >= min.Z - 0.5 and bpos.Z <= max.Z + 0.5 then
                table.insert(initialBlocks, block)
            end
        end
        
        local function GetClosestBlock()
            local closest = nil
            local minDist = math.huge
            local currentPos = hrp.Position
            for i = #initialBlocks, 1, -1 do
                local block = initialBlocks[i]
                if not block or block.Parent ~= blocksFolder then
                    table.remove(initialBlocks, i)
                else
                    local bpos = block:IsA("Model") and block:GetPivot().Position or block.Position
                    local dist = (bpos - currentPos).Magnitude
                    if dist < minDist then
                        minDist = dist
                        closest = block
                    end
                end
            end
            return closest
        end
        
        
        
        local nextBurstTime = tick()
        local cycleBlocks = 0
        
        while BuildSettings.IsWorking do
            local currentPos = hrp.Position
            
            -- Gather all blocks currently within reach (14 studs)
            local sweepBlocks = {}
            local closestGlobal = nil
            local minGlobalDist = math.huge
            
            for i = #initialBlocks, 1, -1 do
                local block = initialBlocks[i]
                if block and block.Parent == blocksFolder then
                    local bpos = block:IsA("Model") and block:GetPivot().Position or block.Position
                    local dist = (bpos - currentPos).Magnitude
                    if dist <= 14 then
                        table.insert(sweepBlocks, {block = block, dist = dist})
                    end
                    if dist < minGlobalDist then
                        minGlobalDist = dist
                        closestGlobal = block
                    end
                else
                    table.remove(initialBlocks, i)
                end
            end
            
            if #initialBlocks == 0 then break end -- All done!
            
            -- If no blocks are within reach, Tween smoothly to the closest block in the map
            if #sweepBlocks == 0 and closestGlobal then
                local targetPos = closestGlobal:IsA("Model") and closestGlobal:GetPivot().Position or closestGlobal.Position
                local tw = LanternMovement.MoveTo(targetPos)
                if not tw then tw = {PlaybackState = Enum.PlaybackState.Completed} end
                
                while tw.PlaybackState == Enum.PlaybackState.Playing and BuildSettings.IsWorking do
                    task.wait(0.05)
                end
                tw:Cancel()
                continue -- Restart the loop to gather blocks at the new position
            end
            
            -- Sort blocks by distance (Ripple Effect: Inside-Out)
            -- This prevents zigzagging because the sequence is fixed for this position
            table.sort(sweepBlocks, function(a, b) return a.dist < b.dist end)
            
            for _, data in ipairs(sweepBlocks) do
                if not BuildSettings.IsWorking then break end
                local targetBlock = data.block
                
                while targetBlock.Parent == blocksFolder and BuildSettings.IsWorking do
                    local hitPart = targetBlock:FindFirstChildWhichIsA("BasePart") or targetBlock
                    task.spawn(function() LanternNetwork.HitBlock(HitRemote, targetBlock, hitPart) end)
                    
                    cycleBlocks = cycleBlocks + 1
                    if cycleBlocks >= 41 then
                        task.wait(CONFIG.BUILD_CYCLE_REST_DELAY) -- End of 10s cycle
                        cycleBlocks = 0
                    else
                        task.wait(CONFIG.BUILD_DESTROY_DELAY) -- Steady hitting
                    end
                end
            end
        end
        
        LanternMovement.Cancel()
        BuildSettings.IsWorking = false
        Library:Notify("Destroy Area Completed!", 3)
    end)
end

local function CopySelection()
    if not SelectionPart or not SelectionPart.Parent then return end
    local blocksFolder = getBuildBlocksFolder()
    local size = SelectionPart.Size
    local pos = SelectionPart.Position
    local min = pos - (size / 2)
    local max = pos + (size / 2)
    
    BuildSettings.Clipboard = {}
    
    -- Snap the center to the nearest block grid point so offsets are perfect multiples of 3
    local center = pos
    local gridOffset = Vector3.new(0, 0, 0)
    if blocksFolder then
        local firstBlock = blocksFolder:FindFirstChildWhichIsA("Model") or blocksFolder:FindFirstChildWhichIsA("BasePart")
        if firstBlock then
            local fpos = firstBlock:IsA("Model") and firstBlock:GetPivot().Position or firstBlock.Position
            gridOffset = Vector3.new(fpos.X % 3, fpos.Y % 3, fpos.Z % 3)
        end
        center = Vector3.new(
            math.round((pos.X - gridOffset.X) / 3) * 3 + gridOffset.X,
            math.round((pos.Y - gridOffset.Y) / 3) * 3 + gridOffset.Y,
            math.round((pos.Z - gridOffset.Z) / 3) * 3 + gridOffset.Z
        )
    end
    
    for _, block in ipairs(blocksFolder:GetChildren()) do
        local bcframe = block:IsA("Model") and block:GetPivot() or block.CFrame
        local bpos = bcframe.Position
        if bpos.X >= min.X - 0.5 and bpos.X <= max.X + 0.5 and bpos.Y >= min.Y - 0.5 and bpos.Y <= max.Y + 0.5 and bpos.Z >= min.Z - 0.5 and bpos.Z <= max.Z + 0.5 then
            local rx, ry, rz = bcframe:ToEulerAnglesXYZ()
            table.insert(BuildSettings.Clipboard, { name = block.Name, offset = bpos - center, rx = rx, ry = ry, rz = rz })
        end
    end
    UpdateBlueprint()
end

local function ExecutePaste(dataSource, targetPart, rotation)
    if #dataSource == 0 then return end
    if not targetPart or not targetPart.Parent then return end
    BuildSettings.IsWorking = true
    local PlaceRemote = LanternNetwork.GetRemote("PlaceBlock")
    if not PlaceRemote then BuildSettings.IsWorking = false; return end
    
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then BuildSettings.IsWorking = false; return end
    
    local center = targetPart.Position
    local rad = math.rad(rotation)
    local cosR = math.floor(math.cos(rad) + 0.5)
    local sinR = math.floor(math.sin(rad) + 0.5)
    
    task.spawn(function()
        local blocksFolder = getBuildBlocksFolder()
        local blockMap = {}
        if blocksFolder then
            for _, b in ipairs(blocksFolder:GetChildren()) do
                local bpos = b:IsA("Model") and b:GetPivot().Position or b.Position
                local key = math.round(bpos.X).."_"..math.round(bpos.Y).."_"..math.round(bpos.Z)
                blockMap[key] = true
            end
        end
        
        local pending = {}
        for _, item in ipairs(dataSource) do
            local rx = item.offset.X * cosR - item.offset.Z * sinR
            local rz = item.offset.X * sinR + item.offset.Z * cosR
            local targetPos = center + Vector3.new(rx, item.offset.Y, rz)
            
            local key = math.round(targetPos.X).."_"..math.round(targetPos.Y).."_"..math.round(targetPos.Z)
            if not blockMap[key] then
                table.insert(pending, {item = item, targetPos = targetPos, done = false})
            end
        end
        
        local startPos = hrp.Position
        local dirX = startPos.X > center.X and -1 or 1
        local dirZ = startPos.Z > center.Z and -1 or 1
        
        table.sort(pending, function(a, b)
            if math.abs(a.targetPos.Y - b.targetPos.Y) > 1 then return a.targetPos.Y < b.targetPos.Y end
            if math.abs(a.targetPos.X - b.targetPos.X) > 1 then return a.targetPos.X * dirX < b.targetPos.X * dirX end
            return a.targetPos.Z * dirZ < b.targetPos.Z * dirZ
        end)
        
        while BuildSettings.IsWorking do
            local hasPending = false
            local nextTarget = nil
            for _, p in ipairs(pending) do
                if not p.done then
                    hasPending = true
                    nextTarget = p
                    break
                end
            end
            
            if not hasPending then break end
            
            local targetPos = nextTarget.targetPos
            local dist = (targetPos - hrp.Position).Magnitude
            if dist > CONFIG.PLACEMENT_REACH then
                local info = TweenInfo.new(math.max(dist / 30, 0.1), Enum.EasingStyle.Linear)
                local tw = LanternMovement.MoveTo(targetPos)
                if not tw then tw = {PlaybackState = Enum.PlaybackState.Completed} end
                
                while tw.PlaybackState == Enum.PlaybackState.Playing and BuildSettings.IsWorking do
                    task.wait(CONFIG.BUILD_FLIGHT_DELAY)
                    local placeCount = 0
                    for _, otherP in ipairs(pending) do
                        if not otherP.done and (otherP.targetPos - hrp.Position).Magnitude <= CONFIG.PLACEMENT_REACH then
                            local cframe = CFrame.new(otherP.targetPos) * CFrame.Angles(0, math.rad(rotation), 0) * CFrame.Angles(otherP.item.rx or 0, otherP.item.ry or 0, otherP.item.rz or 0)
                            task.spawn(function() pcall(function() LanternNetwork.PlaceBlock(PlaceRemote, cframe, otherP.item.name) end) end)
                            otherP.done = true
                            placeCount = placeCount + 1
                            if placeCount >= 10 then break end
                        end
                    end
                    if nextTarget.done then tw:Cancel(); break end
                end
            else
                local placeCount = 0
                for _, otherP in ipairs(pending) do
                    if not otherP.done and (otherP.targetPos - hrp.Position).Magnitude <= CONFIG.PLACEMENT_REACH then
                        local cframe = CFrame.new(otherP.targetPos) * CFrame.Angles(0, math.rad(rotation), 0) * CFrame.Angles(otherP.item.rx or 0, otherP.item.ry or 0, otherP.item.rz or 0)
                        task.spawn(function() pcall(function() LanternNetwork.PlaceBlock(PlaceRemote, cframe, otherP.item.name) end) end)
                        otherP.done = true
                        placeCount = placeCount + 1
                        if placeCount >= 15 then break end
                    end
                end
                if placeCount > 0 then task.wait(CONFIG.BUILD_BATCH_DELAY) end
            end
        end
        BuildSettings.IsWorking = false
        LanternMovement.Cancel()
    end)
end

local function PasteSelection()
    ExecutePaste(BuildSettings.Clipboard, BlueprintPart, BuildSettings.Rotation)
end

local function PasteSavedBlueprint()
    ExecutePaste(BuildSettings.BlueprintData, SavedBlueprintPart, BuildSettings.SavedRotation)
end

-- ==========================================
-- [ 4. FRONTEND UI SETUP ]
-- ==========================================
local MainGroupBox = Tabs.Main:AddLeftGroupbox("Information")
MainGroupBox:AddLabel("Thank you for choosing LanternX. We are committed to providing you with a seamless and reliable UI experience. Get started by exploring our modules below.", true)
MainGroupBox:AddDivider()

MainGroupBox:AddLabel("StatsLabel", {
    Text = "Loading stats...",
    DoesWrap = true
})

local CurrentFPS = 0
RunService.RenderStepped:Connect(function(deltaTime)
    CurrentFPS = math.floor(1 / deltaTime)
end)

local executorName = identifyexecutor and identifyexecutor() or "Unknown"

Library:SetWatermarkVisibility(true)

task.spawn(function()
    while task.wait(0.5) do
        if Library.Unloaded then break end
        
        local okPing, pingRaw = pcall(function() return LocalPlayer:GetNetworkPing() * 1000 end)
        local ping = okPing and math.floor(pingRaw) or 0
        
        local elapsed = os.time() - StartTime
        local s = elapsed % 60
        local m = math.floor(elapsed / 60) % 60
        local h = math.floor(elapsed / 3600)
        local timeStr = string.format("%02d:%02d:%02d", h, m, s)
        
        if Toggles.ShowWatermark and not Toggles.ShowWatermark.Value then
            Library:SetWatermarkVisibility(false)
        else
            Library:SetWatermarkVisibility(true)
            local errCount = LanternNetwork.ErrorCount or 0
            Library:SetWatermark(string.format("LanternX v0.1 | Islands | %d FPS | %d ms | %d Errors | %s", CurrentFPS, ping, errCount, timeStr))
        end
        
        if LocalPlayer and Library.Labels.StatsLabel then
            local rawName = LocalPlayer.Name
            local censoredName = string.sub(rawName, 1, 2) .. "*****"
            
            local okRam, ramRaw = pcall(function() return game:GetService("Stats"):GetTotalMemoryUsageMb() end)
            local ram = okRam and math.floor(ramRaw) or 0
            
            Library.Labels.StatsLabel:SetText(string.format("Executor : %s | Islands 👨‍🌾\nUsername : %s | %s\nF : %d | P : %d | R : %d MB", executorName, censoredName, timeStr, CurrentFPS, ping, ram))
        end
    end
end)

local ContactGroupBox = Tabs.Main:AddLeftGroupbox("Contact Us")
ContactGroupBox:AddLabel("Join our Discord community for instant support, script updates, and community chat. Our support team is available 24/7 on Discord to assist you anytime!", true)
ContactGroupBox:AddDivider()
ContactGroupBox:AddButton({
    Text = "Copy Link (Discord)",
    Func = function()
        setclipboard("https://discord.gg/HckvpgAKhB")
        Library:Notify("Copied Discord Link to clipboard!", 3)
    end
})
ContactGroupBox:AddButton({
    Text = "Website",
    Func = function()
        setclipboard("www.lanternsupport.xyz")
        Library:Notify("Copied Website Link to clipboard!", 3)
    end
})

local VersionBox = Tabs.Main:AddRightGroupbox("LanternX Version v0.1")

local FeatureBox = Tabs.Main:AddRightGroupbox("Feature")
FeatureBox:AddLabel("[+] Auto Farming", true)
FeatureBox:AddLabel("[+] Auto Cutting", true)
FeatureBox:AddLabel("[+] Auto Mining", true)
FeatureBox:AddLabel("[+] Full Auto Combat", true)
FeatureBox:AddLabel("[+] Building Mode", true)
FeatureBox:AddLabel("[+] Vending Mode", true)
FeatureBox:AddLabel("[+] Player Settings", true)

local LogUpdateBox = Tabs.Main:AddRightGroupbox("Log Update")
LogUpdateBox:AddLabel("[~] 5/10/2026 add all Feature and Maintenance LinoriaLib.", true)
LogUpdateBox:AddLabel("[~] 8/10/2026 Optimize and improve the code structure.", true)
LogUpdateBox:AddLabel(" ", true)
LogUpdateBox:AddLabel(" ", true)
LogUpdateBox:AddLabel(" ", true)
LogUpdateBox:AddLabel(" ", true)
LogUpdateBox:AddLabel(" ", true)
LogUpdateBox:AddLabel(" ", true)
LogUpdateBox:AddLabel(" ", true)
LogUpdateBox:AddLabel(" ", true)
LogUpdateBox:AddLabel(" ", true)
LogUpdateBox:AddLabel(" ", true)

local DonateBox = Tabs.Main:AddLeftGroupbox("Thank for Support")
DonateBox:AddLabel("01. butidontknow - 1$")
DonateBox:AddLabel(" ", true)
DonateBox:AddLabel(" ", true)
DonateBox:AddLabel(" ", true)
DonateBox:AddLabel(" ", true)
DonateBox:AddLabel(" ", true)

-- ==========================================
-- [ FARMING TAB ]
-- ==========================================
local FarmingBox = Tabs.Farming:AddLeftGroupbox("Crop Automation")
local TimberBox = Tabs.Farming:AddLeftGroupbox("Cutting Automation")
local MiningBox = Tabs.Farming:AddLeftGroupbox("Mining Automation")
local MonsterBox = Tabs.Farming:AddRightGroupbox("Monster Automation")
local AnimalBox = Tabs.Farming:AddRightGroupbox("Animal & Spirit Automation")
local EnvironmentBox = Tabs.Farming:AddRightGroupbox("Environment & Digging")
-- [ UI Elements ]
local CropKeys = {}
for k, v in pairs(CropMap) do table.insert(CropKeys, k) end
table.sort(CropKeys)

FarmingBox:AddDropdown("CropDropdown", {
    Values = CropKeys,
    Default = 29, 
    Multi = false,
    Text = "Target Crop", Searchable = true })

FarmingBox:AddToggle("AutoHarvestToggle", {
    Text = "Auto Harvest Crops",
    Default = false })

FarmingBox:AddToggle("AutoPlantToggle", {
    Text = "Auto Plant Seeds",
    Default = false })

FarmingBox:AddToggle("AutoPlowToggle", {
    Text = "Auto Plow Grass",
    Default = false })

FarmingBox:AddToggle("AutoUnplowToggle", {
    Text = "Auto Unplow Grass",
    Default = false })

FarmingBox:AddToggle("AutoWaterSoilToggle", {
    Text = "Auto Water Soil",
    Default = false })

FarmingBox:AddToggle("AutoFertilizeToggle", {
    Text = "Auto Basic Fertilizer (Beta)",
    Default = false })

MonsterBox:AddDropdown("MobDropdown", {
    Values = MobTypes,
    Default = 1,
    Multi = false,
    Text = "Target Mob", Searchable = true })

MonsterBox:AddDropdown("BossDropdown", {
    Values = BossTypes,
    Default = 1,
    Multi = false,
    Text = "Target Boss", Searchable = true })

MonsterBox:AddToggle("MonsterAuraToggle", {
    Text = "Kill Aura",
    Default = false })

MonsterBox:AddToggle("MobFarmToggle", {
    Text = "Auto Farm Mobs",
    Default = false })

MonsterBox:AddToggle("BossFarmToggle", {
    Text = "Auto Farm Bosses",
    Default = false })

MonsterBox:AddToggle("AutoEquipToggle", {
    Text = "Auto Equip Weapon",
    Default = false })

MonsterBox:AddSlider("MonsterDistanceSlider", {
    Text = "Max Tween Distance",
    Default = 1500,
    Min = 100,
    Max = 10000,
    Rounding = 0 })

AnimalBox:AddToggle("AutoFishingToggle", {
    Text = "Auto Fishing",
    Default = false })

EnvironmentBox:AddToggle("AutoWaterFlowersToggle", {
    Text = "Auto Water Flowers",
    Default = false })

AnimalBox:AddToggle("AutoSpiritToggle", {
    Text = "Auto Spirit",
    Default = false })

AnimalBox:AddToggle("AutoAnimalToggle", {
    Text = "Auto Frog & Rabbit",
    Default = false })

AnimalBox:AddToggle("AutoBeeToggle", {
    Text = "Auto Bee",
    Default = false })

AnimalBox:AddToggle("AutoFireflyToggle", {
    Text = "Auto Firefly",
    Default = false })

EnvironmentBox:AddToggle("AutoRemoveGrassRockToggle", {
    Text = "Remove Grass & Rock",
    Default = false })


EnvironmentBox:AddDivider()
EnvironmentBox:AddDropdown("AutoDigTargetsDropdown", {
    Values = {"pileSnow", "grassVoid", "sandVoid"},
    Default = 1,
    Multi = true,
    Text = "Select Dig Targets"
})

EnvironmentBox:AddToggle("AutoDigToggle", {
    Text = "Auto Dig Block",
    Default = false })

TimberBox:AddDropdown("TreeDropdown", {
    Values = TreeTypes,
    Default = 1,
    Multi = false,
    Text = "Target Tree", Searchable = true })

TimberBox:AddToggle("TreeAuraToggle", {
    Text = "Aura Cut Tree",
    Default = false })

TimberBox:AddToggle("TweenToTreeToggle", {
    Text = "Auto Cut Tree",
    Default = false })

MiningBox:AddDropdown("RockDropdown", {
    Values = RockTypes,
    Default = 1,
    Multi = true,
    Text = "Target Ore", Searchable = true })

MiningBox:AddDropdown("MiningAreaDropdown", {
    Values = {"Wilderness (Public)", "Private Island"},
    Default = 1,
    Multi = false,
    Text = "Mining Area"
})

MiningBox:AddToggle("RockAuraToggle", {
    Text = "Aura Mining",
    Default = false })

MiningBox:AddToggle("TweenToRockToggle", {
    Text = "Auto Mining",
    Default = false })

MiningBox:AddDivider()

MiningBox:AddButton({ Text = "Remove Spawn Portal (Local)", DoubleClick = true, Func = function()
    local blocks = getblocksfolder()
    if blocks then
        local p = blocks:FindFirstChild("portalToSpawn")
        if p then p:Destroy() end
    end
end })


-- ==========================================
-- [ VENDING TAB ]
-- ==========================================
local SniperBox = Tabs.Vending:AddLeftGroupbox("Vending Machine")

SniperBox:AddLabel("IslandStatsLabel", {
    Text = "Islands : -\nVending : -\nChest : -\nCoin : -",
    DoesWrap = true
})

SniperBox:AddButton({ Text = "Scan Vending Machine", Func = function()
    local buyCounts = {}
    local sellCounts = {}
    local offlineCounts = {}
    
    local totalVending = 0
    local totalChest = 0
    local totalCoin = 0
    
    local blocksFolder = getBuildBlocksFolder()
    if blocksFolder then
        for _, V in ipairs(blocksFolder:GetChildren()) do
            local nameLower = V.Name:lower()
            if nameLower:find("vendingmachine") then
                totalVending = totalVending + 1
                local mode = V:GetAttribute("mode") or V:GetAttribute("Mode")
                if mode == nil then local mc = V:FindFirstChild("mode") or V:FindFirstChild("Mode") if mc then mode = mc.Value end end
                
                local targetTable = offlineCounts
                if mode == 0 then targetTable = buyCounts
                elseif mode == 1 then targetTable = sellCounts end
                
                local contents = V:FindFirstChild("SellingContents")
                if contents then
                    for _, item in ipairs(contents:GetChildren()) do
                        local amtObj = item:FindFirstChild("Amount") or item:FindFirstChild("Value")
                        local amt = amtObj and amtObj.Value or 1
                        targetTable[item.Name] = (targetTable[item.Name] or 0) + amt
                    end
                end
                
                local cb = V:FindFirstChild("CoinBalance")
                if cb then totalCoin = totalCoin + (cb.Value or 0) end
                
            elseif nameLower:find("chest") then
                totalChest = totalChest + 1
            end
        end
    end
    
    local ownerName = "Unknown"
    local joinCode = "None"
    local pIsland = LocalPlayer:GetAttribute("island")
    if pIsland then
        pcall(function()
            local name = game.Players:GetNameFromUserIdAsync(tonumber(pIsland))
            if name then
                ownerName = name:sub(1, 6) .. "***"
            end
        end)
        local islandModel = workspace:FindFirstChild("Islands") and workspace.Islands:FindFirstChild(pIsland .. "-island")
        if islandModel then
            local jc = islandModel:GetAttribute("joinCode") or islandModel:GetAttribute("JoinCode")
            if jc then joinCode = tostring(jc) end
        end
    end
    
    local statsText = string.format("Islands : %s [%s]\nVending : %d\nChest : %d\nCoin : %d", ownerName, joinCode, totalVending, totalChest, totalCoin)
    if Library.Labels.IslandStatsLabel then
        Library.Labels.IslandStatsLabel:SetText(statsText)
    end
    
    local function formatList(counts)
        local dropList = {}
        for name, count in pairs(counts) do
            table.insert(dropList, name .. " [" .. count .. "]")
        end
        table.sort(dropList)
        if #dropList == 0 then table.insert(dropList, "No items found") end
        return dropList
    end
    
    VendingSettings.ScannedData = {
        Buy = formatList(buyCounts),
        Sell = formatList(sellCounts),
        Offline = formatList(offlineCounts)
    }
    
    local currentMode = VendingSettings.SnipeTargetMode or "Buy Mode"
    if currentMode == "Buy Mode" then
        if Options.VendingItemDropdown then Options.VendingItemDropdown:SetValues(VendingSettings.ScannedData.Buy) end
    elseif currentMode == "Sell Mode" then
        if Options.VendingItemDropdown then Options.VendingItemDropdown:SetValues(VendingSettings.ScannedData.Sell) end
    else
        if Options.VendingItemDropdown then Options.VendingItemDropdown:SetValues(VendingSettings.ScannedData.Offline) end
    end
end })

SniperBox:AddDropdown("SniperTargetModeDropdown", {
    Text = "Target Mode",
    Default = 1,
    Values = {"Buy Mode", "Sell Mode", "Offline Mode"},
    Multi = false
})

SniperBox:AddDropdown("VendingItemDropdown", {
    Text = "Target Item",
    Default = 1,
    Values = {"(Select Item Here!)"},
    Searchable = true,
    Multi = false
})

SniperBox:AddInput("VendingPriceInput", {
    Text = "Set Price Limit",
    Default = "",
    Placeholder = "(e.g., 10–1000).",
    Numeric = true,
    Finished = true
})

SniperBox:AddToggle("BuyTargetItemToggle", {
    Text = "Buy Target Item",
    Default = false })

SniperBox:AddSlider("VendingRadiusSlider", {
    Text = "Scan Radius",
    Default = 60,
    Min = 10,
    Max = 300,
    Rounding = 0 })

local AutoSniperBox = Tabs.Vending:AddLeftGroupbox("Auto Sniper")
AutoSniperBox:AddToggle("AutoSniperToggle", {
    Text = "Enable Sniper",
    Default = false })
AutoSniperBox:AddInput("AutoSniperPrice", {
    Text = "Set Price Limit",
    Default = "10",
    Numeric = true,
    Finished = true
})

local VendingSetupBox = Tabs.Vending:AddRightGroupbox("Vending Setup")
VendingSetupBox:AddDropdown("VendingActionModeDropdown", {
    Text = "Target Mode",
    Values = {"Buy Item", "Sell Item", "Offline"},
    Multi = false,
    Default = 1
})
VendingSetupBox:AddInput("VendingActionPriceInput", {
    Text = "Mode Price",
    Default = "10",
    Numeric = true,
    Finished = false
})

VendingSetupBox:AddInput("VendingCoinAmountInput", {
    Text = "Deposit Coin Amount",
    Default = "1000",
    Numeric = true,
    Finished = false
})

VendingSetupBox:AddToggle("ClickToSetToggle", {
    Text = "Click to Set (Mouse)",
    Default = false })
VendingSetupBox:AddToggle("ClickToWithdrawToggle", {
    Text = "Click to Withdraw ALL (Mouse)",
    Default = false })

VendingSetupBox:AddToggle("MaintenanceBypassToggle", {
    Text = "Maintenance Bypass",
    Default = false })

local VendingESPBox = Tabs.Vending:AddRightGroupbox("ESP Vending & Chest")
VendingESPBox:AddToggle("VendingESPToggle", {
    Text = "Enable ESP",
    Default = false })
-- ==========================================
-- [ BUILDING TAB ]
-- ==========================================
local BuildingBox = Tabs.Building:AddLeftGroupbox("Building Manager")
BuildingBox:AddLabel("Use the 3D handles on the box to resize it. The box perfectly snaps to the 3-stud grid.", true)
BuildingBox:AddDivider()
BuildingBox:AddToggle("ShowSelectionBoxToggle", {
    Text = "Show Selection Box",
    Default = false })
BuildingBox:AddToggle("BlueprintModeToggle", {
    Text = "Show Copy Selection",
    Default = false })

BuildingBox:AddButton({ Text = "Auto Fill", Func = function() AutoFillArea() end }):AddButton({ Text = "Destroy Area", Func = function() DestroyArea() end, DoubleClick = true })

BuildingBox:AddButton({ Text = "Copy Selection", Func = function() CopySelection() end })
BuildingBox:AddButton({ Text = "Rotate Copy (90°)", Func = function() RotateBlueprint() end })
BuildingBox:AddButton({ Text = "Paste Copy", Func = function() PasteSelection() end })

BuildingBox:AddDivider()
local StopActionBtn = BuildingBox:AddButton({ Text = "🛑 STOP ACTION", Func = function()
    BuildSettings.IsWorking = false
    LanternMovement.Cancel()
    Library:Notify("Stopped all building actions.", 3)
end })


local BlueprintGroup = Tabs.Building:AddRightGroupbox("Blueprint Mode")
local BlueprintStatusLabel = BlueprintGroup:AddLabel("Blueprint : None\nBlocks : 0 (0 Types)\nSize : 0x0x0", true)
BlueprintGroup:AddDivider()
BlueprintGroup:AddInput("BlueprintNameInput", {
    Default = "",
    Numeric = false,
    Finished = false,
    Text = "Blueprint Name",
    Placeholder = "Enter name here",
})
BlueprintGroup:AddButton({ Text = "Save Blueprint", Func = function()
    SaveBlueprint(Options.BlueprintNameInput.Value)
    if Options.BlueprintDropdown then
        Options.BlueprintDropdown:SetValues(GetSavedBlueprints())
    end
end })

BlueprintGroup:AddDropdown("BlueprintDropdown", {
    Values = GetSavedBlueprints(),
    Default = 1,
    Multi = false,
    Text = "Saved Blueprints",
})
BlueprintGroup:AddButton({ Text = "Refresh List", Func = function()
    if Options.BlueprintDropdown then
        Options.BlueprintDropdown:SetValues(GetSavedBlueprints())
    end
end })
BlueprintGroup:AddButton({ Text = "Load Blueprint", Func = function()
    if Options.BlueprintDropdown and Options.BlueprintDropdown.Value ~= "" then
        LoadBlueprint(Options.BlueprintDropdown.Value)
        UpdateSavedBlueprint()
        local minX, minY, minZ = math.huge, math.huge, math.huge
        local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
        local uniqueBlocks = {}
        local uniqueCount = 0
        
        for _, item in ipairs(BuildSettings.BlueprintData) do
            if item.offset.X < minX then minX = item.offset.X end
            if item.offset.Y < minY then minY = item.offset.Y end
            if item.offset.Z < minZ then minZ = item.offset.Z end
            if item.offset.X > maxX then maxX = item.offset.X end
            if item.offset.Y > maxY then maxY = item.offset.Y end
            if item.offset.Z > maxZ then maxZ = item.offset.Z end
            if not uniqueBlocks[item.name] then
                uniqueBlocks[item.name] = true
                uniqueCount = uniqueCount + 1
            end
        end
        
        local sizeX = #BuildSettings.BlueprintData > 0 and math.floor((maxX - minX) / 3 + 1.5) or 0
        local sizeY = #BuildSettings.BlueprintData > 0 and math.floor((maxY - minY) / 3 + 1.5) or 0
        local sizeZ = #BuildSettings.BlueprintData > 0 and math.floor((maxZ - minZ) / 3 + 1.5) or 0
        
        BlueprintStatusLabel:SetText(string.format("Blueprint : %s.json\nBlocks : %d (%d Types)\nSize : %dx%dx%d", Options.BlueprintDropdown.Value, #BuildSettings.BlueprintData, uniqueCount, sizeX, sizeY, sizeZ))
        if Toggles.BlueprintShowToggle and not Toggles.BlueprintShowToggle.Value then
            Toggles.BlueprintShowToggle:SetValue(true)
        else
            UpdateBlueprintTrackerUI(BuildSettings.SavedBlueprintMode)
        end
    end
end })

BlueprintGroup:AddDivider()

BlueprintGroup:AddToggle("BlueprintShowToggle", {
    Text = "Show Blueprint",
    Default = false })
BlueprintGroup:AddButton({ Text = "Rotate Blueprint (90°)", Func = function() RotateSavedBlueprint() end })
BlueprintGroup:AddButton({ Text = "Paste Blueprint", Func = function() PasteSavedBlueprint() end })

-- ==========================================
-- [ PLAYERS SYSTEM BACKEND ]
-- ==========================================
local PlayerSettings = {
    WalkSpeed = 25, UseWalkSpeed = false,
    JumpPower = 100, UseJumpPower = false,
    InfiniteJump = false, Noclip = false, ESP = false, EntityESP = false,
    FOV = 70, UseFOV = false,
    Fly = false, FlySpeed = 25,
    Freecam = false, FreecamSpeed = 50,
    Fullbright = false, AntiAFK = false, PotatoMode = false
}

RunService.Stepped:Connect(function(_, deltaTime)
    local char = LocalPlayer.Character
    if not char then return end
    
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    
    if hum and hrp then
        -- (Old fly logic removed)
        if PlayerSettings.UseWalkSpeed and hum.MoveDirection.Magnitude > 0 then
            local targetSpeed = PlayerSettings.WalkSpeed
            local currentSpeed = hum.WalkSpeed
            if targetSpeed > currentSpeed then
                local addSpeed = targetSpeed - currentSpeed
                hrp.CFrame = hrp.CFrame + (hum.MoveDirection * addSpeed * deltaTime)
            end
        end
    end
    
    if PlayerSettings.Noclip then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end
end)

game:GetService("UserInputService").JumpRequest:Connect(function()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    
    if PlayerSettings.InfiniteJump then
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
    
    if PlayerSettings.UseJumpPower and hum and hrp then
        if hum.FloorMaterial ~= Enum.Material.Air or PlayerSettings.InfiniteJump then
            hrp.Velocity = Vector3.new(hrp.Velocity.X, PlayerSettings.JumpPower, hrp.Velocity.Z)
        end
    end
end)

local ESPObjects = {}
local EntityESPObjects = {}
local fovConnection
local function EnforceFOV()
    if fovConnection then fovConnection:Disconnect() end
    if not workspace.CurrentCamera then return end
    
    fovConnection = workspace.CurrentCamera:GetPropertyChangedSignal("FieldOfView"):Connect(function()
        if PlayerSettings.UseFOV and workspace.CurrentCamera.FieldOfView ~= PlayerSettings.FOV then
            workspace.CurrentCamera.FieldOfView = PlayerSettings.FOV
        end
    end)
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(EnforceFOV)
EnforceFOV()

RunService.RenderStepped:Connect(function()
    if not PlayerSettings.ESP then
        for _, obj in pairs(ESPObjects) do pcall(function() obj.gui:Destroy() end) end
        table.clear(ESPObjects)
    else
        for _, p in ipairs(game.Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local char = p.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    if not ESPObjects[p] then
                        local bbg = Instance.new("BillboardGui")
                        bbg.Size = UDim2.new(0, 200, 0, 50)
                        bbg.StudsOffset = Vector3.new(0, 3, 0)
                        bbg.AlwaysOnTop = true
                        local txt = Instance.new("TextLabel", bbg)
                        txt.Size = UDim2.new(1, 0, 1, 0)
                        txt.BackgroundTransparency = 1
                        txt.TextColor3 = Color3.fromRGB(0, 255, 128)
                        txt.TextStrokeTransparency = 0
                        txt.Font = Enum.Font.Code
                        txt.TextSize = 14
                        pcall(function() bbg.Parent = game:GetService("CoreGui") end)
                        if not bbg.Parent then bbg.Parent = LocalPlayer:FindFirstChild("PlayerGui") end
                        ESPObjects[p] = { gui = bbg, txt = txt }
                    end
                    if ESPObjects[p] and ESPObjects[p].gui then
                        ESPObjects[p].gui.Adornee = hrp
                        local dist = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and math.floor((hrp.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude) or 0
                        ESPObjects[p].txt.Text = p.Name .. " [" .. dist .. "]"
                    end
                else
                    if ESPObjects[p] then pcall(function() ESPObjects[p].gui:Destroy() end); ESPObjects[p] = nil end
                end
            end
        end
        for p, obj in pairs(ESPObjects) do
            if not p.Parent or not p.Character then
                pcall(function() obj.gui:Destroy() end)
                ESPObjects[p] = nil
            end
        end
    end

    if not PlayerSettings.EntityESP then
        for _, obj in pairs(EntityESPObjects) do pcall(function() obj.gui:Destroy() end) end
        table.clear(EntityESPObjects)
    else
        local currentEntities = {}
        
        local function scanFolder(folder)
            if not folder then return end
            for _, entity in ipairs(folder:GetChildren()) do
                local root = entity:FindFirstChild("HumanoidRootPart") or entity:FindFirstChild("RootPart") or entity.PrimaryPart or entity:FindFirstChildWhichIsA("BasePart") or (entity:IsA("BasePart") and entity)
                if root then
                    currentEntities[entity] = true
                    if not EntityESPObjects[entity] then
                        local bbg = Instance.new("BillboardGui")
                        bbg.Size = UDim2.new(0, 200, 0, 50)
                        bbg.StudsOffset = Vector3.new(0, 3, 0)
                        bbg.AlwaysOnTop = true
                        local txt = Instance.new("TextLabel", bbg)
                        txt.Size = UDim2.new(1, 0, 1, 0)
                        txt.BackgroundTransparency = 1
                        txt.TextColor3 = Color3.fromRGB(255, 100, 100)
                        txt.TextStrokeTransparency = 0
                        txt.Font = Enum.Font.Code
                        txt.TextSize = 13
                        pcall(function() bbg.Parent = game:GetService("CoreGui") end)
                        if not bbg.Parent then bbg.Parent = LocalPlayer:FindFirstChild("PlayerGui") end
                        EntityESPObjects[entity] = { gui = bbg, txt = txt }
                    end
                    
                    if EntityESPObjects[entity] and EntityESPObjects[entity].gui then
                        EntityESPObjects[entity].gui.Adornee = root
                        local dist = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and math.floor((root.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude) or 0
                        EntityESPObjects[entity].txt.Text = entity.Name .. " [" .. dist .. "]"
                    end
                end
            end
        end

        local islandsFolder = workspace:FindFirstChild("Islands")
        if islandsFolder then
            for _, islandFolder in ipairs(islandsFolder:GetChildren()) do
                scanFolder(islandFolder:FindFirstChild("Entities"))
            end
        end
        scanFolder(workspace:FindFirstChild("Entities"))
        scanFolder(workspace:FindFirstChild("WildernessBlocks") and workspace.WildernessBlocks:FindFirstChild("Entities"))
        scanFolder(workspace:FindFirstChild("WildernessIsland") and workspace.WildernessIsland:FindFirstChild("Entities"))
        
        for ent, obj in pairs(EntityESPObjects) do
            if not currentEntities[ent] or not ent.Parent then
                pcall(function() obj.gui:Destroy() end)
                EntityESPObjects[ent] = nil
            end
        end
    end
end)

local function GetPlayerNames()
    local names = {}
    for _, p in ipairs(game.Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(names, p.Name) end
    end
    if #names == 0 then table.insert(names, "No other players") end
    return names
end

-- ==========================================
-- [ PLAYERS TAB ]
-- ==========================================
local MovementGroup = Tabs.Players:AddLeftGroupbox("Movement & Character")
MovementGroup:AddToggle("UseWalkSpeed", { Text = "Enable WalkSpeed", Default = false })
MovementGroup:AddSlider("WalkSpeedSlider", { Text = "WalkSpeed", Default = 25, Min = 16, Max = 150, Rounding = 0 })

MovementGroup:AddToggle("UseJumpPower", { Text = "Enable JumpPower", Default = false })
MovementGroup:AddSlider("JumpPowerSlider", { Text = "JumpPower", Default = 100, Min = 50, Max = 250, Rounding = 0 })
MovementGroup:AddToggle("InfiniteJump", { Text = "Infinite Jump", Default = false })

local FLYING = false
local CONTROL = {F = 0, B = 0, L = 0, R = 0, Q = 0, E = 0}
local lCONTROL = {F = 0, B = 0, L = 0, R = 0, Q = 0, E = 0}
local SPEED = 0

local function sfly()
	local char = LocalPlayer.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local hum = char:FindFirstChild("Humanoid")
	if not hum then return end

	FLYING = true
	local T = hrp
	local BG = Instance.new('BodyGyro')
	local BV = Instance.new('BodyVelocity')
	BG.P = 9e4
	BG.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
	BG.CFrame = T.CFrame
	BG.Parent = T
	BV.Velocity = Vector3.new(0, 0, 0)
	BV.MaxForce = Vector3.new(9e9, 9e9, 9e9)
	BV.Parent = T
	
	task.spawn(function()
		repeat task.wait()
			if not hum or not hum.Parent then break end
			hum.PlatformStand = true
			
			pcall(function()
				local isCatching = (LanternMovement and LanternMovement.IsWorking) or (MonsterSettings and (MonsterSettings.TweenToMob or MonsterSettings.TweenToBoss))
				
				-- Fix Tool Fling bug
				if char then
					local tool = char:FindFirstChildWhichIsA("Tool")
					if tool then
						for _, p in ipairs(tool:GetDescendants()) do
							if p:IsA("BasePart") then
								p.CanCollide = false
								p.Massless = true
							end
						end
					end
				end

				local moveVec = Vector3.new(0, 0, 0)
				local cam = workspace.CurrentCamera
				if not isCatching and cam then
					if CONTROL.L + CONTROL.R ~= 0 or CONTROL.F + CONTROL.B ~= 0 or CONTROL.Q + CONTROL.E ~= 0 then
						SPEED = PlayerSettings.FlySpeed or 50
					elseif not (CONTROL.L + CONTROL.R ~= 0 or CONTROL.F + CONTROL.B ~= 0 or CONTROL.Q + CONTROL.E ~= 0) and SPEED ~= 0 then
						SPEED = 0
					end
					if (CONTROL.L + CONTROL.R) ~= 0 or (CONTROL.F + CONTROL.B) ~= 0 or (CONTROL.Q + CONTROL.E) ~= 0 then
						moveVec = ((cam.CFrame.LookVector * (CONTROL.F + CONTROL.B)) + ((cam.CFrame * CFrame.new(CONTROL.L + CONTROL.R, (CONTROL.F + CONTROL.B) * 0.2, (CONTROL.Q + CONTROL.E)).Position) - cam.CFrame.Position))
						lCONTROL = {F = CONTROL.F, B = CONTROL.B, L = CONTROL.L, R = CONTROL.R, Q = CONTROL.Q, E = CONTROL.E}
					elseif (CONTROL.L + CONTROL.R) == 0 and (CONTROL.F + CONTROL.B) == 0 and (CONTROL.Q + CONTROL.E) == 0 and SPEED ~= 0 then
						moveVec = ((cam.CFrame.LookVector * (lCONTROL.F + lCONTROL.B)) + ((cam.CFrame * CFrame.new(lCONTROL.L + lCONTROL.R, (lCONTROL.F + lCONTROL.B) * 0.2, (lCONTROL.Q + lCONTROL.E)).Position) - cam.CFrame.Position))
					end
				end

				if isCatching then
					BV.MaxForce = Vector3.new(1e9, 1e9, 1e9)
					BV.Velocity = Vector3.new(0, 0, 0)
					BG.MaxTorque = Vector3.new(0, 0, 0)
				else
					BV.MaxForce = Vector3.new(9e9, 9e9, 9e9)
					BG.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
					if moveVec.Magnitude > 0 then
						BV.Velocity = moveVec.Unit * (PlayerSettings.FlySpeed or 30)
					else
						BV.Velocity = Vector3.new(0, 0, 0)
					end
					if cam then
						local camLook = cam.CFrame.LookVector
						local xzLook = Vector3.new(camLook.X, 0, camLook.Z)
						if xzLook.Magnitude > 0.001 then
							BG.CFrame = CFrame.new(Vector3.new(0, 0, 0), xzLook)
						else
							BG.CFrame = cam.CFrame
						end
					end
				end
			end)
		until not FLYING
		CONTROL = {F = 0, B = 0, L = 0, R = 0, Q = 0, E = 0}
		lCONTROL = {F = 0, B = 0, L = 0, R = 0, Q = 0, E = 0}
		SPEED = 0
		BG:Destroy()
		BV:Destroy()
		if hum and hum.Parent then
			hum.PlatformStand = false
		end
	end)
end

local UserInputService = game:GetService("UserInputService")

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.W then CONTROL.F = 1
	elseif input.KeyCode == Enum.KeyCode.S then CONTROL.B = -1
	elseif input.KeyCode == Enum.KeyCode.A then CONTROL.L = -1
	elseif input.KeyCode == Enum.KeyCode.D then CONTROL.R = 1
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.W then CONTROL.F = 0
	elseif input.KeyCode == Enum.KeyCode.S then CONTROL.B = 0
	elseif input.KeyCode == Enum.KeyCode.A then CONTROL.L = 0
	elseif input.KeyCode == Enum.KeyCode.D then CONTROL.R = 0
	end
end)

local FC_CFrame = workspace.CurrentCamera.CFrame
local FC_Pitch = 0
local FC_Yaw = 0

local function StartFreecam()
    FC_CFrame = workspace.CurrentCamera.CFrame
    local x, y, z = FC_CFrame:ToEulerAnglesYXZ()
    FC_Pitch = x
    FC_Yaw = y
    workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
    
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        LocalPlayer.Character.HumanoidRootPart.Anchored = true
    end
end

local function StopFreecam()
    workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        LocalPlayer.Character.HumanoidRootPart.Anchored = false
    end
end

RunService.RenderStepped:Connect(function(deltaTime)
    if PlayerSettings.Freecam then
        local moveDir = Vector3.new()
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + FC_CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - FC_CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - FC_CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + FC_CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.E) then moveDir = moveDir + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.Q) then moveDir = moveDir - Vector3.new(0, 1, 0) end
        
        if moveDir.Magnitude > 0 then moveDir = moveDir.Unit end
        
        if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
            local delta = UserInputService:GetMouseDelta()
            FC_Yaw = FC_Yaw - math.rad(delta.X * 0.3)
            FC_Pitch = math.clamp(FC_Pitch - math.rad(delta.Y * 0.3), -math.rad(89), math.rad(89))
            UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
        else
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        end
        
        FC_CFrame = CFrame.new(FC_CFrame.Position) * CFrame.Angles(0, FC_Yaw, 0) * CFrame.Angles(FC_Pitch, 0, 0)
        FC_CFrame = FC_CFrame + (moveDir * (PlayerSettings.FreecamSpeed * deltaTime))
        workspace.CurrentCamera.CFrame = FC_CFrame
    end
    
    if PlayerSettings.Fullbright then
        local Lighting = game:GetService("Lighting")
        Lighting.Ambient = Color3.new(1, 1, 1)
        Lighting.ColorShift_Bottom = Color3.new(1, 1, 1)
        Lighting.ColorShift_Top = Color3.new(1, 1, 1)
        Lighting.GlobalShadows = false
        Lighting.Brightness = 2
        Lighting.FogEnd = 100000
    end
end)

LocalPlayer.CharacterAdded:Connect(function(char)
    if PlayerSettings.Fly then
        task.wait(0.5)
        sfly()
    end
end)

MovementGroup:AddToggle("Fly", { Text = "Enable Fly", Default = false })
MovementGroup:AddToggle("Noclip", { Text = "Enable Noclip", Default = false })

local ESPGroup = Tabs.Players:AddLeftGroupbox("ESP Settings")
ESPGroup:AddToggle("EnableESP", { Text = "Enable Player ESP", Default = false })
ESPGroup:AddToggle("EnableEntityESP", { Text = "Enable Entities ESP", Default = false })

local TeleportGroup = Tabs.Players:AddRightGroupbox("Teleportation")
TeleportGroup:AddDropdown("PlayerTPDropdown", { Values = GetPlayerNames(), Default = 1, Multi = false, Text = "Select Player", Searchable = true })
TeleportGroup:AddButton({ Text = "Refresh Players", Func = function() if Options.PlayerTPDropdown then Options.PlayerTPDropdown:SetValues(GetPlayerNames()) end end })
TeleportGroup:AddButton({ Text = "Teleport to Player", Func = function()
    local selected = Options.PlayerTPDropdown and Options.PlayerTPDropdown.Value
    if not selected or selected == "No other players" then return end
    local target = game.Players:FindFirstChild(selected)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") and hrp then
        hrp.CFrame = target.Character.HumanoidRootPart.CFrame + Vector3.new(0, 5, 0)
        Library:Notify("Teleported to " .. selected, 3)
    else
        Library:Notify("Player not found or dead", 3)
    end
end })



local CameraGroup = Tabs.Players:AddRightGroupbox("Camera Settings")
CameraGroup:AddToggle("UseFOV", { Text = "Enable Custom FOV", Default = false })
CameraGroup:AddSlider("FOVSlider", { Text = "Field of View (FOV)", Default = 70, Min = 10, Max = 120, Rounding = 0 })


CameraGroup:AddToggle("Freecam", { Text = "Enable Freecam", Default = false })
CameraGroup:AddSlider("FreecamSpeed", { Text = "Freecam Speed", Default = 100, Min = 10, Max = 500, Rounding = 0 })

local RenderGroup = Tabs.Players:AddLeftGroupbox("Render Settings")
local originalLighting = {}

RenderGroup:AddToggle("Fullbright", { Text = "Fullbright", Default = false })

local OriginalProps = {
    Lighting = {},
    Terrain = {},
    Parts = {},
    Decals = {},
    Particles = {},
    Effects = {}
}
RenderGroup:AddToggle("PotatoMode", { Text = "Potato Mode", Default = false })
local WebhookSettings = {
    Enabled = false,
    Url = "",
    DiscordId = ""
}

-- 📌 รายชื่อไอเทมที่ต้องการให้แจ้งเตือน (สามารถเพิ่มลบได้เอง)
local WebhookItems = {
    ["propeller"] = "Propeller",
    ["pearl"] = "Pearl",
    ["coral"] = "Coral",
    ["crystallizedIron"] = "Crystallized Iron",
    ["crystallizedGold"] = "Crystallized Gold",
    ["crystallizedAquamarine"] = "Crystallized Aquamarine",
    ["blueStickyGear"] = "Blue Sticky Gear",
    ["pinkStickyGear"] = "Pink Sticky Gear",
    ["greenStickyGear"] = "Green Sticky Gear",
    ["smilersToken"] = "Smiler's Token",
    ["portalShard"] = "Portal Shard",
    ["vampireBow"] = "Vampire Bow",
    ["ruby"] = "Ruby",
    ["diamond"] = "Diamond",
    ["emerald"] = "Emerald",
    ["amethyst"] = "Amethyst",
    ["spiritCrystal"] = "Spirit Crystal",
    ["obsidian"] = "Obsidian",
    ["tidebook"] = "Tide Spellbook",
    ["magmaBlob"] = "Magma Blob",
    ["opal"] = "Opal"
}

local WebhookThread = nil
local SessionStartAmounts = {}
local SessionEarnedAmounts = {}
local LastRealAmounts = {}
local ActiveMessageId = nil


local function getRequestFunc()
    return request or http_request or (syn and syn.request)
end

local function UpdateDiscordMessage()
    if not WebhookSettings.Enabled or WebhookSettings.Url == "" then return end
    
    local reqFunc = getRequestFunc()
    if not reqFunc then return end

    local function formatItemName(str)
        local s = str:gsub("(%l)(%u)", "%1 %2")
        return s:gsub("^%l", string.upper)
    end

    local totalEarned = 0
    local itemsListStr = ""
    
    for itemName, earned in pairs(SessionEarnedAmounts) do
        if earned > 0 then
            totalEarned = totalEarned + earned
            local displayName = WebhookItems[itemName] or formatItemName(itemName)
            itemsListStr = itemsListStr .. string.format("› %s x%d\n", displayName, earned)
        end
    end
    
    if itemsListStr == "" then
        itemsListStr = "› None\n"
    end
    
    local embedDesc = string.format("**%dx Items Obtained**\n", totalEarned)
    embedDesc = embedDesc .. "────────────────────────\n"
    embedDesc = embedDesc .. itemsListStr
    embedDesc = embedDesc .. "────────────────────────"
    
    local discordTag = WebhookSettings.DiscordId ~= "" and WebhookSettings.DiscordId or ""
    -- If numeric ID is given, convert it to Discord ping format <@ID>
    if tonumber(discordTag) then
        discordTag = string.format("<@%s>", discordTag)
    end
    
    local data = {
        ["content"] = discordTag,
        ["embeds"] = {{
            ["description"] = embedDesc,
            ["color"] = 65280,
            ["footer"] = { ["text"] = string.format("%s  |  Islands 👨‍🌾", LocalPlayer.Name) }
        }}
    }
    
    local jsonData = HttpService:JSONEncode(data)
    
    task.spawn(function()
        pcall(function()
            if ActiveMessageId then
                -- อัปเดตข้อความเดิม (PATCH)
                local editUrl = WebhookSettings.Url .. "/messages/" .. ActiveMessageId
                reqFunc({Url = editUrl, Method = "PATCH", Headers = {["Content-Type"] = "application/json"}, Body = jsonData})
            else
                -- สร้างข้อความใหม่ (POST + wait=true เพื่อเอา ID)
                local createUrl = WebhookSettings.Url .. "?wait=true"
                local response = reqFunc({Url = createUrl, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = jsonData})
                if response and response.Body then
                    local decoded = HttpService:JSONDecode(response.Body)
                    if decoded and decoded.id then
                        ActiveMessageId = decoded.id
                    end
                end
            end
        end)
    end)
end

local function ManageWebhookThread()
    if WebhookSettings.Enabled then
        if not WebhookThread then
            SessionStartAmounts = {}
            SessionEarnedAmounts = {}
            LastRealAmounts = {}
            ActiveMessageId = nil
            
            WebhookThread = task.spawn(function()
                local function scanFolder(folder, targetTable)
                    if not folder then return end
                    for _, item in ipairs(folder:GetChildren()) do
                        if item:IsA("Tool") then
                            local amtObj = item:FindFirstChild("Amount") or item:FindFirstChild("Value")
                            local amt = amtObj and amtObj.Value or 1
                            targetTable[item.Name] = (targetTable[item.Name] or 0) + amt
                        end
                    end
                end
                
                -- สแกนรอบแรกตอนกดเปิด เพื่อตั้งค่าเริ่มต้น
                scanFolder(LocalPlayer:FindFirstChild("Backpack"), SessionStartAmounts)
                scanFolder(LocalPlayer.Character, SessionStartAmounts)
                
                for itemName, amt in pairs(SessionStartAmounts) do
                    LastRealAmounts[itemName] = amt
                    SessionEarnedAmounts[itemName] = 0
                end
                
                -- ส่งข้อความตั้งต้น 1 ครั้ง
                UpdateDiscordMessage()
                
                while WebhookSettings.Enabled do
                    task.wait(CONFIG.CACHE_POLL_RATE)
                    
                    local tempAmounts = {}
                    scanFolder(LocalPlayer:FindFirstChild("Backpack"), tempAmounts)
                    scanFolder(LocalPlayer.Character, tempAmounts)
                    
                    local changed = false
                    
                    -- ตรวจสอบของที่เพิ่มขึ้น
                    for itemName, realAmt in pairs(tempAmounts) do
                        local lastReal = LastRealAmounts[itemName] or 0
                        if realAmt > lastReal then
                            local diff = realAmt - lastReal
                            SessionEarnedAmounts[itemName] = (SessionEarnedAmounts[itemName] or 0) + diff
                            changed = true
                        end
                        LastRealAmounts[itemName] = realAmt
                    end
                    
                    -- รีเซ็ตของที่หายไป (ถูกเก็บกล่อง ฯลฯ)
                    for itemName, _ in pairs(LastRealAmounts) do
                        if not tempAmounts[itemName] then
                            LastRealAmounts[itemName] = 0
                        end
                    end
                    
                    if changed then
                        UpdateDiscordMessage()
                    end
                end
                WebhookThread = nil
            end)
        end
    else
        if WebhookThread then task.cancel(WebhookThread) WebhookThread = nil end
    end
end

local WebhookGroup = Tabs.Players:AddRightGroupbox("Discord Webhook")

WebhookGroup:AddToggle("EnableWebhookToggle", {
    Text = "Enable Notifications",
    Default = false })
WebhookGroup:AddInput("WebhookURLInput", {
    Default = "",
    Numeric = false,
    Finished = true,
    Text = "Webhook URL",
    Placeholder = "https://discord.com/api/webhooks/..."
})
WebhookGroup:AddInput("DiscordIdInput", {
    Default = "",
    Numeric = false,
    Finished = true,
    Text = "Discord ID / Tag",
    Placeholder = "Your Discord ID..."
})

local UtilityGroup = Tabs.Players:AddRightGroupbox("Utility")

local VirtualUser = game:GetService("VirtualUser")
local AntiAfkConnection
UtilityGroup:AddToggle("AntiAFK", { Text = "Anti-AFK (Error 278)", Default = false })


-- ==========================================
-- [ SETTINGS TAB ]
-- ==========================================
local MenuGroup = Tabs.Settings:AddLeftGroupbox("Menu")
MenuGroup:AddToggle("ShowWatermark", { Text = "Show Watermark", Default = true })
MenuGroup:AddToggle("ShowCustomCursor", {
    Text = "Custom Cursor", 
    Default = false })
MenuGroup:AddDivider()
MenuGroup:AddLabel("Menu bind")
MenuGroup:AddButton({ Text = "Unload", DoubleClick = true, Func = function() Library:Unload() end })

Library.ToggleKeybind = Options.MenuKeybind 


-- [ UI BINDINGS ]--
Options.CropDropdown:OnChanged(function()
    local Value = Options.CropDropdown.Value
 FarmingSettings.SelectedCrop = Value 
end)

Toggles.AutoHarvestToggle:OnChanged(function()
    local Value = Toggles.AutoHarvestToggle.Value
 FarmingSettings.AutoHarvest = Value; ManageHarvestThread() 
end)

Toggles.AutoPlantToggle:OnChanged(function()
    local Value = Toggles.AutoPlantToggle.Value
 FarmingSettings.AutoPlant = Value; ManagePlantThread() 
end)

Toggles.AutoPlowToggle:OnChanged(function()
    local Value = Toggles.AutoPlowToggle.Value
 FarmingSettings.AutoPlow = Value; ManagePlowUnplowThread() 
end)

Toggles.AutoUnplowToggle:OnChanged(function()
    local Value = Toggles.AutoUnplowToggle.Value
 FarmingSettings.AutoUnplow = Value; ManagePlowUnplowThread() 
end)

Toggles.AutoWaterSoilToggle:OnChanged(function()
    local Value = Toggles.AutoWaterSoilToggle.Value
 FarmingSettings.AutoWaterSoil = Value; ManageWaterSoilThread() 
end)

Toggles.AutoFertilizeToggle:OnChanged(function()
    local Value = Toggles.AutoFertilizeToggle.Value
 FarmingSettings.AutoFertilize = Value; ManageFertilizeThread() 
end)

Options.MobDropdown:OnChanged(function()
    local Value = Options.MobDropdown.Value
 MonsterSettings.SelectedMob = Value 
end)

Options.BossDropdown:OnChanged(function()
    local Value = Options.BossDropdown.Value
 MonsterSettings.SelectedBoss = Value 
end)

Toggles.MonsterAuraToggle:OnChanged(function()
    local Value = Toggles.MonsterAuraToggle.Value
 MonsterSettings.MonsterAura = Value; ManageMonsterThread() 
end)

Toggles.MobFarmToggle:OnChanged(function()
    local Value = Toggles.MobFarmToggle.Value
        MonsterSettings.TweenToMob = Value
        if Value and Toggles.BossFarmToggle then Toggles.BossFarmToggle:SetValue(false) end
        ManageMonsterThread() 
end)

Toggles.BossFarmToggle:OnChanged(function()
    local Value = Toggles.BossFarmToggle.Value
        MonsterSettings.TweenToBoss = Value
        if Value and Toggles.MobFarmToggle then Toggles.MobFarmToggle:SetValue(false) end
        ManageMonsterThread() 
end)

Toggles.AutoEquipToggle:OnChanged(function()
    local Value = Toggles.AutoEquipToggle.Value
 MonsterSettings.AutoEquip = Value 
end)

Options.MonsterDistanceSlider:OnChanged(function()
    local Value = Options.MonsterDistanceSlider.Value
 MonsterSettings.TweenMaxDistance = Value 
end)

Toggles.AutoFishingToggle:OnChanged(function()
    local Value = Toggles.AutoFishingToggle.Value
 FishingSettings.AutoFishing = Value; ManageFishingThread() 
end)

Toggles.AutoWaterFlowersToggle:OnChanged(function()
    local Value = Toggles.AutoWaterFlowersToggle.Value
 AutoWaterSettings.Enabled = Value; ManageWaterThread() 
end)

Toggles.AutoSpiritToggle:OnChanged(function()
    local Value = Toggles.AutoSpiritToggle.Value
 CatchSettings.AutoSpirit = Value; ManageCatchThread() 
end)

Toggles.AutoAnimalToggle:OnChanged(function()
    local Value = Toggles.AutoAnimalToggle.Value
 CatchSettings.AutoAnimal = Value; ManageCatchThread() 
end)

Toggles.AutoBeeToggle:OnChanged(function()
    local Value = Toggles.AutoBeeToggle.Value
 CatchSettings.AutoBee = Value; ManageCatchThread() 
end)

Toggles.AutoFireflyToggle:OnChanged(function()
    local Value = Toggles.AutoFireflyToggle.Value
 CatchSettings.AutoFirefly = Value; ManageCatchThread() 
end)

Toggles.AutoRemoveGrassRockToggle:OnChanged(function()
    local Value = Toggles.AutoRemoveGrassRockToggle.Value
 GrassRockSettings.Enabled = Value; ManageGrassRockThread() 
end)

Options.AutoDigTargetsDropdown:OnChanged(function()
    local Value = Options.AutoDigTargetsDropdown.Value
 AutoDigSettings.Targets = Value 
end)

Toggles.AutoDigToggle:OnChanged(function()
    local Value = Toggles.AutoDigToggle.Value
 AutoDigSettings.Enabled = Value; ManageAutoDig() 
end)

Options.TreeDropdown:OnChanged(function()
    local Value = Options.TreeDropdown.Value
 TimberSettings.SelectedTree = Value 
end)

Toggles.TreeAuraToggle:OnChanged(function()
    local Value = Toggles.TreeAuraToggle.Value
 TimberSettings.TreeAura = Value; ManageTreeThread() 
end)

Toggles.TweenToTreeToggle:OnChanged(function()
    local Value = Toggles.TweenToTreeToggle.Value
 TimberSettings.TweenToTree = Value; ManageTreeThread() 
end)

Options.RockDropdown:OnChanged(function()
    local Value = Options.RockDropdown.Value
 MiningSettings.SelectedRock = Value 
end)

Options.MiningAreaDropdown:OnChanged(function()
    local Value = Options.MiningAreaDropdown.Value
 MiningSettings.TargetArea = Value 
end)

Toggles.RockAuraToggle:OnChanged(function()
    local Value = Toggles.RockAuraToggle.Value
 MiningSettings.RockAura = Value; ManageRockThread() 
end)

Toggles.TweenToRockToggle:OnChanged(function()
    local Value = Toggles.TweenToRockToggle.Value
 MiningSettings.TweenToRock = Value; ManageRockThread() 
end)

Options.SniperTargetModeDropdown:OnChanged(function()
    local Value = Options.SniperTargetModeDropdown.Value
        VendingSettings.SnipeTargetMode = Value
        if Options.VendingItemDropdown and VendingSettings.ScannedData then
            if Value == "Buy Mode" then
                Options.VendingItemDropdown:SetValues(VendingSettings.ScannedData.Buy)
            elseif Value == "Sell Mode" then
                Options.VendingItemDropdown:SetValues(VendingSettings.ScannedData.Sell)
            else
                Options.VendingItemDropdown:SetValues(VendingSettings.ScannedData.Offline)
            end
        end
end)

Options.VendingItemDropdown:OnChanged(function()
    local Value = Options.VendingItemDropdown.Value
        local rawName = Value:match("^(.-) %[%d+%]$")
        VendingSettings.SnipeBuyItem = rawName or Value
end)

Options.VendingPriceInput:OnChanged(function()
    local Value = Options.VendingPriceInput.Value
 VendingSettings.MaxPrice = tonumber(Value) 
end)

Toggles.BuyTargetItemToggle:OnChanged(function()
    local Value = Toggles.BuyTargetItemToggle.Value
        VendingSettings.BuyTargetItem = Value
        ManageAutoSniperThread()
end)

Options.VendingRadiusSlider:OnChanged(function()
    local Value = Options.VendingRadiusSlider.Value
 VendingSettings.ScanRadius = Value 
end)

Options.AutoSniperPrice:OnChanged(function()
    local Value = Options.AutoSniperPrice.Value
 VendingSettings.AutoSnipePrice = tonumber(Value) or 10 
end)

Toggles.AutoSniperToggle:OnChanged(function()
    local Value = Toggles.AutoSniperToggle.Value
        VendingSettings.AutoSnipe = Value
        ManageAutoSniperThread()
end)

Options.VendingActionModeDropdown:OnChanged(function()
    local Value = Options.VendingActionModeDropdown.Value
        if Value == "Sell Item" then VendingSettings.ActionMode = 0
        elseif Value == "Buy Item" then VendingSettings.ActionMode = 1
        else VendingSettings.ActionMode = 2 end
end)

Options.VendingActionPriceInput:OnChanged(function()
    local Value = Options.VendingActionPriceInput.Value
 VendingSettings.ActionPrice = tonumber(Value) or 0 
end)

Options.VendingCoinAmountInput:OnChanged(function()
    local Value = Options.VendingCoinAmountInput.Value
 VendingSettings.ActionCoinAmount = tonumber(Value) or 0 
end)

Toggles.ClickToSetToggle:OnChanged(function()
    local Value = Toggles.ClickToSetToggle.Value
 VendingSettings.ClickSet = Value; ToggleClickToSetVending(VendingSettings.ClickSet or VendingSettings.ClickWithdraw) 
end)

Toggles.ClickToWithdrawToggle:OnChanged(function()
    local Value = Toggles.ClickToWithdrawToggle.Value
 VendingSettings.ClickWithdraw = Value; ToggleClickToSetVending(VendingSettings.ClickSet or VendingSettings.ClickWithdraw) 
end)

Toggles.MaintenanceBypassToggle:OnChanged(function()
    local Value = Toggles.MaintenanceBypassToggle.Value
 ToggleMaintenanceBypass(Value) 
end)

Toggles.VendingESPToggle:OnChanged(function()
    local Value = Toggles.VendingESPToggle.Value
        VendingSettings.ESPToggle = Value
        ManageVendingESPThread()
end)

Toggles.ShowSelectionBoxToggle:OnChanged(function()
    local Value = Toggles.ShowSelectionBoxToggle.Value
 ToggleSelectionBox(Value) 
end)

Toggles.BlueprintModeToggle:OnChanged(function()
    local Value = Toggles.BlueprintModeToggle.Value
 ToggleBlueprintMode(Value) 
end)

Toggles.BlueprintShowToggle:OnChanged(function()
    local Value = Toggles.BlueprintShowToggle.Value
 ToggleSavedBlueprintMode(Value) 
end)

Options.WalkSpeedSlider:OnChanged(function()
    local v = Options.WalkSpeedSlider.Value
 PlayerSettings.WalkSpeed = v 
end)

Toggles.UseWalkSpeed:OnChanged(function()
    local v = Toggles.UseWalkSpeed.Value
 PlayerSettings.UseWalkSpeed = v 
end)

Options.JumpPowerSlider:OnChanged(function()
    local v = Options.JumpPowerSlider.Value
 PlayerSettings.JumpPower = v 
end)

Toggles.UseJumpPower:OnChanged(function()
    local v = Toggles.UseJumpPower.Value
 PlayerSettings.UseJumpPower = v 
end)

Toggles.InfiniteJump:OnChanged(function()
    local v = Toggles.InfiniteJump.Value
 PlayerSettings.InfiniteJump = v 
end)

Toggles.Fly:OnChanged(function()
    local v = Toggles.Fly.Value
    PlayerSettings.Fly = v 
    if v then
        sfly()
    else
        FLYING = false
    end
end)

Toggles.Noclip:OnChanged(function()
    local v = Toggles.Noclip.Value
    PlayerSettings.Noclip = v 
    if not v and LocalPlayer.Character then
        for _, name in ipairs({"HumanoidRootPart", "Head", "UpperTorso", "LowerTorso", "Torso"}) do
            local p = LocalPlayer.Character:FindFirstChild(name)
            if p and p:IsA("BasePart") then p.CanCollide = true end
        end
    end
end)

Toggles.EnableESP:OnChanged(function()
    local v = Toggles.EnableESP.Value
 PlayerSettings.ESP = v 
end)

Toggles.EnableEntityESP:OnChanged(function()
    local v = Toggles.EnableEntityESP.Value
 PlayerSettings.EntityESP = v 
end)

Toggles.UseFOV:OnChanged(function()
    local v = Toggles.UseFOV.Value
    PlayerSettings.UseFOV = v
    if workspace.CurrentCamera then
        workspace.CurrentCamera.FieldOfView = v and PlayerSettings.FOV or 70
    end
end)

Options.FOVSlider:OnChanged(function()
    local v = Options.FOVSlider.Value
    PlayerSettings.FOV = v
    if PlayerSettings.UseFOV and workspace.CurrentCamera then
        workspace.CurrentCamera.FieldOfView = v
    end
end)

Toggles.Freecam:OnChanged(function()
    local v = Toggles.Freecam.Value
    PlayerSettings.Freecam = v
    if v then StartFreecam() else StopFreecam() end
end)

Options.FreecamSpeed:OnChanged(function()
    local v = Options.FreecamSpeed.Value
    PlayerSettings.FreecamSpeed = v
end)

Toggles.Fullbright:OnChanged(function()
    local v = Toggles.Fullbright.Value
    PlayerSettings.Fullbright = v
    local Lighting = game:GetService("Lighting")
    if v then
        originalLighting = {
            Ambient = Lighting.Ambient,
            ColorShift_Bottom = Lighting.ColorShift_Bottom,
            ColorShift_Top = Lighting.ColorShift_Top,
            GlobalShadows = Lighting.GlobalShadows,
            Brightness = Lighting.Brightness,
            FogEnd = Lighting.FogEnd
        }
        Lighting.Ambient = Color3.new(1, 1, 1)
        Lighting.ColorShift_Bottom = Color3.new(1, 1, 1)
        Lighting.ColorShift_Top = Color3.new(1, 1, 1)
        Lighting.GlobalShadows = false
        Lighting.Brightness = 2
        Lighting.FogEnd = 100000
    else
        if originalLighting.Ambient then
            for k, val in pairs(originalLighting) do
                pcall(function() Lighting[k] = val end)
            end
        end
    end
end)

Toggles.PotatoMode:OnChanged(function()
    local Value = Toggles.PotatoMode.Value
    local Lighting = game:GetService("Lighting")
        local Terrain = workspace:FindFirstChildOfClass("Terrain")

        if Value then
            OriginalProps.Lighting.GlobalShadows = Lighting.GlobalShadows
            OriginalProps.Lighting.FogEnd = Lighting.FogEnd
            OriginalProps.Lighting.Brightness = Lighting.Brightness
            
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 9e9
            Lighting.Brightness = 0

            if Terrain then
                OriginalProps.Terrain.WaterWaveSize = Terrain.WaterWaveSize
                OriginalProps.Terrain.WaterWaveSpeed = Terrain.WaterWaveSpeed
                OriginalProps.Terrain.WaterReflectance = Terrain.WaterReflectance
                OriginalProps.Terrain.WaterTransparency = Terrain.WaterTransparency
                
                Terrain.WaterWaveSize = 0
                Terrain.WaterWaveSpeed = 0
                Terrain.WaterReflectance = 0
                Terrain.WaterTransparency = 1
            end

            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("BasePart") and not obj.Parent:FindFirstChild("Humanoid") then
                    OriginalProps.Parts[obj] = {
                        Material = obj.Material,
                        Reflectance = obj.Reflectance
                    }
                    obj.Material = Enum.Material.SmoothPlastic
                    obj.Reflectance = 0
                elseif obj:IsA("Decal") or obj:IsA("Texture") then
                    OriginalProps.Decals[obj] = obj.Transparency
                    obj.Transparency = 1
                elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") then
                    OriginalProps.Particles[obj] = obj.Enabled
                    obj.Enabled = false
                elseif obj:IsA("PostEffect") then
                    OriginalProps.Effects[obj] = obj.Enabled
                    obj.Enabled = false
                end
            end

            Library:Notify("Potato Mode Enabled!", 3)
        else
            Lighting.GlobalShadows = OriginalProps.Lighting.GlobalShadows
            Lighting.FogEnd = OriginalProps.Lighting.FogEnd
            Lighting.Brightness = OriginalProps.Lighting.Brightness

            if Terrain and OriginalProps.Terrain.WaterWaveSize then
                Terrain.WaterWaveSize = OriginalProps.Terrain.WaterWaveSize
                Terrain.WaterWaveSpeed = OriginalProps.Terrain.WaterWaveSpeed
                Terrain.WaterReflectance = OriginalProps.Terrain.WaterReflectance
                Terrain.WaterTransparency = OriginalProps.Terrain.WaterTransparency
            end

            for part, props in pairs(OriginalProps.Parts) do
                if part and part.Parent then
                    part.Material = props.Material
                    part.Reflectance = props.Reflectance
                end
            end

            for decal, trans in pairs(OriginalProps.Decals) do
                if decal and decal.Parent then
                    decal.Transparency = trans
                end
            end

            for particle, enabled in pairs(OriginalProps.Particles) do
                if particle and particle.Parent then
                    particle.Enabled = enabled
                end
            end

            for effect, enabled in pairs(OriginalProps.Effects) do
                if effect and effect.Parent then
                    effect.Enabled = enabled
                end
            end

            Library:Notify("Potato Mode Disabled!", 3)
        end
end)

Options.WebhookURLInput:OnChanged(function()
    local Value = Options.WebhookURLInput.Value
        WebhookSettings.Url = Value
end)

Options.DiscordIdInput:OnChanged(function()
    local Value = Options.DiscordIdInput.Value
        WebhookSettings.DiscordId = Value
end)

Toggles.EnableWebhookToggle:OnChanged(function()
    local Value = Toggles.EnableWebhookToggle.Value
        WebhookSettings.Enabled = Value
        ManageWebhookThread()
end)

Toggles.AntiAFK:OnChanged(function()
    local v = Toggles.AntiAFK.Value
    PlayerSettings.AntiAFK = v
    if v then
        pcall(function()
            if getconnections then
                for _, conn in pairs(getconnections(LocalPlayer.Idled)) do
                    conn:Disable()
                end
            end
        end)
    else
        pcall(function()
            if getconnections then
                for _, conn in pairs(getconnections(LocalPlayer.Idled)) do
                    conn:Enable()
                end
            end
        end)
    end
end)

Toggles.ShowCustomCursor:OnChanged(function()
    local Value = Toggles.ShowCustomCursor.Value
 Library.ShowCustomCursor = Value 
end)


-- Addons Configuration

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
ThemeManager:SetFolder("LanternLib")
SaveManager:SetFolder("LanternLib/Islands")

SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)

Library:OnUnload(function()
    Library.Unloaded = true
    
    local threadsToCancel = {
        HarvestThread, PlantThread, PlowUnplowThread, WaterSoilThread, FertilizeThread,
        AutoWaterThread, AutoDigThread, GrassRockThread, CatchThread, TreeThread, RockThread,
        MonsterThread, FishingThread, VendingESPThread, AutoSniperThread, WebhookThread
    }
    for _, t in ipairs(threadsToCancel) do
        if t then pcall(function() task.cancel(t) end) end
    end
    
    if LanternMovement.NoclipConn then pcall(function() LanternMovement.NoclipConn:Disconnect() end) end
    if fovConnection then pcall(function() fovConnection:Disconnect() end) end
    if RenderSteppedConn then pcall(function() RenderSteppedConn:Disconnect() end) end
    if AntiAfkConnection then pcall(function() AntiAfkConnection:Disconnect() end) end
    if mouseUnlockConn then pcall(function() mouseUnlockConn:Disconnect() end) end
    if clickToSetConnection then pcall(function() clickToSetConnection:Disconnect() end) end
    if BuildSettings.Conn then pcall(function() BuildSettings.Conn:Disconnect() end) end
    if BuildSettings.SavedConn then pcall(function() BuildSettings.SavedConn:Disconnect() end) end

    
    for _, obj in pairs(ESPObjects) do pcall(function() obj.gui:Destroy() end) end
    for _, obj in pairs(EntityESPObjects) do pcall(function() obj.gui:Destroy() end) end
    table.clear(ESPObjects)
    table.clear(EntityESPObjects)
    
    pcall(function() workspace.CurrentCamera.FieldOfView = 70 end)
    local char = game.Players.LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = 16; hum.JumpPower = 50 end
    end
    print("LanternX Unloaded!")
end)

SaveManager:LoadAutoloadConfig()

-- Initial Notification
Library:Notify("LanternX Successfully Loaded!", 5)
Library:Notify("https://discord.gg/HckvpgAKhB", 5)
Library:Notify("Press [RightShift] to toggle UI.", 5)



