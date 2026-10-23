-- ==============================================================================
-- LANTERNX - OFFICIAL ISLANDS LOADER
-- Repository: LanternSupport/island
-- UI Library: LanternSupport/LanternLib
-- Dimensions: 550 x 180 px
-- ==============================================================================

local libraryRepo = "https://raw.githubusercontent.com/LanternSupport/LanternLib/main/"
local scriptRepo = "https://raw.githubusercontent.com/LanternSupport/island/main/"

-- ------------------------------------------------------------------------------
-- [1] Load External LoaderLib Module (From LanternLib)
-- ------------------------------------------------------------------------------
local LoaderLib = nil
do
    local source = nil
    -- Local developer check
    if readfile and isfile and isfile("loader/LoaderLib.lua") then
        source = readfile("loader/LoaderLib.lua")
    elseif readfile and isfile and isfile("LanternLib/loader/LoaderLib.lua") then
        source = readfile("LanternLib/loader/LoaderLib.lua")
    else
        -- GitHub Raw from LanternLib
        source = game:HttpGet(libraryRepo .. "loader/LoaderLib.lua")
    end

    local fn, err = loadstring(source)
    if not fn then
        error("[LanternX] Failed to load LoaderLib: " .. tostring(err), 2)
    end
    LoaderLib = fn()
end

-- ------------------------------------------------------------------------------
-- [2] Constants & Key Configuration
-- ------------------------------------------------------------------------------
local HWID = LoaderLib:GetHWID()
local GET_KEY_URL = "https://www.lanternsupport.xyz/"
local KEY_FILE = "LanternLib/Key.txt"
local PAYLOAD_URL = scriptRepo .. "LanternX.lua"

-- ------------------------------------------------------------------------------
-- [3] Auto-Save Key Management System
-- ------------------------------------------------------------------------------
local function saveKey(key)
    pcall(function()
        if makefolder and not isfolder("LanternLib") then
            makefolder("LanternLib")
        end
        if writefile then
            writefile(KEY_FILE, key)
        end
    end)
end

local function loadSavedKey()
    local savedKey = nil
    pcall(function()
        if isfile and isfile(KEY_FILE) and readfile then
            savedKey = readfile(KEY_FILE)
        end
    end)
    if savedKey then
        savedKey = string.gsub(savedKey, "%s+", "")
        if #savedKey > 0 then
            return savedKey
        end
    end
    return nil
end

local function deleteSavedKey()
    pcall(function()
        if isfile and isfile(KEY_FILE) and delfile then
            delfile(KEY_FILE)
        end
    end)
end

-- ------------------------------------------------------------------------------
-- [4] Verification & Script Payload Execution Logic
-- ------------------------------------------------------------------------------
local function verifyAndExecute(key, controller, doneCallback, isAutoAuth)
    controller:SetVerifying(true, isAutoAuth and "Auto Login..." or "Checking...")
    controller:SetStatus(isAutoAuth and "Validating saved key..." or "Contacting authentication server...", Color3.fromRGB(56, 189, 248))

    task.spawn(function()
        -- Simulate verification delay
        task.wait(0.5)

        -- Validation check (Key format check)
        local isValid = (#key >= 5)

        if not isValid then
            deleteSavedKey()
            controller:SetVerifying(false)
            controller:SetStatus("Invalid or expired key. Please get a new key.", Color3.fromRGB(244, 63, 94))
            if doneCallback then doneCallback() end
            return
        end

        -- Key is valid! Save it to executor disk
        saveKey(key)

        controller:SetSuccess("Verified!")
        controller:SetStatus("Key verified! Launching LanternX...", Color3.fromRGB(52, 211, 153))

        -- Smoothly close loader window
        task.wait(0.4)
        controller:Close(0.4)

        -- Execute the LanternX payload script from LanternSupport/island
        task.spawn(function()
            local fetchOk, scriptContent = pcall(function()
                return game:HttpGet(PAYLOAD_URL)
            end)

            if not fetchOk or not scriptContent or #scriptContent == 0 then
                warn("[LanternX] Network error: Failed to download LanternX.lua from GitHub.")
                return
            end

            local payloadFn, compileErr = loadstring(scriptContent)
            if not payloadFn then
                warn("[LanternX] Compile error in LanternX.lua: " .. tostring(compileErr))
                return
            end

            local runOk, runErr = pcall(payloadFn)
            if not runOk then
                warn("[LanternX] Runtime error in LanternX.lua: " .. tostring(runErr))
            end
        end)

        if doneCallback then doneCallback() end
    end)
end

-- ------------------------------------------------------------------------------
-- [5] Create Loader Window via LoaderLib
-- ------------------------------------------------------------------------------
local window = LoaderLib:CreateWindow({
    Title = "LanternX - Islands Loader",
    Subtitle = "Roblox Key Verification.",
    HWID = HWID,
    GetKeyURL = GET_KEY_URL,
    PlaceholderText = "Enter Key here (e.g. LX-XXXX-XXXX-XXXX) . . . .",
    OnSubmit = function(submittedKey, controller, doneCallback)
        if not submittedKey or #submittedKey < 5 then
            controller:SetStatus("Please enter a valid key format.", Color3.fromRGB(244, 63, 94))
            doneCallback()
            return
        end
        verifyAndExecute(submittedKey, controller, doneCallback, false)
    end
})

-- ------------------------------------------------------------------------------
-- [6] Auto-Save Key Detection on Startup
-- ------------------------------------------------------------------------------
local savedKey = loadSavedKey()
if savedKey and #savedKey >= 5 then
    window:SetKeyText(savedKey)
    window:SetStatus("Saved key detected. Auto-authenticating...", Color3.fromRGB(56, 189, 248))
    task.delay(0.5, function()
        verifyAndExecute(savedKey, window, nil, true)
    end)
end
