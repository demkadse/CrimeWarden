local _, ns = ...
local L = ns.L
local Range = ns.Range

-- Einstellungsseite unter Interface > AddOns. Der 9.2.7-Client hat noch
-- die alte InterfaceOptions-API; die neue Settings-API wird nur genutzt,
-- falls sie vorhanden ist. Jedes Bedienelement hat einen erklärenden Tooltip.
local Config = {}
ns.Config = Config

local LEFT, RIGHT = 16, 330

local panel, category
local controls = {}

-- Ankreuzfeld; der Text gehört zur Klickfläche und zeigt denselben Tooltip.
local function Checkbox(label, tip, x, y, onClick)
    local box = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    box:SetPoint("TOPLEFT", x, y)
    box:SetSize(26, 26)
    box:SetHitRectInsets(0, -250, 0, 0)
    local text = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", box, "RIGHT", 4, 0)
    text:SetText(label)
    box:SetScript("OnClick", function(self)
        onClick(self:GetChecked() and true or false)
    end)
    ns:SetTooltip(box, label, tip)
    return box
end

local function Button(label, tip, width, onClick)
    local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    button:SetSize(width, 24)
    button:SetText(label)
    button:SetScript("OnClick", onClick)
    ns:SetTooltip(button, label, tip)
    return button
end

local function Header(label, x, y)
    local header = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", x, y)
    header:SetText(label)
    return header
end

-- Textzeile mit "-" und "+" daneben. Beide Knöpfe tragen den Tooltip.
local function Stepper(x, y, title, tip, onStep)
    local text = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("TOPLEFT", x + 4, y)
    local minus = Button("-", tip, 26, function() onStep(-1) end)
    minus:SetPoint("TOPLEFT", x + 190, y + 5)
    ns:SetTooltip(minus, title, tip)
    local plus = Button("+", tip, 26, function() onStep(1) end)
    plus:SetPoint("LEFT", minus, "RIGHT", 4, 0)
    ns:SetTooltip(plus, title, tip)
    -- Auch gesperrt soll der Tooltip erklären, warum.
    minus:SetMotionScriptsWhileDisabled(true)
    plus:SetMotionScriptsWhileDisabled(true)
    return text, minus, plus
end

-- Textzeile mit einem Umschalt-Knopf daneben.
local function Toggle(x, y, title, tip, onClick)
    local text = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("TOPLEFT", x + 4, y)
    local button = Button(L.BTN_TOGGLE, tip, 100, onClick)
    button:SetPoint("TOPLEFT", x + 190, y + 5)
    ns:SetTooltip(button, title, tip)
    return text
end

