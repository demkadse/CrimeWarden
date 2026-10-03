local _, ns = ...

-- Reine Logik ohne WoW-API: Listen der Spieler in der Nähe. Jede Quelle
-- (Namensplaketten, Gruppe, TRP3-Ortung, Spürsinn) führt eine eigene Liste;
-- Roster.Collect führt sie über den vollen Namen zusammen.
local Roster = {}
ns.Roster = Roster

-- Quellen in absteigender Genauigkeit. Taucht ein Spieler mehrfach auf,
-- gewinnt die frühere.
Roster.SOURCES = { "plate", "group", "locator", "senses" }

-- Alle Felder eines Eintrags. Set() übernimmt immer den vollständigen Satz,
-- ein fehlendes Feld bedeutet also "jetzt unbekannt".
-- rangeLower/rangeUpper: weiter als rangeLower, höchstens rangeUpper Meter.
-- distance: genaue Entfernung in Metern (Gruppe, Ortung).
-- seenAt: Zeitpunkt der Information (Ortung, Spürsinn). detail: Art des Spürens.
Roster.FIELDS = {
    "unit", "guid", "name", "fullName", "source", "rpName", "rpStatus", "hasProfile", "characterID",
    "className", "classFile", "race", "level", "guild", "hostile", "attackable",
    "rangeLower", "rangeUpper", "distance", "seenAt", "detail",
}

-- Voller Name "Name-Realm" ohne Leerzeichen im Realm, damit alle Quellen
-- denselben Schlüssel benutzen.
function Roster.FullName(name, defaultRealm)
    if type(name) ~= "string" or name == "" then
        return nil
    end
    local base, realm = name:match("^([^-]+)-(.+)$")
    if not base then
        base, realm = name, defaultRealm or ""
    end
    realm = realm:gsub("%s", "")
    if realm == "" then
        return base
    end
    return base .. "-" .. realm
end

-- Sortierschlüssel für die Entfernung: unbekannt kommt zuletzt.
function Roster.DistanceKey(entry)
    if entry.distance then
        return entry.distance
    elseif entry.rangeUpper then
        return entry.rangeUpper
    elseif entry.rangeLower then
        return entry.rangeLower + 0.5
    end
    return math.huge
end

-- Nur Spieler, die sicher weiter als maxRange weg sind, fallen heraus.
function Roster.WithinRadius(entry, maxRange)
    if not maxRange then
        return true
    end
    if entry.distance then
        return entry.distance <= maxRange
    end
    return not (entry.rangeLower and entry.rangeLower >= maxRange)
end

-- Kann der Spieler dich per /sagen hören? true, false oder nil (unbekannt).
-- Wer gerade gesprochen oder emotet hat (Spürsinn), ist sicher in Hörweite.
function Roster.InEarshot(entry, sayRange)
    if entry.distance then
        return entry.distance <= sayRange
    elseif entry.rangeUpper and entry.rangeUpper <= sayRange then
        return true
    elseif entry.rangeLower and entry.rangeLower >= sayRange then
        return false
    elseif entry.source == "senses" and (entry.detail == "SAY" or entry.detail == "EMOTE") then
        return true
    end
    return nil
end

-- Total RP 3 speichert den Status als character.RP: 1 = im Charakter, 2 = nicht.
function Roster.RoleplayStatus(profile)
    local character = type(profile) == "table" and profile.character
    local status = type(character) == "table" and character.RP
    if status == 1 then
        return "IC"
    elseif status == 2 then
        return "OOC"
    end
    return nil
end

-- Entfernt Farb-, Textur- und Link-Codes aus Profiltexten anderer Spieler.
function Roster.CleanText(value)
    if type(value) ~= "string" then
        return nil
    end
    value = value:gsub("|c%x%x%x%x%x%x%x%x", "")
    value = value:gsub("|r", "")
    value = value:gsub("|T.-|t", "")
    value = value:gsub("|A.-|a", "")
    value = value:gsub("|H.-|h", "")
    value = value:gsub("|h", "")
    value = value:gsub("[\r\n]+", " ")
    value = value:match("^%s*(.-)%s*$")
    if value == "" then
        return nil
    end
    return value
end

function Roster.DisplayName(entry)
    return entry.rpName or entry.name or "?"
end

local function ByName(a, b)
    local aName, bName = Roster.DisplayName(a):lower(), Roster.DisplayName(b):lower()
    if aName ~= bName then
        return aName < bName
    end
    return (a.fullName or a.key) < (b.fullName or b.key)
end

local function ByDistance(a, b)
    local aKey, bKey = Roster.DistanceKey(a), Roster.DistanceKey(b)
    if aKey ~= bKey then
        return aKey < bKey
    end
    return ByName(a, b)
end

local methods = {}

function Roster.New()
    return setmetatable({ entries = {}, count = 0 }, { __index = methods })
end

-- Legt einen Eintrag an oder aktualisiert ihn. Gibt true zurück, wenn sich
-- etwas Sichtbares geändert hat.
function methods:Set(key, info)
    local entry = self.entries[key]
    local changed = false
    if not entry then
        entry = { key = key }
        self.entries[key] = entry
        self.count = self.count + 1
        changed = true
    end
    for _, field in ipairs(Roster.FIELDS) do
        local value = info[field]
        if entry[field] ~= value then
            entry[field] = value
            changed = true
        end
    end
    return changed
end

function methods:Remove(key)
    if not self.entries[key] then
        return false
    end
    self.entries[key] = nil
    self.count = self.count - 1
    return true
end

function methods:Get(key)
    return self.entries[key]
end

function methods:Count()
    return self.count
end

function methods:Clear()
    local hadEntries = self.count > 0
    for key in pairs(self.entries) do
        self.entries[key] = nil
    end
    self.count = 0
    return hadEntries
end

-- Ruft fn(entry) für jeden Spieler genau einmal auf, aus der genauesten
-- Liste, in der er vorkommt. rosters: Listen in der Reihenfolge von SOURCES.
function Roster.ForEachMerged(rosters, fn, seen)
    seen = seen or {}
    for key in pairs(seen) do
        seen[key] = nil
    end
    for _, roster in ipairs(rosters) do
        for key, entry in pairs(roster.entries) do
            local identity = entry.fullName or key
            if not seen[identity] then
                seen[identity] = true
                fn(entry)
            end
        end
    end
end

-- Zusammengeführte, gefilterte und sortierte Liste für die Anzeige. `list`
-- wird geleert und wiederverwendet.
function Roster.Collect(list, rosters, sortBy, hideHostile, maxRange)
    for index = #list, 1, -1 do
        list[index] = nil
    end
    Roster.ForEachMerged(rosters, function(entry)
        if not (hideHostile and entry.hostile) and Roster.WithinRadius(entry, maxRange) then
            list[#list + 1] = entry
        end
    end)
    table.sort(list, sortBy == "name" and ByName or ByDistance)
    return list
end
