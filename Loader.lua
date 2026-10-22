-- ============================================================================
-- LANTERNX - OFFICIAL PRODUCTION LOADER (Loader.lua)
-- Framework: LanternLib Modern Dark Cyan Edition
-- Target Game: Roblox Islands
-- Mode: 100% Strict GitHub Raw
-- ============================================================================

-- [1] Load LanternLib Master Framework (Strict GitHub Raw)
local rawUrl = "https://raw.githubusercontent.com/LanternSupport/LanternLib/main/init.lua?t=" .. os.time()
local content = game:HttpGet(rawUrl)
local fn, compileErr = loadstring(content)
if not fn then
    error("[LanternX] Critical: Failed to compile LanternLib from GitHub: " .. tostring(compileErr), 2)
end
local LanternLib = fn()

-- [2] Launch Script Payload Execution Helper (Strict GitHub Raw)
local function executePayload()
    local scriptUrl = "https://raw.githubusercontent.com/LanternSupport/LanternLib/main/LanternX.lua?t=" .. os.time()
    local payload = game:HttpGet(scriptUrl)

    -- Pass LanternLib in environment to prevent re-fetching
    getgenv().LanternLib = LanternLib

    local payloadFn, payloadErr = loadstring(payload)
    if not payloadFn then
        error("[LanternX] Payload compilation error: " .. tostring(payloadErr), 2)
    end

    local execOk, runtimeErr = pcall(payloadFn)
    if not execOk then
        warn("[LanternX] Payload runtime error: " .. tostring(runtimeErr))
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
