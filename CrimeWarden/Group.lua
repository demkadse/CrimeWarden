local _, ns = ...

-- Quelle "Gruppe": Gruppenmitglieder mit Entfernung, auch außerhalb des
-- Kamerabilds. In der offenen Welt genau über UnitPosition, sonst über die
-- Gegenstands-Reichweiten (die funktionieren mit party/raid-Einheiten
-- unabhängig von der Kamera).
local Group = {}
ns.Group = Group

local roster = ns.rosters.group
local tokens = {}
local active = {}
local eventFrame = CreateFrame("Frame")

local function GroupTokens()
    for index = #tokens, 1, -1 do
        tokens[index] = nil
    end
    if IsInRaid() then
        for index = 1, GetNumGroupMembers() do
            tokens[#tokens + 1] = "raid" .. index
        end
    else
        for index = 1, GetNumSubgroupMembers() do
            tokens[#tokens + 1] = "party" .. index
        end
    end
    return tokens
end

-- Genaue Entfernung in Metern, oder nil (Instanz, anderes Gebiet).
function Group:ExactDistance(unit)
    local playerY, playerX, _, playerInstance = UnitPosition("player")
    local y, x, _, instance = UnitPosition(unit)
    if not playerY or not y or playerInstance ~= instance then
        return nil
    end
    local dx, dy = x - playerX, y - playerY
    return math.sqrt(dx * dx + dy * dy)
end

local function Read(unit)
    if not UnitExists(unit) or UnitIsUnit(unit, "player") or not UnitIsConnected(unit) then
        return nil
    end
    local guid = UnitGUID(unit)
    local name = GetUnitName(unit, true)
    if type(guid) ~= "string" or type(name) ~= "string" or name == "" or name == UNKNOWNOBJECT then
        return nil
    end
    local className, classFile = UnitClass(unit)
    local info = {
        unit = unit,
        guid = guid,
        name = name,
        fullName = ns:FullName(name),
        source = "group",
        className = className,
        classFile = classFile,
        race = UnitRace(unit),
        level = UnitLevel(unit),
        guild = GetGuildInfo(unit),
        hostile = false,
        attackable = false,
    }
    local distance = Group:ExactDistance(unit)
    if distance then
        info.distance = math.floor(distance + 0.5)
    elseif UnitIsVisible(unit) then
        local lower, upper, measured = ns.Distance:Measure(unit, false)
        if measured then
            info.rangeLower, info.rangeUpper = lower, upper
        end
    else
        return nil -- außerhalb der Sichtweite des Clients
    end
    ns.knownGuids[info.fullName] = guid
    info.rpName, info.rpStatus, info.hasProfile, info.characterID = ns.TRP3:GetInfo(unit, name)
    return guid, info
end

-- Liest die Gruppe neu ein. Gibt true zurück, wenn sich etwas geändert hat.
function Group:Update()
    local changed = false
    for key in pairs(active) do
        active[key] = nil
    end
    if ns.db.sources.group then
        for _, unit in ipairs(GroupTokens()) do
            local guid, info = Read(unit)
            if guid then
                active[guid] = true
                if roster:Set(guid, info) then
                    changed = true
                end
            end
        end
    end
    for key in pairs(roster.entries) do
        if not active[key] then
            roster:Remove(key)
            changed = true
        end
    end
    return changed
end

function Group:Init()
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    self:Update()
end

eventFrame:SetScript("OnEvent", function()
    if Group:Update() then
        ns.UI:Refresh()
    end
end)
