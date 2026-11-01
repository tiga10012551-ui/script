--[[
    TD Script Architect Blueprint - Anime Adventures (Anti-Error 267 & d.json / Raid Macro Edition)
    Engineered with Fluent UI, SaveManager, InterfaceManager
    - Hook-Free Macro Recorder: Uses passive Workspace._UNITS & _stats listeners (100% Undetected)
    - Standard Macro Format: Saves & loads unit IDs ("bulma", "goku_ssj3_evolved") like d.json
    - Supports "SpawnTower", "UpgradeTower", "SellTower", and "Use Ability" (Raid format)
    - Anti-Error 267 Safeguards: Strict Equipped UUID validation & Anti-Remote Spam
]]
-- ==================== [ รอเข้าเกมให้เสร็จสมบูรณ์ก่อนรันสคริปต์ ] ====================
if not game:IsLoaded() then
    game.Loaded:Wait()
end

local _Plrs = game:GetService("Players")
local _LP = _Plrs.LocalPlayer
repeat task.wait(0.5) until _LP and _LP.Character and _LP.Character:FindFirstChild("HumanoidRootPart") and _LP:FindFirstChild("PlayerGui")

-- ปรับเลขวินาทีตรงนี้ได้เลย (แนะนำ 8 - 12 วินาที เพื่อให้เกมเช็ค Anti-Cheat ตอนเข้าแมพให้เสร็จก่อน)
task.wait(5)
-- =================================================================================

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local LOBBY_PLACE_ID = 8304191830
local MACRO_FOLDER = "AnimeAdventures_Macros"
local CONFIG_FOLDER = "FluentScriptHub/AnimeAdventures"
local USER_CONFIG_NAME = LocalPlayer.Name

-- ล้าง Connection, Hologram และ Macro Markers เก่าเมื่อรันสคริปต์ซ้ำ
if getgenv().TD_ActiveConnections then
    for _, conn in ipairs(getgenv().TD_ActiveConnections) do
        pcall(function() conn:Disconnect() end)
    end
end
getgenv().TD_ActiveConnections = {}

local function AddConnection(RBXSignal, callback)
    local conn = RBXSignal:Connect(callback)
    table.insert(getgenv().TD_ActiveConnections, conn)
    return conn
end

-- คืนค่า EndpointsClient.invoke_server เดิมหากเคยถูก Hook จากสคริปต์เวอร์ชันเก่า
pcall(function()
    local src = ReplicatedStorage:FindFirstChild("src")
    local Loader = src and require(src:FindFirstChild("Loader"))
    local mainScript = LocalPlayer.PlayerScripts:FindFirstChild("main")
    if Loader and mainScript and getgenv().TD_OrigInvokeServer then
        local ep = Loader.load_client_service(mainScript, "EndpointsClient")
        if ep then
            ep.invoke_server = getgenv().TD_OrigInvokeServer
        end
    end
end)

if Workspace:FindFirstChild("_TD_Holograms") then
    pcall(function() Workspace._TD_Holograms:Destroy() end)
end
if Workspace:FindFirstChild("_TD_MacroMarkers") then
    pcall(function() Workspace._TD_MacroMarkers:Destroy() end)
end

if typeof(makefolder) == "function" and typeof(isfolder) == "function" then
    if not isfolder(MACRO_FOLDER) then
        makefolder(MACRO_FOLDER)
    end
end

-- ==============================================================================
-- 1. CORE GAME MODULES & DYNAMIC WORLD/LEVEL DATA LOADER
-- ==============================================================================
local src = ReplicatedStorage:WaitForChild("src", 15)
local Loader = src and require(src:WaitForChild("Loader", 10))
local mainScript = LocalPlayer.PlayerScripts:WaitForChild("main", 10) or LocalPlayer.PlayerScripts:FindFirstChildWhichIsA("LocalScript")

local EndpointsClient = nil
local UnitCollectionServiceClient = nil
local DataServiceClient = nil
local Util = nil

pcall(function()
    if Loader and mainScript then
        EndpointsClient = Loader.load_client_service(mainScript, "EndpointsClient")
        UnitCollectionServiceClient = Loader.load_client_service(mainScript, "UnitCollectionServiceClient")
        pcall(function()
            DataServiceClient = Loader.load_client_service(mainScript, "DataServiceClient")
        end)
    end
    if src then
        Util = require(src:WaitForChild("Util", 5))
    end
end)

local Worlds = nil
local WorldLevelOrder = nil
local Levels = nil
local UnitsData = nil

pcall(function()
    local dataFolder = src and src:WaitForChild("Data", 10)
    if dataFolder then
        if dataFolder:FindFirstChild("Worlds") then Worlds = require(dataFolder.Worlds) end
        if dataFolder:FindFirstChild("WorldLevelOrder") then WorldLevelOrder = require(dataFolder.WorldLevelOrder) end
        if dataFolder:FindFirstChild("Levels") then Levels = require(dataFolder.Levels) end
        if dataFolder:FindFirstChild("Units") then UnitsData = require(dataFolder.Units) end
    end
end)

local clientToServer = ReplicatedStorage:WaitForChild("endpoints", 5) and ReplicatedStorage.endpoints:WaitForChild("client_to_server", 5)

local function InvokeServer(endpointName, ...)
    if EndpointsClient and type(EndpointsClient.invoke_server) == "function" then
        local ok, res = pcall(EndpointsClient.invoke_server, endpointName, ...)
        if ok then return res end
    end
    local remote = clientToServer and clientToServer:FindFirstChild(endpointName)
    if remote and remote:IsA("RemoteFunction") then
        local ok, res = pcall(remote.InvokeServer, remote, ...)
        if ok then return res end
    end
    return nil
end

local FARM_UNIT_FALLBACK = {
    ["bulma"] = true,
    ["bulma_summer"] = true,
    ["speedwagon"] = true,
    ["todoroki_farm"] = true,
    ["draco"] = true,
    ["leorio"] = true,
    ["charmy"] = true,
    ["oshino"] = true
}

local WorldNameToIdMap = {}
local WorldIdToDisplayName = {}
local DynamicWorldNames = {}

local function BuildDynamicWorldsFromGameData()
    table.clear(WorldNameToIdMap)
    table.clear(WorldIdToDisplayName)
    table.clear(DynamicWorldNames)

    local addedWorldIds = {}

    local function RegisterWorldEntry(wId, wData)
        if type(wId) ~= "string" or addedWorldIds[wId] then return end
        if type(wData) ~= "table" then return end

        local hasValidLevels = false
        if type(Levels) == "table" then
            for _, lData in pairs(Levels) do
                if type(lData) == "table" and lData.world == wId then
                    hasValidLevels = true
                    break
                end
            end
        else
            hasValidLevels = true
        end

        if not hasValidLevels then return end

        local displayName = tostring(wData.name or wData.title or wId)
        if displayName == "" then displayName = wId end

        if WorldNameToIdMap[displayName] and WorldNameToIdMap[displayName] ~= wId then
            displayName = string.format("%s (%s)", displayName, wId)
        end

        addedWorldIds[wId] = true
        WorldNameToIdMap[displayName] = wId
        WorldNameToIdMap[wId] = wId
        WorldIdToDisplayName[wId] = displayName
        table.insert(DynamicWorldNames, displayName)
    end

    if type(WorldLevelOrder) == "table" and type(Worlds) == "table" then
        local orderTable = WorldLevelOrder.WORLD_ORDER or WorldLevelOrder
        if type(orderTable) == "table" then
            for _, wId in ipairs(orderTable) do
                if Worlds[wId] then
                    RegisterWorldEntry(wId, Worlds[wId])
                end
            end
        end
    end

    if type(Worlds) == "table" then
        local extraWorlds = {}
        for wId, wData in pairs(Worlds) do
            if type(wId) == "string" and type(wData) == "table" and not addedWorldIds[wId] then
                table.insert(extraWorlds, { id = wId, data = wData })
            end
        end
        table.sort(extraWorlds, function(a, b)
            local nameA = tostring(a.data.name or a.id):lower()
            local nameB = tostring(b.data.name or b.id):lower()
            return nameA < nameB
        end)
        for _, item in ipairs(extraWorlds) do
            RegisterWorldEntry(item.id, item.data)
        end
    end

    if #DynamicWorldNames == 0 then
        local fallbackList = {
            { id = "planet_namek", name = "Planet Namak" },
            { id = "shiganshina", name = "Shiganshina District" },
            { id = "snowy_town", name = "Snowy Town" },
            { id = "hidden_sand", name = "Hidden Sand Village" },
            { id = "marine_base", name = "Marine's Ford" },
            { id = "ghoul_city", name = "Ghoul City" },
            { id = "hollow_world", name = "Hollow World" },
            { id = "ant_kingdom", name = "Ant Kingdom" },
            { id = "magic_town", name = "Magic Town" },
            { id = "cursed_academy", name = "Cursed Academy" },
            { id = "clover_kingdom", name = "Clover Kingdom" },
            { id = "cape_canaveral", name = "Cape Canaveral" },
            { id = "alien_spaceship", name = "Alien Spaceship" },
            { id = "fable_kingdom", name = "Fable Kingdom" },
            { id = "hero_city", name = "Hero City" },
            { id = "dungeon", name = "Dungeon" }
        }
        for _, fb in ipairs(fallbackList) do
            WorldNameToIdMap[fb.name] = fb.id
            WorldNameToIdMap[fb.id] = fb.id
            WorldIdToDisplayName[fb.id] = fb.name
            table.insert(DynamicWorldNames, fb.name)
        end
    end
end

BuildDynamicWorldsFromGameData()

local function ResolveTargetLevelId(worldName, actStr, diffStr)
    local cleanWorldName = tostring(worldName or "")
    local targetWorldId = WorldNameToIdMap[cleanWorldName]

    if not targetWorldId and type(Worlds) == "table" then
        for wId, wData in pairs(Worlds) do
            if type(wData) == "table" then
                if tostring(wId):lower() == cleanWorldName:lower()
                    or (wData.name and tostring(wData.name):lower() == cleanWorldName:lower()) then
                    targetWorldId = wId
                    break
                end
            end
        end
    end
    targetWorldId = targetWorldId or WorldNameToIdMap[DynamicWorldNames[1]] or "planet_namek"

    local isInfinite = tostring(actStr):lower():find("infinite") ~= nil
    local actNum = tonumber(actStr) or 1
    local targetLevelId = nil

    if type(WorldLevelOrder) == "table" and type(WorldLevelOrder[targetWorldId]) == "table" then
        local orderedLevels = WorldLevelOrder[targetWorldId]
        if not isInfinite and orderedLevels[actNum] then
            targetLevelId = orderedLevels[actNum]
        elseif isInfinite then
            for _, lvlId in ipairs(orderedLevels) do
                if tostring(lvlId):lower():find("infinite") then
                    targetLevelId = lvlId
                    break
                end
            end
        end
    end

    if not targetLevelId and type(Levels) == "table" then
        for id, lData in pairs(Levels) do
            if type(lData) == "table" and lData.world == targetWorldId then
                local idLower = tostring(id):lower()
                if isInfinite then
                    if (idLower:find("infinite") or lData.infinite)
                        and not idLower:find("winter")
                        and not idLower:find("tower")
                        and not idLower:find("legend") then
                        targetLevelId = id
                        break
                    end
                else
                    local rankMatch = (lData.story_level_rank == actNum)
                        or (lData.level_rank == actNum)
                        or (idLower:match("_(%d+)$") == tostring(actNum))
                    if rankMatch
                        and not lData.infinite
                        and not idLower:find("infinite")
                        and not idLower:find("winter")
                        and not idLower:find("challenge")
                        and not idLower:find("legend") then
                        targetLevelId = id
                        break
                    end
                end
            end
        end
    end

    if not targetLevelId then
        targetLevelId = isInfinite and (targetWorldId .. "_infinite") or (targetWorldId .. "_level_" .. tostring(actNum))
    end

    local finalDiff = isInfinite and "Hard" or (diffStr or "Normal")
    return targetLevelId, finalDiff
end

---------------------------------------------------------------------
-- 2. GLOBAL STATE & RAYCAST / COST ENGINE
---------------------------------------------------------------------
local State = {
    IsLobby = (game.PlaceId == LOBBY_PLACE_ID) or (Workspace:FindFirstChild("_LOBBIES") ~= nil),
    -- Macro State
    ActiveMacroData = nil,
    PreviewMacroData = nil,
    PreviewMacroFileName = nil,
    MacroIndex = 1,
    SpawnedUnitUUIDs = {},
    IsRecording = false,
    RecordedActions = {},
    RecordStartTime = 0,
    RecordedUnitCounter = 0,
    InstanceToTagMap = {},
    HookedUnitInstances = {},
    MacroLogLines = {},
    -- Universal Road State
    ActiveRoadLabel = "Auto-Detecting",
    EnemyVerifiedRoad = false,
    CandidateRoadChains = {},
    MainRoadNodes = {},
    MainRoadSegments = {},
    MainRoadTotalLength = 0,
    MainRoadBaseY = 0,
    MainRoadHalfWidth = 2.5,
    MainPartInstances = {},
    -- Hill State (workspace._terrain.hill)
    HillPartInstances = {},
    HillGeometries = {},
    HologramFolder = nil,
    MacroMarkerFolder = nil,
    CalculatedSlots = {
        Ground = {},
        Hill = {},
        Farm = {}
    },
    CachedProfileData = nil,
    IsBootingConfig = true,
}

local function GetPlayerCash()
    local stats = LocalPlayer:FindFirstChild("_stats")
    if stats and stats:FindFirstChild("resource") then
        return tonumber(stats.resource.Value) or 0
    end
    local gameData = Workspace:FindFirstChild("_DATA") and Workspace._DATA:FindFirstChild("GameData")
    if gameData and gameData:FindFirstChild(LocalPlayer.Name) and gameData[LocalPlayer.Name]:FindFirstChild("resource") then
        return tonumber(gameData[LocalPlayer.Name].resource.Value) or 0
    end
    return 0
end

local reusableRayParams = RaycastParams.new()
reusableRayParams.FilterType = Enum.RaycastFilterType.Exclude
reusableRayParams.IgnoreWater = true

local obstacleCheckRayParams = RaycastParams.new()
obstacleCheckRayParams.FilterType = Enum.RaycastFilterType.Exclude
obstacleCheckRayParams.IgnoreWater = true

local hillOnlyRayParams = RaycastParams.new()
hillOnlyRayParams.FilterType = Enum.RaycastFilterType.Include
hillOnlyRayParams.IgnoreWater = true

local function RefreshRayFilter(includeRoadInFilter)
    local ignore = {}
    if LocalPlayer.Character then table.insert(ignore, LocalPlayer.Character) end
    if State.HologramFolder then table.insert(ignore, State.HologramFolder) end
    if State.MacroMarkerFolder then table.insert(ignore, State.MacroMarkerFolder) end
    if Workspace:FindFirstChild("_TD_Holograms") then table.insert(ignore, Workspace._TD_Holograms) end
    if Workspace:FindFirstChild("_TD_MacroMarkers") then table.insert(ignore, Workspace._TD_MacroMarkers) end
    if Workspace:FindFirstChild("_UNITS") then table.insert(ignore, Workspace._UNITS) end
    if Workspace:FindFirstChild("_ENEMIES") then table.insert(ignore, Workspace._ENEMIES) end
    if Workspace:FindFirstChild("_FX") then table.insert(ignore, Workspace._FX) end
    if Workspace:FindFirstChild("_ignore") then table.insert(ignore, Workspace._ignore) end
    if Workspace:FindFirstChild("_PROJECTILES") then table.insert(ignore, Workspace._PROJECTILES) end

    obstacleCheckRayParams.FilterDescendantsInstances = { unpack(ignore) }

    if includeRoadInFilter and Workspace:FindFirstChild("_road") then
        table.insert(ignore, Workspace._road)
    end
    reusableRayParams.FilterDescendantsInstances = ignore
end

local function SafeRaycastGround(pos, upOffset, downDist)
    local upY = upOffset or 12
    local downY = downDist or -45
    local res = Workspace:Raycast(Vector3.new(pos.X, pos.Y + upY, pos.Z), Vector3.new(0, downY, 0), reusableRayParams)
    if res and res.Position then
        return res.Position, res.Instance, res.Normal
    end
    return pos, nil, Vector3.new(0, 1, 0)
end

local function ValidateGroundPlacementPoint(samplePos, refGroundY)
    local res = Workspace:Raycast(
        Vector3.new(samplePos.X, refGroundY + 35, samplePos.Z),
        Vector3.new(0, -65, 0),
        obstacleCheckRayParams
    )
    if not res or not res.Instance then
        return samplePos, true
    end

    local hitInst = res.Instance
    local hitPos = res.Position
    local hitNormal = res.Normal

    if hitNormal.Y < 0.75 or math.abs(hitPos.Y - refGroundY) > 1.85 then
        return nil, false
    end

    local roadFolder = Workspace:FindFirstChild("_road") or Workspace:FindFirstChild("road")
    if roadFolder and hitInst:IsDescendantOf(roadFolder) then
        return nil, false
    end

    local terrainFolder = Workspace:FindFirstChild("_terrain") or Workspace:FindFirstChild("terrain")
    local mapFolder = Workspace:FindFirstChild("_map") or Workspace:FindFirstChild("map")
    if terrainFolder and mapFolder and hitInst:IsDescendantOf(mapFolder) and not hitInst:IsDescendantOf(terrainFolder) then
        return nil, false
    end

    return hitPos, true
end

local function BuildPlacementCFrame(posOrCF)
    RefreshRayFilter(true)
    local rawPos = typeof(posOrCF) == "CFrame" and posOrCF.Position or posOrCF
    local groundPos, hitInst = SafeRaycastGround(rawPos, 6, -18)
    if not hitInst or math.abs(groundPos.Y - rawPos.Y) > 3.5 then
        groundPos = rawPos
    end
    if Util and type(Util.CFramePLV) == "function" then
        local ok, cf = pcall(Util.CFramePLV, groundPos, Vector3.new(0, 0, -1), Vector3.new(0, 1, 0))
        if ok and cf then return cf end
    end
    return CFrame.new(groundPos)
end

local function NormalizeUnitIdentifier(str)
    local s = tostring(str or ""):lower()
    s = s:match("^([^:]+)") or s
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    return s
end

local function LookupUnitDataEntry(unitId, unitName)
    local cleanId = NormalizeUnitIdentifier(unitId or unitName)
    if UnitsData and cleanId ~= "" then
        local uEntry = UnitsData[cleanId] or UnitsData[tostring(unitId or "")]
        if not uEntry then
            for k, v in pairs(UnitsData) do
                if type(v) == "table" then
                    local kLower = tostring(k):lower()
                    local vIdLower = v.id and tostring(v.id):lower() or ""
                    local vNameLower = v.name and tostring(v.name):lower() or ""
                    if kLower == cleanId
                        or vIdLower == cleanId
                        or vNameLower == cleanId
                        or (unitName and vNameLower == tostring(unitName):lower()) then
                        uEntry = v
                        break
                    end
                end
            end
        end
        return uEntry
    end
    return nil
end

