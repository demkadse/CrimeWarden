local _, ns = ...
local L = ns.L
local Roster = ns.Roster

local UI = {}
ns.UI = UI

local ROW_HEIGHT = 36
local ROW_GAP = 2
local ROW_STRIDE = ROW_HEIGHT + ROW_GAP
local TITLE_HEIGHT = 26
local TOOLBAR_HEIGHT = 20
local CONTENT_TOP = TITLE_HEIGHT + TOOLBAR_HEIGHT + 8
local PADDING = 8
local MIN_WIDTH, MIN_HEIGHT, MAX_WIDTH, MAX_HEIGHT = 330, 170, 700, 900

-- Schalter der Werkzeugleiste für die Quellen: Einstellungsschlüssel,
-- Beschriftung und Erklärung.
local SOURCE_BUTTONS = {
    { key = "group", label = "BTN_GROUP", tip = "TIP_SRC_GROUP", width = 66 },
    { key = "locator", label = "BTN_LOCATOR", tip = "TIP_SRC_LOCATOR", width = 62 },
    { key = "senses", label = "BTN_SENSES", tip = "TIP_SRC_SENSES", width = 72 },
}

local WHITE = "Interface\\Buttons\\WHITE8X8"
local EARSHOT_ICON = "Interface\\GossipFrame\\GossipGossipIcon"
local DICE_ICON = "Interface\\Buttons\\UI-GroupLoot-Dice-Up"
local DICE_ICON_HIGHLIGHT = "Interface\\Buttons\\UI-GroupLoot-Dice-Highlight"
local DICE_ICON_PRESSED = "Interface\\Buttons\\UI-GroupLoot-Dice-Down"
local Perception = ns.Perception

local WARN_COLOR = { 1.00, 0.30, 0.25 } -- innerhalb der Warngrenze
local CLOSE_COLOR = { 0.95, 0.80, 0.30 } -- bis 30 m
local FAR_COLOR = { 0.65, 0.65, 0.68 }
local UNKNOWN_COLOR = { 0.50, 0.50, 0.50 }
local IC_COLOR = { 0.40, 0.90, 0.45 }
local OOC_COLOR = { 0.95, 0.40, 0.35 }

local frame, title, modeSwitch, scrollFrame, scrollChild, emptyText, platesButton, resizeHandle
local sourceButtons = {}
local rows = {}
local entries = {}
local dirty = true

local function ClassColor(classFile)
    local color = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if color then
        return color.r, color.g, color.b
    end
    return 0.90, 0.90, 0.90
end

-- Herkunft für Spieler, die nicht über die Namensplakette erfasst sind.
local function SourceNote(entry)
    local age = entry.seenAt and math.max(0, math.floor(GetTime() - entry.seenAt + 0.5))
    if entry.source == "group" then
        return L.NOTE_GROUP
    elseif entry.source == "locator" then
        return L.NOTE_LOCATOR:format(age or 0)
    elseif entry.source == "senses" then
        return L.NOTE_SENSES:format(age or 0, L["SENSE_" .. (entry.detail or "COMBAT")])
    end
    return nil
end

-- Entfernungstext und -farbe je nach Quelle.
local function DistanceText(entry)
    if entry.distance then
        local format = entry.source == "locator" and L.DIST_APPROX or L.DIST_EXACT
        return format:format(entry.distance), entry.distance <= 30 and CLOSE_COLOR or FAR_COLOR
    elseif entry.rangeUpper then
        return L.DIST_UPTO:format(entry.rangeUpper), entry.rangeUpper <= 30 and CLOSE_COLOR or FAR_COLOR
    elseif entry.rangeLower then
        return L.DIST_BEYOND:format(entry.rangeLower), FAR_COLOR
    elseif entry.source == "senses" then
        return entry.detail == "COMBAT" and L.DIST_NEARBY or L.DIST_EARSHOT, UNKNOWN_COLOR
    end
    return L.DIST_UNKNOWN, UNKNOWN_COLOR
end