-- Nächste oder vorherige Stufe aus Range.STEPS.
local function ShiftStep(current, direction)
    local index = 1
    for i, step in ipairs(Range.STEPS) do
        if step == current then
            index = i
        end
    end
    index = math.max(1, math.min(#Range.STEPS, index + direction))
    return Range.STEPS[index]
end

function Config:Refresh()
    if not panel then
        return
    end
    local warning, sources = ns.db.warning, ns.db.sources
    controls.lock:SetChecked(ns.db.window.locked)
    controls.hideHostile:SetChecked(ns.db.hideHostile)
    controls.minimap:SetChecked(ns.db.minimap.show)
    controls.sortText:SetText(L.OPT_SORT:format(ns.db.sortBy == "name" and L.SORT_NAME or L.SORT_DISTANCE))
    controls.radiusText:SetText(L.OPT_RADIUS:format(ns.db.radius))
    local following = ns.ChatRangeSync:IsFollowing()
    if following then
        controls.sayRangeText:SetText(L.OPT_SAY_RANGE_FOLLOW:format(ns:GetSayRange()))
    else
        controls.sayRangeText:SetText(L.OPT_SAY_RANGE:format(ns.db.sayRange))
    end
    controls.sayRangeMinus:SetEnabled(not following)
    controls.sayRangePlus:SetEnabled(not following)
    controls.chatRangeFollow:SetChecked(ns.db.chatRange.follow)
    controls.chatRangeStatus:SetText(ns.ChatRangeSync:GetStatus())
    controls.windowButton:SetText(ns.UI:IsShown() and L.BTN_WINDOW_HIDE or L.BTN_WINDOW_SHOW)

    controls.modeSwitch:Update()
    controls.warnYardsText:SetText(L.OPT_WARN_YARDS:format(ns.Warden:GetYards()))
    controls.warnBanner:SetChecked(warning.banner)
    controls.warnSound:SetChecked(warning.sound)
    controls.warnChat:SetChecked(warning.chat)
    controls.warnGroup:SetChecked(warning.ignoreGroup)

    controls.srcGroup:SetChecked(sources.group)
    controls.srcLocator:SetChecked(sources.locator)
    controls.intervalText:SetText(L.OPT_LOCATOR_INTERVAL:format(sources.locatorInterval))
    controls.srcSenses:SetChecked(sources.senses)

    local ready = ns:NameplatesReady()
    controls.platesText:SetText(L.OPT_PLATES:format(ready and L.PLATES_STATE_ON or L.PLATES_STATE_OFF))
    controls.platesButton:SetEnabled(not ready)
end

local function BuildListSection()
    Header(L.SECTION_LIST, LEFT, -64)
    controls.lock = Checkbox(L.OPT_LOCK, L.TIP_LOCK, LEFT, -88, function(checked)
        ns.db.window.locked = checked
        ns.UI:ApplyWindow()
    end)
    controls.hideHostile = Checkbox(L.OPT_HIDE_HOSTILE, L.TIP_HIDE_HOSTILE, LEFT, -114, function(checked)
        ns.db.hideHostile = checked
        ns.UI:Refresh()
    end)
    controls.minimap = Checkbox(L.OPT_MINIMAP, L.TIP_MINIMAP, LEFT, -140, function(checked)
        ns.db.minimap.show = checked
        ns.MinimapButton:Refresh()
    end)
    controls.sortText = Toggle(LEFT, -178, L.TIP_SORT_TITLE, L.TIP_SORT, function()
        ns.db.sortBy = ns.db.sortBy == "name" and "distance" or "name"
        ns:SettingsChanged()
    end)
    controls.radiusText = Stepper(LEFT, -210, L.TIP_RADIUS_TITLE, L.TIP_RADIUS, function(direction)
        ns.db.radius = ns:ClampRadius(ShiftStep(ns.db.radius, direction))
        ns:SettingsChanged()
    end)

    controls.sayRangeText, controls.sayRangeMinus, controls.sayRangePlus = Stepper(LEFT, -238,
        L.TIP_SAY_RANGE_TITLE, L.TIP_SAY_RANGE, function(direction)
        ns.db.sayRange = ns:ClampSayRange(ShiftStep(ns.db.sayRange, direction))
        ns:SettingsChanged()
    end)

    local resetButton = Button(L.BTN_RESET, L.TIP_RESET, 160, function()
        ns:ResetWindow()
        ns:Print(L.WINDOW_RESET)
    end)
    resetButton:SetPoint("TOPLEFT", LEFT + 4, -266)
    controls.windowButton = Button(L.BTN_WINDOW_HIDE, L.TIP_WINDOW, 130, function()
        ns.UI:Toggle()
        Config:Refresh()
    end)
    controls.windowButton:SetPoint("LEFT", resetButton, "RIGHT", 6, 0)
end

local function BuildWarningSection()
    local warning = ns.db.warning
    Header(L.SECTION_WARN, RIGHT, -64)
    local modeLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    modeLabel:SetPoint("TOPLEFT", RIGHT + 4, -96)
    modeLabel:SetText(L.OPT_MODE_LABEL)
    controls.modeSwitch = ns.UI:CreateModeSwitch(panel, 160, 22)
    controls.modeSwitch:SetPoint("TOPLEFT", RIGHT + 110, -91)
    controls.warnYardsText = Stepper(RIGHT, -126, L.TIP_WARN_YARDS_TITLE, L.TIP_WARN_YARDS, function(direction)
        ns.Warden:SetYards(ShiftStep(ns.Warden:GetYards(), direction))
        ns:SettingsChanged()
    end)
    controls.warnBanner = Checkbox(L.OPT_WARN_BANNER, L.TIP_WARN_BANNER, RIGHT, -152, function(checked)
        warning.banner = checked
    end)
    controls.warnSound = Checkbox(L.OPT_WARN_SOUND, L.TIP_WARN_SOUND, RIGHT, -178, function(checked)
        warning.sound = checked
    end)
    controls.warnChat = Checkbox(L.OPT_WARN_CHAT, L.TIP_WARN_CHAT, RIGHT, -204, function(checked)
        warning.chat = checked
    end)
    controls.warnGroup = Checkbox(L.OPT_WARN_GROUP, L.TIP_WARN_GROUP, RIGHT, -230, function(checked)
        warning.ignoreGroup = checked
    end)
    local testButton = Button(L.BTN_TEST_WARNING, L.TIP_TEST_WARNING, 180, function()
        ns.Warden:TestWarning()
    end)
    testButton:SetPoint("TOPLEFT", RIGHT + 4, -262)
end

local function BuildSourcesSection()
    local sources = ns.db.sources
    Header(L.SECTION_SOURCES, LEFT, -306)
    controls.srcGroup = Checkbox(L.OPT_SRC_GROUP, L.TIP_SRC_GROUP, LEFT, -330, function(checked)
        sources.group = checked
        ns:SourcesChanged()
    end)
    controls.srcLocator = Checkbox(L.OPT_SRC_LOCATOR, L.TIP_SRC_LOCATOR, LEFT, -356, function(checked)
        sources.locator = checked
        ns:SourcesChanged()
    end)
    controls.intervalText = Stepper(LEFT + 30, -390, L.TIP_INTERVAL_TITLE, L.TIP_INTERVAL, function(direction)
        sources.locatorInterval = ns:ClampInterval(sources.locatorInterval + direction * 5)
        Config:Refresh()
    end)
    controls.srcSenses = Checkbox(L.OPT_SRC_SENSES, L.TIP_SRC_SENSES, LEFT, -412, function(checked)
        sources.senses = checked
        ns:SourcesChanged()
    end)
end

local function BuildChatRangeSection()
    Header(L.SECTION_CHATRANGE, RIGHT, -398)
    controls.chatRangeFollow = Checkbox(L.OPT_CHATRANGE_FOLLOW, L.TIP_CHATRANGE_FOLLOW, RIGHT, -422, function(checked)
        ns.db.chatRange.follow = checked
        ns.ChatRangeSync:Read()
        ns:SettingsChanged()
    end)
    controls.chatRangeStatus = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    controls.chatRangeStatus:SetPoint("TOPLEFT", RIGHT + 4, -452)
    controls.chatRangeStatus:SetWidth(270)
    controls.chatRangeStatus:SetJustifyH("LEFT")
    controls.chatRangeStatus:SetWordWrap(true)
end

local function BuildPlatesSection()
    Header(L.SECTION_PLATES, RIGHT, -300)
    controls.platesText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    controls.platesText:SetPoint("TOPLEFT", RIGHT + 4, -326)
    controls.platesText:SetWidth(270)
    controls.platesText:SetJustifyH("LEFT")
    controls.platesButton = Button(L.BTN_PLATES_ON, L.TIP_PLATES, 220, function()
        ns:EnableNameplates()
    end)
    controls.platesButton:SetPoint("TOPLEFT", RIGHT + 4, -362)
    -- Auch deaktiviert (Plaketten schon richtig eingestellt) soll der Tooltip erscheinen.
    controls.platesButton:SetMotionScriptsWhileDisabled(true)
end

function Config:Init()
    if panel then
        return
    end

    panel = CreateFrame("Frame", nil, UIParent)
    panel.name = L.TITLE
    panel:Hide()

    local heading = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    heading:SetPoint("TOPLEFT", 16, -16)
    heading:SetText(L.TITLE)

    local description = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -6)
    description:SetText(L.OPT_DESC)

    BuildListSection()
    BuildWarningSection()
    BuildSourcesSection()
    BuildPlatesSection()
    BuildChatRangeSection()

    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", LEFT + 4, -490)
    hint:SetWidth(580)
    hint:SetJustifyH("LEFT")
    hint:SetWordWrap(true)
    hint:SetText(L.OPT_PLATES_HINT)

    panel:SetScript("OnShow", function()
        Config:Refresh()
    end)

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

function Config:Open()
    if category and Settings and Settings.OpenToCategory then
        return pcall(Settings.OpenToCategory, category:GetID())
    end
    if InterfaceOptionsFrame_OpenToCategory then
        -- Der erste Aufruf öffnet oft nur das Fenster, ohne die Seite zu wählen.
        local ok = pcall(InterfaceOptionsFrame_OpenToCategory, panel)
        if ok then
            pcall(InterfaceOptionsFrame_OpenToCategory, panel)
        end
        return ok
    end
    return false
end
