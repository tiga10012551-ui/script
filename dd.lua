--[[
    TD Script Architect - Anime Adventures (Kaitan Gem Farm + Real-Time Intercept Road Visualizer)
    File Name: Kaitan_GemFarm_Titan_AutoPlace_NoDuplicate_Road17_GemHUD_v47_StopAutoPlaceAfterAct6.luau
    v48 changes: minimize the UI at startup; refresh Act 6 completion on startup and force Auto Place OFF / Click to Place ON if both worlds are already complete; keep the guard during Infinite.
    [FULL REVISION & SYNTAX AUDIT]:
        - Fixed unclosed parenthesis syntax error (Expected ')' to close '(' at line ..., got 'end')
        - Ensured all task.spawn, pcall, and table definitions have matching closures
        - Retained all Kaitan Auto-Farm, World Skip memory, and UUID Quest Redeemer logic
        - Placement/Hologram spec coverage: 1.1 lane waypoint ordering, 1.2 raycast filtering without destructive map deletion, 2.1 zone marker + Billboard label, 4.1 route percentage interpolation, 4.2 surface-grid validation, 5 existing MiniDot renderer (no Template Dummy)
        - Retained Real-Time Monster Road Intercept Hologram (Zone Beacon + Boundary Ring + Mini Dots)
        - Physical _road parts are destroyed locally after caching route; separate neon route line remains visual-only
        - v31: Added Manual Click Placement mode using the existing spawn_unit path; v30 Auto Play remains intact
        - v32: Fixed Fluent dropdown updates by using SetValues first and showing update errors
        - v33: One-click manual placement; auto-cycles equipped units using game data caps
        - v33: Removes manual unit dropdown/refresh/cap slider and silent retry notices
        - v33: Re-raycasts the actual ground under clicked units and retries nearby points
        - v33: Moves placement geometry diagnostics into Advanced tab; adds placement profiles
        - v35-A: destroy local _road parts after caching route; exact clicked CFrame only; shrink _hitbox test retained
        - v39: require at least one equipped unit before World Skip, stage start, replay, or next; retry auto-equip after failures
        - v43: Auto Vote Start retries every 3.5 seconds while _waves_started is false; sends client_loaded_session once per session
        - v44: restore the local Animate script / Animator if missing or disabled; recover missing walk tracks while moving
        - v39: share the Kaitan status updater with the game-finished handler
]]

-- v48: minimize UI at startup; if both Act 6 worlds are already complete, force Auto Place OFF and Click to Place ON immediately.
-- ==================== [ INITIALIZATION & SAFETY GUARDS ] ====================
if not game:IsLoaded() then
    pcall(function()
        game.Loaded:Wait()
    end)
    local _Plrs = game:GetService("Players")
local _LP = _Plrs.LocalPlayer
repeat task.wait(0.5) until _LP and _LP.Character and _LP.Character:FindFirstChild("HumanoidRootPart") and _LP:FindFirstChild("PlayerGui")

-- ปรับเลขวินาทีตรงนี้ได้เลย (แนะนำ 8 - 12 วินาที เพื่อให้เกมเช็ค Anti-Cheat ตอนเข้าแมพให้เสร็จก่อน)
task.wait(5)
end

local getgenv = getgenv or function()
    return _G
end

-- ============================================================================
-- AA_CONFIG: ตั้งค่าหลักไว้ด้านบน แก้ตรงนี้ก่อนรันสคริปต์
-- หมายเหตุ: ตัวสคริปต์รุ่นนี้รองรับ Kaitan Gem Farm + ระบบเล่น/วางยูนิตเดิม
-- ยังไม่มีระบบ Fool's Hunt / AprilCoins แบบตัวอย่าง จึงไม่ใส่ตัวเลือกหลอกว่าใช้งานได้
-- ============================================================================
getgenv().AA_CONFIG = getgenv().AA_CONFIG or {
    -- ==================== MAIN ====================
    Mode = 1, -- 1 = Kaitan Gem Farm, 0 = ปิด Kaitan mode
    UI = {
        MinimizeOnStart = true,
        MinimizeKey = "RightControl",
    },

    -- ==================== AUTO FARM / MATCH ====================
    Farm = {
        Target = "namek_infinite", -- namek_infinite / aot_infinite
        GemGoal = 20000,
        AutoSkip = true,
        AutoReplay = true,
        AutoNext = false,
        AutoBackToLobby = false,
        AutoStart = false, -- Kaitan จัดการการเริ่มด่านเอง
    },

    -- ==================== AUTO PLAY / PLACEMENT ====================
    AutoPlay = {
        Enabled = true,              -- Auto Place Cluster ในด่านทั่วไป
        AutoPlaceInInfinite = true,  -- true = วางอัตโนมัติใน Infinite ด้วย
        ManualClickToPlace = false,  -- Click to Place; ควร false เมื่อใช้ Auto Place
        AutoUpgrade = true,
        UpgradeOrder = "Cheapest first", -- Cheapest first / Farms first / Strongest first
        UpgradeFirstUnit = "",      -- ชื่อยูนิตที่เน้นอัปก่อน; ว่าง = ไม่เจาะจง
    },

    -- ==================== AUTO JOIN (เมื่อ Mode = 0) ====================
    AutoJoin = {
        Story = false,
        FriendsOnly = true,
        WorldSkip = false,
        AutoStart = true,
        World = 1,                    -- ลำดับโลกจาก DynamicWorldNames เริ่มที่ 1
        Act = "1",                  -- "1" ถึง "6" หรือ "Infinite"
        Difficulty = "Normal",      -- Normal / Hard / Nightmare
    },

    -- ==================== SUMMON ====================
    Summon = {
        Banner = "EventClover",
        Currency = "gems",           -- ค่าที่เกมรับ เช่น gems; ตรวจชื่อที่ใช้ได้กับเกมเวอร์ชันปัจจุบัน
        MinGemsToSummon = 50,
    },

    -- ==================== TEAM ====================
    Team = {
        MaxEquipUnits = 4,
        EquipDelay = 1.0,
        UnequipDelay = 1.2,
    },

    -- ==================== PLACEMENT / ROAD VISUALIZER ====================
    Placement = {
        Profile = "Dense Overlap", -- Dense Overlap / Balanced / Wide Coverage / Dynamic Intercept
        ClusterSpacing = 0.15,
        GroundCircleRadius = 5,
        HillCircleRadius = 5,
        InterceptRoadPercent = 70,
        DynamicMonsterIntercept = false,
        MonsterLeadStuds = 12,
        RoadSideOffset = 0,
        ShowMiniClusterDots = true,
        ShowRoadPathLines = true,
        ShowHologramZone = true,
        AutoRemoveRoadAfterLine = true,
    },

    -- ==================== PERFORMANCE ====================
    Performance = {
        LowGraphics = true,
    },
}
local AA_CONFIG = getgenv().AA_CONFIG

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    task.wait(0.1)
    LocalPlayer = Players.LocalPlayer
end

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local StarterPlayer = game:GetService("StarterPlayer")

-- ==================== [ DEFAULT LOW GRAPHICS / LOCAL MAP VISUAL REDUCTION ] ====================
-- Enabled by default on every script run. This hides decorative visuals locally,
-- disables expensive visual effects/shadows, and preserves gameplay geometry such as
-- floors, lanes, _road, _terrain and _UNITS for placement/raycast logic.
local Lighting = game:GetService("Lighting")
local Terrain = Workspace:FindFirstChildOfClass("Terrain")
local TD_LOW_GRAPHICS_ENABLED = not (AA_CONFIG.Performance and AA_CONFIG.Performance.LowGraphics == false)
local TD_LowGraphicsConnections = {}

local function TD_IsGameplayGeometry(inst)
    local n = tostring(inst.Name):lower()
    if n == "_road" or n == "_terrain" or n == "_units" or n == "lanes"
        or n == "spawn" or n == "final" or tonumber(n) ~= nil then
        return true
    end
    local p = inst.Parent
    while p and p ~= Workspace do
        local pn = tostring(p.Name):lower()
        if pn == "_road" or pn == "_terrain" or pn == "_units" or pn == "lanes" then
            return true
        end
        p = p.Parent
    end
    return false
end

local function TD_ApplyLowGraphics()
    if not TD_LOW_GRAPHICS_ENABLED then return end

    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 1000000
        Lighting.Brightness = 1
        Lighting.EnvironmentDiffuseScale = 0
        Lighting.EnvironmentSpecularScale = 0
        for _, effect in ipairs(Lighting:GetChildren()) do
            if effect:IsA("PostEffect") then
                effect.Enabled = false
            end
        end
    end)

    if Terrain then
        pcall(function()
            Terrain.Decoration = false
            Terrain.WaterWaveSize = 0
            Terrain.WaterWaveSpeed = 0
            Terrain.WaterReflectance = 0
            Terrain.WaterTransparency = 1
        end)
    end

    for _, inst in ipairs(Workspace:GetDescendants()) do
        pcall(function()
            if inst:IsA("BasePart") then
                if not TD_IsGameplayGeometry(inst) then
                    inst.LocalTransparencyModifier = 1
                    inst.CastShadow = false
                else
                    inst.CastShadow = false
                end
                -- Reduces material rendering cost without changing collision or position.
                if inst.Material ~= Enum.Material.Neon and inst.Material ~= Enum.Material.ForceField then
                    inst.Material = Enum.Material.SmoothPlastic
                end
                if inst:IsA("MeshPart") then
                    inst.RenderFidelity = Enum.RenderFidelity.Performance
                end
            elseif inst:IsA("Decal") or inst:IsA("Texture") then
                inst.Transparency = 1
            elseif inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Beam")
                or inst:IsA("Fire") or inst:IsA("Smoke") or inst:IsA("Sparkles") then
                inst.Enabled = false
            elseif inst:IsA("Light") then
                inst.Enabled = false
            elseif inst:IsA("Highlight") then
                inst.Enabled = false
            end
        end)
    end
end

-- Avoid rescanning every frame; only apply once at startup and to newly added visuals.
task.spawn(function()
    task.wait(1)
    TD_ApplyLowGraphics()
    local conn = Workspace.DescendantAdded:Connect(function(inst)
        task.defer(function()
            if not TD_LOW_GRAPHICS_ENABLED or not inst or not inst.Parent then return end
            pcall(function()
                if inst:IsA("BasePart") then
                    inst.CastShadow = false
                    if not TD_IsGameplayGeometry(inst) then
                        inst.LocalTransparencyModifier = 1
                    end
                    if inst.Material ~= Enum.Material.Neon and inst.Material ~= Enum.Material.ForceField then
                        inst.Material = Enum.Material.SmoothPlastic
                    end
                    if inst:IsA("MeshPart") then inst.RenderFidelity = Enum.RenderFidelity.Performance end
                elseif inst:IsA("Decal") or inst:IsA("Texture") then
                    inst.Transparency = 1
                elseif inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Beam")
                    or inst:IsA("Fire") or inst:IsA("Smoke") or inst:IsA("Sparkles")
                    or inst:IsA("Light") or inst:IsA("Highlight") then
                    inst.Enabled = false
                elseif inst:IsA("PostEffect") then
                    inst.Enabled = false
                end
            end)
        end)
    end)
    table.insert(getgenv().TD_ActiveConnections, conn)
end)


local LOBBY_PLACE_ID = 8304191830
local MACRO_FOLDER = "AnimeAdventures_Macros"
local CONFIG_FOLDER = "FluentScriptHub/AnimeAdventures"
local USER_CONFIG_NAME = LocalPlayer.Name or "DefaultUser"
local KAITAN_CONFIG_FILE = CONFIG_FOLDER .. "/Kaitan_Config_" .. USER_CONFIG_NAME .. ".json"

-- ล้าง Connection และ Visual เก่าเมื่อรันสคริปต์ซ้ำ
if getgenv().TD_ActiveConnections then
    for _, conn in ipairs(getgenv().TD_ActiveConnections) do
        pcall(function()
            conn:Disconnect()
        end)
    end
end
getgenv().TD_ActiveConnections = {}
-- Prevent stale saved Auto Play options from firing while Quick Place boots.
getgenv().TD_QuickManualPlacementBoot = true

local function AddConnection(RBXSignal, callback)
    local conn = RBXSignal:Connect(callback)
    table.insert(getgenv().TD_ActiveConnections, conn)
    return conn
end

-- ==================== [ LOCAL WALK ANIMATION RECOVERY ] ====================
-- This only repairs the local character's animation controller. It does not alter
-- WalkSpeed, position, physics, or the game's movement remotes.
local function TD_EnsureCharacterAnimate(character)
    if not character or character ~= LocalPlayer.Character then return false end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        local ok, result = pcall(function()
            return character:WaitForChild("Humanoid", 4)
        end)
        if ok then humanoid = result end
    end
    if not humanoid or not humanoid:IsA("Humanoid") or humanoid.Health <= 0 then
        return false
    end

    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        pcall(function()
            animator = Instance.new("Animator")
            animator.Parent = humanoid
        end)
    end

    local animate = character:FindFirstChild("Animate")
    if not animate then
        local starterScripts = StarterPlayer:FindFirstChild("StarterCharacterScripts")
        local template = starterScripts and starterScripts:FindFirstChild("Animate")
        if template and template:IsA("LocalScript") then
            local ok, clone = pcall(function()
                local c = template:Clone()
                c.Enabled = true
                c.Parent = character
                return c
            end)
            if ok then animate = clone end
        end
    end

    if animate and animate:IsA("LocalScript") then
        pcall(function()
            if not animate.Enabled then animate.Enabled = true end
        end)
    end
    return animator ~= nil and animate ~= nil
end

local function TD_HasMovementAnimation(humanoid)
    local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
    if not animator then return false end
    local ok, tracks = pcall(function()
        return animator:GetPlayingAnimationTracks()
    end)
    if not ok or type(tracks) ~= "table" then return false end
    for _, track in ipairs(tracks) do
        if track and track.IsPlaying then
            local success, priority = pcall(function() return track.Priority end)
            if success and priority == Enum.AnimationPriority.Movement then
                return true
            end
            local name = tostring(track.Name or ""):lower()
            if name:find("walk", 1, true) or name:find("run", 1, true) then
                return true
            end
        end
    end
    return false
end

local function TD_RepairCharacterAnimations(character)
    task.spawn(function()
        for _ = 1, 6 do
            if not character or not character.Parent or character ~= LocalPlayer.Character then
                return
            end
            if TD_EnsureCharacterAnimate(character) then return end
            task.wait(0.75)
        end
        warn("[TD AnimationRecovery] Could not find/restore Animate; this game may use a custom animation controller.")
    end)
end

AddConnection(LocalPlayer.CharacterAdded, TD_RepairCharacterAnimations)
if LocalPlayer.Character then
    TD_RepairCharacterAnimations(LocalPlayer.Character)
end

-- In some sessions Animate remains present but its walk track stops after the start wait.
-- Only restart the local Animate script after sustained movement with no movement track.
getgenv().TD_AnimationWatchdogToken = (tonumber(getgenv().TD_AnimationWatchdogToken) or 0) + 1
local tdAnimationWatchdogToken = getgenv().TD_AnimationWatchdogToken
task.spawn(function()
    local missingTrackSince = nil
    local lastRecoveryAt = 0
    while getgenv().TD_AnimationWatchdogToken == tdAnimationWatchdogToken do
        task.wait(1.25)
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not character or not humanoid or humanoid.Health <= 0 then
            missingTrackSince = nil
        elseif humanoid.MoveDirection.Magnitude > 0.08
            and humanoid:GetState() == Enum.HumanoidStateType.Running
            and not TD_HasMovementAnimation(humanoid) then
            missingTrackSince = missingTrackSince or os.clock()
            if os.clock() - missingTrackSince >= 2.5 and os.clock() - lastRecoveryAt >= 5 then
                lastRecoveryAt = os.clock()
                local animate = character:FindFirstChild("Animate")
                if animate and animate:IsA("LocalScript") then
                    pcall(function()
                        animate.Enabled = false
                    end)
                    task.wait(0.1)
                    pcall(function()
                        animate.Enabled = true
                    end)
                else
                    TD_EnsureCharacterAnimate(character)
                end
                missingTrackSince = nil
            end
        else
            missingTrackSince = nil
        end
    end
end)

if Workspace:FindFirstChild("_TD_Holograms") then
    pcall(function()
        Workspace._TD_Holograms:Destroy()
    end)
end
if Workspace:FindFirstChild("_TD_RoadVisual") then
    pcall(function()
        Workspace._TD_RoadVisual:Destroy()
    end)
end
if Workspace:FindFirstChild("_TD_MacroMarkers") then
    pcall(function()
        Workspace._TD_MacroMarkers:Destroy()
    end)
end

if typeof(makefolder) == "function" and typeof(isfolder) == "function" then
    if not isfolder("FluentScriptHub") then pcall(makefolder, "FluentScriptHub") end
    if not isfolder(CONFIG_FOLDER) then pcall(makefolder, CONFIG_FOLDER) end
    if not isfolder(MACRO_FOLDER) then pcall(makefolder, MACRO_FOLDER) end
end

-- ==================== [ SAFE FLUENT UI LOADER ] ====================
local function SafeHttpGet(url)
    local ok, res = pcall(function()
        return game:HttpGet(url)
    end)
    if ok and type(res) == "string" and #res > 0 then
        return res
    end
    return nil
end

local FluentRaw = SafeHttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua")
    or SafeHttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/main.lua")

if not FluentRaw then
    warn("[TD Architect Error]: Failed to load Fluent UI library from GitHub.")
    return
end

local Fluent = loadstring(FluentRaw)()

local SaveManagerRaw = SafeHttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua")
local SaveManager = SaveManagerRaw and loadstring(SaveManagerRaw)() or nil

local InterfaceManagerRaw = SafeHttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua")
local InterfaceManager = InterfaceManagerRaw and loadstring(InterfaceManagerRaw)() or nil

-- ==============================================================================
-- 0. KAITAN CONFIG & PROGRESSION MEMORY
-- ==============================================================================
local KaitanConfig = {
    EnableKaitanMode = tonumber(AA_CONFIG.Mode) ~= 0,
    SummonBanner = tostring((AA_CONFIG.Summon and AA_CONFIG.Summon.Banner) or "EventClover"),
    SummonCurrency = tostring((AA_CONFIG.Summon and AA_CONFIG.Summon.Currency) or "gems"),
    MinGemsToSummon = tonumber((AA_CONFIG.Summon and AA_CONFIG.Summon.MinGemsToSummon) or 50),
    GemGoal = tonumber((AA_CONFIG.Farm and AA_CONFIG.Farm.GemGoal) or 20000),
    -- เลือกด่าน Infinite เป้าหมาย: "namek_infinite" หรือ "aot_infinite"
    FarmTarget = tostring((AA_CONFIG.Farm and AA_CONFIG.Farm.Target) or "namek_infinite"),
    ProgressSchema = 38,
    MaxEquipUnits = tonumber((AA_CONFIG.Team and AA_CONFIG.Team.MaxEquipUnits) or 4),
    EquipDelay = tonumber((AA_CONFIG.Team and AA_CONFIG.Team.EquipDelay) or 1.0),
    UnequipDelay = tonumber((AA_CONFIG.Team and AA_CONFIG.Team.UnequipDelay) or 1.2),
    PassedNamek = false,
    PassedWalledCity = false
}

local function SaveKaitanConfig()
    if typeof(writefile) == "function" then
        pcall(function()
            writefile(KAITAN_CONFIG_FILE, HttpService:JSONEncode(KaitanConfig))
        end)
    end
end

local function LoadKaitanConfig()
    if typeof(isfile) == "function" and typeof(readfile) == "function" and isfile(KAITAN_CONFIG_FILE) then
        pcall(function()
            local decoded = HttpService:JSONDecode(readfile(KAITAN_CONFIG_FILE))
            if type(decoded) == "table" then
                -- Schema 36+ completion flags came from profile completion data.
                -- Keep valid progress when migrating to schema 37.
                local savedSchema = tonumber(decoded.ProgressSchema) or 0
                if savedSchema < 36 then
                    -- Older builds could mark Act 6 complete merely because World Skip failed.
                    decoded.PassedNamek = false
                    decoded.PassedWalledCity = false
                end
                -- Migrate the old default goal of 2,000 to 20,000 exactly once.
                -- After schema 37 is saved, users can deliberately choose 2,000 again.
                if savedSchema < 37 and tonumber(decoded.GemGoal) == 2000 then
                    decoded.GemGoal = 20000
                end
                decoded.ProgressSchema = 38
                for k, v in pairs(decoded) do
                    KaitanConfig[k] = v
                end
            end
        end)
    else
        SaveKaitanConfig()
    end
end

LoadKaitanConfig()
-- AA_CONFIG at the top of the file is the source of truth for user-editable settings.
-- Keep saved completion/progression flags, but apply the current run's selected options.
KaitanConfig.EnableKaitanMode = tonumber(AA_CONFIG.Mode) ~= 0
KaitanConfig.SummonBanner = tostring((AA_CONFIG.Summon and AA_CONFIG.Summon.Banner) or KaitanConfig.SummonBanner or "EventClover")
KaitanConfig.SummonCurrency = tostring((AA_CONFIG.Summon and AA_CONFIG.Summon.Currency) or KaitanConfig.SummonCurrency or "gems")
KaitanConfig.MinGemsToSummon = math.max(0, tonumber((AA_CONFIG.Summon and AA_CONFIG.Summon.MinGemsToSummon) or KaitanConfig.MinGemsToSummon) or 50)
KaitanConfig.GemGoal = math.max(50, tonumber((AA_CONFIG.Farm and AA_CONFIG.Farm.GemGoal) or KaitanConfig.GemGoal) or 20000)
KaitanConfig.FarmTarget = tostring((AA_CONFIG.Farm and AA_CONFIG.Farm.Target) or KaitanConfig.FarmTarget or "namek_infinite"):lower()
if KaitanConfig.FarmTarget ~= "namek_infinite" and KaitanConfig.FarmTarget ~= "aot_infinite" then
    KaitanConfig.FarmTarget = "namek_infinite"
end
KaitanConfig.MaxEquipUnits = math.max(1, math.floor(tonumber((AA_CONFIG.Team and AA_CONFIG.Team.MaxEquipUnits) or KaitanConfig.MaxEquipUnits) or 4))
KaitanConfig.EquipDelay = math.max(0, tonumber((AA_CONFIG.Team and AA_CONFIG.Team.EquipDelay) or KaitanConfig.EquipDelay) or 1.0)
KaitanConfig.UnequipDelay = math.max(0, tonumber((AA_CONFIG.Team and AA_CONFIG.Team.UnequipDelay) or KaitanConfig.UnequipDelay) or 1.2)
-- Persist schema migration and the validated target/config values.
SaveKaitanConfig()

-- ==================== [ LOCAL MANUAL-PLACEMENT HITBOX TEST ] ====================
-- CLIENT-ONLY experiment. It may bypass local hologram checks, but cannot force the
-- server to accept a placement if the server independently validates overlap.
local TD_HITBOX_TEST_MODE = "shrink"
do
    local trackedUnits = setmetatable({}, { __mode = "k" })
    local attachedFolders = setmetatable({}, { __mode = "k" })

    local function modifyUnitPart(part)
        if not part or not part:IsA("BasePart") then return end
        pcall(function()
            if TD_HITBOX_TEST_MODE == "shrink" then
                if part.Name == "_hitbox" then
                    part.Size = Vector3.new(0.001, 0.001, 0.001)
                end
                part.CanCollide = false
                part.CanTouch = false
                part.CanQuery = false
            elseif TD_HITBOX_TEST_MODE == "destroy" and part.Name == "_hitbox" then
                part:Destroy()
            end
        end)
    end

    local function applyUnit(unit)
        if not unit or trackedUnits[unit] then return end
        trackedUnits[unit] = true

        if TD_HITBOX_TEST_MODE == "shrink" then
            for _, inst in ipairs(unit:GetDescendants()) do
                if inst:IsA("BasePart") then modifyUnitPart(inst) end
            end
        else
            -- Method 2: remove only the named hitbox, keeping other unit parts intact.
            local hitbox = unit:FindFirstChild("_hitbox", true)
            if hitbox then pcall(function() hitbox:Destroy() end) end
        end

        AddConnection(unit.DescendantAdded, function(inst)
            task.defer(function()
                if not inst or not inst.Parent then return end
                if TD_HITBOX_TEST_MODE == "shrink" then
                    modifyUnitPart(inst)
                elseif inst.Name == "_hitbox" then
                    pcall(function() inst:Destroy() end)
                end
            end)
        end)
    end

    local function attachUnitsFolder(folder)
        if not folder or attachedFolders[folder] then return end
        attachedFolders[folder] = true
        for _, unit in ipairs(folder:GetChildren()) do applyUnit(unit) end
        AddConnection(folder.ChildAdded, function(unit)
            task.delay(0.08, function()
                if unit and unit.Parent == folder then applyUnit(unit) end
            end)
        end)
    end

    local unitsFolder = Workspace:FindFirstChild("_UNITS")
    if unitsFolder then
        attachUnitsFolder(unitsFolder)
    end
    AddConnection(Workspace.ChildAdded, function(child)
        if child.Name == "_UNITS" then
            task.defer(function() attachUnitsFolder(child) end)
        end
    end)

    warn(TD_HITBOX_TEST_MODE == "shrink"
        and "[TD Manual Place] Test A active: locally shrink _hitbox and disable unit-part query/collision"
        or "[TD Manual Place] Test B active: locally remove _hitbox from units")
end

-- ==============================================================================
-- 1. CORE GAME MODULES & ENDPOINTS
-- ==============================================================================
local src = ReplicatedStorage:FindFirstChild("src") or ReplicatedStorage:WaitForChild("src", 5)
local Loader = nil
if src and src:FindFirstChild("Loader") then
    pcall(function()
        Loader = require(src.Loader)
    end)
end

local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts") or LocalPlayer:WaitForChild("PlayerScripts", 5)
local mainScript = playerScripts and (playerScripts:FindFirstChild("main") or playerScripts:FindFirstChildWhichIsA("LocalScript"))

local EndpointsClient = nil
local UnitCollectionServiceClient = nil
local ItemInventoryServiceClient = nil
local QuestsServiceClient = nil
local DataServiceClient = nil
local Util = nil

pcall(function()
    if Loader and mainScript then
        EndpointsClient = Loader.load_client_service(mainScript, "EndpointsClient")
        UnitCollectionServiceClient = Loader.load_client_service(mainScript, "UnitCollectionServiceClient")
        pcall(function()
            ItemInventoryServiceClient = Loader.load_client_service(mainScript, "ItemInventoryServiceClient")
        end)
        pcall(function()
            QuestsServiceClient = Loader.load_client_service(mainScript, "QuestsServiceClient")
        end)
        pcall(function()
            DataServiceClient = Loader.load_client_service(mainScript, "DataServiceClient")
        end)
    end
    if src and src:FindFirstChild("Util") then
        Util = require(src.Util)
    end
end)

local Worlds = nil
local WorldLevelOrder = nil
local Levels = nil
local UnitsData = nil
local UnitTags = nil

pcall(function()
    local dataFolder = src and src:FindFirstChild("Data")
    if dataFolder then
        if dataFolder:FindFirstChild("Worlds") then Worlds = require(dataFolder.Worlds) end
        if dataFolder:FindFirstChild("WorldLevelOrder") then WorldLevelOrder = require(dataFolder.WorldLevelOrder) end
        if dataFolder:FindFirstChild("Levels") then Levels = require(dataFolder.Levels) end
        if dataFolder:FindFirstChild("Units") then UnitsData = require(dataFolder.Units) end
        if dataFolder:FindFirstChild("UnitTags") then UnitTags = require(dataFolder.UnitTags) end
    end
end)

local clientToServer = ReplicatedStorage:FindFirstChild("endpoints") and ReplicatedStorage.endpoints:FindFirstChild("client_to_server")

