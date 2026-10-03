local _, ns = ...
local L = ns.L
local Range = ns.Range

-- Annäherungswarnung (Modus "Unjust"): Kommt ein Spieler näher als die
-- eingestellte Grenze (Standard 50 m), gibt es Banner, Ton und Chatzeile.
-- Geprüft wird fünfmal pro Sekunde über alle Quellen und sofort, wenn eine
-- Namensplakette erscheint. Im Modus "Just" ist sie aus.
local Warden = {}
ns.Warden = Warden

Warden.TICK_SECONDS = 0.2
Warden.MEMORY_SECONDS = 60

local alarm = ns.Alarm.New(Warden.MEMORY_SECONDS)
local ticker
local changed = false
-- Nach dem Einschalten oder einer neuen Grenze: einen Durchlauf lang nur den
-- Stand erfassen, ohne zu melden. Wer dann schon drin ist, löst erst wieder
-- aus, wenn er draußen war und erneut über die Grenze kommt.
local quiet = false

Warden.MAX_YARDS = 50 -- darüber ließe sich das Zurückstellen nicht mehr messen

-- Warngrenzen: eine Stufe aus Range.STEPS zwischen 5 und 50 m. Zurückgestellt
-- wird eine Stufe weiter draußen (50 m -> über 55 m).
function Warden:ClampYards(yards)
    yards = tonumber(yards) or self.MAX_YARDS
    return Range.StepAtOrBelow(math.max(5, math.min(self.MAX_YARDS, yards)))
end

function Warden:GetYards()
    return self:ClampYards(ns.db.warning.yards)
end

-- Zustand neu erfassen, ohne alle Anwesenden auf einmal zu melden.
function Warden:Rebaseline()
    alarm:Reset()
    quiet = true
end

function Warden:SetYards(yards)
    ns.db.warning.yards = self:ClampYards(yards)
    self:Rebaseline()
    return ns.db.warning.yards
end

local function DisplayName(entry)
    local name = entry.rpName or entry.name or "?"
    if entry.rpStatus then
        name = name .. " (" .. L[entry.rpStatus] .. ")"
    end
    if entry.hostile then
        name = name .. " |cffff5050" .. L.HOSTILE .. "|r"
    end
    return name
end

function Warden:Notify(entry, yards)
    local warning = ns.db.warning
    local text = L.WARN_TEXT:format(DisplayName(entry), yards)
    if warning.banner and RaidNotice_AddMessage and RaidWarningFrame then
        local color = ChatTypeInfo and ChatTypeInfo.RAID_WARNING or { r = 1, g = 0.28, b = 0 }
        RaidNotice_AddMessage(RaidWarningFrame, text, color)
    end
    if warning.sound and PlaySound and SOUNDKIT and SOUNDKIT.RAID_WARNING then
        PlaySound(SOUNDKIT.RAID_WARNING, "Master")
    end
    if warning.chat then
        ns:Print(text)
    end
end

-- Zeigt eine Probewarnung mit den aktuellen Einstellungen (Banner, Ton, Chat).
function Warden:TestWarning()
    self:Notify({ name = L.TEST_NAME, rpStatus = "IC" }, self:GetYards())
end

local function IsGroupMember(unit)
    return (UnitInParty and UnitInParty(unit)) or (UnitInRaid and UnitInRaid(unit)) or false
end

local function AlarmKey(entry)
    return entry.fullName or entry.key
end

-- Messung über Gegenstands-Reichweiten an einer Einheit.
local function MeasureUnit(unit, yards, attackable)
    local inside = ns.Distance:Within(unit, yards, attackable)
    local outside = inside == false and ns.Distance:Within(unit, Range.NextStep(yards), attackable) == false
    return inside == true, outside
end

-- inside, outside je nach Quelle: Plaketten über Gegenstände, Gruppe und
-- Ortung über die (live nachgerechnete) Entfernung. Spürsinn hat keine.
local function Measure(entry, yards)
    local distance
    if entry.source == "plate" then
        return MeasureUnit(entry.unit, yards, entry.attackable)
    elseif entry.source == "group" then
        distance = ns.Group:ExactDistance(entry.unit)
        if not distance then
            return MeasureUnit(entry.unit, yards, false)
        end
    elseif entry.source == "locator" then
        distance = ns.Locator:DistanceTo(entry.fullName)
    end
    if not distance then
        return false, false
    end
    return distance <= yards, distance > Range.NextStep(yards)
end

local function Check(entry, now)
    local warning = ns.db.warning
    if not warning.enabled or entry.source == "senses" then
        return
    end
    if warning.ignoreGroup and (entry.source == "group" or (entry.unit and IsGroupMember(entry.unit))) then
        return
    end
    local key = AlarmKey(entry)
    local yards = Warden:GetYards()
    local wasInside = alarm:IsInside(key)
    local inside, outside = Measure(entry, yards)
    if alarm:Update(key, inside, outside, now) and not quiet then
        Warden:Notify(entry, yards)
    end
    if alarm:IsInside(key) ~= wasInside then
        changed = true
    end
end

function Warden:IsInside(entry)
    return ns.db.warning.enabled and alarm:IsInside(AlarmKey(entry))
end

-- Sofortprüfung für eine gerade erschienene Plakette.
function Warden:CheckUnit(unit, now)
    local guid = ns.Scanner:GetGuid(unit)
    local entry = guid and ns.rosters.plate:Get(guid)
    if entry then
        Check(entry, now)
    end
end

function Warden:Tick()
    local now = GetTime()
    ns:ForEachEntry(function(entry)
        Check(entry, now)
    end)
    quiet = false
    alarm:Expire(now)
    if changed then
        changed = false
        ns.UI:Refresh()
    end
end

function Warden:Init()
    ns.db.warning.yards = self:ClampYards(ns.db.warning.yards)
    if not ticker then
        ticker = C_Timer.NewTicker(self.TICK_SECONDS, function()
            Warden:Tick()
        end)
    end
end
