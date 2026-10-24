-- ==============================================================================
-- LANTERNX - OFFICIAL ISLANDS LOADER (SUPABASE CLOUD KEY SYSTEM)
-- Repository: LanternSupport/island
-- UI Library: LanternSupport/LanternLib
-- Dimensions: 550 x 180 px
-- ==============================================================================

local libraryRepo = "https://raw.githubusercontent.com/LanternSupport/LanternLib/main/"
local scriptRepo = "https://raw.githubusercontent.com/LanternSupport/island/main/"

-- ------------------------------------------------------------------------------
-- [1] Load External LoaderLib Module (From LanternLib)
-- ------------------------------------------------------------------------------
local LoaderLib = loadstring(game:HttpGet(libraryRepo .. "loader/LoaderLib.lua"))()

-- ------------------------------------------------------------------------------
-- [2] Constants & Supabase Cloud Configuration
-- ------------------------------------------------------------------------------
local HWID = LoaderLib:GetHWID()

-- URL ของหน้าเว็บรับคีย์ของคุณ (แนบ HWID ไปอัตโนมัติ เพื่อนำไปล็อคเครื่อง)
local GET_KEY_URL = "https://lanternsupport.xyz/?hwid=" .. tostring(HWID) .. "#getkey"

local KEY_FILE = "LanternLib/Key.txt"
local PAYLOAD_URL = scriptRepo .. "LanternX.lua"

-- ข้อมูลเชื่อมต่อ Supabase Database
local SUPABASE_REST_URL = "https://fvptksmyvhhmhpgasjiq.supabase.co/rest/v1/user_keys"
local SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ2cHRrc215dmhobWhwZ2FzamlxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI3ODMxNjEsImV4cCI6MjEwODM1OTE2MX0.mC4fp9VldEEYG5uJlgrM4VxRDjMSJd7uUElky-T4YFg"

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

-- ฟังก์ชันแปลง ISO 8601 Timestamp (UTC) เป็น Unix Timestamp
local function parseIsoTimestamp(isoStr)
    if not isoStr then return 0 end
    local pattern = "(%d+)%-(%d+)%-(%d+)T(%d+):(%d+):(%d+)"
    local year, month, day, hour, min, sec = isoStr:match(pattern)
    if not year then return 0 end
    return os.time({
        year = tonumber(year),
        month = tonumber(month),
        day = tonumber(day),
        hour = tonumber(hour),
        min = tonumber(min),
        sec = tonumber(sec)
    })
end