local function InvokeServer(endpointName, ...)
    if EndpointsClient and type(EndpointsClient.invoke_server) == "function" then
        local ok, res = pcall(EndpointsClient.invoke_server, endpointName, ...)
        if ok then return res end
    end
    local remote = clientToServer and clientToServer:FindFirstChild(endpointName)
    if remote and remote:IsA("RemoteFunction") then
        local ok, res = pcall(remote.InvokeServer, remote, ...)
        if ok then return res end
    elseif remote and remote:IsA("RemoteEvent") then
        local ok = pcall(remote.FireServer, remote, ...)
        if ok then return true end
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

        local displayName = tostring(wData.name or wData.title or wId)
        if displayName == "" then displayName = wId end

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
        for wId, wData in pairs(Worlds) do
            if type(wId) == "string" and type(wData) == "table" and not addedWorldIds[wId] then
                RegisterWorldEntry(wId, wData)
            end
        end
    end

    if #DynamicWorldNames == 0 then
        local fallbackList = {
            { id = "planet_namek", name = "Planet Greenie" },
            { id = "shiganshina", name = "Walled City" },
            { id = "snowy_town", name = "Snowy Town" },
            { id = "hidden_sand", name = "Hidden Sand Village" },
            { id = "marine_base", name = "Marine's Ford" },
            { id = "tokyo_ghoul", name = "Ghoul City" }
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

local function GetExactWorldId(targetDisplayName, defaultFallbackId)
    local searchLower = tostring(targetDisplayName or ""):lower()
    if type(Worlds) == "table" then
        for wId, wData in pairs(Worlds) do
            if type(wData) == "table" then
                local wName = tostring(wData.name or wData.title or ""):lower()
                if wName == searchLower or (searchLower ~= "" and wName:find(searchLower, 1, true)) then
                    return wId
                end
            end
        end
    end
    for disp, wId in pairs(WorldNameToIdMap) do
        if tostring(disp):lower() == searchLower or (searchLower ~= "" and tostring(disp):lower():find(searchLower, 1, true)) then
            return wId
        end
    end
    return defaultFallbackId or WorldNameToIdMap[targetDisplayName] or targetDisplayName
end

local function ResolveTargetLevelId(worldNameOrId, actStr, diffStr)
    local cleanWorldName = tostring(worldNameOrId or "")
    local targetWorldId = WorldNameToIdMap[cleanWorldName] or GetExactWorldId(cleanWorldName, nil) or "planet_namek"

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
    return targetLevelId, finalDiff, targetWorldId
end

---------------------------------------------------------------------
-- 2. GLOBAL STATE & MEMORY SCANNERS
---------------------------------------------------------------------
local State = {
    IsLobby = (game.PlaceId == LOBBY_PLACE_ID) or (Workspace:FindFirstChild("_LOBBIES") ~= nil),
    MainRoadNodes = {},
    MainRoadSegments = {},
    MainRoadTotalLength = 0,
    MainRoadHalfWidth = 2.5,
    MainPartInstances = {},
    ActiveRoadLabel = "Auto-Detecting",
    EnemyVerifiedRoad = false,
    CandidateRoadChains = {},
    MainRoadBaseY = 0,
    HillPartInstances = {},
    HillGeometries = {},
    HologramFolder = nil,
    RoadVisualFolder = nil,
    RoadWasRemoved = false,
    RoadPathBuilt = false,
    RoadGroundChildCount = 0,
    RoadBuildPendingCount = -1,
    RoadBuildStableTicks = 0,
    RoadBuildLastAttempt = 0,
    ClusterSlots = {
        Ground = {},
        Hill = {},
        -- Visual grids are independent from the stricter Auto Play candidate lists.
        -- They keep the full circle visible even where props or roads hide the floor.
        GroundVisual = {},
        HillVisual = {},
        CenterPos = Vector3.zero,
        GroundCenterPos = Vector3.zero,
        HillCenterPos = Vector3.zero,
        GroundRadius = 6,
        HillRadius = 6
    },
    -- A unit's placement surface is learned from its metadata first, then from
    -- which surface the server actually accepts. This works for every unit ID/name.
    UnitPlacementOverrides = {},
    UnitPlacementOverrideConfirmed = {},
    UnitPlacementProbe = {},
    CachedProfileData = nil,
    IsBootingConfig = true,
    KaitanDidLobbyPrep = false,
    KaitanEquippedThisLobby = false
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

local function GetInventorySessionTable()
    if ItemInventoryServiceClient and ItemInventoryServiceClient.session then
        return ItemInventoryServiceClient.session
    end
    if DataServiceClient and type(DataServiceClient.get_data) == "function" then
        local ok, d = pcall(DataServiceClient.get_data)
        if ok and type(d) == "table" then
            State.CachedProfileData = d
            return d
        end
    end
    if State.CachedProfileData then return State.CachedProfileData end
    if typeof(getgc) == "function" then
        pcall(function()
            for _, obj in ipairs(getgc(true)) do
                if type(obj) == "table" then
                    local col = rawget(obj, "collection")
                    local prof = rawget(obj, "profile_data")
                    if type(col) == "table" and type(prof) == "table" then
                        State.CachedProfileData = obj
                        break
                    end
                end
            end
        end)
    end
    return State.CachedProfileData
end

local function RefreshAndCheckWorldCompletion()
    local w1Id = GetExactWorldId("Planet Greenie", "planet_namek")
    local w2Id = GetExactWorldId("Walled City", "shiganshina")
    local act6W1 = ResolveTargetLevelId(w1Id, "6", "Normal")
    local act6W2 = ResolveTargetLevelId(w2Id, "6", "Normal")

    -- PRIMARY STORY COMPLETION SOURCE: game's completed_story_levels table in GC.
    -- This is the same detection approach supplied by the user; GUI text is only fallback.
    local STORY_MAPS = {
        { key = "namek", name = "Planet Greenie" },
        { key = "aot", name = "Walled City" },
        { key = "demonslayer", name = "Snowy Town" },
        { key = "naruto", name = "Sand Village" },
        { key = "marineford", name = "Navy Bay" },
        { key = "tokyo_ghoul", name = "Fiend City" },
        { key = "hueco", name = "Spirit World" },
        { key = "hxhant", name = "Ant Kingdom" },
        { key = "magnolia", name = "Magic Town" },
        { key = "jjk", name = "Haunted Academy" },
        { key = "clover", name = "Magic Hills" },
        { key = "jojo", name = "Space Center" },
        { key = "opm", name = "Alien Spaceship" },
        { key = "7ds", name = "Fabled Kingdom" },
        { key = "mha", name = "Ruined City" },
        { key = "dressrosa", name = "Puppet Island" },
        { key = "sao", name = "Virtual Dungeon" },
        { key = "berserk", name = "Snowy Kingdom" },
        { key = "overlord", name = "Dungeon Throne" },
        { key = "fate", name = "Mountain Temple" },
        { key = "amegakure", name = "Rain Village" },
        { key = "shibuya", name = "Shibuya District" },
    }

    local completedStoryLevels = nil
    if typeof(getgc) == "function" then
        pcall(function()
            for _, obj in pairs(getgc(true)) do
                if type(obj) == "table" then
                    local ok, data = pcall(function()
                        return rawget(obj, "completed_story_levels")
                    end)
                    if ok and type(data) == "table" then
                        completedStoryLevels = data
                        break
                    end
                end
            end
        end)
    end

    if type(completedStoryLevels) == "table" then
        for _, mapInfo in ipairs(STORY_MAPS) do
            local key = mapInfo.key
            local clearsCount = 0
            local directData = completedStoryLevels[key]
            if type(directData) == "table" then
                for _ in pairs(directData) do
                    clearsCount = clearsCount + 1
                end
            else
                for k in pairs(completedStoryLevels) do
                    local strKey = tostring(k):lower()
                    local lowerKey = key:lower()
                    if strKey:find("^" .. lowerKey) or strKey:find(lowerKey .. "_") then
                        clearsCount = clearsCount + 1
                    end
                end
            end
            if clearsCount > 6 then clearsCount = 6 end

            -- Print only when the count changes; RefreshAndCheckWorldCompletion runs repeatedly.
            State.KaitanStoryLogCounts = State.KaitanStoryLogCounts or {}
            if State.KaitanStoryLogCounts[key] ~= clearsCount then
                State.KaitanStoryLogCounts[key] = clearsCount
                pcall(function()
                    print(string.format("[STORY UPDATE]\t%s\t%s | %d/6", key, mapInfo.name, clearsCount))
                end)
            end
            if clearsCount >= 6 then
                if key == "namek" and not KaitanConfig.PassedNamek then
                    KaitanConfig.PassedNamek = true
                    SaveKaitanConfig()
                elseif key == "aot" and not KaitanConfig.PassedWalledCity then
                    KaitanConfig.PassedWalledCity = true
                    SaveKaitanConfig()
                end
            end
        end
    end

    -- Read GUI properties independently: TextLabel has .Text, while ValueBase has .Value.
    -- Accessing a missing Roblox property throws, so never use obj.Text or obj.Value in one expression.
    local function ReadGuiText(obj)
        if not obj then return "" end
        local ok, result = pcall(function() return obj.Text end)
        if ok and result ~= nil and tostring(result) ~= "" then
            return tostring(result)
        end
        ok, result = pcall(function() return obj.Value end)
        if ok and result ~= nil and tostring(result) ~= "" then
            return tostring(result)
        end
        return ""
    end

    local function IsSixOfSix(value)
        local normalized = tostring(value or ""):gsub("%s+", "")
        return normalized == "6/6"
    end

    -- Check the exact hierarchy supplied by the user first.
    local guiText = ""
    local playerGui = nil
    pcall(function()
        playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        local levelSelect = playerGui and playerGui:FindFirstChild("LevelSelectGui")
        local mapSelect = levelSelect and levelSelect:FindFirstChild("MapSelect")
        local main = mapSelect and mapSelect:FindFirstChild("Main")
        local wrapper = main and main:FindFirstChild("Wrapper")
        local container = wrapper and wrapper:FindFirstChild("Container")
        local namek = container and container:FindFirstChild("namek")
        local namekMain = namek and namek:FindFirstChild("Main")
        local namekContainer = namekMain and namekMain:FindFirstChild("Container")
        local levelsCleared = namekContainer and namekContainer:FindFirstChild("LevelsCleared")
        local value = levelsCleared and levelsCleared:FindFirstChild("V")
        guiText = ReadGuiText(value)
        if guiText == "" then guiText = ReadGuiText(levelsCleared) end
    end)

    -- Fallback: search PlayerGui descendants, including nested descendants under V,
    -- but only accept a LevelsCleared object belonging to Namek/Greenie.
    if not IsSixOfSix(guiText) and playerGui then
        pcall(function()
            for _, obj in ipairs(playerGui:GetDescendants()) do
                if tostring(obj.Name):lower() == "levelscleared" then
                    local node = obj
                    local belongsToNamek = false
                    for _ = 1, 12 do
                        if not node then break end
                        local nodeName = tostring(node.Name):lower():gsub("[%s_%-]", "")
                        if nodeName:find("namek", 1, true) or nodeName:find("greenie", 1, true)
                            or nodeName:find("planetgreenie", 1, true) then
                            belongsToNamek = true
                            break
                        end
                        node = node.Parent
                    end
                    if belongsToNamek then
                        local v = obj:FindFirstChild("V")
                        local candidate = ReadGuiText(v)
                        if not IsSixOfSix(candidate) then candidate = ReadGuiText(obj) end
                        if not IsSixOfSix(candidate) and v then
                            for _, nested in ipairs(v:GetDescendants()) do
                                candidate = ReadGuiText(nested)
                                if IsSixOfSix(candidate) then break end
                            end
                        end
                        if IsSixOfSix(candidate) then
                            guiText = candidate
                            break
                        end
                    end
                end
            end
        end)
    end

    if IsSixOfSix(guiText) and not KaitanConfig.PassedNamek then
        KaitanConfig.PassedNamek = true
        SaveKaitanConfig()
    end

    local function inspectCompletionTable(lc)
        if type(lc) ~= "table" then return end
        local visited = {}
        local namekId = tostring(act6W1 or ""):lower()
        local walledId = tostring(act6W2 or ""):lower()

        local function walk(tbl, path, depth)
            if type(tbl) ~= "table" or depth > 8 or visited[tbl] then return end
            visited[tbl] = true
            for k, v in pairs(tbl) do
                local key = tostring(k):lower()
                local fullKey = (path == "" and key or (path .. "_" .. key)):lower()
                if type(v) == "table" then
                    walk(v, fullKey, depth + 1)
                else
                    local valueText = type(v) == "string" and v:lower() or ""
                    local completed = (v == true) or (type(v) == "number" and v > 0)
                        or valueText == "true" or valueText == "completed" or valueText == "passed" or valueText == "1"
                    if completed then
                        local hasAct6 = fullKey:find("level_6", 1, true) ~= nil or fullKey:match("_6$") ~= nil
                        local isInfinite = fullKey:find("infinite", 1, true) ~= nil
                        local isNamekWorld = fullKey:find("namek", 1, true) ~= nil
                            or fullKey:find("planet_greenie", 1, true) ~= nil
                            or fullKey:find("greenie", 1, true) ~= nil
                        local isWalledWorld = fullKey:find("shiganshina", 1, true) ~= nil
                            or fullKey:find("walled", 1, true) ~= nil
                            or fullKey:find("aot", 1, true) ~= nil
                            or fullKey:find("titan", 1, true) ~= nil

                        local exactNamek = namekId ~= "" and fullKey:find(namekId, 1, true) ~= nil
                        local exactWalled = walledId ~= "" and fullKey:find(walledId, 1, true) ~= nil
                        -- Never treat Act 1-5 as Act 6 merely because the world name matches.
                        local isNamekAct6 = not isInfinite and hasAct6 and (exactNamek or isNamekWorld)
                        local isWalledAct6 = not isInfinite and hasAct6 and (exactWalled or isWalledWorld)

                        if isNamekAct6 and not KaitanConfig.PassedNamek then
                            KaitanConfig.PassedNamek = true
                            SaveKaitanConfig()
                        end
                        if isWalledAct6 and not KaitanConfig.PassedWalledCity then
                            KaitanConfig.PassedWalledCity = true
                            SaveKaitanConfig()
                        end
                    end
                end
            end
        end
        walk(lc, "", 0)
    end

    local session = GetInventorySessionTable()
    if type(session) == "table" then
        inspectCompletionTable(session.level_completion)
        if type(session.profile_data) == "table" then
            inspectCompletionTable(session.profile_data.level_completion)
        end
    end

    if typeof(getgc) == "function" and (not KaitanConfig.PassedNamek or not KaitanConfig.PassedWalledCity) then
        pcall(function()
            for _, obj in ipairs(getgc(true)) do
                if type(obj) == "table" then
                    local lc = rawget(obj, "level_completion")
                    if type(lc) == "table" then
                        inspectCompletionTable(lc)
                    end
                end
            end
        end)
    end

    return KaitanConfig.PassedNamek, KaitanConfig.PassedWalledCity
end

local function ClaimAllDailyAndUUIDQuests()
    pcall(function()
        InvokeServer("claim_daily_reward")
    end)

    local questUUIDs = {}
    local seenUUID = {}

    local function addQuestId(idStr)
        if type(idStr) ~= "string" then return end
        local clean = idStr:gsub("^%s+", ""):gsub("%s+$", "")
        if clean == "" or seenUUID[clean] then return end
        seenUUID[clean] = true
        table.insert(questUUIDs, clean)

        if clean:match("^%x+-%x+-%x+-%x+-%x+$") then
            local bracketed = "{" .. clean .. "}"
            if not seenUUID[bracketed] then
                seenUUID[bracketed] = true
                table.insert(questUUIDs, bracketed)
            end
        end
    end

    local function scanTableForQuestUUIDs(tbl, depth)
        if type(tbl) ~= "table" or (depth or 0) > 4 then return end
        for k, v in pairs(tbl) do
            local kStr = tostring(k)
            if kStr:match("^%b{}$") or kStr:match("%x+-%x+-%x+-%x+-%x+") then
                addQuestId(kStr)
            end
            if type(v) == "table" then
                if v.uuid then addQuestId(tostring(v.uuid)) end
                if v.id then addQuestId(tostring(v.id)) end
                if v.quest_id then addQuestId(tostring(v.quest_id)) end
                scanTableForQuestUUIDs(v, (depth or 0) + 1)
            elseif type(v) == "string" and (v:match("^%b{}$") or v:match("%x+-%x+-%x+-%x+-%x+")) then
                addQuestId(v)
            end
        end
    end

    pcall(function()
        if QuestsServiceClient then
            scanTableForQuestUUIDs(QuestsServiceClient, 1)
        end
    end)

    local session = GetInventorySessionTable()
    if type(session) == "table" then
        scanTableForQuestUUIDs(session.quests, 1)
        scanTableForQuestUUIDs(session.quest_data, 1)
        if type(session.profile_data) == "table" then
            scanTableForQuestUUIDs(session.profile_data.quests, 1)
            scanTableForQuestUUIDs(session.profile_data.quest_data, 1)
            scanTableForQuestUUIDs(session.profile_data.daily_quests, 1)
        end
    end

    if typeof(getgc) == "function" then
        pcall(function()
            for _, obj in ipairs(getgc(true)) do
                if type(obj) == "table" then
                    local qTbl = rawget(obj, "quests") or rawget(obj, "quest_data") or rawget(obj, "active_quests")
                    if type(qTbl) == "table" then
                        scanTableForQuestUUIDs(qTbl, 1)
                    end
                end
            end
        end)
    end

    local pgui = LocalPlayer:FindFirstChild("PlayerGui")
    if pgui then
        for _, inst in ipairs(pgui:GetDescendants()) do
            local iName = inst.Name
            if iName:match("^%b{}$") or iName:match("%x+-%x+-%x+-%x+-%x+") then
                local anc = inst:FindFirstAncestor("QuestsUI") or inst:FindFirstAncestor("quests") or inst:FindFirstAncestor("Main")
                if anc or not inst:FindFirstAncestor("collection") then
                    addQuestId(iName)
                end
            end
            for _, attrName in ipairs({"uuid", "UUID", "quest_id", "QuestId", "id"}) do
                local attrVal = inst:GetAttribute(attrName)
                if attrVal then
                    addQuestId(tostring(attrVal))
                end
            end
        end
    end

    local claimedCount = 0
    for _, qId in ipairs(questUUIDs) do
        pcall(function()
            InvokeServer("redeem_quest", qId)
            claimedCount = claimedCount + 1
        end)
        task.wait(0.05)
    end
    pcall(function()
        InvokeServer("redeem_quest")
    end)
    return claimedCount
end

local function GetPlayerGems()
    local stats = LocalPlayer:FindFirstChild("_stats")
    if stats then
        for _, childName in ipairs({"gem_amount", "gems", "Gems", "Gem"}) do
            local valObj = stats:FindFirstChild(childName)
            if valObj and tonumber(valObj.Value) then
                return tonumber(valObj.Value)
            end
        end
    end

    local session = GetInventorySessionTable()
    if type(session) == "table" then
        if type(session.profile_data) == "table" and tonumber(session.profile_data.gem_amount) then
            return tonumber(session.profile_data.gem_amount)
        end
        if tonumber(session.gem_amount) then
            return tonumber(session.gem_amount)
        end
    end

    local pgui = LocalPlayer:FindFirstChild("PlayerGui")
    if pgui then
        local spawnUnitsGui = pgui:FindFirstChild("spawn_units")
        if spawnUnitsGui then
            for _, d in ipairs(spawnUnitsGui:GetDescendants()) do
                if d:IsA("TextLabel") and d.Visible and d.Parent and (d.Parent.Name:lower():find("gem") or d.Name:lower():find("gem")) then
                    local cleanNum = tonumber((d.Text:gsub(",", ""):gsub("%s+", "")))
                    if cleanNum then return cleanNum end
                end
            end
        end
    end

    return 0
end

-- Startup fix: saved config can contain EnableKaitanMode=false from an older run.
-- Re-enable it on launch unless the selected target progression is complete and the gem goal
-- has already been reached; that completion state is intentionally allowed to stay stopped.
do
    local startupGemGoal = math.max(50, tonumber(KaitanConfig.GemGoal) or 20000)
    local startupFarmNamek = tostring(KaitanConfig.FarmTarget or "namek_infinite"):lower() == "namek_infinite"
    local startupTargetDone = startupFarmNamek and KaitanConfig.PassedNamek
        or (KaitanConfig.PassedNamek and KaitanConfig.PassedWalledCity)
    local alreadyReachedGemGoal = startupTargetDone
        and GetPlayerGems() >= startupGemGoal
    if tonumber(AA_CONFIG.Mode) == 0 then
        KaitanConfig.EnableKaitanMode = false
        SaveKaitanConfig()
    elseif not alreadyReachedGemGoal then
        KaitanConfig.EnableKaitanMode = true
        SaveKaitanConfig()
    end
end

-- Top-right real-time gem HUD (client overlay, independent from Fluent tab visibility).
do
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    pcall(function()
        local previous = playerGui:FindFirstChild("KaitanGemHUD")
        if previous then previous:Destroy() end
    end)

    local gui = Instance.new("ScreenGui")
    gui.Name = "KaitanGemHUD"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 999999
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = playerGui

    local frame = Instance.new("Frame")
    frame.Name = "GemPanel"
    frame.AnchorPoint = Vector2.new(1, 0)
    frame.Position = UDim2.new(1, -14, 0, 14)
    frame.Size = UDim2.fromOffset(260, 76)
    frame.BackgroundColor3 = Color3.fromRGB(5, 5, 8)
    frame.BackgroundTransparency = 0.06
    frame.BorderSizePixel = 0
    frame.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(70, 70, 80)
    stroke.Thickness = 1
    stroke.Transparency = 0.15
    stroke.Parent = frame

    local gemsLabel = Instance.new("TextLabel")
    gemsLabel.Name = "GemCount"
    gemsLabel.BackgroundTransparency = 1
    gemsLabel.Position = UDim2.fromOffset(10, 5)
    gemsLabel.Size = UDim2.new(1, -20, 0, 31)
    gemsLabel.Font = Enum.Font.GothamBold
    gemsLabel.TextSize = 16
    gemsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    gemsLabel.TextXAlignment = Enum.TextXAlignment.Left
    gemsLabel.Text = "💎 Gems: --"
    gemsLabel.Parent = frame

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "Progress"
    statusLabel.BackgroundTransparency = 1
    statusLabel.Position = UDim2.fromOffset(10, 39)
    statusLabel.Size = UDim2.new(1, -20, 0, 27)
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 11
    statusLabel.TextColor3 = Color3.fromRGB(195, 200, 210)
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.TextTruncate = Enum.TextTruncate.AtEnd
    statusLabel.Text = "Greenie Act 6: -- | Titan Act 6: --"
    statusLabel.Parent = frame

    task.spawn(function()
        while gui.Parent do
            local gems = GetPlayerGems()
            local goal = math.max(50, math.floor(tonumber(KaitanConfig.GemGoal) or 20000))
            gemsLabel.Text = string.format("💎 Gems: %d / %d", math.floor(gems or 0), goal)
            local namek = KaitanConfig.PassedNamek and "✓" or "…"
            local walled = KaitanConfig.PassedWalledCity and "✓" or "…"
            local targetNamek = tostring(KaitanConfig.FarmTarget or "namek_infinite"):lower() == "namek_infinite"
            local targetDone = targetNamek and KaitanConfig.PassedNamek or (KaitanConfig.PassedNamek and KaitanConfig.PassedWalledCity)
            local phase = targetDone and (targetNamek and "Namek Infinite Farm" or "AOT Infinite Farm") or "Act 6"
            statusLabel.Text = string.format("Greenie: %s | Titan: %s | %s", namek, walled, phase)
            task.wait(0.5)
        end
    end)
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

local function NormalizePlacementKey(value)
    return tostring(value or ""):lower():gsub("[^%w]", "")
end

local function DecodePlacementLabel(value)
    if type(value) ~= "string" then return nil end
    local token = NormalizePlacementKey(value)
    if token == "farm" or token == "farming" or token == "farmunit" or token == "farmplacement" then
        return "Farm"
    end
    if token == "hill" or token == "hillunit" or token == "hillunits" or token == "hillplacement"
        or token == "air" or token == "airunit" or token == "airunits" or token == "airplacement"
        or token == "aerial" or token == "flying" or token == "flyingunit" or token == "flyingunits"
        or token == "elevated" or token == "hybrid" or token == "hybridunit" then
        return "Hill"
    end
    if token == "ground" or token == "groundunit" or token == "groundplacement"
        or token == "land" or token == "landunit" or token == "groundplaced" then
        return "Ground"
    end
    return nil
end

local function DecodePlacementGroup(value)
    local token = NormalizePlacementKey(value)
    if token:find("hill", 1, true) or token == "air" or token == "airunit" or token == "airunits"
        or token == "aerial" or token == "flying" or token == "flyingunits" or token == "elevated" or token == "hybrid" then
        return "Hill"
    end
    if token:find("ground", 1, true) or token == "land" or token == "landunits" then return "Ground" end
    if token:find("farm", 1, true) then return "Farm" end
    return DecodePlacementLabel(value)
end

local function IsTruthyMetadata(value)
    if value == true or value == 1 then return true end
    if type(value) == "string" then
        local v = value:lower():gsub("%s+", "")
        return v == "true" or v == "1" or v == "yes"
    end
    return false
end

local PLACEMENT_FIELDS = {
    placement = true,
    placementtype = true,
    placetype = true,
    deploymenttype = true,
    deploymentcategory = true,
    placementcategory = true,
    unitplacement = true,
    placementmode = true,
    placecategory = true,
    platformtype = true,
    positiontype = true,
}
local GENERIC_TYPE_FIELDS = {
    unittype = true,
    category = true,
    kind = true,
    type = true,
}
local HILL_FLAG_FIELDS = {
    hill = true, ishill = true, ishillunit = true, canplacehill = true, canplaceonhill = true,
    requireshill = true, hillplacement = true, air = true, isair = true, isairunit = true,
    aerial = true, isaerial = true, flying = true, isflying = true, elevated = true,
    iselevated = true, hybrid = true, ishybrid = true, airplacement = true,
}
local GROUND_FLAG_FIELDS = { ground = true, isground = true, land = true, island = true }
local FARM_FLAG_FIELDS = { farm = true, isfarm = true, farming = true }
local TAG_CONTAINER_FIELDS = { tags = true, unittags = true, placementtags = true, attributes = true, properties = true }

-- Reads common game-data shapes without binding the code to one unit name or ID.
-- Return score distinguishes explicit placement metadata from weak generic "type" fields.
local function ReadPlacementMetadata(metadata)
    if type(metadata) ~= "table" then return nil, 0 end
    local seen = {}
    local budget = 2400

    local function walk(node, depth, phase)
        if type(node) ~= "table" or depth > 8 or seen[node] or budget <= 0 then return nil end
        seen[node] = true
        for key, value in pairs(node) do
            budget = budget - 1
            if budget <= 0 then break end
            local k = NormalizePlacementKey(key)
            if phase == 1 and PLACEMENT_FIELDS[k] then
                local decoded = DecodePlacementLabel(value)
                if decoded then return decoded end
                if type(value) == "table" then
                    for nestedKey, nestedValue in pairs(value) do
                        local d = DecodePlacementLabel(nestedKey) or DecodePlacementLabel(nestedValue)
                        if d then return d end
                    end
                end
            elseif phase == 2 then
                local keyType = DecodePlacementLabel(tostring(key))
                if keyType and IsTruthyMetadata(value) then return keyType end
                if HILL_FLAG_FIELDS[k] and IsTruthyMetadata(value) then return "Hill" end
                if FARM_FLAG_FIELDS[k] and IsTruthyMetadata(value) then return "Farm" end
                if GROUND_FLAG_FIELDS[k] and IsTruthyMetadata(value) then return "Ground" end
                if TAG_CONTAINER_FIELDS[k] and type(value) == "string" then
                    local tagType = DecodePlacementLabel(value)
                    if tagType then return tagType end
                elseif TAG_CONTAINER_FIELDS[k] and type(value) == "table" then
                    for tagKey, tagValue in pairs(value) do
                        local d = DecodePlacementLabel(tagValue)
                        if not d and IsTruthyMetadata(tagValue) then d = DecodePlacementGroup(tagKey) end
                        if d then return d end
                        if type(tagValue) == "table" then
                            for innerKey, innerValue in pairs(tagValue) do
                                local inner = DecodePlacementLabel(innerValue)
                                if not inner and IsTruthyMetadata(innerValue) then inner = DecodePlacementGroup(innerKey) end
                                if inner then return inner end
                            end
                        end
                    end
                end
            elseif phase == 3 and GENERIC_TYPE_FIELDS[k] then
                local decoded = DecodePlacementLabel(value)
                if decoded then return decoded end
            end
            if type(value) == "table" then
                local result = walk(value, depth + 1, phase)
                if result then return result end
            end
        end
        return nil
    end

    -- Dedicated placement fields outrank tags; tags/boolean flags outrank generic "type".
    for phase = 1, 3 do
        seen = {}
        budget = 2400
        local result = walk(metadata, 0, phase)
        if result then
            local confidence = (phase == 1 and 4) or (phase == 2 and 3) or 1
            return result, confidence
        end
    end
    return nil, 0
end

local function FindPlacementInUnitTags(unitId, unitName)
    if type(UnitTags) ~= "table" then return nil, 0 end
    local targetIds = {}
    local function addTarget(value)
        local n = NormalizePlacementKey(value)
        if n ~= "" then targetIds[n] = true end
    end
    addTarget(unitId)
    addTarget(NormalizeUnitIdentifier(unitId))
    addTarget(unitName)
    if next(targetIds) == nil then return nil, 0 end

    local function containsTarget(node, depth, seen)
        if depth > 8 then return false end
        if type(node) ~= "table" then return targetIds[NormalizePlacementKey(node)] == true end
        if seen[node] then return false end
        seen[node] = true
        for k, v in pairs(node) do
            if targetIds[NormalizePlacementKey(k)] or targetIds[NormalizePlacementKey(v)] then return true end
            if type(v) == "table" and containsTarget(v, depth + 1, seen) then return true end
        end
        return false
    end

    local function findCategoryBucket(node, desired, depth, seen)
        if type(node) ~= "table" or depth > 9 or seen[node] then return false end
        seen[node] = true
        for key, value in pairs(node) do
            if DecodePlacementGroup(key) == desired then
                if type(value) == "table" and containsTarget(value, 0, {}) then return true end
                if targetIds[NormalizePlacementKey(value)] then return true end
            end
            if type(value) == "table" and findCategoryBucket(value, desired, depth + 1, seen) then return true end
        end
        return false
    end

    -- When unit tags contain multiple classification groups, prefer Hill/Air before Ground.
    for _, desired in ipairs({"Hill", "Farm", "Ground"}) do
        if findCategoryBucket(UnitTags, desired, 0, {}) then return desired, 3 end
    end

    local function readTagBranch(node, depth, seen)
        if depth > 8 or type(node) ~= "table" or seen[node] then return nil end
        seen[node] = true
        for key, value in pairs(node) do
            local decoded = DecodePlacementGroup(key)
            if decoded and IsTruthyMetadata(value) then return decoded end
            decoded = DecodePlacementLabel(value)
            if decoded then return decoded end
            if type(value) == "table" then
                local result = readTagBranch(value, depth + 1, seen)
                if result then return result end
            end
        end
        return nil
    end

    local seen = {}
    local budget = 5000
    local function walk(node, depth)
        if type(node) ~= "table" or depth > 9 or seen[node] or budget <= 0 then return nil end
        seen[node] = true
        for key, value in pairs(node) do
            budget = budget - 1
            if budget <= 0 then break end
            if targetIds[NormalizePlacementKey(key)] and type(value) == "table" then
                local tagType = readTagBranch(value, 0, {})
                if tagType then return tagType end
            end
            if type(value) == "table" then
                local result = walk(value, depth + 1)
                if result then return result end
            end
        end
        return nil
    end

    local result = walk(UnitTags, 0)
    return result, result and 3 or 0
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

local function ClassifyUnitPlacementType(unitId, unitName, runtimeUnitData)
    local checkStr = (tostring(unitId or "") .. " " .. tostring(unitName or "")):lower()
    for farmKey, isFarm in pairs(FARM_UNIT_FALLBACK) do
        if isFarm and checkStr:find(tostring(farmKey):lower(), 1, true) then
            return "Farm", 4
        end
    end

    local uEntry = LookupUnitDataEntry(unitId, unitName)
    local bestType, bestConfidence = nil, 0
    local function consider(candidate, confidence)
        if candidate and (confidence or 0) > bestConfidence then
            bestType, bestConfidence = candidate, confidence
        end
    end

    -- Runtime inventory/unit data and static Units data can have different schemas.
    local runtimeType, runtimeConfidence = ReadPlacementMetadata(runtimeUnitData)
    local entryType, entryConfidence = ReadPlacementMetadata(uEntry)
    consider(runtimeType, runtimeConfidence)
    consider(entryType, entryConfidence)

    local tagsType, tagsConfidence = FindPlacementInUnitTags(unitId, unitName)
    consider(tagsType, tagsConfidence)

    -- Check table-level tags/flags as a final metadata source.
    if type(uEntry) == "table" then
        local entryTags = uEntry.tags or uEntry.tag or uEntry.placement_tags or uEntry.placementTags
        local tagsClass, tagsScore = ReadPlacementMetadata({ tags = entryTags })
        consider(tagsClass, tagsScore)
    end

    if bestType then return bestType, bestConfidence end

    -- The metadata had no reliable placement field. Return Ground as a first trial,
    -- but confidence 0 signals that Auto Play must try Hill too if the server rejects it.
    return "Ground", 0
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

local UNIT_CAP_NEST_KEYS = {
    placement = true, deployment = true, deploy = true, spawn = true,
    stats = true, limits = true, config = true, unitdata = true,
    unit_data = true, data = true, metadata = true,
}

local UNIT_CAP_PRIORITY = {
    "spawncap", "maxplaced", "maxcap", "placementlimit", "maxunitsplaced",
    "unitcap", "maxdeployed", "deploycap", "maxdeployment", "deploymentlimit",
    "placelimit", "spawnlimit", "unitlimit", "maxunits", "maxcount", "limit"
}

local function ReadUnitPlacementCap(source, depth)
    if type(source) ~= "table" or (depth or 0) > 3 then return nil end
    depth = depth or 0
    local valuesByKey = {}
    for key, value in pairs(source) do
        local normalized = tostring(key):lower():gsub("[^%w]", "")
        valuesByKey[normalized] = value
    end
    -- Prefer explicit placement/spawn cap fields; generic "limit" is checked last.
    for _, key in ipairs(UNIT_CAP_PRIORITY) do
        local numberValue = tonumber(valuesByKey[key])
        if numberValue and numberValue >= 1 and numberValue <= 99 then
            return math.floor(numberValue)
        end
    end
    for key, value in pairs(source) do
        local normalized = tostring(key):lower():gsub("[^%w]", "")
        if type(value) == "table" and UNIT_CAP_NEST_KEYS[normalized] then
            local cap = ReadUnitPlacementCap(value, depth + 1)
            if cap then return cap end
        end
    end
    return nil
end

local function GetEquippedUnitsDetailed()
    local results = {}
    local seenUUID = {}
    local session = GetInventorySessionTable()

    local ownedUnitsMap = nil
    local equippedUnitsMap = nil

    if type(session) == "table" then
        if session.collection and session.collection.collection_profile_data then
            ownedUnitsMap = session.collection.collection_profile_data.owned_units
            equippedUnitsMap = session.collection.collection_profile_data.equipped_units
        else
            ownedUnitsMap = session.owned_units
            equippedUnitsMap = session.equipped_units
        end
    end

    local function AddUnitEntry(uuid, unitId, levelVal)
        if type(uuid) == "string" and uuid ~= "" and not seenUUID[uuid] then
            seenUUID[uuid] = true
            local uId = tostring(unitId or "")
            local uLvl = tonumber(levelVal) or 1

            if ownedUnitsMap and type(ownedUnitsMap[uuid]) == "table" then
                local oData = ownedUnitsMap[uuid]
                if uId == "" then uId = tostring(oData.unit_id or oData.id or "") end
                uLvl = tonumber(oData.level) or uLvl
            end

            local runtimeUnitData = nil
            if UnitCollectionServiceClient and type(UnitCollectionServiceClient.get_unit_data) == "function" then
                local ok, uData = pcall(UnitCollectionServiceClient.get_unit_data, uuid)
                if ok and type(uData) == "table" then
                    runtimeUnitData = uData
                    if uId == "" then uId = tostring(uData.unit_id or uData.id or "") end
                    uLvl = tonumber(uData.level) or uLvl
                end
            end

            local uEntry = LookupUnitDataEntry(uId, uId)
            local displayName = (uEntry and uEntry.name and tostring(uEntry.name)) or uId
            -- Prefer explicit placement-cap metadata from the game data/runtime unit schema.
            -- The user no longer configures this manually.
            local maxCap = ReadUnitPlacementCap(runtimeUnitData) or ReadUnitPlacementCap(uEntry) or 4
            local baseDmg = tonumber(uEntry and (uEntry.damage or uEntry.Damage or uEntry.atk)) or 10
            local realDmg = math.floor((baseDmg * (1 + (uLvl - 1) * 0.035)) + 0.5)

            local classifiedType, placementConfidence = ClassifyUnitPlacementType(uId, displayName, runtimeUnitData)
            local overrideType = State.UnitPlacementOverrides[uuid]
            if overrideType then
                classifiedType = overrideType
                placementConfidence = State.UnitPlacementOverrideConfirmed[uuid] and 4 or 0
            end

            table.insert(results, {
                uuid = uuid,
                unit_id = uId,
                unit_name = displayName,
                level = uLvl,
                damage = realDmg,
                max_cap = maxCap,
                placement_type = classifiedType,
                placement_confidence = placementConfidence or 0
            })
        end
    end

    if type(equippedUnitsMap) == "table" then
        for i = 1, 6 do
            local u = equippedUnitsMap[tostring(i)] or equippedUnitsMap[i]
            if type(u) == "string" then AddUnitEntry(u, nil, nil) end
        end
        for _, u in pairs(equippedUnitsMap) do
            if type(u) == "string" then AddUnitEntry(u, nil, nil) end
        end
    end

    if #results == 0 and UnitCollectionServiceClient and type(UnitCollectionServiceClient.get_equipped_units) == "function" then
        local ok, equipped = pcall(UnitCollectionServiceClient.get_equipped_units)
        if ok and type(equipped) == "table" then
            for i = 1, 6 do
                local u = equipped[tostring(i)] or equipped[i]
                if type(u) == "string" then AddUnitEntry(u, nil, nil) end
            end
            for _, u in pairs(equipped) do
                if type(u) == "string" then AddUnitEntry(u, nil, nil) end
            end
        end
    end

    return results
end

-- Auto-equip helper is forward-declared so the entry guard can fill an empty team.
local AutoEquipStrongestUnits
local LastNoEquippedWarningAt = 0
local LastEnsureAutoEquipAttemptAt = 0

-- Entry guard: require at least one equipped unit, never exactly four.
-- If the team is empty, automatically equip up to the available unique unit types (max 4),
-- then wait for the equipped-team state to replicate before blocking entry.
local function EnsureEquippedTeamBeforePlay(context, statusCallback)
    local function ReadEquippedCount()
        local ok, equipped = pcall(GetEquippedUnitsDetailed)
        if ok and type(equipped) == "table" then
            return #equipped
        end
        return 0
    end

    for attempt = 1, 4 do
        local count = ReadEquippedCount()
        if count > 0 then
            return true, count
        end
        if attempt < 4 then task.wait(0.35) end
    end

    -- Avoid repeatedly unequipping/re-equipping when several guards run close together.
    if type(AutoEquipStrongestUnits) == "function"
        and (os.clock() - LastEnsureAutoEquipAttemptAt) >= 8 then
        LastEnsureAutoEquipAttemptAt = os.clock()
        if statusCallback then
            pcall(function()
                statusCallback("⚔️ ยังไม่มีตัวละครในทีม — กำลังใส่ตัวที่มีให้อัตโนมัติ สูงสุด 4 ตัวและไม่ซ้ำชนิด...")
            end)
        end
        local equipOk, equipCount = pcall(AutoEquipStrongestUnits, KaitanConfig.MaxEquipUnits or 4)
        if equipOk and (tonumber(equipCount) or 0) > 0 then
            for attempt = 1, 8 do
                task.wait(0.35)
                local count = ReadEquippedCount()
                if count > 0 then
                    return true, count
                end
            end
        end
    end

    local message = "⛔ ไม่พบตัวละครที่ใส่ในทีม จึงไม่เข้าเกม (" .. tostring(context or "Auto Join") .. ") — ระบบจะใส่ตัวที่มีให้อัตโนมัติสูงสุด 4 ตัว โดยไม่ซ้ำชนิด; ถ้ายังไม่ผ่านให้ตรวจว่ามียูนิตอยู่ในคลังหรือไม่"
    if statusCallback then
        pcall(function() statusCallback(message) end)
    end
    if os.clock() - LastNoEquippedWarningAt >= 8 then
        LastNoEquippedWarningAt = os.clock()
        pcall(function()
            Fluent:Notify({
                Title = "ไม่พบตัวละครในทีม",
                Content = "ยกเลิกการเข้าเกมแล้ว ระบบลองใส่ตัวที่มีให้อัตโนมัติแล้ว (สูงสุด 4 ตัว ไม่ซ้ำชนิด)",
                Duration = 5
            })
        end)
    end
    return false, 0
end

AutoEquipStrongestUnits = function(maxCount)
    -- Timestamp any equip attempt so the entry guard does not immediately run a second
    -- unequip/equip cycle while the game's equipped-team data is still replicating.
    LastEnsureAutoEquipAttemptAt = os.clock()
    maxCount = math.floor(tonumber(maxCount) or tonumber(KaitanConfig.MaxEquipUnits) or 4)
    maxCount = math.clamp(maxCount, 1, 4)
    local unequipDelay = KaitanConfig.UnequipDelay or 1.2
    local equipDelay = KaitanConfig.EquipDelay or 1.0

    local unitList = {}
    local session = GetInventorySessionTable()
    local ownedMap = nil

    if type(session) == "table" then
        if session.collection and session.collection.collection_profile_data then
            ownedMap = session.collection.collection_profile_data.owned_units
        else
            ownedMap = session.owned_units
        end
    end

    if type(ownedMap) == "table" then
        for uuidKey, uData in pairs(ownedMap) do
            if type(uData) == "table" then
                local rawId = uData.unit_id or uData.id
                local lvl = tonumber(uData.level) or 1
                local finalUUID = tostring(uData.uuid or uuidKey)
                if rawId then
                    local cleanId = NormalizeUnitIdentifier(rawId)
                    local info = LookupUnitDataEntry(cleanId, cleanId)
                    local displayName = (info and (info.name or info.id)) or cleanId
                    local baseDmg = tonumber(info and (info.damage or info.Damage or info.atk)) or 0
                    local realDamage = math.floor((baseDmg * (1 + (lvl - 1) * 0.035)) + 0.5)

                    table.insert(unitList, {
                        UUID = finalUUID,
                        ID = cleanId,
                        Name = displayName,
                        Level = lvl,
                        Damage = realDamage
                    })
                end
            end
        end
    end

    if #unitList == 0 then return 0 end

    table.sort(unitList, function(a, b)
        return a.Damage > b.Damage
    end)

    -- Keep only one copy of each unit type in the team; retain its strongest owned variant.
    local uniqueUnits, seenUnitTypes = {}, {}
    for _, unit in ipairs(unitList) do
        local key = NormalizeUnitIdentifier(unit.ID or unit.Name)
        if key ~= "" and not seenUnitTypes[key] then
            seenUnitTypes[key] = true
            table.insert(uniqueUnits, unit)
        end
    end
    unitList = uniqueUnits

    InvokeServer("unequip_all", nil)
    task.wait(unequipDelay)

    local totalToEquip = math.min(maxCount, #unitList)
    local equippedCount = 0

    for i = 1, totalToEquip do
        local u = unitList[i]
        for attempt = 1, 2 do
            local res = InvokeServer("equip_unit", u.UUID)
            if res ~= false then
                equippedCount = equippedCount + 1
                break
            else
                task.wait(0.5)
            end
        end
        task.wait(equipDelay)
    end

    return equippedCount
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

local function FireGuiButton(btn)
    if not btn then return false end
    if typeof(firesignal) == "function" then
        pcall(function() firesignal(btn.Activated) end)
        pcall(function() firesignal(btn.MouseButton1Click) end)
        return true
    end
    if typeof(getconnections) == "function" then
        for _, sig in ipairs({btn.Activated, btn.MouseButton1Click}) do
            if sig then
                local ok, conns = pcall(getconnections, sig)
                if ok and type(conns) == "table" then
                    for _, conn in ipairs(conns) do
                        if conn and type(conn.Fire) == "function" then
                            pcall(function() conn:Fire() end)
                        elseif conn and type(conn.Function) == "function" then
                            task.spawn(conn.Function)
                        end
                    end
                end
            end
        end
        return true
    end
    return false
end

local function SafeUpdateParagraph(para, title, desc)
    if not para then return end
    if title then pcall(function() para:SetTitle(title) end) end
    if desc then
        local ok = pcall(function() para:SetDesc(desc) end)
        if not ok then pcall(function() para:SetValue(desc) end) end
    end
end

---------------------------------------------------------------------
-- 3. ROAD SCANNER, PATH VISUALIZER & HOLOGRAM ENGINE
---------------------------------------------------------------------
local groundRayParams = RaycastParams.new()
groundRayParams.FilterType = Enum.RaycastFilterType.Exclude
groundRayParams.IgnoreWater = true

local hillOnlyRayParams = RaycastParams.new()
hillOnlyRayParams.FilterType = Enum.RaycastFilterType.Include
hillOnlyRayParams.IgnoreWater = true

local function RefreshPlacementRayFilter()
    local ignore = {}
    if LocalPlayer and LocalPlayer.Character then table.insert(ignore, LocalPlayer.Character) end
    if State.HologramFolder then table.insert(ignore, State.HologramFolder) end
    if State.RoadVisualFolder then table.insert(ignore, State.RoadVisualFolder) end
    if Workspace:FindFirstChild("_TD_Holograms") then table.insert(ignore, Workspace._TD_Holograms) end
    if Workspace:FindFirstChild("_TD_RoadVisual") then table.insert(ignore, Workspace._TD_RoadVisual) end
    if Workspace:FindFirstChild("_UNITS") then table.insert(ignore, Workspace._UNITS) end
    if Workspace:FindFirstChild("_ENEMIES") then table.insert(ignore, Workspace._ENEMIES) end
    if Workspace:FindFirstChild("_FX") then table.insert(ignore, Workspace._FX) end
    if Workspace:FindFirstChild("_ignore") then table.insert(ignore, Workspace._ignore) end
    if Workspace:FindFirstChild("_PROJECTILES") then table.insert(ignore, Workspace._PROJECTILES) end
    groundRayParams.FilterDescendantsInstances = ignore
end

local function SnapPositionToGroundOrRoad(pos)
    RefreshPlacementRayFilter()
    local res = Workspace:Raycast(Vector3.new(pos.X, pos.Y + 25, pos.Z), Vector3.new(0, -65, 0), groundRayParams)
    if res and res.Position then
        return res.Position
    end
    return pos
end

local function BuildPlacementCFrame(posOrCF)
    RefreshPlacementRayFilter()
    local rawPos = typeof(posOrCF) == "CFrame" and posOrCF.Position or posOrCF
    if typeof(rawPos) ~= "Vector3" then return nil end

    -- Preserve the sampled surface coordinate. Snap only when the hit is nearby;
    -- do not apply an arbitrary height offset to the unit pivot.
    local hit = Workspace:Raycast(
        rawPos + Vector3.new(0, 6, 0),
        Vector3.new(0, -18, 0),
        groundRayParams
    )
    local placePos = rawPos
    if hit and hit.Position and math.abs(hit.Position.Y - rawPos.Y) <= 3.5 then
        placePos = hit.Position
    end

    if Util and type(Util.CFramePLV) == "function" then
        local ok, cf = pcall(Util.CFramePLV, placePos, Vector3.new(0, 0, -1), Vector3.new(0, 1, 0))
        if ok and typeof(cf) == "CFrame" then return cf end
    end
    return CFrame.new(placePos)
end

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

local function FlatDist2D(v1, v2)
    return Vector3.new(v1.X - v2.X, 0, v1.Z - v2.Z).Magnitude
end

local function FindBaseAnchorPosition(roadInfos, endpointIndices)
    local bases = Workspace:FindFirstChild("_BASES") or Workspace:FindFirstChild("Bases")
    local candidates, seen = {}, {}

    local function normalized(value)
        return string.lower(tostring(value or "")):gsub("[%s%-]+", "_")
    end

    local function explicitBaseName(name)
        name = normalized(name)
        return name == "base" or name == "_base" or name == "base_part"
            or name == "player_base" or name == "base_point" or name == "base_spawn"
            or name == "goal" or name == "goal_point" or name == "goalpoint"
            or name == "home_base" or name == "pve_base" or name == "core"
            or name:find("player_base", 1, true) ~= nil
            or name:find("base_point", 1, true) ~= nil
            or name:find("base_spawn", 1, true) ~= nil
            or name:find("goal_point", 1, true) ~= nil
    end

    local function valueBelongsToLocalPlayer(value)
        if value == nil then return false end
        if typeof(value) == "Instance" then
            if value == LocalPlayer then return true end
            local n = value.Name and tostring(value.Name):lower() or ""
            return n == tostring(LocalPlayer.Name):lower()
                or (LocalPlayer.UserId and n == tostring(LocalPlayer.UserId))
        end
        local s = tostring(value):lower()
        return s == tostring(LocalPlayer.Name):lower()
            or s == tostring(LocalPlayer.UserId):lower()
    end

    local function isOwnedByLocalPlayer(inst)
        local cur = inst
        while cur and cur ~= Workspace do
            if normalized(cur.Name) == normalized(LocalPlayer.Name) then
                return true
            end
            for _, attrName in ipairs({"player", "Player", "owner", "Owner", "PlayerName", "OwnerName", "UserId", "OwnerUserId"}) do
                local ok, attr = pcall(function() return cur:GetAttribute(attrName) end)
                if ok and valueBelongsToLocalPlayer(attr) then return true end
            end
            local stats = cur:FindFirstChild("_stats") or cur:FindFirstChild("stats") or cur:FindFirstChild("Stats")
            if stats then
                for _, key in ipairs({"player", "owner", "Player", "Owner", "user", "UserId", "owner_user_id"}) do
                    local valueObj = stats:FindFirstChild(key)
                    if valueObj then
                        local ok, value = pcall(function() return valueObj.Value end)
                        if ok and valueBelongsToLocalPlayer(value) then return true end
                    end
                end
            end
            if bases and cur == bases then break end
            cur = cur.Parent
        end
        return false
    end

    local function add(inst, priority, reason)
        if not inst or seen[inst] then return end
        local pos = ExtractObjectPos(inst)
        if pos then
            seen[inst] = true
            table.insert(candidates, {pos = pos, priority = priority or 3, instance = inst, reason = reason or "unknown"})
        end
    end

    -- First priority: the actual local player's base, even if the map names it
    -- with a user id or an unrelated model name instead of "base".
    if bases then
        for _, child in ipairs(bases:GetChildren()) do
            if isOwnedByLocalPlayer(child) then add(child, 0, "local-player-base") end
            if explicitBaseName(child.Name) then add(child, 1, "named-base-root") end
            -- Important fallback: each entry under _BASES may be a base model
            -- named after a player, even when its name contains no word 'base'.
            add(child, 3, "bases-child-fallback")
        end

        for _, inst in ipairs(bases:GetDescendants()) do
            if explicitBaseName(inst.Name) then
                add(inst, isOwnedByLocalPlayer(inst) and 0 or 1, "named-base-descendant")
            elseif isOwnedByLocalPlayer(inst) and inst:IsA("Model") then
                add(inst, 0, "owned-base-model")
            end
        end
    end

    -- If the game does not have _BASES, fall back only to explicit map markers,
    -- excluding every script-generated folder.
    local roadVisual = Workspace:FindFirstChild("_TD_RoadVisual")
    local holograms = Workspace:FindFirstChild("_TD_Holograms")
    local macroMarkers = Workspace:FindFirstChild("_TD_MacroMarkers")
    for _, inst in ipairs(Workspace:GetDescendants()) do
        local generated = (roadVisual and inst:IsDescendantOf(roadVisual))
            or (holograms and inst:IsDescendantOf(holograms))
            or (macroMarkers and inst:IsDescendantOf(macroMarkers))
        local insideBaseFolder = bases and inst:IsDescendantOf(bases)
        if not generated and not insideBaseFolder and explicitBaseName(inst.Name) then
            add(inst, bases and 4 or 2, "explicit-world-marker")
        end
    end

    if #candidates == 0 then return nil end

    local best, bestScore = nil, math.huge
    for _, candidate in ipairs(candidates) do
        local nearest = 0
        if roadInfos and endpointIndices and #endpointIndices > 0 then
            nearest = math.huge
            for _, idx in ipairs(endpointIndices) do
                local info = roadInfos[idx]
                if info then
                    local d = FlatDist2D(candidate.pos, info.center)
                    if d < nearest then nearest = d end
                end
            end
        end
        -- Ownership/name is the primary signal. When several player bases exist,
        -- distance to an actual terminal road tile chooses the correct anchor.
        local score = candidate.priority * 10000 + nearest
        if score < bestScore then best, bestScore = candidate, score end
    end

    if best and roadInfos and endpointIndices and #endpointIndices > 0 then
        local nearest = math.huge
        for _, idx in ipairs(endpointIndices) do
            local info = roadInfos[idx]
            if info then nearest = math.min(nearest, FlatDist2D(best.pos, info.center)) end
        end
        -- Reject distant decorative props; callers will then use the connected
        -- road's far endpoint rather than stopping at an unrelated object.
        if nearest > 160 then return nil end
    end
    return best and best.pos or nil
end

-- The route builder calls this function to choose the monster-side endpoint.
-- On some maps `initial_spawn` is a non-spatial marker (e.g. a light) whose
-- parent is the actual map Part; on others it is a Part or Model itself.
local function FindMonsterSpawnAnchorPosition(roadInfos, endpointIndices)
    local priorities = {
        initial_spawn = 1,
        monster_spawn = 2,
        enemy_spawn = 2,
        mob_spawn = 3,
        spawn_point = 3,
        spawnpoint = 3,
        enemy_start = 3,
        monster_start = 3,
    }
    local candidates = {}
    local roadVisual = Workspace:FindFirstChild("_TD_RoadVisual")
    local holograms = Workspace:FindFirstChild("_TD_Holograms")
    local macroMarkers = Workspace:FindFirstChild("_TD_MacroMarkers")
    local enemies = Workspace:FindFirstChild("_ENEMIES") or Workspace:FindFirstChild("Enemies")

    local function getPosition(inst)
        if inst:IsA("BasePart") then return inst.Position end
        if inst:IsA("Model") then
            local ok, pivot = pcall(function() return inst:GetPivot() end)
            if ok and pivot then return pivot.Position end
        end
        local parent = inst.Parent
        if parent and parent:IsA("BasePart") then return parent.Position end
        local bp = inst:FindFirstChildWhichIsA("BasePart", true)
        return bp and bp.Position or nil
    end

    for _, inst in ipairs(Workspace:GetDescendants()) do
        local name = string.lower(tostring(inst.Name)):gsub("[%s%-]+", "_")
        local priority = priorities[name]
        local generated = (roadVisual and inst:IsDescendantOf(roadVisual))
            or (holograms and inst:IsDescendantOf(holograms))
            or (macroMarkers and inst:IsDescendantOf(macroMarkers))
            or (enemies and inst:IsDescendantOf(enemies))
        if priority and not generated then
            local pos = getPosition(inst)
            if pos then table.insert(candidates, { pos = pos, priority = priority, instance = inst }) end
        end
    end
    if #candidates == 0 then return nil end
    if not roadInfos or not endpointIndices or #endpointIndices == 0 then
        table.sort(candidates, function(a, b) return a.priority < b.priority end)
        return candidates[1].pos
    end

    local best, bestScore = nil, math.huge
    for _, c in ipairs(candidates) do
        local nearest = math.huge
        for _, idx in ipairs(endpointIndices) do
            local d = FlatDist2D(c.pos, roadInfos[idx].center)
            if d < nearest then nearest = d end
        end
        local score = (c.priority * 1000) + nearest
        if score < bestScore then best, bestScore = c, score end
    end
    if best and bestScore < math.huge then
        local nearest = math.huge
        for _, idx in ipairs(endpointIndices) do
            local d = FlatDist2D(best.pos, roadInfos[idx].center)
            if d < nearest then nearest = d end
        end
        if nearest <= 150 then return best.pos end
    end
    return nil
end

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
        ScanTerrainHillParts()
    end
    if #State.HillGeometries == 0 then
        return nil, nil
    end

    -- Candidate surfaces are only parts under Workspace._terrain.hill.
    -- Try every overlapping part from highest to lowest instead of trusting
    -- the first bounding box (which can belong to decorative/overlapping geometry).
    local candidates = {}
    for _, g in ipairs(State.HillGeometries) do
        local part = g.part
        if part and part.Parent then
            local localPt = g.cf:PointToObjectSpace(Vector3.new(worldX, part.Position.Y, worldZ))
            local margin = math.min(0.8, math.max(0.15, math.min(g.size.X, g.size.Z) * 0.08))
            if math.abs(localPt.X) <= (g.size.X * 0.5 - margin)
                and math.abs(localPt.Z) <= (g.size.Z * 0.5 - margin) then
                table.insert(candidates, g)
            end
        end
    end
    table.sort(candidates, function(a, b) return a.topY > b.topY end)

    for _, g in ipairs(candidates) do
        hillOnlyRayParams.FilterDescendantsInstances = { g.part }
        local startY = math.max(g.topY + 80, g.part.Position.Y + 80)
        local rayRes = Workspace:Raycast(
            Vector3.new(worldX, startY, worldZ),
            Vector3.new(0, -360, 0),
            hillOnlyRayParams
        )
        if rayRes and rayRes.Instance == g.part and rayRes.Position and rayRes.Normal.Y >= 0.72 then
            hillOnlyRayParams.FilterDescendantsInstances = State.HillPartInstances
            return rayRes.Position, rayRes.Instance
        end
    end

    hillOnlyRayParams.FilterDescendantsInstances = State.HillPartInstances
    return nil, nil
end

local function FindClosestPointOnTerrainHill(roadPos)
    if #State.HillGeometries == 0 then ScanTerrainHillParts() end
    if #State.HillGeometries == 0 then return nil, nil end

    local bestWorldPos, bestHillGeom, bestDistance = nil, nil, math.huge
    for _, g in ipairs(State.HillGeometries) do
        local part = g.part
        if part and part.Parent then
            local localPt = g.cf:PointToObjectSpace(roadPos)
            local marginX = math.min(1.0, math.max(0.2, g.size.X * 0.08))
            local marginZ = math.min(1.0, math.max(0.2, g.size.Z * 0.08))
            local maxX = math.max(0, g.size.X * 0.5 - marginX)
            local maxZ = math.max(0, g.size.Z * 0.5 - marginZ)
            local cx = math.clamp(localPt.X, -maxX, maxX)
            local cz = math.clamp(localPt.Z, -maxZ, maxZ)
            local sx = math.max(1.0, math.min(2.5, g.size.X * 0.18))
            local sz = math.max(1.0, math.min(2.5, g.size.Z * 0.18))

            -- Sample a small local grid to find a real top-face hit. No topY fallback.
            for _, ox in ipairs({0, -sx, sx}) do
                for _, oz in ipairs({0, -sz, sz}) do
                    local lx = math.clamp(cx + ox, -maxX, maxX)
                    local lz = math.clamp(cz + oz, -maxZ, maxZ)
                    local world = g.cf:PointToWorldSpace(Vector3.new(lx, 0, lz))
                    local surface = GetSurfacePointOnTerrainHill(world.X, world.Z)
                    if surface then
                        local d = FlatDist2D(surface, roadPos)
                        if d < bestDistance then
                            bestDistance, bestWorldPos, bestHillGeom = d, surface, g
                        end
                    end
                end
            end
        end
    end
    return bestWorldPos, bestHillGeom
end

local function SafeRaycastGround(pos, upOffset, downDist)
    local upY = upOffset or 12
    local downY = downDist or -45
    local res = Workspace:Raycast(Vector3.new(pos.X, pos.Y + upY, pos.Z), Vector3.new(0, downY, 0), groundRayParams)
    if res and res.Position then
        return res.Position, res.Instance, res.Normal
    end
    return pos, nil, Vector3.new(0, 1, 0)
end

-- Hill placement: keep the exact surface returned by the source hill geometry.
-- Do NOT pass hill points through SnapPositionToGroundOrRoad, which can snap them to the lower ground.
local function BuildHillPlacementCFrame(posOrCF)
    local rawPos = typeof(posOrCF) == "CFrame" and posOrCF.Position or posOrCF
    if typeof(rawPos) ~= "Vector3" then return nil end
    local surfacePos = GetSurfacePointOnTerrainHill(rawPos.X, rawPos.Z)
    if not surfacePos then
        surfacePos = FindClosestPointOnTerrainHill(rawPos)
    end
    if not surfacePos then return nil end

    -- Use the exact point on the hill surface. Do not add a vertical offset:
    -- the placement service expects the same surface coordinate that was raycast.
    if Util and type(Util.CFramePLV) == "function" then
        local ok, cf = pcall(Util.CFramePLV, surfacePos, Vector3.new(0, 0, -1), Vector3.new(0, 1, 0))
        if ok and typeof(cf) == "CFrame" then return cf end
    end
    return CFrame.new(surfacePos)
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

    RefreshPlacementRayFilter()
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

local function GetPlayerReferencePos()
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if hrp then return hrp.Position end
    local spawnLoc = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
    if spawnLoc then return spawnLoc.Position end
    return nil
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

    local baseAnchor = nil
    if not tostring(label):find("BASE%-to%-SPAWN endpoint path") then
        baseAnchor = FindBaseAnchorPosition()
    end
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
    -- Build one centerline from the actual numbered road parts.
    -- Use each road Part's center rather than both side endpoints; endpoints
    -- of wide/rotated road tiles created the parallel red lines on this map.
    if #numberedSegs < 2 then return nil end

    table.sort(numberedSegs, function(x, y)
        local nx, ny = (x.numIndex or 0), (y.numIndex or 0)
        if nx ~= ny then return nx < ny end
        if x.center.X ~= y.center.X then return x.center.X < y.center.X end
        return x.center.Z < y.center.Z
    end)

    local ordered = {}
    local remaining = {}
    for _, info in ipairs(numberedSegs) do
        table.insert(remaining, info)
    end

    -- Pick one connected chain. At each step take the closest remaining road
    -- center, preferring the next numeric index; stop rather than drawing a
    -- long connector across unrelated road branches.
    local first = table.remove(remaining, 1)
    table.insert(ordered, first)
    local maxGap = 32
    while #remaining > 0 do
        local prev = ordered[#ordered]
        local bestIndex, bestScore, bestDist = nil, math.huge, math.huge
        for i, cand in ipairs(remaining) do
            local d = FlatDist2D(prev.center, cand.center)
            if d <= maxGap then
                local indexPenalty = math.abs((cand.numIndex or 0) - (prev.numIndex or 0))
                local score = d + indexPenalty * 0.75
                if score < bestScore then
                    bestIndex, bestScore, bestDist = i, score, d
                end
            end
        end
        if not bestIndex then break end
        table.insert(ordered, table.remove(remaining, bestIndex))
    end

    if #ordered < 2 then return nil end
    local chainNodes = {}
    local selectedParts = {}
    for _, info in ipairs(ordered) do
        local center = info.center
        if #chainNodes == 0 or FlatDist2D(chainNodes[#chainNodes], center) > 0.65 then
            table.insert(chainNodes, center)
            table.insert(selectedParts, info)
        end
    end
    return CompileCandidateChain(chainNodes, selectedParts, label, true)
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

-- สแกนพาร์ททั้งหมดใน workspace._terrain.hill (ไม่แก้ไข Property CanQuery ของแมพเพื่อกัน Anti-Cheat)

local function VerifyAndLockRoadWithEnemies()
    -- The route is derived from the actual _road geometry; don't switch to a nearby
    -- candidate just because enemies pass near a decorative branch.
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

-- Spec 1.1: build the numeric waypoint sequence from spawn -> 1..N -> final.
-- The live Workspace waypoint instance names are intentionally NOT renamed: the
-- ordered position array provides the same calculation benefit without mutating game state.
-- Spec 1.2: placement Raycasts exclude characters, roads, units, effects, and holograms;
-- map decorations are filtered by surface/height/collision validation rather than destroying _map.
-- This avoids irreversible local map removal and preserves the actual playable floor.
-- Build a single lane's true waypoint polyline in numeric order:
-- LANES[1].spawn -> LANES[1][1] -> LANES[1][2] -> ... -> LANES[1][N] -> LANES[1].final.
-- Numeric children must be sorted numerically (1,2,...,10), never lexicographically (1,10,2,...).
-- A LANES child represents a lane, so never concatenate unrelated lanes into one artificial path.
local function GetLaneMarkerPosition(marker, depth)
    depth = depth or 0
    if marker == nil or depth > 6 then return nil end

    local kindOk, kind = pcall(function() return typeof(marker) end)
    if kindOk then
        if kind == "Vector3" then return marker end
        if kind == "CFrame" then return marker.Position end
        if kind == "Instance" then
            if marker:IsA("BasePart") then return marker.Position end
            if marker:IsA("Attachment") then return marker.WorldPosition end
            if marker:IsA("Vector3Value") then return marker.Value end
            if marker:IsA("CFrameValue") then return marker.Value.Position end
            if marker:IsA("ObjectValue") then
                return GetLaneMarkerPosition(marker.Value, depth + 1)
            end
            if marker:IsA("Model") then
                local ok, pivot = pcall(function() return marker:GetPivot() end)
                if ok and pivot then return pivot.Position end
            end

            for _, childName in ipairs({"Position", "WorldPosition", "CFrame", "Value", "point", "Point", "part", "Part"}) do
                local child = marker:FindFirstChild(childName)
                if child then
                    local pos = GetLaneMarkerPosition(child, depth + 1)
                    if pos then return pos end
                end
            end
            if marker:IsA("ValueBase") then
                local ok, value = pcall(function() return marker.Value end)
                if ok then
                    local pos = GetLaneMarkerPosition(value, depth + 1)
                    if pos then return pos end
                end
            end
            for _, descendant in ipairs(marker:GetDescendants()) do
                if descendant:IsA("Attachment") then return descendant.WorldPosition end
                if descendant:IsA("BasePart") then return descendant.Position end
                if descendant:IsA("Vector3Value") then return descendant.Value end
                if descendant:IsA("CFrameValue") then return descendant.Value.Position end
                if descendant:IsA("ObjectValue") and descendant.Value then
                    local pos = GetLaneMarkerPosition(descendant.Value, depth + 1)
                    if pos then return pos end
                end
            end
        end
    end
    return nil
end

local function FindDirectOrNestedChild(parent, lowerName)
    if not parent then return nil end
    for _, child in ipairs(parent:GetChildren()) do
        if tostring(child.Name):lower() == tostring(lowerName):lower() then
            return child
        end
    end
    for _, child in ipairs(parent:GetDescendants()) do
        if tostring(child.Name):lower() == tostring(lowerName):lower() then
            return child
        end
    end
    return nil
end

local function BuildPathFromBaseLanes()
    local bases = Workspace:FindFirstChild("_BASES") or Workspace:FindFirstChild("Bases")
    local pve = bases and (bases:FindFirstChild("pve") or bases:FindFirstChild("PVE"))
    local lanes = pve and (pve:FindFirstChild("LANES") or pve:FindFirstChild("lanes"))
    if not lanes then return nil end

    local function fail(reason)
        State.CandidateRoadChains = {}
        State.MainRoadNodes = {}
        State.MainRoadSegments = {}
        State.MainRoadTotalLength = 0
        State.MainRoadBaseY = 0
        State.MainRoadHalfWidth = 2.5
        State.MainPartInstances = {}
        State.ActiveRoadLabel = "LANES path unavailable: " .. reason
        State.EnemyVerifiedRoad = false
        State.RoadPathBuilt = false
        warn("[TD LanePath] " .. reason)
        return false
    end

    -- Prefer the exact lane the UI/tree names: _BASES.pve.LANES["1"].
    -- If a map uses a different first lane ID, choose the lowest numeric lane only.
    local laneItems = {}
    for _, lane in ipairs(lanes:GetChildren()) do
        local laneIndex = tonumber(lane.Name)
        if laneIndex and laneIndex >= 1 and laneIndex % 1 == 0 then
            table.insert(laneItems, {index = laneIndex, instance = lane})
        end
    end
    table.sort(laneItems, function(a, b) return a.index < b.index end)
    if #laneItems == 0 then return fail("no numeric LANES children") end

    local selectedLane = lanes:FindFirstChild("1") or lanes:FindFirstChild("01") or laneItems[1].instance
    local laneIndex = tonumber(selectedLane.Name) or laneItems[1].index

    local spawnMarker = FindDirectOrNestedChild(selectedLane, "spawn")
    local finalMarker = FindDirectOrNestedChild(selectedLane, "final")
    local spawnPos = GetLaneMarkerPosition(spawnMarker)
    local finalPos = GetLaneMarkerPosition(finalMarker)
    if not spawnPos then return fail(string.format("LANES[%d].spawn has no readable position", laneIndex)) end
    if not finalPos then return fail(string.format("LANES[%d].final has no readable position", laneIndex)) end

    -- Collect only numeric waypoint children belonging to the selected lane.
    -- Special children such as _formation, spawn and final are deliberately ignored here.
    local waypoints = {}
    for _, child in ipairs(selectedLane:GetChildren()) do
        local waypointIndex = tonumber(child.Name)
        if waypointIndex and waypointIndex >= 1 and waypointIndex % 1 == 0 then
            local pos = GetLaneMarkerPosition(child)
            if pos then
                table.insert(waypoints, {index = waypointIndex, pos = pos, instance = child})
            else
                warn(string.format("[TD LanePath] LANES[%d].%s has no readable position", laneIndex, child.Name))
            end
        end
    end
    table.sort(waypoints, function(a, b) return a.index < b.index end)
    if #waypoints == 0 then
        return fail(string.format("LANES[%d] has no readable numeric waypoint children", laneIndex))
    end

    local nodes = {}
    local function appendUnique(pos)
        if not pos then return end
        local previous = nodes[#nodes]
        if not previous or (pos - previous).Magnitude > 0.05 then
            table.insert(nodes, pos)
        end
    end

    -- Exact required order: spawn, 1, 2, 3, ... N, final.
    appendUnique(spawnPos)
    for _, waypoint in ipairs(waypoints) do
        appendUnique(waypoint.pos)
    end
    appendUnique(finalPos)

    if #nodes < 2 then return fail("ordered lane path contains fewer than two unique positions") end

    local segments, totalLength = {}, 0
    for i = 1, #nodes - 1 do
        local a, b = nodes[i], nodes[i + 1]
        local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
        local length = flat.Magnitude
        if length > 0.15 then
            local direction = flat.Unit
            table.insert(segments, {
                a = a,
                b = b,
                dir = direction,
                right = Vector3.new(-direction.Z, 0, direction.X),
                len = length,
                startDist = totalLength
            })
            totalLength = totalLength + length
        end
    end
    if #segments == 0 or totalLength < 1 then
        return fail("ordered lane waypoints do not form a usable path")
    end

    State.MainRoadNodes = nodes
    State.MainRoadSegments = segments
    State.MainRoadTotalLength = totalLength
    State.MainRoadBaseY = finalPos.Y
    State.MainRoadHalfWidth = 2.5
    State.MainPartInstances = {}
    State.ActiveRoadLabel = string.format("_BASES.pve.LANES[%d]: spawn -> %d numeric waypoint(s) -> final", laneIndex, #waypoints)
    State.EnemyVerifiedRoad = true
    State.CandidateRoadChains = {{
        label = State.ActiveRoadLabel,
        nodes = nodes,
        segments = segments,
        totalLength = totalLength,
        baseY = State.MainRoadBaseY,
        halfWidth = State.MainRoadHalfWidth,
        partInstances = {},
        score = totalLength
    }}
    -- Keep this count aligned with the outer updater, which detects number of lane folders.
    State.RoadLaneChildCount = #laneItems
    State.RoadPathBuilt = true
    warn(string.format(
        "[TD LanePath] Built LANES[%d]: spawn -> numeric waypoints [1..N] (%d point(s)) -> final; %d segment(s), %.1f studs",
        laneIndex, #waypoints, #segments, totalLength
    ))
    return true
end

local function BuildMainRoadPathFromWorkspace(force)
    RefreshPlacementRayFilter()
    ScanTerrainHillParts()

    -- If this map exposes _BASES.pve.LANES, use it as the only route source.
    -- Do not fall through to heuristic _road graph guessing when LANES exists.
    local laneBuild = BuildPathFromBaseLanes()
    if laneBuild ~= nil then return laneBuild end

    local roadRoot = Workspace:FindFirstChild("_road") or Workspace:FindFirstChild("road")
    local ground = roadRoot and roadRoot:FindFirstChild("ground")
    if not ground then
        State.CandidateRoadChains = {}
        State.MainRoadNodes = {}
        State.MainRoadSegments = {}
        State.MainRoadTotalLength = 0
        State.ActiveRoadLabel = "No ground road"
        State.EnemyVerifiedRoad = false
        return
    end

    local children = ground:GetChildren()
    local seedPart = children[19]
    local roadInfos, indexByPart = {}, {}
    for childIndex, child in ipairs(children) do
        if child:IsA("BasePart") and child.Size.Magnitude >= 1 then
            local info = AnalyzeRoadPartGeometry(child)
            if info and info.a and info.b and info.center then
                info.childIndex = childIndex
                -- Exactly one vertex per real road Part: its center, not both
                -- ends. This prevents rendering two parallel edge-lines per tile.
                info.center = Vector3.new(child.Position.X, info.surfaceY, child.Position.Z)
                table.insert(roadInfos, info)
                indexByPart[child] = #roadInfos
            end
        end
    end

    local seedIndex = seedPart and indexByPart[seedPart]
    if not seedIndex and seedPart then
        local seedPosition = ExtractObjectPos(seedPart)
        if seedPosition then
            local nearestDistance = math.huge
            for i, info in ipairs(roadInfos) do
                local distance = FlatDist2D(info.center, seedPosition)
                if distance < nearestDistance then
                    nearestDistance = distance
                    seedIndex = i
                end
            end
            if nearestDistance > 30 then seedIndex = nil end
        end
    end
    if not seedIndex or #roadInfos < 2 then
        State.CandidateRoadChains = {}
        State.MainRoadNodes = {}
        State.MainRoadSegments = {}
        State.MainRoadTotalLength = 0
        State.ActiveRoadLabel = "No ground road chain"
        State.EnemyVerifiedRoad = false
        return
    end

    local function portsFor(info)
        if info.isSquareNode or FlatDist2D(info.a, info.b) < 0.5 then
            return {{ pos = info.center, inward = nil }}
        end
        return {
            { pos = info.a, inward = (info.b - info.a).Unit },
            { pos = info.b, inward = (info.a - info.b).Unit }
        }
    end

    local ports, graph = {}, {}
    for i, info in ipairs(roadInfos) do
        ports[i] = portsFor(info)
        graph[i] = {}
    end

    -- Build adjacency using actual road endpoint proximity. Use a restrained
    -- relaxed gap for seams between map tiles, but reject links across parallel
    -- tracks where the road interiors point in the same direction.
    for i = 1, #roadInfos - 1 do
        local aInfo = roadInfos[i]
        for j = i + 1, #roadInfos do
            local bInfo = roadInfos[j]
            local threshold = math.clamp((math.min(aInfo.width, bInfo.width) * 0.45) + 1.25, 3.5, 7.5)
            local relaxedThreshold = threshold + 2.0
            local maxCenter = (math.max(aInfo.rawLength or 0, 2) * 0.5)
                + (math.max(bInfo.rawLength or 0, 2) * 0.5) + relaxedThreshold + 4
            local centerDelta = bInfo.center - aInfo.center
            local centerDistance = FlatDist2D(aInfo.center, bInfo.center)
            local dirA = (aInfo.b - aInfo.a)
            local dirB = (bInfo.b - bInfo.a)
            local parallelSideBySide = false
            if dirA.Magnitude > 0.5 and dirB.Magnitude > 0.5 and centerDistance > 0.01 then
                local parallel = math.abs(dirA.Unit:Dot(dirB.Unit)) > 0.88
                local alongA = math.abs(centerDelta.Unit:Dot(dirA.Unit))
                local alongB = math.abs(centerDelta.Unit:Dot(dirB.Unit))
                -- Parallel tiles beside each other are another road lane, not a join.
                -- True consecutive tiles have their center delta mostly along their axes.
                parallelSideBySide = parallel and math.min(alongA, alongB) < 0.42
            end

            if centerDistance <= maxCenter and not parallelSideBySide then
                local bestScore, bestGap, bestDot = math.huge, math.huge, 0
                for _, pa in ipairs(ports[i]) do
                    for _, pb in ipairs(ports[j]) do
                        local gap = FlatDist2D(pa.pos, pb.pos)
                        if gap <= relaxedThreshold then
                            local dot = 0
                            if pa.inward and pb.inward then
                                dot = pa.inward:Dot(pb.inward)
                            end
                            local sideBySide = pa.inward and pb.inward and dot > 0.55
                            if not sideBySide then
                                local gapPenalty = 0
                                if gap > threshold then
                                    gapPenalty = 24 + ((gap - threshold) * 7)
                                end
                                local score = gap + ((1 + dot) * 0.8) + gapPenalty
                                if score < bestScore then
                                    bestScore, bestGap, bestDot = score, gap, dot
                                end
                            end
                        end
                    end
                end

                -- Square/turn tiles may touch the middle of a neighbouring
                -- centerline instead of another endpoint.
                if bestScore == math.huge and (aInfo.isSquareNode or bInfo.isSquareNode) then
                    local gap = math.huge
                    if aInfo.isSquareNode then gap = math.min(gap, PointToSegmentDist2D(aInfo.center, bInfo.a, bInfo.b)) end
                    if bInfo.isSquareNode then gap = math.min(gap, PointToSegmentDist2D(bInfo.center, aInfo.a, aInfo.b)) end
                    if gap <= relaxedThreshold then
                        bestGap = gap
                        bestDot = 0
                        bestScore = gap + (gap > threshold and (24 + (gap - threshold) * 7) or 0)
                    end
                end

                if bestScore < math.huge then
                    local turnPenalty = (1 + bestDot) * 1.2
                    local edgeWeight = centerDistance + (bestGap * 1.5) + turnPenalty
                    if bestGap > threshold then edgeWeight = edgeWeight + 24 + ((bestGap - threshold) * 7) end
                    table.insert(graph[i], { to = j, weight = edgeWeight })
                    table.insert(graph[j], { to = i, weight = edgeWeight })
                end
            end
        end
    end

    local function shortestPath(source, target)
        if not source or not target then return nil, math.huge end
        local dist, prev, visited = {}, {}, {}
        for i = 1, #roadInfos do dist[i] = math.huge end
        dist[source] = 0
        while true do
            local u, best = nil, math.huge
            for i = 1, #roadInfos do
                if not visited[i] and dist[i] < best then u, best = i, dist[i] end
            end
            if not u then break end
            if u == target then break end
            visited[u] = true
            for _, edge in ipairs(graph[u]) do
                if not visited[edge.to] and dist[u] + edge.weight < dist[edge.to] then
                    dist[edge.to] = dist[u] + edge.weight
                    prev[edge.to] = u
                end
            end
        end
        if dist[target] == math.huge then return nil, math.huge end
        local rev, cur = {}, target
        while cur do
            table.insert(rev, cur)
            if cur == source then break end
            cur = prev[cur]
        end
        if rev[#rev] ~= source then return nil, math.huge end
        local path = {}
        for i = #rev, 1, -1 do table.insert(path, rev[i]) end
        return path, dist[target]
    end

    local function distancesFrom(source)
        local dist, visited = {}, {}
        for i = 1, #roadInfos do dist[i] = math.huge end
        dist[source] = 0
        while true do
            local u, best = nil, math.huge
            for i = 1, #roadInfos do
                if not visited[i] and dist[i] < best then u, best = i, dist[i] end
            end
            if not u then break end
            visited[u] = true
            for _, edge in ipairs(graph[u]) do
                if not visited[edge.to] and dist[u] + edge.weight < dist[edge.to] then
                    dist[edge.to] = dist[u] + edge.weight
                end
            end
        end
        return dist
    end

    local function nearestNode(pos, allowed)
        if not pos then return nil, math.huge end
        local bestIdx, bestDist = nil, math.huge
        for i, info in ipairs(roadInfos) do
            if not allowed or allowed[i] then
                local d = FlatDist2D(info.center, pos)
                if d < bestDist then bestIdx, bestDist = i, d end
            end
        end
        return bestIdx, bestDist
    end

    -- Find the connected road component containing the user's known road tile.
    -- The final route is selected from terminal road tiles (degree 1) rather than
    -- arbitrary nearby tiles. This avoids connecting side-by-side lanes into loops.
    local seedComponent, queue = { [seedIndex] = true }, { seedIndex }
    local qPos = 1
    while qPos <= #queue do
        local cur = queue[qPos]
        qPos = qPos + 1
        for _, edge in ipairs(graph[cur]) do
            if not seedComponent[edge.to] then
                seedComponent[edge.to] = true
                table.insert(queue, edge.to)
            end
        end
    end

    local endpoints = {}
    for i = 1, #roadInfos do
        if seedComponent[i] then
            local degree = 0
            for _, edge in ipairs(graph[i]) do
                if seedComponent[edge.to] then degree = degree + 1 end
            end
            if degree == 1 then table.insert(endpoints, i) end
        end
    end
    -- If the road is represented as a loop or many tiles meet at joints, allow
    -- every node as a last-resort candidate; shortestPath still returns one chain.
    if #endpoints < 2 then
        endpoints = {}
        for i = 1, #roadInfos do
            if seedComponent[i] then table.insert(endpoints, i) end
        end
    end

    -- Resolve base/spawn only after endpoints exist so ownership and endpoint
    -- proximity can distinguish this player's base from the opposite-side base.
    local spawnPos = FindMonsterSpawnAnchorPosition(roadInfos, endpoints)
    local basePos = FindBaseAnchorPosition(roadInfos, endpoints)
    if basePos then
        warn(string.format("[TD BaseAnchor] selected base anchor at X=%.1f Z=%.1f", basePos.X, basePos.Z))
    else
        warn("[TD BaseAnchor] no explicit base matched; using the opposite terminal of the connected _road.ground component")
    end

    local function closestEndpoint(pos)
        if not pos then return nil, math.huge end
        local best, bestDist = nil, math.huge
        for _, i in ipairs(endpoints) do
            local d = FlatDist2D(roadInfos[i].center, pos)
            if d < bestDist then best, bestDist = i, d end
        end
        return best, bestDist
    end

    local function farthestEndpointFrom(source, excluded)
        if not source then return nil, -1 end
        local dists = distancesFrom(source)
        local best, bestDist = nil, -1
        for _, i in ipairs(endpoints) do
            local d = dists[i]
            if i ~= excluded and d and d < math.huge and d > bestDist then
                best, bestDist = i, d
            end
        end
        return best, bestDist
    end

    local spawnIndex, spawnDist = closestEndpoint(spawnPos)
    local baseIndex, baseDist = closestEndpoint(basePos)
    -- Marker names occasionally point to non-route decorations. Only trust a
    -- marker when it is near an actual road endpoint; never draw a long diagonal.
    if spawnDist > 110 then spawnIndex = nil end
    if baseDist > 110 then baseIndex = nil end

    if spawnIndex and (not baseIndex or baseIndex == spawnIndex) then
        baseIndex = farthestEndpointFrom(spawnIndex, spawnIndex)
    elseif baseIndex and not spawnIndex then
        spawnIndex = farthestEndpointFrom(baseIndex, baseIndex)
    elseif not spawnIndex and not baseIndex then
        -- No reliable markers: use a two-sweep road-graph diameter. Its endpoints
        -- are the opposite ends of the connected road, not an arbitrary center tile.
        local farA = farthestEndpointFrom(seedIndex)
        if farA then
            local farB = farthestEndpointFrom(farA, farA)
            baseIndex, spawnIndex = farA, farB
        end
    end

    if not spawnIndex or not baseIndex or spawnIndex == baseIndex then
        State.CandidateRoadChains = {}
        State.MainRoadNodes = {}
        State.MainRoadSegments = {}
        State.MainRoadTotalLength = 0
        State.ActiveRoadLabel = "Could not identify two road endpoints"
        State.EnemyVerifiedRoad = false
        warn("[TD Road] Could not identify two distinct road endpoints; no false line drawn")
        return
    end

    -- Keep the road state oriented BASE -> SPAWN for systems that measure distance
    -- from the player base. This is still one shortest path through ground road tiles.
    local pathIndices, pathCost = shortestPath(baseIndex, spawnIndex)
    if not pathIndices or #pathIndices < 2 then
        State.CandidateRoadChains = {}
        State.MainRoadNodes = {}
        State.MainRoadSegments = {}
        State.MainRoadTotalLength = 0
        State.ActiveRoadLabel = "No connected path between road endpoints"
        State.EnemyVerifiedRoad = false
        warn("[TD Road] No connected base-to-spawn path in _road.ground")
        return
    end

    local pathNodes, pathParts, seen = {}, {}, {}
    for _, idx in ipairs(pathIndices) do
        local info = roadInfos[idx]
        if not seen[idx] then
            seen[idx] = true
            table.insert(pathNodes, info.center)
            table.insert(pathParts, info)
        end
    end

    -- Only attach marker positions when they are immediately beside the selected
    -- endpoint. Never extend a path by 50-100 studs across the map.
    if basePos and #pathNodes > 0 and FlatDist2D(basePos, pathNodes[1]) <= 32 then
        table.insert(pathNodes, 1, Vector3.new(basePos.X, pathNodes[1].Y, basePos.Z))
    end
    if spawnPos and #pathNodes > 0 and FlatDist2D(spawnPos, pathNodes[#pathNodes]) <= 32 then
        table.insert(pathNodes, Vector3.new(spawnPos.X, pathNodes[#pathNodes].Y, spawnPos.Z))
    end

    local candidate = CompileCandidateChain(pathNodes, pathParts, "_road.ground single BASE-to-SPAWN endpoint path", true)
    State.CandidateRoadChains = {}
    if candidate then
        table.insert(State.CandidateRoadChains, candidate)
        ApplyCandidateChainToState(candidate, false)
    else
        State.MainRoadNodes = {}
        State.MainRoadSegments = {}
        State.MainRoadTotalLength = 0
        State.ActiveRoadLabel = "No valid single road path"
        State.EnemyVerifiedRoad = false
        warn("[TD Road] The selected path failed validation; no fallback circle is drawn")
    end
end

-- Render exactly the currently selected route, from the same segment array used by the slider.
local function RenderVisualRoadPath()
    if State.RoadVisualFolder then
        pcall(function() State.RoadVisualFolder:Destroy() end)
        State.RoadVisualFolder = nil
    end
    local old = Workspace:FindFirstChild("_TD_RoadVisual")
    if old then pcall(function() old:Destroy() end) end

    local option = Fluent and Fluent.Options and Fluent.Options.ShowRoadPathLines
    if option and option.Value == false then return end
    if not State.MainRoadSegments or #State.MainRoadSegments == 0 then return end

    local folder = Instance.new("Folder")
    folder.Name = "_TD_RoadVisual"
    folder.Parent = Workspace
    State.RoadVisualFolder = folder

    for i, segment in ipairs(State.MainRoadSegments) do
        local a = segment.a + Vector3.new(0, 0.28, 0)
        local b = segment.b + Vector3.new(0, 0.28, 0)
        local delta = b - a
        local length = delta.Magnitude
        if length > 0.15 then
            local line = Instance.new("Part")
            line.Name = "LaneCenterline_" .. tostring(i)
            line.Anchored = true
            line.CanCollide = false
            line.CanTouch = false
            line.CanQuery = false
            line.CastShadow = false
            line.Material = Enum.Material.Neon
            line.Color = Color3.fromRGB(255, 35, 65)
            line.Transparency = 0.03
            line.Size = Vector3.new(0.42, 0.42, length)
            line.CFrame = CFrame.lookAt((a + b) * 0.5, b)
            line.Parent = folder
        end
    end
end

-- Build a separate fake route line first, then DESTROY physical _road parts locally.
-- The cached State.MainRoadSegments + _TD_RoadVisual are retained as visualization/data.
-- Unlike LocalTransparencyModifier, Destroy cannot be undone by placement-preview code
-- merely setting road transparency back to 0.
local function RestoreMonsterRoadLocalState()
    -- Destroyed client-side road parts cannot be restored reliably from saved properties.
    -- Setting this false only stops the watcher from deleting newly recreated road parts.
    State.RoadWasRemoved = false
end

local function DestroyRoadPart(inst)
    if not inst or not inst:IsA("BasePart") then return false end
    local fakeVisual = Workspace:FindFirstChild("_TD_RoadVisual")
    if fakeVisual and inst:IsDescendantOf(fakeVisual) then return false end
    local ok = pcall(function() inst:Destroy() end)
    return ok
end

local function AttachRoadDestroyWatcher(roadRoot)
    if not roadRoot then return end
    if State.RoadDestroyWatcherRoot == roadRoot then return end
    State.RoadDestroyWatcherRoot = roadRoot

    -- If the map recreated _road after placement mode started, remove current parts too.
    if State.RoadWasRemoved then
        for _, inst in ipairs(roadRoot:GetDescendants()) do
            if inst:IsA("BasePart") then DestroyRoadPart(inst) end
        end
    end

    AddConnection(roadRoot.DescendantAdded, function(inst)
        if not State.RoadWasRemoved or not inst:IsA("BasePart") then return end
        -- Remove immediately so a newly created road tile does not flash in placement mode.
        DestroyRoadPart(inst)
        task.defer(function()
            if State.RoadWasRemoved and inst.Parent then DestroyRoadPart(inst) end
        end)
    end)
end

-- Watch replacement road roots between rounds/maps.
AddConnection(Workspace.ChildAdded, function(child)
    if child.Name == "_road" or child.Name == "road" then
        task.defer(function()
            if child and child.Parent == Workspace then AttachRoadDestroyWatcher(child) end
        end)
    end
end)

local function ProcessAndRemoveMonsterRoad()
    if State.RoadWasRemoved then return true end
    if not State.MainRoadSegments or #State.MainRoadSegments == 0 then
        warn("[TD Road] Keep _road for now: route data has not been cached")
        return false
    end

    -- Always keep the route as a separately-created, non-collidable visual line.
    local option = Fluent and Fluent.Options and Fluent.Options.ShowRoadPathLines
    if option and option.Value == false then
        pcall(function() option:SetValue(true) end)
    end
    RenderVisualRoadPath()

    local roadVisual = Workspace:FindFirstChild("_TD_RoadVisual")
    local hasRenderedLine = false
    if roadVisual then
        for _, inst in ipairs(roadVisual:GetChildren()) do
            if inst:IsA("BasePart") and inst.Name:match("^LaneCenterline_") then
                hasRenderedLine = true
                break
            end
        end
    end
    if not hasRenderedLine then
        warn("[TD Road] Did not delete _road because the fake route line was not built")
        return false
    end

    local roadRoot = Workspace:FindFirstChild("_road") or Workspace:FindFirstChild("road")
    if not roadRoot then
        State.RoadWasRemoved = true
        return true
    end

    -- Flag first, then remove every actual road BasePart. Do not touch our fake red line.
    State.RoadWasRemoved = true
    AttachRoadDestroyWatcher(roadRoot)
    local removedCount = 0
    for _, inst in ipairs(roadRoot:GetDescendants()) do
        if inst:IsA("BasePart") then
            if DestroyRoadPart(inst) then removedCount += 1 end
        end
    end
    -- If the road root itself happens to be a BasePart, remove it as well.
    if roadRoot:IsA("BasePart") and DestroyRoadPart(roadRoot) then
        removedCount += 1
    end

    warn(string.format(
        "[TD Road] Destroyed %d physical road parts locally; retained fake route visualization (%d segments)",
        removedCount, #State.MainRoadSegments
    ))
    return true
end

local function GetPointAlongRoadByDist(distFromBase)
    local segs = State.MainRoadSegments
    local totalLen = State.MainRoadTotalLength
    if #segs == 0 or totalLen <= 0.05 then
        return State.MainRoadNodes[1] or Vector3.zero, Vector3.new(0, 0, 1), Vector3.new(1, 0, 0)
    end
    local clampedDist = math.clamp(distFromBase, 0, totalLen)
    for _, s in ipairs(segs) do
        if clampedDist >= s.startDist and clampedDist <= (s.startDist + s.len) then
            local alpha = (clampedDist - s.startDist) / math.max(s.len, 0.001)
            local pt = s.a:Lerp(s.b, alpha)
            return pt, s.dir, s.right
        end
    end
    local last = segs[#segs]
    return last.b, last.dir, last.right
end

local function GetFrontMonsterRoadDistance()
    local enemiesFolder = Workspace:FindFirstChild("_ENEMIES") or Workspace:FindFirstChild("Enemies")
    if not enemiesFolder or #State.MainRoadSegments == 0 then return nil end

    local maxRoadDistFromSpawn = -math.huge
    local foundAny = false

    for _, enemy in ipairs(enemiesFolder:GetChildren()) do
        local ePos = ExtractObjectPos(enemy)
        if ePos then
            local bestSegDist = math.huge
            local bestAlongRoad = nil
            for _, s in ipairs(State.MainRoadSegments) do
                local pFlat = Vector3.new(ePos.X, 0, ePos.Z)
                local aFlat = Vector3.new(s.a.X, 0, s.a.Z)
                local bFlat = Vector3.new(s.b.X, 0, s.b.Z)
                local ab = bFlat - aFlat
                local lenSq = ab.Magnitude * ab.Magnitude
                local t = lenSq > 0.001 and math.clamp((pFlat - aFlat):Dot(ab) / lenSq, 0, 1) or 0
                local proj = aFlat + (ab * t)
                local d = (pFlat - proj).Magnitude
                if d < bestSegDist then
                    bestSegDist = d
                    bestAlongRoad = s.startDist + (s.len * t)
                end
            end
            if bestAlongRoad and bestSegDist <= 25 and bestAlongRoad > maxRoadDistFromSpawn then
                maxRoadDistFromSpawn = bestAlongRoad
                foundAny = true
            end
        end
    end

    return foundAny and maxRoadDistFromSpawn or nil
end

do
    local buildOk, buildErr = pcall(function()
        BuildMainRoadPathFromWorkspace(false)
    end)
    if not buildOk then
        warn("[Kaitan RoadPath] Initial build failed: " .. tostring(buildErr))
    end
end

---------------------------------------------------------------------
-- 4. FLUENT WINDOW & TABS SETUP
---------------------------------------------------------------------
local Window = Fluent:CreateWindow({
    Title = "TD Script Architect (Kaitan & LANES Waypoint Route)",
    SubTitle = "User: " .. USER_CONFIG_NAME,
    TabWidth = 160,
    Size = UDim2.fromOffset(650, 530),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode[tostring((AA_CONFIG.UI and AA_CONFIG.UI.MinimizeKey) or "RightControl")] or Enum.KeyCode.RightControl
})

local Tabs = {
    AutoJoin = Window:AddTab({ Title = "Auto Join & Kaitan", Icon = "door-open" }),
    AI       = Window:AddTab({ Title = "Quick Place", Icon = "mouse-pointer-2" }),
    Macro    = Window:AddTab({ Title = "Macro", Icon = "play-circle" }),
    Game     = Window:AddTab({ Title = "Game", Icon = "gamepad-2" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

local Options = Fluent.Options

local saveDebounce = false
local function AutoSaveUserConfig()
    if State.IsBootingConfig or saveDebounce then return end
    saveDebounce = true
    task.delay(0.4, function()
        pcall(function()
            if SaveManager then
                local targetProfile = KaitanConfig.EnableKaitanMode and (USER_CONFIG_NAME .. "_Kaitan") or USER_CONFIG_NAME
                SaveManager:Save(targetProfile)
            end
            SaveKaitanConfig()
        end)
        saveDebounce = false
    end)
end

local function FindMyUnitNearPosition(targetPos, maxDist)
    local unitsFolder = Workspace:FindFirstChild("_UNITS")
    if not unitsFolder then return nil end
    local closest, minD = nil, maxDist or 0.45
    for _, u in ipairs(unitsFolder:GetChildren()) do
        local stats = u:FindFirstChild("_stats")
        if stats and stats:FindFirstChild("player") and stats.player.Value == LocalPlayer then
            local rp = u.PrimaryPart or u:FindFirstChild("HumanoidRootPart") or u:FindFirstChildWhichIsA("BasePart", true)
            if rp then
                local d = FlatDist2D(rp.Position, targetPos)
                if d < minD then
                    minD = d
                    closest = u
                end
            end
        end
    end
    return closest
end

---------------------------------------------------------------------
-- TAB 1: AUTO JOIN & KAITAN GEM FARM MODE
---------------------------------------------------------------------
-- Shared updater reference lets the separate game-finished loop update this tab safely.
local KaitanStatusUpdater = nil
do
    local KaitanStatusPara = Tabs.AutoJoin:AddParagraph({
        Title = "🐤 สถานะโหมดไก่ตัน (Kaitan Gem Farm Status)",
        Content = "กำลังตรวจสอบสถานะด่าน..."
    })

    local function UpdateKaitanSummaryText(extraMsg)
        RefreshAndCheckWorldCompletion()
        SafeUpdateParagraph(
            KaitanStatusPara,
            "🐤 สถานะโหมดไก่ตัน (Kaitan Gem Farm Status)",
            string.format(
                "โหมดไก่ตัน: %s | Planet Greenie: %s | Walled City: %s\n%s",
                KaitanConfig.EnableKaitanMode and "🟢 เปิด" or "⚪ ปิด",
                KaitanConfig.PassedNamek and "✅ ผ่านแล้ว" or "❌ ยังไม่ผ่าน",
                KaitanConfig.PassedWalledCity and "✅ ผ่านแล้ว" or "❌ ยังไม่ผ่าน",
                tostring(extraMsg or "พร้อมทำงานอัตโนมัติ")
            )
        )
    end
    KaitanStatusUpdater = UpdateKaitanSummaryText

    UpdateKaitanSummaryText()

    Tabs.AutoJoin:AddToggle("EnableKaitanMode", {
        Title = "Enable Kaitan Mode (เปิดโหมดไก่ตันฟาร์มเพชร)",
        Description = "ไต่ Act 6 ตามโลกเป้าหมาย แล้วฟาร์ม Infinite ของโลกที่เลือก; Auto Play ปิดและ Replay เปิดใน Infinite",
        Default = KaitanConfig.EnableKaitanMode,
        Callback = function(val)
            KaitanConfig.EnableKaitanMode = val
            SaveKaitanConfig()
            UpdateKaitanSummaryText(val and "เปิดโหมดไก่ตันแล้ว!" or "ปิดโหมดไก่ตัน (โหมดปกติ)")
            AutoSaveUserConfig()
        end
    })

    Tabs.AutoJoin:AddInput("KaitanBannerName", {
        Title = "Summon Banner Name (ชื่อตู้สุ่มโหมดไก่ตัน)",
        Default = KaitanConfig.SummonBanner or "EventClover",
        Placeholder = "EventClover",
        Finished = false,
        Callback = function(val)
            if val and val ~= "" then
                KaitanConfig.SummonBanner = val
                SaveKaitanConfig()
            end
        end
    })

    Tabs.AutoJoin:AddDropdown("KaitanFarmTarget", {
        Title = "Infinite Farm Target (ด่าน Infinite ที่จะฟาร์ม)",
        Values = {"namek_infinite", "aot_infinite"},
        Default = KaitanConfig.FarmTarget or "namek_infinite",
        Multi = false,
        Callback = function(val)
            if val == "namek_infinite" or val == "aot_infinite" then
                KaitanConfig.FarmTarget = val
                SaveKaitanConfig()
                UpdateKaitanSummaryText("ตั้งด่านฟาร์มเป็น " .. val .. " แล้ว")
            end
        end
    })

    Tabs.AutoJoin:AddInput("KaitanGemGoalInput", {
        Title = "Gem Farm Goal (เป้าหมายเพชร)",
        Description = "เมื่อเพชรถึงค่านี้ ระบบจะหยุดฟาร์ม Infinite และปิด Replay",
        Default = tostring(KaitanConfig.GemGoal or 20000),
        Placeholder = "2000",
        Finished = true,
        Callback = function(val)
            local n = tonumber(val)
            if n and n >= 50 then
                KaitanConfig.GemGoal = math.floor(n)
                SaveKaitanConfig()
                UpdateKaitanSummaryText("ตั้งเป้าหมายฟาร์มเพชรไว้ที่ " .. tostring(KaitanConfig.GemGoal) .. " แล้ว")
            else
                Fluent:Notify({Title = "Gem Goal", Content = "ใส่จำนวนเพชรตั้งแต่ 50 ขึ้นไป", Duration = 3})
            end
        end
    })

    Tabs.AutoJoin:AddButton({
        Title = "Claim Daily & All UUID Quests Now (รับรางวัลรายวัน + เควส UUID ทั้งหมด)",
        Description = "สแกนหา UUID เควสจาก Memory และ UI แล้วกดรับทันที",
        Callback = function()
            task.spawn(function()
                local count = ClaimAllDailyAndUUIDQuests()
                Fluent:Notify({
                    Title = "Claimed Quests",
                    Content = string.format("ส่งคำสั่งรับรายวันและเควส UUID ทั้งหมด %d รายการแล้ว!", count),
                    Duration = 4
                })
            end)
        end
    })

    Tabs.AutoJoin:AddButton({
        Title = "Auto Equip Up To 4 Strongest Units (ใส่เท่าที่มี สูงสุด 4 ตัว)",
        Callback = function()
            task.spawn(function()
                local equipLimit = math.max(1, math.min(4, math.floor(tonumber(KaitanConfig.MaxEquipUnits) or 4)))
                local count = AutoEquipStrongestUnits(equipLimit)
                Fluent:Notify({
                    Title = "Auto Equip",
                    Content = string.format("สวมใส่ยูนิตดาเมจสูงสุด %d ตัวแล้ว (เป้าหมายสูงสุด %d ตัว ไม่ซ้ำชนิด)", count, equipLimit),
                    Duration = 3
                })
            end)
        end
    })

    Tabs.AutoJoin:AddButton({
        Title = "Reset Kaitan World Memory (รีเซ็ตความจำผ่านด่าน Namek / Walled City)",
        Description = "กดปุ่มนี้เฉพาะกรณีต้องการบังคับให้สคริปต์กลับไปปลดล็อค Planet Greenie ใหม่ตั้งแต่ต้น",
        Callback = function()
            KaitanConfig.PassedNamek = false
            KaitanConfig.PassedWalledCity = false
            SaveKaitanConfig()
            UpdateKaitanSummaryText("รีเซ็ตสถานะผ่านด่านเรียบร้อยแล้ว")
        end
    })

    local LobbyStatusPara = Tabs.AutoJoin:AddParagraph({
        Title = "Lobby Auto Join Status (โหมดปกติ)",
        Content = "พร้อมใช้งาน"
    })

    Tabs.AutoJoin:AddDropdown("JoinWorld", {
        Title = "Story (World)",
        Values = DynamicWorldNames,
        Default = math.max(1, math.floor(tonumber((AA_CONFIG.AutoJoin and AA_CONFIG.AutoJoin.World) or 1) or 1)),
        Multi = false,
        Callback = function() AutoSaveUserConfig() end
    })

    Tabs.AutoJoin:AddDropdown("JoinAct", {
        Title = "Act",
        Values = {"1", "2", "3", "4", "5", "6", "Infinite"},
        Default = tostring((AA_CONFIG.AutoJoin and AA_CONFIG.AutoJoin.Act) or "1"),
        Multi = false,
        Callback = function() AutoSaveUserConfig() end
    })

    Tabs.AutoJoin:AddDropdown("JoinDifficulty", {
        Title = "Difficulty",
        Values = {"Normal", "Hard", "Nightmare"},
        Default = tostring((AA_CONFIG.AutoJoin and AA_CONFIG.AutoJoin.Difficulty) or "Normal"),
        Multi = false,
        Callback = function() AutoSaveUserConfig() end
    })

    Tabs.AutoJoin:AddToggle("FriendsOnly", { Title = "Friends Only", Default = not (AA_CONFIG.AutoJoin and AA_CONFIG.AutoJoin.FriendsOnly == false), Callback = function() AutoSaveUserConfig() end })
    Tabs.AutoJoin:AddToggle("WorldSkip", { Title = "World Skip (โหมดปกติ)", Default = AA_CONFIG.AutoJoin and AA_CONFIG.AutoJoin.WorldSkip == true, Callback = function() AutoSaveUserConfig() end })
    Tabs.AutoJoin:AddToggle("AutoStart", { Title = "Auto Start (Solo Vote)", Default = not (AA_CONFIG.AutoJoin and AA_CONFIG.AutoJoin.AutoStart == false), Callback = function() AutoSaveUserConfig() end })
    Tabs.AutoJoin:AddToggle("AutoJoinStory", { Title = "Auto Join Story (โหมดปกติ)", Default = AA_CONFIG.AutoJoin and AA_CONFIG.AutoJoin.Story == true, Callback = function() AutoSaveUserConfig() end })

    local function ClickWorldSkipButtonsStrictly()
        local pgui = LocalPlayer:FindFirstChild("PlayerGui")
        if not pgui then return false end
        for _, obj in ipairs(pgui:GetDescendants()) do
            if obj:IsA("TextLabel") and obj.Visible then
                local txt = tostring(obj.Text or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
                if txt == "confirm" or txt == "select" or txt == "ยืนยัน" then
                    local btn = obj:FindFirstAncestorWhichIsA("GuiButton")
                        or (obj.Parent and obj.Parent:FindFirstChildWhichIsA("GuiButton"))
                    if btn and FireGuiButton(btn) then
                        return true
                    end
                end
            end
        end
        return false
    end

    local function ClickWorldSkipConfirmGuiIfVisible()
        return ClickWorldSkipButtonsStrictly()
    end

    local function ClickWorldButtonInGui(worldNameKeyword)
        local pgui = LocalPlayer:FindFirstChild("PlayerGui")
        if not pgui or not worldNameKeyword then return false end
        local key = tostring(worldNameKeyword):lower()
        for _, obj in ipairs(pgui:GetDescendants()) do
            if obj:IsA("TextLabel") and obj.Visible then
                local txt = tostring(obj.Text or ""):lower()
                if txt:find(key, 1, true) then
                    local btn = obj:FindFirstAncestorWhichIsA("GuiButton")
                        or (obj.Parent and obj.Parent:FindFirstChildWhichIsA("GuiButton"))
                    if btn and FireGuiButton(btn) then return true end
                end
            end
        end
        return false
    end

    local function ClickTargetWorldTile(targetWorldId, explicitKeyword)
        local id = tostring(targetWorldId or ""):lower()
        local keywords = {}
        if explicitKeyword and explicitKeyword ~= "" then table.insert(keywords, explicitKeyword) end
        if id:find("namek") or id:find("greenie") then
            table.insert(keywords, "Greenie")
        elseif id:find("shiganshina") or id:find("walled") or id:find("aot") then
            table.insert(keywords, "Walled City")
            table.insert(keywords, "Titan")
            table.insert(keywords, "Shiganshina")
        end
        for _, keyword in ipairs(keywords) do
            if ClickWorldButtonInGui(keyword) then return true, keyword end
        end
        return false, nil
    end

    local function IsPlayerInStoryPod(lobby)
        if not lobby then return false end
        local ownerObj = lobby:FindFirstChild("Owner")
        if ownerObj and (ownerObj.Value == LocalPlayer or tostring(ownerObj.Value) == LocalPlayer.Name) then
            return true
        end
        local playersFolder = lobby:FindFirstChild("Players")
        if playersFolder and playersFolder:FindFirstChild(LocalPlayer.Name) then
            return true
        end
        return false
    end

    local function JoinOrGetCurrentStoryPod()
        local lobbies = Workspace:FindFirstChild("_LOBBIES")
        local story = lobbies and lobbies:FindFirstChild("Story")
        if not story then return nil end

        for _, lobby in ipairs(story:GetChildren()) do
            if IsPlayerInStoryPod(lobby) then
                return lobby
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

        if not free_lobby then return nil end

        local ok = InvokeServer("request_join_lobby", free_lobby.Name)
        if not ok and not IsPlayerInStoryPod(free_lobby) then
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local primary = free_lobby:FindFirstChild("primary") or free_lobby:FindFirstChild("Door")
            if hrp and primary then
                hrp.CFrame = primary.CFrame + Vector3.new(0, 3, 0)
            end
            task.wait(0.35)
            InvokeServer("request_join_lobby", free_lobby.Name)
        end

        task.wait(0.4)
        return free_lobby
    end

    -- Avoid treating the same still-visible toast as completion of multiple worlds.
    local LastAlreadyCompletedWorldNotice = nil

    local function TryWorldSkipOnPod(pod, targetWorldId, statusCallback, explicitWorldKeyword)
        if not pod or not targetWorldId then return false end
        local function status(msg)
            if statusCallback then pcall(function() statusCallback(msg) end) end
        end

        -- The game's completion popup is authoritative when the local completion table
        -- has not replicated (or uses a schema this script cannot recognize).
        local function MarkWorldPassedIfAlreadyCompletedNotice()
            local pgui = LocalPlayer:FindFirstChild("PlayerGui")
            if not pgui then return false end
            local notice = nil
            for _, obj in ipairs(pgui:GetDescendants()) do
                if (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) and obj.Visible then
                    local txt = tostring(obj.Text or ""):lower():gsub("[%p%c]", " ")
                    txt = txt:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
                    if txt:find("you have already completed this world", 1, true)
                        or txt:find("already completed this world", 1, true)
                        or txt:find("you already completed this world", 1, true) then
                        notice = txt
                        break
                    end
                end
            end
            if not notice then
                LastAlreadyCompletedWorldNotice = nil
                return false
            end
            if LastAlreadyCompletedWorldNotice == notice then
                return false
            end
            LastAlreadyCompletedWorldNotice = notice

            local id = tostring(targetWorldId):lower()
            local changed = false
            if id:find("namek", 1, true) or id:find("greenie", 1, true) then
                if not KaitanConfig.PassedNamek then
                    KaitanConfig.PassedNamek = true
                    changed = true
                end
                status("✅ เกมแจ้งว่า Planet Greenie ผ่านแล้ว — บันทึกสถานะและจะข้ามไป Walled City ในรอบถัดไป")
            elseif id:find("shiganshina", 1, true) or id:find("walled", 1, true) or id:find("aot", 1, true) then
                if not KaitanConfig.PassedWalledCity then
                    KaitanConfig.PassedWalledCity = true
                    changed = true
                end
                status("✅ เกมแจ้งว่า Walled City ผ่านแล้ว — บันทึกสถานะโลกนี้แล้ว")
            else
                return false
            end
            if changed then SaveKaitanConfig() end
            return true
        end

        if not EnsureEquippedTeamBeforePlay("World Skip", status) then
            return false
        end

        status(string.format("🌍 เลือกโลก %s ใน GUI ก่อน World Skip...", tostring(explicitWorldKeyword or targetWorldId)))
        local selected = false
        for _ = 1, 5 do
            local ok, keyword = ClickTargetWorldTile(targetWorldId, explicitWorldKeyword)
            if ok then
                selected = true
                status("✅ เลือกโลกจาก GUI แล้ว: " .. tostring(keyword))
                break
            end
            task.wait(0.4)
        end
        if not selected then
            status("ℹ️ ไม่พบปุ่มชื่อโลกบน GUI; จะลองเรียก World Skip ด้วย world ID โดยตรง")
        end

        status(string.format("🚀 เรียก lobby_world_skip(%q)...", tostring(targetWorldId)))
        local callOk, callErr = pcall(function()
            InvokeServer("lobby_world_skip", targetWorldId)
        end)
        if not callOk then status("❌ lobby_world_skip error: " .. tostring(callErr)) end

        task.wait(0.25)
        if MarkWorldPassedIfAlreadyCompletedNotice() then
            return false
        end
        task.wait(0.55)
        for _ = 1, 5 do
            if MarkWorldPassedIfAlreadyCompletedNotice() then return false end
            if ClickWorldSkipButtonsStrictly() then task.wait(0.25) end
            if Workspace:FindFirstChild("_LOBBIES") == nil then
                status("✅ ออกจากล็อบบี้แล้ว กำลังเข้า " .. tostring(targetWorldId))
                return true
            end
            task.wait(0.3)
        end

        local startWait = os.clock()
        while os.clock() - startWait < 12 do
            if MarkWorldPassedIfAlreadyCompletedNotice() then return false end
            if Workspace:FindFirstChild("_LOBBIES") == nil then
                status("✅ World Skip สำเร็จ: " .. tostring(targetWorldId))
                return true
            end
            ClickWorldSkipButtonsStrictly()
            task.wait(0.35)
        end

        status("⚠️ ยังอยู่ในล็อบบี้หลัง World Skip; จะตรวจสถานะแล้วลองใหม่ ไม่บันทึกว่าผ่าน Act 6 เอง")
        return false
    end

    local function KaitanSetOption(name, value)
        local opt = Options and Options[name]
        if opt and type(opt.SetValue) == "function" then
            pcall(function() opt:SetValue(value) end)
        end
    end

    -- Before both Act 6 records are complete, keep Auto Play and Auto Back to Lobby on.
    -- The Kaitan GameFinished handler owns the transition and returns to the lobby;
    -- the lobby loop then re-enables these two options for the next missing Act 6.
    local function KaitanPrepareAct6Mode()
        -- Act 6 progression still needs automatic placement.
        getgenv().TD_QuickManualPlacementBoot = false
        KaitanSetOption("ManualOverlapMode", false)
        KaitanSetOption("AutoPlayEnabled", true)
        KaitanSetOption("AutoSkip", true)
        KaitanSetOption("AutoReplay", false)
        KaitanSetOption("AutoNext", false)
        KaitanSetOption("AutoBackToLobby", true)
        KaitanSetOption("AutoJoinStory", false)
        KaitanSetOption("AutoStart", false)
    end

    -- After both Act 6 records are complete, prevent any automatic placements in
    -- Titan / Walled City Infinite. Manual click mode is enabled as the requested guard.
    local function KaitanPrepareTitanFarmMode()
        local autoPlaceInfinite = AA_CONFIG.AutoPlay and AA_CONFIG.AutoPlay.AutoPlaceInInfinite ~= false
        -- Honor the top-level config instead of forcing manual placement for every Infinite run.
        getgenv().TD_QuickManualPlacementBoot = not autoPlaceInfinite
        KaitanSetOption("ManualOverlapMode", not autoPlaceInfinite)
        KaitanSetOption("AutoPlayEnabled", autoPlaceInfinite and AA_CONFIG.AutoPlay.Enabled ~= false)
        KaitanSetOption("AutoSkip", not (AA_CONFIG.Farm and AA_CONFIG.Farm.AutoSkip == false))
        KaitanSetOption("AutoReplay", not (AA_CONFIG.Farm and AA_CONFIG.Farm.AutoReplay == false))
        KaitanSetOption("AutoNext", false)
        KaitanSetOption("AutoBackToLobby", false)
        KaitanSetOption("AutoJoinStory", false)
        KaitanSetOption("AutoStart", false)
    end

    local function KaitanSummonToFloor()
        -- Refresh the live completion GUI before any spending decision.
        RefreshAndCheckWorldCompletion()
        if KaitanConfig.PassedNamek == true then
            UpdateKaitanSummaryText("✅ Planet Greenie 6/6 แล้ว | ยกเลิกการสุ่ม ไม่ใช้เพชรเพิ่ม")
            return true
        end
        local banner = tostring(KaitanConfig.SummonBanner or "EventClover")
        local minGems = math.max(50, tonumber(KaitanConfig.MinGemsToSummon) or 50)
        local gems = GetPlayerGems()
        if gems < minGems then return true end

        -- The known endpoint signature in this script is (banner, currency), so a
        -- 10-pull batch is ten verified single requests, not an invented third argument.
        while KaitanConfig.EnableKaitanMode and gems >= 500 do
            local batchStart = gems
            local anyProgress = false
            UpdateKaitanSummaryText(string.format("💎 เพชร %d: เริ่มชุดสุ่ม 10 ครั้ง (%s)", gems, banner))
            for pull = 1, 10 do
                if not KaitanConfig.EnableKaitanMode then return false end
                -- Re-check before EACH individual pull; do not spend if Namek is already 6/6.
                RefreshAndCheckWorldCompletion()
                if KaitanConfig.PassedNamek == true then
                    UpdateKaitanSummaryText("✅ Planet Greenie 6/6 แล้ว | หยุดสุ่มทันที")
                    return true
                end
                local before = GetPlayerGems()
                if before < minGems then break end
                local ok = pcall(function()
                    InvokeServer("buy_from_banner", banner, tostring(KaitanConfig.SummonCurrency or "gems"))
                end)
                task.wait(0.75)
                local after = GetPlayerGems()
                if ok and after < before then
                    anyProgress = true
                    gems = after
                    UpdateKaitanSummaryText(string.format("💎 ชุดสุ่ม %d/10 | เหลือ %d เพชร", pull, gems))
                else
                    task.wait(0.6)
                    after = GetPlayerGems()
                    if after < before then
                        anyProgress = true
                        gems = after
                    else
                        UpdateKaitanSummaryText("⚠️ ยอดเพชรไม่ลดหลังส่งคำขอสุ่ม หยุดเพื่อไม่ให้ยิง Remote ซ้ำ")
                        return false
                    end
                end
                if gems < minGems then break end
            end
            gems = GetPlayerGems()
            if not anyProgress or gems >= batchStart then
                UpdateKaitanSummaryText("⚠️ ชุดสุ่มไม่ทำให้ยอดเพชรลดลง จึงหยุดไว้ก่อน")
                return false
            end
        end

        -- Below 500, use single requests until the balance is under 50.
        while KaitanConfig.EnableKaitanMode and gems >= minGems and gems < 500 do
            RefreshAndCheckWorldCompletion()
            if KaitanConfig.PassedNamek == true then
                UpdateKaitanSummaryText("✅ Planet Greenie 6/6 แล้ว | หยุดสุ่มทันที")
                return true
            end
            local before = GetPlayerGems()
            local ok = pcall(function()
                InvokeServer("buy_from_banner", banner, tostring(KaitanConfig.SummonCurrency or "gems"))
            end)
            task.wait(0.75)
            gems = GetPlayerGems()
            if not ok or gems >= before then
                task.wait(0.6)
                gems = GetPlayerGems()
                if gems >= before then
                    UpdateKaitanSummaryText("⚠️ ยอดเพชรไม่ลดหลังสุ่มเดี่ยว หยุดเพื่อป้องกันการเรียกซ้ำ")
                    return false
                end
            end
            UpdateKaitanSummaryText(string.format("💎 สุ่มเดี่ยวแล้ว เหลือ %d เพชร", gems))
        end
        return gems < minGems
    end

    task.spawn(function()
        local nextLaunchAt = 0
        local nextEquipAttemptAt = 0
        while true do
            task.wait(2.0)
            local inLobby = Workspace:FindFirstChild("_LOBBIES") ~= nil

            if not inLobby then
                State.KaitanEquippedThisLobby = false
                State.KaitanDidLobbyPrep = false
            elseif KaitanConfig.EnableKaitanMode then
                local world1Id = GetExactWorldId("Planet Greenie", "planet_namek")
                local world2Id = GetExactWorldId("Walled City", "shiganshina")
                local namekDone, walledDone = RefreshAndCheckWorldCompletion()
                local gemGoal = math.max(50, tonumber(KaitanConfig.GemGoal) or 20000)
                local gemCount = GetPlayerGems()

                if not State.KaitanDidLobbyPrep then
                    State.KaitanDidLobbyPrep = true
                    UpdateKaitanSummaryText("🎁 กำลังกวาดรับรางวัลรายวันและเควส UUID ทั้งหมด...")
                    ClaimAllDailyAndUUIDQuests()
                    task.wait(0.8)
                end

                local farmNamek = tostring(KaitanConfig.FarmTarget or "namek_infinite"):lower() == "namek_infinite"
                local targetDone = farmNamek and namekDone or (namekDone and walledDone)
                local targetWorldId = farmNamek and world1Id or world2Id
                local targetLabel = farmNamek and "Planet Greenie / Namek Infinite" or "Walled City / AOT Infinite"

                if targetDone and gemCount >= gemGoal then
                    -- Target world is complete and gem goal reached: stop farming.
                    getgenv().TD_QuickManualPlacementBoot = true
                    KaitanSetOption("ManualOverlapMode", true)
                    KaitanSetOption("AutoPlayEnabled", false)
                    KaitanConfig.EnableKaitanMode = false
                    SaveKaitanConfig()
                    KaitanSetOption("AutoSkip", false)
                    KaitanSetOption("AutoReplay", false)
                    KaitanSetOption("AutoBackToLobby", false)
                    UpdateKaitanSummaryText(string.format("🎯 ถึงเป้าหมายเพชรแล้ว (%d/%d) ปิดโหมดฟาร์มเรียบร้อย", gemCount, gemGoal))
                elseif targetDone then
                    -- Join the selected Infinite world; Namek target does not require AOT Act 6.
                    KaitanPrepareTitanFarmMode()
                    if os.clock() >= nextLaunchAt then
                        local pod = JoinOrGetCurrentStoryPod()
                        if pod then
                            if EnsureEquippedTeamBeforePlay(targetLabel, UpdateKaitanSummaryText) then
                                UpdateKaitanSummaryText(string.format("✅ ปลดล็อกโลกเป้าหมายแล้ว | กำลังเข้า %s | เพชร %d/%d", targetLabel, gemCount, gemGoal))
                                local infLvl, infDiff = ResolveTargetLevelId(targetWorldId, "Infinite", "Hard")
                                local lockOk = pcall(function()
                                    InvokeServer("request_lock_level", pod.Name, infLvl, true, infDiff)
                                end)
                                task.wait(0.4)
                                local startOk = pcall(function()
                                    InvokeServer("request_start_game", pod.Name)
                                end)
                                nextLaunchAt = os.clock() + 12
                                if not lockOk or not startOk then
                                    UpdateKaitanSummaryText("⚠️ เริ่ม Infinite ไม่สำเร็จ จะลองใหม่หลังพักสั้น ๆ")
                                end
                            else
                                nextLaunchAt = os.clock() + 5
                            end
                        end
                    end
                else
                    KaitanPrepareAct6Mode()
                    -- Finish all affordable gem summons first. Do not equip or launch a map
                    -- while summon requests are still pending or the gem balance is >= 50.
                    local minSummonGems = math.max(50, tonumber(KaitanConfig.MinGemsToSummon) or 50)
                    local summonReady = GetPlayerGems() < minSummonGems
                    -- Re-check the completion GUI and saved flag immediately before any summon request.
                    namekDone = namekDone or KaitanConfig.PassedNamek == true

                    -- Planet Greenie is already 6/6: never summon again for this progression.
                    if namekDone then
                        summonReady = true
                        UpdateKaitanSummaryText(
                            "✅ Planet Greenie ผ่าน 6/6 แล้ว | ข้ามการสุ่มและไปขั้นตอนถัดไป"
                        )
                    elseif not summonReady then
                        -- Final gate immediately before the summon function.
                        RefreshAndCheckWorldCompletion()
                        if KaitanConfig.PassedNamek == true then
                            namekDone = true
                            summonReady = true
                            UpdateKaitanSummaryText("✅ Planet Greenie ผ่าน 6/6 แล้ว | ข้ามการสุ่มและไปขั้นตอนถัดไป")
                        else
                            UpdateKaitanSummaryText("🎲 กำลังสุ่มใช้เพชรให้เสร็จก่อน แล้วจึงค่อยใส่ยูนิต...")
                            summonReady = KaitanSummonToFloor()
                        end
                        if summonReady and GetPlayerGems() < minSummonGems then
                            -- Let newly summoned units replicate into the inventory session before reading it.
                            task.wait(2.5)
                            summonReady = GetPlayerGems() < minSummonGems
                            UpdateKaitanSummaryText(summonReady
                                and "✅ สุ่มเสร็จแล้ว | กำลังโหลดรายการยูนิตก่อนใส่ทีม..."
                                or "⏳ รอยืนยันยอดเพชรหลังสุ่มก่อนใส่ยูนิต")
                        end
                        if not summonReady then task.wait(1.0) end
                    end

                    if summonReady and not State.KaitanEquippedThisLobby and os.clock() >= nextEquipAttemptAt then
                        -- Read owned inventory only after summoning is complete, then equip the best
                        -- available distinct unit types (up to four) in one pass.
                        task.wait(0.8)
                        State.KaitanEquippedThisLobby = true
                        UpdateKaitanSummaryText("⚔️ สุ่มเสร็จแล้ว | กำลังใส่ยูนิตที่มีให้ครบเท่าที่มี (สูงสุด 4 ตัว ไม่ซ้ำชนิด)...")
                        local equipCount = AutoEquipStrongestUnits(math.max(1, tonumber(KaitanConfig.MaxEquipUnits) or 4))
                        task.wait(1.2)
                        if equipCount <= 0 or not EnsureEquippedTeamBeforePlay("Act 6", UpdateKaitanSummaryText) then
                            State.KaitanEquippedThisLobby = false
                            nextEquipAttemptAt = os.clock() + 8
                        end
                    end

                    if summonReady and os.clock() >= nextLaunchAt then
                        local pod = JoinOrGetCurrentStoryPod()
                        if pod then
                            local started
                            if not namekDone then
                                started = TryWorldSkipOnPod(pod, world1Id, UpdateKaitanSummaryText, "Greenie")
                            else
                                started = TryWorldSkipOnPod(pod, world2Id, UpdateKaitanSummaryText, "Walled City")
                            end
                            nextLaunchAt = os.clock() + (started and 8 or 6)
                        end
                    end
                end
            elseif inLobby and (Options.AutoJoinStory and Options.AutoJoinStory.Value) then
                local pod = JoinOrGetCurrentStoryPod()
                if pod then
                    local function NormalJoinStatus(msg)
                        SafeUpdateParagraph(LobbyStatusPara, nil, msg)
                    end
                    if EnsureEquippedTeamBeforePlay("Auto Join Story", NormalJoinStatus) then
                        local worldName = Options.JoinWorld and Options.JoinWorld.Value or DynamicWorldNames[1]
                        local actStr = Options.JoinAct and Options.JoinAct.Value or "1"
                        local diffStr = Options.JoinDifficulty and Options.JoinDifficulty.Value or "Normal"
                        local friendsOnly = (Options.FriendsOnly and Options.FriendsOnly.Value) or false
                        local targetLevel, diff, exactWorldId = ResolveTargetLevelId(worldName, actStr, diffStr)

                        if Options.WorldSkip and Options.WorldSkip.Value then
                            TryWorldSkipOnPod(pod, exactWorldId, NormalJoinStatus, tostring(worldName))
                        else
                            InvokeServer("request_lock_level", pod.Name, targetLevel, friendsOnly, diff)
                            if Options.AutoStart and Options.AutoStart.Value then
                                task.wait(0.35)
                                -- Re-check immediately before the start request in case the team changed.
                                if EnsureEquippedTeamBeforePlay("Auto Start", NormalJoinStatus) then
                                    InvokeServer("request_start_game", pod.Name)
                                end
                            end
                            task.wait(3.0)
                        end
                    end
                end
            end
        end
    end)
end

---------------------------------------------------------------------
-- TAB 2: AI - AUTO PLAY (REAL-TIME ROAD INTERCEPT & HOLOGRAM ZONE)
---------------------------------------------------------------------
do
    local AIStatusPara = Tabs.AI:AddParagraph({
        Title = "🎯 Real-Time Road Intercept (กำหนดจุดวางบนทางเดินมอน)",
        Content = "พร้อมทำงาน: ปรับตำแหน่งบนสไลเดอร์แล้วโฮโลแกรมจะเลื่อนตามเส้นทางเดินแบบ Real-Time"
    })

    local MiniDotPool = {
        Folder = nil,
        GroundDots = {},
        HillDots = {},
        GroundRings = {},
        HillRings = {},
        GroundZoneAnchor = nil,
        HillZoneAnchor = nil,
        GroundZoneBoundary = nil,
        HillZoneBoundary = nil,
        CenterPin = nil,
        ZoneRing = nil,
        ZoneBeacon = nil
    }

    local function CreateHologramPart(parent, name, shape, color, sizeVec, transparency, material)
        local p = Instance.new("Part")
        p.Name = name
        p.Shape = shape or Enum.PartType.Ball
        p.Material = material or Enum.Material.Neon
        p.Color = color
        p.Size = sizeVec
        p.Transparency = transparency or 0
        p.Anchored = true
        p.CanCollide = false
        p.CanTouch = false
        pcall(function()
            p.CanQuery = false
        end)
        p.CastShadow = false
        p.Parent = parent
        return p
    end

    -- MiniDots are UI markers, not physical blockers. BillboardGui.AlwaysOnTop makes
    -- every marker visible through units, road pieces, props, and other occluders.
    -- The invisible anchor Part still follows the actual sampled surface in 3D.
    local function EnsureMiniDotAlwaysOnTop(anchor, color, pixelSize)
        if not anchor or not anchor.Parent then return end
        anchor.Transparency = 1
        anchor.CastShadow = false
        anchor.CanCollide = false
        anchor.CanTouch = false
        pcall(function() anchor.CanQuery = false end)
        local gui = anchor:FindFirstChild("__MiniDotAlwaysOnTop")
        if not gui then
            gui = Instance.new("BillboardGui")
            gui.Name = "__MiniDotAlwaysOnTop"
            gui.Adornee = anchor
            gui.AlwaysOnTop = true
            gui.LightInfluence = 0
            gui.MaxDistance = 10000
            gui.Size = UDim2.fromOffset(pixelSize or 4, pixelSize or 4)
            gui.StudsOffsetWorldSpace = Vector3.zero
            gui.Parent = anchor
            local dotFrame = Instance.new("Frame")
            dotFrame.Name = "Dot"
            dotFrame.BackgroundTransparency = 0
            dotFrame.BorderSizePixel = 0
            dotFrame.Size = UDim2.fromScale(1, 1)
            dotFrame.AnchorPoint = Vector2.new(0.5, 0.5)
            dotFrame.Position = UDim2.fromScale(0.5, 0.5)
            dotFrame.Parent = gui
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(1, 0)
            corner.Parent = dotFrame
        end
        local frame = gui:FindFirstChild("Dot")
        if frame then frame.BackgroundColor3 = color end
        gui.Size = UDim2.fromOffset(pixelSize or 4, pixelSize or 4)
        gui.Enabled = true
    end

    -- V27 GROUNDED placement scanner (dense full-circle grids; route-render-before-road-removal).
    -- The road path is only a search anchor; it does not make a point valid by itself.
    -- Ground slots must hit a real walkable surface away from road/hill footprints.
    -- Hill slots must hit a real upward-facing surface belonging to _terrain.hill.
    local placementScanRayParams = RaycastParams.new()
    placementScanRayParams.FilterType = Enum.RaycastFilterType.Exclude
    placementScanRayParams.IgnoreWater = true
    local groundVisualIncludeParams = RaycastParams.new()
    groundVisualIncludeParams.FilterType = Enum.RaycastFilterType.Include
    groundVisualIncludeParams.IgnoreWater = true
    local rejectedPlacementSlots = { Ground = {}, Hill = {} }
    local lastSurfaceScanAt = 0
    local surfaceSlotsDirty = true

    local function RefreshPlacementScanFilter()
        local ignore = {}
        local function addNamed(name)
            local inst = Workspace:FindFirstChild(name)
            if inst then table.insert(ignore, inst) end
        end
        if LocalPlayer and LocalPlayer.Character then table.insert(ignore, LocalPlayer.Character) end
        for _, name in ipairs({"_road", "road", "_BASES", "Bases", "_UNITS", "_ENEMIES", "Enemies", "_FX", "_ignore", "_PROJECTILES", "_TD_Holograms", "_TD_RoadVisual", "_TD_MacroMarkers"}) do
            addNamed(name)
        end
        local terrainRoot = Workspace:FindFirstChild("_terrain") or Workspace:FindFirstChild("terrain")
        local hillFolder = terrainRoot and (terrainRoot:FindFirstChild("hill") or terrainRoot:FindFirstChild("Hill"))
        if hillFolder then table.insert(ignore, hillFolder) end
        if State.HologramFolder then table.insert(ignore, State.HologramFolder) end
        if State.RoadVisualFolder then table.insert(ignore, State.RoadVisualFolder) end
        placementScanRayParams.FilterDescendantsInstances = ignore
    end

    local function IsInsideAnyHillFootprint(worldX, worldZ, margin)
        for _, g in ipairs(State.HillGeometries) do
            if g.part and g.part.Parent then
                local localPt = g.cf:PointToObjectSpace(Vector3.new(worldX, g.part.Position.Y, worldZ))
                local m = margin or 0
                if math.abs(localPt.X) <= g.size.X * 0.5 + m
                    and math.abs(localPt.Z) <= g.size.Z * 0.5 + m then
                    return true
                end
            end
        end
        return false
    end

    local function IsRejectedSlot(kind, pos)
        for _, badPos in ipairs(rejectedPlacementSlots[kind]) do
            if FlatDist2D(badPos, pos) < 1.6 then return true end
        end
        return false
    end

    local function RememberRejectedSlot(kind, pos)
        if not IsRejectedSlot(kind, pos) then
            table.insert(rejectedPlacementSlots[kind], pos)
            if #rejectedPlacementSlots[kind] > 180 then table.remove(rejectedPlacementSlots[kind], 1) end
        end
    end

    local function CastValidGroundSurface(x, z, refY, maxHeightDelta)
        local referenceY = tonumber(refY)
        if not referenceY then return nil end
        local heightTolerance = tonumber(maxHeightDelta) or 8.0

        -- Start close enough to the expected floor so large decorations/rocks above
        -- the play surface cannot become placement candidates.
        local hit = Workspace:Raycast(
            Vector3.new(x, referenceY + 180, z),
            Vector3.new(0, -360, 0),
            placementScanRayParams
        )
        if not hit or not hit.Position or not hit.Instance then return nil end
        if not hit.Normal or hit.Normal.Y < 0.75 then return nil end
        -- Raycasts must resolve to a collidable floor/platform, not non-collidable
        -- decoration or marker parts. _BASES is excluded in RefreshPlacementScanFilter.
        if hit.Instance:IsA("BasePart") and not hit.Instance.CanCollide then return nil end
        if math.abs(hit.Position.Y - referenceY) > heightTolerance then return nil end

        -- The source script's original ground validator excludes decorative map props
        -- that live under _map but outside _terrain. They were the reason dots could
        -- appear on raised objects rather than on the walkable floor.
        -- Do not reject surfaces solely because they live under _map. Some maps
        -- store their actual walkable floor there instead of under _terrain.ground.
        -- The upward normal, collidable surface, and height tolerance above are the
        -- ground checks; _terrain.hill is excluded separately by footprint.

        -- _road is excluded by RefreshPlacementScanFilter, so this raycast is
        -- already sampling the ground beneath the route. Do not reject the same X/Z
        -- just because it lies inside the road footprint: the user intentionally
        -- removes road children after the route has been drawn.
        if IsInsideAnyHillFootprint(x, z, 0.2) then return nil end
        return hit.Position
    end

    local function AddUniqueSlot(list, pos, minimumGap)
        -- Candidates are generated from unique X/Z grid coordinates. Raycast returns
        -- that same X/Z, so a quadratic neighbour scan only throttles dense MiniDots.
        table.insert(list, pos)
    end

    local function ThinSlotsAcrossRadius(slots, maxCount, center)
        if #slots <= maxCount then
            table.sort(slots, function(a, b)
                return FlatDist2D(a, center) < FlatDist2D(b, center)
            end)
            return slots
        end
        -- Pick evenly from the grid traversal order first, so the visible candidates
        -- cover the whole circle instead of retaining only the innermost points.
        local reduced = {}
        local stride = #slots / maxCount
        for i = 1, maxCount do
            local index = math.clamp(math.floor((i - 0.5) * stride + 1), 1, #slots)
            table.insert(reduced, slots[index])
        end
        table.sort(reduced, function(a, b)
            return FlatDist2D(a, center) < FlatDist2D(b, center)
        end)
        return reduced
    end

    local function BuildGroundSurfaceSlots(center, radius, step)
        local slots = {}
        RefreshPlacementScanFilter()
        for dx = -radius, radius, step do
            for dz = -radius, radius, step do
                if (dx * dx + dz * dz) <= radius * radius then
                    local hitPos = CastValidGroundSurface(center.X + dx, center.Z + dz, center.Y)
                    if hitPos and not IsRejectedSlot("Ground", hitPos) then
                        AddUniqueSlot(slots, hitPos, math.clamp(step * 0.55, 0.12, 0.9))
                    end
                end
            end
        end
        return ThinSlotsAcrossRadius(slots, 3600, center)
    end

    local function BuildHillSurfaceSlots(center, radius, step)
        local slots = {}
        if #State.HillGeometries == 0 then ScanTerrainHillParts() end
        if #State.HillGeometries == 0 then return slots end

        -- Scan a world-space grid around the target instead of generating points from
        -- each part's bounding box. Each candidate must independently ray-hit an actual
        -- upward-facing surface inside _terrain.hill.
        for dx = -radius, radius, step do
            for dz = -radius, radius, step do
                if (dx * dx + dz * dz) <= radius * radius then
                    local worldX = center.X + dx
                    local worldZ = center.Z + dz
                    local surface, hitPart = GetSurfacePointOnTerrainHill(worldX, worldZ)
                    if surface and hitPart and not IsRejectedSlot("Hill", surface) then
                        AddUniqueSlot(slots, surface, math.clamp(step * 0.55, 0.12, 0.9))
                    end
                end
            end
        end

        return ThinSlotsAcrossRadius(slots, 3600, center)
    end

    -- Build separate, dense visual grids. These markers can show through occluders,
    -- while Auto Play continues using only the strictly validated Ground/Hill lists.
    local function GetGroundVisualSurface(x, z, centerY)
        local terrainRoot = Workspace:FindFirstChild("_terrain") or Workspace:FindFirstChild("terrain")
        local groundFolder = terrainRoot and (terrainRoot:FindFirstChild("ground") or terrainRoot:FindFirstChild("Ground"))
        local origin = Vector3.new(x, (tonumber(centerY) or 0) + 180, z)
        local direction = Vector3.new(0, -360, 0)
        if groundFolder then
            groundVisualIncludeParams.FilterDescendantsInstances = {groundFolder}
            local hit = Workspace:Raycast(origin, direction, groundVisualIncludeParams)
            if hit and hit.Position and hit.Normal and hit.Normal.Y >= 0.55 then
                return hit.Position
            end
        end
        -- Fallback for maps without a dedicated _terrain.ground folder. This path is
        -- visual-only and deliberately does not reject props/road-overlap candidates.
        local hit = Workspace:Raycast(origin, direction, placementScanRayParams)
        if hit and hit.Position and hit.Normal and hit.Normal.Y >= 0.55 then
            return hit.Position
        end
        -- Keep the display grid complete if a point has no ray hit. This fallback is
        -- never added to the actual slot lists used by Auto Play.
        return Vector3.new(x, tonumber(centerY) or 0, z)
    end

    local function BuildGroundVisualGrid(center, radius, step)
        local dots = {}
        RefreshPlacementScanFilter()
        for dx = -radius, radius, step do
            for dz = -radius, radius, step do
                if dx * dx + dz * dz <= radius * radius then
                    local surface = GetGroundVisualSurface(center.X + dx, center.Z + dz, center.Y)
                    if surface then table.insert(dots, surface) end
                end
            end
        end
        return ThinSlotsAcrossRadius(dots, 2400, center)
    end

    local function SnapGroundCenterToActualSurface(pos)
        RefreshPlacementScanFilter()
        local hit = Workspace:Raycast(
            Vector3.new(pos.X, pos.Y + 180, pos.Z),
            Vector3.new(0, -360, 0),
            placementScanRayParams
        )
        if not hit or not hit.Position or not hit.Instance or not hit.Normal or hit.Normal.Y < 0.75 then
            return nil
        end
        if hit.Instance:IsA("BasePart") and not hit.Instance.CanCollide then return nil end
        if IsInsideAnyHillFootprint(pos.X, pos.Z, 0.2) then return nil end
        -- Always carry the actual surface Y forward. Returning the route's old Y
        -- when the floor lived under _map caused the cluster scan to reject every dot.
        return Vector3.new(pos.X, hit.Position.Y, pos.Z)
    end

    local function CalculateTightInterceptCluster()
        if #State.MainRoadSegments == 0 then
            BuildMainRoadPathFromWorkspace(false)
        end
        if #State.HillPartInstances == 0 then
            ScanTerrainHillParts()
        end

        local totalRoadLen = math.max(State.MainRoadTotalLength, 1)
        local basePct = (tonumber(Options.InterceptRoadPercent and Options.InterceptRoadPercent.Value) or 17) / 100
        local leadStuds = tonumber(Options.MonsterLeadStuds and Options.MonsterLeadStuds.Value) or 16
        local pointSpacing = math.clamp(tonumber(Options.ClusterSpacing and Options.ClusterSpacing.Value) or 0.20, 0.10, 1.0)
        local roadSideOffset = tonumber(Options.RoadSideOffset and Options.RoadSideOffset.Value) or 0
        local trackFrontMonster = Options.DynamicMonsterIntercept and Options.DynamicMonsterIntercept.Value

        local sharedTargetDist = totalRoadLen * basePct
        if trackFrontMonster then
            local frontMonsterDist = GetFrontMonsterRoadDistance()
            if frontMonsterDist then
                sharedTargetDist = math.clamp(frontMonsterDist - leadStuds, totalRoadLen * 0.08, totalRoadLen * 0.92)
            end
        end

        -- Ground and Hill use the SAME route target. Their own valid surface hits
        -- determine the final position; there are no separate per-type route offsets.
        local groundTargetDist = sharedTargetDist
        local hillTargetDist = sharedTargetDist
        local centerRoadPos, rightVec
        local groundRoadPos, groundRightVec
        local hillRoadPos, hillRightVec

        if #State.MainRoadSegments > 0 and State.MainRoadTotalLength > 0.05 then
            centerRoadPos, _, rightVec = GetPointAlongRoadByDist(sharedTargetDist)
            groundRoadPos, _, groundRightVec = GetPointAlongRoadByDist(groundTargetDist)
            hillRoadPos, _, hillRightVec = GetPointAlongRoadByDist(hillTargetDist)
        else
            local baseAnchor = FindBaseAnchorPosition()
            local spawnAnchor = FindMonsterSpawnAnchorPosition()
            local sharedFallbackPct = math.clamp(sharedTargetDist / totalRoadLen, 0, 1)
            local groundFallbackPct = math.clamp(groundTargetDist / totalRoadLen, 0, 1)
            local hillFallbackPct = math.clamp(hillTargetDist / totalRoadLen, 0, 1)
            if baseAnchor and spawnAnchor then
                centerRoadPos = baseAnchor:Lerp(spawnAnchor, sharedFallbackPct)
                groundRoadPos = baseAnchor:Lerp(spawnAnchor, groundFallbackPct)
                hillRoadPos = baseAnchor:Lerp(spawnAnchor, hillFallbackPct)
            elseif baseAnchor then
                centerRoadPos, groundRoadPos, hillRoadPos = baseAnchor, baseAnchor, baseAnchor
            elseif spawnAnchor then
                centerRoadPos, groundRoadPos, hillRoadPos = spawnAnchor, spawnAnchor, spawnAnchor
            else
                local playerPos = GetPlayerReferencePos() or Vector3.zero
                centerRoadPos, groundRoadPos, hillRoadPos = playerPos, playerPos, playerPos
            end
            rightVec = Vector3.new(1, 0, 0)
            groundRightVec = rightVec
            hillRightVec = rightVec
        end

        rightVec = rightVec or Vector3.new(1, 0, 0)
        groundRightVec = groundRightVec or rightVec
        hillRightVec = hillRightVec or rightVec
        local scanCenter = centerRoadPos + (rightVec * roadSideOffset)
        local groundCenterRaw = groundRoadPos + (groundRightVec * roadSideOffset)
        local groundCenter = SnapGroundCenterToActualSurface(groundCenterRaw)
        local groundSurfaceCenterValid = groundCenter ~= nil
        -- Keep the path anchor for UI stability only; never generate ground dots from it
        -- when a real collidable floor surface could not be found beneath it.
        if not groundCenter then groundCenter = groundCenterRaw end
        local hillSearchAnchor = hillRoadPos + (hillRightVec * roadSideOffset)

        -- Center the Hill zone on a real part under _terrain.hill, not the road waypoint.
        -- If no nearby hill surface is found, keep the search anchor and the Hill list stays empty.
        local hillSurfaceCenter = FindClosestPointOnTerrainHill(hillSearchAnchor)
        local hillCenter = hillSearchAnchor
        if hillSurfaceCenter and FlatDist2D(hillSurfaceCenter, hillSearchAnchor) <= 32 then
            hillCenter = hillSurfaceCenter
        end

        State.ClusterSlots.CenterPos = scanCenter
        State.ClusterSlots.GroundCenterPos = groundCenter
        State.ClusterSlots.HillCenterPos = hillCenter

        -- Each colored circle is the actual search boundary for its own placement type.
        -- Dots outside the corresponding circle are never generated.
        local groundCircleRadius = math.clamp(tonumber(Options.GroundCircleRadius and Options.GroundCircleRadius.Value) or 6, 2, 10)
        local hillCircleRadius = math.clamp(tonumber(Options.HillCircleRadius and Options.HillCircleRadius.Value) or 6, 2, 10)
        State.ClusterSlots.GroundRadius = groundCircleRadius
        State.ClusterSlots.HillRadius = hillCircleRadius

        -- Low spacing values create tightly packed grids while keeping the raycast workload bounded.
        local sampleStep = math.clamp(pointSpacing, 0.10, 1.0)
        local groundCluster = {}
        if groundSurfaceCenterValid then
            groundCluster = BuildGroundSurfaceSlots(groundCenter, groundCircleRadius, sampleStep)
        end
        local hillStep = math.clamp(pointSpacing, 0.10, 1.0)
        local hillCluster = BuildHillSurfaceSlots(hillCenter, hillCircleRadius, hillStep)
        State.ClusterSlots.Ground = groundCluster
        State.ClusterSlots.Hill = hillCluster
        -- Display-only dots use a stable dense grid (min 0.28 studs) and are not
        -- throttled by road/prop blockers. Actual Auto Play still uses the valid lists above.
        local visualStep = math.max(0.28, sampleStep * 1.8)
        State.ClusterSlots.GroundVisual = BuildGroundVisualGrid(groundCenter, groundCircleRadius, visualStep)
        -- HillSurfaceSlots already raycast against the include-only _terrain.hill filter,
        -- so blockers cannot remove valid hill points; reuse it instead of doing a second scan.
        State.ClusterSlots.HillVisual = hillCluster
        lastSurfaceScanAt = os.clock()
        surfaceSlotsDirty = false

        SafeUpdateParagraph(
            AIStatusPara,
            "🧭 Surface-Validated Placement (สแกนพื้นผิวจริง)",
            string.format("ในวงกลม Ground (r=%.1f): %d จุด | Hill (r=%.1f): %d จุด | ระยะห่างจุด %.2f studs", groundCircleRadius, #groundCluster, hillCircleRadius, #hillCluster, pointSpacing)
        )
    end

    local function RenderMiniClusterDots()
        local showDots = (Options.ShowMiniClusterDots and Options.ShowMiniClusterDots.Value) ~= false
        local showZone = (Options.ShowHologramZone and Options.ShowHologramZone.Value) ~= false

        if not showDots and not showZone then
            if MiniDotPool.Folder then
                pcall(function()
                    MiniDotPool.Folder:Destroy()
                end)
                MiniDotPool.Folder = nil
                State.HologramFolder = nil
                MiniDotPool.GroundDots = {}
                MiniDotPool.HillDots = {}
                MiniDotPool.GroundRings = {}
                MiniDotPool.HillRings = {}
                MiniDotPool.GroundZoneAnchor = nil
                MiniDotPool.HillZoneAnchor = nil
                MiniDotPool.GroundZoneBoundary = nil
                MiniDotPool.HillZoneBoundary = nil
                MiniDotPool.CenterPin = nil
                MiniDotPool.ZoneRing = nil
                MiniDotPool.ZoneBeacon = nil
            end
            return
        end

        -- Do not rescan hundreds of surface points every render tick. Re-scan on
        -- setting/map changes, or periodically if a placement type has no valid points.
        if surfaceSlotsDirty or (os.clock() - lastSurfaceScanAt) >= 4.0 then
            CalculateTightInterceptCluster()
        end

        if not MiniDotPool.Folder or not MiniDotPool.Folder.Parent then
            local existing = Workspace:FindFirstChild("_TD_Holograms")
            if existing then
                pcall(function()
                    existing:Destroy()
                end)
            end
            local folder = Instance.new("Folder")
            folder.Name = "_TD_Holograms"
            folder.Parent = Workspace
            MiniDotPool.Folder = folder
            State.HologramFolder = folder
            MiniDotPool.GroundDots = {}
            MiniDotPool.HillDots = {}
            MiniDotPool.GroundRings = {}
            MiniDotPool.HillRings = {}
            MiniDotPool.GroundZoneAnchor = nil
            MiniDotPool.HillZoneAnchor = nil
            MiniDotPool.GroundZoneBoundary = nil
            MiniDotPool.HillZoneBoundary = nil
            MiniDotPool.CenterPin = nil
            MiniDotPool.ZoneRing = nil
            MiniDotPool.ZoneBeacon = nil
        end

        local centerPos = State.ClusterSlots.CenterPos
        local spacingVal = math.clamp(tonumber(Options.ClusterSpacing and Options.ClusterSpacing.Value) or 0.20, 0.10, 1.0)
        RefreshPlacementScanFilter()

        if showZone then
            if not MiniDotPool.ZoneBeacon or not MiniDotPool.ZoneBeacon.Parent then
                MiniDotPool.ZoneBeacon = CreateHologramPart(
                    MiniDotPool.Folder,
                    "ClusterZoneBeacon",
                    Enum.PartType.Cylinder,
                    Color3.fromRGB(45, 255, 110),
                    Vector3.new(5, 0.18, 0.18),
                    0.72,
                    Enum.Material.Neon
                )
            end
            MiniDotPool.ZoneBeacon.CFrame = CFrame.new(centerPos + Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.rad(90))

            local function EnsureZoneBoundary(anchorKey, boundaryKey, center, radius, color, slots, name)
                local isHillBoundary = name == "HillPlacement"

                local function SurfaceAt(x, z)
                    if isHillBoundary then
                        local p = GetSurfacePointOnTerrainHill(x, z)
                        if p then return p end
                        return GetGroundVisualSurface(x, z, center.Y)
                    end
                    return GetGroundVisualSurface(x, z, center.Y)
                end

                local anchorSurface = SurfaceAt(center.X, center.Z)
                local anchorY = anchorSurface and (anchorSurface.Y + 0.03) or center.Y
                local anchor = MiniDotPool[anchorKey]
                if not anchor or not anchor.Parent then
                    anchor = CreateHologramPart(
                        MiniDotPool.Folder,
                        name .. "_CircleAnchor",
                        Enum.PartType.Ball,
                        color,
                        Vector3.new(0.05, 0.05, 0.05),
                        1,
                        Enum.Material.SmoothPlastic
                    )
                    MiniDotPool[anchorKey] = anchor
                end
                anchor.CFrame = CFrame.new(center.X, anchorY, center.Z)

                local boundary = MiniDotPool[boundaryKey]
                if boundary and not boundary:IsA("Folder") then
                    pcall(function() boundary:Destroy() end)
                    boundary = nil
                end
                if not boundary or not boundary.Parent then
                    boundary = Instance.new("Folder")
                    boundary.Name = name .. "_SurfaceCircleBoundary"
                    boundary.Parent = MiniDotPool.Folder
                    MiniDotPool[boundaryKey] = boundary
                end

                local ringCount = 144
                for i = 1, ringCount do
                    local beadName = "RingDot_" .. i
                    local bead = boundary:FindFirstChild(beadName)
                    if not bead or not bead:IsA("BasePart") then
                        if bead then pcall(function() bead:Destroy() end) end
                        bead = CreateHologramPart(
                            boundary,
                            beadName,
                            Enum.PartType.Ball,
                            color,
                            Vector3.new(0.22, 0.08, 0.22),
                            0.04,
                            Enum.Material.Neon
                        )
                    end

                    local angle = (i - 1) * (math.pi * 2 / ringCount)
                    local x = center.X + math.cos(angle) * radius
                    local z = center.Z + math.sin(angle) * radius
                    local surface = SurfaceAt(x, z)
                    if surface then
                        -- Each bead follows the real surface at its own X/Z, so the
                        -- circular boundary cannot float at slots[1].Y on uneven ground.
                        bead.CFrame = CFrame.new(x, surface.Y + 0.045, z)
                        bead.Transparency = 0.04
                    else
                        -- Display-only circle outline must stay closed even when the
                        -- ray is occluded/misses; placement candidates remain separately validated.
                        bead.CFrame = CFrame.new(x, center.Y + 0.08, z)
                        bead.Transparency = 0.04
                    end
                    bead.Color = color
                    EnsureMiniDotAlwaysOnTop(bead, color, 5)
                end
            end

            EnsureZoneBoundary(
                "GroundZoneAnchor", "GroundZoneBoundary",
                State.ClusterSlots.GroundCenterPos or centerPos,
                State.ClusterSlots.GroundRadius or 6,
                Color3.fromRGB(0, 235, 255), State.ClusterSlots.Ground, "GroundPlacement"
            )
            EnsureZoneBoundary(
                "HillZoneAnchor", "HillZoneBoundary",
                State.ClusterSlots.HillCenterPos or centerPos,
                State.ClusterSlots.HillRadius or 6,
                Color3.fromRGB(255, 225, 35), State.ClusterSlots.Hill, "HillPlacement"
            )

            -- The old shared tiny disk is no longer used; keep only the two clear
            -- Ground/Hill circle outlines that contain their respective point sets.
            if MiniDotPool.ZoneRing then
                pcall(function() MiniDotPool.ZoneRing:Destroy() end)
                MiniDotPool.ZoneRing = nil
            end
        else
            if MiniDotPool.ZoneBeacon then
                MiniDotPool.ZoneBeacon:Destroy()
                MiniDotPool.ZoneBeacon = nil
            end
            if MiniDotPool.ZoneRing then
                MiniDotPool.ZoneRing:Destroy()
                MiniDotPool.ZoneRing = nil
            end
            for _, key in ipairs({"GroundZoneBoundary", "HillZoneBoundary", "GroundZoneAnchor", "HillZoneAnchor"}) do
                local item = MiniDotPool[key]
                if item then pcall(function() item:Destroy() end) end
                MiniDotPool[key] = nil
            end
        end

        if not MiniDotPool.CenterPin or not MiniDotPool.CenterPin.Parent then
            MiniDotPool.CenterPin = CreateHologramPart(
                MiniDotPool.Folder,
                "InterceptCenterDot",
                Enum.PartType.Ball,
                Color3.fromRGB(45, 255, 110),
                Vector3.new(0.32, 0.32, 0.32),
                0.05,
                Enum.Material.Neon
            )
        end
        MiniDotPool.CenterPin.CFrame = CFrame.new(centerPos + Vector3.new(0, 0.18, 0))

        -- Section 2.1: use the existing MiniDot center marker as the anchor.
        -- No R6/template dummy is created; the marker remains a lightweight local Part.
        local centerBillboard = MiniDotPool.CenterPin:FindFirstChild("__PlacementZoneLabel")
        if not centerBillboard then
            centerBillboard = Instance.new("BillboardGui")
            centerBillboard.Name = "__PlacementZoneLabel"
            centerBillboard.Adornee = MiniDotPool.CenterPin
            centerBillboard.AlwaysOnTop = true
            centerBillboard.LightInfluence = 0
            centerBillboard.MaxDistance = 10000
            centerBillboard.Size = UDim2.fromOffset(150, 28)
            centerBillboard.StudsOffsetWorldSpace = Vector3.new(0, 2.2, 0)
            centerBillboard.Parent = MiniDotPool.CenterPin
            local label = Instance.new("TextLabel")
            label.Name = "Label"
            label.BackgroundTransparency = 1
            label.BorderSizePixel = 0
            label.Size = UDim2.fromScale(1, 1)
            label.Font = Enum.Font.GothamBold
            label.TextScaled = true
            label.TextStrokeTransparency = 0.25
            label.TextColor3 = Color3.fromRGB(120, 255, 150)
            label.Parent = centerBillboard
        end
        local centerLabel = centerBillboard:FindFirstChild("Label")
        if centerLabel then
            local pct = tonumber(Options.InterceptRoadPercent and Options.InterceptRoadPercent.Value) or 17
            local dynamic = Options.DynamicMonsterIntercept and Options.DynamicMonsterIntercept.Value
            centerLabel.Text = dynamic and string.format("MiniDot • Dynamic | %.0f%%", pct)
                or string.format("MiniDot • Road %.0f%%", pct)
        end

        if showDots then
            local gList = (State.ClusterSlots.GroundVisual and #State.ClusterSlots.GroundVisual > 0)
                and State.ClusterSlots.GroundVisual or State.ClusterSlots.Ground
            local gCount = math.min(#gList, 2400)
            for i = 1, gCount do
                local dot = MiniDotPool.GroundDots[i]
                if not dot or not dot.Parent then
                    dot = CreateHologramPart(
                        MiniDotPool.Folder,
                        "MiniGroundDot_" .. i,
                        Enum.PartType.Ball,
                        Color3.fromRGB(0, 215, 255),
                        Vector3.new(0.18, 0.12, 0.18),
                        0.025,
                        Enum.Material.Neon
                    )
                    MiniDotPool.GroundDots[i] = dot
                end
                dot.CFrame = CFrame.new(gList[i] + Vector3.new(0, 0.10, 0))
                EnsureMiniDotAlwaysOnTop(dot, Color3.fromRGB(0, 215, 255), 4)
            end

            -- The scan displays up to 3600 points per surface; stale dots are cleared below.

            local hList = (State.ClusterSlots.HillVisual and #State.ClusterSlots.HillVisual > 0)
                and State.ClusterSlots.HillVisual or State.ClusterSlots.Hill
            local hCount = math.min(#hList, 2400)
            for i = 1, hCount do
                local dot = MiniDotPool.HillDots[i]
                if not dot or not dot.Parent then
                    dot = CreateHologramPart(
                        MiniDotPool.Folder,
                        "MiniHillDot_" .. i,
                        Enum.PartType.Ball,
                        Color3.fromRGB(255, 230, 55),
                        Vector3.new(0.18, 0.12, 0.18),
                        0.025,
                        Enum.Material.Neon
                    )
                    MiniDotPool.HillDots[i] = dot
                end
                dot.CFrame = CFrame.new(hList[i] + Vector3.new(0, 0.10, 0))
                EnsureMiniDotAlwaysOnTop(dot, Color3.fromRGB(255, 230, 55), 4)
            end
            for i = #MiniDotPool.GroundDots, gCount + 1, -1 do
                local staleRing = MiniDotPool.GroundRings[i]
                if staleRing then pcall(function() staleRing:Destroy() end) end
                MiniDotPool.GroundRings[i] = nil
                local stale = MiniDotPool.GroundDots[i]
                if stale then pcall(function() stale:Destroy() end) end
                MiniDotPool.GroundDots[i] = nil
            end
            for i = #MiniDotPool.HillDots, hCount + 1, -1 do
                local staleRing = MiniDotPool.HillRings[i]
                if staleRing then pcall(function() staleRing:Destroy() end) end
                MiniDotPool.HillRings[i] = nil
                local stale = MiniDotPool.HillDots[i]
                if stale then pcall(function() stale:Destroy() end) end
                MiniDotPool.HillDots[i] = nil
            end
        else
            for _, d in pairs(MiniDotPool.GroundDots) do
                pcall(function()
                    d:Destroy()
                end)
            end
            for _, d in pairs(MiniDotPool.HillDots) do
                pcall(function()
                    d:Destroy()
                end)
            end
            for _, ring in pairs(MiniDotPool.GroundRings) do
                pcall(function() ring:Destroy() end)
            end
            for _, ring in pairs(MiniDotPool.HillRings) do
                pcall(function() ring:Destroy() end)
            end
            MiniDotPool.GroundDots = {}
            MiniDotPool.HillDots = {}
            MiniDotPool.GroundRings = {}
            MiniDotPool.HillRings = {}
        end
    end

    Tabs.AI:AddToggle("AutoPlayEnabled", {
        Title = "Auto Place Cluster (วางอัตโนมัติเป็นกระจุก)",
        Description = "เปิดเป็นค่าเริ่มต้นเพื่อให้ระบบวางยูนิตอัตโนมัติ; ปิดเมื่อต้องการคลิกวางเอง",
        Default = not (AA_CONFIG.AutoPlay and AA_CONFIG.AutoPlay.Enabled == false),
        Callback = function() AutoSaveUserConfig() end
    })

    -----------------------------------------------------------------
    -- QUICK MANUAL PLACEMENT (v33)
    -- Run script, then click a placeable surface. Selects the next eligible equipped
    -- unit automatically and reads the native placement cap from unit data.
    -----------------------------------------------------------------
    local ManualOverlapState = {
        Enabled = false,
        LastClickAt = 0,
        Busy = false,
        NextUnitIndex = 1,
        CachedPreviewUnit = nil,
        LastPreviewScanAt = 0,
        LastPreviewAt = 0,
    }
    local ManualOverlapMouse = LocalPlayer:GetMouse()
    local ManualOverlapInput = game:GetService("UserInputService")

    local oldManualMarker = Workspace:FindFirstChild("_TD_ManualOverlapTarget")
    if oldManualMarker then pcall(function() oldManualMarker:Destroy() end) end

    local ManualOverlapMarker = Instance.new("Part")
    ManualOverlapMarker.Name = "_TD_ManualOverlapTarget"
    ManualOverlapMarker.Shape = Enum.PartType.Ball
    ManualOverlapMarker.Size = Vector3.new(0.48, 0.48, 0.48)
    ManualOverlapMarker.Anchored = true
    ManualOverlapMarker.CanCollide = false
    ManualOverlapMarker.CanTouch = false
    ManualOverlapMarker.CanQuery = false
    ManualOverlapMarker.Material = Enum.Material.Neon
    ManualOverlapMarker.Transparency = 1
    ManualOverlapMarker.Parent = Workspace

    local function ManualStatus(title, description)
        -- No pop-up for failed placement attempts. Keep compact status in the main panel.
        pcall(function()
            SafeUpdateParagraph(AIStatusPara, title, description)
        end)
    end

    local function GetUnitPlacementCap(unitInfo)
        local cap = tonumber(unitInfo and unitInfo.max_cap)
        if cap and cap > 0 then return math.floor(cap) end
        return 4 -- Last-resort fallback only when game metadata contains no cap field.
    end

    -- When the mouse is over an already-placed unit, target its exact model pivot X/Z,
    -- not the surface point on the visible side/top of the unit. This is critical for
    -- intentional exact overlap with manual clicks.
    local function GetManualClickPosition(target, fallbackPos)
        local unitsFolder = Workspace:FindFirstChild("_UNITS")
        if not unitsFolder or not target or not target:IsDescendantOf(unitsFolder) then
            return fallbackPos
        end
        local rootUnit = target
        while rootUnit and rootUnit.Parent and rootUnit.Parent ~= unitsFolder do
            rootUnit = rootUnit.Parent
        end
        if not rootUnit or rootUnit.Parent ~= unitsFolder then return fallbackPos end
        if rootUnit:IsA("Model") then
            local ok, pivot = pcall(function() return rootUnit:GetPivot() end)
            if ok and typeof(pivot) == "CFrame" then return pivot.Position end
        elseif rootUnit:IsA("BasePart") then
            return rootUnit.Position
        end
        return fallbackPos
    end

    local function BuildManualPlacementCFrame(pos, unitInfo)
        if typeof(pos) ~= "Vector3" then return nil end
        if unitInfo and tostring(unitInfo.placement_type) == "Hill" then
            return BuildHillPlacementCFrame(pos)
        end

        -- Mouse.Hit can be the TOP of an already-placed unit. Raycast from well above
        -- the click to the real ground, ignoring _UNITS/_ENEMIES, before asking the
        -- standard placement builder to produce the final server CFrame.
        RefreshPlacementRayFilter()
        local groundPos, groundInst = SafeRaycastGround(pos, 90, -240)
        if groundInst and groundPos then
            return BuildPlacementCFrame(groundPos)
        end
        return BuildPlacementCFrame(pos)
    end

    local function HideManualOverlapMarker()
        if ManualOverlapMarker and ManualOverlapMarker.Parent then
            ManualOverlapMarker.Transparency = 1
        end
    end

    local function GetNextManualUnit()
        local ok, equipped = pcall(GetEquippedUnitsDetailed)
        if not ok or type(equipped) ~= "table" or #equipped == 0 then
            return nil, nil, nil, nil, "ยังไม่พบยูนิตในทีม"
        end

        local count = #equipped
        local cash = GetPlayerCash()
        local startIndex = math.clamp(ManualOverlapState.NextUnitIndex, 1, count)
        for step = 0, count - 1 do
            local index = ((startIndex + step - 1) % count) + 1
            local info = equipped[index]
            if info and info.uuid then
                local currentCount = CountMyPlacedUnitsByIdOrUUID(info.unit_id, info.uuid)
                local cap = GetUnitPlacementCap(info)
                local price = LookupUnitCostByIdOrName(info.unit_id, info.unit_name, 0) or 400
                if currentCount < cap and cash >= price then
                    return info, index, currentCount, cap, nil
                end
            end
        end
        return nil, nil, nil, nil, cash < 1 and "รอเงินในเกม" or "ยูนิตในทีมวางครบลิมิตหรือเงินยังไม่พอ"
    end

    -- Clicking once cycles through the equipped team; no dropdown or refresh button required.
    Tabs.AI:AddToggle("ManualOverlapMode", {
        Title = "Click to Place (วางมือทันที)",
        Description = "ปิดเป็นค่าเริ่มต้นเพื่อให้ Auto Place ทำงาน; เปิดเฉพาะเมื่อต้องการคลิกวางเอง",
        Default = AA_CONFIG.AutoPlay and AA_CONFIG.AutoPlay.ManualClickToPlace == true,
        Callback = function(value)
            ManualOverlapState.Enabled = value == true
            if ManualOverlapState.Enabled then
                if Options.AutoPlayEnabled and Options.AutoPlayEnabled.Value then
                    Options.AutoPlayEnabled:SetValue(false)
                end
                ManualStatus("🟢 พร้อมคลิกวาง", "คลิกพื้นที่บนแผนที่เพื่อใช้ยูนิตตัวถัดไปที่ยังวางได้")
            else
                HideManualOverlapMarker()
                ManualStatus("⏸ ปิด Click to Place", "เปิดอีกครั้งเมื่อต้องการกลับมาคลิกวาง")
            end
            AutoSaveUserConfig()
        end
    })
    -- Ensure first-run behavior doesn't depend on Fluent firing the default callback.
    ManualOverlapState.Enabled = false

    AddConnection(RunService.RenderStepped, function()
        if not ManualOverlapState.Enabled then
            HideManualOverlapMarker()
            return
        end
        local previewNow = os.clock()
        if previewNow - ManualOverlapState.LastPreviewAt < 0.06 then return end
        ManualOverlapState.LastPreviewAt = previewNow
        local target = ManualOverlapMouse.Target
        if not target or not target.Parent then
            HideManualOverlapMarker()
            return
        end
        local hitPos = GetManualClickPosition(target, ManualOverlapMouse.Hit.Position)
        if os.clock() - ManualOverlapState.LastPreviewScanAt >= 0.45 then
            ManualOverlapState.CachedPreviewUnit = select(1, GetNextManualUnit())
            ManualOverlapState.LastPreviewScanAt = os.clock()
        end
        local info = ManualOverlapState.CachedPreviewUnit
        if not info then
            HideManualOverlapMarker()
            return
        end
        local cf = BuildManualPlacementCFrame(hitPos, info)
        if cf then
            ManualOverlapMarker.Color = tostring(info.placement_type) == "Hill"
                and Color3.fromRGB(255, 220, 45) or Color3.fromRGB(0, 235, 255)
            ManualOverlapMarker.CFrame = cf * CFrame.new(0, 0.18, 0)
            ManualOverlapMarker.Transparency = 0.18
        else
            HideManualOverlapMarker()
        end
    end)

    -- Exact-point test: never silently place beside the clicked coordinate.
    local ManualRetryOffsets = { Vector3.zero }
    local ManualExactPointRetries = 1 -- A sends one request at the exact clicked point only.

    AddConnection(ManualOverlapInput.InputBegan, function(input, gameProcessed)
        if not ManualOverlapState.Enabled or gameProcessed then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        if ManualOverlapInput:GetFocusedTextBox() or ManualOverlapState.Busy then return end

        local target = ManualOverlapMouse.Target
        if not target or not target.Parent then return end
        if LocalPlayer.Character and target:IsDescendantOf(LocalPlayer.Character) then return end

        local now = os.clock()
        if now - ManualOverlapState.LastClickAt < 0.22 then return end
        ManualOverlapState.LastClickAt = now

        local hitPos = GetManualClickPosition(target, ManualOverlapMouse.Hit.Position)
        local info, selectedIndex, oldCount, unitCap, reason = GetNextManualUnit()
        if not info then
            ManualStatus("⏳ ยังวางไม่ได้", tostring(reason or "รอยูนิต/เงิน/ลิมิตพร้อม"))
            return
        end

        ManualOverlapState.Busy = true
        task.spawn(function()
            local accepted = false
            local attempts = 0
            for _, offset in ipairs(ManualRetryOffsets) do
                if accepted then break end
                local attemptPos = hitPos + offset
                local placementCF = BuildManualPlacementCFrame(attemptPos, info)
                if placementCF then
                    for exactTry = 1, ManualExactPointRetries do
                        if accepted then break end
                        attempts = attempts + 1
                        InvokeServer("spawn_unit", info.uuid, placementCF)
                        -- Re-send only the same CFrame; never shift away from the clicked overlap point.
                        for _ = 1, 4 do
                            task.wait(0.15)
                            local current = CountMyPlacedUnitsByIdOrUUID(info.unit_id, info.uuid)
                            if current > oldCount then
                                accepted = true
                                oldCount = current
                                break
                            end
                        end
                    end
                end
            end

            if accepted then
                ManualOverlapState.NextUnitIndex = (selectedIndex % math.max(1, #GetEquippedUnitsDetailed())) + 1
                ManualStatus(
                    "✅ วางสำเร็จ",
                    string.format("%s • %d/%d • ตรวจตำแหน่ง %d จุด", tostring(info.unit_name), oldCount, unitCap, attempts)
                )
            else
                -- Silent failure: no notification popup. Keep the next click available and report only in-panel.
                ManualStatus(
                    "↻ พร้อมลองใหม่",
                    string.format("จุดเดิมยังไม่ผ่านการตรวจของเกมสำหรับ %s; ระบบจะไม่เลื่อนจุดไปวางข้าง ๆ", tostring(info.unit_name))
                )
            end
            ManualOverlapState.Busy = false
        end)
    end)

    -- Short profiles set several placement variables together; detailed controls remain in Advanced.
    Tabs.AI:AddDropdown("PlacementProfile", {
        Title = "Placement Profile (ตั้งค่าพร้อมกัน)",
        Description = "เลือกแบบเดียวเพื่อปรับค่าที่เกี่ยวข้องหลายตัวพร้อมกัน",
        Values = { "Dense Overlap", "Balanced", "Wide Coverage", "Dynamic Intercept" },
        Default = (function()
            local v = AA_CONFIG.Placement and AA_CONFIG.Placement.Profile
            if v == "Balanced" then return 2 elseif v == "Wide Coverage" then return 3 elseif v == "Dynamic Intercept" then return 4 end
            return 1
        end)(),
        Multi = false,
        Callback = function(value)
            local profile = tostring(value)
            local config = {
                ["Dense Overlap"] = { spacing = 0.15, radius = 5, road = 70, dynamic = false, lead = 12, offset = 0 },
                ["Balanced"] = { spacing = 0.25, radius = 6, road = 68, dynamic = false, lead = 16, offset = 0 },
                ["Wide Coverage"] = { spacing = 0.45, radius = 8, road = 65, dynamic = false, lead = 16, offset = 0 },
                ["Dynamic Intercept"] = { spacing = 0.22, radius = 6, road = 68, dynamic = true, lead = 18, offset = 0 },
            }
            local c = config[profile]
            if c then
                local function setValue(key, val)
                    local opt = Options and Options[key]
                    if opt and type(opt.SetValue) == "function" then pcall(opt.SetValue, opt, val) end
                end
                setValue("ClusterSpacing", c.spacing)
                setValue("GroundCircleRadius", c.radius)
                setValue("HillCircleRadius", c.radius)
                setValue("InterceptRoadPercent", c.road)
                setValue("DynamicMonsterIntercept", c.dynamic)
                setValue("MonsterLeadStuds", c.lead)
                setValue("RoadSideOffset", c.offset)
                ManualStatus("⚙ ใช้โปรไฟล์ " .. profile, "ปรับค่าการวางที่เกี่ยวข้องพร้อมกันแล้ว; เปลี่ยนละเอียดได้ในแท็บ Settings")
            end
            AutoSaveUserConfig()
        end
    })

    task.defer(function()
        -- Let saved settings and game state initialize, then check the actual Act 6 completion flags.
        task.wait(0.6)
        pcall(function() RefreshAndCheckWorldCompletion() end)
        local bothAct6Complete = KaitanConfig.PassedNamek == true and KaitanConfig.PassedWalledCity == true

        if bothAct6Complete then
            local autoPlaceInfinite = AA_CONFIG.AutoPlay and AA_CONFIG.AutoPlay.AutoPlaceInInfinite ~= false
            if autoPlaceInfinite then
                -- Both Act 6 are complete, but the user explicitly wants Auto Place in Infinite.
                getgenv().TD_QuickManualPlacementBoot = false
                ManualOverlapState.Enabled = false
                if Options.ManualOverlapMode then pcall(function() Options.ManualOverlapMode:SetValue(false) end) end
                if Options.AutoPlayEnabled then pcall(function() Options.AutoPlayEnabled:SetValue(AA_CONFIG.AutoPlay.Enabled ~= false) end) end
                KaitanSetOption("AutoPlayEnabled", AA_CONFIG.AutoPlay.Enabled ~= false)
                KaitanSetOption("ManualOverlapMode", false)
                ManualStatus("🟢 Auto Place ใน Infinite เปิดอยู่", "AA_CONFIG.AutoPlay.AutoPlaceInInfinite = true")
            else
                -- Safe legacy behavior: keep Infinite placement manual when explicitly disabled in config.
                getgenv().TD_QuickManualPlacementBoot = true
                ManualOverlapState.Enabled = true
                if Options.AutoPlayEnabled then pcall(function() Options.AutoPlayEnabled:SetValue(false) end) end
                if Options.ManualOverlapMode then pcall(function() Options.ManualOverlapMode:SetValue(true) end) end
                KaitanSetOption("AutoPlayEnabled", false)
                KaitanSetOption("ManualOverlapMode", true)
                ManualStatus("🛑 ผ่าน Act 6 ครบแล้ว", "ปิด Auto Place ใน Infinite ตามค่า AutoPlaceInInfinite = false")
            end
        else
            -- New / unfinished accounts need automatic placement for Act 6 progression.
            ManualOverlapState.Enabled = false
            if Options.ManualOverlapMode and Options.ManualOverlapMode.Value ~= false then
                pcall(function() Options.ManualOverlapMode:SetValue(false) end)
            end
            if Options.AutoPlayEnabled and Options.AutoPlayEnabled.Value ~= true then
                pcall(function() Options.AutoPlayEnabled:SetValue(true) end)
            end
            getgenv().TD_QuickManualPlacementBoot = false
            ManualStatus("🟢 Auto Place พร้อมใช้งาน", "วางอัตโนมัติเปิดอยู่; Click to Place ปิดอยู่")
        end

        -- Force-hide the Fluent panel after startup. Window:Minimize() is a toggle,
        -- so setting the state directly avoids accidentally showing it again.
        if not (AA_CONFIG.UI and AA_CONFIG.UI.MinimizeOnStart == false) then
            task.wait(0.25)
            pcall(function()
                if Window and Window.Root then
                    Window.Minimized = true
                    Window.Root.Visible = false
                end
            end)
        end
    end)

    Tabs.Settings:AddToggle("AutoRemoveRoadAfterLine", {
        Title = "Delete physical _road locally (ลบถนนจริงฝั่งเครื่อง)",
        Description = "เก็บเส้นแดงจำลองไว้ แล้วลบชิ้นส่วนถนนจริงฝั่งเครื่อง; ถ้าต้องการคืนแผนที่ให้เข้าแมตช์ใหม่",
        Default = not (AA_CONFIG.Placement and AA_CONFIG.Placement.AutoRemoveRoadAfterLine == false),
        Callback = function(val)
            if val then
                task.defer(function()
                    local masked = ProcessAndRemoveMonsterRoad()
                    if masked then surfaceSlotsDirty = true end
                    pcall(CalculateTightInterceptCluster)
                    pcall(RenderMiniClusterDots)
                end)
            else
                RestoreMonsterRoadLocalState() -- Stop deleting newly-created road parts; old destroyed parts require a new match to return.
                pcall(CalculateTightInterceptCluster)
                pcall(RenderMiniClusterDots)
            end
            AutoSaveUserConfig()
        end
    })

    Tabs.Settings:AddToggle("ShowRoadPathLines", {
        Title = "Show Monster Path Line (เส้นกลางตาม LANES)",
        Description = "วาดเส้นกลางตามลำดับ spawn -> numeric waypoints 1..N -> final; สไลเดอร์อ้างอิงเส้นเดียวกัน",
        Default = not (AA_CONFIG.Placement and AA_CONFIG.Placement.ShowRoadPathLines == false),
        Callback = function()
            RenderVisualRoadPath()
            AutoSaveUserConfig()
        end
    })
    task.defer(function() pcall(RenderVisualRoadPath) end)

    Tabs.Settings:AddToggle("ShowHologramZone", {
        Title = "Show Hologram Zone & Beacon (แสดงเสาแสงและวงแหวนอาณาเขต)",
        Description = "แสดงขอบวงกลม Ground สีฟ้าและ Hill สีเหลือง พร้อมเสาแสงจุดอ้างอิง",
        Default = not (AA_CONFIG.Placement and AA_CONFIG.Placement.ShowHologramZone == false),
        Callback = function()
            pcall(RenderMiniClusterDots)
            AutoSaveUserConfig()
        end
    })

    Tabs.Settings:AddToggle("ShowMiniClusterDots", {
        Title = "Show Mini Cluster Dots (แสดงจุดวางในวงกลม)",
        Description = "จุดฟ้ากระจายเต็มพื้นที่ Ground ที่ตรวจพื้นได้; จุดเหลืองกระจายเต็มพื้นที่ Hill ที่ตรวจผิวเนินได้",
        Default = not (AA_CONFIG.Placement and AA_CONFIG.Placement.ShowMiniClusterDots == false),
        Callback = function()
            pcall(RenderMiniClusterDots)
            AutoSaveUserConfig()
        end
    })

    Tabs.Settings:AddSlider("InterceptRoadPercent", {
        Title = "Road Intercept % (ตำแหน่งดักบนทางเดินมอน)",
        Description = "ค่าเริ่มต้น 17% ของเส้นทางมอน; จุดวางเลื่อนตามเส้นแดงแบบ Real-Time",
        Default = tonumber((AA_CONFIG.Placement and AA_CONFIG.Placement.InterceptRoadPercent) or 70),
        Min = 0,
        Max = 100,
        Rounding = 0,
        Callback = function()
            pcall(CalculateTightInterceptCluster)
            pcall(RenderMiniClusterDots)
            AutoSaveUserConfig()
        end
    })

    Tabs.Settings:AddToggle("DynamicMonsterIntercept", {
        Title = "Dynamic Intercept Ahead of Monsters (ดักหน้ามอนตัวแรกอัตโนมัติ)",
        Description = "คำนวณตำแหน่งมอนตัวหน้าสุดแล้วถอยมาดักรอข้างหน้า (ปิดตัวนี้หากต้องการล็อคจุดวางตาม % บนสไลเดอร์ Road Intercept %)",
        Default = AA_CONFIG.Placement and AA_CONFIG.Placement.DynamicMonsterIntercept == true,
        Callback = function()
            surfaceSlotsDirty = true
            pcall(CalculateTightInterceptCluster)
            pcall(RenderMiniClusterDots)
            AutoSaveUserConfig()
        end
    })

    Tabs.Settings:AddSlider("MonsterLeadStuds", {
        Title = "Monster Lead Distance (studs) — ระยะเผื่อดักหน้ามอน",
        Description = "ใช้ร่วมกับ Dynamic Intercept เพื่อเว้นระยะเผื่อหน้ามอนสเตอร์",
        Default = tonumber((AA_CONFIG.Placement and AA_CONFIG.Placement.MonsterLeadStuds) or 12),
        Min = 6,
        Max = 40,
        Rounding = 0,
        Callback = function()
            surfaceSlotsDirty = true
            pcall(CalculateTightInterceptCluster)
            pcall(RenderMiniClusterDots)
            AutoSaveUserConfig()
        end
    })

    Tabs.Settings:AddSlider("ClusterSpacing", {
        Title = "Placement Point Spacing (studs) — ระยะห่างจุดในวงกลม",
        Description = "จุดแสดงผลเป็น AlwaysOnTop เห็นผ่านสิ่งบังได้; ลดค่าเพื่อเพิ่มความหนาแน่นของกริด และ Auto Play ใช้เฉพาะจุดที่ผ่านการตรวจพื้นจริง",
        Default = tonumber((AA_CONFIG.Placement and AA_CONFIG.Placement.ClusterSpacing) or 0.15),
        Min = 0.10,
        Max = 1.0,
        Rounding = 2,
        Callback = function()
            surfaceSlotsDirty = true
            pcall(CalculateTightInterceptCluster)
            pcall(RenderMiniClusterDots)
            AutoSaveUserConfig()
        end
    })

    Tabs.Settings:AddSlider("GroundCircleRadius", {
        Title = "Ground Placement Circle Radius (studs)",
        Description = "กำหนดขนาดวงกลมสีฟ้าสำหรับจุดวาง Ground; จุดอยู่นอกวงจะไม่ถูกสร้าง",
        Default = tonumber((AA_CONFIG.Placement and AA_CONFIG.Placement.GroundCircleRadius) or 5),
        Min = 2,
        Max = 10,
        Rounding = 1,
        Callback = function()
            surfaceSlotsDirty = true
            pcall(CalculateTightInterceptCluster)
            pcall(RenderMiniClusterDots)
            AutoSaveUserConfig()
        end
    })

    Tabs.Settings:AddSlider("HillCircleRadius", {
        Title = "Hill Placement Circle Radius (studs)",
        Description = "กำหนดขนาดวงกลมสีเหลืองสำหรับจุดวาง Hill บน _terrain.hill; จุดอยู่นอกวงจะไม่ถูกสร้าง",
        Default = tonumber((AA_CONFIG.Placement and AA_CONFIG.Placement.HillCircleRadius) or 5),
        Min = 2,
        Max = 10,
        Rounding = 1,
        Callback = function()
            surfaceSlotsDirty = true
            pcall(CalculateTightInterceptCluster)
            pcall(RenderMiniClusterDots)
            AutoSaveUserConfig()
        end
    })

    Tabs.Settings:AddSlider("RoadSideOffset", {
        Title = "Road Side Offset (studs) — ขยับซ้าย/ขวาจากกลางถนน",
        Description = "0 = วางตรงกึ่งกลางแนวทางเดินมอนสเตอร์พอดี",
        Default = tonumber((AA_CONFIG.Placement and AA_CONFIG.Placement.RoadSideOffset) or 0),
        Min = -8,
        Max = 8,
        Rounding = 1,
        Callback = function()
            surfaceSlotsDirty = true
            pcall(CalculateTightInterceptCluster)
            pcall(RenderMiniClusterDots)
            AutoSaveUserConfig()
        end
    })

    Tabs.AI:AddToggle("AutoUpgradeEnabled", {
        Title = "Auto Upgrade (อัปเกรดอัตโนมัติหลังจากวางครบทุกสล็อตแล้ว)",
        Default = not (AA_CONFIG.AutoPlay and AA_CONFIG.AutoPlay.AutoUpgrade == false),
        Callback = function() AutoSaveUserConfig() end
    })

    Tabs.AI:AddInput("UpgradeFirstUnit", {
        Title = "Upgrade First (ชื่อยูนิตที่เน้นอัปเกรดก่อน เช่น Carrot)",
        Default = tostring((AA_CONFIG.AutoPlay and AA_CONFIG.AutoPlay.UpgradeFirstUnit) or ""),
        Placeholder = "เว้นว่างไว้หากไม่เจาะจง",
        Finished = false,
        Callback = function() AutoSaveUserConfig() end
    })

    Tabs.AI:AddDropdown("UpgradeOrder", {
        Title = "Upgrade Order (ลำดับการอัปเกรด)",
        Values = {"Cheapest first", "Farms first", "Strongest first"},
        Default = (function()
            local v = AA_CONFIG.AutoPlay and AA_CONFIG.AutoPlay.UpgradeOrder
            if v == "Farms first" then return 2 elseif v == "Strongest first" then return 3 end
            return 1
        end)(),
        Multi = false,
        Callback = function() AutoSaveUserConfig() end
    })

    Tabs.Settings:AddButton({
        Title = "Refresh placement scan (สแกนพื้นและเนินใหม่)",
        Description = "สแกนชนิดพื้น/เนินและจุดวางใหม่ โดยไม่วาดเส้นแดงและไม่ลบ _road",
        Callback = function()
            task.spawn(function()
                pcall(ScanTerrainHillParts)
                pcall(BuildMainRoadPathFromWorkspace, true)
                pcall(RenderVisualRoadPath)
                if Options.AutoRemoveRoadAfterLine and Options.AutoRemoveRoadAfterLine.Value then
                    ProcessAndRemoveMonsterRoad()
                end
                surfaceSlotsDirty = true
                pcall(CalculateTightInterceptCluster)
                pcall(RenderMiniClusterDots)
                Fluent:Notify({
                    Title = "Placement Scan",
                    Content = "สแกนพื้น/เนินและจุด MiniDot ใหม่แล้ว; เก็บเส้นแดงจำลองไว้และลบชิ้นส่วนถนนจริงฝั่งเครื่อง",
                    Duration = 3
                })
            end)
        end
    })

    local function IsCurrentlyInInfiniteMode()
        local gameData = Workspace:FindFirstChild("_DATA") and Workspace._DATA:FindFirstChild("GameData")
        if gameData then
            local lvlObj = gameData:FindFirstChild("level") or gameData:FindFirstChild("Level")
            if lvlObj and tostring(lvlObj.Value):lower():find("infinite") then
                return true
            end
        end
        return KaitanConfig.PassedNamek and KaitanConfig.PassedWalledCity
    end

    task.spawn(function()
        local groundAttemptIdx = 1
        local hillAttemptIdx = 1

        while true do
            task.wait(0.55)
            local is_ingame = Workspace:FindFirstChild("_UNITS") ~= nil

            if is_ingame then
                local roadRoot = Workspace:FindFirstChild("_road") or Workspace:FindFirstChild("road")
                local groundFolder = roadRoot and roadRoot:FindFirstChild("ground")
                local groundCount = groundFolder and #groundFolder:GetChildren() or 0
                local basesFolder = Workspace:FindFirstChild("_BASES") or Workspace:FindFirstChild("Bases")
                local pveFolder = basesFolder and (basesFolder:FindFirstChild("pve") or basesFolder:FindFirstChild("PVE"))
                local lanesFolder = pveFolder and (pveFolder:FindFirstChild("LANES") or pveFolder:FindFirstChild("lanes"))
                local laneCount = lanesFolder and #lanesFolder:GetChildren() or 0
                local canBuildFromLanes = laneCount > 0
                local canBuildFromRoad = groundFolder and groundCount >= 20
                local canBuild = canBuildFromLanes or canBuildFromRoad
                local buildToken = canBuildFromLanes and (100000 + laneCount) or groundCount

                if canBuild and not State.RoadWasRemoved then
                    if State.RoadBuildPendingCount == buildToken then
                        State.RoadBuildStableTicks = State.RoadBuildStableTicks + 1
                    else
                        State.RoadBuildPendingCount = buildToken
                        State.RoadBuildStableTicks = 0
                    end

                    local isLaneRoute = tostring(State.ActiveRoadLabel):find("_BASES.pve.LANES", 1, true) ~= nil
                    local needsBuild = (not State.RoadPathBuilt)
                        or (canBuildFromLanes and (not isLaneRoute or State.RoadLaneChildCount ~= laneCount))
                        or (not canBuildFromLanes and groundCount ~= State.RoadGroundChildCount)
                    if needsBuild and State.RoadBuildStableTicks >= 1 and (os.clock() - State.RoadBuildLastAttempt) >= 0.65 then
                        State.RoadBuildLastAttempt = os.clock()
                        local buildOk, buildErr = pcall(function()
                            BuildMainRoadPathFromWorkspace(true)
                        end)
                        if not buildOk then
                            warn("[Kaitan RoadPath] Build failed: " .. tostring(buildErr))
                        end
                        surfaceSlotsDirty = true
                        pcall(RenderVisualRoadPath)
                        State.RoadGroundChildCount = groundCount
                        State.RoadLaneChildCount = laneCount
                        State.RoadPathBuilt = (#State.MainRoadSegments > 0)
                        local removeOption = Options.AutoRemoveRoadAfterLine
                        if State.RoadPathBuilt and (not removeOption or removeOption.Value ~= false) then
                            if ProcessAndRemoveMonsterRoad() then
                                -- Road hitboxes are now gone; rebuild all ground/hill slots
                                -- against the exposed surfaces while preserving the route data.
                                surfaceSlotsDirty = true
                                lastSurfaceScanAt = 0
                                pcall(CalculateTightInterceptCluster)
                            end
                        end
                    end
                end

                -- Keep one route selected from the actual Workspace._road geometry.
                -- Enemy proximity can be used as diagnostic evidence, but must not replace
                -- the road-derived path with a nearby false branch after the wave starts.

                pcall(RenderMiniClusterDots)

                -- Do not silently suppress Auto Play on infinite maps. The user-controlled
                -- AutoPlayEnabled toggle is the source of truth; Kaitan mode may still run it.
                if not getgenv().TD_QuickManualPlacementBoot and (not ManualOverlapState.Enabled) and ((Options.AutoPlayEnabled and Options.AutoPlayEnabled.Value) or (KaitanConfig.EnableKaitanMode and not (KaitanConfig.PassedNamek and KaitanConfig.PassedWalledCity))) then
                    if surfaceSlotsDirty or ((#State.ClusterSlots.Ground == 0 or #State.ClusterSlots.Hill == 0)
                        and (os.clock() - lastSurfaceScanAt) >= 4.0) then
                        pcall(CalculateTightInterceptCluster)
                    end

                    local equippedList = GetEquippedUnitsDetailed()
                    local spacingVal = math.clamp(tonumber(Options.ClusterSpacing and Options.ClusterSpacing.Value) or 0.35, 0.15, 1.5)
                    local overlapCheckRadius = math.max(1.8, spacingVal * 1.15)

                    local allUnitsFullyPlaced = true
                    local totalPlacedAll = 0
                    local totalTargetAll = 0

                    for _, unitInfo in ipairs(equippedList) do
                        local targetCap = GetUnitPlacementCap(unitInfo)
                        local placedCount = CountMyPlacedUnitsByIdOrUUID(unitInfo.unit_id, unitInfo.uuid)
                        totalPlacedAll = totalPlacedAll + math.min(placedCount, targetCap)
                        totalTargetAll = totalTargetAll + targetCap

                        if placedCount < targetCap then
                            allUnitsFullyPlaced = false
                            local deployCost = LookupUnitCostByIdOrName(unitInfo.unit_id, unitInfo.unit_name, 0) or 400

                            if GetPlayerCash() >= deployCost then
                                local pType = unitInfo.placement_type
                                local slotList = (pType == "Hill") and State.ClusterSlots.Hill or State.ClusterSlots.Ground
                                if #slotList == 0 then
                                    local alternativeType = (pType == "Hill") and "Ground" or "Hill"
                                    local alternativeSlots = State.ClusterSlots[alternativeType] or {}
                                    if #alternativeSlots > 0 then
                                        pType = alternativeType
                                        slotList = alternativeSlots
                                        State.UnitPlacementOverrides[unitInfo.uuid] = pType
                                        State.UnitPlacementOverrideConfirmed[unitInfo.uuid] = false
                                    end
                                end

                                if #slotList > 0 and unitInfo.uuid then
                                    for tryOffset = 0, math.min(#slotList - 1, 8) do
                                        local idx = (pType == "Hill")
                                            and (((hillAttemptIdx - 1 + tryOffset) % #slotList) + 1)
                                            or (((groundAttemptIdx - 1 + tryOffset) % #slotList) + 1)
                                        local candidatePos = slotList[idx]

                                        do -- Allow tightly packed/overlapping unit placement; server placement validation still applies.
                                            SafeUpdateParagraph(
                                                AIStatusPara,
                                                string.format("📦 เฟส 1: กำลังวางกระจุกบนทางเดิน (%d/%d)", totalPlacedAll, totalTargetAll),
                                                string.format("วาง: %s [%s] จุดที่ #%d | เงิน: %d¥", tostring(unitInfo.unit_name), tostring(pType), idx, deployCost)
                                            )
                                            -- The original working placement path used BuildPlacementCFrame
                                            -- for both unit classes. Hill candidates are already sampled on
                                            -- _terrain.hill, so do not apply a second, competing hill snap.
                                            local placementCF = BuildPlacementCFrame(candidatePos)
                                            if not placementCF then
                                                RememberRejectedSlot(pType == "Hill" and "Hill" or "Ground", candidatePos)
                                                table.remove(slotList, idx)
                                                SafeUpdateParagraph(
                                                    AIStatusPara,
                                                    "⛔ ข้ามจุดที่ไม่มีผิววางจริง",
                                                    string.format("%s: ไม่พบพื้นผิวที่ยืนยันได้ จึงตัดจุดนี้ออก", tostring(pType))
                                                )
                                                break
                                            end

                                            InvokeServer("spawn_unit", unitInfo.uuid, placementCF)
                                            local accepted = false
                                            -- Validate against the game's actual result. Geometric dots alone
                                            -- cannot guarantee that the server permits placement at that location.
                                            for _ = 1, 6 do
                                                task.wait(0.2)
                                                local nowCount = CountMyPlacedUnitsByIdOrUUID(unitInfo.unit_id, unitInfo.uuid)
                                                if nowCount > placedCount then
                                                    accepted = true
                                                    break
                                                end
                                            end

                                            if accepted then
                                                -- Server acceptance is definitive for this unit instance.
                                                State.UnitPlacementOverrides[unitInfo.uuid] = pType
                                                State.UnitPlacementOverrideConfirmed[unitInfo.uuid] = true
                                                State.UnitPlacementProbe[unitInfo.uuid] = nil
                                                if pType == "Hill" then
                                                    hillAttemptIdx = idx + 1
                                                else
                                                    groundAttemptIdx = idx + 1
                                                end
                                            else
                                                RememberRejectedSlot(pType == "Hill" and "Hill" or "Ground", candidatePos)
                                                table.remove(slotList, idx)
                                                if pType == "Hill" then
                                                    hillAttemptIdx = math.max(1, math.min(idx, #slotList))
                                                else
                                                    groundAttemptIdx = math.max(1, math.min(idx, #slotList))
                                                end

                                                -- If game data did not expose a reliable placement type, learn it by
                                                -- testing the other surface after a small batch of rejected points.
                                                -- This is generic for every unit ID/name and never marks a failed type as valid.
                                                local probe = State.UnitPlacementProbe[unitInfo.uuid]
                                                if not probe then
                                                    probe = { active = pType, consecutiveFailures = 0 }
                                                    State.UnitPlacementProbe[unitInfo.uuid] = probe
                                                end
                                                if probe.active ~= pType then
                                                    probe.active = pType
                                                    probe.consecutiveFailures = 0
                                                end
                                                probe.consecutiveFailures = probe.consecutiveFailures + 1
                                                if probe.consecutiveFailures >= 3 then
                                                    local alternativeType = (pType == "Hill") and "Ground" or "Hill"
                                                    local alternativeSlots = State.ClusterSlots[alternativeType] or {}
                                                    if #alternativeSlots > 0 then
                                                        State.UnitPlacementOverrides[unitInfo.uuid] = alternativeType
                                                        State.UnitPlacementOverrideConfirmed[unitInfo.uuid] = false
                                                        probe.active = alternativeType
                                                        probe.consecutiveFailures = 0
                                                        SafeUpdateParagraph(
                                                            AIStatusPara,
                                                            "🔎 ตรวจชนิดพื้นที่วางอัตโนมัติ",
                                                            string.format("%s: จุด %s ถูกปฏิเสธ 3 ครั้ง จึงลองพื้นที่ %s แทน", tostring(unitInfo.unit_name), tostring(pType), tostring(alternativeType))
                                                        )
                                                    else
                                                        probe.consecutiveFailures = 0
                                                    end
                                                end

                                                SafeUpdateParagraph(
                                                    AIStatusPara,
                                                    "⛔ เกมปฏิเสธตำแหน่ง — ตัดออก",
                                                    string.format("%s จุดนี้ไม่เกิดยูนิตหลังส่งคำสั่ง จึงไม่ลองซ้ำ", tostring(pType))
                                                )
                                            end
                                            break
                                        end
                                    end
                                    break
                                end
                            else
                                SafeUpdateParagraph(
                                    AIStatusPara,
                                    string.format("⏳ เฟส 1: รอเงินวางยูนิตในกระจุก (%d/%d)", totalPlacedAll, totalTargetAll),
                                    string.format("รอวาง: %s | ต้องการ: %d¥ (มี: %d¥)", tostring(unitInfo.unit_name), deployCost, GetPlayerCash())
                                )
                                break
                            end
                        end
                    end

                    if allUnitsFullyPlaced and #equippedList > 0 and (Options.AutoUpgradeEnabled and Options.AutoUpgradeEnabled.Value) then
                        local unitsFolder = Workspace:FindFirstChild("_UNITS")
                        if unitsFolder then
                            local myPlacedUnits = {}
                            local priorityFilter = tostring(Options.UpgradeFirstUnit and Options.UpgradeFirstUnit.Value or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
                            local upgradeOrder = (Options.UpgradeOrder and Options.UpgradeOrder.Value) or "Cheapest first"

                            for _, u in ipairs(unitsFolder:GetChildren()) do
                                local st = u:FindFirstChild("_stats")
                                if st and st:FindFirstChild("player") and st.player.Value == LocalPlayer then
                                    local upgLvl = (st:FindFirstChild("upgrade") and tonumber(st.upgrade.Value)) or 0
                                    local idVal = st:FindFirstChild("id") and tostring(st.id.Value) or u.Name
                                    local uEntry = LookupUnitDataEntry(idVal, u.Name)
                                    local maxUpg = (uEntry and uEntry.upgrade and #uEntry.upgrade) or 10

                                    local rawCost = st:FindFirstChild("upgrade_cost") and tonumber(st.upgrade_cost.Value)
                                    local upgCost = (rawCost and rawCost > 0 and rawCost) or LookupUnitCostByIdOrName(idVal, u.Name, upgLvl + 1) or 0

                                    if upgLvl < maxUpg and upgCost > 0 and upgCost < 9999999 then
                                        local dispName = (uEntry and uEntry.name and tostring(uEntry.name)) or idVal
                                        local pType = ClassifyUnitPlacementType(idVal, dispName)
                                        local baseDmg = tonumber(uEntry and (uEntry.damage or uEntry.Damage or uEntry.atk)) or 10
                                        local curDmg = baseDmg * (1 + upgLvl * 0.35)
                                        local isPriority = (priorityFilter ~= "") and (idVal:lower():find(priorityFilter, 1, true) or dispName:lower():find(priorityFilter, 1, true))

                                        table.insert(myPlacedUnits, {
                                            instance = u,
                                            name = dispName,
                                            cost = upgCost,
                                            level = upgLvl,
                                            isFarm = (pType == "Farm"),
                                            damage = curDmg,
                                            isPriority = isPriority
                                        })
                                    end
                                end
                            end

                            table.sort(myPlacedUnits, function(a, b)
                                if a.isPriority ~= b.isPriority then return a.isPriority end
                                if upgradeOrder == "Farms first" and a.isFarm ~= b.isFarm then return a.isFarm end
                                if upgradeOrder == "Strongest first" and a.damage ~= b.damage then return a.damage > b.damage end
                                return a.cost < b.cost
                            end)

                            local targetUpg = myPlacedUnits[1]
                            if targetUpg then
                                if GetPlayerCash() >= targetUpg.cost then
                                    SafeUpdateParagraph(
                                        AIStatusPara,
                                        "⬆️ เฟส 2: กำลังอัปเกรดกระจุกยูนิต (" .. upgradeOrder .. ")",
                                        string.format("อัปเกรด: %s (Lv.%d) | ใช้เงิน: %d¥", targetUpg.name, targetUpg.level + 1, targetUpg.cost)
                                    )
                                    InvokeServer("upgrade_unit_ingame", targetUpg.instance)
                                    task.wait(0.3)
                                else
                                    SafeUpdateParagraph(
                                        AIStatusPara,
                                        "⏳ เฟส 2: รอเงินอัปเกรด (" .. upgradeOrder .. ")",
                                        string.format("ถัดไป: %s (Lv.%d) | ใช้เงิน: %d¥ (มี: %d¥)", targetUpg.name, targetUpg.level + 1, targetUpg.cost, GetPlayerCash())
                                    )
                                end
                            else
                                SafeUpdateParagraph(AIStatusPara, "✅ อัปเกรดยูนิตในกระจุกเต็มทุกตัวแล้ว!", "ยูนิตทุกตัวในสนามอัปเกรดถึงระดับสูงสุดแล้ว")
                            end
                        end
                    end
                end
            end
        end
    end)
end

---------------------------------------------------------------------
-- TAB 3 & 4: MACRO & GAME
---------------------------------------------------------------------
do
    local function KaitanSetGameOption(name, value)
        local opt = Options and Options[name]
        if opt and type(opt.SetValue) == "function" then
            pcall(function() opt:SetValue(value) end)
        end
    end

    Tabs.Game:AddToggle("AutoSkip", { Title = "Auto Skip Wave", Default = not (AA_CONFIG.Farm and AA_CONFIG.Farm.AutoSkip == false), Callback = function() AutoSaveUserConfig() end })
    Tabs.Game:AddToggle("AutoReplay", { Title = "Auto Replay", Default = AA_CONFIG.Farm and AA_CONFIG.Farm.AutoReplay == true, Callback = function() AutoSaveUserConfig() end })
    Tabs.Game:AddToggle("AutoNext", { Title = "Auto Next", Default = AA_CONFIG.Farm and AA_CONFIG.Farm.AutoNext == true, Callback = function() AutoSaveUserConfig() end })
    Tabs.Game:AddToggle("AutoBackToLobby", { Title = "Auto Back to Lobby", Default = AA_CONFIG.Farm and AA_CONFIG.Farm.AutoBackToLobby == true, Callback = function() AutoSaveUserConfig() end })

    local function RecordMatchCompletionBeforeLeaving()
        -- Trust the actual saved level-completion table. Reaching a wave or finishing a
        -- match alone is not proof that Act 6 was passed.
        for _ = 1, 8 do
            RefreshAndCheckWorldCompletion()
            if KaitanConfig.PassedNamek and KaitanConfig.PassedWalledCity then break end
            task.wait(0.35)
        end
        SaveKaitanConfig()
    end

    task.spawn(function()
        local handledFinishedSession = false
        local sentLoadedSession = false
        local lastSkippedWave = -1
        local lastVoteStartAttempt = 0

        while true do
            task.wait(1.0)
            local is_ingame = Workspace:FindFirstChild("_UNITS") ~= nil

            if not is_ingame then
                State.RoadWasRemoved = false
                State.RoadPathBuilt = false
                State.RoadGroundChildCount = 0
                State.RoadBuildPendingCount = -1
                State.RoadBuildStableTicks = 0
                State.RoadBuildLastAttempt = 0
                if State.RoadVisualFolder then
                    pcall(function()
                        State.RoadVisualFolder:Destroy()
                    end)
                    State.RoadVisualFolder = nil
                end
                handledFinishedSession = false
                sentLoadedSession = false
                lastSkippedWave = -1
                lastVoteStartAttempt = 0
            else
                local wavesStartedFlag = Workspace:FindFirstChild("_waves_started")
                if wavesStartedFlag and wavesStartedFlag.Value == false then
                    -- Notify the server once that this client loaded, then keep voting
                    -- to start at a modest interval until the wave actually begins.
                    if not sentLoadedSession then
                        sentLoadedSession = true
                        task.wait(1.0)
                        pcall(function()
                            InvokeServer("client_loaded_session")
                        end)
                    end

                    if (os.clock() - lastVoteStartAttempt) >= 3.5 then
                        lastVoteStartAttempt = os.clock()
                        pcall(function()
                            InvokeServer("vote_start")
                        end)
                    end
                elseif wavesStartedFlag and wavesStartedFlag.Value == true then
                    lastVoteStartAttempt = 0
                end

                local currentWave = GetCurrentWave()
                local dataFolder = Workspace:FindFirstChild("_DATA")
                local finishedValue = dataFolder and dataFolder:FindFirstChild("GameFinished")
                local finished = finishedValue and finishedValue.Value == true

                if ((Options.AutoSkip and Options.AutoSkip.Value) or KaitanConfig.EnableKaitanMode) and not finished and currentWave > 0 and currentWave ~= lastSkippedWave then
                    lastSkippedWave = currentWave
                    InvokeServer("vote_wave_skip")
                end

                if not finished then
                    handledFinishedSession = false
                elseif not handledFinishedSession then
                    handledFinishedSession = true
                    sentLoadedSession = false
                    lastSkippedWave = -1

                    if KaitanConfig.EnableKaitanMode then
                        local gameData = Workspace:FindFirstChild("_DATA") and Workspace._DATA:FindFirstChild("GameData")
                        local lvlObj = gameData and (gameData:FindFirstChild("level") or gameData:FindFirstChild("Level"))
                        local lvlStr = lvlObj and tostring(lvlObj.Value):lower() or ""
                        local isInfMatch = (lvlStr:find("infinite", 1, true) ~= nil)
                        -- Some game builds expose an internal level ID that does not contain
                        -- the word "infinite". Once both Act 6 worlds are complete, Kaitan mode
                        -- launches Titan / Walled City Infinite only; don't misclassify that
                        -- finished run as an Act 6 match and force a lobby teleport.
                        local farmNamek = tostring(KaitanConfig.FarmTarget or "namek_infinite"):lower() == "namek_infinite"
                        local targetDone = farmNamek and KaitanConfig.PassedNamek
                            or (KaitanConfig.PassedNamek and KaitanConfig.PassedWalledCity)
                        if not isInfMatch and targetDone then
                            isInfMatch = true
                        end

                        if isInfMatch then
                            local gems = GetPlayerGems()
                            local goal = math.max(50, tonumber(KaitanConfig.GemGoal) or 20000)
                            -- Re-assert the configured Infinite placement mode at every result/replay.
                            local autoPlaceInfinite = AA_CONFIG.AutoPlay and AA_CONFIG.AutoPlay.AutoPlaceInInfinite ~= false
                            getgenv().TD_QuickManualPlacementBoot = not autoPlaceInfinite
                            KaitanSetGameOption("ManualOverlapMode", not autoPlaceInfinite)
                            KaitanSetGameOption("AutoPlayEnabled", autoPlaceInfinite and AA_CONFIG.AutoPlay.Enabled ~= false)
                            if gems >= goal then
                                KaitanSetGameOption("AutoSkip", false)
                                KaitanConfig.EnableKaitanMode = false
                                SaveKaitanConfig()
                                KaitanSetGameOption("AutoReplay", false)
                                KaitanSetGameOption("AutoBackToLobby", false)
                                if KaitanStatusUpdater then
                                    pcall(function() KaitanStatusUpdater(string.format("🎯 ถึงเป้าหมายเพชร %d/%d แล้ว กำลังกลับ Lobby และหยุด Replay", gems, goal)) end)
                                end
                                task.wait(1.0)
                                pcall(function() InvokeServer("teleport_back_to_lobby") end)
                            else
                                KaitanSetGameOption("AutoSkip", true)
                                KaitanSetGameOption("AutoReplay", true)
                                KaitanSetGameOption("AutoBackToLobby", false)
                                if KaitanStatusUpdater then
                                    pcall(function() KaitanStatusUpdater(string.format("💎 Infinite จบหนึ่งรอบ | %d/%d เพชร — ตรวจทีมก่อน Replay", gems, goal)) end)
                                end
                                task.wait(1.0)
                                if EnsureEquippedTeamBeforePlay("Titan Replay", nil) then
                                    KaitanSetGameOption("AutoReplay", true)
                                    InvokeServer("set_game_finished_vote", "replay")
                                else
                                    -- A transient inventory/equipped-state read must not cancel Titan farming
                                    -- by sending the player to the lobby. Stay at results, keep replay armed,
                                    -- and let this GameFinished handler retry the team check.
                                    KaitanSetGameOption("AutoReplay", true)
                                    KaitanSetGameOption("AutoBackToLobby", false)
                                    if KaitanStatusUpdater then
                                        pcall(function()
                                            KaitanStatusUpdater("⚠️ ยังตรวจทีมไม่สำเร็จ — คงอยู่หน้าจบเกมและจะตรวจ/ลอง Replay ใหม่ (ไม่ส่งกลับ Lobby)")
                                        end)
                                    end
                                    handledFinishedSession = false
                                    task.wait(3.0)
                                end
                            end
                        else
                            RecordMatchCompletionBeforeLeaving()
                            -- Before returning to lobby, prepare the next phase using the Infinite config.
                            local farmNamek = tostring(KaitanConfig.FarmTarget or "namek_infinite"):lower() == "namek_infinite"
                            if (farmNamek and KaitanConfig.PassedNamek) or (KaitanConfig.PassedNamek and KaitanConfig.PassedWalledCity) then
                                local autoPlaceInfinite = AA_CONFIG.AutoPlay and AA_CONFIG.AutoPlay.AutoPlaceInInfinite ~= false
                                getgenv().TD_QuickManualPlacementBoot = not autoPlaceInfinite
                                KaitanSetGameOption("ManualOverlapMode", not autoPlaceInfinite)
                            end
                            -- During lobby transition Auto Play and Replay are off; KaitanPrepareTitanFarmMode
                            -- applies AutoPlaceInInfinite again when the Infinite match is launched.
                            KaitanSetGameOption("AutoPlayEnabled", false)
                            KaitanSetGameOption("AutoSkip", false)
                            KaitanSetGameOption("AutoReplay", false)
                            KaitanSetGameOption("AutoNext", false)
                            KaitanSetGameOption("AutoBackToLobby", false)
                            task.wait(1.5)
                            InvokeServer("teleport_back_to_lobby")
                        end
                    else
                        if Options.AutoReplay and Options.AutoReplay.Value then
                            task.wait(1)
                            if EnsureEquippedTeamBeforePlay("Auto Replay", nil) then
                                InvokeServer("set_game_finished_vote", "replay")
                            else
                                task.wait(0.75)
                                pcall(function() InvokeServer("teleport_back_to_lobby") end)
                            end
                        elseif Options.AutoNext and Options.AutoNext.Value then
                            task.wait(2)
                            if EnsureEquippedTeamBeforePlay("Auto Next", nil) then
                                InvokeServer("set_game_finished_vote", "next")
                            else
                                task.wait(0.75)
                                pcall(function() InvokeServer("teleport_back_to_lobby") end)
                            end
                        elseif Options.AutoBackToLobby and Options.AutoBackToLobby.Value then
                            task.wait(2)
                            InvokeServer("teleport_back_to_lobby")
                        end
                    end
                end
            end
        end
    end)
end

---------------------------------------------------------------------
-- TAB 5: SETTINGS
---------------------------------------------------------------------
if SaveManager then
    pcall(function()
        SaveManager:SetLibrary(Fluent)
        SaveManager:IgnoreThemeSettings()
        if SaveManager.SetIgnoreIndexes then
            SaveManager:SetIgnoreIndexes({ "EnableKaitanMode" })
        else
            SaveManager.IgnoreIndexes = { "EnableKaitanMode" }
        end
        SaveManager:SetFolder(CONFIG_FOLDER)
        SaveManager:BuildConfigSection(Tabs.Settings)
    end)
end

if InterfaceManager then
    pcall(function()
        InterfaceManager:SetLibrary(Fluent)
        InterfaceManager:SetFolder("FluentScriptHub")
        InterfaceManager:BuildInterfaceSection(Tabs.Settings)
    end)
end

pcall(function()
    Window:SelectTab(1)
end)

pcall(function()
    if SaveManager then
        local activeProfile = KaitanConfig.EnableKaitanMode and (USER_CONFIG_NAME .. "_Kaitan") or USER_CONFIG_NAME
        local userCfgPath = CONFIG_FOLDER .. "/settings/" .. activeProfile .. ".json"
        if typeof(isfile) == "function" and isfile(userCfgPath) then
            SaveManager:Load(activeProfile)
        else
            SaveManager:Save(activeProfile)
        end
    end
end)

-- Older profiles saved this toggle as false when the line renderer was disabled.
-- Restore the requested visible LANES route after loading the old profile.
task.defer(function()
    task.wait(0.25)
    local showRoadOption = Fluent and Fluent.Options and Fluent.Options.ShowRoadPathLines
    if showRoadOption and showRoadOption.Value == false then
        pcall(function() showRoadOption:SetValue(true) end)
    end
    -- Ignore stale profiles that disabled road deletion; retain only the synthetic line.
    local removeRoadOption = Fluent and Fluent.Options and Fluent.Options.AutoRemoveRoadAfterLine
    if removeRoadOption and removeRoadOption.Value == false then
        pcall(function() removeRoadOption:SetValue(true) end)
    end
    pcall(RenderVisualRoadPath)
end)

task.spawn(function()
    task.wait(0.5)
    State.IsBootingConfig = false
end)

Fluent:Notify({
    Title = "TD Script Architect Ready!",
    Content = "โหลดสำเร็จ",
    Duration = 5
})

-- Final startup guard: hide the script panel after all widgets and notifications initialize.
-- RightControl remains the Fluent minimize/restore toggle configured in CreateWindow.
task.delay(1.5, function()
    pcall(function()
        if Window and Window.Root then
            Window.Minimized = true
            Window.Root.Visible = false
        end
    end)
end)
