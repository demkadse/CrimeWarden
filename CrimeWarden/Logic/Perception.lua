local _, ns = ...

-- Reine Logik ohne WoW-API: Wahrnehmungswurf "Bemerke ich diese Person?".
-- W20, je näher, desto leichter. Das Ergebnis sieht nur der Würfelnde; damit
-- das nicht zum Neuwürfeln verleitet, gilt pro Person ein Wurf für
-- LOCK_SECONDS, und so lange bleibt das Ergebnis stehen.
local Perception = {}
ns.Perception = Perception

Perception.DIE = 20
Perception.LOCK_SECONDS = 300
Perception.NEAR_YARDS = 10
Perception.FAR_YARDS = 30
Perception.DC_NEAR = 6 -- bis 10 m
Perception.DC_MID = 11 -- bis 30 m, auch bei unbekannter Entfernung
Perception.DC_FAR = 16 -- über 30 m

-- Zielwert (ab dieser Augenzahl bemerkt) für einen Listeneintrag.
function Perception.Difficulty(entry)
    local distance = entry.distance or entry.rangeUpper
    if distance then
        if distance <= Perception.NEAR_YARDS then
            return Perception.DC_NEAR
        elseif distance <= Perception.FAR_YARDS then
            return Perception.DC_MID
        end
        return Perception.DC_FAR
    end
    if entry.rangeLower and entry.rangeLower >= Perception.FAR_YARDS then
        return Perception.DC_FAR
    end
    return Perception.DC_MID
end

local methods = {}

function Perception.New(lockSeconds)
    return setmetatable({ lock = lockSeconds or Perception.LOCK_SECONDS, results = {} }, { __index = methods })
end

-- Gültiges Ergebnis für eine Person oder nil (noch nicht oder zu lange her).
function methods:Get(key, now)
    local result = self.results[key]
    if result and now - result.at < self.lock then
        return result
    end
    self.results[key] = nil
    return nil
end

-- Steht noch irgendein Ergebnis? Räumt abgelaufene dabei weg.
function methods:HasAny(now)
    local any = false
    for key in pairs(self.results) do
        if self:Get(key, now) then
            any = true
        end
    end
    return any
end

-- Entfernt abgelaufene Ergebnisse. Gibt true zurück, wenn eins abgelaufen ist
-- (dann muss die Anzeige neu gezeichnet werden).
function methods:Expire(now)
    local expired = false
    for key, result in pairs(self.results) do
        if now - result.at >= self.lock then
            self.results[key] = nil
            expired = true
        end
    end
    return expired
end

-- Restliche Sekunden bis zum nächsten erlaubten Wurf (0 = sofort möglich).
function methods:Remaining(key, now)
    local result = self:Get(key, now)
    return result and math.max(0, math.ceil(self.lock - (now - result.at))) or 0
end

-- Würfelt für eine Person. random(1, DIE) liefert die Augenzahl (in WoW
-- math.random). Gibt das Ergebnis und true zurück, oder das bestehende
-- Ergebnis und false, wenn die Sperre noch läuft.
function methods:Roll(key, difficulty, now, random)
    local existing = self:Get(key, now)
    if existing then
        return existing, false
    end
    local roll = random(1, Perception.DIE)
    local result = { roll = roll, difficulty = difficulty, noticed = roll >= difficulty, at = now }
    self.results[key] = result
    return result, true
end