local function LookupUnitCostByIdOrName(unitId, unitName, targetUpgradeLevel)
    local uEntry = LookupUnitDataEntry(unitId, unitName)
    if uEntry then
        if targetUpgradeLevel and targetUpgradeLevel > 0 then
            local upgTable = uEntry.upgrade or uEntry.upgrades
            if type(upgTable) == "table" then
                local step = upgTable[targetUpgradeLevel] or upgTable[tostring(targetUpgradeLevel)]
                if type(step) == "table" then
                    local uc = tonumber(step.cost) or tonumber(step.price)
                    if uc and uc > 0 then return uc end
                elseif tonumber(step) then
                    return tonumber(step)
                end
            end
        else
            local sc = tonumber(uEntry.cost) or tonumber(uEntry.deploy_cost) or tonumber(uEntry.price)
            if sc and sc > 0 then return sc end
        end
    end
    return nil
end

local function ClassifyUnitPlacementType(unitId, unitName)
    local checkStr = (tostring(unitId or "") .. " " .. tostring(unitName or "")):lower()
    for farmKey, _ in pairs(FARM_UNIT_FALLBACK) do
        if checkStr:find(farmKey) then
            return "Farm"
        end
    end
    local uEntry = LookupUnitDataEntry(unitId, unitName)
    if uEntry then
        if uEntry.farm or uEntry.is_farm or (uEntry.type and tostring(uEntry.type):lower():find("farm")) then
            return "Farm"
        end
        if uEntry.hill or uEntry.air or uEntry.placement == "hill" or uEntry.placement == "air" or uEntry.hybrid then
            return "Hill"
        end
    end
    return "Ground"
end

local function GetCurrentWave()
    local w = Workspace:FindFirstChild("_wave_num")
    if w then return tonumber(w.Value) or 0 end
    local gameData = Workspace:FindFirstChild("_DATA") and Workspace._DATA:FindFirstChild("GameData")
    if gameData and gameData:FindFirstChild("wave") then
        return tonumber(gameData.wave.Value) or 0
    end
    return 0
end

local function GetClientProfileTable()
    if State.CachedProfileData then return State.CachedProfileData end
    if DataServiceClient and type(DataServiceClient.get_data) == "function" then
        local ok, d = pcall(DataServiceClient.get_data)
        if ok and type(d) == "table" then
            State.CachedProfileData = d
            return d
        end
    end
    if typeof(getgc) == "function" then
        pcall(function()
            for _, obj in ipairs(getgc(true)) do
                if type(obj) == "table" then
                    local eq = rawget(obj, "equipped_units")
                    local ow = rawget(obj, "owned_units")
                    if type(eq) == "table" and type(ow) == "table" then
                        State.CachedProfileData = obj
                        break
                    end
                end
            end
        end)
    end
    return State.CachedProfileData
end

local function GetEquippedUnitsDetailed()
    local results = {}
    local seenUUID = {}
    local profile = GetClientProfileTable()

    local function AddUnitEntry(uuid, unitId)
        if type(uuid) == "string" and uuid ~= "" and not seenUUID[uuid] then
            seenUUID[uuid] = true
            local uId = tostring(unitId or "")
            if uId == "" and UnitCollectionServiceClient and type(UnitCollectionServiceClient.get_unit_data) == "function" then
                local ok, uData = pcall(UnitCollectionServiceClient.get_unit_data, uuid)
                if ok and type(uData) == "table" and (uData.unit_id or uData.id) then
                    uId = tostring(uData.unit_id or uData.id)
                end
            end
            if uId == "" and profile and type(profile.owned_units) == "table" then
                local owned = profile.owned_units[uuid]
                if type(owned) == "table" and (owned.unit_id or owned.id) then
                    uId = tostring(owned.unit_id or owned.id)
                end
            end
            local uEntry = LookupUnitDataEntry(uId, uId)
            local displayName = (uEntry and uEntry.name and tostring(uEntry.name)) or uId
            local maxCap = (uEntry and (tonumber(uEntry.spawn_cap) or tonumber(uEntry.max_placed) or tonumber(uEntry.limit))) or 4
            table.insert(results, {
                uuid = uuid,
                unit_id = uId,
                unit_name = displayName,
                max_cap = maxCap,
                placement_type = ClassifyUnitPlacementType(uId, displayName)
            })
        end
    end

    if UnitCollectionServiceClient and type(UnitCollectionServiceClient.get_equipped_units) == "function" then
        local ok, equipped = pcall(UnitCollectionServiceClient.get_equipped_units)
        if ok and type(equipped) == "table" then
            for i = 1, 6 do
                local u = equipped[tostring(i)] or equipped[i]
                if type(u) == "string" then AddUnitEntry(u, nil) end
            end
            for _, u in pairs(equipped) do
                if type(u) == "string" then AddUnitEntry(u, nil) end
            end
        end
    end

    if #results == 0 and profile and type(profile.equipped_units) == "table" then
        local eq = profile.equipped_units
        for i = 1, 6 do
            local u = eq[tostring(i)] or eq[i]
            if type(u) == "string" then AddUnitEntry(u, nil) end
        end
        for _, u in pairs(eq) do
            if type(u) == "string" then AddUnitEntry(u, nil) end
        end
    end

    -- Fallback: อ่านจากยูนิตที่วางไปแล้วในแมพ (กรณี Executor ไม่รองรับ getgc)
    local unitsFolder = Workspace:FindFirstChild("_UNITS")
    if unitsFolder then
        for _, u in ipairs(unitsFolder:GetChildren()) do
            local st = u:FindFirstChild("_stats")
            if st and st:FindFirstChild("player") and st.player.Value == LocalPlayer then
                local stUuid = st:FindFirstChild("uuid") and tostring(st.uuid.Value) or ""
                local stId = st:FindFirstChild("id") and tostring(st.id.Value) or u.Name
                if stUuid ~= "" then
                    AddUnitEntry(stUuid, stId)
                end
            end
        end
    end

    return results
end

-- แปลงชื่อยูนิตจากไฟล์มาโคร (เช่น "bulma", "goku_ssj3_evolved", "Iscanur (Pride)") ให้เป็น UUID ที่สวมใส่จริงในกระเป๋าเรา
local function ResolveEquippedUUIDFromUnitName(macroUnitStr, unitId, unitName)
    local detailed = GetEquippedUnitsDetailed()
    if #detailed == 0 then return nil, nil end

    local candidatesToMatch = {}
    for _, raw in ipairs({ macroUnitStr, unitId, unitName }) do
        local clean = NormalizeUnitIdentifier(raw)
        if clean ~= "" then
            table.insert(candidatesToMatch, clean)
        end
    end

    -- 1. เช็คกรณีตรงกับ UUID หรือตรงกับ unit_id / unit_name แบบ 100%
    for _, targetStr in ipairs(candidatesToMatch) do
        for _, item in ipairs(detailed) do
            local eqUuid = tostring(item.uuid):lower()
            local eqId = NormalizeUnitIdentifier(item.unit_id)
            local eqName = NormalizeUnitIdentifier(item.unit_name)
            if eqUuid == targetStr or (eqId ~= "" and eqId == targetStr) or (eqName ~= "" and eqName == targetStr) then
                return item.uuid, item.unit_id
            end
        end
    end

    -- 2. เช็คกรณีชื่อยูนิตเป็นร่าง Evolved / Skin (เช่น "goku_ssj3_evolved" <-> "goku_ssj3")
    for _, targetStr in ipairs(candidatesToMatch) do
        local strippedTarget = targetStr:gsub("_evolved$", ""):gsub("_evo$", "")
        for _, item in ipairs(detailed) do
            local eqId = NormalizeUnitIdentifier(item.unit_id):gsub("_evolved$", ""):gsub("_evo$", "")
            local eqName = NormalizeUnitIdentifier(item.unit_name)
            if (eqId ~= "" and (eqId == strippedTarget or eqId:find(strippedTarget, 1, true) or strippedTarget:find(eqId, 1, true)))
                or (eqName ~= "" and (eqName:find(strippedTarget, 1, true) or strippedTarget:find(eqName, 1, true))) then
                return item.uuid, item.unit_id
            end
        end
    end

    -- คืนค่า nil เสมอหากไม่ได้ใส่ยูนิตตัวนั้นในทีม เพื่อป้องกันไม่ให้ส่งค่ามั่วไปโดน Error 267
    return nil, nil
end

local function CountMyPlacedUnitsByIdOrUUID(unitId, uuid)
    local unitsFolder = Workspace:FindFirstChild("_UNITS")
    if not unitsFolder then return 0 end
    local count = 0
    local cleanId = NormalizeUnitIdentifier(unitId)

    for _, u in ipairs(unitsFolder:GetChildren()) do
        local st = u:FindFirstChild("_stats")
        if st and st:FindFirstChild("player") and st.player.Value == LocalPlayer then
            local stUuid = st:FindFirstChild("uuid") and tostring(st.uuid.Value) or ""
            local stId = st:FindFirstChild("id") and NormalizeUnitIdentifier(st.id.Value) or NormalizeUnitIdentifier(u.Name)
            if (uuid and stUuid ~= "" and stUuid == tostring(uuid))
                or (cleanId ~= "" and (stId == cleanId or NormalizeUnitIdentifier(u.Name) == cleanId)) then
                count = count + 1
            end
        end
    end
    return count
end

local function SendHttpRequest(reqData)
    local fn = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
    if fn then return fn(reqData) end
    return nil
end

local function GetMacroFileList()
    local files = {}
    if typeof(listfiles) == "function" and typeof(isfolder) == "function" and isfolder(MACRO_FOLDER) then
        for _, file in ipairs(listfiles(MACRO_FOLDER)) do
            if file:sub(-5) == ".json" then
                local filename = file:match("([^/\\]+)%.json$")
                if filename then table.insert(files, filename) end
            end
        end
    end
    table.sort(files)
    if #files == 0 then table.insert(files, "None") end
    return files
end

local function ParseCFrameOrPosition(posStr)
    local parts = {}
    for num in string.gmatch(tostring(posStr or ""), "[-+]?%d*%.?%d+[eE]?[-+]?%d*") do
        local n = tonumber(num)
        if n then table.insert(parts, n) end
    end
    if #parts >= 12 then
        return CFrame.new(
            parts[1], parts[2], parts[3],
            parts[4], parts[5], parts[6],
            parts[7], parts[8], parts[9],
            parts[10], parts[11], parts[12]
        ), Vector3.new(parts[1], parts[2], parts[3])
    elseif #parts >= 3 then
        local v = Vector3.new(parts[1], parts[2], parts[3])
        return BuildPlacementCFrame(v), v
    end
    return CFrame.new(), Vector3.zero
end

local function FireGuiButton(btn)
    if not btn then return false end
    if typeof(firesignal) == "function" then
        local ok = pcall(function()
            firesignal(btn.Activated)
        end)
        return ok
    end
    if typeof(getconnections) == "function" then
        local ok, activatedConnections = pcall(getconnections, btn.Activated)
        if ok and type(activatedConnections) == "table" and #activatedConnections > 0 then
            local fired = false
            for _, conn in ipairs(activatedConnections) do
                if conn and type(conn.Fire) == "function" then
                    local connOk = pcall(function() conn:Fire() end)
                    fired = fired or connOk
                end
            end
            return fired
        end
    end
    return false
end

local function SafeUpdateParagraph(para, title, desc)
    if not para then return end
    if title then
        pcall(function() para:SetTitle(title) end)
    end
    if desc then
        local ok = pcall(function() para:SetDesc(desc) end)
        if not ok then
            pcall(function() para:SetValue(desc) end)
        end
    end
end

