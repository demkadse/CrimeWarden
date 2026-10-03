-- Simulation für "CrimeWarden": lädt das komplette Addon mit einer nachgebauten
-- WoW-9.2.7-API und Total RP 3 2.3 und spielt Abläufe durch.
-- Ersetzt keinen Test im Spiel, findet aber Laufzeitfehler und Logikfehler.
--   luajit tests/crimewarden_sim.lua     (aus dem Projektordner)

-- Globals, die hier nachgebaut oder vom Addon angelegt werden:
-- luacheck: globals GameTooltip SlashCmdList CrimeWardenDB CrimeWardenFrame RaidWarningFrame WorldMapFrame

-------------------------------------------------------------------------------
-- Nachgebaute WoW-API
-------------------------------------------------------------------------------

local clock = 1000
local inCombat = false
local shiftDown = false
local itemsCached = false
local printed = {}
local eventFrames = {}
local tickers = {}
local calls = {
    tell = {}, openChat = {}, sendQuery = {}, openPage = {}, mainFrame = 0, optionsOpened = 0,
    banners = {}, sounds = 0, itemRequests = 0,
}
local optionsPanels = {}
local ns = {}

-- Methoden, die es erst ab 10.0 gibt und im 9.2.7-Client fehlen müssen.
local MISSING_IN_927 = { SetResizeBounds = true }

local function noop() end

