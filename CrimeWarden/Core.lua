local addonName, ns = ...
local L = ns.L
local Roster = ns.Roster

ns.name = addonName

ns.defaults = {
    window = {
        shown = true,
        locked = false,
        point = "CENTER",
        relPoint = "CENTER",
        x = 0,
        y = 0,
        width = 340,
        height = 300,
        scale = 1,
    },
    hideHostile = false,
    sortBy = "distance", -- "distance" oder "name"
    radius = 50, -- Umkreis der Liste in Metern
    sayRange = 30, -- /sagen-Hörweite in Metern (laut Spielerschaft auf dem Server)
    -- Hörweite dem Server-Regler "Chat-Reichweite" folgen lassen (nur lesen)
    chatRange = { follow = true },
    minimap = { show = true, angle = 200 },
    -- enabled = Modus "Unjust" (Warnungen), aus = "Just" (keine Warnungen)
    warning = {
        enabled = true,
        yards = 50,
        sound = true,
        banner = true,
        chat = true,
        ignoreGroup = true,
    },
    -- Zusätzliche Quellen neben den Namensplaketten
    sources = {
        group = true,
        locator = true,
        locatorInterval = 10, -- Sekunden zwischen zwei TRP3-Ortungen
        senses = true,
    },
}

-- Eine Liste pro Quelle, in der Reihenfolge von Roster.SOURCES.
ns.rosters = {}
ns.rosterList = {}
for _, source in ipairs(Roster.SOURCES) do
    ns.rosters[source] = Roster.New()
    ns.rosterList[#ns.rosterList + 1] = ns.rosters[source]
end

-- Voller Name -> GUID, aus allen Quellen, die eine GUID kennen. Damit haben
-- auch georteter oder gespürte Spieler Klasse und Volk.
ns.knownGuids = {}

-- Klasse und Volk zu einer GUID: className, classFile, race (oder nil).
function ns:ClassInfo(guid)
    if not guid or not GetPlayerInfoByGUID then
        return nil
    end
    local ok, className, classFile, race = pcall(GetPlayerInfoByGUID, guid)
    if not ok then
        return nil
    end
    return className, classFile, race
end

-- Wahrnehmungswürfe pro Person (nur für den Spieler selbst sichtbar).
ns.perception = ns.Perception.New()

local mergeSeen = {}

-- fn(entry) für jeden Spieler einmal, aus der genauesten Quelle.
function ns:ForEachEntry(fn)
    Roster.ForEachMerged(ns.rosterList, fn, mergeSeen)
end

function ns:CollectEntries(list)
    return Roster.Collect(list, ns.rosterList, ns.db.sortBy, ns.db.hideHostile, ns.db.radius)
end

function ns:FullName(name)
    return Roster.FullName(name, GetNormalizedRealmName and GetNormalizedRealmName() or nil)
end

-- Umkreis der Liste: eine Stufe aus Range.STEPS zwischen 10 und 60 m.
function ns:ClampRadius(yards)
    return ns.Range.StepAtOrBelow(math.max(10, tonumber(yards) or 50))
end

-- Wirksame Hörweite: die umgerechnete Stellung des Server-Reglers, wenn
-- CrimeWarden ihm folgt und ihn gefunden hat, sonst die eingestellte Hörweite.
function ns:GetSayRange()
    if ns.db.chatRange.follow then
        local yards = ns.ChatRangeSync:GetYards()
        if yards then
            return yards
        end
    end
    return ns.db.sayRange
end

-- /sagen-Hörweite: eine Stufe aus Range.STEPS zwischen 10 und 60 m.
function ns:ClampSayRange(yards)
    return ns.Range.StepAtOrBelow(math.max(10, math.min(60, tonumber(yards) or 30)))
end

-- Abstand der TRP3-Ortung: 5 bis 60 Sekunden in 5er-Schritten.
function ns:ClampInterval(seconds)
    seconds = math.floor((tonumber(seconds) or 10) / 5 + 0.5) * 5
    return math.max(5, math.min(60, seconds))
end

-- Ergänzt fehlende oder falsch typisierte Werte, vorhandene bleiben erhalten.
local function CopyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            CopyDefaults(target[key], value)
        elseif type(target[key]) ~= type(value) then
            target[key] = value
        end
    end
end

function ns:Print(text, ...)
    if select("#", ...) > 0 then
        text = text:format(...)
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff" .. L.TITLE .. "|r " .. text)
end

-- Erklärender Tooltip für ein Bedienelement. title und body dürfen
-- Funktionen sein, dann wird der Text beim Anzeigen erzeugt (z. B. mit dem
-- aktuellen Zustand).
function ns:SetTooltip(frame, title, body)
    frame:SetScript("OnEnter", function(owner)
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:AddLine(type(title) == "function" and title() or title)
        local text = type(body) == "function" and body() or body
        if text then
            GameTooltip:AddLine(text, 0.9, 0.9, 0.9, true)
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function(owner)
        if GameTooltip:IsOwned(owner) then
            GameTooltip:Hide()
        end
    end)
end

function ns:ResetWindow()
    local window = ns.db.window
    for key, value in pairs(ns.defaults.window) do
        if key ~= "shown" then
            window[key] = value
        end
    end
    ns.UI:ApplyWindow()
end

-- Nach jeder Einstellungsänderung: Fenster und Einstellungsseite nachziehen.
function ns:SettingsChanged()
    ns.UI:Refresh()
    ns.Config:Refresh()
end

function ns:IsUnjust()
    return ns.db.warning.enabled
end

-- Braucht gerade jemand die Daten? Bei geschlossenem Fenster im Modus Just
-- zeigt und warnt CrimeWarden nichts; dann verschickt es auch keine Ortungs-
-- oder Profilanfragen an andere Spieler.
function ns:IsActive()
    return ns:IsUnjust() or ns.UI:IsShown()
end

function ns:SetUnjust(unjust)
    if unjust and not ns:IsUnjust() then
        -- Wer beim Einschalten schon nah ist, wird nicht auf einen Schlag gemeldet.
        ns.Warden:Rebaseline()
    end
    ns.db.warning.enabled = unjust and true or false
    if unjust then
        ns:Print(L.MODE_UNJUST_SET, ns.Warden:GetYards())
    else
        ns:Print(L.MODE_JUST_SET)
    end
    ns:SettingsChanged()
end

local function ReadCVar(name)
    if C_CVar and C_CVar.GetCVar then
        return C_CVar.GetCVar(name)
    end
    return GetCVar(name)
end

-- Plaketten-Sichtweite: mindestens der Umkreis der Liste und so weit, dass
-- sich die Rückstellung der Warnung noch messen lässt (Warngrenze 50 m ->
-- Rückstellung über 55 m -> 60 m). Mehr als 60 m gibt es nicht.
local function PlateDistanceNeeded()
    local rearm = ns.Range.NextStep(ns.Warden:GetYards()) or 0
    return math.min(60, math.max(ns.db.radius, rearm + 5))
end

local function PlateDistanceReady()
    local distance = tonumber(ReadCVar("nameplateMaxDistance"))
    return not distance or distance >= PlateDistanceNeeded()
end

-- Freundliche Plaketten müssen an sein, auch außerhalb des Kampfes
-- erscheinen ("Namensplaketten immer anzeigen") und weit genug reichen.
function ns:NameplatesReady()
    return ReadCVar("nameplateShowFriends") == "1" and ReadCVar("nameplateShowAll") == "1"
        and PlateDistanceReady()
end

function ns:EnableNameplates()
    if InCombatLockdown() then
        ns:Print(L.PLATES_COMBAT)
        return false
    end
    SetCVar("nameplateShowFriends", "1")
    SetCVar("nameplateShowAll", "1")
    if not PlateDistanceReady() then
        SetCVar("nameplateMaxDistance", tostring(PlateDistanceNeeded()))
    end
    ns:Print(L.PLATES_ENABLED)
    ns.Scanner:Capture()
    ns:SettingsChanged()
    return true
end

local function PrintHelp()
    ns:Print(L.HELP_HEADER)
    for _, key in ipairs({ "HELP_TOGGLE", "HELP_OPTIONS", "HELP_MODE", "HELP_WARN_YARDS", "HELP_RADIUS", "HELP_SAY_RANGE",
        "HELP_CHATRANGE",
        "HELP_GROUP", "HELP_LOCATOR", "HELP_SENSES", "HELP_PLATES", "HELP_RESET", "HELP_HELP" }) do
        DEFAULT_CHAT_FRAME:AddMessage("  " .. L[key])
    end
end

-- "an"/"aus" -> true/false, sonst nil.
local function OnOff(argument)
    if argument == "an" or argument == "on" then
        return true
    elseif argument == "aus" or argument == "off" then
        return false
    end
    return nil
end

local function StateText(value)
    return value and L.STATE_ON or L.STATE_OFF
end

-- Schaltet eine Quelle (gruppe, ortung, spürsinn) und meldet den Stand.
local function HandleSource(key, label, argument)
    local value = OnOff(argument)
    if value ~= nil then
        ns.db.sources[key] = value
        ns:SourcesChanged()
    end
    ns:Print(L.SOURCE_STATE, label, StateText(ns.db.sources[key]))
end

function ns:SourcesChanged()
    ns.Group:Update(GetTime())
    ns.Locator:Update(GetTime())
    ns.Senses:Update(GetTime())
    ns:SettingsChanged()
end

local function HandleSlash(message)
    local command = (message or ""):match("^%s*(.-)%s*$"):lower()
    local word, argument = command:match("^(%S+)%s*(.-)$")

    if word == "unjust" then
        ns:SetUnjust(true)
    elseif word == "just" or word == "righteous" then
        ns:SetUnjust(false)
    elseif word == "modus" or word == "mode" then
        ns:SetUnjust(not ns:IsUnjust())
    elseif word == "warnung" or word == "warn" then
        local yards = tonumber(argument)
        if yards then
            ns:Print(L.WARN_YARDS_SET, ns.Warden:SetYards(yards))
            ns:SettingsChanged()
        elseif OnOff(argument) ~= nil then
            ns:SetUnjust(OnOff(argument))
        else
            ns:Print(ns:IsUnjust() and L.MODE_UNJUST_SET or L.MODE_JUST_SET, ns.Warden:GetYards())
        end
    elseif word == "umkreis" or word == "radius" then
        if tonumber(argument) then
            ns.db.radius = ns:ClampRadius(argument)
        end
        ns:Print(L.RADIUS_SET, ns.db.radius)
        ns:SettingsChanged()
    elseif word == "hörweite" or word == "hoerweite" or word == "earshot" then
        if tonumber(argument) then
            ns.db.sayRange = ns:ClampSayRange(argument)
        end
        if ns.ChatRangeSync:IsFollowing() then
            ns:Print(L.SAY_RANGE_FOLLOWING, ns:GetSayRange(), ns.db.sayRange)
        else
            ns:Print(L.SAY_RANGE_SET, ns.db.sayRange)
        end
        ns:SettingsChanged()
    elseif word == "regler" or word == "slider" then
        local value = OnOff(argument)
        if value ~= nil then
            ns.db.chatRange.follow = value
            ns.ChatRangeSync:Read()
        end
        ns:Print(L.CHATRANGE_STATE, StateText(ns.db.chatRange.follow), ns.ChatRangeSync:GetStatus())
        ns:SettingsChanged()
    elseif word == "gruppe" or word == "group" then
        HandleSource("group", L.SRC_GROUP, argument)
    elseif word == "ortung" or word == "locate" then
        if tonumber(argument) then
            ns.db.sources.locatorInterval = ns:ClampInterval(argument)
            ns:Print(L.LOCATOR_INTERVAL_SET, ns.db.sources.locatorInterval)
            ns:SettingsChanged()
        else
            HandleSource("locator", L.SRC_LOCATOR, argument)
        end
    elseif word == "spürsinn" or word == "spuersinn" or word == "senses" then
        HandleSource("senses", L.SRC_SENSES, argument)
    elseif command == "" then
        ns.UI:Toggle()
    elseif command == "optionen" or command == "options" then
        if not ns.Config:Open() then
            ns:Print(L.OPTIONS_FAILED)
        end
    elseif command == "plaketten" or command == "plates" then
        ns:EnableNameplates()
    elseif command == "reset" then
        ns:ResetWindow()
        ns:Print(L.WINDOW_RESET)
    elseif command == "hilfe" or command == "help" then
        PrintHelp()
    else
        ns:Print(L.UNKNOWN_CMD)
        PrintHelp()
    end
end

local function Initialize()
    if type(CrimeWardenDB) ~= "table" then
        CrimeWardenDB = {}
    end
    CopyDefaults(CrimeWardenDB, ns.defaults)
    if CrimeWardenDB.sortBy ~= "name" then
        CrimeWardenDB.sortBy = "distance"
    end
    CrimeWardenDB.radius = ns:ClampRadius(CrimeWardenDB.radius)
    CrimeWardenDB.sayRange = ns:ClampSayRange(CrimeWardenDB.sayRange)
    CrimeWardenDB.sources.locatorInterval = ns:ClampInterval(CrimeWardenDB.sources.locatorInterval)
    ns.db = CrimeWardenDB

    ns.Distance:Init()
    ns.UI:Init()
    ns.MinimapButton:Init()
    ns.Config:Init()
    ns.Scanner:Init()
    ns.Group:Init()
    ns.Locator:Init()
    ns.Senses:Init()
    ns.ChatRangeSync:Read()
    ns.Warden:Init()
    ns.UI:ApplyWindow()

    local version = GetAddOnMetadata and GetAddOnMetadata(addonName, "Version") or "?"
    ns:Print(L.LOADED, version)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, _, loadedName)
    if loadedName == addonName then
        self:UnregisterEvent("ADDON_LOADED")
        Initialize()
    end
end)

SLASH_CRIMEWARDEN1 = "/warden"
SLASH_CRIMEWARDEN2 = "/crimewarden"
SlashCmdList.CRIMEWARDEN = HandleSlash
