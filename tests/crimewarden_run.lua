-- Tests für die reine Logik von "CrimeWarden" (CrimeWarden/Logic). Laufen ohne WoW:
--   luajit tests/crimewarden_run.lua     (aus dem Projektordner)

local ns = {}
local function load(path)
    local chunk = assert(loadfile("CrimeWarden/Logic/" .. path))
    chunk("CrimeWarden", ns)
end
load("Roster.lua")
load("RequestQueue.lua")
load("Range.lua")
load("Alarm.lua")
load("ChatRange.lua")
load("Perception.lua")

local Roster, RequestQueue, Range, Alarm = ns.Roster, ns.RequestQueue, ns.Range, ns.Alarm
local ChatRange = ns.ChatRange
local Perception = ns.Perception

local passed, failed = 0, 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
    else
        failed = failed + 1
        print("FEHLER  " .. name .. "\n        " .. tostring(err))
    end
end

local function eq(actual, expected, what)
    if actual ~= expected then
        error(string.format("%s: erwartet %s, bekommen %s", what or "Wert", tostring(expected), tostring(actual)), 2)
    end
end

local function info(fields)
    local result = { name = "Spieler", rangeLower = 45, rangeUpper = 50, hostile = false }
    for key, value in pairs(fields or {}) do
        result[key] = value
    end
    return result
end

-------------------------------------------------------------------------------
-- Roster
-------------------------------------------------------------------------------

test("FullName vereinheitlicht Namen", function()
    eq(Roster.FullName("Aria", "Testrealm"), "Aria-Testrealm", "ohne Realm")
    eq(Roster.FullName("Aria-Testrealm", "Anders"), "Aria-Testrealm", "mit Realm")
    eq(Roster.FullName("Aria-Die Aldor", nil), "Aria-DieAldor", "Leerzeichen im Realm")
    eq(Roster.FullName("Aria", "Die Aldor"), "Aria-DieAldor", "Standard-Realm mit Leerzeichen")
    eq(Roster.FullName("Aria", nil), "Aria", "kein Realm bekannt")
    eq(Roster.FullName("", "X"), nil, "leer")
end)

test("Genaue Entfernung hat Vorrang", function()
    eq(Roster.DistanceKey({ distance = 23, rangeUpper = 25 }), 23)
    eq(Roster.WithinRadius({ distance = 49 }, 50), true)
    eq(Roster.WithinRadius({ distance = 51 }, 50), false)
end)

