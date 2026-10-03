local _, ns = ...
local L = ns.L
local ChatRange = ns.ChatRange

-- Liest den Server-Regler "Chat-Reichweite" (ChatRangeMenuPopup.Slider)
-- aus, damit die Hörweite ihm folgen kann. CrimeWarden liest nur: Es verstellt
-- den Regler nicht und verändert nichts an der echten Chat-Reichweite.
-- Der Server baut den Regler per eingeschleustem Lua-Code; er kann erst
-- existieren, nachdem man ihn einmal geöffnet hat. Bis dahin gilt die
-- eingestellte Hörweite.
local Sync = {}
ns.ChatRangeSync = Sync

local hooked = false
local current = {}

local function FindSlider()
    local popup = _G.ChatRangeMenuPopup
    local slider = type(popup) == "table" and popup.Slider
    if type(slider) == "table" and type(slider.GetValue) == "function"
        and type(slider.GetMinMaxValues) == "function" then
        return slider
    end
    return nil
end

-- Liest den Regler neu ein. Gibt true zurück, wenn sich die daraus berechnete
-- Hörweite geändert hat.
function Sync:Read()
    local value, minValue, maxValue
    local slider = FindSlider()
    if slider then
        local okValue, readValue = pcall(slider.GetValue, slider)
        local okRange, readMin, readMax = pcall(slider.GetMinMaxValues, slider)
        if okValue and okRange then
            value, minValue, maxValue = readValue, readMin, readMax
        end
        -- Sofort reagieren, wenn der Schieber bewegt wird (nur mithören).
        if not hooked and type(slider.HookScript) == "function" then
            hooked = pcall(slider.HookScript, slider, "OnValueChanged", function()
                if Sync:Read() then
                    ns:SettingsChanged()
                end
            end)
        end
    end
    local yards = ChatRange.ToYards(value, minValue, maxValue)
    local changed = yards ~= current.yards
    current.found = slider ~= nil
    current.value, current.min, current.max, current.yards = value, minValue, maxValue, yards
    return changed
end

-- Umgerechnete Reglerstellung in Metern, oder nil (Regler nicht gefunden).
function Sync:GetYards()
    return current.yards
end

function Sync:IsFollowing()
    return ns.db.chatRange.follow and current.yards ~= nil
end

-- Statuszeile für die Einstellungen.
function Sync:GetStatus()
    if not current.yards then
        return L.CHATRANGE_NOT_FOUND
    end
    local format = ChatRange.FormatNumber
    return L.CHATRANGE_STATUS:format(format(current.value), format(current.min), format(current.max), current.yards)
end
