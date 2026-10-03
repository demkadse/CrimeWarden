local _, ns = ...

-- Quelle "TRP3-Ortung": dieselbe Ortungsanfrage, die auch die Karte von
-- Total RP 3 verschickt (Befehl C_SCAN über den TRP3-Kanal). Jeder TRP3-Nutzer
-- auf derselben Karte, der die Ortung erlaubt, antwortet direkt mit seinen
-- Kartenkoordinaten. Daraus wird die Entfernung in Metern berechnet, auch für
-- Spieler außerhalb des Kamerabilds. Die Position ist so alt wie die letzte
-- Antwort; eigene Bewegung wird live eingerechnet.
--
-- Rücksicht auf die TRP3-Karte: Die Antworten enthalten nur Koordinaten, keine
-- Karte. TRP3 übernimmt während seines eigenen Kartenscans jede Antwort und
-- zeichnet sie auf die angezeigte Karte. Antworten auf CrimeWardens Anfrage
-- (eigene Karte) erschienen deshalb auf einer anderen Karte, die man gerade
-- scannte. Darum: keine eigenen Anfragen, solange die Weltkarte offen ist oder
-- TRP3 scannt, und ein Filter vor TRP3s Ergebnisliste (siehe FilterTRP3Answers).
local Locator = {}
ns.Locator = Locator

local SCAN_COMMAND = "C_SCAN"
local ANSWER_WINDOW = 5 -- Sekunden, in denen Antworten zur eigenen Anfrage passen
local TRP3_SCAN_BLOCK = 6 -- so lange nach einem TRP3-Kartenscan nichts anfassen
local TRP3_SCAN_MARGIN = 1 -- Sekunden über die Scandauer von TRP3 hinaus

local roster = ns.rosters.locator
local positions = {} -- [fullName] = { mapID, x, y, at }
local nextScanAt = 0
local lastScanAt = -math.huge
local scanMapID
local trp3ScanAt = -math.huge
local trp3ScanMapID
local trp3ScanDuration = 3
local handlerRegistered = false
local mapHooked = false

local function Broadcast()
    local communications = type(AddOn_TotalRP3) == "table" and AddOn_TotalRP3.Communications
    local broadcast = type(communications) == "table" and communications.broadcast
    if type(broadcast) == "table" and type(broadcast.broadcast) == "function"
        and type(broadcast.registerP2PCommand) == "function" then
        return broadcast
    end
    return nil
end

local function ScannersManager()
    local manager = type(TRP3_API) == "table" and TRP3_API.MapScannersManager
    return type(manager) == "table" and manager or nil
end

local function IsIgnored(fullName)
    local register = type(TRP3_API) == "table" and TRP3_API.register
    local isIgnored = type(register) == "table" and register.isIDIgnored
    if type(isIgnored) ~= "function" then
        return false
    end
    local ok, ignored = pcall(isIgnored, fullName)
    return ok and ignored
end

local function WorldPosition(mapID, x, y)
    local ok, continent, position = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(x, y))
    if not ok or not continent or not position then
        return nil
    end
    local worldX, worldY = position:GetXY()
    return continent, worldX, worldY
end

-- Karte und Koordinaten des Spielers, oder nil (z. B. in Instanzen).
local function PlayerMapPosition()
    local mapID = C_Map.GetBestMapForUnit("player")
    local position = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    if not position then
        return nil
    end
    local x, y = position:GetXY()
    return mapID, x, y
end

-- Aktuelle Entfernung zu einem georteten Spieler in Metern, oder nil.
function Locator:DistanceTo(fullName)
    local target = positions[fullName]
    local mapID, x, y = PlayerMapPosition()
    if not target or not mapID or mapID ~= target.mapID then
        return nil
    end
    local myContinent, myX, myY = WorldPosition(mapID, x, y)
    local continent, targetX, targetY = WorldPosition(target.mapID, target.x, target.y)
    if not myContinent or myContinent ~= continent then
        return nil
    end
    local dx, dy = targetX - myX, targetY - myY
    return math.sqrt(dx * dx + dy * dy)
end

local function OnAnswer(sender, x, y)
    local now = GetTime()
    x, y = tonumber(x), tonumber(y)
    -- Nur Antworten auf die eigene Anfrage; während eines TRP3-Kartenscans
    -- könnten sie zu einer anderen Karte gehören.
    if not x or not y or not scanMapID or now - lastScanAt > ANSWER_WINDOW or now - trp3ScanAt < TRP3_SCAN_BLOCK then
        return
    end
    local fullName = ns:FullName(sender)
    if not fullName or IsIgnored(fullName) then
        return
    end
    positions[fullName] = { mapID = scanMapID, x = x, y = y, at = now }
end

local function DisplayedMapID()
    local worldMap = _G.WorldMapFrame
    if type(worldMap) == "table" and type(worldMap.GetMapID) == "function" then
        local ok, mapID = pcall(worldMap.GetMapID, worldMap)
        if ok then
            return mapID
        end
    end
    return nil
end

local function WorldMapOpen()
    local worldMap = _G.WorldMapFrame
    return type(worldMap) == "table" and type(worldMap.IsShown) == "function" and worldMap:IsShown() or false
end

function Locator:IsTRP3Scanning(now)
    return now - trp3ScanAt <= trp3ScanDuration + TRP3_SCAN_MARGIN