---------------------------------------------------------------------
-- 3. 4-STAGE UNIVERSAL ROAD & HILL ENGINE (Safe & Undetected)
---------------------------------------------------------------------
local function ExtractObjectPos(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj.Position end
    if obj:IsA("Model") then
        local ok, cf = pcall(obj.GetPivot, obj)
        if ok and cf then return cf.Position end
        local bp = obj:FindFirstChildWhichIsA("BasePart", true)
        if bp then return bp.Position end
    end
    local bp = obj:FindFirstChildWhichIsA("BasePart", true)
    if bp then return bp.Position end
    return nil
end

local function FindBaseAnchorPosition()
    local bases = Workspace:FindFirstChild("_BASES") or Workspace:FindFirstChild("Bases")
    if bases then
        for _, b in ipairs(bases:GetChildren()) do
            local n = b.Name:lower()
            local p = ExtractObjectPos(b)
            if p and (n:find("base") or n:find("player") or n:find("home") or n:find("pve")) then
                return p
            end
        end
        for _, desc in ipairs(bases:GetDescendants()) do
            if desc:IsA("BasePart") then
                return desc.Position
            end
        end
    end
    return nil
end

local function GetPlayerReferencePos()
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if hrp then return hrp.Position end
    local spawnLoc = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
    if spawnLoc then return spawnLoc.Position end
    return nil
end

-- สแกนพาร์ททั้งหมดใน workspace._terrain.hill (ไม่แก้ไข Property CanQuery ของแมพเพื่อกัน Anti-Cheat)
local function ScanTerrainHillParts()
    local terrainFolder = Workspace:FindFirstChild("_terrain") or Workspace:FindFirstChild("terrain")
    local hillFolder = terrainFolder and (terrainFolder:FindFirstChild("hill") or terrainFolder:FindFirstChild("Hill"))

    local hillParts = {}
    local hillGeoms = {}

    if hillFolder then
        for _, inst in ipairs(hillFolder:GetDescendants()) do
            if inst:IsA("BasePart") then
                local cf = inst.CFrame
                local sz = inst.Size
                local worldHalfY = (math.abs(cf.RightVector.Y * sz.X) + math.abs(cf.UpVector.Y * sz.Y) + math.abs(cf.LookVector.Y * sz.Z)) * 0.5
                local topY = inst.Position.Y + worldHalfY

                table.insert(hillParts, inst)
                table.insert(hillGeoms, {
                    part = inst,
                    cf = cf,
                    size = sz,
                    topY = topY,
                    center = Vector3.new(inst.Position.X, topY, inst.Position.Z)
                })
            end
        end
    end

    State.HillPartInstances = hillParts
    State.HillGeometries = hillGeoms
    hillOnlyRayParams.FilterDescendantsInstances = hillParts
end

local function GetSurfacePointOnTerrainHill(worldX, worldZ)
    if #State.HillGeometries == 0 then
        return nil
    end

    local bestY = -math.huge
    local matchedGeom = nil

    for _, g in ipairs(State.HillGeometries) do
        if g.part and g.part.Parent then
            local localPt = g.cf:PointToObjectSpace(Vector3.new(worldX, g.part.Position.Y, worldZ))
            local margin = 0.65
            if math.abs(localPt.X) <= (g.size.X * 0.5 - margin) and math.abs(localPt.Z) <= (g.size.Z * 0.5 - margin) then
                if g.topY > bestY then
                    bestY = g.topY
                    matchedGeom = g
                end
            end
        end
    end

    if not matchedGeom then
        return nil
    end

    local rayRes = Workspace:Raycast(
        Vector3.new(worldX, bestY + 15, worldZ),
        Vector3.new(0, -35, 0),
        hillOnlyRayParams
    )
    if rayRes and rayRes.Instance and rayRes.Position and rayRes.Normal.Y >= 0.75 then
        return rayRes.Position, rayRes.Instance
    end

    return Vector3.new(worldX, bestY, worldZ), matchedGeom.part
end

local function FindClosestPointOnTerrainHill(roadPos)
    if #State.HillGeometries == 0 then
        ScanTerrainHillParts()
    end
    if #State.HillGeometries == 0 then
        return nil, nil
    end

    local bestWorldPos = nil
    local bestHillGeom = nil
    local minFlatDist = math.huge

    for _, g in ipairs(State.HillGeometries) do
        if g.part and g.part.Parent then
            local localPt = g.cf:PointToObjectSpace(roadPos)
            local padX = math.min(1.2, g.size.X * 0.25)
            local padZ = math.min(1.2, g.size.Z * 0.25)

            local clampedX = math.clamp(localPt.X, -(g.size.X * 0.5) + padX, (g.size.X * 0.5) - padX)
            local clampedZ = math.clamp(localPt.Z, -(g.size.Z * 0.5) + padZ, (g.size.Z * 0.5) - padZ)
            local worldCandidate = g.cf:PointToWorldSpace(Vector3.new(clampedX, 0, clampedZ))

            local flatDist = Vector3.new(worldCandidate.X - roadPos.X, 0, worldCandidate.Z - roadPos.Z).Magnitude
            if flatDist < minFlatDist then
                minFlatDist = flatDist
                local exactSurface = GetSurfacePointOnTerrainHill(worldCandidate.X, worldCandidate.Z)
                bestWorldPos = exactSurface or Vector3.new(worldCandidate.X, g.topY, worldCandidate.Z)
                bestHillGeom = g
            end
        end
    end

    return bestWorldPos, bestHillGeom
end

local function AnalyzeRoadPartGeometry(part)
    local cf = part.CFrame
    local sz = part.Size

    local axes = {
        Vector3.new(cf.RightVector.X * sz.X, 0, cf.RightVector.Z * sz.X),
        Vector3.new(cf.UpVector.X * sz.Y, 0, cf.UpVector.Z * sz.Y),
        Vector3.new(cf.LookVector.X * sz.Z, 0, cf.LookVector.Z * sz.Z)
    }
    table.sort(axes, function(a, b)
        return a.Magnitude > b.Magnitude
    end)

    local longVec = axes[1]
    local wideVec = axes[2]
    local lengthH = longVec.Magnitude
    local widthH = wideVec.Magnitude

    local flatDir = lengthH > 0.05 and longVec.Unit or Vector3.new(0, 0, 1)
    local isSquareNode = (lengthH <= widthH * 1.35) and (lengthH <= 8.0)
    local halfSpan = isSquareNode and 0 or math.max(0.25, (lengthH * 0.5) - (widthH * 0.22))

    RefreshRayFilter(true)
    local hitPos, hitInst = SafeRaycastGround(part.Position, 12, -30)
    local surfaceY = part.Position.Y
    if hitInst and math.abs(hitPos.Y - part.Position.Y) <= 8 then
        surfaceY = hitPos.Y
    else
        local worldHalfY = (math.abs(cf.RightVector.Y * sz.X) + math.abs(cf.UpVector.Y * sz.Y) + math.abs(cf.LookVector.Y * sz.Z)) * 0.5
        surfaceY = part.Position.Y + math.min(worldHalfY, 1.5)
    end

    local centerPos = Vector3.new(part.Position.X, surfaceY, part.Position.Z)
    local ptA = centerPos - (flatDir * halfSpan)
    local ptB = centerPos + (flatDir * halfSpan)

    return {
        part = part,
        a = ptA,
        b = ptB,
        center = centerPos,
        length = halfSpan * 2,
        rawLength = lengthH,
        width = math.clamp(widthH, 2.0, 14.0),
        surfaceY = surfaceY,
        isSquareNode = isSquareNode,
        numIndex = tonumber(part.Name)
    }
end

local function FlatDist2D(v1, v2)
    return Vector3.new(v1.X - v2.X, 0, v1.Z - v2.Z).Magnitude
end

local function PointToSegmentDist2D(p, a, b)
    local pFlat = Vector3.new(p.X, 0, p.Z)
    local aFlat = Vector3.new(a.X, 0, a.Z)
    local bFlat = Vector3.new(b.X, 0, b.Z)
    local ab = bFlat - aFlat
    local lenSq = ab.Magnitude * ab.Magnitude
    if lenSq < 0.001 then
        return (pFlat - aFlat).Magnitude
    end
    local t = math.clamp((pFlat - aFlat):Dot(ab) / lenSq, 0, 1)
    local proj = aFlat + (ab * t)
    return (pFlat - proj).Magnitude
end

local function SegmentToSegmentMinDist2D(s1, s2)
    return math.min(
        PointToSegmentDist2D(s1.a, s2.a, s2.b),
        PointToSegmentDist2D(s1.b, s2.a, s2.b),
        PointToSegmentDist2D(s2.a, s1.a, s1.b),
        PointToSegmentDist2D(s2.b, s1.a, s1.b)
    )
end

local function CompileCandidateChain(nodes, partsList, label, isNumberedSource)
    if #nodes < 2 then return nil end

    local cleanNodes = { nodes[1] }
    for i = 2, #nodes do
        if FlatDist2D(nodes[i], cleanNodes[#cleanNodes]) > 0.65 then
            table.insert(cleanNodes, nodes[i])
        end
    end
    if #cleanNodes < 2 then return nil end

    local baseAnchor = FindBaseAnchorPosition()
    if baseAnchor then
        local dStart = FlatDist2D(cleanNodes[1], baseAnchor)
        local dEnd = FlatDist2D(cleanNodes[#cleanNodes], baseAnchor)
        if dEnd + 2.0 < dStart then
            local reversed = {}
            for i = #cleanNodes, 1, -1 do
                table.insert(reversed, cleanNodes[i])
            end
            cleanNodes = reversed
        end
    end

    local compiledSegs = {}
    local totalLen = 0
    local yList = {}
    local widthSum = 0

    for _, pInfo in ipairs(partsList) do
        table.insert(yList, pInfo.surfaceY)
        widthSum = widthSum + pInfo.width
    end
    table.sort(yList)
    local medianY = (#yList > 0 and yList[math.ceil(#yList * 0.5)]) or cleanNodes[1].Y
    local avgHalfWidth = (#partsList > 0 and math.clamp((widthSum / #partsList) * 0.5, 1.8, 6.0)) or 2.5

    for i = 1, #cleanNodes - 1 do
        local p1 = Vector3.new(cleanNodes[i].X, medianY, cleanNodes[i].Z)
        local p2 = Vector3.new(cleanNodes[i + 1].X, medianY, cleanNodes[i + 1].Z)
        local flat = Vector3.new(p2.X - p1.X, 0, p2.Z - p1.Z)
        local len = flat.Magnitude
        if len > 0.1 then
            local unitDir = flat.Unit
            table.insert(compiledSegs, {
                a = p1,
                b = p2,
                dir = unitDir,
                right = Vector3.new(-unitDir.Z, 0, unitDir.X),
                len = len,
                startDist = totalLen
            })
            totalLen = totalLen + len
        end
    end

    if #compiledSegs == 0 or totalLen < 12 then
        return nil
    end

    local score = 0
    local playerPos = GetPlayerReferencePos()

    local minBaseDist = math.huge
    if baseAnchor then
        minBaseDist = math.min(
            FlatDist2D(compiledSegs[1].a, baseAnchor),
            FlatDist2D(compiledSegs[#compiledSegs].b, baseAnchor)
        )
        for _, s in ipairs(compiledSegs) do
            minBaseDist = math.min(minBaseDist, PointToSegmentDist2D(baseAnchor, s.a, s.b))
        end
        if minBaseDist <= 30 then
            score = score + 1200 - (minBaseDist * 15)
        elseif minBaseDist <= 85 then
            score = score + 600 - (minBaseDist * 5)
        else
            score = score - (minBaseDist * 6)
        end
    end

    if #State.HillGeometries > 0 then
        local minHillDist = math.huge
        for _, h in ipairs(State.HillGeometries) do
            for _, s in ipairs(compiledSegs) do
                local d = PointToSegmentDist2D(h.center, s.a, s.b)
                if d < minHillDist then minHillDist = d end
            end
        end
        if minHillDist <= 45 then
            score = score + 850 - (minHillDist * 10)
        elseif minHillDist <= 100 then
            score = score + 300
        else
            score = score - (minHillDist * 4)
        end
    end

    if playerPos then
        local minPlayerDist = math.huge
        for _, s in ipairs(compiledSegs) do
            local d = PointToSegmentDist2D(playerPos, s.a, s.b)
            if d < minPlayerDist then minPlayerDist = d end
        end
        if minPlayerDist <= 120 then
            score = score + 400 - (minPlayerDist * 2)
        else
            score = score - (minPlayerDist * 3)
        end
    end

    if isNumberedSource then
        score = score + 650
    end
    score = score + math.min(totalLen * 2.2, 700)
    score = score + math.min(#partsList * 35, 350)

    local rawPartInstances = {}
    for _, pInfo in ipairs(partsList) do
        if pInfo.part then
            table.insert(rawPartInstances, pInfo.part)
        end
    end

    return {
        label = label,
        nodes = cleanNodes,
        segments = compiledSegs,
        totalLength = totalLen,
        baseY = medianY,
        halfWidth = avgHalfWidth,
        partInstances = rawPartInstances,
        score = score
    }
end

local function BuildNumberedCandidateFromParts(numberedSegs, label)
    table.sort(numberedSegs, function(x, y)
        return (x.numIndex or 0) < (y.numIndex or 0)
    end)

    local chainNodes = {}
    for i, seg in ipairs(numberedSegs) do
        if seg.isSquareNode or FlatDist2D(seg.a, seg.b) < 1.2 then
            table.insert(chainNodes, seg.center)
        else
            if i == 1 then
                local nextSeg = numberedSegs[2]
                if nextSeg then
                    local dA = math.min(FlatDist2D(seg.a, nextSeg.a), FlatDist2D(seg.a, nextSeg.b), FlatDist2D(seg.a, nextSeg.center))
                    local dB = math.min(FlatDist2D(seg.b, nextSeg.a), FlatDist2D(seg.b, nextSeg.b), FlatDist2D(seg.b, nextSeg.center))
                    if dB <= dA then
                        table.insert(chainNodes, seg.a)
                        table.insert(chainNodes, seg.b)
                    else
                        table.insert(chainNodes, seg.b)
                        table.insert(chainNodes, seg.a)
                    end
                else
                    table.insert(chainNodes, seg.a)
                    table.insert(chainNodes, seg.b)
                end
            else
                local prevTip = chainNodes[#chainNodes]
                local dA = FlatDist2D(prevTip, seg.a)
                local dB = FlatDist2D(prevTip, seg.b)
                local entryPt = (dA <= dB) and seg.a or seg.b
                local exitPt = (dA <= dB) and seg.b or seg.a
                if FlatDist2D(prevTip, entryPt) > 1.5 then
                    table.insert(chainNodes, entryPt)
                end
                table.insert(chainNodes, exitPt)
            end
        end
    end

    return CompileCandidateChain(chainNodes, numberedSegs, label, true)
end

local function BuildUnnumberedClusterChain(clusterSegs, label)
    if #clusterSegs == 0 then return nil end
    if #clusterSegs == 1 then
        local s = clusterSegs[1]
        return CompileCandidateChain({ s.a, s.b }, clusterSegs, label, false)
    end

    local startSegIdx = 1
    local startAtA = true
    local baseAnchor = FindBaseAnchorPosition()

    if baseAnchor then
        local minD = math.huge
        for i, s in ipairs(clusterSegs) do
            local dA = FlatDist2D(s.a, baseAnchor)
            local dB = FlatDist2D(s.b, baseAnchor)
            if dA < minD then minD = dA; startSegIdx = i; startAtA = true end
            if dB < minD then minD = dB; startSegIdx = i; startAtA = false end
        end
    else
        local maxNearestDist = -1
        for i, s1 in ipairs(clusterSegs) do
            for _, isEndA in ipairs({ true, false }) do
                local testPt = isEndA and s1.a or s1.b
                local nearestOther = math.huge
                for j, s2 in ipairs(clusterSegs) do
                    if i ~= j then
                        local d = math.min(FlatDist2D(testPt, s2.a), FlatDist2D(testPt, s2.b))
                        if d < nearestOther then nearestOther = d end
                    end
                end
                if nearestOther > maxNearestDist then
                    maxNearestDist = nearestOther
                    startSegIdx = i
                    startAtA = isEndA
                end
            end
        end
    end

    local used = { [startSegIdx] = true }
    local firstSeg = clusterSegs[startSegIdx]
    local chainNodes = startAtA and { firstSeg.a, firstSeg.b } or { firstSeg.b, firstSeg.a }
    local orderedParts = { firstSeg }

    for _ = 1, #clusterSegs - 1 do
        local currentTip = chainNodes[#chainNodes]
        local bestNextIdx = nil
        local connectAtA = true
        local minGap = math.huge

        for i, cand in ipairs(clusterSegs) do
            if not used[i] then
                local dA = FlatDist2D(cand.a, currentTip)
                local dB = FlatDist2D(cand.b, currentTip)
                if dA < minGap then
                    minGap = dA
                    bestNextIdx = i
                    connectAtA = true
                end
                if dB < minGap then
                    minGap = dB
                    bestNextIdx = i
                    connectAtA = false
                end
            end
        end

        if bestNextIdx and minGap <= 45 then
            used[bestNextIdx] = true
            local nextSeg = clusterSegs[bestNextIdx]
            table.insert(orderedParts, nextSeg)
            local entryPt = connectAtA and nextSeg.a or nextSeg.b
            local exitPt = connectAtA and nextSeg.b or nextSeg.a
            if FlatDist2D(entryPt, currentTip) > 1.2 then
                table.insert(chainNodes, entryPt)
            end
            table.insert(chainNodes, exitPt)
        else
            break
        end
    end

    return CompileCandidateChain(chainNodes, orderedParts, label, false)
end

local function ApplyCandidateChainToState(cand, isEnemyVerified)
    if not cand then return end
    State.ActiveRoadLabel = cand.label
    State.EnemyVerifiedRoad = isEnemyVerified or false
    State.MainRoadNodes = cand.nodes
    State.MainRoadSegments = cand.segments
    State.MainRoadTotalLength = cand.totalLength
    State.MainRoadBaseY = cand.baseY
    State.MainRoadHalfWidth = cand.halfWidth
    State.MainPartInstances = cand.partInstances
end

local function BuildMainRoadPathFromWorkspace()
    RefreshRayFilter(true)
    ScanTerrainHillParts()

    State.CandidateRoadChains = {}
    State.EnemyVerifiedRoad = false

    local roadRoot = Workspace:FindFirstChild("_road") or Workspace:FindFirstChild("road")
    if roadRoot then
        local containersToCheck = { roadRoot }
        for _, child in ipairs(roadRoot:GetDescendants()) do
            if child:IsA("Folder") or child:IsA("Model") then
                local cName = child.Name:lower()
                if not cName:find("air") and not cName:find("fly") then
                    table.insert(containersToCheck, child)
                end
            end
        end

        for _, container in ipairs(containersToCheck) do
            local numberedParts = {}
            for _, ch in ipairs(container:GetChildren()) do
                if ch:IsA("BasePart") and tonumber(ch.Name) ~= nil then
                    table.insert(numberedParts, AnalyzeRoadPartGeometry(ch))
                end
            end
            if #numberedParts >= 2 then
                local cLabel = (container == roadRoot) and "_road[1..N]" or ("_road." .. container.Name .. "[1..N]")
                local cand = BuildNumberedCandidateFromParts(numberedParts, cLabel)
                if cand then
                    table.insert(State.CandidateRoadChains, cand)
                end
            end
        end

        local allValidSegs = {}
        for _, inst in ipairs(roadRoot:GetDescendants()) do
            if inst:IsA("BasePart") then
                local parentName = inst.Parent and inst.Parent.Name:lower() or ""
                if not parentName:find("air") and not parentName:find("fly") and inst.Size.Magnitude >= 1.5 then
                    table.insert(allValidSegs, AnalyzeRoadPartGeometry(inst))
                end
            end
        end

        local visited = {}
        local clusterCount = 0
        for i = 1, #allValidSegs do
            if not visited[i] then
                clusterCount = clusterCount + 1
                local cluster = {}
                local queue = { i }
                visited[i] = true

                while #queue > 0 do
                    local currIdx = table.remove(queue, 1)
                    local currSeg = allValidSegs[currIdx]
                    table.insert(cluster, currSeg)

                    for j = 1, #allValidSegs do
                        if not visited[j] then
                            local otherSeg = allValidSegs[j]
                            local heightDiff = math.abs(currSeg.surfaceY - otherSeg.surfaceY)
                            local dist2D = SegmentToSegmentMinDist2D(currSeg, otherSeg)
                            if heightDiff <= 7.5 and dist2D <= 26.0 then
                                visited[j] = true
                                table.insert(queue, j)
                            end
                        end
                    end
                end

                local firstPartParent = cluster[1].part and cluster[1].part.Parent
                local parentTag = (firstPartParent and firstPartParent ~= roadRoot) and ("_road." .. firstPartParent.Name) or "_road"
                local cand = BuildUnnumberedClusterChain(cluster, string.format("%s (Cluster #%d)", parentTag, clusterCount))
                if cand then
                    table.insert(State.CandidateRoadChains, cand)
                end
            end
        end
    end

    table.sort(State.CandidateRoadChains, function(a, b)
        return a.score > b.score
    end)

    if #State.CandidateRoadChains > 0 then
        ApplyCandidateChainToState(State.CandidateRoadChains[1], false)
    else
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local p0 = hrp and SafeRaycastGround(hrp.Position, 8, -25) or Vector3.new(0, 5, 0)
        local fallbackNodes = {
            p0 + Vector3.new(-45, 0, 0),
            p0 + Vector3.new(-15, 0, 0),
            p0 + Vector3.new(15, 0, 0),
            p0 + Vector3.new(45, 0, 0)
        }
        local fbCand = CompileCandidateChain(fallbackNodes, {}, "Lobby Preview", false)
        if fbCand then
            ApplyCandidateChainToState(fbCand, false)
        end
    end
end

local function VerifyAndLockRoadWithEnemies()
    if #State.CandidateRoadChains <= 1 then return false end
    local enemiesFolder = Workspace:FindFirstChild("_ENEMIES") or Workspace:FindFirstChild("Enemies")
    if not enemiesFolder then return false end

    local enemyPositions = {}
    for _, enemy in ipairs(enemiesFolder:GetChildren()) do
        local pos = ExtractObjectPos(enemy)
        if pos then
            table.insert(enemyPositions, pos)
        end
    end
    if #enemyPositions == 0 then return false end

    local bestChain = nil
    local bestHits = 0
    local bestAvgDist = math.huge

    for _, cand in ipairs(State.CandidateRoadChains) do
        local hits = 0
        local distSum = 0
        for _, ePos in ipairs(enemyPositions) do
            local minD = math.huge
            for _, s in ipairs(cand.segments) do
                local d = PointToSegmentDist2D(ePos, s.a, s.b)
                if d < minD then minD = d end
            end
            if minD <= 12.0 then
                hits = hits + 1
                distSum = distSum + minD
            end
        end
        if hits > bestHits or (hits == bestHits and hits > 0 and (distSum / hits) < bestAvgDist) then
            bestHits = hits
            bestAvgDist = distSum / hits
            bestChain = cand
        end
    end

    if bestChain and bestHits > 0 then
        local changed = (State.ActiveRoadLabel ~= bestChain.label) or (not State.EnemyVerifiedRoad)
        ApplyCandidateChainToState(bestChain, true)
        return changed
    end
    return false
end

local function EvaluateMainRoadAtPercent(percent01)
    percent01 = math.clamp(tonumber(percent01) or 0.5, 0, 1)
    local segs = State.MainRoadSegments
    local totalLen = State.MainRoadTotalLength

    if #segs == 0 or totalLen <= 0.05 then
        local fallbackPt = State.MainRoadNodes[1] or Vector3.new(0, State.MainRoadBaseY, 0)
        return fallbackPt, Vector3.new(0, 0, 1), Vector3.new(1, 0, 0)
    end

    local targetDist = totalLen * percent01
    for _, s in ipairs(segs) do
        if targetDist >= s.startDist and targetDist <= (s.startDist + s.len) then
            local alpha = (targetDist - s.startDist) / math.max(s.len, 0.001)
            return s.a:Lerp(s.b, alpha), s.dir, s.right
        end
    end

    local last = segs[#segs]
    return last.b, last.dir, last.right
end

local function IsPointOverlappingMainRoad(pos, customBuffer)
    local clearance = customBuffer or (State.MainRoadHalfWidth + 2.15)
    local pFlat = Vector3.new(pos.X, 0, pos.Z)
    for _, s in ipairs(State.MainRoadSegments) do
        local aFlat = Vector3.new(s.a.X, 0, s.a.Z)
        local bFlat = Vector3.new(s.b.X, 0, s.b.Z)
        local ab = bFlat - aFlat
        local denom = s.len * s.len
        local t = denom > 0.001 and math.clamp((pFlat - aFlat):Dot(ab) / denom, 0, 1) or 0
        local closest = aFlat + (ab * t)
        if (pFlat - closest).Magnitude < clearance then
            return true
        end
    end
    return false
end

pcall(BuildMainRoadPathFromWorkspace)

---------------------------------------------------------------------
-- 4. FLUENT WINDOW & AUTO-SAVE HELPER
---------------------------------------------------------------------
local Window = Fluent:CreateWindow({
    Title = "TD Script Architect",
    SubTitle = "User: " .. USER_CONFIG_NAME,
    TabWidth = 160,
    Size = UDim2.fromOffset(620, 500),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl
})

local Tabs = {
    AutoJoin     = Window:AddTab({ Title = "Auto Join", Icon = "door-open" }),
    Macro        = Window:AddTab({ Title = "Macro", Icon = "play-circle" }),
    AI           = Window:AddTab({ Title = "AI - System", Icon = "cpu" }),
    Game         = Window:AddTab({ Title = "Game", Icon = "gamepad-2" }),
    Notification = Window:AddTab({ Title = "Notification", Icon = "bell" }),
    Settings     = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

local Options = Fluent.Options

local saveDebounce = false
local function AutoSaveUserConfig()
    if State.IsBootingConfig or saveDebounce then return end
    saveDebounce = true
    task.delay(0.4, function()
        pcall(function()
            SaveManager:Save(USER_CONFIG_NAME)
        end)
        saveDebounce = false
    end)
end

---------------------------------------------------------------------
-- 5. MACRO NORMALIZER (d.json & Raid Format) + GROUND MARKERS
---------------------------------------------------------------------
local MacroMarkerPool = {
    Folder = nil,
    Items = {}
}

local function CreateMarkerPart(parent, name)
    local p = Instance.new("Part")
    p.Name = name
    p.Anchored = true
    p.CanCollide = false
    p.CanTouch = false
    pcall(function() p.CanQuery = false end)
    p.CastShadow = false
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end

local function HideMacroMarkers()
    if MacroMarkerPool.Folder then
        pcall(function() MacroMarkerPool.Folder:Destroy() end)
        MacroMarkerPool.Folder = nil
        State.MacroMarkerFolder = nil
        MacroMarkerPool.Items = {}
    end
end

local function FindMyUnitNearPosition(targetPos, maxDist)
    local unitsFolder = Workspace:FindFirstChild("_UNITS")
    if not unitsFolder then return nil end
    local closest, minD = nil, maxDist or 6
    for _, u in ipairs(unitsFolder:GetChildren()) do
        local stats = u:FindFirstChild("_stats")
        if stats and stats:FindFirstChild("player") and stats.player.Value == LocalPlayer then
            local rp = u.PrimaryPart or u:FindFirstChild("HumanoidRootPart") or u:FindFirstChildWhichIsA("BasePart", true)
            if rp then
                local d = Vector3.new(rp.Position.X - targetPos.X, 0, rp.Position.Z - targetPos.Z).Magnitude
                if d < minD then
                    minD = d
                    closest = u
                end
            end
        end
    end
    return closest
end

-- แปลงข้อมูลจากทั้ง d.json และ raid map 2.json ให้มีข้อมูลครบถ้วนสำหรับทั้งการเล่นและการแสดงจุดสี
local function NormalizeMacroActions(rawActions)
    if type(rawActions) ~= "table" then return {} end

    local minSpawnY = math.huge
    local rawCoords = {}
    for i, act in ipairs(rawActions) do
        if type(act) == "table" and act.Method == "SpawnTower" and act.Position then
            local _, vec = ParseCFrameOrPosition(act.Position)
            rawCoords[i] = vec
            if vec.Y < minSpawnY then minSpawnY = vec.Y end
        end
    end
    if minSpawnY == math.huge then minSpawnY = 0 end

    local unitMetaByValue = {}
    local upgradeCounterByValue = {}
    for i, act in ipairs(rawActions) do
        if type(act) == "table" then
            act.Index = tonumber(act.Index) or i
            act.Wave = tonumber(act.Wave) or 0
            act.Time = tonumber(act.Time) or 0
            local uVal = tonumber(act.UnitValue) or act.UnitValue or i

            if act.Method == "SpawnTower" then
                local rawUnitStr = tostring(act.Unit or act.UnitId or act.UnitName or "Unit")
                local vec = rawCoords[i] or Vector3.zero
                local pType = act.PlacementType or ClassifyUnitPlacementType(rawUnitStr, rawUnitStr)
                if pType == "Ground" and (vec.Y - minSpawnY) >= 2.4 then pType = "Hill" end
                local baseCost = tonumber(act.Cost) or LookupUnitCostByIdOrName(rawUnitStr, rawUnitStr, 0) or 500

                act.Unit = rawUnitStr
                act.UnitId = act.UnitId or rawUnitStr
                act.UnitName = act.UnitName or rawUnitStr
                act.PlacementType = pType
                act.Cost = baseCost

                unitMetaByValue[uVal] = {
                    unitId = act.UnitId,
                    unitName = act.UnitName,
                    placementType = pType,
                    spawnPos = vec
                }
                upgradeCounterByValue[uVal] = 0

            elseif act.Method == "UpgradeTower" then
                local curCount = (upgradeCounterByValue[uVal] or 0) + 1
                upgradeCounterByValue[uVal] = curCount
                local meta = unitMetaByValue[uVal]
                if meta then
                    act.Unit = act.Unit or meta.unitId
                    act.UnitId = act.UnitId or meta.unitId
                    act.UnitName = act.UnitName or meta.unitName
                end
                act.TargetLevel = tonumber(act.TargetLevel) or curCount
                if not act.Cost or (tonumber(act.Cost) or 0) <= 0 then
                    act.Cost = LookupUnitCostByIdOrName(act.UnitId, act.UnitName, act.TargetLevel) or 500
                end

            elseif act.Method == "Use Ability" or act.Method == "UseAbility" then
                local meta = unitMetaByValue[uVal]
                if meta then
                    act.Unit = act.Unit or meta.unitId
                    act.UnitName = act.UnitName or meta.unitName
                end
            end
        end
    end
    return rawActions
end

local function LoadPreviewMacroActions()
    if State.IsRecording and #State.RecordedActions > 0 then
        return NormalizeMacroActions(State.RecordedActions)
    end
    if State.ActiveMacroData then
        return NormalizeMacroActions(State.ActiveMacroData.Marco_Data or State.ActiveMacroData.Macro_Data)
    end
    local sel = Options.SelectMacroFile and Options.SelectMacroFile.Value
    if sel and sel ~= "None" then
        if State.PreviewMacroFileName ~= sel or not State.PreviewMacroData then
            local path = MACRO_FOLDER .. "/" .. sel .. ".json"
            if typeof(isfile) == "function" and isfile(path) then
                pcall(function()
                    local decoded = HttpService:JSONDecode(readfile(path))
                    local list = decoded and (decoded.Marco_Data or decoded.Macro_Data)
                    if list then NormalizeMacroActions(list) end
                    State.PreviewMacroData = decoded
                    State.PreviewMacroFileName = sel
                end)
            end
        end
        if State.PreviewMacroData then
            return NormalizeMacroActions(State.PreviewMacroData.Marco_Data or State.PreviewMacroData.Macro_Data)
        end
    end
    return nil
end

local function UpdateMacroGroundMarkers()
    local showMarkers = (Options.ShowMacroPlacementMarkers and Options.ShowMacroPlacementMarkers.Value)
        or (Options.ShowMacroPlacementMarkersAI and Options.ShowMacroPlacementMarkersAI.Value)

    if not showMarkers then
        HideMacroMarkers()
        return
    end

    local actions = LoadPreviewMacroActions()
    if not actions or #actions == 0 then
        HideMacroMarkers()
        return
    end

    if not MacroMarkerPool.Folder or not MacroMarkerPool.Folder.Parent then
        local existing = Workspace:FindFirstChild("_TD_MacroMarkers")
        if existing then pcall(function() existing:Destroy() end) end
        local folder = Instance.new("Folder")
        folder.Name = "_TD_MacroMarkers"
        folder.Parent = Workspace
        MacroMarkerPool.Folder = folder
        State.MacroMarkerFolder = folder
        MacroMarkerPool.Items = {}
    end

    local spawnEntries = {}
    local seenUnitTag = {}
    local nextSpawnActionIdx = nil

    for actionIdx, act in ipairs(actions) do
        if act.Method == "SpawnTower" and act.Position then
            if not nextSpawnActionIdx and (Options.PlayBackMacro and Options.PlayBackMacro.Value) and actionIdx >= (State.MacroIndex or 1) then
                nextSpawnActionIdx = actionIdx
            end
            local uTag = tostring(act.UnitValue or (#spawnEntries + 1))
            if not seenUnitTag[uTag] then
                seenUnitTag[uTag] = true
                local _, rawVec = ParseCFrameOrPosition(act.Position)
                local rawUnitName = tostring(act.Unit or act.UnitName or act.UnitId or "Unit")
                local pType = tostring(act.PlacementType or ClassifyUnitPlacementType(rawUnitName, rawUnitName))
                local cost = tonumber(act.Cost) or LookupUnitCostByIdOrName(rawUnitName, rawUnitName, 0) or 500
                table.insert(spawnEntries, {
                    actionIdx = actionIdx,
                    unitTag = uTag,
                    unitName = rawUnitName,
                    cost = cost,
                    pos = rawVec,
                    placementType = pType
                })
            end
        end
    end

    local rotAngle = (os.clock() * 90) % 360

    for i, entry in ipairs(spawnEntries) do
        local item = MacroMarkerPool.Items[i]
        if not item or not item.OuterRing.Parent then
            local outer = CreateMarkerPart(MacroMarkerPool.Folder, "MacroOuter_" .. i)
            outer.Shape = Enum.PartType.Cylinder
            outer.Material = Enum.Material.Neon
            outer.Size = Vector3.new(0.08, 1.35, 1.35)

            local innerDisk = CreateMarkerPart(MacroMarkerPool.Folder, "MacroInner_" .. i)
            innerDisk.Shape = Enum.PartType.Cylinder
            innerDisk.Material = Enum.Material.SmoothPlastic
            innerDisk.Color = Color3.fromRGB(20, 22, 30)
            innerDisk.Transparency = 0.15
            innerDisk.Size = Vector3.new(0.10, 0.95, 0.95)

            local diamond = CreateMarkerPart(MacroMarkerPool.Folder, "MacroDiamond_" .. i)
            diamond.Material = Enum.Material.Neon
            diamond.Size = Vector3.new(0.28, 0.28, 0.28)

            local corePin = CreateMarkerPart(MacroMarkerPool.Folder, "MacroPin_" .. i)
            corePin.Shape = Enum.PartType.Cylinder
            corePin.Material = Enum.Material.Neon
            corePin.Size = Vector3.new(0.48, 0.10, 0.10)

            local bgui = Instance.new("BillboardGui")
            bgui.Name = "MacroTagGui"
            bgui.Size = UDim2.fromOffset(145, 27)
            bgui.StudsOffset = Vector3.new(0, 1.45, 0)
            bgui.AlwaysOnTop = true
            bgui.MaxDistance = 140
            bgui.Parent = diamond

            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.fromScale(1, 1)
            lbl.BackgroundTransparency = 0.35
            lbl.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
            lbl.BorderSizePixel = 0
            lbl.TextStrokeTransparency = 0.1
            lbl.Font = Enum.Font.GothamBold
            lbl.TextSize = 9
            lbl.Parent = bgui

            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 5)
            corner.Parent = lbl

            item = {
                OuterRing = outer,
                InnerDisk = innerDisk,
                Diamond = diamond,
                CorePin = corePin,
                Label = lbl
            }
            MacroMarkerPool.Items[i] = item
        end

        local isPlaced = FindMyUnitNearPosition(entry.pos, 2.2) ~= nil
        local isNext = (nextSpawnActionIdx == entry.actionIdx) and not isPlaced

        local markerColor
        local statusPrefix
        if isPlaced then
            markerColor = Color3.fromRGB(45, 255, 115)
            statusPrefix = "✅"
        elseif isNext then
            markerColor = Color3.fromRGB(195, 80, 255)
            statusPrefix = "⏭️ NEXT"
        else
            markerColor = Color3.fromRGB(255, 175, 35)
            statusPrefix = "📍"
        end

        item.OuterRing.Transparency = 0.15
        item.InnerDisk.Transparency = 0.15
        item.Diamond.Transparency = 0.05
        item.CorePin.Transparency = 0.25
        item.Label.Visible = true

        item.OuterRing.Color = markerColor
        item.Diamond.Color = markerColor
        item.CorePin.Color = markerColor
        item.Label.TextColor3 = markerColor

        local groundPos = entry.pos
        item.OuterRing.CFrame = CFrame.new(groundPos + Vector3.new(0, 0.07, 0)) * CFrame.Angles(0, 0, math.rad(90))
        item.InnerDisk.CFrame = CFrame.new(groundPos + Vector3.new(0, 0.09, 0)) * CFrame.Angles(0, 0, math.rad(90))
        item.CorePin.CFrame = CFrame.new(groundPos + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
        item.Diamond.CFrame = CFrame.new(groundPos + Vector3.new(0, 1.05, 0)) * CFrame.Angles(math.rad(45), math.rad(rotAngle), math.rad(45))

        item.Label.Text = string.format("%s #%s [%s]\n💰 %d¥ (%s)", statusPrefix, entry.unitTag, entry.unitName, entry.cost, entry.placementType)
    end

    for i = #spawnEntries + 1, #MacroMarkerPool.Items do
        local item = MacroMarkerPool.Items[i]
        if item and item.OuterRing.Parent then
            item.OuterRing.Transparency = 1
            item.InnerDisk.Transparency = 1
            item.Diamond.Transparency = 1
            item.CorePin.Transparency = 1
            item.Label.Visible = false
        end
    end
end

---------------------------------------------------------------------
-- TAB 1: AUTO JOIN (Dynamic Worlds & Working Best Story Finder)
---------------------------------------------------------------------
do
    local LobbyStatusPara = Tabs.AutoJoin:AddParagraph({
        Title = "Lobby Auto Join Status",
        Content = string.format(
            "%s | โหลดรายชื่อด่านจากเกมแล้ว %d Worlds",
            State.IsLobby and "🟢 อยู่ใน Lobby พร้อมค้นหาห้อง" or "⚔️ อยู่ในด่าน (Auto Join พักการทำงาน)",
            #DynamicWorldNames
        )
    })

    local JoinWorldDropdown = Tabs.AutoJoin:AddDropdown("JoinWorld", {
        Title = "Story (World) - ดึงชื่อตรงจากข้อมูลเกม",
        Values = DynamicWorldNames,
        Default = 1,
        Multi = false,
        Callback = function(val)
            local wId = WorldNameToIdMap[tostring(val or "")] or "?"
            local actVal = Options.JoinAct and Options.JoinAct.Value or "1"
            local diffVal = Options.JoinDifficulty and Options.JoinDifficulty.Value or "Normal"
            local resolvedLvl, resolvedDiff = ResolveTargetLevelId(val, actVal, diffVal)
            SafeUpdateParagraph(
                LobbyStatusPara,
                nil,
                string.format("เลือกด่าน: %s (ID: %s) -> Level: %s [%s]", tostring(val), tostring(wId), tostring(resolvedLvl), tostring(resolvedDiff))
            )
            AutoSaveUserConfig()
        end
    })

    local JoinActDropdown = Tabs.AutoJoin:AddDropdown("JoinAct", {
        Title = "Act",
        Values = {"1", "2", "3", "4", "5", "6", "Infinite"},
        Default = 1,
        Multi = false,
        Callback = function(actVal)
            local worldVal = Options.JoinWorld and Options.JoinWorld.Value or DynamicWorldNames[1]
            local diffVal = Options.JoinDifficulty and Options.JoinDifficulty.Value or "Normal"
            local resolvedLvl, resolvedDiff = ResolveTargetLevelId(worldVal, actVal, diffVal)
            SafeUpdateParagraph(
                LobbyStatusPara,
                nil,
                string.format("เลือกด่าน: %s -> Level: %s [%s]", tostring(worldVal), tostring(resolvedLvl), tostring(resolvedDiff))
            )
            AutoSaveUserConfig()
        end
    })

    Tabs.AutoJoin:AddDropdown("JoinDifficulty", {
        Title = "Difficulty",
        Values = {"Normal", "Hard", "Nightmare"},
        Default = 1,
        Multi = false,
        Callback = function() AutoSaveUserConfig() end
    })

    Tabs.AutoJoin:AddButton({
        Title = "Select Best Story (เลือกด่านเนื้อเรื่องสูงสุดที่ปลดล็อคแล้ว)",
        Description = "ตรวจสอบข้อมูลผู้เล่นและตั้งค่าไปยัง World & Act ล่าสุดโดยอัตโนมัติ",
        Callback = function()
            local profile = GetClientProfileTable()
            local bestWorldName = DynamicWorldNames[1]
            local bestActStr = "1"

            if profile and type(profile.level_completion) == "table" and type(WorldLevelOrder) == "table" then
                local orderTable = WorldLevelOrder.WORLD_ORDER or WorldLevelOrder
                if type(orderTable) == "table" then
                    for _, wId in ipairs(orderTable) do
                        local wDisplay = WorldIdToDisplayName[wId]
                        if wDisplay then
                            for actIdx = 1, 6 do
                                local lvlId = ResolveTargetLevelId(wDisplay, tostring(actIdx), "Normal")
                                local comp = profile.level_completion[lvlId]
                                if not comp then
                                    bestWorldName = wDisplay
                                    bestActStr = tostring(actIdx)
                                    break
                                else
                                    bestWorldName = wDisplay
                                    bestActStr = tostring(math.min(6, actIdx + 1))
                                end
                            end
                        end
                    end
                end
            end

            JoinWorldDropdown:SetValue(bestWorldName)
            JoinActDropdown:SetValue(bestActStr)
            Fluent:Notify({
                Title = "Best Story Selected",
                Content = string.format("ตั้งค่าไปยัง %s - Act %s เรียบร้อย!", tostring(bestWorldName), tostring(bestActStr)),
                Duration = 3
            })
        end
    })

    Tabs.AutoJoin:AddButton({
        Title = "Refresh Game Worlds (ดึงรายชื่อด่านจากเกมใหม่)",
        Description = "อัปเดตรายชื่อ World ทั้งหมดจาก ReplicatedStorage.src.Data.Worlds โดยตรง",
        Callback = function()
            BuildDynamicWorldsFromGameData()
            JoinWorldDropdown:SetValues(DynamicWorldNames)
            JoinWorldDropdown:SetValue(DynamicWorldNames[1])
            Fluent:Notify({
                Title = "Worlds Refreshed",
                Content = string.format("ดึงข้อมูลด่านจากเกมสำเร็จทั้งหมด %d ด่าน!", #DynamicWorldNames),
                Duration = 3
            })
        end
    })

    Tabs.AutoJoin:AddToggle("FriendsOnly", { Title = "Friends Only", Default = true, Callback = function() AutoSaveUserConfig() end })
    Tabs.AutoJoin:AddToggle("WorldSkip", { Title = "World Skip", Default = false, Callback = function() AutoSaveUserConfig() end })
    Tabs.AutoJoin:AddToggle("AutoStart", { Title = "Auto Start (Solo Vote)", Default = true, Callback = function() AutoSaveUserConfig() end })

    Tabs.AutoJoin:AddToggle("AutoJoinStory", {
        Title = "Auto Join Story",
        Default = false,
        Callback = function() AutoSaveUserConfig() end
    })

    Tabs.AutoJoin:AddButton({
        Title = "Return to Lobby",
        Description = "เทเลพอร์ตกลับไปที่ล็อบบี้หลัก",
        Callback = function()
            InvokeServer("teleport_back_to_lobby")
            task.wait(1)
            TeleportService:Teleport(LOBBY_PLACE_ID, LocalPlayer)
        end
    })

    local function JoinSelectedStoryPod()
        local lobbies = Workspace:FindFirstChild("_LOBBIES")
        local story = lobbies and lobbies:FindFirstChild("Story")
        if not story then return false end

        local worldName = Options.JoinWorld and Options.JoinWorld.Value or DynamicWorldNames[1]
        local actStr = Options.JoinAct and Options.JoinAct.Value or "1"
        local diffStr = Options.JoinDifficulty and Options.JoinDifficulty.Value or "Normal"
        local friendsOnly = (Options.FriendsOnly and Options.FriendsOnly.Value) or false

        local targetLevel, diff = ResolveTargetLevelId(worldName, actStr, diffStr)

        for _, lobby in ipairs(story:GetChildren()) do
            local players = lobby:FindFirstChild("Players")
            if players and players:FindFirstChild(LocalPlayer.Name) then
                SafeUpdateParagraph(LobbyStatusPara, nil, "กำลังล็อคด่าน: " .. targetLevel .. " (" .. diff .. ")")
                InvokeServer("request_lock_level", lobby.Name, targetLevel, friendsOnly, diff)
                if Options.AutoStart and Options.AutoStart.Value then
                    task.wait(0.35)
                    InvokeServer("request_start_game", lobby.Name)
                end
                return true
            end
        end

        local free_lobby = nil
        for _, lobby in ipairs(story:GetChildren()) do
            local owner = lobby:FindFirstChild("Owner") and lobby.Owner.Value
            local players = lobby:FindFirstChild("Players") and #lobby.Players:GetChildren()
            if (not owner or owner == nil or owner == "") and (players == 0) then
                free_lobby = lobby
                break
            end
        end

        if not free_lobby then return false end

        local ok = InvokeServer("request_join_lobby", free_lobby.Name)
        if not ok then
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local primary = free_lobby:FindFirstChild("primary") or free_lobby:FindFirstChild("Door")
            if hrp and primary then
                hrp.CFrame = primary.CFrame + Vector3.new(0, 3, 0)
            end
            task.wait(0.35)
            ok = InvokeServer("request_join_lobby", free_lobby.Name)
        end

        if ok then
            SafeUpdateParagraph(LobbyStatusPara, nil, "เข้าห้อง " .. free_lobby.Name .. " สำเร็จ! กำลังเริ่มด่าน " .. targetLevel)
            task.wait(0.25)
            InvokeServer("request_lock_level", free_lobby.Name, targetLevel, friendsOnly, diff)
            if Options.AutoStart and Options.AutoStart.Value then
                task.wait(0.35)
                InvokeServer("request_start_game", free_lobby.Name)
            end
            return true
        end
        return false
    end

    task.spawn(function()
        while true do
            task.wait(2.0)
            if Options.AutoJoinStory and Options.AutoJoinStory.Value then
                if Workspace:FindFirstChild("_LOBBIES") ~= nil then
                    JoinSelectedStoryPod()
                end
            end
        end
    end)
end

---------------------------------------------------------------------
-- TAB 2: MACRO (Hook-Free d.json Format Recorder + Playback + Raid Ability Support)
---------------------------------------------------------------------
local MacroStatusPara = nil
local MacroLiveLogPara = nil

local function AppendMacroLog(msg)
    local t = State.IsRecording and math.floor(os.clock() - State.RecordStartTime) or 0
    table.insert(State.MacroLogLines, 1, string.format("[W%d | %ds] %s", GetCurrentWave(), t, msg))
    if #State.MacroLogLines > 8 then
        table.remove(State.MacroLogLines)
    end
    SafeUpdateParagraph(MacroLiveLogPara, nil, table.concat(State.MacroLogLines, "\n"))
end

do
    MacroStatusPara = Tabs.Macro:AddParagraph({
        Title = "Macro Status",
        Content = "Idle | Active File: None"
    })

    MacroLiveLogPara = Tabs.Macro:AddParagraph({
        Title = "Live Macro Log (ฟอร์แมต d.json: เก็บชื่อ Unit, Wave, Time, UnitValue)",
        Content = "พร้อมทำงาน..."
    })

    local MacroFileDropdown = Tabs.Macro:AddDropdown("SelectMacroFile", {
        Title = "Select Active Macro File (ไฟล์ที่ใช้เล่นและบันทึก)",
        Values = GetMacroFileList(),
        Default = 1,
        Multi = false
    })

    local MacroFileNameInput = Tabs.Macro:AddInput("MacroFileName", {
        Title = "New File Name (สำหรับสร้างไฟล์ใหม่)",
        Default = "",
        Placeholder = "พิมพ์ชื่อไฟล์ใหม่ เช่น d หรือ raid_macro",
        Numeric = false,
        Finished = false
    })

    local function GetActiveTargetMacroName()
        local sel = Options.SelectMacroFile and Options.SelectMacroFile.Value
        if sel and sel ~= "" and sel ~= "None" then
            return sel
        end
        local inputName = Options.MacroFileName and Options.MacroFileName.Value
        if inputName and inputName ~= "" then
            return inputName
        end
        return "Default_Macro"
    end

    MacroFileDropdown:OnChanged(function(val)
        State.ActiveMacroData = nil
        State.PreviewMacroData = nil
        State.PreviewMacroFileName = nil
        if val and val ~= "None" then
            local path = MACRO_FOLDER .. "/" .. val .. ".json"
            local count = 0
            if typeof(isfile) == "function" and isfile(path) then
                pcall(function()
                    local decoded = HttpService:JSONDecode(readfile(path))
                    local listData = decoded and (decoded.Marco_Data or decoded.Macro_Data)
                    if listData then
                        NormalizeMacroActions(listData)
                        count = #listData
                    end
                    State.PreviewMacroData = decoded
                    State.PreviewMacroFileName = val
                end)
            end
            SafeUpdateParagraph(MacroStatusPara, nil, string.format("ไฟล์ที่เลือก: %s.json (%d คำสั่ง)", val, count))
        end
        pcall(UpdateMacroGroundMarkers)
        AutoSaveUserConfig()
    end)

    Tabs.Macro:AddButton({
        Title = "Create & Select Macro File (สร้างและเลือกไฟล์นี้ทันที)",
        Description = "สร้างไฟล์ใหม่จากช่อง New File Name และสลับไปใช้ไฟล์นั้นทันที",
        Callback = function()
            local name = Options.MacroFileName and Options.MacroFileName.Value
            if not name or name == "" then
                Fluent:Notify({ Title = "Macro Error", Content = "กรุณาพิมพ์ชื่อไฟล์ในช่อง New File Name ก่อนกดสร้าง", Duration = 3 })
                return
            end
            name = name:gsub("%.json$", "")
            if typeof(writefile) == "function" then
                local template = {
                    Map = Options.JoinWorld and Options.JoinWorld.Value or "Any",
                    Mode = "story",
                    Version = 2,
                    Index = 0,
                    Marco_Data = {}
                }
                local path = MACRO_FOLDER .. "/" .. name .. ".json"
                writefile(path, HttpService:JSONEncode(template))
                local list = GetMacroFileList()
                MacroFileDropdown:SetValues(list)
                MacroFileDropdown:SetValue(name)
                Fluent:Notify({ Title = "Macro Created & Selected", Content = "สร้างและเลือกไฟล์: " .. name .. ".json แล้ว", Duration = 4 })
            end
        end
    })

    Tabs.Macro:AddButton({
        Title = "Refresh Macro Files",
        Callback = function()
            local currentSel = Options.SelectMacroFile and Options.SelectMacroFile.Value
            local list = GetMacroFileList()
            MacroFileDropdown:SetValues(list)
            if currentSel and table.find(list, currentSel) then
                MacroFileDropdown:SetValue(currentSel)
            else
                MacroFileDropdown:SetValue(list[1] or "None")
            end
        end
    })

    Tabs.Macro:AddButton({
        Title = "Delete Selected Macro (ลบไฟล์ที่เลือกอยู่)",
        Callback = function()
            local sel = Options.SelectMacroFile and Options.SelectMacroFile.Value
            if sel and sel ~= "None" and typeof(delfile) == "function" then
                local path = MACRO_FOLDER .. "/" .. sel .. ".json"
                pcall(delfile, path)
                local list = GetMacroFileList()
                MacroFileDropdown:SetValues(list)
                MacroFileDropdown:SetValue(list[1] or "None")
                Fluent:Notify({ Title = "Macro Deleted", Content = "ลบไฟล์: " .. path, Duration = 3 })
            end
        end
    })

    Tabs.Macro:AddInput("MacroURL", {
        Title = "URL File (Import)",
        Default = "",
        Placeholder = "https://raw.githubusercontent.com/.../d.json",
        Finished = false
    })

    Tabs.Macro:AddButton({
        Title = "Import File from URL",
        Callback = function()
            local url = Options.MacroURL.Value
            if url and url ~= "" and typeof(writefile) == "function" then
                local success, res = pcall(function() return game:HttpGet(url) end)
                if success and res then
                    local baseName = (Options.MacroFileName.Value ~= "" and Options.MacroFileName.Value) or "Imported_Macro"
                    baseName = baseName:gsub("%.json$", "")
                    local path = MACRO_FOLDER .. "/" .. baseName .. ".json"
                    writefile(path, res)
                    local list = GetMacroFileList()
                    MacroFileDropdown:SetValues(list)
                    MacroFileDropdown:SetValue(baseName)
                    Fluent:Notify({ Title = "Macro Imported", Content = "นำเข้าและเลือกไฟล์: " .. baseName, Duration = 4 })
                else
                    Fluent:Notify({ Title = "Import Error", Content = "ดาวน์โหลดไฟล์จาก URL ไม่สำเร็จ", Duration = 4 })
                end
            end
        end
    })

    Tabs.Macro:AddDropdown("MacroMethod", {
        Title = "Macro Method (โหมดการเล่นมาโคร)",
        Values = {"Hybrid (Cash + Wave)", "Cash Only", "Wave + Time", "Time Only"},
        Default = 1,
        Multi = false,
        Callback = function() AutoSaveUserConfig() end
    })

    local MacroRecordingToggle = Tabs.Macro:AddToggle("MacroRecording", {
        Title = "Macro Recording (อัดแบบ d.json ไม่ใช้ UUID / ไม่ Hook เกม)",
        Default = false
    })

    Tabs.Macro:AddToggle("PlayBackMacro", {
        Title = "PlayBack Macro (เล่นมาโครจากไฟล์ที่เลือก)",
        Default = false,
        Callback = function() AutoSaveUserConfig() end
    })

    Tabs.Macro:AddToggle("ShowMacroPlacementMarkers", {
        Title = "Show Macro Unit Markers (แสดงจุดสีบนพื้นตามตำแหน่งยูนิตในมาโคร)",
        Description = "แสดงวงแหวนและคริสตัลบอกจุดวางยูนิตตามมาโคร (สีส้ม=รอวาง, สีม่วง=ตัวถัดไป, สีเขียว=วางแล้ว)",
        Default = false,
        Callback = function(val)
            if Options.ShowMacroPlacementMarkersAI and Options.ShowMacroPlacementMarkersAI.Value ~= val then
                pcall(function() Options.ShowMacroPlacementMarkersAI:SetValue(val) end)
            end
            pcall(UpdateMacroGroundMarkers)
            AutoSaveUserConfig()
        end
    })

    Tabs.Macro:AddToggle("AutoUpgradeHighest", {
        Title = "Auto Upgrade (Highest Cost First after Macro)",
        Default = true,
        Callback = function() AutoSaveUserConfig() end
    })

    -- บันทึกข้อมูลมาโครลงไฟล์ตามโครงสร้าง d.json เป๊ะๆ
    local function FlushRecordedMacroToDisk()
        if typeof(writefile) ~= "function" then return end
        local targetFile = GetActiveTargetMacroName()
        local exportData = {
            Map = Options.JoinWorld and Options.JoinWorld.Value or "Any",
            Marco_Data = State.RecordedActions,
            Mode = "story",
            Version = 2,
            Index = #State.RecordedActions
        }
        local path = MACRO_FOLDER .. "/" .. targetFile .. ".json"
        pcall(function()
            writefile(path, HttpService:JSONEncode(exportData))
            State.PreviewMacroData = exportData
            State.PreviewMacroFileName = targetFile
        end)
    end

    -- ฟังก์ชันดักจับยูนิตใน Workspace._UNITS แบบ Passive (ไม่ต้อง Hook ฟังก์ชันของเกม จึงไม่โดน Error 267 และอัดติด 100%)
    local function AttachUnitRecorderListeners(unitModel, isPreExisting)
        if not unitModel or State.HookedUnitInstances[unitModel] then return end
        State.HookedUnitInstances[unitModel] = true

        task.spawn(function()
            local st = unitModel:WaitForChild("_stats", 5)
            if not st then return end
            local playerObj = st:WaitForChild("player", 5)
            if not playerObj or playerObj.Value ~= LocalPlayer then return end

            local idObj = st:WaitForChild("id", 3)
            local upgObj = st:WaitForChild("upgrade", 3)
            local unitCleanName = (idObj and tostring(idObj.Value) ~= "" and tostring(idObj.Value)) or unitModel.Name

            -- กำหนดหมายเลข UnitValue ให้ยูนิตของเรา
            local unitTag = State.InstanceToTagMap[unitModel]
            if not unitTag then
                State.RecordedUnitCounter = State.RecordedUnitCounter + 1
                unitTag = State.RecordedUnitCounter
                State.InstanceToTagMap[unitModel] = unitTag
            end

            -- ถ้าเป็นยูนิตที่เพิ่งวางใหม่ระหว่างเปิดอัดมาโคร ให้บันทึก SpawnTower ตามโครงสร้าง d.json
            if State.IsRecording and not isPreExisting then
                local rp = unitModel.PrimaryPart or unitModel:FindFirstChild("HumanoidRootPart") or unitModel:FindFirstChildWhichIsA("BasePart", true)
                local unitCF = rp and rp.CFrame or CFrame.new()
                local okPivot, pivotCF = pcall(function() return unitModel:GetPivot() end)
                if okPivot and pivotCF then
                    unitCF = pivotCF
                end

                -- ปรับความสูง Y ให้ติดพื้นจริงเหมือนค่าใน d.json
                local exactCF = BuildPlacementCFrame(unitCF.Position)
                local nextIndex = #State.RecordedActions + 1
                local elapsedSec = math.max(0, math.floor(os.clock() - State.RecordStartTime))
                local curWave = math.max(1, GetCurrentWave())

                table.insert(State.RecordedActions, {
                    Wave = curWave,
                    Index = nextIndex,
                    Position = tostring(exactCF),
                    Method = "SpawnTower",
                    Time = elapsedSec,
                    UnitValue = unitTag,
                    Unit = unitCleanName
                })

                FlushRecordedMacroToDisk()
                pcall(UpdateMacroGroundMarkers)
                SafeUpdateParagraph(MacroStatusPara, string.format("🔴 Recording -> %s.json (%d Actions)", GetActiveTargetMacroName(), #State.RecordedActions), nil)
                AppendMacroLog(string.format("Spawn #%d [%s] (Index %d)", unitTag, unitCleanName, nextIndex))
            end

            -- ดักจับการอัปเกรดยูนิต (_stats.upgrade.Changed)
            if upgObj then
                local lastUpgVal = tonumber(upgObj.Value) or 0
                AddConnection(upgObj.Changed, function(newVal)
                    local currentUpg = tonumber(newVal) or 0
                    if currentUpg > lastUpgVal then
                        local diff = currentUpg - lastUpgVal
                        lastUpgVal = currentUpg
                        if State.IsRecording then
                            for _ = 1, diff do
                                local nextIndex = #State.RecordedActions + 1
                                local elapsedSec = math.max(0, math.floor(os.clock() - State.RecordStartTime))
                                local curWave = math.max(1, GetCurrentWave())

                                table.insert(State.RecordedActions, {
                                    Wave = curWave,
                                    Index = nextIndex,
                                    Time = elapsedSec,
                                    UnitValue = unitTag,
                                    Method = "UpgradeTower"
                                })

                                AppendMacroLog(string.format("Upgrade #%d [%s] -> Lv.%d", unitTag, unitCleanName, currentUpg))
                            end
                            FlushRecordedMacroToDisk()
                            SafeUpdateParagraph(MacroStatusPara, string.format("🔴 Recording -> %s.json (%d Actions)", GetActiveTargetMacroName(), #State.RecordedActions), nil)
                        end
                    end
                end)
            end

            -- ดักจับการกดสกิล (หากมีตัวแปรคูลดาวน์สกิลใน _stats)
            local activeAttackVal = st:FindFirstChild("active_attack_cooldown") or st:FindFirstChild("last_active_attack")
            if activeAttackVal then
                AddConnection(activeAttackVal.Changed, function()
                    if State.IsRecording then
                        local nextIndex = #State.RecordedActions + 1
                        local elapsedSec = math.max(0, math.floor(os.clock() - State.RecordStartTime))
                        local curWave = math.max(1, GetCurrentWave())
                        table.insert(State.RecordedActions, {
                            Wave = curWave,
                            Index = nextIndex,
                            Ability = "Active",
                            Method = "Use Ability",
                            UnitValue = unitTag,
                            Time = elapsedSec
                        })
                        FlushRecordedMacroToDisk()
                        AppendMacroLog(string.format("Use Ability #%d [%s]", unitTag, unitCleanName))
                    end
                end)
            end

            -- ดักจับการขายยูนิต (เมื่อถูกลบออกจาก _UNITS ก่อนจบเกม)
            AddConnection(unitModel.AncestryChanged, function(_, newParent)
                if newParent == nil and State.IsRecording then
                    local dataFolder = Workspace:FindFirstChild("_DATA")
                    local finished = dataFolder and dataFolder:FindFirstChild("GameFinished") and dataFolder.GameFinished.Value
                    if not finished and Workspace:FindFirstChild("_UNITS") then
                        local nextIndex = #State.RecordedActions + 1
                        local elapsedSec = math.max(0, math.floor(os.clock() - State.RecordStartTime))
                        local curWave = math.max(1, GetCurrentWave())
                        table.insert(State.RecordedActions, {
                            Wave = curWave,
                            Index = nextIndex,
                            Time = elapsedSec,
                            UnitValue = unitTag,
                            Method = "SellTower"
                        })
                        FlushRecordedMacroToDisk()
                        SafeUpdateParagraph(MacroStatusPara, string.format("🔴 Recording -> %s.json (%d Actions)", GetActiveTargetMacroName(), #State.RecordedActions), nil)
                        AppendMacroLog(string.format("Sell #%d [%s]", unitTag, unitCleanName))
                    end
                end
            end)
        end)
    end

    -- เชื่อมต่อตัวดักจับเข้ากับโฟลเดอร์ _UNITS อัตโนมัติ
    local currentWatchedUnitsFolder = nil
    local function EnsureUnitsFolderRecorderWatcher()
        local uFolder = Workspace:FindFirstChild("_UNITS")
        if uFolder and uFolder ~= currentWatchedUnitsFolder then
            currentWatchedUnitsFolder = uFolder
            for _, existingUnit in ipairs(uFolder:GetChildren()) do
                AttachUnitRecorderListeners(existingUnit, true)
            end
            AddConnection(uFolder.ChildAdded, function(newUnit)
                AttachUnitRecorderListeners(newUnit, false)
            end)
        end
    end

    EnsureUnitsFolderRecorderWatcher()
    AddConnection(Workspace.ChildAdded, function(ch)
        if ch.Name == "_UNITS" then
            EnsureUnitsFolderRecorderWatcher()
        end
    end)

    MacroRecordingToggle:OnChanged(function(val)
        State.IsRecording = val
        local targetFile = GetActiveTargetMacroName()

        if val then
            EnsureUnitsFolderRecorderWatcher()
            if Options.SelectMacroFile.Value == "None" then
                local list = GetMacroFileList()
                if not table.find(list, targetFile) then
                    table.insert(list, targetFile)
                end
                MacroFileDropdown:SetValues(list)
                MacroFileDropdown:SetValue(targetFile)
            end

            State.RecordedActions = {}
            State.InstanceToTagMap = {}
            State.HookedUnitInstances = {}
            State.MacroLogLines = {}
            State.RecordedUnitCounter = 0
            State.RecordStartTime = os.clock()

            -- หากมียูนิตที่วางอยู่ในแมพแล้วก่อนกดอัด ให้บันทึกยูนิตเหล่านั้นเป็นลำดับตั้งต้นทันที
            local uFolder = Workspace:FindFirstChild("_UNITS")
            if uFolder then
                for _, existingUnit in ipairs(uFolder:GetChildren()) do
                    AttachUnitRecorderListeners(existingUnit, false)
                end
            end

            SafeUpdateParagraph(MacroStatusPara, "🔴 Recording -> " .. targetFile .. ".json", "วางหรืออัปเกรดยูนิตในเกมได้เลย (บันทึกเป็นชื่อยูนิตแบบ d.json)")
            AppendMacroLog("เริ่มอัดมาโครลงไฟล์: " .. targetFile .. ".json")
            Fluent:Notify({ Title = "Macro Recorder", Content = "กำลังอัดลงไฟล์: " .. targetFile .. ".json", Duration = 3 })
        else
            if #State.RecordedActions > 0 then
                FlushRecordedMacroToDisk()
                local list = GetMacroFileList()
                MacroFileDropdown:SetValues(list)
                MacroFileDropdown:SetValue(targetFile)
                State.ActiveMacroData = nil
                pcall(UpdateMacroGroundMarkers)
                SafeUpdateParagraph(MacroStatusPara, "💾 Saved " .. #State.RecordedActions .. " Actions -> " .. targetFile .. ".json", nil)
                AppendMacroLog("บันทึกสำเร็จ " .. #State.RecordedActions .. " คำสั่งลงใน " .. targetFile .. ".json")
                Fluent:Notify({ Title = "Macro Saved", Content = "บันทึกลงไฟล์ " .. targetFile .. ".json เรียบร้อย!", Duration = 4 })
            else
                SafeUpdateParagraph(MacroStatusPara, "Idle | No Actions Recorded", nil)
            end
        end
    end)

    -- ลูป PlayBack Macro (รองรับทั้ง d.json และ raid map 2.json โดยแปลงชื่อ Unit เป็น UUID ในกระเป๋าขณะเล่น)
    task.spawn(function()
        local macroCompleted = false
        local playbackStartClock = 0
        local lastLoadedFileName = nil
        local gameEntryTime = nil

        while true do
            task.wait(0.3)
            local is_ingame = Workspace:FindFirstChild("_UNITS") ~= nil
            local currentWave = GetCurrentWave()
            if is_ingame then
                gameEntryTime = gameEntryTime or os.clock()
            else
                gameEntryTime = nil
            end

            if is_ingame and currentWave <= 1 and macroCompleted then
                State.ActiveMacroData = nil
                macroCompleted = false
            end

            if Options.PlayBackMacro and Options.PlayBackMacro.Value and is_ingame and gameEntryTime and (os.clock() - gameEntryTime) >= 5 and not State.IsRecording then
                local sel = Options.SelectMacroFile and Options.SelectMacroFile.Value
                if sel and sel ~= "None" and (not State.ActiveMacroData or lastLoadedFileName ~= sel) then
                    local path = MACRO_FOLDER .. "/" .. sel .. ".json"
                    if typeof(isfile) == "function" and isfile(path) then
                        local ok, decoded = pcall(function()
                            return HttpService:JSONDecode(readfile(path))
                        end)
                        if ok and type(decoded) == "table" then
                            local rawList = decoded.Marco_Data or decoded.Macro_Data
                            if type(rawList) == "table" then
                                NormalizeMacroActions(rawList)
                            end
                            State.ActiveMacroData = decoded
                            State.MacroIndex = 1
                            State.SpawnedUnitUUIDs = {}
                            macroCompleted = false
                            playbackStartClock = os.clock()
                            lastLoadedFileName = sel
                            AppendMacroLog("โหลดมาโคร: " .. sel .. ".json (" .. tostring(rawList and #rawList or 0) .. " คำสั่ง)")
                        end
                    end
                end

                local actions = State.ActiveMacroData and (State.ActiveMacroData.Marco_Data or State.ActiveMacroData.Macro_Data)
                if actions then
                    local currAction = actions[State.MacroIndex]
                    local elapsed = os.clock() - playbackStartClock
                    local currentCash = GetPlayerCash()

                    if currAction then
                        local method = Options.MacroMethod and Options.MacroMethod.Value or "Hybrid (Cash + Wave)"
                        local canExecute = false
                        local unitKey = tonumber(currAction.UnitValue) or currAction.UnitValue or State.MacroIndex
                        local targetUnit = State.SpawnedUnitUUIDs[unitKey]
                        local actionWave = tonumber(currAction.Wave) or 0
                        local actionTime = tonumber(currAction.Time) or 0

                        local neededCost = tonumber(currAction.Cost) or 0
                        if currAction.Method == "SpawnTower" then
                            local unitIdentifier = currAction.Unit or currAction.UnitId or currAction.UnitName
                            neededCost = LookupUnitCostByIdOrName(unitIdentifier, unitIdentifier, 0) or neededCost or 500
                        elseif currAction.Method == "UpgradeTower" then
                            if targetUnit and targetUnit.Parent then
                                local st = targetUnit:FindFirstChild("_stats")
                                if st and st:FindFirstChild("upgrade_cost") and tonumber(st.upgrade_cost.Value) and tonumber(st.upgrade_cost.Value) > 0 then
                                    neededCost = tonumber(st.upgrade_cost.Value)
                                end
                            end
                            if not neededCost or neededCost <= 0 then
                                neededCost = LookupUnitCostByIdOrName(currAction.UnitId or currAction.Unit, currAction.UnitName, currAction.TargetLevel) or 500
                            end
                        else
                            neededCost = 0
                        end

                        -- ตรวจสอบเงื่อนไขตามโหมดที่เลือก
                        if method == "Time Only" then
                            canExecute = (elapsed >= actionTime)
                        elseif method == "Wave + Time" then
                            canExecute = (currentWave >= actionWave) and (elapsed >= actionTime) and (currentCash >= neededCost)
                        elseif method == "Cash Only" then
                            if currAction.Method == "SellTower" or currAction.Method == "Use Ability" or currAction.Method == "UseAbility" then
                                canExecute = (currentWave >= actionWave) or (elapsed >= actionTime)
                            else
                                canExecute = (currentCash >= neededCost)
                            end
                        else
                            -- Hybrid (Cash + Wave)
                            if currAction.Method == "SellTower" or currAction.Method == "Use Ability" or currAction.Method == "UseAbility" then
                                canExecute = (actionWave > 0 and currentWave >= actionWave) or (elapsed >= actionTime)
                            else
                                local waveReady = (actionWave <= 1) or (currentWave >= actionWave) or (elapsed >= actionTime)
                                canExecute = waveReady and (currentCash >= neededCost)
                            end
                        end

                        SafeUpdateParagraph(
                            MacroStatusPara,
                            string.format("▶️ Playing [%s] | Step %d/%d", tostring(lastLoadedFileName), State.MacroIndex, #actions),
                            string.format(
                                "Action: %s [%s #%s] | W:%d/%d | ใช้เงิน: %d¥ (มี: %d¥)",
                                tostring(currAction.Method),
                                tostring(currAction.Unit or currAction.UnitName or "Unit"),
                                tostring(unitKey),
                                currentWave,
                                actionWave,
                                neededCost,
                                currentCash
                            )
                        )

                        if canExecute then
                            local actionDone = false

                            if currAction.Method == "SpawnTower" then
                                local spawnCF, spawnPos = ParseCFrameOrPosition(currAction.Position)
                                local existing = FindMyUnitNearPosition(spawnPos, 2.0)
                                if existing then
                                    State.SpawnedUnitUUIDs[unitKey] = existing
                                    actionDone = true
                                else
                                    local uuidToUse, matchedUnitId = ResolveEquippedUUIDFromUnitName(currAction.Unit, currAction.UnitId, currAction.UnitName)
                                    if not uuidToUse then
                                        -- ป้องกัน Error 267: ห้ามส่งชื่อยูนิตหรือ UUID ที่ไม่ได้อยู่ในทีมไปที่ spawn_unit เด็ดขาด
                                        AppendMacroLog(string.format("⚠️ ข้าม #%s [%s] (ไม่ได้ใส่ยูนิตนี้ในทีม)", tostring(unitKey), tostring(currAction.Unit)))
                                        actionDone = true
                                    else
                                        InvokeServer("spawn_unit", uuidToUse, spawnCF)
                                        task.wait(0.35)

                                        local newlySpawned = FindMyUnitNearPosition(spawnPos, 5.5)
                                        if newlySpawned then
                                            State.SpawnedUnitUUIDs[unitKey] = newlySpawned
                                            actionDone = true
                                            AppendMacroLog(string.format("วาง #%s [%s] (%d¥) สำเร็จ", tostring(unitKey), tostring(matchedUnitId or newlySpawned.Name), neededCost))
                                        else
                                            -- ลองปรับ CFrame ให้แนบพื้นแมพอีก 1 ครั้งด้วย UUID ที่ถูกต้องเท่านั้น
                                            local altCF = BuildPlacementCFrame(spawnPos)
                                            InvokeServer("spawn_unit", uuidToUse, altCF)
                                            task.wait(0.35)
                                            newlySpawned = FindMyUnitNearPosition(spawnPos, 5.5)
                                            if newlySpawned then
                                                State.SpawnedUnitUUIDs[unitKey] = newlySpawned
                                                actionDone = true
                                                AppendMacroLog(string.format("วาง #%s [%s] สำเร็จ", tostring(unitKey), newlySpawned.Name))
                                            end
                                        end
                                    end
                                end

                            elseif currAction.Method == "UpgradeTower" then
                                if targetUnit and targetUnit.Parent then
                                    local st = targetUnit:FindFirstChild("_stats")
                                    local curUpg = (st and st:FindFirstChild("upgrade") and tonumber(st.upgrade.Value)) or 0
                                    local goalUpg = tonumber(currAction.TargetLevel) or (curUpg + 1)

                                    if curUpg >= goalUpg then
                                        actionDone = true
                                    else
                                        InvokeServer("upgrade_unit_ingame", targetUnit)
                                        task.wait(0.35)
                                        local newUpg = (st and st:FindFirstChild("upgrade") and tonumber(st.upgrade.Value)) or curUpg
                                        if newUpg > curUpg or method == "Time Only" then
                                            actionDone = true
                                            AppendMacroLog(string.format("อัปเกรด #%s [%s] -> Lv.%d (%d¥)", tostring(unitKey), targetUnit.Name, newUpg, neededCost))
                                        end
                                    end
                                else
                                    actionDone = true
                                end

                            elseif currAction.Method == "Use Ability" or currAction.Method == "UseAbility" then
                                if targetUnit and targetUnit.Parent then
                                    InvokeServer("use_active_attack", targetUnit)
                                    AppendMacroLog(string.format("กดสกิล #%s [%s] (%s)", tostring(unitKey), targetUnit.Name, tostring(currAction.Ability or "Skill")))
                                end
                                actionDone = true

                            elseif currAction.Method == "SellTower" then
                                if targetUnit and targetUnit.Parent then
                                    InvokeServer("sell_unit_ingame", targetUnit)
                                    AppendMacroLog(string.format("ขาย #%s [%s]", tostring(unitKey), targetUnit.Name))
                                end
                                actionDone = true
                            else
                                actionDone = true
                            end

                            if actionDone then
                                State.MacroIndex = State.MacroIndex + 1
                            end
                        end
                    else
                        if not macroCompleted then
                            macroCompleted = true
                            SafeUpdateParagraph(MacroStatusPara, "✅ Macro Completed | Auto-Upgrading", nil)
                            AppendMacroLog("เล่นมาโครครบทุกขั้นตอนแล้ว!")
                        end

                        if Options.AutoUpgradeHighest and Options.AutoUpgradeHighest.Value then
                            local placedFolder = Workspace:FindFirstChild("_UNITS")
                            if placedFolder then
                                local highestCost = -1
                                local highestUnit = nil
                                for _, unit in ipairs(placedFolder:GetChildren()) do
                                    local st = unit:FindFirstChild("_stats")
                                    if st and st:FindFirstChild("player") and st.player.Value == LocalPlayer then
                                        local upgLvl = (st:FindFirstChild("upgrade") and tonumber(st.upgrade.Value)) or 0
                                        local idVal = st:FindFirstChild("id") and tostring(st.id.Value) or unit.Name
                                        local cost = (st:FindFirstChild("upgrade_cost") and tonumber(st.upgrade_cost.Value))
                                            or LookupUnitCostByIdOrName(idVal, unit.Name, upgLvl + 1)
                                            or 500
                                        if cost > 0 and cost > highestCost and cost <= currentCash then
                                            highestCost = cost
                                            highestUnit = unit
                                        end
                                    end
                                end
                                if highestUnit then
                                    InvokeServer("upgrade_unit_ingame", highestUnit)
                                    task.wait(0.4)
                                end
                            end
                        end
                    end
                end
            else
                if not (Options.PlayBackMacro and Options.PlayBackMacro.Value) then
                    State.ActiveMacroData = nil
                end
            end
        end
    end)
end

---------------------------------------------------------------------
-- TAB 3: AI - SYSTEM (Obstacle-Free Slots + Real-Time Hologram + Safe Auto Place)
---------------------------------------------------------------------
do
    local AIStatusPara = Tabs.AI:AddParagraph({
        Title = "Universal Road & Terrain Hill Hologram Status",
        Content = string.format(
            "สแกนสำเร็จ: ถนน [%s] %d ชิ้น (%.0f studs) | เนิน '_terrain.hill' %d ชิ้น",
            tostring(State.ActiveRoadLabel),
            #State.MainPartInstances,
            State.MainRoadTotalLength,
            #State.HillPartInstances
        )
    })

    local HologramPool = {
        Folder = nil,
        GroundDisk = nil,
        GroundLabel = nil,
        HillDisk = nil,
        HillLabel = nil,
        FarmDisk = nil,
        FarmLabel = nil,
        PathBeams = {},
        Figures = {
            Ground = {},
            Hill = {},
            Farm = {}
        }
    }

    local function CreateNonBlockingPart(parent, name)
        local p = Instance.new("Part")
        p.Name = name
        p.Anchored = true
        p.CanCollide = false
        p.CanTouch = false
        pcall(function() p.CanQuery = false end)
        p.CastShadow = false
        p.TopSurface = Enum.SurfaceType.Smooth
        p.BottomSurface = Enum.SurfaceType.Smooth
        p.Parent = parent
        return p
    end

    local function AttachBillboardTag(parentPart, text, color)
        local bgui = Instance.new("BillboardGui")
        bgui.Name = "TagGui"
        bgui.Size = UDim2.fromOffset(210, 28)
        bgui.StudsOffset = Vector3.new(0, 2.8, 0)
        bgui.AlwaysOnTop = true
        bgui.Parent = parentPart

        local lbl = Instance.new("TextLabel")
        lbl.Name = "TagLabel"
        lbl.Size = UDim2.fromScale(1, 1)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.TextColor3 = color
        lbl.TextStrokeTransparency = 0.15
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 13
        lbl.Parent = bgui
        return lbl
    end

    local function EnsureHologramPoolFolder()
        if HologramPool.Folder and HologramPool.Folder.Parent and HologramPool.GroundDisk and HologramPool.GroundDisk.Parent then
            return HologramPool.Folder
        end
        local existing = Workspace:FindFirstChild("_TD_Holograms")
        if existing then pcall(function() existing:Destroy() end) end

        local folder = Instance.new("Folder")
        folder.Name = "_TD_Holograms"
        folder.Parent = Workspace
        HologramPool.Folder = folder
        State.HologramFolder = folder

        local function MakeDisk(name, color)
            local d = CreateNonBlockingPart(folder, name)
            d.Shape = Enum.PartType.Cylinder
            d.Material = Enum.Material.Neon
            d.Color = color
            d.Transparency = 0.55
            return d
        end

        HologramPool.GroundDisk = MakeDisk("GroundZoneDisk", Color3.fromRGB(255, 80, 220))
        HologramPool.GroundLabel = AttachBillboardTag(HologramPool.GroundDisk, "⚔️ GROUND ZONE", Color3.fromRGB(255, 110, 235))

        HologramPool.HillDisk = MakeDisk("HillZoneDisk", Color3.fromRGB(255, 230, 65))
        HologramPool.HillLabel = AttachBillboardTag(HologramPool.HillDisk, "⛰️ HILL (_terrain.hill)", Color3.fromRGB(255, 245, 110))

        HologramPool.FarmDisk = MakeDisk("FarmZoneDisk", Color3.fromRGB(55, 245, 130))
        HologramPool.FarmLabel = AttachBillboardTag(HologramPool.FarmDisk, "💰 FARM (GROUND)", Color3.fromRGB(110, 255, 150))

        HologramPool.PathBeams = {}
        HologramPool.Figures = { Ground = {}, Hill = {}, Farm = {} }
        return folder
    end

    local function SetPooledFigures(category, positions, figColor, padColor)
        local folder = EnsureHologramPoolFolder()
        local poolList = HologramPool.Figures[category]

        for i, pos in ipairs(positions) do
            local fig = poolList[i]
            local showThisFigure = not (Options.ShowNextPlacementOnly and Options.ShowNextPlacementOnly.Value) or i == 1
            if not fig or not fig.Pad.Parent then
                local pad = CreateNonBlockingPart(folder, category .. "_Pad_" .. i)
                pad.Shape = Enum.PartType.Cylinder
                pad.Material = Enum.Material.SmoothPlastic
                pad.Color = padColor
                pad.Transparency = 0.25
                pad.Size = Vector3.new(0.12, 1.15, 1.15)

                local body = CreateNonBlockingPart(folder, category .. "_Body_" .. i)
                body.Material = Enum.Material.Neon
                body.Color = figColor
                body.Transparency = 0.15
                body.Size = Vector3.new(0.48, 0.72, 0.3)

                local head = CreateNonBlockingPart(folder, category .. "_Head_" .. i)
                head.Shape = Enum.PartType.Ball
                head.Material = Enum.Material.Neon
                head.Color = figColor
                head.Transparency = 0.1
                head.Size = Vector3.new(0.4, 0.4, 0.4)

                fig = { Pad = pad, Body = body, Head = head }
                poolList[i] = fig
            end

            fig.Pad.Transparency = showThisFigure and 0.25 or 1
            fig.Body.Transparency = showThisFigure and 0.15 or 1
            fig.Head.Transparency = showThisFigure and 0.1 or 1

            fig.Pad.CFrame = CFrame.new(pos + Vector3.new(0, 0.09, 0)) * CFrame.Angles(0, 0, math.rad(90))
            fig.Body.CFrame = CFrame.new(pos + Vector3.new(0, 0.75, 0))
            fig.Head.CFrame = CFrame.new(pos + Vector3.new(0, 1.65, 0))
        end

        for i = #positions + 1, #poolList do
            local fig = poolList[i]
            if fig and fig.Pad.Parent then
                fig.Pad.Transparency = 1
                fig.Body.Transparency = 1
                fig.Head.Transparency = 1
            end
        end
    end

    local function HideAllHolograms()
        if HologramPool.Folder then
            pcall(function() HologramPool.Folder:Destroy() end)
            HologramPool.Folder = nil
            State.HologramFolder = nil
        end
    end

    local function FindLowGroundFarmCenter(farmPct, refGroundY)
        RefreshRayFilter(true)
        local trackPt, _, rightVec = EvaluateMainRoadAtPercent(farmPct)
        local sideOffset = State.MainRoadHalfWidth + 9.5

        for _, side in ipairs({ 1, -1 }) do
            local candidate = Vector3.new(
                trackPt.X + rightVec.X * sideOffset * side,
                refGroundY,
                trackPt.Z + rightVec.Z * sideOffset * side
            )
            if not GetSurfacePointOnTerrainHill(candidate.X, candidate.Z) and not IsPointOverlappingMainRoad(candidate) then
                local validPos, isOk = ValidateGroundPlacementPoint(candidate, refGroundY)
                if isOk and validPos then
                    return validPos
                end
            end
        end

        return Vector3.new(
            trackPt.X + rightVec.X * sideOffset,
            refGroundY,
            trackPt.Z + rightVec.Z * sideOffset
        )
    end

    local function UpdateRealTimeHologramPositions()
        if #State.MainRoadSegments == 0 then
            BuildMainRoadPathFromWorkspace()
        end
        if #State.HillPartInstances == 0 then
            ScanTerrainHillParts()
        end
        RefreshRayFilter(true)

        local showHolo = Options.ShowUnitPlacementHologram and Options.ShowUnitPlacementHologram.Value

        local placePct = (tonumber(Options.PlacementDistance and Options.PlacementDistance.Value) or 50) / 100
        local farmPct = (tonumber(Options.FarmPlacementDistance and Options.FarmPlacementDistance.Value) or 15) / 100
        local groundAreaPct = (tonumber(Options.GroundAreaPercent and Options.GroundAreaPercent.Value) or 70) / 100
        local hillAreaPct = (tonumber(Options.HillAreaPercent and Options.HillAreaPercent.Value) or 70) / 100
        local pathOffset = tonumber(Options.PathOffset and Options.PathOffset.Value) or 3.5
        local hillDensity = (tonumber(Options.HillDensity and Options.HillDensity.Value) or 100) / 100

        local groundRadius = 8.0 + (17.0 * groundAreaPct)
        local hillRadius = 6.0 + (22.0 * hillAreaPct)
        local farmRadius = 9.0
        local slotSpacing = math.clamp(tonumber(Options.HologramSpacing and Options.HologramSpacing.Value) or 1.2, 0.8, 4.0)

        local roadPoint, _, rightVec = EvaluateMainRoadAtPercent(placePct)
        local refGroundY = State.MainRoadBaseY ~= 0 and State.MainRoadBaseY or roadPoint.Y
        local hitRoadGround, hitInst = SafeRaycastGround(roadPoint, 8, -20)
        if hitInst and math.abs(hitRoadGround.Y - refGroundY) <= 4.5 then
            refGroundY = hitRoadGround.Y
        end
        local groundCenter = Vector3.new(roadPoint.X, refGroundY, roadPoint.Z) + rightVec * pathOffset

        local hillCenter = FindClosestPointOnTerrainHill(groundCenter)
        local hasValidHill = (hillCenter ~= nil)
        if not hillCenter then
            hillCenter = groundCenter - (rightVec * (groundRadius + hillRadius + 4.0)) + Vector3.new(0, 4.0, 0)
        end

        local farmCenter = FindLowGroundFarmCenter(farmPct, refGroundY)

        local newGroundSlots = {}
        local newHillSlots = {}
        local newFarmSlots = {}

        local roadHalfWidth = math.max(tonumber(State.MainRoadHalfWidth) or 4.0, 2.0)
        local roadClearance = roadHalfWidth + 0.25

        local function GetNearestPathDistance(pos)
            local nearestPathDistance = math.huge
            for _, seg in ipairs(State.MainRoadSegments) do
                local d = PointToSegmentDist2D(pos, seg.a, seg.b)
                if d < nearestPathDistance then
                    nearestPathDistance = d
                end
            end
            return nearestPathDistance
        end

        for dx = -groundRadius, groundRadius, slotSpacing do
            for dz = -groundRadius, groundRadius, slotSpacing do
                if (dx * dx + dz * dz) <= (groundRadius * groundRadius) then
                    local samplePos = Vector3.new(groundCenter.X + dx, refGroundY, groundCenter.Z + dz)
                    if GetNearestPathDistance(samplePos) >= roadClearance
                        and not GetSurfacePointOnTerrainHill(samplePos.X, samplePos.Z) then
                        local validPos, isOk = ValidateGroundPlacementPoint(samplePos, refGroundY)
                        if isOk and validPos then
                            table.insert(newGroundSlots, validPos)
                        end
                    end
                end
            end
        end

        table.sort(newGroundSlots, function(a, b)
            return GetNearestPathDistance(a) < GetNearestPathDistance(b)
        end)

        if hasValidHill then
            local hillSpacing = math.max(0.8, slotSpacing / math.max(hillDensity, 0.35))
            for dx = -hillRadius, hillRadius, hillSpacing do
                for dz = -hillRadius, hillRadius, hillSpacing do
                    if (dx * dx + dz * dz) <= (hillRadius * hillRadius) then
                        local surfacePt = GetSurfacePointOnTerrainHill(hillCenter.X + dx, hillCenter.Z + dz)
                        if surfacePt then
                            table.insert(newHillSlots, surfacePt)
                        end
                    end
                end
            end
            if #newHillSlots == 0 then
                table.insert(newHillSlots, hillCenter)
            end
        end

        for dx = -farmRadius, farmRadius, slotSpacing * 1.1 do
            for dz = -farmRadius, farmRadius, slotSpacing * 1.1 do
                if (dx * dx + dz * dz) <= (farmRadius * farmRadius) then
                    local samplePos = Vector3.new(farmCenter.X + dx, refGroundY, farmCenter.Z + dz)
                    if not IsPointOverlappingMainRoad(samplePos) and not GetSurfacePointOnTerrainHill(samplePos.X, samplePos.Z) then
                        local validPos, isOk = ValidateGroundPlacementPoint(samplePos, refGroundY)
                        if isOk and validPos then
                            table.insert(newFarmSlots, validPos)
                        end
                    end
                end
            end
        end

        State.CalculatedSlots.Ground = newGroundSlots
        State.CalculatedSlots.Hill = newHillSlots
        State.CalculatedSlots.Farm = newFarmSlots

        SafeUpdateParagraph(
            AIStatusPara,
            nil,
            string.format(
                "Road [%s%s]: %d ชิ้น | Hill: %d ชิ้น | ระยะ: %d%% | พื้น (ชมพู): %d | เนิน (เหลือง): %d | ฟาร์ม (เขียว %d%%): %d",
                tostring(State.ActiveRoadLabel),
                State.EnemyVerifiedRoad and " ✅EnemyLocked" or "",
                #State.MainPartInstances,
                #State.HillPartInstances,
                math.floor(placePct * 100 + 0.5),
                #newGroundSlots,
                #newHillSlots,
                math.floor(farmPct * 100 + 0.5),
                #newFarmSlots
            )
        )

        if not showHolo then
            HideAllHolograms()
            return
        end

        local folder = EnsureHologramPoolFolder()

        if #HologramPool.PathBeams ~= #State.MainRoadSegments then
            for _, oldBeam in ipairs(HologramPool.PathBeams) do
                pcall(function() oldBeam:Destroy() end)
            end
            HologramPool.PathBeams = {}
            for i, s in ipairs(State.MainRoadSegments) do
                local beam = CreateNonBlockingPart(folder, "MainRoadBeam_" .. i)
                beam.Material = Enum.Material.Neon
                beam.Color = Color3.fromRGB(0, 225, 255)
                beam.Transparency = 0.3
                beam.Size = Vector3.new(0.65, 0.22, s.len)
                beam.CFrame = CFrame.lookAt((s.a + s.b) * 0.5 + Vector3.new(0, 0.22, 0), s.b + Vector3.new(0, 0.22, 0))
                table.insert(HologramPool.PathBeams, beam)
            end
        end

        HologramPool.GroundDisk.Size = Vector3.new(0.3, groundRadius * 2, groundRadius * 2)
        HologramPool.GroundDisk.CFrame = CFrame.new(groundCenter + Vector3.new(0, 0.16, 0)) * CFrame.Angles(0, 0, math.rad(90))
        if HologramPool.GroundLabel then
            HologramPool.GroundLabel.Text = string.format("⚔️ GROUND [%s] (%d%%)", tostring(State.ActiveRoadLabel), math.floor(placePct * 100 + 0.5))
        end

        if hasValidHill then
            HologramPool.HillDisk.Transparency = 0.55
            HologramPool.HillDisk.Size = Vector3.new(0.35, hillRadius * 2, hillRadius * 2)
            HologramPool.HillDisk.CFrame = CFrame.new(hillCenter + Vector3.new(0, 0.18, 0)) * CFrame.Angles(0, 0, math.rad(90))
            if HologramPool.HillLabel then
                HologramPool.HillLabel.Text = string.format("⛰️ HILL [_terrain.hill] (Area %d%%)", math.floor(hillAreaPct * 100 + 0.5))
            end
        else
            HologramPool.HillDisk.Transparency = 1
            if HologramPool.HillLabel then
                HologramPool.HillLabel.Text = ""
            end
        end

        HologramPool.FarmDisk.Size = Vector3.new(0.3, farmRadius * 2, farmRadius * 2)
        HologramPool.FarmDisk.CFrame = CFrame.new(farmCenter + Vector3.new(0, 0.16, 0)) * CFrame.Angles(0, 0, math.rad(90))
        if HologramPool.FarmLabel then
            HologramPool.FarmLabel.Text = string.format("💰 FARM GROUND (%d%%)", math.floor(farmPct * 100 + 0.5))
        end

        SetPooledFigures("Ground", newGroundSlots, Color3.fromRGB(255, 50, 215), Color3.fromRGB(220, 90, 210))
        SetPooledFigures("Hill", newHillSlots, Color3.fromRGB(255, 240, 75), Color3.fromRGB(240, 210, 80))
        SetPooledFigures("Farm", newFarmSlots, Color3.fromRGB(65, 255, 130), Color3.fromRGB(80, 220, 140))
    end

    local hologramDirty = true
    local function RequestHologramRefresh()
        hologramDirty = true
    end

    Tabs.AI:AddToggle("AutoTowerPlacement", {
        Title = "Auto Tower Placement (วางตัวตามตำแหน่งโฮโลแกรมอัตโนมัติ)",
        Default = false,
        Callback = function()
            RequestHologramRefresh()
            AutoSaveUserConfig()
        end
    })

    Tabs.AI:AddToggle("ShowUnitPlacementHologram", {
        Title = "Show Unit Placement Hologram (แสดงโฮโลแกรมเกาะตาม _road & _terrain.hill)",
        Default = false,
        Callback = function()
            RequestHologramRefresh()
            AutoSaveUserConfig()
        end
    })

    Tabs.AI:AddToggle("ShowMacroPlacementMarkersAI", {
        Title = "Show Macro Unit Markers (แสดงจุดสีบนพื้นตามตำแหน่งยูนิตในมาโคร)",
        Description = "แสดงวงแหวนและคริสตัลบอกจุดวางยูนิตตามไฟล์มาโคร (แยกจากโฮโลแกรม AI)",
        Default = false,
        Callback = function(val)
            if Options.ShowMacroPlacementMarkers and Options.ShowMacroPlacementMarkers.Value ~= val then
                pcall(function() Options.ShowMacroPlacementMarkers:SetValue(val) end)
            end
            pcall(UpdateMacroGroundMarkers)
            AutoSaveUserConfig()
        end
    })

    Tabs.AI:AddSlider("PlacementDistance", {
        Title = "Placement Distance % (0% = ฐาน Base | 50% = กลางทาง | 100% = จุดเกิดมอน)",
        Description = "ลากเพื่อเลื่อนโฮโลแกรมพื้นราบและเนินเขา (_terrain.hill) ไปตามทางเดินแบบ Real-Time",
        Default = 50,
        Min = 0,
        Max = 100,
        Rounding = 0,
        Callback = function()
            RequestHologramRefresh()
            AutoSaveUserConfig()
        end
    })

    Tabs.AI:AddSlider("GroundAreaPercent", {
        Title = "Ground Area % (ขนาดวงกลมวางตัวพื้นราบ - หุ่นสีชมพู)",
        Description = "ขยายหรือลดขนาดวงกลมพื้นราบแบบ Real-Time",
        Default = 70,
        Min = 20,
        Max = 100,
        Rounding = 0,
        Callback = function()
            RequestHologramRefresh()
            AutoSaveUserConfig()
        end
    })

    Tabs.AI:AddSlider("HillAreaPercent", {
        Title = "Hill Area % (ขนาดวงกลมวางตัวเนินสูงบน workspace._terrain.hill - หุ่นสีเหลือง)",
        Description = "ขยายหรือลดขนาดวงกลมบนพาร์ท workspace._terrain.hill แบบ Real-Time",
        Default = 70,
        Min = 20,
        Max = 100,
        Rounding = 0,
        Callback = function()
            RequestHologramRefresh()
            AutoSaveUserConfig()
        end
    })

    Tabs.AI:AddToggle("ShowNextPlacementOnly", {
        Title = "Show Next Placement Only (แสดงโฮโลแกรมจุดแรกเท่านั้น)",
        Description = "ลดความรกโดยแสดงจุดแรกของแต่ละประเภทเท่านั้น",
        Default = false,
        Callback = function() RequestHologramRefresh(); AutoSaveUserConfig() end
    })

    Tabs.AI:AddSlider("PathOffset", {
        Title = "Path Offset (studs) — ระยะออกจากทางเดิน",
        Description = "เลื่อนจุดโฮโลแกรมออกด้านข้างจากเส้นทาง; ค่ามากขึ้นจะห่างถนนมากขึ้น",
        Default = 3.5, Min = 1, Max = 12, Rounding = 1,
        Callback = function() RequestHologramRefresh(); AutoSaveUserConfig() end
    })

    Tabs.AI:AddSlider("HologramSpacing", {
        Title = "Hologram Spacing (studs) — ระยะห่างจุด",
        Description = "ลดค่าเพื่อให้จุดเรียงถี่ขึ้น",
        Default = 1.2, Min = 0.8, Max = 4, Rounding = 1,
        Callback = function() RequestHologramRefresh(); AutoSaveUserConfig() end
    })

    Tabs.AI:AddSlider("HillDensity", {
        Title = "Hill Density % — ความถี่จุดบน Hill",
        Description = "เพิ่มค่าเพื่อสร้างจุด Hill ถี่ขึ้น โดยแยกจากความถี่ Ground",
        Default = 100, Min = 50, Max = 200, Rounding = 0,
        Callback = function() RequestHologramRefresh(); AutoSaveUserConfig() end
    })

    Tabs.AI:AddSlider("FarmPlacementDistance", {
        Title = "Farm Placement Distance % (ตำแหน่งวงกลมฟาร์มพื้นล่าง - หุ่นสีเขียว)",
        Description = "เลื่อนวงกลมวางตัวฟาร์ม (บังคับอยู่เฉพาะพื้นราบด้านล่าง 100% ไม่ขึ้น Hill)",
        Default = 15,
        Min = 0,
        Max = 100,
        Rounding = 0,
        Callback = function()
            RequestHologramRefresh()
            AutoSaveUserConfig()
        end
    })

    Tabs.AI:AddButton({
        Title = "Rescan _road & _terrain.hill (สแกนถนนและเนินเขาใหม่ทันที)",
        Description = "วิเคราะห์โครงสร้างถนนใหม่และกรองพาร์ทตกแต่งออกอัตโนมัติ",
        Callback = function()
            HologramPool.PathBeams = {}
            pcall(BuildMainRoadPathFromWorkspace)
            pcall(VerifyAndLockRoadWithEnemies)
            pcall(UpdateRealTimeHologramPositions)
            Fluent:Notify({
                Title = "Hologram Refreshed",
                Content = string.format(
                    "เลือกสายทางเดิน [%s] (%d ชิ้น) | เนิน (%d ชิ้น)",
                    tostring(State.ActiveRoadLabel),
                    #State.MainPartInstances,
                    #State.HillPartInstances
                ),
                Duration = 3
            })
        end
    })

    local lastStateSnapshot = {
        show = nil,
        placeDist = nil,
        groundArea = nil,
        hillArea = nil,
        farmDist = nil,
        pathOffset = nil,
        spacing = nil,
        hillDensity = nil,
        showNextOnly = nil
    }

    AddConnection(RunService.RenderStepped, function()
        local curShow = Options.ShowUnitPlacementHologram and Options.ShowUnitPlacementHologram.Value or false
        local curPlace = Options.PlacementDistance and Options.PlacementDistance.Value or 50
        local curGround = Options.GroundAreaPercent and Options.GroundAreaPercent.Value or 70
        local curHill = Options.HillAreaPercent and Options.HillAreaPercent.Value or 70
        local curFarm = Options.FarmPlacementDistance and Options.FarmPlacementDistance.Value or 15
        local curOffset = Options.PathOffset and Options.PathOffset.Value or 3.5
        local curSpacing = Options.HologramSpacing and Options.HologramSpacing.Value or 1.2
        local curHillDensity = Options.HillDensity and Options.HillDensity.Value or 100
        local curShowNextOnly = Options.ShowNextPlacementOnly and Options.ShowNextPlacementOnly.Value or false

        if curShow ~= lastStateSnapshot.show
            or curPlace ~= lastStateSnapshot.placeDist
            or curGround ~= lastStateSnapshot.groundArea
            or curHill ~= lastStateSnapshot.hillArea
            or curFarm ~= lastStateSnapshot.farmDist
            or curOffset ~= lastStateSnapshot.pathOffset
            or curSpacing ~= lastStateSnapshot.spacing
            or curHillDensity ~= lastStateSnapshot.hillDensity
            or curShowNextOnly ~= lastStateSnapshot.showNextOnly then

            lastStateSnapshot.show = curShow
            lastStateSnapshot.placeDist = curPlace
            lastStateSnapshot.groundArea = curGround
            lastStateSnapshot.hillArea = curHill
            lastStateSnapshot.farmDist = curFarm
            lastStateSnapshot.pathOffset = curOffset
            lastStateSnapshot.spacing = curSpacing
            lastStateSnapshot.hillDensity = curHillDensity
            lastStateSnapshot.showNextOnly = curShowNextOnly
            hologramDirty = true
        end

        if hologramDirty then
            hologramDirty = false
            pcall(UpdateRealTimeHologramPositions)
        end

        if (Options.ShowMacroPlacementMarkers and Options.ShowMacroPlacementMarkers.Value)
            or (Options.ShowMacroPlacementMarkersAI and Options.ShowMacroPlacementMarkersAI.Value) then
            pcall(UpdateMacroGroundMarkers)
        end
    end)

    task.spawn(function()
        local lastRoadDescendants = 0
        local lastHillDescendants = 0
        while true do
            task.wait(1.5)
            local roadRoot = Workspace:FindFirstChild("_road") or Workspace:FindFirstChild("road")
            local terrainFolder = Workspace:FindFirstChild("_terrain") or Workspace:FindFirstChild("terrain")
            local hillFolder = terrainFolder and (terrainFolder:FindFirstChild("hill") or terrainFolder:FindFirstChild("Hill"))

            local curRoadCount = roadRoot and #roadRoot:GetDescendants() or 0
            local curHillCount = hillFolder and #hillFolder:GetDescendants() or 0

            if curRoadCount ~= lastRoadDescendants or curHillCount ~= lastHillDescendants or #State.MainRoadSegments == 0 then
                lastRoadDescendants = curRoadCount
                lastHillDescendants = curHillCount
                HologramPool.PathBeams = {}
                pcall(BuildMainRoadPathFromWorkspace)
                RequestHologramRefresh()
            end

            if not State.EnemyVerifiedRoad then
                local ok, switched = pcall(VerifyAndLockRoadWithEnemies)
                if ok and switched then
                    HologramPool.PathBeams = {}
                    RequestHologramRefresh()
                end
            end
        end
    end)

    local function PickAvailableHologramSlot(slotList, startIdx)
        if not slotList or #slotList == 0 then return nil, startIdx end
        for offset = 0, #slotList - 1 do
            local idx = ((startIdx - 1 + offset) % #slotList) + 1
            local candidatePos = slotList[idx]
            if not FindMyUnitNearPosition(candidatePos, 2.8) then
                return candidatePos, idx + 1
            end
        end
        local fallbackPos = slotList[((startIdx - 1) % #slotList) + 1]
        return fallbackPos, startIdx + 1
    end

    -- ลูป Auto Tower Placement: เช็คราคาค่าวางและค่าอัปเกรดก่อนส่ง Remote ทุกครั้ง (ป้องกัน Error 267)
    task.spawn(function()
        local gIdx, hIdx, fIdx = 1, 1, 1
        while true do
            task.wait(1.0)
            local is_ingame = Workspace:FindFirstChild("_UNITS") ~= nil
            if Options.AutoTowerPlacement and Options.AutoTowerPlacement.Value and is_ingame and not (Options.PlayBackMacro and Options.PlayBackMacro.Value) then
                if #State.CalculatedSlots.Ground == 0 then
                    pcall(UpdateRealTimeHologramPositions)
                    task.wait(0.2)
                end

                local cash = GetPlayerCash()
                local equippedList = GetEquippedUnitsDetailed()
                for _, unitInfo in ipairs(equippedList) do
                    if not (Options.AutoTowerPlacement and Options.AutoTowerPlacement.Value) then break end

                    local deployCost = LookupUnitCostByIdOrName(unitInfo.unit_id, unitInfo.unit_name, 0) or 400
                    local placedCount = CountMyPlacedUnitsByIdOrUUID(unitInfo.unit_id, unitInfo.uuid)
                    if GetPlayerCash() >= deployCost and placedCount < (unitInfo.max_cap or 4) then
                        local pType = unitInfo.placement_type
                        local targetPos = nil

                        if pType == "Farm" and #State.CalculatedSlots.Farm > 0 then
                            targetPos, fIdx = PickAvailableHologramSlot(State.CalculatedSlots.Farm, fIdx)
                        elseif pType == "Hill" and #State.CalculatedSlots.Hill > 0 then
                            targetPos, hIdx = PickAvailableHologramSlot(State.CalculatedSlots.Hill, hIdx)
                        elseif #State.CalculatedSlots.Ground > 0 then
                            targetPos, gIdx = PickAvailableHologramSlot(State.CalculatedSlots.Ground, gIdx)
                        end

                        if targetPos and unitInfo.uuid then
                            InvokeServer("spawn_unit", unitInfo.uuid, BuildPlacementCFrame(targetPos))
                            task.wait(0.35)
                        end
                    end
                end

                local unitsFolder = Workspace:FindFirstChild("_UNITS")
                if unitsFolder then
                    local curCash = GetPlayerCash()
                    for _, u in ipairs(unitsFolder:GetChildren()) do
                        local st = u:FindFirstChild("_stats")
                        if st and st:FindFirstChild("player") and st.player.Value == LocalPlayer then
                            local upgLvl = (st:FindFirstChild("upgrade") and tonumber(st.upgrade.Value)) or 0
                            local idVal = st:FindFirstChild("id") and tostring(st.id.Value) or u.Name
                            local upgCost = (st:FindFirstChild("upgrade_cost") and tonumber(st.upgrade_cost.Value))
                                or LookupUnitCostByIdOrName(idVal, u.Name, upgLvl + 1)
                                or 500
                            if upgCost > 0 and curCash >= upgCost then
                                InvokeServer("upgrade_unit_ingame", u)
                                task.wait(0.35)
                                break
                            end
                        end
                    end
                end
            end
        end
    end)
end

---------------------------------------------------------------------
-- TAB 4: GAME (Anti-Spam Session Loader, Skills & Wave Controls)
---------------------------------------------------------------------
do
    Tabs.Game:AddToggle("AutoCommander", { Title = "Auto Commander (Erwin)", Default = false, Callback = function() AutoSaveUserConfig() end })
    Tabs.Game:AddToggle("AutoWindDragon", { Title = "Auto Wind Dragon (Wendy)", Default = false, Callback = function() AutoSaveUserConfig() end })
    Tabs.Game:AddToggle("AutoElfy", { Title = "Auto Elfy", Default = false, Callback = function() AutoSaveUserConfig() end })

    Tabs.Game:AddSlider("SelectWave", {
        Title = "Select Wave",
        Description = "เวฟเป้าหมายสำหรับ Auto Sell / Auto Leave",
        Default = 30,
        Min = 1,
        Max = 150,
        Rounding = 0,
        Callback = function() AutoSaveUserConfig() end
    })

    Tabs.Game:AddToggle("AutoSell", { Title = "Auto Sell (All Units)", Default = false, Callback = function() AutoSaveUserConfig() end })
    Tabs.Game:AddToggle("AutoLeave", { Title = "Auto Leave", Default = false, Callback = function() AutoSaveUserConfig() end })
    Tabs.Game:AddToggle("SellBeforeLeave", {
        Title = "Sell Before Leave (Sequential Flow)",
        Description = "ขายยูนิตทั้งหมดก่อน รอ 1.5 วินาที แล้วออกด่าน",
        Default = true,
        Callback = function() AutoSaveUserConfig() end
    })

    Tabs.Game:AddToggle("AutoSkip", { Title = "Auto Skip Wave (โหวตข้ามเวฟอัตโนมัติ)", Default = true, Callback = function() AutoSaveUserConfig() end })
    Tabs.Game:AddToggle("AutoReplay", { Title = "Auto Replay (กดเล่นซ้ำอัตโนมัติ ไม่ใช้เมาส์)", Default = false, Callback = function() AutoSaveUserConfig() end })
    Tabs.Game:AddToggle("AutoNext", { Title = "Auto Next (กดไปด่านถัดไปอัตโนมัติ ไม่ใช้เมาส์)", Default = false, Callback = function() AutoSaveUserConfig() end })
    Tabs.Game:AddToggle("AutoBackToLobby", { Title = "Auto Back to Lobby (จบเกมกลับล็อบบี้)", Default = false, Callback = function() AutoSaveUserConfig() end })

    task.spawn(function()
        while true do
            task.wait(3.0)
            local unitsFolder = Workspace:FindFirstChild("_UNITS")
            if unitsFolder then
                for _, unit in ipairs(unitsFolder:GetChildren()) do
                    local st = unit:FindFirstChild("_stats")
                    if st and st:FindFirstChild("player") and st.player.Value == LocalPlayer then
                        local uName = unit.Name:lower()
                        local idVal = st:FindFirstChild("id") and tostring(st.id.Value):lower() or ""

                        if (Options.AutoCommander and Options.AutoCommander.Value) and (uName:find("erwin") or uName:find("commander") or idVal:find("erwin")) then
                            InvokeServer("use_active_attack", unit)
                        end
                        if (Options.AutoWindDragon and Options.AutoWindDragon.Value) and (uName:find("wendy") or uName:find("wind") or idVal:find("wendy")) then
                            InvokeServer("use_active_attack", unit)
                        end
                        if (Options.AutoElfy and Options.AutoElfy.Value) and (uName:find("elfy") or idVal:find("elfy")) then
                            InvokeServer("use_active_attack", unit)
                        end
                    end
                end
            end
        end
    end)

    task.spawn(function()
        local executedWaveAction = false
        local handledFinishedSession = false
        local sentLoadedSession = false
        local lastVoteStartAttempt = 0
        local lastSkippedWave = -1

        while true do
            task.wait(1)
            local is_ingame = Workspace:FindFirstChild("_UNITS") ~= nil

            if not is_ingame then
                handledFinishedSession = false
                executedWaveAction = false
                sentLoadedSession = false
                lastSkippedWave = -1
            else
                if Workspace:FindFirstChild("_waves_started") and not Workspace._waves_started.Value then
                    if not sentLoadedSession then
                        sentLoadedSession = true
                        -- รอ 8 วินาทีให้ตัวเกมโหลดฉากและส่ง client_loaded_session ของเกมเองให้เสร็จก่อน
                        task.wait(1.0)
                        if Workspace:FindFirstChild("_waves_started") and not Workspace._waves_started.Value then
                            InvokeServer("vote_start")
                        end
                    end
                end

                local currentWave = GetCurrentWave()
                local dataFolder = Workspace:FindFirstChild("_DATA")
                local finishedValue = dataFolder and dataFolder:FindFirstChild("GameFinished")
                local finished = finishedValue and finishedValue.Value == true

                -- โหวตข้ามเวฟแค่ครั้งเดียวต่อเวฟ และไม่ยิงตอนจบเกมแล้ว (ป้องกัน Error 267)
                if Options.AutoSkip and Options.AutoSkip.Value and not finished and currentWave > 0 and currentWave ~= lastSkippedWave then
                    lastSkippedWave = currentWave
                    InvokeServer("vote_wave_skip")
                end

                local targetWave = Options.SelectWave and Options.SelectWave.Value or 30

                if currentWave >= targetWave and not executedWaveAction then
                    executedWaveAction = true
                    local doSell = Options.AutoSell and Options.AutoSell.Value
                    local doLeave = Options.AutoLeave and Options.AutoLeave.Value
                    local sequential = Options.SellBeforeLeave and Options.SellBeforeLeave.Value

                    if doSell then
                        local placedFolder = Workspace:FindFirstChild("_UNITS")
                        if placedFolder then
                            for _, unit in ipairs(placedFolder:GetChildren()) do
                                local st = unit:FindFirstChild("_stats")
                                if st and st:FindFirstChild("player") and st.player.Value == LocalPlayer then
                                    InvokeServer("sell_unit_ingame", unit)
                                    task.wait(0.15)
                                end
                            end
                        end
                        if sequential and doLeave then
                            task.wait(1.5)
                        end
                    end

                    if doLeave then
                        InvokeServer("teleport_back_to_lobby")
                    end
                elseif currentWave < targetWave then
                    executedWaveAction = false
                end

                if not finished then
                    handledFinishedSession = false
                elseif not handledFinishedSession then
                    handledFinishedSession = true
                    -- รีเซ็ตสถานะเพื่อให้รอบถัดไปพร้อมทำงานใหม่ทันทีเมื่อกด Replay
                    sentLoadedSession = false
                    lastSkippedWave = -1

                    local pgui = LocalPlayer:FindFirstChild("PlayerGui")
                    local resultsUI = pgui and pgui:FindFirstChild("ResultsUI")

                    if resultsUI and not (Options.AutoReplay and Options.AutoReplay.Value) then
                        local holder = resultsUI:FindFirstChild("Holder")
                        if holder and holder.Visible then
                            local holderBtns = holder:FindFirstChild("Buttons")
                            local summaryNextBtn = holderBtns and holderBtns:FindFirstChild("Next")
                            if summaryNextBtn then
                                FireGuiButton(summaryNextBtn)
                            end
                        end

                        local finishedFrame = resultsUI:FindFirstChild("Finished")
                        if finishedFrame and finishedFrame.Visible then
                            if Options.AutoNext and Options.AutoNext.Value then
                                local nextStageBtn = finishedFrame:FindFirstChild("Next") or finishedFrame:FindFirstChild("NextLevel")
                                if nextStageBtn then FireGuiButton(nextStageBtn) end
                            end
                        end
                    end

                    if Options.AutoReplay and Options.AutoReplay.Value then
                        task.wait(1)
                        if Options.AutoReplay and Options.AutoReplay.Value then
                            InvokeServer("set_game_finished_vote", "replay")
                        end
                    elseif Options.AutoNext and Options.AutoNext.Value then
                        task.wait(2)
                        if Options.AutoNext and Options.AutoNext.Value then
                            InvokeServer("set_game_finished_vote", "next")
                        end
                    elseif Options.AutoBackToLobby and Options.AutoBackToLobby.Value then
                        task.wait(2)
                        InvokeServer("teleport_back_to_lobby")
                    end
                end
            end
        end
    end)
end

---------------------------------------------------------------------
-- TAB 5: NOTIFICATION (Discord Webhook)
---------------------------------------------------------------------
do
    Tabs.Notification:AddInput("WebhookURL", {
        Title = "Webhook URL",
        Default = "",
        Placeholder = "https://discord.com/api/webhooks/...",
        Finished = false,
        Callback = function() AutoSaveUserConfig() end
    })

    Tabs.Notification:AddInput("PingRoleID", {
        Title = "Ping Role ID",
        Default = "",
        Placeholder = "123456789012345678 (Optional)",
        Finished = false,
        Callback = function() AutoSaveUserConfig() end
    })

    Tabs.Notification:AddInput("BotName", {
        Title = "Custom Bot Name",
        Default = "Anime Adventures Architect",
        Finished = false,
        Callback = function() AutoSaveUserConfig() end
    })

    Tabs.Notification:AddInput("AvatarURL", {
        Title = "Avatar Icon URL",
        Default = "https://i.imgur.com/83pZshm.png",
        Finished = false,
        Callback = function() AutoSaveUserConfig() end
    })

    Tabs.Notification:AddToggle("DiscordNotification", {
        Title = "Discord Webhook Notification",
        Default = true,
        Callback = function() AutoSaveUserConfig() end
    })

    local function SendDiscordEmbed(title, description, color, fields)
        local url = Options.WebhookURL and Options.WebhookURL.Value
        if not url or url == "" then return end

        local roleTag = ""
        local roleId = Options.PingRoleID and Options.PingRoleID.Value
        if roleId and roleId ~= "" then
            roleTag = "<@&" .. roleId .. ">"
        end

        local payload = {
            username = (Options.BotName and Options.BotName.Value) or "Anime Adventures Architect",
            avatar_url = (Options.AvatarURL and Options.AvatarURL.Value) or "",
            content = roleTag,
            embeds = {{
                title = title,
                description = description,
                color = color,
                fields = fields,
                footer = { text = "Player: " .. USER_CONFIG_NAME .. " | " .. os.date("%X") },
                timestamp = DateTime.now():ToIsoDate()
            }}
        }

        SendHttpRequest({
            Url = url,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(payload)
        })
    end

    Tabs.Notification:AddButton({
        Title = "Testing Notification",
        Description = "ส่งข้อความทดสอบไปยัง Discord Webhook",
        Callback = function()
            SendDiscordEmbed(
                "🔔 Webhook Test Successful!",
                "TD Script Architect เชื่อมต่อกับบัญชี **" .. USER_CONFIG_NAME .. "** เรียบร้อยแล้ว",
                0x57F287,
                {
                    { name = "User", value = USER_CONFIG_NAME, inline = true },
                    { name = "Wave", value = tostring(GetCurrentWave()), inline = true },
                    { name = "Status", value = "Active", inline = true }
                }
            )
            Fluent:Notify({ Title = "Notification", Content = "ส่งข้อความทดสอบไปยัง Discord แล้ว", Duration = 4 })
        end
    })

    task.spawn(function()
        local dispatchedEndScreen = false
        while true do
            task.wait(1.5)
            local is_ingame = Workspace:FindFirstChild("_UNITS") ~= nil
            if Options.DiscordNotification and Options.DiscordNotification.Value and is_ingame then
                local dataFolder = Workspace:FindFirstChild("_DATA")
                local finished = dataFolder and dataFolder:FindFirstChild("GameFinished") and dataFolder.GameFinished.Value

                if finished and not dispatchedEndScreen then
                    dispatchedEndScreen = true
                    SendDiscordEmbed(
                        "🏆 Match Finished (" .. USER_CONFIG_NAME .. ")",
                        "จบการเล่นในด่าน **Anime Adventures**",
                        0x57F287,
                        {
                            { name = "🌊 Final Wave", value = tostring(GetCurrentWave()), inline = true },
                            { name = "💰 Final Cash", value = tostring(GetPlayerCash()), inline = true }
                        }
                    )
                elseif not finished then
                    dispatchedEndScreen = false
                end
            end
        end
    end)
end

---------------------------------------------------------------------
-- TAB 6: SETTINGS & AUTO-SAVE PER USERNAME
---------------------------------------------------------------------
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MacroRecording", "MacroFileName" })

InterfaceManager:SetFolder("FluentScriptHub")
SaveManager:SetFolder(CONFIG_FOLDER)

Tabs.Settings:AddParagraph({
    Title = "Auto-Config Profile (แยกตามชื่อผู้เล่นอัตโนมัติ)",
    Content = "โปรไฟล์ปัจจุบัน: " .. USER_CONFIG_NAME .. ".json\nทุกการปรับปุ่มใน UI จะถูกบันทึกเข้าชื่อตัวละครนี้โดยอัตโนมัติ"
})

InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)

pcall(function()
    local userCfgPath = CONFIG_FOLDER .. "/settings/" .. USER_CONFIG_NAME .. ".json"
    if typeof(isfile) == "function" and isfile(userCfgPath) then
        SaveManager:Load(USER_CONFIG_NAME)
    else
        SaveManager:LoadAutoloadConfig()
        SaveManager:Save(USER_CONFIG_NAME)
    end
end)

task.spawn(function()
    task.wait(0.5)
    if Options.JoinWorld and not WorldNameToIdMap[tostring(Options.JoinWorld.Value or "")] then
        pcall(function()
            Options.JoinWorld:SetValue(DynamicWorldNames[1])
        end)
    end
    pcall(UpdateMacroGroundMarkers)
    State.IsBootingConfig = false
end)

Fluent:Notify({
    Title = "TD Script Architect",
    Content = string.format(
        "โหลด %d Worlds | ถนน [%s] (%d ชิ้น) | เนิน (%d ชิ้น) พร้อมใช้งาน!",
        #DynamicWorldNames,
        tostring(State.ActiveRoadLabel),
        #State.MainPartInstances,
        #State.HillPartInstances
    ),
    Duration = 5
})



