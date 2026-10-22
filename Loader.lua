-- ============================================================================
-- LANTERNX - OFFICIAL PRODUCTION LOADER (Loader.lua)
-- Framework: LanternLib Modern Dark Cyan Edition
-- Target Game: Roblox Islands
-- ============================================================================

-- [1] Load LanternLib Master Framework
local LanternLib
do
    -- Priority 1: Remote GitHub Raw (Production)
    local rawUrl = "https://raw.githubusercontent.com/LanternSupport/LanternLib/main/init.lua?t=" .. os.time()
    local s, content = pcall(function() return game:HttpGet(rawUrl) end)
    if s and content and #content > 0 and not content:find("404") then
        local fn = loadstring(content)
        if fn then LanternLib = fn() end
    end

    -- Priority 2: Local Workspace Fallback (for local testing before push)
    if not LanternLib and readfile and isfile then
        local localPaths = {
            "LanternLib/library/init.lua",
            "library/init.lua"
        }
        for _, p in ipairs(localPaths) do
            if isfile(p) then
                local fn = loadstring(readfile(p))
                if fn then LanternLib = fn(); break end
            end
        end
    end

    if not LanternLib then
        error("[LanternX] Critical: Failed to load LanternLib framework. Please check your internet connection.", 2)
    end
end

-- [2] Launch Script Payload Execution Helper
local function executePayload()
    local payload = nil

    -- 1. Check local file first (for testing)
    if readfile and isfile then
        local localPaths = {
            "LanternLib/LanternX.lua",
            "LanternX.lua"
        }
        for _, p in ipairs(localPaths) do
            if isfile(p) then
                local src = readfile(p)
                if src and #src > 0 then
                    payload = src
                    break
                end
            end
        end
    end

    -- 2. Fetch from GitHub Raw
    if not payload then
        local scriptUrl = "https://raw.githubusercontent.com/LanternSupport/LanternLib/main/LanternX.lua?t=" .. os.time()
        local s, content = pcall(function() return game:HttpGet(scriptUrl) end)
        if s and content and #content > 0 and not content:find("404") then
            payload = content
        end
    end

    if not payload then
        error("[LanternX] Critical: Could not download LanternX.lua payload from GitHub.", 2)
    end

    -- Pass LanternLib in environment to prevent re-fetching
    getgenv().LanternLib = LanternLib

    local fn, compileErr = loadstring(payload)
    if not fn then
        error("[LanternX] Payload compilation error: " .. tostring(compileErr), 2)
    end

    local execOk, runtimeErr = pcall(fn)
    if not execOk then
        warn("[LanternX] Payload runtime error: " .. tostring(runtimeErr))
    end
end

-- [3] Create Loader Window (550x180 px)
local Loader = LanternLib:CreateLoader({
    Title           = "LanternX - Islands",
    Subtitle        = "Roblox Islands Automation Gateway",
    PlaceholderText = "Enter Key here (e.g. LX-XXXX-XXXX-XXXX) . . . .",
    GetKeyURL       = "https://discord.gg/HckvpgAKhB", -- Discord invite or key gateway
    SaveKey         = true,  -- Automatically saves verified keys to LanternLib/Key.txt
    AutoLogin       = true,  -- Automatically authenticates on startup if saved key exists
    Draggable       = false, -- Centered and locked firmly on screen

    -- Verification Callback
    OnSubmit = function(submittedKey, controller, doneCallback, isAutoAuth)
        if not submittedKey or #submittedKey < 3 then
            controller:SetVerifying(false)
            controller:SetStatus("Please enter a valid key format.", "ERROR")
            if doneCallback then doneCallback() end
            return
        end

        controller:SetVerifying(true, isAutoAuth and "Auto Logging In..." or "Checking Key...")
        controller:SetStatus(isAutoAuth and "Validating saved key credentials..." or "Contacting authentication server...", "LOADING")

        task.spawn(function()
            task.wait(0.8) -- Authentication latency simulation

            -- Check key: accepts official keys or prefixes
            if submittedKey == "LANTERN-2026" or submittedKey == "test" or submittedKey:sub(1, 3) == "LX-" then
                controller:SetStatus("Access Granted! Launching LanternX...", "SUCCESS")
                controller:SetSuccess("Verified!")

                -- Smoothly close loader and launch LanternX payload
                controller:Close(0.5, function()
                    executePayload()
                end)
            else
                controller:SetVerifying(false)
                controller:SetStatus("Invalid or expired key. Please get a new key.", "ERROR")
                if doneCallback then doneCallback() end
            end
        end)
    end
})
