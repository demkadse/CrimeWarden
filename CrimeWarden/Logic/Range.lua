local _, ns = ...

-- Reine Logik ohne WoW-API: Entfernungsstufen und die Gegenstände, mit denen
-- WoW 9.2.7 prüfen kann, ob ein Spieler höchstens so weit entfernt ist
-- (IsItemInRange). Die Gegenstände muss man nicht besitzen.
-- Quelle: LibRangeCheck-3.0 (WeakAuras), Retail-Listen, nur Gegenstände, die
-- es in 9.2.7 schon gab. Pro Stufe mehrere, falls einer im Client fehlt.
local Range = {}
ns.Range = Range

-- 55 m ist die Rückstell-Stufe für eine Warngrenze von 50 m: Namensplaketten
-- reichen nur etwa 60 m weit, weiter draußen lässt sich nichts mehr messen.
Range.STEPS = { 5, 8, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60 }

-- Für freundliche (nicht angreifbare) Spieler.
Range.FRIEND = {
    [5] = { 1970, 8149, 15826 }, -- Restoring Balm, Voodoo Charm, Curative Animal Salve
    [8] = { 34368, 33278, 35943 }, -- Attuned Crystal Cores, Burning Torch, Jeremiah's Tools
    [10] = { 21267, 17626, 17689 }, -- Toasting Goblet, Frostwolf Muzzle, Stormpike Training Collar
    [15] = { 1251, 2581, 3530 }, -- Linen Bandage, Heavy Linen Bandage, Wool Bandage
    [20] = { 21519, 17757, 22473 }, -- Mistletoe, Amulet of Spirits, Antheol's Disciplinary Rod
    [25] = { 31463, 13289, 34979 }, -- Zezzak's Shard, Egan's Blaster, Pouch of Crushed Bloodspore
    [30] = { 1180, 954, 955 }, -- Scroll of Stamina, Scroll of Strength, Scroll of Intellect
    [35] = { 18904, 24501, 35121 }, -- Zorbin's Ultra-Shrinker, Gordawg's Boulder, Wolf Bait
    [40] = { 1713, 5232, 5323 }, -- Ankh of Life, Soulstone, Everglow Lantern
    [45] = { 32698, 28369, 34691 }, -- Wrangling Rope, Battery Recharging Blaster, Arcane Binder
    [50] = { 116139, 110009, 147006 }, -- Haunting Memento, Leaf of the Ancient Protectors, Archive of Faith
    [55] = { 74637 }, -- Kiryn's Poison Vial (einziger Gegenstand dieser Stufe)
    [60] = { 32825, 34111, 34121 }, -- Soul Cannon, Trained Rock Falcon (2x)
}

-- Für angreifbare Spieler.
Range.HARM = {
    [5] = { 8149, 15826, 17117 }, -- Voodoo Charm, Curative Animal Salve, Rat Catcher's Flute
    [8] = { 34368, 33278, 35943 }, -- Attuned Crystal Cores, Burning Torch, Jeremiah's Tools
    [10] = { 9606, 9618, 9619 }, -- Muisek Vessels
    [15] = { 30651, 30652, 30653 }, -- Dertrok's Wands
    [20] = { 10645, 1191, 4388 }, -- Gnomish Death Ray, Bag of Marbles, Discombobulator Ray
    [25] = { 24268, 13289, 31463 }, -- Netherweave Net, Egan's Blaster, Zezzak's Shard
    [30] = { 835, 1399, 1434 }, -- Large Rope Net, Magic Candle, Glowing Wax Stick
    [35] = { 24269, 18904, 24501 }, -- Heavy Netherweave Net, Zorbin's Ultra-Shrinker, Gordawg's Boulder
    [40] = { 28767, 4945, 33581 }, -- The Decapitator, Faintly Glowing Skull, Vrykul Insult
    [45] = { 23836, 28369, 32698 }, -- Goblin Rocket Launcher, Battery Recharging Blaster, Wrangling Rope
    [50] = { 116139, 129372, 134836 }, -- Haunting Memento, Spymaster Jenri's Scope, Trident
    [55] = { 74637 }, -- Kiryn's Poison Vial (einziger Gegenstand dieser Stufe)
    [60] = { 32825, 34111, 34121 }, -- Soul Cannon, Trained Rock Falcon (2x)
}

-- Größte Stufe, die höchstens `yards` beträgt (mindestens die kleinste).
function Range.StepAtOrBelow(yards)
    local result = Range.STEPS[1]
    for _, step in ipairs(Range.STEPS) do
        if step <= yards then
            result = step
        end
    end
    return result
end

-- Nächstgrößere Stufe nach `step`, oder nil, wenn es keine gibt.
function Range.NextStep(step)
    for _, candidate in ipairs(Range.STEPS) do
        if candidate > step then
            return candidate
        end
    end
    return nil
end

-- Misst mit check(stufe) -> true (höchstens so weit) / false / nil (unbekannt).
-- Gibt lower, upper zurück: Der Spieler ist weiter als lower und höchstens
-- upper entfernt. nil bedeutet "keine Grenze bekannt".
function Range.Measure(check)
    local lower
    for _, step in ipairs(Range.STEPS) do
        local within = check(step)
        if within == true then
            return lower, step
        elseif within == false then
            lower = step
        end
    end
    return lower, nil
end