-- Zweite Zeile: Charaktername (falls ein RP-Name oben steht), Stufe, Volk,
-- Klasse, Gilde, ggf. "feindlich" und die Herkunft.
local function InfoLine(entry)
    local parts = {}
    if entry.rpName then
        parts[#parts + 1] = entry.name
    end
    local who = {}
    if type(entry.level) == "number" then
        who[#who + 1] = L.LEVEL:format(entry.level > 0 and tostring(entry.level) or "??")
    end
    who[#who + 1] = entry.race
    who[#who + 1] = entry.className
    if #who > 0 then
        parts[#parts + 1] = table.concat(who, " ")
    end
    if entry.guild then
        parts[#parts + 1] = "<" .. entry.guild .. ">"
    end
    if entry.hostile then
        parts[#parts + 1] = "|cffff5050" .. L.HOSTILE .. "|r"
    end
    local note = SourceNote(entry)
    if note then
        parts[#parts + 1] = note
    end
    return table.concat(parts, "  ·  ")
end

local function ShowRowTooltip(row)
    local entry = row.entry
    if not entry then
        return
    end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    if entry.unit and UnitGUID(entry.unit) == entry.guid then
        GameTooltip:SetUnit(entry.unit)
    else
        GameTooltip:AddLine(entry.name, ClassColor(entry.classFile))
    end
    if entry.rpName then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(entry.rpName, 1, 0.82, 0, true)
        GameTooltip:AddLine(L.TIP_CHARNAME:format(entry.name), 0.8, 0.8, 0.8)
    end
    if entry.rpStatus then
        local color = entry.rpStatus == "IC" and IC_COLOR or OOC_COLOR
        GameTooltip:AddLine(L["TIP_" .. entry.rpStatus], color[1], color[2], color[3])
    end
    local note = SourceNote(entry)
    if note then
        GameTooltip:AddLine(note, 0.8, 0.8, 0.8)
    end
    if Roster.InEarshot(entry, ns:GetSayRange()) then
        GameTooltip:AddLine(L.TIP_EARSHOT:format(ns:GetSayRange()), 0.55, 0.85, 1)
    end
    GameTooltip:AddLine(" ")
    if entry.hasProfile then
        GameTooltip:AddLine(L.TIP_CLICK_PROFILE, 0.6, 0.6, 0.6)
    end
    GameTooltip:AddLine(L.TIP_CLICK_WHISPER, 0.6, 0.6, 0.6)
    GameTooltip:AddLine(L.TIP_CLICK_LINK, 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

local function HideRowTooltip(row)
    if GameTooltip:IsOwned(row) then
        GameTooltip:Hide()
    end
end

local function OnRowClick(row, button)
    local entry = row.entry
    if not entry then
        return
    end
    if button == "RightButton" then
        ChatFrame_SendTell(entry.name)
    elseif IsShiftKeyDown() then
        local editBox = ChatEdit_GetActiveWindow()
        if editBox then
            editBox:Insert(entry.name)
        else
            ChatFrame_OpenChat(entry.name)
        end
    elseif entry.hasProfile and ns.TRP3:OpenProfile(entry.characterID) then
        return
    elseif ns.TRP3:IsLoaded() then
        ns:Print(L.NO_PROFILE, entry.name)
    else
        ns:Print(L.TRP3_MISSING, entry.name)
    end
end

-- Wahrnehmungswurf: "Bemerkt mein Charakter diese Person?" (nur für mich).
local function PerceptionKey(entry)
    return entry.fullName or entry.key
end

local function ResultText(result)
    return L.DICE_RESULT:format(result.roll, result.difficulty, result.noticed and L.DICE_NOTICED or L.DICE_MISSED)
end

local function DiceTooltip(entry)
    if not entry then
        return nil
    end
    local key, now = PerceptionKey(entry), GetTime()
    local lines = { L.DICE_RULE:format(Perception.Difficulty(entry)) }
    local result = ns.perception:Get(key, now)
    if result then
        lines[#lines + 1] = ResultText(result)
        lines[#lines + 1] = L.DICE_LOCKED:format(ns.perception:Remaining(key, now))
    else
        lines[#lines + 1] = L.DICE_CLICK
    end
    lines[#lines + 1] = L.DICE_PRIVATE
    return table.concat(lines, "\n\n")
end

local function OnDiceClick(button)
    local entry = button.row.entry
    if not entry then
        return
    end
    local key, now = PerceptionKey(entry), GetTime()
    local result, fresh = ns.perception:Roll(key, Perception.Difficulty(entry), now, math.random)
    local name = Roster.DisplayName(entry)
    if fresh then
        ns:Print(L.DICE_CHAT, name, ResultText(result))
    else
        ns:Print(L.DICE_CHAT_LOCKED, name, ns.perception:Remaining(key, now))
    end
    UI:Refresh()
    if GameTooltip:IsOwned(button) then
        button:GetScript("OnEnter")(button)
    end
end

local function CreateRow(index)
    local row = CreateFrame("Button", nil, scrollChild)
    row:SetHeight(ROW_HEIGHT)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local background = row:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(1, 1, 1, index % 2 == 0 and 0.04 or 0.015)

    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 0.82, 0, 0.12)

    row.status = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.status:SetPoint("TOPLEFT", 4, -5)
    row.status:SetWidth(28)
    row.status:SetJustifyH("LEFT")

    row.distance = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.distance:SetPoint("TOPRIGHT", -4, -5)
    row.distance:SetJustifyH("RIGHT")

    -- Sprechblase: kann dich per /sagen hören.
    row.earshot = row:CreateTexture(nil, "OVERLAY")
    row.earshot:SetSize(12, 12)
    row.earshot:SetPoint("RIGHT", row.distance, "LEFT", -3, 0)
    row.earshot:SetTexture(EARSHOT_ICON)
    row.earshot:Hide()

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.name:SetPoint("TOPLEFT", 34, -4)
    row.name:SetPoint("RIGHT", row.earshot, "LEFT", -4, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    -- Würfelknopf und Ergebnis rechts in der zweiten Zeile.
    row.dice = CreateFrame("Button", nil, row)
    row.dice:SetSize(16, 16)
    row.dice:SetPoint("BOTTOMRIGHT", -4, 3)
    row.dice:SetNormalTexture(DICE_ICON)
    row.dice:SetHighlightTexture(DICE_ICON_HIGHLIGHT)
    row.dice:SetPushedTexture(DICE_ICON_PRESSED)
    row.dice.row = row
    row.dice:SetScript("OnClick", OnDiceClick)
    ns:SetTooltip(row.dice, L.DICE_TITLE, function()
        return DiceTooltip(row.entry)
    end)

    row.diceResult = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.diceResult:SetPoint("RIGHT", row.dice, "LEFT", -3, 0)
    row.diceResult:SetJustifyH("RIGHT")

    row.info = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.info:SetPoint("TOPLEFT", 34, -21)
    row.info:SetPoint("RIGHT", row.diceResult, "LEFT", -4, 0)
    row.info:SetJustifyH("LEFT")
    row.info:SetWordWrap(false)

    row:SetScript("OnClick", OnRowClick)
    row:SetScript("OnEnter", ShowRowTooltip)
    row:SetScript("OnLeave", HideRowTooltip)

    rows[index] = row
    return row
end

local function UpdateRow(row, entry, index)
    row.entry = entry

    row.name:SetText(Roster.DisplayName(entry))
    row.name:SetTextColor(ClassColor(entry.classFile))

    if entry.rpStatus then
        local color = entry.rpStatus == "IC" and IC_COLOR or OOC_COLOR
        row.status:SetText(L[entry.rpStatus])
        row.status:SetTextColor(color[1], color[2], color[3])
    else
        row.status:SetText("")
    end

    local text, color = DistanceText(entry)
    if ns.Warden:IsInside(entry) then
        text = "! " .. text
        color = WARN_COLOR
    end
    row.distance:SetText(text)
    row.distance:SetTextColor(color[1], color[2], color[3])
    row.earshot:SetShown(Roster.InEarshot(entry, ns:GetSayRange()) == true)

    row.info:SetText(InfoLine(entry))

    local result = ns.perception:Get(PerceptionKey(entry), GetTime())
    if result then
        row.diceResult:SetText((result.noticed and L.DICE_SHORT_NOTICED or L.DICE_SHORT_MISSED):format(result.roll))
        row.dice:SetAlpha(0.45) -- gesperrt, bis das Ergebnis abläuft
    else
        row.diceResult:SetText("")
        row.dice:SetAlpha(1)
    end
    -- Nicht live gesehene Spieler etwas blasser.
    row:SetAlpha((entry.source == "locator" or entry.source == "senses") and 0.75 or 1)

    local offset = -((index - 1) * ROW_STRIDE)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 0, offset)
    row:SetPoint("TOPRIGHT", 0, offset)
    row:Show()

    if GameTooltip:IsOwned(row) then
        ShowRowTooltip(row)
    end
end

-- Zweigeteilter Modusschalter: links Just, rechts Unjust. Die aktive
-- Hälfte ist grün bzw. rot, die andere grau. Ein Klick auf eine Hälfte
-- aktiviert genau diesen Modus. Wird im Fenster und in den Einstellungen
-- verwendet.
local MODE_HALVES = {
    { unjust = false, label = "MODE_JUST", tip = "TIP_MODE_JUST",
      background = { 0.10, 0.42, 0.14 }, text = { 0.80, 1.00, 0.80 } },
    { unjust = true, label = "MODE_UNJUST", tip = "TIP_MODE_UNJUST",
      background = { 0.55, 0.10, 0.08 }, text = { 1.00, 0.80, 0.75 } },
}
local INACTIVE_BACKGROUND = { 0.16, 0.16, 0.17 }
local INACTIVE_TEXT = { 0.50, 0.50, 0.50 }

local function UpdateModeSwitch(switch)
    local unjust = ns:IsUnjust()
    for _, half in ipairs(switch.halves) do
        local active = half.info.unjust == unjust
        local background = active and half.info.background or INACTIVE_BACKGROUND
        local text = active and half.info.text or INACTIVE_TEXT
        half.background:SetColorTexture(background[1], background[2], background[3], 1)
        half.label:SetTextColor(text[1], text[2], text[3])
    end
end

function UI:CreateModeSwitch(parent, width, height)
    local switch = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    switch:SetSize(width, height)
    switch:SetBackdrop({ edgeFile = WHITE, edgeSize = 1 })
    switch:SetBackdropBorderColor(0.30, 0.26, 0.19, 1)
    switch.halves = {}
    for index, info in ipairs(MODE_HALVES) do
        local half = CreateFrame("Button", nil, switch)
        half:SetSize(width / 2 - 1, height - 2)
        half:SetPoint(index == 1 and "LEFT" or "RIGHT", index == 1 and 1 or -1, 0)
        half.info = info
        half.background = half:CreateTexture(nil, "BACKGROUND")
        half.background:SetAllPoints()
        local highlight = half:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(1, 1, 1, 0.10)
        half.label = half:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        half.label:SetAllPoints()
        half.label:SetText(L[info.label])
        half:SetScript("OnClick", function(clicked)
            if ns:IsUnjust() ~= info.unjust then
                ns:SetUnjust(info.unjust)
            end
            clicked:GetScript("OnEnter")(clicked)
        end)
        ns:SetTooltip(half, function() return L[info.label] end, function()
            local state = ns:IsUnjust() == info.unjust and L.TIP_MODE_ACTIVE or L.TIP_MODE_ACTIVATE
            return state .. "\n\n" .. L[info.tip]:format(ns.Warden:GetYards())
        end)
        switch.halves[index] = half
    end
    switch.Update = UpdateModeSwitch
    switch:Update()
    return switch
end

-- Quellen-Schalter: grün = an, grau = aus.
local function UpdateToolbar()
    for _, button in ipairs(sourceButtons) do
        local on = ns.db.sources[button.key]
        button:SetText((on and "|cff60e060" or "|cff909090") .. L[button.label] .. "|r")
    end
end

local function StateLine(on)
    return on and L.TIP_STATE_ON or L.TIP_STATE_OFF
end

local function BuildToolbar()
    local previous
    for _, info in ipairs(SOURCE_BUTTONS) do
        local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        button:SetSize(info.width, TOOLBAR_HEIGHT)
        if previous then
            button:SetPoint("LEFT", previous, "RIGHT", 4, 0)
        else
            button:SetPoint("TOPLEFT", PADDING, -(TITLE_HEIGHT + 4))
        end
        button.key = info.key
        button.label = info.label
        button:SetScript("OnClick", function(self)
            ns.db.sources[info.key] = not ns.db.sources[info.key]
            ns:SourcesChanged()
            self:GetScript("OnEnter")(self)
        end)
        ns:SetTooltip(button, function() return L[info.label] end, function()
            return StateLine(ns.db.sources[info.key]) .. "\n\n" .. L[info.tip] .. "\n\n" .. L.TIP_CLICK_TOGGLE
        end)
        sourceButtons[#sourceButtons + 1] = button
        previous = button
    end

    local helpButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    helpButton:SetSize(22, TOOLBAR_HEIGHT)
    helpButton:SetPoint("TOPRIGHT", -PADDING, -(TITLE_HEIGHT + 4))
    helpButton:SetText("?")
    ns:SetTooltip(helpButton, L.HELP_TITLE, L.HELP_BODY)

    local optionsButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    optionsButton:SetSize(70, TOOLBAR_HEIGHT)
    optionsButton:SetPoint("RIGHT", helpButton, "LEFT", -4, 0)
    optionsButton:SetText(L.BTN_OPTIONS)
    optionsButton:SetScript("OnClick", function()
        if not ns.Config:Open() then
            ns:Print(L.OPTIONS_FAILED)
        end
    end)
    ns:SetTooltip(optionsButton, L.BTN_OPTIONS, L.TIP_OPTIONS)
end

function UI:Refresh()
    dirty = true
    if not frame or not frame:IsShown() then
        return
    end
    dirty = false

    local list = ns:CollectEntries(entries)
    title:SetText(L.TITLE_COUNT:format(#list))
    modeSwitch:Update()
    UpdateToolbar()
    for index, entry in ipairs(list) do
        UpdateRow(rows[index] or CreateRow(index), entry, index)
    end
    for index = #list + 1, #rows do
        local row = rows[index]
        HideRowTooltip(row)
        row.entry = nil
        row:Hide()
    end
    scrollChild:SetHeight(math.max(1, #list * ROW_STRIDE))

    local empty = #list == 0
    local platesReady = ns:NameplatesReady()
    emptyText:SetText(platesReady and (L.EMPTY .. "\n\n" .. L.EMPTY_HINT) or L.PLATES_OFF)
    emptyText:SetShown(empty)
    platesButton:SetShown(empty and not platesReady)
    scrollFrame:SetShown(not empty)
end

local function SavePosition()
    local point, _, relPoint, x, y = frame:GetPoint(1)
    local window = ns.db.window
    window.point, window.relPoint, window.x, window.y = point, relPoint, x, y
end

local function SaveSize()
    local window = ns.db.window
    window.width = math.floor(frame:GetWidth() + 0.5)
    window.height = math.floor(frame:GetHeight() + 0.5)
end

function UI:ApplyWindow()
    local window = ns.db.window
    frame:SetScale(window.scale)
    frame:SetSize(
        math.max(MIN_WIDTH, math.min(MAX_WIDTH, window.width)),
        math.max(MIN_HEIGHT, math.min(MAX_HEIGHT, window.height))
    )
    frame:ClearAllPoints()
    frame:SetPoint(window.point, UIParent, window.relPoint, window.x, window.y)
    frame:SetMovable(not window.locked)
    frame:SetResizable(not window.locked)
    resizeHandle:SetShown(not window.locked)
    frame:SetShown(window.shown)
    self:Refresh()
end

function UI:SetShown(shown)
    ns.db.window.shown = shown and true or false
    frame:SetShown(ns.db.window.shown)
    if shown then
        self:Refresh()
    end
end

function UI:Toggle()
    self:SetShown(not frame:IsShown())
end

function UI:IsShown()
    return frame:IsShown()
end

function UI:Init()
    if frame then
        return
    end

    frame = CreateFrame("Frame", "CrimeWardenFrame", UIParent, "BackdropTemplate")
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    -- 9.x kennt nur SetMinResize/SetMaxResize, ab 10.0 gibt es SetResizeBounds.
    if frame.SetResizeBounds then
        frame:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT, MAX_WIDTH, MAX_HEIGHT)
    else
        frame:SetMinResize(MIN_WIDTH, MIN_HEIGHT)
        frame:SetMaxResize(MAX_WIDTH, MAX_HEIGHT)
    end
    frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    frame:SetBackdropColor(0.04, 0.035, 0.045, 0.90)
    frame:SetBackdropBorderColor(0.30, 0.26, 0.19, 1)
    frame:Hide()

    frame:SetScript("OnDragStart", function()
        if not ns.db.window.locked then
            frame:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        SavePosition()
    end)
    frame:SetScript("OnShow", function()
        if dirty then
            UI:Refresh()
        end
    end)

    modeSwitch = UI:CreateModeSwitch(frame, 136, 18)
    modeSwitch:SetPoint("TOPRIGHT", -26, -4)

    title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetPoint("RIGHT", modeSwitch, "LEFT", -6, 0)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    title:SetText(L.TITLE)

    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(0.95, 0.72, 0.16, 0.6)
    divider:SetPoint("TOPLEFT", 1, -TITLE_HEIGHT)
    divider:SetPoint("TOPRIGHT", -1, -TITLE_HEIGHT)
    divider:SetHeight(1)

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", 2, 2)
    closeButton:SetScript("OnClick", function()
        UI:SetShown(false)
    end)
    ns:SetTooltip(closeButton, L.TIP_CLOSE_TITLE, L.TIP_CLOSE)

    BuildToolbar()

    scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", PADDING, -CONTENT_TOP)
    scrollFrame:SetPoint("BOTTOMRIGHT", -(PADDING + 22), PADDING + 12)
    scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(1, 1)
    scrollFrame:SetScrollChild(scrollChild)
    scrollFrame:SetScript("OnSizeChanged", function(_, width)
        scrollChild:SetWidth(math.max(1, width))
    end)

    emptyText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    emptyText:SetPoint("TOPLEFT", 18, -(CONTENT_TOP + 18))
    emptyText:SetPoint("TOPRIGHT", -18, -(CONTENT_TOP + 18))
    emptyText:SetJustifyH("CENTER")
    emptyText:SetWordWrap(true)

    platesButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    platesButton:SetSize(220, 24)
    platesButton:SetPoint("TOP", emptyText, "BOTTOM", 0, -14)
    platesButton:SetText(L.BTN_PLATES_ON)
    platesButton:SetScript("OnClick", function()
        ns:EnableNameplates()
    end)
    ns:SetTooltip(platesButton, L.BTN_PLATES_ON, L.TIP_PLATES)
    platesButton:Hide()

    resizeHandle = CreateFrame("Button", nil, frame)
    resizeHandle:SetSize(16, 16)
    resizeHandle:SetPoint("BOTTOMRIGHT", -2, 2)
    resizeHandle:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeHandle:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeHandle:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeHandle:SetScript("OnMouseDown", function()
        if not ns.db.window.locked then
            frame:StartSizing("BOTTOMRIGHT")
        end
    end)
    resizeHandle:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        SaveSize()
        SavePosition()
    end)
    ns:SetTooltip(resizeHandle, L.TIP_RESIZE_TITLE, L.TIP_RESIZE)
end
