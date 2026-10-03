local _, ns = ...

-- Reine Logik ohne WoW-API: Umrechnung des Server-Reglers
-- "Chat-Reichweite" (Niedrig ... Normal) in Meter.
local ChatRange = {}
ns.ChatRange = ChatRange

-- "Normal" (ganz rechts) ist laut Spielerschaft zugleich die größte /sagen-
-- Reichweite: 30 m.
ChatRange.NORMAL_YARDS = 30

-- Schätzung: anteilig zum Höchstwert des Reglers (Höchstwert = 30 m). Im Spiel
-- abgelesen (2026-10-02): Der Regler liefert 0.35 bis 1, also vermutlich einen
-- Faktor auf die normale Reichweite; "Niedrig" wären dann etwa 10.5 m. Ob das
-- stimmt, muss ein Test mit zwei Charakteren zeigen.
-- Gibt nil zurück, wenn die Reglerwerte unbrauchbar sind.
function ChatRange.ToYards(value, minValue, maxValue, normalYards)
    normalYards = normalYards or ChatRange.NORMAL_YARDS
    if type(value) ~= "number" or value ~= value or type(maxValue) ~= "number" or maxValue <= 0 then
        return nil
    end
    minValue = type(minValue) == "number" and minValue or 0
    if minValue > maxValue then
        return nil
    end
    value = math.max(minValue, math.min(maxValue, value))
    return math.max(1, math.floor(normalYards * value / maxValue + 0.5))
end

-- Zahl ohne überflüssiges ".0" für die Anzeige.
function ChatRange.FormatNumber(value)
    if type(value) ~= "number" then
        return "?"
    end
    if value == math.floor(value) then
        return tostring(math.floor(value))
    end
    local text = ("%.2f"):format(value):gsub("0+$", ""):gsub("%.$", "")
    return text
end