end

-- Soll eine Ortungsantwort in TRP3s Kartenliste? Nur während TRP3 selbst
-- scannt, und nicht, wenn kurz vorher eine CrimeWarden-Anfrage für eine
-- andere Karte verschickt wurde (dann ist unklar, zu welcher Karte sie gehört).
-- Außerhalb von TRP3-Scans würde TRP3 die Antworten ohnehin nicht anzeigen,
-- sondern nur sammeln.
function Locator:PassToTRP3(now)
    if not self:IsTRP3Scanning(now) then
        return false
    end
    local ownPending = now - lastScanAt <= ANSWER_WINDOW
    return not (ownPending and scanMapID ~= trp3ScanMapID)
end

local function FilterTRP3Answers(manager)
    if type(manager.getByID) ~= "function" then
        return
    end
    local ok, scanner = pcall(manager.getByID, "playerScan")
    if not ok or type(scanner) ~= "table" or type(scanner.OnScanDataReceived) ~= "function" then
        return
    end
    trp3ScanDuration = tonumber(scanner.duration) or trp3ScanDuration
    local original = scanner.OnScanDataReceived
    scanner.OnScanDataReceived = function(...)
        if Locator:PassToTRP3(GetTime()) then
            return original(...)
        end
    end
end

local function EnsureHandler(broadcast)
    if handlerRegistered then
        return
    end
    handlerRegistered = pcall(broadcast.registerP2PCommand, SCAN_COMMAND, OnAnswer)
    local manager = ScannersManager()
    if manager and type(manager.launch) == "function" then
        hooksecurefunc(manager, "launch", function()
            trp3ScanAt = GetTime()
            trp3ScanMapID = DisplayedMapID()
        end)
        FilterTRP3Answers(manager)
    end
end

function Locator:Scan(now)
    local broadcast = Broadcast()
    local mapID = PlayerMapPosition()
    if not broadcast or not mapID then
        return false
    end
    EnsureHandler(broadcast)
    -- Bei offener Weltkarte könnte gleich ein TRP3-Kartenscan starten.
    if WorldMapOpen() or self:IsTRP3Scanning(now) then
        return false
    end
    scanMapID = mapID
    lastScanAt = now
    return pcall(broadcast.broadcast, SCAN_COMMAND, mapID)
end

function Locator:IsAvailable()
    return Broadcast() ~= nil
end

local function BuildInfo(fullName, position, distance)
    local guid = ns.knownGuids[fullName]
    local name = Ambiguate(fullName, "none")
    local info = {
        guid = guid,
        name = name,
        fullName = fullName,
        source = "locator",
        distance = math.floor(distance + 0.5),
        seenAt = position.at,
        hostile = false,
        attackable = false,
    }
    info.className, info.classFile, info.race = ns:ClassInfo(guid)
    info.rpName, info.rpStatus, info.hasProfile, info.characterID = ns.TRP3:GetInfoByID(fullName, name)
    return info
end

-- Schickt bei Bedarf eine Anfrage und baut die Liste aus den Antworten.
-- Gibt true zurück, wenn sich etwas geändert hat.
-- Nach dem Schließen der Weltkarte sofort orten, statt bis zu einem ganzen
-- Takt zu warten. Läuft noch ein TRP3-Kartenscan, direkt nach dessen Ende.
function Locator:OnWorldMapClosed(now)
    if not ns.db or not ns.db.sources.locator or not ns:IsActive() then
        return
    end
    if self:IsTRP3Scanning(now) then
        nextScanAt = trp3ScanAt + trp3ScanDuration + TRP3_SCAN_MARGIN + 0.1
        return
    end
    nextScanAt = now + ns.db.sources.locatorInterval
    self:Scan(now)
end

-- Die Weltkarte kann später geladen werden als CrimeWarden; deshalb wird bei
-- jedem Takt geprüft, ob sie schon da ist.
local function HookWorldMap()
    local worldMap = _G.WorldMapFrame
    if mapHooked or type(worldMap) ~= "table" or type(worldMap.HookScript) ~= "function" then
        return
    end
    mapHooked = pcall(worldMap.HookScript, worldMap, "OnHide", function()
        Locator:OnWorldMapClosed(GetTime())
    end)
end

function Locator:Update(now)
    local sources = ns.db.sources
    local changed = false
    HookWorldMap()
    -- Keine Anfragen im Leerlauf (Fenster zu, Modus Just): niemand braucht sie.
    if sources.locator and now >= nextScanAt and ns:IsActive() then
        nextScanAt = now + sources.locatorInterval
        self:Scan(now)
    end

    local maxAge = sources.locatorInterval * 2 + ANSWER_WINDOW
    for fullName, position in pairs(positions) do
        local distance = sources.locator and now - position.at <= maxAge and self:DistanceTo(fullName)
        if distance then
            if roster:Set(fullName, BuildInfo(fullName, position, distance)) then
                changed = true
            end
        else
            positions[fullName] = nil
        end
    end
    for key in pairs(roster.entries) do
        if not positions[key] then
            roster:Remove(key)
            changed = true
        end
    end
    return changed
end

function Locator:Init()
    nextScanAt = GetTime() + 2 -- dem TRP3-Kanal nach dem Einloggen etwas Zeit lassen
    HookWorldMap()
end
