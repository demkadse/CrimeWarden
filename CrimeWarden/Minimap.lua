local _, ns = ...
local L = ns.L

-- Einfacher Minimap-Button ohne Bibliothek. Die Position ist ein Winkel um
-- die Minimap und wird beim Ziehen gespeichert.
local MinimapButton = {}
ns.MinimapButton = MinimapButton

local ICON = "Interface\\Icons\\INV_Misc_Spyglass_03"
local BORDER = 136430 -- Interface\Minimap\MiniMap-TrackingBorder
local BACKGROUND = 136467 -- Interface\Minimap\UI-Minimap-Background
local HIGHLIGHT = 136477 -- Interface\Minimap\UI-Minimap-ZoomButton-Highlight

local button

local function UpdatePosition()
    local minimap = _G.Minimap
    local angle = math.rad(ns.db.minimap.angle)
    local radius = minimap:GetWidth() / 2 + 5
    button:ClearAllPoints()
    button:SetPoint("CENTER", minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function OnDragUpdate()
    local minimap = _G.Minimap
    local centerX, centerY = minimap:GetCenter()
    if not centerX then
        return
    end
    local cursorX, cursorY = GetCursorPosition()
    local scale = minimap:GetEffectiveScale()
    ns.db.minimap.angle = math.deg(math.atan2(cursorY / scale - centerY, cursorX / scale - centerX)) % 360
    UpdatePosition()
end

function MinimapButton:Refresh()
    if button then
        button:SetShown(ns.db.minimap.show)
    end
end

function MinimapButton:Init()
    local minimap = _G.Minimap
    if button or not minimap then
        return
    end

    button = CreateFrame("Button", "CrimeWardenMinimapButton", minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(minimap:GetFrameLevel() + 5)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture(HIGHLIGHT)

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetTexture(BACKGROUND)
    background:SetSize(24, 24)
    background:SetPoint("CENTER")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ICON)
    icon:SetSize(18, 18)
    icon:SetPoint("CENTER")
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture(BORDER)
    border:SetSize(50, 50)
    border:SetPoint("TOPLEFT")

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            if not ns.Config:Open() then
                ns:Print(L.OPTIONS_FAILED)
            end
        else
            ns.UI:Toggle()
        end
    end)
    button:SetScript("OnDragStart", function()
        button:LockHighlight()
        button:SetScript("OnUpdate", OnDragUpdate)
    end)
    button:SetScript("OnDragStop", function()
        button:SetScript("OnUpdate", nil)
        button:UnlockHighlight()
    end)
    button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(button, "ANCHOR_LEFT")
        GameTooltip:AddLine(L.TITLE)
        GameTooltip:AddLine(L.MINIMAP_TIP_LEFT, 0.9, 0.9, 0.9)
        GameTooltip:AddLine(L.MINIMAP_TIP_RIGHT, 0.9, 0.9, 0.9)
        GameTooltip:AddLine(L.MINIMAP_TIP_DRAG, 0.9, 0.9, 0.9)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        if GameTooltip:IsOwned(button) then
            GameTooltip:Hide()
        end
    end)

    UpdatePosition()
    self:Refresh()
end
