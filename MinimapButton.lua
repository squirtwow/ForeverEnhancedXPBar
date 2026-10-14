-- The minimap button (minimap, minimapAngle): left-click opens or closes the settings, right-click shows or hides the bar
-- (showBar), and dragging moves it round the minimap's edge. A sibling of Squirt's other addons' buttons: a dark circle in
-- the minimap's gold ring, here with the logo's rising chevron over a segmented bar. Its hover box is its own (Tip.lua;
-- the game's tooltip is never touched): your level and how far through it you are, how long until the next one, and what
-- the clicks do. Named (ForeverEnhancedXPBarMinimapButton) so minimap tidiers can find it.
local _, F = ...

local TP = F.Tip

local MB = {}
F.MinimapButton = MB

local RING_GAP = 4 -- how far out from the minimap's edge it sits
local AFTER_DRAG = .2 -- a click this soon after a drag is the drag letting go
local atan2 = math.atan2 or math.atan

local button, dragAngle
local dropped = -math.huge

-- Round the minimap's edge at the saved angle (degrees anticlockwise from the right), or where the cursor is mid-drag.
function MB:Place()
    if not button then return end
    local width = F.Number(Minimap:GetWidth()) or 140
    local angle = math.rad(dragAngle or F:Get("minimapAngle"))
    local radius = width / 2 + RING_GAP
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function Follow()
    local x, y = Minimap:GetCenter()
    local cursorX, cursorY = GetCursorPosition()
    x, y, cursorX, cursorY = F.Number(x), F.Number(y), F.Number(cursorX), F.Number(cursorY)
    if not (x and y and cursorX and cursorY) then return end
    local scale = F.Number(Minimap:GetEffectiveScale()) or 1
    dragAngle = math.floor(math.deg(atan2(cursorY / scale - y, cursorX / scale - x)) + .5) % 360
    MB:Place()
end

-- Saved once, where it was let go.
local function Drop(self)
    self:SetScript("OnUpdate", nil)
    self.isMoving = nil
    dropped = GetTime()
    local angle = dragAngle
    dragAngle = nil
    if angle then F:Set("minimapAngle", angle) end
    MB:Place()
end

-- The hover box: your level and how far through it, how long to the next, then the clicks.
function MB:TipContent()
    local TR = F.Track
    local st = TR.now
    local rows = {}
    if st.level then
        if TR:AtMax() then
            rows[#rows + 1] = { text = "Level " .. F.Commas(st.level) .. ", max level" }
        else
            rows[#rows + 1] = { text = "Level " .. F.Commas(st.level) .. ": " .. F.Percent(st.xp, st.max) }
            local eta = TR:EtaSeconds()
            if eta then rows[#rows + 1] = { text = F.Eta(eta) .. " to level" } end
        end
    end
    rows[#rows + 1] = { "Left-click", "settings" }
    rows[#rows + 1] = { "Right-click", F:Get("showBar") and "hide the bar" or "show the bar" }
    rows[#rows + 1] = { "Drag", "move it round the minimap" }
    return { title = F.TITLE, rows = rows, minWidth = 220 }
end

local function Build()
    button = CreateFrame("Button", "ForeverEnhancedXPBarMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel((F.Number(Minimap:GetFrameLevel()) or 1) + 8)
    local back = button:CreateTexture(nil, "BACKGROUND")
    back:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    back:SetSize(20, 20)
    back:SetPoint("CENTER")
    back:SetVertexColor(.067, .063, .082)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(F.MEDIA .. "MinimapIcon.tga")
    icon:SetSize(18, 18)
    icon:SetPoint("CENTER")
    button.icon = icon
    local ring = button:CreateTexture(nil, "OVERLAY")
    ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    ring:SetSize(54, 54)
    ring:SetPoint("TOPLEFT")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnClick", function(self, click)
        if GetTime() - dropped < AFTER_DRAG then return end
        if click == "RightButton" then
            F:Set("showBar", not F:Get("showBar"))
            TP:Update(self, MB:TipContent())
        elseif F.ToggleWindow then
            F.ToggleWindow()
        end
    end)
    -- isMoving tells minimap tidiers not to fade it mid-drag.
    button:SetScript("OnDragStart", function(self)
        TP:Hide(self)
        self.isMoving = true
        self:SetScript("OnUpdate", Follow)
    end)
    button:SetScript("OnDragStop", Drop)
    button:SetScript("OnHide", function(self)
        TP:Hide(self)
        if self.isMoving then Drop(self) end
    end)
    button:SetScript("OnEnter", function(self)
        if not self.isMoving then TP:Show(self, MB:TipContent()) end
    end)
    button:SetScript("OnLeave", function(self) TP:Hide(self) end)
end

function MB:Refresh()
    if not button then return end
    button:SetShown(F:Get("minimap") == true)
    self:Place()
end

function MB:Button()
    return button
end

-- Made once, when you log in (the saved settings have loaded by then).
function MB:Start()
    if button or not Minimap then return end
    Build()
    -- The minimap can change size: stay on its edge.
    Minimap:HookScript("OnSizeChanged", function() MB:Place() end)
    self:Refresh()
end

F:On("PLAYER_LOGIN", function() MB:Start() end)

F:Listen(function(what)
    if what == "minimap" or what == "minimapAngle" or what == "reset" then MB:Refresh() end
end)