local function MakeObject(kind, name, parent, template)
    local obj = {
        kind = kind, name = name, parent = parent, template = template,
        shown = true, scripts = {}, events = {}, width = 100, height = 100, fontStrings = {},
    }
    local methods = {
        Show = function(self)
            local wasShown = self.shown
            self.shown = true
            if not wasShown and self.scripts.OnShow then self.scripts.OnShow(self) end
        end,
        Hide = function(self) self.shown = false end,
        IsShown = function(self) return self.shown end,
        SetShown = function(self, value) if value then self:Show() else self:Hide() end end,
        SetScript = function(self, script, fn) self.scripts[script] = fn end,
        GetScript = function(self, script) return self.scripts[script] end,
        RegisterEvent = function(self, event) self.events[event] = true; eventFrames[self] = true end,
        UnregisterEvent = function(self, event) self.events[event] = nil end,
        SetSize = function(self, w, h) self.width, self.height = w, h end,
        SetWidth = function(self, w) self.width = w end,
        SetHeight = function(self, h) self.height = h end,
        GetWidth = function(self) return self.width end,
        GetHeight = function(self) return self.height end,
        SetPoint = function(self, point, a, b, c, d)
            self.points = self.points or {}
            local x, y = c, d
            if type(a) == "number" then x, y = a, b end
            self.points[point] = { x = x or 0, y = y or 0 }
            self.firstPoint = self.firstPoint or { point, point, x or 0, y or 0 }
        end,
        ClearAllPoints = function(self) self.points = {}; self.firstPoint = nil end,
        GetPoint = function(self)
            local p = self.firstPoint or { "CENTER", "CENTER", 0, 0 }
            return p[1], nil, p[2], p[3], p[4]
        end,
        SetText = function(self, text) self.text = text end,
        SetTextColor = function(self, r, g, b) self.textColor = { r, g, b } end,
        SetColorTexture = function(self, r, g, b) self.color = { r, g, b } end,
        GetText = function(self) return self.text end,
        SetChecked = function(self, value) self.checked = value end,
        SetEnabled = function(self, value) self.enabled = value end,
        GetChecked = function(self) return self.checked end,
        GetFrameLevel = function() return 1 end,
        GetCenter = function() return 500, 500 end,
        GetEffectiveScale = function() return 1 end,
        SetMinResize = function(self, w, h) self.minResize = { w, h } end,
        SetMaxResize = function(self, w, h) self.maxResize = { w, h } end,
        CreateTexture = function(self) return MakeObject("Texture", nil, self) end,
        CreateFontString = function(self, _, _, fontTemplate)
            local fs = MakeObject("FontString", nil, self, fontTemplate)
            self.fontStrings[#self.fontStrings + 1] = fs
            return fs
        end,
    }
    -- Unbekannte Methoden (in WoW immer mit Großbuchstaben) sind No-ops,
    -- unbekannte Felder bleiben nil.
    return setmetatable(obj, {
        __index = function(_, key)
            if methods[key] then return methods[key] end
            if MISSING_IN_927[key] or not key:match("^%u") then return nil end
            return noop
        end,
    })
end

local allFrames = {}
_G.CreateFrame = function(kind, name, parent, template)
    local frame = MakeObject(kind, name, parent, template)
    allFrames[#allFrames + 1] = frame
    if name then _G[name] = frame end
    return frame
end
_G.UIParent = MakeObject("Frame")
_G.Minimap = MakeObject("Frame")
_G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) printed[#printed + 1] = text end }
_G.SlashCmdList = {}
_G.UNKNOWNOBJECT = "Unbekannt"
_G.RAID_CLASS_COLORS = {
    MAGE = { r = 0.25, g = 0.78, b = 0.92 },
    PALADIN = { r = 0.96, g = 0.55, b = 0.73 },
    ROGUE = { r = 1, g = 0.96, b = 0.41 },
}
_G.GetLocale = function() return "deDE" end
_G.GetTime = function() return clock end
_G.InCombatLockdown = function() return inCombat end
_G.IsShiftKeyDown = function() return shiftDown end
_G.GetCursorPosition = function() return 0, 0 end
_G.GetAddOnMetadata = function(_, field) return field == "Version" and "0.7.2" or nil end
_G.C_Timer = {
    NewTicker = function(interval, fn)
        tickers[#tickers + 1] = { interval = interval, fn = fn }
        return { Cancel = noop }
    end,
}
_G.ChatFrame_SendTell = function(name) calls.tell[#calls.tell + 1] = name end
_G.ChatEdit_GetActiveWindow = function() return nil end
_G.ChatFrame_OpenChat = function(text) calls.openChat[#calls.openChat + 1] = text end
_G.InterfaceOptions_AddCategory = function(panel) optionsPanels[#optionsPanels + 1] = panel end
_G.InterfaceOptionsFrame_OpenToCategory = function(panel)
    assert(panel == optionsPanels[1], "falsches Panel")
    calls.optionsOpened = calls.optionsOpened + 1
end
_G.RaidWarningFrame = MakeObject("Frame")
_G.ChatTypeInfo = { RAID_WARNING = { r = 1, g = 0.28, b = 0 } }
_G.RaidNotice_AddMessage = function(frame, text)
    assert(frame == RaidWarningFrame, "falscher Rahmen")
    calls.banners[#calls.banners + 1] = text
end
_G.SOUNDKIT = { RAID_WARNING = 8959 }
_G.PlaySound = function(id) if id == 8959 then calls.sounds = calls.sounds + 1 end end

local cvars = { nameplateShowFriends = "0", nameplateShowAll = "0", nameplateMaxDistance = "40" }
_G.C_CVar = { GetCVar = function(name) return cvars[name] end }
_G.GetCVar = function(name) return cvars[name] end
_G.SetCVar = function(name, value) cvars[name] = tostring(value) end

-- Einheiten hinter den Namensplaketten. "nameplateX" -> Daten (dist in Metern).
local units = {}
local GameTooltipLines = {}
_G.GameTooltip = MakeObject("GameTooltip")
GameTooltip.SetOwner = function(self, owner) self.owner = owner; GameTooltipLines = {}; self.unit = nil end
GameTooltip.IsOwned = function(self, owner) return self.owner == owner end
GameTooltip.SetUnit = function(self, unit) self.unit = unit end
GameTooltip.AddLine = function(_, text) GameTooltipLines[#GameTooltipLines + 1] = text end
GameTooltip.Hide = function(self) self.owner = nil end

_G.C_NamePlate = {
    GetNamePlates = function()
        local plates = {}
        for token in pairs(units) do
            if token:match("^nameplate") then
                plates[#plates + 1] = { namePlateUnitToken = token } -- 9.x: kein GetUnit()
            end
        end
        return plates
    end,
}
_G.UnitExists = function(unit) return units[unit] ~= nil or unit == "player" end
_G.UnitIsPlayer = function(unit) return units[unit] and units[unit].player or false end
_G.UnitIsUnit = function(a, b) return b == "player" and units[a] and units[a].self or false end
_G.UnitGUID = function(unit) return units[unit] and units[unit].guid end
_G.GetUnitName = function(unit) return units[unit] and units[unit].name end
_G.UnitClass = function(unit) local u = units[unit]; if u then return u.className, u.classFile end end
_G.UnitRace = function(unit) return units[unit] and units[unit].race end
_G.UnitLevel = function(unit) return units[unit] and units[unit].level or 0 end
_G.GetGuildInfo = function(unit) return units[unit] and units[unit].guild end
_G.UnitIsFriend = function(_, unit) return units[unit] and not units[unit].hostile or false end
_G.UnitCanAttack = function(_, unit) return units[unit] and units[unit].hostile or false end
_G.UnitInParty = function(unit) return units[unit] and units[unit].group or false end
_G.UnitInRaid = function() return nil end
_G.CheckInteractDistance = function(unit, index)
    local u = units[unit]
    if not u then return false end
    if index == 3 then return u.dist <= 10 end
    if index == 4 then return u.dist <= 28 end
    return false
end

-- IsItemInRange: Reichweite jedes Gegenstands aus der Liste des Addons. Ohne
-- geladene Gegenstandsdaten liefert das Spiel nil.
local itemYards
_G.C_Item = { RequestLoadItemDataByID = function() calls.itemRequests = calls.itemRequests + 1; itemsCached = true end }
_G.IsItemInRange = function(item, unit)
    if not itemsCached then return nil end
    if not itemYards then
        itemYards = {}
        for _, lists in ipairs({ ns.Range.FRIEND, ns.Range.HARM }) do
            for yards, items in pairs(lists) do
                for _, id in ipairs(items) do
                    assert(itemYards[id] == nil or itemYards[id] == yards, "Gegenstand mit zwei Reichweiten: " .. id)
                    itemYards[id] = yards
                end
            end
        end
    end
    local u = units[unit]
    if not u or not itemYards[item] then return nil end
    return u.dist <= itemYards[item]
end

-- Gruppe: party1..4 mit Weltposition (UnitPosition liefert y, x, z, Instanz).
local groupSize = 0
local inInstance = false
local playerWorld = { x = 500, y = 500 }
_G.IsInRaid = function() return false end
_G.GetNumGroupMembers = function() return groupSize > 0 and groupSize + 1 or 0 end
_G.GetNumSubgroupMembers = function() return groupSize end
_G.UnitIsConnected = function(unit) return units[unit] ~= nil end
_G.UnitIsVisible = function(unit) return units[unit] ~= nil and units[unit].dist <= 100 end
_G.UnitPosition = function(unit)
    if inInstance then return nil end
    if unit == "player" then return playerWorld.y, playerWorld.x, 0, 0 end
    local u = units[unit]
    if not u or not u.world then return nil end
    return u.world.y, u.world.x, 0, 0
end

-- Karte: Karte 1 ist 1000 x 1000 Meter, Ursprung bei Welt (0, 0).
local function Vector(x, y)
    return { x = x, y = y, GetXY = function(self) return self.x, self.y end }
end
_G.CreateVector2D = Vector
_G.C_Map = {
    GetBestMapForUnit = function() return (not inInstance) and 1 or nil end,
    GetPlayerMapPosition = function(mapID)
        if inInstance or mapID ~= 1 then return nil end
        return Vector(playerWorld.x / 1000, playerWorld.y / 1000)
    end,
    GetWorldPosFromMapPos = function(mapID, position)
        if mapID ~= 1 then return nil end
        return 7, Vector(position.x * 1000, position.y * 1000)
    end,
}
_G.GetNormalizedRealmName = function() return "Testrealm" end
_G.Ambiguate = function(name) return (name:gsub("%-Testrealm$", "")) end
local playerInfo = {}
_G.GetPlayerInfoByGUID = function(guid)
    local info = playerInfo[guid]
    if info then return info.className, info.classFile, info.race end
end
_G.hooksecurefunc = function(tbl, key, hook)
    local original = tbl[key]
    tbl[key] = function(...) local result = original(...); hook(...); return result end
end

-- Kampflog
local combatEvent = {}
_G.CombatLogGetCurrentEventInfo = function() return unpack(combatEvent, 1, 11) end
_G.COMBATLOG_OBJECT_TYPE_PLAYER = 0x400
_G.COMBATLOG_OBJECT_AFFILIATION_MINE = 0x1
_G.COMBATLOG_OBJECT_REACTION_HOSTILE = 0x40

-- Weltkarte: zeigt Karte displayedMap (1 = Nordhafen, 2 = Vorland).
local displayedMap = 1
_G.WorldMapFrame = MakeObject("Frame")
WorldMapFrame.shown = false
WorldMapFrame.GetMapID = function() return displayedMap end
WorldMapFrame.hooks = {}
WorldMapFrame.HookScript = function(self, script, fn) self.hooks[script] = fn end
-- Karte schließen wie im Spiel: erst unsichtbar, dann OnHide.
local function CloseMap()
    WorldMapFrame.shown = false
    if WorldMapFrame.hooks.OnHide then WorldMapFrame.hooks.OnHide(WorldMapFrame) end
end

-- TRP3s eigener Kartenscanner (playerScan), wie in TRP3 2.3: Er übernimmt jede
-- Ortungsantwort in seine Liste, leert sie beim Start eines Kartenscans und
-- zeigt nach 3 s an, was gesammelt wurde.
local trp3Scanner = { duration = 3, data = {} }
function trp3Scanner:ResetScanData() self.data = {} end
function trp3Scanner:OnScanDataReceived(sender, x, y) self.data[#self.data + 1] = { sender = sender, x = x, y = y } end
calls.trp3Scans = {}
local trp3MapScanners = {
    launch = function(scanID)
        assert(scanID == "playerScan", "unbekannter Scan")
        trp3Scanner:ResetScanData()
        calls.trp3Scans[#calls.trp3Scans + 1] = { mapID = WorldMapFrame:GetMapID(), at = clock }
    end,
    getByID = function(id)
        if id == "playerScan" then return trp3Scanner end
    end,
}

-- TRP3-Ortungskanal: Anfragen mitschreiben, Antworten an registrierte Handler.
-- TRP3s eigener Empfänger ist zuerst angemeldet (TRP3 lädt vor CrimeWarden).
local p2pHandlers = {
    C_SCAN = { function(sender, x, y) trp3Scanner:OnScanDataReceived(sender, tonumber(x), tonumber(y)) end },
}
calls.scans = {}
_G.AddOn_TotalRP3 = {
    Communications = {
        broadcast = {
            broadcast = function(command, mapID)
                calls.scans[#calls.scans + 1] = { command = command, mapID = mapID, at = clock }
            end,
            registerP2PCommand = function(command, handler)
                p2pHandlers[command] = p2pHandlers[command] or {}
                table.insert(p2pHandlers[command], handler)
            end,
        },
    },
}
local function Answer(sender, x, y)
    for _, handler in ipairs(p2pHandlers.C_SCAN or {}) do handler(sender, tostring(x), tostring(y), "true") end
end

-- Total RP 3 2.3.13, so wie es auf dem Server installiert ist.
local trp3Loaded = true
_G.IsAddOnLoaded = function(name) return name == "totalRP3" and trp3Loaded end
local trp3Characters = {
    ["Aria-Testrealm"] = { profileID = "P1", FN = "Lady Aria", RP = 1 },
}
local function MakeTRP3()
    return {
        utils = { str = { getUnitID = function(unit)
            local u = units[unit]
            if not u then return nil end
            return u.name:find("-") and u.name or (u.name .. "-Testrealm")
        end } },
        register = {
            isUnitIDKnown = function(id) assert(id, "Nil unitID"); return trp3Characters[id] ~= nil end,
            hasProfile = function(id) assert(trp3Characters[id], "Unknown character"); return trp3Characters[id].profileID end,
            getUnitRPNameWithID = function(id, name)
                local c = trp3Characters[id]
                return c and c.FN and ("|cffffcc00" .. c.FN .. "|r") or name
            end,
            getUnitIDCurrentProfileSafe = function(id)
                local c = trp3Characters[id]
                return c and { character = { RP = c.RP } } or {}
            end,
            openPageByUnitID = function(id) calls.openPage[#calls.openPage + 1] = id end,
        },
        r = { sendQuery = function(id) calls.sendQuery[#calls.sendQuery + 1] = id end },
        navigation = { openMainFrame = function() calls.mainFrame = calls.mainFrame + 1 end },
        MapScannersManager = trp3MapScanners,
    }
end
_G.TRP3_API = MakeTRP3()

-------------------------------------------------------------------------------
-- Addon laden
-------------------------------------------------------------------------------

local loadErrors = {}
for line in io.lines("CrimeWarden/CrimeWarden.toc") do
    line = line:gsub("\r", "")
    if line ~= "" and not line:match("^#") then
        local chunk, err = loadfile("CrimeWarden/" .. line:gsub("\\", "/"))
        if not chunk then
            loadErrors[#loadErrors + 1] = err
        else
            local ok, runErr = pcall(chunk, "CrimeWarden", ns)
            if not ok then loadErrors[#loadErrors + 1] = line .. ": " .. tostring(runErr) end
        end
    end
end

local function Fire(event, ...)
    for frame in pairs(eventFrames) do
        if frame.events[event] and frame.scripts.OnEvent then
            frame.scripts.OnEvent(frame, event, ...)
        end
    end
end

local function RunTickers(interval)
    for _, ticker in ipairs(tickers) do
        if ticker.interval == interval then ticker.fn() end
    end
end

-- Scanner-Takt (1 s): Liste, Entfernungen, TRP3.
local function Tick(seconds)
    clock = clock + (seconds or 1)
    RunTickers(1)
end

-- Warn-Takt (0,2 s).
local function FastTick()
    clock = clock + 0.2
    RunTickers(0.2)
end

local function Slash(text)
    SlashCmdList.CRIMEWARDEN(text)
end

local function AddPlate(token, data)
    units[token] = data
    Fire("NAME_PLATE_UNIT_ADDED", token)
end

local function RemovePlate(token)
    Fire("NAME_PLATE_UNIT_REMOVED", token)
    units[token] = nil
end

-- Sichtbare Zeilen von oben nach unten.
local function VisibleRows()
    local list = {}
    for _, frame in ipairs(allFrames) do
        if frame.info and frame.distance and frame.status and frame.shown and frame.entry then
            list[#list + 1] = frame
        end
    end
    table.sort(list, function(a, b) return a.points.TOPLEFT.y > b.points.TOPLEFT.y end)
    return list
end

local function RowOf(guid)
    for _, row in ipairs(VisibleRows()) do
        if row.entry.guid == guid then return row end
    end
end

-- Die beiden Hälften (Just, Unjust) des Modusschalters unter `owner`.
local function ModeHalves(owner)
    local just, unjust
    for _, frame in ipairs(allFrames) do
        if frame.info and frame.parent and frame.parent.parent == owner and frame.label then
            if frame.info.unjust then unjust = frame else just = frame end
        end
    end
    return just, unjust
end

local function IsGrey(color) return color and math.abs(color[1] - color[2]) < 0.05 and math.abs(color[2] - color[3]) < 0.05 end
local function IsGreen(color) return color and color[2] > color[1] * 2 end
local function IsRed(color) return color and color[1] > color[2] * 2 end

local function LastPrint()
    return printed[#printed] or ""
end

local passed, failed = 0, 0
local function Check(name, condition, detail)
    if condition then
        passed = passed + 1
    else
        failed = failed + 1
        print("FEHLER  " .. name .. (detail ~= nil and ("\n        " .. tostring(detail)) or ""))
    end
end

local function Scenario(name, fn)
    local ok, err = xpcall(fn, debug.traceback)
    if not ok then
        failed = failed + 1
        print("ABBRUCH " .. name .. "\n" .. tostring(err))
    end
end

-------------------------------------------------------------------------------
-- Abläufe
-------------------------------------------------------------------------------

-- Kaputte gespeicherte Einstellungen werden repariert.
_G.CrimeWardenDB = { window = "kaputt", sortBy = 5, minimap = { angle = "x" }, radius = 33, warning = { yards = 17 } }

Scenario("Laden und Initialisieren", function()
    Check("Alle Dateien laden", #loadErrors == 0, loadErrors[1])
    Fire("ADDON_LOADED", "totalRP3")
    Fire("ADDON_LOADED", "CrimeWarden")
    Check("Ladenachricht", LastPrint():find("Version 0.7.2 geladen"), LastPrint())
    Check("DB repariert: window", type(CrimeWardenDB.window) == "table" and CrimeWardenDB.window.width == 340)
    Check("DB repariert: sortBy", CrimeWardenDB.sortBy == "distance")
    Check("DB repariert: minimap.angle", CrimeWardenDB.minimap.angle == 200)
    Check("DB: Umkreis auf Stufe gerundet", CrimeWardenDB.radius == 30, CrimeWardenDB.radius)
    Check("DB: Warngrenze auf Stufe gerundet", CrimeWardenDB.warning.yards == 15, CrimeWardenDB.warning.yards)
    Check("DB: fehlende Warn-Optionen ergänzt", CrimeWardenDB.warning.enabled == true and CrimeWardenDB.warning.sound == true)
    Check("Gegenstandsdaten angefordert", calls.itemRequests > 0)
    Check("Fenster sichtbar", ns.UI:IsShown())
    Check("Resize-Grenzen über 9.x-API", CrimeWardenFrame.minResize and CrimeWardenFrame.maxResize)
    Check("Minimap-Button", _G.CrimeWardenMinimapButton ~= nil)
    Check("Einstellungsseite registriert", #optionsPanels == 1)
    Check("Zwei Ticker (1 s und 0,2 s)", #tickers == 2)
    Check("Standard: Modus Unjust", CrimeWardenDB.warning.enabled == true)
    Check("Standard: Warnung ab 50 m, Hörweite 30 m", ns.defaults.warning.yards == 50
        and ns.defaults.sayRange == 30 and CrimeWardenDB.sayRange == 30)
    Check("Standard: alle Quellen an", CrimeWardenDB.sources.group and CrimeWardenDB.sources.locator
        and CrimeWardenDB.sources.senses and CrimeWardenDB.sources.locatorInterval == 10)
    CrimeWardenDB.radius = 50
end)

local title = CrimeWardenFrame and CrimeWardenFrame.fontStrings[1]
local emptyText
for _, fs in ipairs(CrimeWardenFrame and CrimeWardenFrame.fontStrings or {}) do
    if fs.template == "GameFontDisable" then emptyText = fs end
end

Scenario("Hinweis bei ausgeschalteten Namensplaketten", function()
    Check("Titel ohne Spieler", title.text == "CrimeWarden (0)", title.text)
    Check("Hinweistext Plaketten aus", emptyText.shown and emptyText.text:find("Namensplaketten sind aus"), emptyText.text)
    inCombat = true
    Slash("plaketten")
    Check("Im Kampf abgelehnt", cvars.nameplateShowFriends == "0" and LastPrint():find("Im Kampf"), LastPrint())
    inCombat = false
    Slash("plaketten")
    Check("CVars gesetzt", cvars.nameplateShowFriends == "1" and cvars.nameplateShowAll == "1")
    Check("Plaketten-Sichtweite auf Umkreis angehoben", cvars.nameplateMaxDistance == "50", cvars.nameplateMaxDistance)
    Check("Hinweistext jetzt 'Niemand'", emptyText.text:find("Niemand in Sichtweite"), emptyText.text)
end)

Scenario("Spieler kommen in Sichtweite", function()
    AddPlate("nameplate1", { player = true, guid = "G-ARIA", name = "Aria", className = "Magierin", classFile = "MAGE",
        race = "Blutelfe", level = 60, guild = "Die Wache", dist = 25 })
    AddPlate("nameplate2", { player = true, guid = "G-BERN", name = "Bern", className = "Schurke", classFile = "ROGUE",
        race = "Untoter", level = 58, dist = 5 })
    AddPlate("nameplate3", { player = true, guid = "G-FEIND", name = "Feindus-Andererealm", className = "Paladin",
        classFile = "PALADIN", race = "Mensch", level = -1, dist = 48, hostile = true })
    AddPlate("nameplate4", { player = true, self = true, guid = "G-ICH", name = "Ich", dist = 0 }) -- eigene Plakette
    AddPlate("nameplate5", { player = false, guid = "NPC-1", name = "Wache", dist = 3 }) -- NPC
    AddPlate("nameplate6", { player = true, guid = "G-WEIT", name = "Weitweg", dist = 55 }) -- außerhalb 50 m

    Check("Vier Spieler erfasst", ns.rosters.plate:Count() == 4, ns.rosters.plate:Count())
    Check("Titel zählt nur den Umkreis", title.text == "CrimeWarden (3)", title.text)
    Check("Leertext versteckt", not emptyText.shown)

    local rows = VisibleRows()
    Check("Drei Zeilen", #rows == 3, #rows)
    Check("Sortiert: Bern (nah) zuerst", rows[1].name.text == "Bern", rows[1].name.text)
    Check("Bern bei Erscheinen schon in 15 m: gewarnt", #calls.banners == 1 and calls.banners[1]:find("Bern"),
        calls.banners[1])
    Check("Bern rot markiert, bis 5 m", rows[1].distance.text == "! bis 5 m", rows[1].distance.text)
    Check("Aria zweite Zeile mit RP-Name", rows[2].name.text == "Lady Aria", rows[2].name.text)
    Check("Aria: IC", rows[2].status.text == "IC")
    Check("Aria: bis 25 m", rows[2].distance.text == "bis 25 m", rows[2].distance.text)
    local info = rows[2].info.text
    Check("Aria Infozeile", info:find("Aria") and info:find("Stufe 60 Blutelfe Magierin") and info:find("<Die Wache>"), info)
    Check("Feind gemessen über Feind-Gegenstände", rows[3].distance.text == "bis 50 m", rows[3].distance.text)
    Check("Feind markiert, Stufe ??", rows[3].info.text:find("feindlich") and rows[3].info.text:find("Stufe ??"),
        rows[3].info.text)
    Slash("umkreis 60")
    Check("/warden umkreis 60 zeigt auch Weitweg", title.text == "CrimeWarden (4)", title.text)
    Slash("umkreis 50")
end)

Scenario("Annäherungswarnung", function()
    local banners, sounds = #calls.banners, calls.sounds
    AddPlate("nameplate7", { player = true, guid = "G-GERD", name = "Gerd", dist = 40, level = 60 })
    FastTick()
    Check("Bei 40 m keine Warnung", #calls.banners == banners)
    units.nameplate7.dist = 20
    FastTick()
    Check("Bei 20 m keine Warnung", #calls.banners == banners)
    units.nameplate7.dist = 14
    FastTick()
    Check("Bei 14 m Warnung (Banner)", #calls.banners == banners + 1 and calls.banners[#calls.banners]:find("Gerd ist näher als 15 m"),
        calls.banners[#calls.banners])
    Check("Warnton", calls.sounds == sounds + 1)
    Check("Chatzeile", LastPrint():find("Gerd ist näher als 15 m"), LastPrint())
    units.nameplate7.dist = 10
    FastTick()
    FastTick()
    Check("Bleibt drin: keine weitere Warnung", #calls.banners == banners + 1)
    units.nameplate7.dist = 18
    FastTick()
    units.nameplate7.dist = 12
    FastTick()
    Check("Pendeln an der Grenze (15-20 m): keine Warnung", #calls.banners == banners + 1)
    units.nameplate7.dist = 25
    FastTick()
    units.nameplate7.dist = 13
    FastTick()
    Check("Raus über 20 m und wieder rein: erneute Warnung", #calls.banners == banners + 2)

    -- Kamera gedreht: Plakette weg und wieder da, Gerd steht weiter nah
    RemovePlate("nameplate7")
    clock = clock + 10
    AddPlate("nameplate7", { player = true, guid = "G-GERD", name = "Gerd", dist = 13, level = 60 })
    FastTick()
    Check("Kameradrehen löst keine neue Warnung aus", #calls.banners == banners + 2)

    -- Gruppenmitglied
    AddPlate("nameplate8", { player = true, guid = "G-FREUND", name = "Freund", dist = 40, group = true })
    units.nameplate8.dist = 5
    FastTick()
    Check("Gruppenmitglieder werden ignoriert", #calls.banners == banners + 2)
    RemovePlate("nameplate8")
end)

Scenario("Warnung einstellen", function()
    local banners = #calls.banners
    Slash("just")
    Check("/warden just", CrimeWardenDB.warning.enabled == false and LastPrint():find("Just"), LastPrint())
    AddPlate("nameplate9", { player = true, guid = "G-HANS", name = "Hans", dist = 5 })
    FastTick()
    Check("Ausgeschaltet: keine Warnung", #calls.banners == banners)
    Check("Ausgeschaltet: keine rote Markierung", not RowOf("G-HANS").distance.text:find("!"), RowOf("G-HANS").distance.text)
    Slash("unjust")
    FastTick()
    Check("/warden unjust: wer schon nah ist, wird nicht auf einen Schlag gemeldet", #calls.banners == banners)
    Check("... ist aber rot markiert", RowOf("G-HANS").distance.text:find("!"), RowOf("G-HANS").distance.text)
    units.nameplate9.dist = 25
    FastTick()
    units.nameplate9.dist = 5
    FastTick()
    Check("Hans geht raus und kommt wieder: jetzt Warnung", #calls.banners == banners + 1)

    Slash("warnung 30")
    Check("/warden warnung 30", CrimeWardenDB.warning.yards == 30 and LastPrint():find("30 m"), LastPrint())
    units.nameplate1.dist = 40
    FastTick()
    units.nameplate1.dist = 28
    local before = #calls.banners
    FastTick()
    local hit = false
    for i = before + 1, #calls.banners do
        if calls.banners[i]:find("Lady Aria %(IC%) ist näher als 30 m") then hit = true end
    end
    Check("Neue Grenze 30 m wirkt (mit RP-Name und IC)", hit, calls.banners[#calls.banners])
    Slash("warnung 3")
    Check("Untergrenze 5 m", CrimeWardenDB.warning.yards == 5)
    Slash("warnung 100")
    Check("Obergrenze 50 m", CrimeWardenDB.warning.yards == 50)
    Slash("warnung 15")

    CrimeWardenDB.warning.banner = false
    CrimeWardenDB.warning.sound = false
    local sounds = calls.sounds
    before = #calls.banners
    units.nameplate1.dist = 40
    FastTick()
    units.nameplate1.dist = 10
    FastTick()
    Check("Banner aus: kein Banner", #calls.banners == before)
    Check("Ton aus: kein Ton", calls.sounds == sounds)
    Check("Chat bleibt", LastPrint():find("Lady Aria"), LastPrint())
    CrimeWardenDB.warning.banner = true
    CrimeWardenDB.warning.sound = true
end)

Scenario("Im Kampf", function()
    local banners = #calls.banners
    units.nameplate9.dist = 40
    units.nameplate3.dist = 40
    Tick(1)
    FastTick()
    inCombat = true
    units.nameplate9.dist = 5
    units.nameplate3.dist = 5
    FastTick()
    Check("Im Kampf: nur der angreifbare Spieler wird gemeldet",
        #calls.banners == banners + 1 and calls.banners[#calls.banners]:find("Feindus"), calls.banners[#calls.banners])
    Tick(1)
    Check("Im Kampf: Entfernung freundlicher Spieler bleibt stehen", ns.rosters.plate:Get("G-HANS").rangeUpper == 40,
        ns.rosters.plate:Get("G-HANS").rangeUpper)
    inCombat = false
    FastTick()
    Check("Nach dem Kampf: Hans wird gemeldet", #calls.banners == banners + 2 and calls.banners[#calls.banners]:find("Hans"))
end)

Scenario("Ohne geladene Gegenstandsdaten", function()
    itemsCached = false
    units.nameplate2.dist = 5
    units.nameplate1.dist = 20
    Tick(1)
    Check("Grobe Stufe über CheckInteractDistance (bis 10 m)", ns.rosters.plate:Get("G-BERN").rangeUpper == 10)
    Check("Grobe Stufe über CheckInteractDistance (10-28 m)", ns.rosters.plate:Get("G-ARIA").rangeLower == 10
        and ns.rosters.plate:Get("G-ARIA").rangeUpper == 28)
    local banners = #calls.banners
    FastTick()
    Check("Ohne Gegenstände keine Fehlalarme", #calls.banners == banners)
    itemsCached = true
    Tick(1)
    Check("Danach wieder genau", ns.rosters.plate:Get("G-ARIA").rangeUpper == 20)
end)

Scenario("Profilanfragen an TRP3", function()
    for _ = 1, 3 do Tick(2) end
    local bern = 0
    for _, id in ipairs(calls.sendQuery) do if id == "Bern-Testrealm" then bern = bern + 1 end end
    Check("Bern (ohne Profil) genau einmal angefragt", bern == 1, bern)
    for _, id in ipairs(calls.sendQuery) do
        Check("Keine Anfrage für Aria (Profil bekannt)", id ~= "Aria-Testrealm")
    end
    trp3Characters["Bern-Testrealm"] = { profileID = "P2", FN = "Bernhard der Graue", RP = 2 }
    Tick(1)
    local row = RowOf("G-BERN")
    Check("Bern zeigt jetzt RP-Namen", row and row.name.text == "Bernhard der Graue", row and row.name.text)
    Check("Bern ist OOC", row and row.status.text == "OOC")
end)

Scenario("Filter und Sortierung", function()
    ns.db.hideHostile = true
    ns.UI:Refresh()
    Check("Feind ausgeblendet", RowOf("G-FEIND") == nil)
    ns.db.hideHostile = false
    ns.db.sortBy = "name"
    ns.UI:Refresh()
    local rows = VisibleRows()
    local names = {}
    for i, row in ipairs(rows) do names[i] = row.name.text end
    Check("Nach Name sortiert", names[1] == "Bernhard der Graue" and names[#names] == "Lady Aria", table.concat(names, " / "))
    ns.db.sortBy = "distance"
    ns.UI:Refresh()
end)

Scenario("Klicks und Tooltip", function()
    local aria = RowOf("G-ARIA")
    aria.scripts.OnClick(aria, "LeftButton")
    Check("Linksklick öffnet TRP3-Profil", calls.mainFrame == 1 and calls.openPage[1] == "Aria-Testrealm")
    aria.scripts.OnClick(aria, "RightButton")
    Check("Rechtsklick flüstert", calls.tell[1] == "Aria")
    shiftDown = true
    aria.scripts.OnClick(aria, "LeftButton")
    shiftDown = false
    Check("Umschalt+Klick setzt Namen in den Chat", calls.openChat[1] == "Aria")
    aria.scripts.OnEnter(aria)
    Check("Tooltip zeigt Einheit", GameTooltip.unit == "nameplate1")
    local hasRP = false
    for _, line in ipairs(GameTooltipLines) do if line == "Lady Aria" then hasRP = true end end
    Check("Tooltip enthält RP-Namen", hasRP)
    aria.scripts.OnLeave(aria)
    Check("Tooltip geschlossen", GameTooltip.owner == nil)
    local hans = RowOf("G-HANS")
    hans.scripts.OnClick(hans, "LeftButton")
    Check("Ohne Profil: Hinweis", LastPrint():find("kein Total%-RP%-3%-Profil"), LastPrint())
end)

Scenario("Spieler gehen, Plaketten werden neu vergeben", function()
    RemovePlate("nameplate3")
    Check("Feind entfernt", ns.rosters.plate:Get("G-FEIND") == nil)
    units.nameplate2 = { player = true, guid = "G-CARA", name = "Cara", className = "Magierin", classFile = "MAGE",
        race = "Gnom", level = 60, dist = 30 }
    Tick(1)
    Check("Alter Spieler weg", ns.rosters.plate:Get("G-BERN") == nil)
    Check("Neuer Spieler da", ns.rosters.plate:Get("G-CARA") ~= nil)
    units.nameplate1 = nil
    Tick(5)
    Check("Abgleich entfernt verwaiste Einträge", ns.rosters.plate:Get("G-ARIA") == nil, ns.rosters.plate:Count())
end)

Scenario("Ohne Total RP 3", function()
    trp3Loaded = false
    _G.TRP3_API = nil
    Tick(1)
    local cara = ns.rosters.plate:Get("G-CARA")
    Check("Ohne TRP3 kein Profil", cara and not cara.hasProfile and cara.rpName == nil)
    local row = RowOf("G-CARA")
    row.scripts.OnClick(row, "LeftButton")
    Check("Hinweis TRP3 fehlt", LastPrint():find("Total RP 3 ist nicht geladen"), LastPrint())
    trp3Loaded = true
    _G.TRP3_API = MakeTRP3()
end)

Scenario("Modusschalter Just / Unjust im Fenster", function()
    local just, unjust = ModeHalves(CrimeWardenFrame)
    Check("Zweigeteilter Schalter: Just und Unjust", just and unjust and just.label.text == "Just"
        and unjust.label.text == "Unjust")
    Check("Unjust aktiv: rot, Just grau", IsRed(unjust.background.color) and IsGrey(just.background.color)
        and IsGrey(just.label.textColor))
    just.scripts.OnClick(just)
    Check("Klick auf Just: keine Warnungen", CrimeWardenDB.warning.enabled == false and LastPrint():find("Modus Just"),
        LastPrint())
    Check("Just aktiv: grün, Unjust grau", IsGreen(just.background.color) and IsGrey(unjust.background.color)
        and IsGrey(unjust.label.textColor))
    local text = table.concat(GameTooltipLines, " ")
    Check("Tooltip: aktiv und Erklärung", text:find("Aktiv") and text:find("Keine Warnungen"), text)
    local before = #printed
    just.scripts.OnClick(just)
    Check("Erneuter Klick auf aktive Hälfte ändert nichts", CrimeWardenDB.warning.enabled == false and #printed == before)
    unjust.scripts.OnEnter(unjust)
    text = table.concat(GameTooltipLines, " ")
    Check("Tooltip der inaktiven Hälfte lädt zum Aktivieren ein", text:find("Klicken, um diesen Modus")
        and text:find("15 m"), text)
    unjust.scripts.OnClick(unjust)
    Check("Klick auf Unjust: wieder Warnungen, rot", CrimeWardenDB.warning.enabled == true
        and IsRed(unjust.background.color))
    unjust.scripts.OnLeave(unjust)
end)

Scenario("Gruppe hinter der Kamera", function()
    groupSize = 1
    units.party1 = { player = true, guid = "G-PIA", name = "Pia", className = "Priesterin", classFile = "PRIEST",
        race = "Draenei", level = 60, dist = 30, world = { x = 530, y = 500 } }
    Fire("GROUP_ROSTER_UPDATE")
    local pia = ns.rosters.group:Get("G-PIA")
    Check("Gruppenmitglied ohne Plakette erfasst", pia ~= nil)
    Check("Genaue Entfernung 30 m", pia and pia.distance == 30, pia and pia.distance)
    local row = RowOf("G-PIA")
    Check("Zeile zeigt 30 m und Gruppe", row and row.distance.text == "30 m" and row.info.text:find("Gruppe"),
        row and (row.distance.text .. " | " .. row.info.text))

    local banners = #calls.banners
    units.party1.world.x = 510
    FastTick()
    Check("Gruppe wird standardmäßig nicht gemeldet", #calls.banners == banners)
    CrimeWardenDB.warning.ignoreGroup = false
    units.party1.world.x = 530
    FastTick()
    units.party1.world.x = 510
    FastTick()
    Check("Ohne 'Gruppe ignorieren': Warnung live über die Weltposition",
        #calls.banners == banners + 1 and calls.banners[#calls.banners]:find("Pia"), calls.banners[#calls.banners])
    CrimeWardenDB.warning.ignoreGroup = true

    inInstance = true
    units.party1.dist = 12
    Tick(1)
    pia = ns.rosters.group:Get("G-PIA")
    Check("In Instanzen: Gegenstands-Reichweite", pia and pia.distance == nil and pia.rangeUpper == 15,
        pia and tostring(pia.rangeUpper))
    inInstance = false

    Slash("gruppe aus")
    Check("/warden gruppe aus leert die Gruppenliste", ns.rosters.group:Count() == 0 and LastPrint():find("Gruppe: aus"),
        LastPrint())
    Slash("gruppe an")
    Check("/warden gruppe an", ns.rosters.group:Count() == 1)
    groupSize = 0
    units.party1 = nil
    Fire("GROUP_ROSTER_UPDATE")
    Check("Gruppe verlassen", ns.rosters.group:Count() == 0)
end)

Scenario("TRP3-Ortung", function()
    Check("Ortungsanfragen verschickt", #calls.scans > 0 and calls.scans[#calls.scans].command == "C_SCAN"
        and calls.scans[#calls.scans].mapID == 1)
    local before = #calls.scans
    for _ = 1, 20 do Tick(1) end
    Check("Alle 10 s eine Anfrage", #calls.scans - before == 2, #calls.scans - before)

    local function UntilScan()
        local count = #calls.scans
        for _ = 1, 15 do
            Tick(1)
            if #calls.scans > count then return end
        end
    end
    UntilScan()
    Answer("Lena-Testrealm", 0.53, 0.5)
    Tick(1)
    local lena = ns.rosters.locator:Get("Lena-Testrealm")
    Check("Geortet mit 30 m", lena and lena.distance == 30, lena and lena.distance)
    local row
    for _, r in ipairs(VisibleRows()) do if r.entry.fullName == "Lena-Testrealm" then row = r end end
    Check("Zeile zeigt ~30 m und 'geortet vor'", row and row.distance.text == "~30 m"
        and row.info.text:find("geortet vor %d+ s"), row and (row.distance.text .. " | " .. row.info.text))

    for _ = 1, 6 do Tick(1) end
    Answer("Spaet-Testrealm", 0.52, 0.5)
    Tick(1)
    Check("Verspätete Antwort wird ignoriert", ns.rosters.locator:Get("Spaet-Testrealm") == nil)

    local banners = #calls.banners
    playerWorld.x = 525
    FastTick()
    Check("Eigene Bewegung zählt live: Warnung bei 5 m",
        #calls.banners == banners + 1 and calls.banners[#calls.banners]:find("Lena"), calls.banners[#calls.banners])

    AddPlate("nameplate11", { player = true, guid = "G-LENA", name = "Lena", dist = 5, level = 60 })
    local lenas = 0
    for _, r in ipairs(VisibleRows()) do if r.entry.fullName == "Lena-Testrealm" then lenas = lenas + 1 end end
    Check("Plakette und Ortung: nur eine Zeile", lenas == 1)
    FastTick()
    Check("Keine doppelte Warnung beim Quellenwechsel", #calls.banners == banners + 1)
    RemovePlate("nameplate11")
    playerWorld.x = 500

    UntilScan()
    _G.TRP3_API.MapScannersManager.launch("playerScan")
    Answer("Kartenscan-Testrealm", 0.51, 0.5)
    Check("Während eines TRP3-Kartenscans keine Übernahme", ns.rosters.locator:Get("Kartenscan-Testrealm") == nil)

    Tick(26)
    Tick(1)
    Check("Alte Ortungen verfallen", ns.rosters.locator:Get("Lena-Testrealm") == nil)

    Slash("ortung aus")
    before = #calls.scans
    for _ = 1, 15 do Tick(1) end
    Check("/warden ortung aus: keine Anfragen", #calls.scans == before)
    Slash("ortung 5")
    Check("/warden ortung 5", CrimeWardenDB.sources.locatorInterval == 5 and LastPrint():find("alle 5 s"), LastPrint())
    Slash("ortung an")
    inInstance = true
    before = #calls.scans
    for _ = 1, 12 do Tick(1) end
    Check("In Instanzen keine Anfragen", #calls.scans == before)
    inInstance = false
    for _ = 1, 6 do Tick(1) end
    Check("Danach wieder Anfragen", #calls.scans > before)
    Slash("ortung 10")
end)

-- Fehler aus 0.6.0: In Nordhafen stehen, auf der Weltkarte zu "Vorland"
-- wechseln und mit TRP3 nach Spielern suchen: TRP3 zeigte Spieler aus
-- Nordhafen, weil Antworten auf CrimeWardens Ortung in TRP3s Liste landeten.
Scenario("TRP3-Karte zeigt keine Spieler einer anderen Karte", function()
    local manager = _G.TRP3_API.MapScannersManager
    local function UntilOwnScan()
        local count = #calls.scans
        for _ = 1, 15 do
            Tick(1)
            if #calls.scans > count then return true end
        end
        return false
    end

    Check("CrimeWarden ortet (Karte schließen)", UntilOwnScan())
    local trp3Before = #trp3Scanner.data -- Rest vom letzten TRP3-Scan, TRP3 leert erst beim nächsten
    Answer("Nordhafener-Testrealm", 0.52, 0.5)
    Check("Antwort auf CrimeWardens Anfrage landet nicht in TRP3s Kartenliste", #trp3Scanner.data == trp3Before,
        #trp3Scanner.data)
    Tick(1)
    Check("... wohl aber in CrimeWarden", ns.rosters.locator:Get("Nordhafener-Testrealm") ~= nil)

    WorldMapFrame.shown = true
    displayedMap = 2
    local before = #calls.scans
    for _ = 1, 25 do Tick(1) end
    Check("Bei offener Weltkarte keine CrimeWarden-Anfragen", #calls.scans == before, #calls.scans - before)

    manager.launch("playerScan")
    Answer("Torwache-Testrealm", 0.3, 0.4)
    Check("TRP3-Scan von 'Vorland': Antwort von dort kommt an",
        #trp3Scanner.data == 1 and trp3Scanner.data[1].sender == "Torwache-Testrealm")
    Tick(1)
    Check("CrimeWarden übernimmt sie nicht (andere Karte)", ns.rosters.locator:Get("Torwache-Testrealm") == nil)
    clock = clock + 5
    Answer("Nachzuegler-Testrealm", 0.3, 0.4)
    Check("Nach dem TRP3-Scan kommt nichts mehr in TRP3s Liste", #trp3Scanner.data == 1, #trp3Scanner.data)

    -- Knapper Fall: CrimeWarden fragt für Nordhafen, eine Sekunde später
    -- scannt man 'Vorland'; die Nordhafener Antwort trifft erst dann ein.
    displayedMap = 1
    local scansBefore = #calls.scans
    CloseMap()
    Check("Karte zu: CrimeWarden ortet sofort", #calls.scans == scansBefore + 1, #calls.scans - scansBefore)
    WorldMapFrame.shown = true
    displayedMap = 2
    clock = clock + 1
    manager.launch("playerScan")
    Answer("Nordhafener-Testrealm", 0.52, 0.5)
    Check("Späte Nordhafener Antwort erscheint nicht auf 'Vorland'", #trp3Scanner.data == 0, #trp3Scanner.data)

    -- Scannt man die eigene Karte, gehen auch solche Antworten durch (sie gehören dorthin).
    clock = clock + 6
    displayedMap = 1
    CloseMap()
    WorldMapFrame.shown = true
    manager.launch("playerScan")
    Answer("Nordhafener-Testrealm", 0.52, 0.5)
    Check("TRP3-Scan der eigenen Karte: Antwort kommt an", #trp3Scanner.data == 1, #trp3Scanner.data)

    -- Karte schließen, während der TRP3-Scan noch läuft: erst danach orten.
    scansBefore = #calls.scans
    CloseMap()
    Check("Karte zu während TRP3-Scan: noch keine Anfrage", #calls.scans == scansBefore)
    local waited = 0
    while #calls.scans == scansBefore and waited < 10 do
        Tick(1)
        waited = waited + 1
    end
    Check("Anfrage direkt nach Ende des TRP3-Scans (höchstens 5 s)", #calls.scans == scansBefore + 1 and waited <= 5,
        waited)

    -- TRP3-Ortung in CrimeWarden aus: Schließen der Karte löst nichts aus.
    Slash("ortung aus")
    clock = clock + 6
    WorldMapFrame.shown = true
    scansBefore = #calls.scans
    CloseMap()
    Check("Ortung aus: Schließen der Karte löst keine Anfrage aus", #calls.scans == scansBefore)
    Slash("ortung an")
    clock = clock + 6
end)

Scenario("Spürsinn", function()
    local originalUnitGUID = _G.UnitGUID
    _G.UnitGUID = function(unit)
        if unit == "player" then return "G-ICH" end
        return originalUnitGUID(unit)
    end
    local banners = #calls.banners
    playerInfo["G-GERDA"] = { className = "Kriegerin", classFile = "WARRIOR", race = "Zwergin" }
    Fire("CHAT_MSG_SAY", "Hallo zusammen", "Gerda-Testrealm", "", "", "", "", 0, 0, "", 0, 1, "G-GERDA")
    Fire("CHAT_MSG_SAY", "Ich bin's", "Ich-Testrealm", "", "", "", "", 0, 0, "", 0, 2, "G-ICH")
    combatEvent = { clock, "SPELL_CAST_SUCCESS", false, "G-OTTO", "Otto", 0x548, 0, "G-ICH", "Ich", 0x511, 0 }
    Fire("COMBAT_LOG_EVENT_UNFILTERED")
    Tick(1)

    local gerda = ns.rosters.senses:Get("Gerda-Testrealm")
    Check("Gesprochenes wird gespürt", gerda ~= nil)
    Check("Eigene Nachricht wird ignoriert", ns.rosters.senses:Get("Ich-Testrealm") == nil)
    local row
    for _, r in ipairs(VisibleRows()) do if r.entry.fullName == "Gerda-Testrealm" then row = r end end
    Check("Zeile: in Hörweite, gespürt, Klasse aus GUID", row and row.distance.text == "in Hörweite"
        and row.info.text:find("gespürt vor %d+ s %(spricht%)") and row.info.text:find("Zwergin Kriegerin"),
        row and (row.distance.text .. " | " .. row.info.text))
    local otto = ns.rosters.senses:Get("Otto-Testrealm")
    Check("Kampflog: feindlicher Spieler gespürt", otto and otto.hostile == true and otto.detail == "COMBAT")
    Check("Kampflog: eigene Einheit ignoriert", ns.rosters.senses:Get("Ich-Testrealm") == nil)
    FastTick()
    Check("Spürsinn löst keine Warnung aus", #calls.banners == banners)

    Tick(61)
    Check("Nach 60 s vergessen", ns.rosters.senses:Count() == 0, ns.rosters.senses:Count())

    Slash("spürsinn aus")
    Check("/warden spürsinn aus", CrimeWardenDB.sources.senses == false and LastPrint():find("Spürsinn: aus"), LastPrint())
    Fire("CHAT_MSG_EMOTE", "winkt", "Gerda-Testrealm", "", "", "", "", 0, 0, "", 0, 3, "G-GERDA")
    Tick(1)
    Check("Ausgeschaltet: nichts gespürt", ns.rosters.senses:Count() == 0)
    Slash("spuersinn an")
    Fire("CHAT_MSG_EMOTE", "winkt", "Gerda-Testrealm", "", "", "", "", 0, 0, "", 0, 4, "G-GERDA")
    Tick(1)
    Check("Wieder an: Emote gespürt", ns.rosters.senses:Get("Gerda-Testrealm")
        and ns.rosters.senses:Get("Gerda-Testrealm").detail == "EMOTE")
    Tick(61)
    _G.UnitGUID = originalUnitGUID
end)

Scenario("Befehle", function()
    Slash("")
    Check("/warden blendet aus", not ns.UI:IsShown() and CrimeWardenDB.window.shown == false)
    local count = ns.rosters.plate:Count()
    AddPlate("nameplate10", { player = true, guid = "G-DORA", name = "Dora", dist = 30, level = 30 })
    Slash("")
    Check("/warden blendet ein und zeigt neuen Stand", ns.UI:IsShown() and ns.rosters.plate:Count() == count + 1
        and title.text:find("CrimeWarden %(%d+%)"), title.text)
    Slash("optionen")
    Check("/warden optionen öffnet Einstellungen", calls.optionsOpened >= 1)
    CrimeWardenDB.window.x = 300
    Slash("reset")
    Check("/warden reset", CrimeWardenDB.window.x == 0 and LastPrint():find("zurückgesetzt"))
    Slash("hilfe")
    Check("/warden hilfe", LastPrint():find("/warden hilfe"))
    Slash("warnung")
    Check("/warden warnung zeigt Status", LastPrint():find("Modus Unjust.*15 m"), LastPrint())
    Slash("quatsch")
    Check("Unbekannter Befehl zeigt Hilfe", LastPrint():find("/warden hilfe"))
end)

Scenario("Einstellungsseite", function()
    local panel = optionsPanels[1]
    panel.scripts.OnShow(panel)
    local function FindCheck(pattern)
        for _, frame in ipairs(allFrames) do
            if frame.parent == panel and frame.kind == "CheckButton" and frame.fontStrings[1].text:find(pattern) then
                return frame
            end
        end
    end
    local lock = FindCheck("sperren")
    lock.checked = true
    lock.scripts.OnClick(lock)
    Check("Sperren gespeichert", CrimeWardenDB.window.locked == true)
    lock.checked = false
    lock.scripts.OnClick(lock)
    Check("Entsperren gespeichert", CrimeWardenDB.window.locked == false)
    local panelJust, panelUnjust = ModeHalves(panel)
    Check("Modusschalter auch in den Einstellungen, Unjust aktiv", panelJust and panelUnjust
        and IsRed(panelUnjust.background.color) and IsGrey(panelJust.background.color))
    local group = FindCheck("Gruppe auch")
    Check("Quellen-Schalter zeigen Zustand", group and group.checked == true and FindCheck("Spürsinn").checked == true)

    local warnText
    for _, fs in ipairs(panel.fontStrings) do
        if fs.text and fs.text:find("Warnen ab") then warnText = fs end
    end
    Check("Warngrenze angezeigt", warnText and warnText.text == "Warnen ab: 15 m", warnText and warnText.text)
    local plus, toggles = {}, {}
    for _, frame in ipairs(allFrames) do
        if frame.parent == panel and frame.text == "+" and frame.points.LEFT then plus[#plus + 1] = frame end
        if frame.parent == panel and frame.text == "Umschalten" then toggles[#toggles + 1] = frame end
    end
    Check("Vier +/- Regler (Umkreis, Hörweite, Warngrenze, Ortung)", #plus == 4, #plus)
    Check("Ein Umschaltknopf (Sortierung)", #toggles == 1, #toggles)
    plus[2].scripts.OnClick(plus[2])
    Check("+ erhöht die Hörweite auf 35 m", CrimeWardenDB.sayRange == 35, CrimeWardenDB.sayRange)
    Slash("hörweite 30")
    plus[3].scripts.OnClick(plus[3])
    Check("+ erhöht die Warngrenze auf 20 m", CrimeWardenDB.warning.yards == 20 and warnText.text == "Warnen ab: 20 m",
        warnText.text)
    Slash("warnung 15")
    panelJust.scripts.OnClick(panelJust)
    local windowJust = ModeHalves(CrimeWardenFrame)
    Check("Just in den Einstellungen: beide Schalter grün", CrimeWardenDB.warning.enabled == false
        and IsGreen(panelJust.background.color) and IsGreen(windowJust.background.color))
    panelUnjust.scripts.OnClick(panelUnjust)
    toggles[1].scripts.OnClick(toggles[1])
    Check("Sortier-Knopf schaltet auf Name", CrimeWardenDB.sortBy == "name")
    toggles[1].scripts.OnClick(toggles[1])
    plus[4].scripts.OnClick(plus[4])
    Check("+ erhöht den Ortungsabstand", CrimeWardenDB.sources.locatorInterval == 15)
    Slash("ortung 10")
    plus[1].scripts.OnClick(plus[1])
    Check("+ erhöht den Umkreis auf die nächste Stufe (55 m)", CrimeWardenDB.radius == 55, CrimeWardenDB.radius)
    Slash("umkreis 50")
    group.checked = false
    group.scripts.OnClick(group)
    Check("Gruppe abschaltbar", CrimeWardenDB.sources.group == false)
    group.checked = true
    group.scripts.OnClick(group)

    local function FindButton(text)
        for _, frame in ipairs(allFrames) do
            if frame.parent == panel and frame.text == text then return frame end
        end
    end
    local banners = #calls.banners
    local test = FindButton("Testwarnung")
    test.scripts.OnClick(test)
    Check("Testwarnung zeigt Banner", #calls.banners == banners + 1 and calls.banners[#calls.banners]:find("Testperson"),
        calls.banners[#calls.banners])
    local window = FindButton("Fenster verbergen")
    window.scripts.OnClick(window)
    Check("Knopf 'Fenster verbergen' blendet aus und heißt dann 'Fenster zeigen'",
        not ns.UI:IsShown() and window.text == "Fenster zeigen", window.text)
    window.scripts.OnClick(window)
    Check("Und wieder ein", ns.UI:IsShown())
end)

Scenario("Werkzeugleiste im Fenster", function()
    local function FindWindowButton(pattern)
        for _, frame in ipairs(allFrames) do
            if frame.parent == CrimeWardenFrame and frame.text and frame.text:find(pattern) then return frame end
        end
    end
    local locate = FindWindowButton("Ortung")
    Check("Ortung-Schalter grün (an)", locate and locate.text:find("60e060"), locate and locate.text)
    locate.scripts.OnClick(locate)
    Check("Klick schaltet Ortung aus", CrimeWardenDB.sources.locator == false and locate.text:find("909090"),
        locate.text)
    local stateShown = false
    for _, line in ipairs(GameTooltipLines) do if line:find("Ausgeschaltet") then stateShown = true end end
    Check("Tooltip zeigt den neuen Zustand", stateShown)
    locate.scripts.OnClick(locate)
    Check("Und wieder an", CrimeWardenDB.sources.locator == true)
    local senses = FindWindowButton("Spürsinn")
    senses.scripts.OnClick(senses)
    Check("Spürsinn-Schalter wirkt", CrimeWardenDB.sources.senses == false)
    senses.scripts.OnClick(senses)
    local group = FindWindowButton("Gruppe")
    group.scripts.OnClick(group)
    Check("Gruppen-Schalter wirkt", CrimeWardenDB.sources.group == false)
    group.scripts.OnClick(group)

    local opened = calls.optionsOpened
    local options = FindWindowButton("^Optionen$")
    options.scripts.OnClick(options)
    Check("Optionen-Knopf öffnet die Einstellungen", calls.optionsOpened > opened)
    local help = FindWindowButton("^%?$")
    help.scripts.OnEnter(help)
    local text = table.concat(GameTooltipLines, " ")
    Check("Hilfe erklärt Liste, Quellen, Modus und Klicks", text:find("Just") and text:find("Spürsinn")
        and text:find("anflüstern"), text)
end)

Scenario("Jedes Bedienelement hat eine Erklärung", function()
    local panel = optionsPanels[1]
    local checked, missing = 0, {}
    for _, frame in ipairs(allFrames) do
        local parent = frame.parent
        local grandparent = parent and parent.parent
        local inUI = parent == panel or parent == CrimeWardenFrame or parent == _G.Minimap
            or grandparent == panel or grandparent == CrimeWardenFrame
        if inUI and (frame.kind == "Button" or frame.kind == "CheckButton") then
            checked = checked + 1
            local onEnter = frame.scripts.OnEnter
            GameTooltipLines = {}
            if onEnter then onEnter(frame) end
            if not onEnter or #GameTooltipLines < 2 then
                missing[#missing + 1] = tostring(frame.text or (frame.fontStrings[1] and frame.fontStrings[1].text)
                    or frame.template or frame.kind)
            end
            if frame.scripts.OnLeave then frame.scripts.OnLeave(frame) end
        end
    end
    Check("Bedienelemente gefunden", checked >= 30, checked)
    Check("Alle mit Tooltip aus Titel und Erklärung", #missing == 0, table.concat(missing, ", "))
end)

Scenario("Hörweite und Warnung ab 50 m", function()
    Slash("warnung 50")
    FastTick() -- wer schon innerhalb von 50 m steht, wird nach der Änderung neu gemeldet
    local banners = #calls.banners
    AddPlate("nameplate20", { player = true, guid = "G-WACHE", name = "Wachtmeister", dist = 58, level = 60 })
    FastTick()
    Check("Bei 58 m keine Warnung", #calls.banners == banners)
    units.nameplate20.dist = 49
    FastTick()
    Check("Bei 49 m Warnung (Grenze 50 m)", #calls.banners == banners + 1
        and calls.banners[#calls.banners]:find("näher als 50 m"), calls.banners[#calls.banners])
    units.nameplate20.dist = 53
    FastTick()
    units.nameplate20.dist = 48
    FastTick()
    Check("Pendeln zwischen 50 und 55 m: keine neue Warnung", #calls.banners == banners + 1)
    units.nameplate20.dist = 57
    FastTick()
    units.nameplate20.dist = 47
    FastTick()
    Check("Über 55 m und wieder herein: erneute Warnung", #calls.banners == banners + 2)
    Slash("warnung 60")
    Check("Warngrenze höchstens 50 m", CrimeWardenDB.warning.yards == 50)
    cvars.nameplateMaxDistance = "50"
    Check("Warngrenze 50 m braucht 60 m Plaketten-Sichtweite (sonst nicht bereit)", not ns:NameplatesReady())
    Slash("plaketten")
    Check("Knopf stellt die Sichtweite auf 60 m", cvars.nameplateMaxDistance == "60", cvars.nameplateMaxDistance)

    units.nameplate20.dist = 25
    Tick(1)
    local row = RowOf("G-WACHE")
    Check("Bei 25 m Sprechblase (in Hörweite)", row and row.earshot.shown == true)
    row.scripts.OnEnter(row)
    local text = table.concat(GameTooltipLines, " ")
    Check("Tooltip: kann dich hören", text:find("Kann dich per /sagen hören %(bis 30 m%)"), text)
    row.scripts.OnLeave(row)
    units.nameplate20.dist = 40
    Tick(1)
    Check("Bei 40 m keine Sprechblase", RowOf("G-WACHE").earshot.shown == false)
    Slash("hörweite 45")
    Check("/warden hörweite 45", CrimeWardenDB.sayRange == 45 and LastPrint():find("45 m"), LastPrint())
    Check("Mit 45 m Hörweite: Sprechblase bei 40 m", RowOf("G-WACHE").earshot.shown == true)
    Slash("hörweite 30")
    RemovePlate("nameplate20")
    Slash("warnung 15")
end)

-- Regression 0.4.2: "/cw" ist im deutschen Client der Flüsterbefehl
-- (SLASH_WHISPER1). Ein Addon-Befehl mit demselben Kürzel überschreibt die
-- Chat-Art in hash_ChatTypeInfoList und macht Flüstern per Rechtsklick kaputt.
Scenario("Hörweite folgt dem Server-Regler (nur lesen)", function()
    local panel = optionsPanels[1]
    local function PanelText(pattern)
        for _, fs in ipairs(panel.fontStrings) do
            if fs.text and fs.text:find(pattern) then return fs end
        end
    end
    panel.scripts.OnShow(panel)
    Check("Ohne Regler: Hinweis 'nicht gefunden'", PanelText("Regler noch nicht gefunden") ~= nil)
    Check("Ohne Regler: eingestellte Hörweite gilt", ns:GetSayRange() == 30)

    -- Der Server erzeugt den Regler erst beim ersten Öffnen.
    local setValueCalls = 0
    local slider = { value = 2, min = 1, max = 3, hooks = {} }
    function slider:GetValue() return self.value end
    function slider:GetMinMaxValues() return self.min, self.max end
    function slider:SetValue() setValueCalls = setValueCalls + 1 end
    function slider:HookScript(script, fn) self.hooks[script] = fn end
    local function Move(value)
        slider.value = value
        if slider.hooks.OnValueChanged then slider.hooks.OnValueChanged(slider, value) end
    end
    _G.ChatRangeMenuPopup = { Slider = slider }
    Tick(1)
    Check("Regler gefunden und mitgehört", slider.hooks.OnValueChanged ~= nil)
    Check("Stufe 2 von 1 bis 3 = 20 m", ns:GetSayRange() == 20, ns:GetSayRange())
    panel.scripts.OnShow(panel)
    Check("Statuszeile zeigt die Reglerwerte", PanelText("Regler steht auf 2 %(Bereich 1 bis 3%), geschätzt 20 m") ~= nil)
    Check("Hörweiten-Zeile zeigt 'Regler'", PanelText("^Hörweite: 20 m %(Regler%)") ~= nil)
    local locked = 0
    for _, frame in ipairs(allFrames) do
        if frame.parent == panel and (frame.text == "-" or frame.text == "+") and frame.enabled == false then
            locked = locked + 1
        end
    end
    Check("Hörweiten-Knöpfe gesperrt (2)", locked == 2, locked)

    AddPlate("nameplate21", { player = true, guid = "G-LAUSCHER", name = "Lauscher", dist = 25, level = 60 })
    Tick(1)
    Check("25 m bei 20 m Hörweite: keine Sprechblase", RowOf("G-LAUSCHER").earshot.shown == false)
    Move(3)
    Check("Schieber auf Normal: sofort 30 m", ns:GetSayRange() == 30)
    Check("Und die Sprechblase erscheint sofort", RowOf("G-LAUSCHER").earshot.shown == true)
    Move(1)
    Check("Schieber auf Niedrig: 10 m", ns:GetSayRange() == 10)

    Slash("hörweite 45")
    Check("Manuelle Hörweite wird gemerkt, Regler gilt weiter", CrimeWardenDB.sayRange == 45 and ns:GetSayRange() == 10
        and LastPrint():find("folgt gerade"), LastPrint())
    Slash("regler aus")
    Check("/warden regler aus: eingestellte Hörweite gilt", ns:GetSayRange() == 45 and LastPrint():find("aus"),
        LastPrint())
    panel.scripts.OnShow(panel)
    locked = 0
    for _, frame in ipairs(allFrames) do
        if frame.parent == panel and (frame.text == "-" or frame.text == "+") and frame.enabled == false then
            locked = locked + 1
        end
    end
    Check("Ohne Folgen: keine Knöpfe gesperrt", locked == 0, locked)
    Slash("regler an")
    Check("/warden regler an: wieder vom Regler", ns:GetSayRange() == 10)
    Slash("hörweite 30")
    Move(3)

    Check("CrimeWarden hat den Regler nie verstellt", setValueCalls == 0, setValueCalls)
    RemovePlate("nameplate21")
end)

Scenario("Wahrnehmungswurf pro Eintrag", function()
    AddPlate("nameplate22", { player = true, guid = "G-SCHATTEN", name = "Schatten", dist = 25, level = 60 })
    Tick(1)
    local row = RowOf("G-SCHATTEN")
    Check("Zeile hat einen Würfelknopf", row and row.dice ~= nil)
    row.dice.scripts.OnEnter(row.dice)
    local text = table.concat(GameTooltipLines, " ")
    Check("Tooltip erklärt Regel und Zielwert (bis 25 m: ab 11)", text:find("W20") and text:find("Hier: ab 11")
        and text:find("Nur du siehst"), text)

    -- Feste Augenzahlen statt Zufall.
    local originalRandom = math.random
    rawset(math, "random", function(low, high) assert(low == 1 and high == 20); return 14 end)
    local printedBefore = #printed
    local bannersBefore, queriesBefore, scansBefore = #calls.banners, #calls.sendQuery, #calls.scans
    row.dice.scripts.OnClick(row.dice)
    Check("Ergebnis im eigenen Chat", #printed == printedBefore + 1
        and LastPrint():find("Wahrnehmungswurf auf Schatten: Gewürfelt: 14 %(ab 11%)") and LastPrint():find("bemerkt"),
        LastPrint())
    row = RowOf("G-SCHATTEN")
    Check("Zeile zeigt 'bemerkt (14)'", row.diceResult.text and row.diceResult.text:find("bemerkt %(14%)"),
        row.diceResult.text)
    Check("Nur für mich: kein Banner, nichts verschickt", #calls.banners == bannersBefore
        and #calls.sendQuery == queriesBefore and #calls.scans == scansBefore)

    rawset(math, "random", function() return 2 end)
    row.dice.scripts.OnClick(row.dice)
    Check("Zweiter Wurf gesperrt, altes Ergebnis bleibt", LastPrint():find("schon gewürfelt")
        and RowOf("G-SCHATTEN").diceResult.text:find("14"), LastPrint())
    row.dice.scripts.OnEnter(row.dice)
    text = table.concat(GameTooltipLines, " ")
    Check("Tooltip zeigt Ergebnis und Restzeit", text:find("Gewürfelt: 14") and text:find("Nächster Wurf"), text)
    row.dice.scripts.OnLeave(row.dice)

    clock = clock + 301
    Tick(1)
    Check("Nach 5 Minuten verschwindet das Ergebnis", RowOf("G-SCHATTEN").diceResult.text == "",
        RowOf("G-SCHATTEN").diceResult.text)
    units.nameplate22.dist = 45
    Tick(1)
    rawset(math, "random", function() return 15 end)
    row = RowOf("G-SCHATTEN")
    row.dice.scripts.OnClick(row.dice)
    Check("Neuer Wurf auf 45 m: 15 gegen 16 nicht bemerkt", LastPrint():find("15 %(ab 16%)")
        and LastPrint():find("nicht bemerkt") and RowOf("G-SCHATTEN").diceResult.text:find("unbemerkt %(15%)"),
        LastPrint())
    rawset(math, "random", originalRandom)
    RemovePlate("nameplate22")
end)

Scenario("Neue Warngrenze meldet nicht alle auf einmal", function()
    AddPlate("nameplate23", { player = true, guid = "G-NAH1", name = "Nahbei", dist = 8 })
    AddPlate("nameplate24", { player = true, guid = "G-NAH2", name = "Nebenan", dist = 12 })
    FastTick()
    local banners = #calls.banners
    Slash("warnung 30")
    FastTick()
    FastTick()
    Check("Grenze geändert: keine Flut für alle, die schon drin sind", #calls.banners == banners,
        #calls.banners - banners)
    units.nameplate23.dist = 40
    FastTick()
    units.nameplate23.dist = 10
    FastTick()
    Check("Wer danach von außen kommt, wird gemeldet", #calls.banners == banners + 1)
    RemovePlate("nameplate23")
    RemovePlate("nameplate24")
    Slash("warnung 15")
end)

Scenario("Leerlauf: keine Anfragen, wenn niemand die Daten braucht", function()
    Slash("just")
    if ns.UI:IsShown() then Slash("") end
    Check("Fenster zu, Modus Just", not ns.UI:IsShown() and not ns:IsUnjust())
    local scansBefore, queriesBefore = #calls.scans, #calls.sendQuery
    AddPlate("nameplate25", { player = true, guid = "G-FREMD", name = "Fremdling", dist = 20 })
    for _ = 1, 25 do Tick(1) end
    Check("Keine Ortungsanfragen im Leerlauf", #calls.scans == scansBefore, #calls.scans - scansBefore)
    Check("Keine Profilanfragen im Leerlauf", #calls.sendQuery == queriesBefore, #calls.sendQuery - queriesBefore)
    WorldMapFrame.shown = true
    CloseMap()
    Check("Auch Kartenschließen löst im Leerlauf nichts aus", #calls.scans == scansBefore)
    Slash("")
    for _ = 1, 12 do Tick(1) end
    Check("Fenster offen: Ortung läuft wieder", #calls.scans > scansBefore)
    Check("... und Profilanfragen auch", #calls.sendQuery > queriesBefore)
    Slash("")
    scansBefore = #calls.scans
    Slash("unjust")
    for _ = 1, 12 do Tick(1) end
    Check("Fenster zu, aber Unjust: Ortung läuft (für die Warnung)", #calls.scans > scansBefore)
    Slash("")
    RemovePlate("nameplate25")
end)

Scenario("Spürsinn: feindlich bleibt feindlich", function()
    local originalUnitGUID = _G.UnitGUID
    _G.UnitGUID = function(unit)
        if unit == "player" then return "G-ICH" end
        return originalUnitGUID(unit)
    end
    combatEvent = { clock, "SPELL_CAST_SUCCESS", false, "G-GROLL", "Groll", 0x548, 0, "G-ICH", "Ich", 0x511, 0 }
    Fire("COMBAT_LOG_EVENT_UNFILTERED")
    Fire("CHAT_MSG_SAY", "Na warte", "Groll-Testrealm", "", "", "", "", 0, 0, "", 0, 9, "G-GROLL")
    Tick(1)
    local groll = ns.rosters.senses:Get("Groll-Testrealm")
    Check("Nach Kampflog und /sagen weiter feindlich", groll and groll.hostile == true and groll.detail == "SAY")
    Tick(61)
    _G.UnitGUID = originalUnitGUID
end)

Scenario("Kein Befehl kollidiert mit Blizzard-Befehlen", function()
    local blizzard = {}
    for line in io.lines("tests/data/blizzard_slash_commands.txt") do
        if not line:match("^#") and line ~= "" then
            blizzard[line] = true
        end
    end
    Check("Blizzard-Liste geladen (inkl. /cw)", blizzard["/cw"] and blizzard["/w"])
    local index = 1
    while _G["SLASH_CRIMEWARDEN" .. index] do
        local command = _G["SLASH_CRIMEWARDEN" .. index]:lower()
        Check("Befehl " .. command .. " ist frei", not blizzard[command], command)
        index = index + 1
    end
    Check("Kurzbefehl ist /warden", _G.SLASH_CRIMEWARDEN1 == "/warden", _G.SLASH_CRIMEWARDEN1)
end)

Scenario("Weltwechsel", function()
    Fire("PLAYER_LEAVING_WORLD")
    Check("Liste geleert", ns.rosters.plate:Count() == 0 and title.text == "CrimeWarden (0)", title.text)
    Fire("PLAYER_ENTERING_WORLD")
    Check("Danach neu eingelesen", ns.rosters.plate:Count() > 0, ns.rosters.plate:Count())
end)

print(string.format("%d Prüfungen bestanden, %d fehlgeschlagen", passed, failed))
os.exit(failed == 0 and 0 or 1)
