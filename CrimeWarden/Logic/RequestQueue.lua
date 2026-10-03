local _, ns = ...

-- Reine Logik ohne WoW-API: gedrosselte Warteschlange für Profilanfragen.
-- Höchstens eine Anfrage pro `interval` Sekunden, dieselbe ID frühestens
-- wieder nach `cooldown` Sekunden.
local RequestQueue = {}
ns.RequestQueue = RequestQueue

local methods = {}

function RequestQueue.New(interval, cooldown)
    return setmetatable({
        interval = interval,
        cooldown = cooldown,
        items = {},
        queued = {},
        lastSent = {},
        nextAt = -math.huge,
    }, { __index = methods })
end

function methods:Push(id, now)
    if type(id) ~= "string" or id == "" or self.queued[id] then
        return false
    end
    local last = self.lastSent[id]
    if last and now - last < self.cooldown then
        return false
    end
    self.queued[id] = true
    self.items[#self.items + 1] = id
    return true
end

-- Nimmt eine wartende ID wieder heraus, z. B. wenn der Spieler weg ist.
function methods:Drop(id)
    if not self.queued[id] then
        return false
    end
    self.queued[id] = nil
    for index = #self.items, 1, -1 do
        if self.items[index] == id then
            table.remove(self.items, index)
        end
    end
    return true
end

-- Gibt die nächste ID zurück, wenn die Drosselung es erlaubt, sonst nil.
function methods:Pop(now)
    if now < self.nextAt or #self.items == 0 then
        return nil
    end
    local id = table.remove(self.items, 1)
    self.queued[id] = nil
    self.lastSent[id] = now
    self.nextAt = now + self.interval
    return id
end

function methods:Size()
    return #self.items
end
