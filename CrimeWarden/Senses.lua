local _, ns = ...

-- Quelle "Spürsinn": Wer in der Nähe spricht (/sagen), emotet oder kämpft
-- bzw. zaubert, wird bemerkt, auch außerhalb des Kamerabilds. Eine
-- Entfernung gibt es nicht; der Eintrag zeigt, wie lange das her ist, und
-- verblasst nach MEMORY_SECONDS.
local Senses = {}
ns.Senses = Senses

Senses.MEMORY_SECONDS = 60

local PLAYER_FLAG = COMBATLOG_OBJECT_TYPE_PLAYER or 0x400
local MINE_FLAG = COMBATLOG_OBJECT_AFFILIATION_MINE or 0x1
local HOSTILE_FLAG = COMBATLOG_OBJECT_REACTION_HOSTILE or 0x40

local roster = ns.rosters.senses
local noticed = {} -- [fullName] = { guid, at, kind, hostile }
local eventFrame = CreateFrame("Frame")

local CHAT_KINDS = {
    CHAT_MSG_SAY = "SAY",
    CHAT_MSG_EMOTE = "EMOTE",
    CHAT_MSG_TEXT_EMOTE = "EMOTE",
}

local function Notice(name, guid, kind, hostile)
    if not ns.db or not ns.db.sources.senses or type(name) ~= "string" or name == "" then
        return
    end
    if guid and guid == UnitGUID("player") then
        return
    end
    local fullName = ns:FullName(name)
    local now = GetTime()
    local entry = noticed[fullName]
    if not entry then
        entry = {}
        noticed[fullName] = entry
    elseif entry.kind ~= "COMBAT" and kind == "COMBAT" and now - entry.at < 10 then
        -- Gesprochenes ist aussagekräftiger als Kampflärm: kurz behalten.
        entry.at = now
        return
    end
    entry.guid = guid or entry.guid
    entry.at = now
    entry.kind = kind
    -- Chat kennt keine Feindschaft; eine Markierung aus dem Kampflog bleibt.
    entry.hostile = (hostile or entry.hostile) and true or false
    if guid then
        ns.knownGuids[fullName] = guid
    end
end

local function IsOtherPlayer(flags)
    return flags and bit.band(flags, PLAYER_FLAG) ~= 0 and bit.band(flags, MINE_FLAG) == 0
end

local function OnCombatLog()
    local _, _, _, sourceGUID, sourceName, sourceFlags, _, destGUID, destName, destFlags = CombatLogGetCurrentEventInfo()
    if IsOtherPlayer(sourceFlags) then
        Notice(sourceName, sourceGUID, "COMBAT", bit.band(sourceFlags, HOSTILE_FLAG) ~= 0)
    end
    if IsOtherPlayer(destFlags) then
        Notice(destName, destGUID, "COMBAT", bit.band(destFlags, HOSTILE_FLAG) ~= 0)
    end
end

-- Baut die Liste aus dem Bemerkten. Gibt true zurück, wenn sich etwas
-- geändert hat.
function Senses:Update(now)
    local enabled = ns.db.sources.senses
    local changed = false
    for fullName, entry in pairs(noticed) do
        if not enabled or now - entry.at > self.MEMORY_SECONDS then
            noticed[fullName] = nil
        else
            local name = Ambiguate(fullName, "none")
            local info = {
                guid = entry.guid,
                name = name,
                fullName = fullName,
                source = "senses",
                seenAt = entry.at,
                detail = entry.kind,
                hostile = entry.hostile,
                attackable = entry.hostile,
            }
            info.className, info.classFile, info.race = ns:ClassInfo(entry.guid)
            info.rpName, info.rpStatus, info.hasProfile, info.characterID = ns.TRP3:GetInfoByID(fullName, name)
            if roster:Set(fullName, info) then
                changed = true
            end
        end
    end
    for key in pairs(roster.entries) do
        if not noticed[key] then
            roster:Remove(key)
            changed = true
        end
    end
    return changed
end

function Senses:Init()
    for event in pairs(CHAT_KINDS) do
        eventFrame:RegisterEvent(event)
    end
    eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        OnCombatLog()
    else
        local _, sender, _, _, _, _, _, _, _, _, _, guid = ...
        Notice(sender, guid, CHAT_KINDS[event], false)
    end
end)
