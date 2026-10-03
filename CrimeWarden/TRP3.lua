local _, ns = ...
local Roster = ns.Roster

-- Anbindung an Total RP 3 in der Version, die auf dem Server läuft (2.3.x).
-- Jeder Zugriff ist abgesichert: Ohne TRP3 oder bei geänderter API zeigt die
-- Liste einfach die normalen Charakternamen.
local TRP3 = {}
ns.TRP3 = TRP3

-- Neue Profildaten brauchen keine eigene Benachrichtigung: Der Scanner liest
-- jede Sekunde alles neu ein. TRP3 fragt Profile über sein Namensplaketten-
-- Modul selbst an; wir helfen nur sparsam nach: alle 2 Sekunden eine
-- Anfrage, je Spieler alle 5 Minuten.
local queue = ns.RequestQueue.New(2, 300)

local function API()
    return type(TRP3_API) == "table" and TRP3_API or nil
end

local function Fn(parent, key)
    return type(parent) == "table" and type(parent[key]) == "function" and parent[key] or nil
end

local function Call(fn, ...)
    if not fn then
        return false
    end
    return pcall(fn, ...)
end

function TRP3:IsLoaded()
    return type(IsAddOnLoaded) == "function" and IsAddOnLoaded("totalRP3") and API() ~= nil or false
end

-- Gibt rpName, rpStatus ("IC"/"OOC"/nil), hasProfile und characterID zurück.
function TRP3:GetInfo(unit, fullName)
    local api = API()
    if not api then
        return nil, nil, false, nil
    end

    local okID, characterID = Call(Fn(api.utils and api.utils.str, "getUnitID"), unit)
    if not okID or type(characterID) ~= "string" or characterID == "" then
        return nil, nil, false, nil
    end
    return self:GetInfoByID(characterID, fullName)
end

-- Wie GetInfo, aber für Spieler ohne Einheit (Ortung, Spürsinn): characterID
-- ist der volle Name "Name-Realm".
function TRP3:GetInfoByID(characterID, fullName)
    local api = API()
    if not api or type(characterID) ~= "string" or characterID == "" then
        return nil, nil, false, nil
    end
    fullName = fullName or characterID

    local register = api.register
    local okKnown, known = Call(Fn(register, "isUnitIDKnown"), characterID)
    if not okKnown or not known then
        return nil, nil, false, characterID
    end
    local okProfile, profileID = Call(Fn(register, "hasProfile"), characterID)
    if not okProfile or not profileID then
        return nil, nil, false, characterID
    end

    local rpName
    local okName, value = Call(Fn(register, "getUnitRPNameWithID"), characterID, fullName)
    if okName then
        rpName = Roster.CleanText(value)
    end
    -- Ohne eigenen RP-Namen liefert TRP3 den Charakternamen zurück.
    if rpName == fullName or rpName == characterID or rpName == fullName:match("^[^-]+") then
        rpName = nil
    end

    local okData, profile = Call(Fn(register, "getUnitIDCurrentProfileSafe"), characterID)
    local status = okData and Roster.RoleplayStatus(profile) or nil
    return rpName, status, true, characterID
end

function TRP3:QueueRequest(characterID, now)
    if Fn(API() and API().r, "sendQuery") then
        queue:Push(characterID, now)
    end
end

function TRP3:DropRequest(characterID)
    queue:Drop(characterID)
end

function TRP3:ProcessQueue(now)
    local characterID = queue:Pop(now)
    if characterID then
        local api = API()
        Call(Fn(api and api.r, "sendQuery"), characterID)
    end
end

-- TRP3 2.3 öffnet bekannte Profile über das Hauptfenster und die Profilseite.
function TRP3:OpenProfile(characterID)
    local api = API()
    local openMainFrame = Fn(api and api.navigation, "openMainFrame")
    local openPage = Fn(api and api.register, "openPageByUnitID")
    if not characterID or not openMainFrame or not openPage then
        return false
    end
    local ok = Call(function()
        openMainFrame()
        openPage(characterID)
    end)
    return ok
end
