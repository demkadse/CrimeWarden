local _, ns = ...
local Range = ns.Range

-- Entfernungsmessung über IsItemInRange (Gegenstände aus Logic/Range.lua).
-- Wie LibRangeCheck: Im Kampf wird bei nicht angreifbaren Spielern nicht
-- gemessen, das Spiel schränkt solche Prüfungen dort ein.
local Distance = {}
ns.Distance = Distance

local function ItemInRange(item, unit)
    local check = C_Item and C_Item.IsItemInRange or IsItemInRange
    if not check then
        return nil
    end
    local ok, result = pcall(check, item, unit)
    if not ok or result == nil then
        return nil
    end
    -- Ältere Clients liefern 1/0 statt true/false.
    return result == true or result == 1
end

-- Lädt die Gegenstandsdaten vor; ohne Cache liefert IsItemInRange nil.
function Distance:Init()
    local request = C_Item and C_Item.RequestLoadItemDataByID
    for _, lists in ipairs({ Range.FRIEND, Range.HARM }) do
        for _, items in pairs(lists) do
            for _, item in ipairs(items) do
                if request then
                    pcall(request, item)
                elseif GetItemInfo then
                    GetItemInfo(item)
                end
            end
        end
    end
end

function Distance:CanMeasure(attackable)
    return attackable or not InCombatLockdown()
end

-- true = höchstens `step` Meter entfernt, false = weiter, nil = unbekannt.
-- `step` muss eine Stufe aus Range.STEPS sein.
function Distance:Within(unit, step, attackable)
    if not self:CanMeasure(attackable) then
        return nil
    end
    local items = (attackable and Range.HARM or Range.FRIEND)[step]
    if not items then
        return nil
    end
    for _, item in ipairs(items) do
        local result = ItemInRange(item, unit)
        if result ~= nil then
            return result
        end
    end
    return nil
end

-- Gibt lower, upper, measured zurück. measured = false heißt: gar nicht
-- messbar, den alten Wert behalten.
function Distance:Measure(unit, attackable)
    if not self:CanMeasure(attackable) then
        return nil, nil, false
    end
    local lower, upper = Range.Measure(function(step)
        return self:Within(unit, step, attackable)
    end)
    if lower or upper then
        return lower, upper, true
    end

    -- Gegenstände noch nicht geladen: grobe Stufen über Duell (ca. 10 m)
    -- und Folgen (ca. 28 m).
    local ok10, within10 = pcall(CheckInteractDistance, unit, 3)
    local ok28, within28 = pcall(CheckInteractDistance, unit, 4)
    if not ok10 or not ok28 then
        return nil, nil, false
    end
    if within10 then
        return nil, 10, true
    elseif within28 then
        return 10, 28, true
    end
    return 28, nil, true
end
