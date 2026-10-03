local _, ns = ...

-- Sammelt alle Spieler mit sichtbarer Namensplakette. Die Liste ist live:
-- Verschwindet die Plakette, verschwindet der Spieler aus der Liste.
-- Der Takt (1 s) treibt auch die übrigen Quellen an.
local Scanner = {}
ns.Scanner = Scanner

Scanner.TICK_SECONDS = 1 -- Entfernung, Gilde, Profile nachziehen
Scanner.RECONCILE_SECONDS = 5 -- voller Abgleich mit allen Plaketten

local roster = ns.rosters.plate

local guidByUnit = {}
local unitByGuid = {}
local units = {}
local seen = {}
local dirty = false
local nextReconcileAt = 0
local ticker

local eventFrame = CreateFrame("Frame")

local function ReadUnit(unit, guid)
    local name = GetUnitName(unit, true)
    if type(name) ~= "string" or name == "" or name == UNKNOWNOBJECT then
        return nil
    end
    local previous = roster:Get(guid)
    local className, classFile = UnitClass(unit)
    local attackable = UnitCanAttack("player", unit) and true or false
    local info = {
        unit = unit,
        guid = guid,
        name = name,
        fullName = ns:FullName(name),
        source = "plate",
        className = className,
        classFile = classFile,
        race = UnitRace(unit),
        level = UnitLevel(unit),
        guild = GetGuildInfo(unit),
        hostile = not UnitIsFriend("player", unit),
        attackable = attackable,
    }
    local lower, upper, measured = ns.Distance:Measure(unit, attackable)
    if measured then
        info.rangeLower, info.rangeUpper = lower, upper
    elseif previous then
        -- Nicht messbar (z. B. im Kampf): letzten Stand behalten.
        info.rangeLower, info.rangeUpper = previous.rangeLower, previous.rangeUpper
    end
    info.rpName, info.rpStatus, info.hasProfile, info.characterID = ns.TRP3:GetInfo(unit, name)
    ns.knownGuids[info.fullName] = guid
    return info
end

local function Untrack(unit)
    local guid = guidByUnit[unit]
    guidByUnit[unit] = nil
    if guid and unitByGuid[guid] == unit then
        unitByGuid[guid] = nil
        local entry = roster:Get(guid)
        if entry and entry.characterID then
            ns.TRP3:DropRequest(entry.characterID)
        end
        if roster:Remove(guid) then
            dirty = true
        end
    end
end

local function Track(unit, now)
    local guid = UnitExists(unit) and UnitIsPlayer(unit) and not UnitIsUnit(unit, "player") and UnitGUID(unit)
    if guidByUnit[unit] and guidByUnit[unit] ~= guid then
        Untrack(unit)
    end
    if type(guid) ~= "string" or guid == "" then
        return
    end

    local info = ReadUnit(unit, guid)
    if not info then
        return
    end

    local oldUnit = unitByGuid[guid]
    if oldUnit and oldUnit ~= unit then
        guidByUnit[oldUnit] = nil
    end
    unitByGuid[guid] = unit
    guidByUnit[unit] = guid

    if roster:Set(guid, info) then
        dirty = true
    end
    if info.characterID and not info.hasProfile then
        ns.TRP3:QueueRequest(info.characterID, now)
    end
end

local function TokenOf(plate)
    if type(plate) ~= "table" then
        return nil
    end
    if type(plate.GetUnit) == "function" then
        local ok, unit = pcall(plate.GetUnit, plate)
        if ok and type(unit) == "string" and unit ~= "" then
            return unit
        end
    end
    local unit = plate.namePlateUnitToken
    return type(unit) == "string" and unit ~= "" and unit or nil
end

local function Flush()
    if dirty then
        dirty = false
        ns.UI:Refresh()
    end
end

-- Liest alle aktuell vorhandenen Plaketten neu ein und wirft Verwaistes raus.
function Scanner:Capture()
    local now = GetTime()
    for unit in pairs(seen) do
        seen[unit] = nil
    end
    local plates = C_NamePlate.GetNamePlates() or {}
    for index = 1, #plates do
        local unit = TokenOf(plates[index])
        if unit then
            seen[unit] = true
            Track(unit, now)
        end
    end
    for unit in pairs(guidByUnit) do
        if not seen[unit] then
            units[#units + 1] = unit
        end
    end
    for index = #units, 1, -1 do
        Untrack(units[index])
        units[index] = nil
    end
    Flush()
end

function Scanner:Clear()
    for unit in pairs(guidByUnit) do
        guidByUnit[unit] = nil
    end
    for guid in pairs(unitByGuid) do
        unitByGuid[guid] = nil
    end
    if roster:Clear() then
        dirty = true
    end
    Flush()
end

function Scanner:GetGuid(unit)
    return guidByUnit[unit]
end

function Scanner:Tick()
    local now = GetTime()
    if now >= nextReconcileAt then
        nextReconcileAt = now + self.RECONCILE_SECONDS
        self:Capture()
    else
        for unit in pairs(guidByUnit) do
            units[#units + 1] = unit
        end
        for index = #units, 1, -1 do
            Track(units[index], now)
            units[index] = nil
        end
    end
    if ns:IsActive() then
        ns.TRP3:ProcessQueue(now)
    end
    -- Die übrigen Quellen laufen im selben Takt.
    if ns.Group:Update(now) then dirty = true end
    if ns.Locator:Update(now) then dirty = true end
    if ns.Senses:Update(now) then dirty = true end
    if ns.ChatRangeSync:Read() then
        dirty = true
        ns.Config:Refresh()
    end
    -- "vor X s" bei Ortung und Spürsinn mitzählen lassen; abgelaufene
    -- Würfelergebnisse verschwinden lassen.
    if ns.rosters.locator:Count() + ns.rosters.senses:Count() > 0 or ns.perception:Expire(now) then
        dirty = true
    end
    Flush()
end

function Scanner:Init()
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_LEAVING_WORLD")
    self:Capture()
    nextReconcileAt = GetTime() + self.RECONCILE_SECONDS
    if not ticker then
        ticker = C_Timer.NewTicker(self.TICK_SECONDS, function()
            Scanner:Tick()
        end)
    end
end

eventFrame:SetScript("OnEvent", function(_, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
        local now = GetTime()
        Track(unit, now)
        ns.Warden:CheckUnit(unit, now)
        Flush()
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        Untrack(unit)
        Flush()
    elseif event == "PLAYER_ENTERING_WORLD" then
        Scanner:Capture()
    elseif event == "PLAYER_LEAVING_WORLD" then
        Scanner:Clear()
    end
end)