-- ------------------------------------------------------------------------------
-- [4] Verification via Supabase Database (HWID Lock + Expiry Check)
-- ------------------------------------------------------------------------------
local function verifyAndExecute(key, controller, doneCallback, isAutoAuth)
    controller:SetVerifying(true, isAutoAuth and "Auto Login..." or "Checking...")
    controller:SetStatus(isAutoAuth and "Validating saved key..." or "Contacting Supabase Cloud...", Color3.fromRGB(255, 0, 0))

    task.spawn(function()
        task.wait(0.2)

        local HttpService = game:GetService("HttpService")
        local cleanKey = string.gsub(key, "%s+", "")
        local encodedKey = HttpService:UrlEncode(cleanKey)
        
        -- ส่ง API query ไปยัง Supabase (แนบ apikey ไปใน URL ทำให้รองรับ Executor ทุกตัวรวมถึง game:HttpGet)
        local queryUrl = SUPABASE_REST_URL .. "?apikey=" .. SUPABASE_KEY .. "&key=eq." .. encodedKey .. "&select=*"

        local req = (syn and syn.request) or (http and http.request) or http_request or request
        local success, response = pcall(function()
            if req then
                return req({
                    Url = queryUrl,
                    Method = "GET",
                    Headers = {
                        ["apikey"] = SUPABASE_KEY,
                        ["Authorization"] = "Bearer " .. SUPABASE_KEY
                    }
                })
            else
                local body = game:HttpGet(queryUrl)
                return { StatusCode = 200, Body = body }
            end
        end)

        if not success or not response or response.StatusCode ~= 200 then
            controller:SetVerifying(false)
            controller:SetStatus("Connection error to auth server. Try again.", Color3.fromRGB(244, 63, 94))
            if doneCallback then doneCallback() end
            return
        end

        local parseOk, records = pcall(function()
            return HttpService:JSONDecode(response.Body)
        end)

        if not parseOk or type(records) ~= "table" or #records == 0 then
            deleteSavedKey()
            controller:SetVerifying(false)
            controller:SetStatus("Invalid Key! Key not found in system.", Color3.fromRGB(244, 63, 94))
            if doneCallback then doneCallback() end
            return
        end

        local record = records[1]

        -- [1] ตรวจสอบการล็อค HWID (HWID Locking Verification with Auto-Binding on First Use)
        local isUnbound = (record.hwid == nil or record.hwid == "" or record.hwid == "UNBOUND" or tostring(record.hwid) == "userdata: NULL" or tostring(record.hwid) == "null")

        if isUnbound then
            -- คีย์นี้รับมาจากหน้าเว็บโดยตรง (ยังไม่เคยผูกกับใคร)! ทำการล็อคผูกกับ HWID ของเครื่องนี้ทันที
            controller:SetStatus("First use detected! Binding key to this device...", Color3.fromRGB(255, 180, 0))

            local patchUrl = SUPABASE_REST_URL .. "?apikey=" .. SUPABASE_KEY .. "&key=eq." .. encodedKey
            local patchBody = HttpService:JSONEncode({ hwid = tostring(HWID) })

            pcall(function()
                if req then
                    req({
                        Url = patchUrl,
                        Method = "PATCH",
                        Headers = {
                            ["apikey"] = SUPABASE_KEY,
                            ["Authorization"] = "Bearer " .. SUPABASE_KEY,
                            ["Content-Type"] = "application/json",
                            ["Prefer"] = "return=minimal"
                        },
                        Body = patchBody
                    })
                end
            end)
        else
            -- คีย์นี้เคยถูกผูกกับเครื่องไว้แล้ว! ตรวจสอบว่าตรงกับ HWID เครื่องนี้หรือไม่
            if tostring(record.hwid) ~= tostring(HWID) then
                deleteSavedKey()
                controller:SetVerifying(false)
                controller:SetStatus("HWID Mismatch! Key locked to another device.", Color3.fromRGB(244, 63, 94))
                if doneCallback then doneCallback() end
                return
            end
        end

        -- [2] ตรวจสอบวันหมดอายุ (24-Hour Expiration Check)
        if record.expires_at then
            local expiryUnix = parseIsoTimestamp(record.expires_at)
            local currentUnix = os.time()
            if expiryUnix > 0 and currentUnix > expiryUnix then
                deleteSavedKey()
                controller:SetVerifying(false)
                controller:SetStatus("Key Expired! Please get a new 24h key.", Color3.fromRGB(244, 63, 94))
                if doneCallback then doneCallback() end
                return
            end
        end

        -- คีย์ถูกต้อง 100% และ HWID ตรงกับเครื่องนี้! บันทึกคีย์ลงเครื่อง
        saveKey(cleanKey)

        controller:SetSuccess("Verified!")
        controller:SetStatus("Key verified! Launching LanternX...", Color3.fromRGB(52, 211, 153))

        -- ปิดหน้าต่าง Loader อย่างนุ่มนวล
        task.wait(0.4)
        controller:Close(0.4)

        -- รันสคริปต์หลัก (LanternX.lua) จาก GitHub
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
    PlaceholderText = "Enter Key here (e.g. ISLANDS-XXXX-XXXX-XXXX) . . . .",
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
    window:SetStatus("Saved key detected. Auto-authenticating...", Color3.fromRGB(255, 0, 0))
    task.delay(0.5, function()
        verifyAndExecute(savedKey, window, nil, true)
    end)
end