test("Quellen zusammenführen: genaueste gewinnt", function()
    local plate, group, locator, senses = Roster.New(), Roster.New(), Roster.New(), Roster.New()
    plate:Set("GUID-A", info({ name = "Aria", fullName = "Aria-S", source = "plate", rangeLower = 10, rangeUpper = 15 }))
    locator:Set("Aria-S", info({ name = "Aria", fullName = "Aria-S", source = "locator", distance = 40 }))
    locator:Set("Bern-S", info({ name = "Bern", fullName = "Bern-S", source = "locator", distance = 30 }))
    senses:Set("Bern-S", info({ name = "Bern", fullName = "Bern-S", source = "senses" }))
    senses:Set("Cara-S", { name = "Cara", fullName = "Cara-S", source = "senses" }) -- ohne Entfernung
    group:Set("GUID-D", info({ name = "Dora", fullName = "Dora-S", source = "group", distance = 5 }))
    local list = Roster.Collect({}, { plate, group, locator, senses }, "distance", false, 50)
    eq(#list, 4, "jeder nur einmal")
    eq(list[1].name, "Dora", "Gruppe 5 m zuerst")
    eq(list[2].name, "Aria", "Aria aus Plakette (15 m)")
    eq(list[2].source, "plate", "Plakette schlägt Ortung")
    eq(list[3].source, "locator", "Bern: Ortung schlägt Spürsinn")
    eq(list[4].name, "Cara", "ohne Entfernung zuletzt")
    local count = 0
    Roster.ForEachMerged({ plate, group, locator, senses }, function() count = count + 1 end)
    eq(count, 4, "ForEachMerged ebenso")
end)

test("InEarshot: wer kann /sagen hören", function()
    eq(Roster.InEarshot({ distance = 30 }, 30), true, "genau 30 m")
    eq(Roster.InEarshot({ distance = 31 }, 30), false, "31 m")
    eq(Roster.InEarshot({ rangeLower = 25, rangeUpper = 30 }, 30), true, "bis 30 m")
    eq(Roster.InEarshot({ rangeLower = 30, rangeUpper = 35 }, 30), false, "über 30 m")
    eq(Roster.InEarshot({ rangeLower = 20, rangeUpper = 35 }, 30), nil, "grob, unklar")
    eq(Roster.InEarshot({ source = "senses", detail = "SAY" }, 30), true, "hat gesprochen")
    eq(Roster.InEarshot({ source = "senses", detail = "EMOTE" }, 30), true, "hat emotet")
    eq(Roster.InEarshot({ source = "senses", detail = "COMBAT" }, 30), nil, "nur Kampflog")
    eq(Roster.InEarshot({}, 30), nil, "unbekannt")
end)

test("DistanceKey und Umkreis", function()
    eq(Roster.DistanceKey({ rangeLower = 10, rangeUpper = 15 }), 15, "Obergrenze")
    eq(Roster.DistanceKey({ rangeLower = 60 }), 60.5, "nur Untergrenze")
    eq(Roster.DistanceKey({}), math.huge, "unbekannt")
    eq(Roster.WithinRadius({ rangeLower = 45, rangeUpper = 50 }, 50), true, "bis 50 m")
    eq(Roster.WithinRadius({ rangeLower = 50, rangeUpper = 60 }, 50), false, "über 50 m")
    eq(Roster.WithinRadius({}, 50), true, "unbekannt bleibt sichtbar")
    eq(Roster.WithinRadius({ rangeLower = 60 }, nil), true, "ohne Umkreis")
end)

test("RoleplayStatus", function()
    eq(Roster.RoleplayStatus({ character = { RP = 1 } }), "IC")
    eq(Roster.RoleplayStatus({ character = { RP = 2 } }), "OOC")
    eq(Roster.RoleplayStatus({ character = {} }), nil, "ohne RP-Feld")
    eq(Roster.RoleplayStatus({}), nil, "ohne character")
    eq(Roster.RoleplayStatus(nil), nil, "nil")
end)

test("CleanText entfernt Codes", function()
    eq(Roster.CleanText("|cffff0000Lady|r Aria"), "Lady Aria")
    eq(Roster.CleanText("|TInterface\\Icons\\X:16|t Aria"), "Aria")
    eq(Roster.CleanText("  Aria\nvon Sturmwind "), "Aria von Sturmwind")
    eq(Roster.CleanText("   "), nil, "nur Leerzeichen")
    eq(Roster.CleanText(42), nil, "keine Zeichenkette")
end)

test("Set meldet Änderungen und zählt", function()
    local r = Roster.New()
    eq(r:Set("G1", info({ name = "Aria" })), true, "neu")
    eq(r:Count(), 1, "Anzahl")
    eq(r:Set("G1", info({ name = "Aria" })), false, "unverändert")
    eq(r:Set("G1", info({ name = "Aria", guild = "Die Wache" })), true, "Gilde neu")
    eq(r:Get("G1").guild, "Die Wache")
    eq(r:Set("G1", info({ name = "Aria" })), true, "Gilde weg")
    eq(r:Get("G1").guild, nil, "Gilde gelöscht")
    eq(r:Count(), 1, "Anzahl bleibt")
end)

test("Remove und Clear", function()
    local r = Roster.New()
    r:Set("G1", info())
    r:Set("G2", info())
    eq(r:Remove("G1"), true)
    eq(r:Remove("G1"), false, "doppelt")
    eq(r:Count(), 1)
    eq(r:Clear(), true)
    eq(r:Count(), 0)
    eq(r:Clear(), false, "leer")
end)

test("Sortierung nach Entfernung, dann Name", function()
    local r = Roster.New()
    r:Set("G1", info({ name = "Zora", rangeLower = 5, rangeUpper = 8 }))
    r:Set("G2", info({ name = "Aria", rangeLower = 40, rangeUpper = 45 }))
    r:Set("G3", info({ name = "Bern", rangeLower = 5, rangeUpper = 8 }))
    r:Set("G4", { name = "Anna" }) -- Entfernung unbekannt
    local list = Roster.Collect({}, { r }, "distance", false)
    eq(#list, 4)
    eq(list[1].name, "Bern")
    eq(list[2].name, "Zora")
    eq(list[3].name, "Aria")
    eq(list[4].name, "Anna", "unbekannte Entfernung zuletzt")
end)

test("Sortierung nach Name nutzt RP-Namen", function()
    local r = Roster.New()
    r:Set("G1", info({ name = "Zora", rpName = "Amalia" }))
    r:Set("G2", info({ name = "Bern" }))
    local list = Roster.Collect({}, { r }, "name", false)
    eq(list[1].name, "Zora", "Amalia vor Bern")
    eq(Roster.DisplayName(list[1]), "Amalia")
end)

test("Feindliche ausblenden", function()
    local r = Roster.New()
    r:Set("G1", info({ name = "Freund" }))
    r:Set("G2", info({ name = "Feind", hostile = true }))
    eq(#Roster.Collect({}, { r }, "name", false), 2)
    local list = Roster.Collect({}, { r }, "name", true)
    eq(#list, 1)
    eq(list[1].name, "Freund")
end)

test("Umkreis filtert die Liste", function()
    local r = Roster.New()
    r:Set("G1", info({ name = "Nah", rangeLower = 10, rangeUpper = 15 }))
    r:Set("G2", info({ name = "Weit", rangeLower = 50, rangeUpper = 60 }))
    eq(#Roster.Collect({}, { r }, "distance", false, 50), 1)
    eq(#Roster.Collect({}, { r }, "distance", false, 60), 2)
end)

-------------------------------------------------------------------------------
-- Range
-------------------------------------------------------------------------------

test("Jede Stufe hat Gegenstände für beide Listen", function()
    for _, step in ipairs(Range.STEPS) do
        assert(Range.FRIEND[step] and #Range.FRIEND[step] > 0, "FRIEND fehlt: " .. step)
        assert(Range.HARM[step] and #Range.HARM[step] > 0, "HARM fehlt: " .. step)
    end
end)

test("StepAtOrBelow und NextStep", function()
    eq(Range.StepAtOrBelow(15), 15)
    eq(Range.StepAtOrBelow(17), 15)
    eq(Range.StepAtOrBelow(3), 5, "mindestens kleinste Stufe")
    eq(Range.StepAtOrBelow(100), 60)
    eq(Range.NextStep(15), 20)
    eq(Range.NextStep(50), 55, "Rückstellung bei 50 m Warngrenze noch messbar")
    eq(Range.StepAtOrBelow(57), 55)
    eq(Range.NextStep(60), nil)
end)

test("Measure findet die Stufe", function()
    local function at(distance)
        return function(step) return distance <= step end
    end
    local lower, upper = Range.Measure(at(12))
    eq(lower, 10, "unten")
    eq(upper, 15, "oben")
    lower, upper = Range.Measure(at(3))
    eq(lower, nil, "ganz nah unten")
    eq(upper, 5, "ganz nah oben")
    lower, upper = Range.Measure(at(80))
    eq(lower, 60, "zu weit unten")
    eq(upper, nil, "zu weit oben")
    -- Eine Stufe nicht prüfbar (nil): wird übersprungen
    lower, upper = Range.Measure(function(step)
        if step == 10 then return nil end
        return 12 <= step
    end)
    eq(lower, 8, "Lücke unten")
    eq(upper, 15, "Lücke oben")
    lower, upper = Range.Measure(function() return nil end)
    eq(lower, nil)
    eq(upper, nil)
end)

-------------------------------------------------------------------------------
-- Alarm
-------------------------------------------------------------------------------

test("Alarm löst bei jedem Überschreiten aus", function()
    local a = Alarm.New(60)
    eq(a:Update("G", false, true, 0), false, "draußen")
    eq(a:Update("G", true, false, 1), true, "kommt rein")
    eq(a:IsInside("G"), true)
    eq(a:Update("G", true, false, 2), false, "bleibt drin")
    eq(a:Update("G", false, false, 3), false, "Grenzbereich")
    eq(a:Update("G", true, false, 4), false, "Grenzbereich zurück: kein Flackern")
    eq(a:Update("G", false, true, 5), false, "sicher draußen")
    eq(a:IsInside("G"), false)
    eq(a:Update("G", true, false, 6), true, "kommt erneut rein")
end)

test("Alarm: erster Blick innerhalb löst aus, Kameradrehen nicht", function()
    local a = Alarm.New(60)
    eq(a:Update("G", true, false, 0), true, "zum ersten Mal gesehen, schon nah")
    -- Plakette verschwindet (Kamera gedreht), nach 10 s wieder da
    eq(a:Update("G", true, false, 10), false, "kein zweites Mal")
    a:Expire(50)
    eq(a:IsInside("G"), true, "noch im Gedächtnis")
    a:Expire(71)
    eq(a:IsInside("G"), false, "nach 60 s vergessen")
    eq(a:Update("G", true, false, 72), true, "danach wieder Warnung")
end)

test("Alarm: unbekannt ändert nichts, Reset", function()
    local a = Alarm.New(60)
    eq(a:Update("G", false, false, 0), false)
    eq(a:IsInside("G"), false)
    a:Update("G", true, false, 1)
    a:Reset()
    eq(a:IsInside("G"), false)
    eq(a:Update("G", true, false, 2), true, "nach Reset wieder scharf")
end)

-------------------------------------------------------------------------------
-- ChatRange (Server-Regler)
-------------------------------------------------------------------------------

test("ChatRange.ToYards: anteilig, Höchstwert = 30 m", function()
    eq(ChatRange.ToYards(3, 1, 3), 30, "ganz rechts")
    eq(ChatRange.ToYards(2, 1, 3), 20, "Mitte")
    eq(ChatRange.ToYards(1, 1, 3), 10, "ganz links")
    eq(ChatRange.ToYards(0.5, 0, 1), 15, "0 bis 1")
    eq(ChatRange.ToYards(0, 0, 1), 1, "ganz links bei 0: mindestens 1 m")
    eq(ChatRange.ToYards(5, 1, 3), 30, "über dem Höchstwert begrenzt")
    eq(ChatRange.ToYards(2, 1, 3, 40), 27, "andere Normal-Reichweite")
end)

test("ChatRange.ToYards: unbrauchbare Werte", function()
    eq(ChatRange.ToYards(nil, 1, 3), nil, "kein Wert")
    eq(ChatRange.ToYards(2, 1, 0), nil, "Höchstwert 0")
    eq(ChatRange.ToYards(2, 5, 3), nil, "Minimum über Maximum")
    eq(ChatRange.ToYards(0 / 0, 1, 3), nil, "NaN")
    eq(ChatRange.ToYards("2", 1, 3), nil, "Text")
end)

test("ChatRange.FormatNumber", function()
    eq(ChatRange.FormatNumber(3), "3")
    eq(ChatRange.FormatNumber(0.5), "0.5")
    eq(ChatRange.FormatNumber(0.25), "0.25")
    eq(ChatRange.FormatNumber(nil), "?")
end)

-------------------------------------------------------------------------------
-- Perception (Wahrnehmungswurf)
-------------------------------------------------------------------------------

test("Perception.Difficulty: je näher, desto leichter", function()
    eq(Perception.Difficulty({ distance = 4 }), 6, "4 m")
    eq(Perception.Difficulty({ distance = 10 }), 6, "genau 10 m")
    eq(Perception.Difficulty({ rangeLower = 10, rangeUpper = 15 }), 11, "bis 15 m")
    eq(Perception.Difficulty({ distance = 30 }), 11, "genau 30 m")
    eq(Perception.Difficulty({ rangeLower = 30, rangeUpper = 35 }), 16, "bis 35 m")
    eq(Perception.Difficulty({ rangeLower = 60 }), 16, "über 60 m")
    eq(Perception.Difficulty({ rangeLower = 20 }), 11, "über 20 m, sonst unbekannt")
    eq(Perception.Difficulty({ source = "senses" }), 11, "unbekannt")
end)

test("Perception: Wurf, Ergebnis, Sperre", function()
    local p = Perception.New(300)
    local function dice(value) return function(low, high) assert(low == 1 and high == 20); return value end end
    local result, fresh = p:Roll("A", 11, 0, dice(11))
    eq(fresh, true, "erster Wurf")
    eq(result.roll, 11)
    eq(result.noticed, true, "11 gegen 11 bemerkt")
    result, fresh = p:Roll("A", 11, 100, dice(20))
    eq(fresh, false, "gesperrt")
    eq(result.roll, 11, "altes Ergebnis bleibt")
    eq(p:Remaining("A", 100), 200, "Restzeit")
    eq(p:HasAny(100), true)
    result = p:Roll("B", 16, 0, dice(15))
    eq(result.noticed, false, "15 gegen 16 nicht bemerkt")
    eq(p:Get("A", 299) ~= nil, true, "kurz vor Ablauf noch da")
    eq(p:Get("A", 300), nil, "nach 5 Minuten weg")
    eq(p:Remaining("A", 300), 0)
    result, fresh = p:Roll("A", 6, 300, dice(3))
    eq(fresh, true, "danach neuer Wurf")
    eq(result.noticed, false)
    eq(p:Expire(299), false, "noch nichts abgelaufen")
    eq(p:Expire(600), true, "jetzt abgelaufen")
    eq(p:HasAny(1000), false, "alles abgelaufen")
end)

-------------------------------------------------------------------------------
-- RequestQueue
-------------------------------------------------------------------------------

test("Queue drosselt und hält Cooldown ein", function()
    local q = RequestQueue.New(2, 300)
    eq(q:Push("A-Realm", 0), true)
    eq(q:Push("A-Realm", 0), false, "schon wartend")
    eq(q:Push("B-Realm", 0), true)
    eq(q:Pop(0), "A-Realm")
    eq(q:Pop(1), nil, "Intervall")
    eq(q:Pop(2), "B-Realm")
    eq(q:Push("A-Realm", 100), false, "Cooldown")
    eq(q:Push("A-Realm", 300), true, "nach Cooldown")
    eq(q:Pop(300), "A-Realm")
end)

test("Queue Drop und ungültige IDs", function()
    local q = RequestQueue.New(2, 300)
    eq(q:Push(nil, 0), false)
    eq(q:Push("", 0), false)
    q:Push("A-Realm", 0)
    q:Push("B-Realm", 0)
    eq(q:Drop("A-Realm"), true)
    eq(q:Drop("A-Realm"), false, "doppelt")
    eq(q:Size(), 1)
    eq(q:Pop(0), "B-Realm")
    eq(q:Push("A-Realm", 0), true, "nach Drop wieder möglich")
end)

print(string.format("%d Tests bestanden, %d fehlgeschlagen", passed, failed))
os.exit(failed == 0 and 0 or 1)
