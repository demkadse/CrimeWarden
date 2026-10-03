local _, ns = ...

-- Reine Logik ohne WoW-API: entscheidet, wann die Annäherungswarnung auslöst.
-- Sie löst jedes Mal aus, wenn ein Spieler von außen über die Grenze kommt.
-- Erneut scharf wird sie erst, wenn er sicher wieder draußen ist (eine
-- Entfernungsstufe Abstand, damit es an der Grenze nicht flackert).
-- Der Zustand bleibt `memory` Sekunden erhalten, auch wenn der Spieler kurz
-- aus dem Blickfeld gerät; Kameradrehen löst also keine neue Warnung aus.
local Alarm = {}
ns.Alarm = Alarm

local methods = {}

function Alarm.New(memory)
    return setmetatable({ memory = memory, states = {} }, { __index = methods })
end

-- inside: sicher innerhalb der Grenze. outside: sicher jenseits der
-- Rückstellgrenze. Beides false = unbekannt, nichts ändert sich.
-- Gibt true zurück, wenn jetzt gewarnt werden soll.
function methods:Update(guid, inside, outside, now)
    local state = self.states[guid]
    if not state then
        state = { armed = true }
        self.states[guid] = state
    end
    state.seen = now
    if inside then
        if state.armed then
            state.armed = false
            return true
        end
    elseif outside then
        state.armed = true
    end
    return false
end

function methods:IsInside(guid)
    local state = self.states[guid]
    return state ~= nil and not state.armed
end

-- Vergisst Spieler, die länger als `memory` Sekunden nicht geprüft wurden.
function methods:Expire(now)
    for guid, state in pairs(self.states) do
        if now - state.seen > self.memory then
            self.states[guid] = nil
        end
    end
end

function methods:Reset()
    for guid in pairs(self.states) do
        self.states[guid] = nil
    end
end
