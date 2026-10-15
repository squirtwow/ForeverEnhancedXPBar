-- The addon's look. The settings window keeps the family look (flat dark panels with thin borders, gold headings, the
-- family purple as the one accent); the bar follows the user's mockup: XP in a blue-violet to violet gradient, XP waiting
-- in finished quests in a deep orange to warm gold one, rested in a deeper blue to sky blue one (each flat if the game
-- can't draw it), a dark rounded track with a thin dark edge and white text. The hover box keeps the first mockup's
-- palette. Every piece is given its size as it's made, so nothing waits on a first refresh to have one.
local _, F = ...

local T = {}
F.Theme = T

local FLAT = "Interface\\Buttons\\WHITE8X8"
T.FLAT = FLAT

local function Rgb(hex, alpha)
    return { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255,
        alpha or 1 }
end
T.Rgb = Rgb

-- The settings window (the family look).
T.C = {
    window = Rgb("0e1014"), edge = Rgb("2a2d35"),
    nav = Rgb("06070a"), navEdge = Rgb("22252c"), navHover = Rgb("0c0e12"), navSelected = Rgb("12151b"),
    text = Rgb("e8e6e1"), soft = Rgb("94a0ad"), muted = Rgb("8d96a3"), dim = Rgb("6f7a86"),
    gold = Rgb("edbf52"), tag = Rgb("a39a86"),
    row = Rgb("14171c"), rowEdge = Rgb("1d2128"), rowHover = Rgb("1a1e25"), rowHoverEdge = Rgb("2c313a"),
    tickEdge = Rgb("4d525c"), tickBack = Rgb("0f1013"),
    option = Rgb("0f1216"), optionEdge = Rgb("2f343e"), onAccent = Rgb("0d0e12"),
    button = Rgb("1b1f27"), buttonEdge = Rgb("3a3f4a"), groove = Rgb("2f343e"),
}
T.ACCENT = F.ACCENT

-- The bar (the user's mockup). Each part fades left to right from its From to its To; xp, quest and rested are the flat
-- colours used when the game can't draw a gradient (about halfway between the two ends), quest and rested also the line's.
T.B = {
    track = Rgb("121017"), xpFrom = Rgb("6a6af7"), xpTo = Rgb("c56ef7"), xp = Rgb("986cf7"),
    questFrom = Rgb("f0821e"), questTo = Rgb("ffbe3c"), quest = Rgb("ffa500"),
    restedFrom = Rgb("3a7ff0"), restedTo = Rgb("80c4ff"), rested = Rgb("5aa0ff"),
    max = Rgb("a8873e"), off = Rgb("5e5a68"),
    edgeInner = Rgb("000000"), edgeOuter = Rgb("2e2a38"), text = Rgb("ffffff"),
}

-- The hover box (the mockup).
T.TIP = {
    back = Rgb("0a090e", .92), edge = Rgb("3a3446"), title = Rgb("c9a8ff"), line = Rgb("2d2838"),
    label = Rgb("a59fb2"), value = Rgb("f1eef6"), footer = Rgb("847d92"),
}

function T:Hex(colour)
    local function Byte(v) return math.floor(math.max(0, math.min(1, v)) * 255 + .5) end
    return ("%02x%02x%02x"):format(Byte(colour[1]), Byte(colour[2]), Byte(colour[3]))
end

-- Text in a colour, for one piece of a longer line.
function T:Paint(text, colour)
    return "|cff" .. self:Hex(colour) .. text .. "|r"
end

function T:Fill(texture, colour, alpha)
    texture:SetColorTexture(colour[1], colour[2], colour[3], alpha or colour[4] or 1)
end

function T:Flat(frame, fill, edge, alpha)
    frame:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
    frame:SetBackdropColor(fill[1], fill[2], fill[3], alpha or fill[4] or 1)
    edge = edge or self.C.edge
    frame:SetBackdropBorderColor(edge[1], edge[2], edge[3], 1)
end

-- A plain colour block.
function T:Block(parent, colour, layer)
    local texture = parent:CreateTexture(nil, layer or "BACKGROUND")
    self:Fill(texture, colour)
    return texture
end

function T:Text(parent, font, colour)
    local text = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    text:SetJustifyH("LEFT")
    colour = colour or self.C.text
    text:SetTextColor(colour[1], colour[2], colour[3])
    return text
end

-- A section heading: small gold capitals.
function T:Heading(parent, label)
    local text = self:Text(parent, "GameFontNormalSmall", self.C.gold)
    text:SetText(label:upper())
    return text
end

-- A row the width given, with a square tick in the accent, its label and a quiet tag after it (lower case, never boxed).
-- SetBlocked greys it out while it can't be used (the window ignores its clicks then and says why).
function T:Tick(parent, width, label, tag)
    local C = self.C
    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetSize(width, 30)
    self:Flat(row, C.row, C.rowEdge)
    local box = CreateFrame("Frame", nil, row, "BackdropTemplate")
    box:SetSize(13, 13)
    box:SetPoint("LEFT", 10, 0)
    self:Flat(box, C.tickBack, C.tickEdge)
    box:EnableMouse(false)
    local fill = box:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", 3, -3)
    fill:SetPoint("BOTTOMRIGHT", -3, 3)
    self:Fill(fill, self.ACCENT)
    fill:Hide()
    row.box, row.fill = box, fill
    row.label = self:Text(row, "GameFontHighlight")
    row.label:SetPoint("LEFT", box, "RIGHT", 9, 0)
    row.label:SetText(label)
    if tag then
        row.tag = self:Text(row, "GameFontHighlightSmall", C.tag)
        row.tag:SetPoint("LEFT", row.label, "RIGHT", 5, 0)
        row.tag:SetText(tag:lower())
    end
    function row:SetChecked(on)
        self.checked = on and true or false
        self.fill:SetShown(self.checked)
    end
    function row:GetChecked()
        return self.checked == true
    end
    function row:SetBlocked(blocked)
        self.blocked = blocked and true or false
        local alpha = self.blocked and .4 or 1
        self.box:SetAlpha(alpha)
        self.label:SetAlpha(alpha)
        if self.tag then self.tag:SetAlpha(alpha) end
    end
    row:SetScript("OnEnter", function(self)
        self:SetBackdropColor(C.rowHover[1], C.rowHover[2], C.rowHover[3], 1)
        self:SetBackdropBorderColor(C.rowHoverEdge[1], C.rowHoverEdge[2], C.rowHoverEdge[3], 1)
    end)
    row:SetScript("OnLeave", function(self)
        self:SetBackdropColor(C.row[1], C.row[2], C.row[3], 1)
        self:SetBackdropBorderColor(C.rowEdge[1], C.rowEdge[2], C.rowEdge[3], 1)
    end)
    row:SetChecked(false)
    row:SetBlocked(false)
    return row
end

-- One choice among several; the chosen one fills with the accent.
function T:Option(parent, label)
    local C = self.C
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button.label = self:Text(button, "GameFontNormalSmall", C.soft)
    button.label:SetPoint("CENTER")
    button.label:SetJustifyH("CENTER")
    button.label:SetText(label)
    button:SetSize(math.floor((button.label:GetStringWidth() or 60) + 20 + .5), 24)
    self:Flat(button, C.option, C.optionEdge)
    local accent = self.ACCENT
    function button:SetSelected(on)
        self.selected = on and true or false
        local fill = self.selected and accent or C.option
        local edge = self.selected and accent or C.optionEdge
        local text = self.selected and C.onAccent or C.soft
        self:SetBackdropColor(fill[1], fill[2], fill[3], 1)
        self:SetBackdropBorderColor(edge[1], edge[2], edge[3], 1)
        self.label:SetTextColor(text[1], text[2], text[3])
        -- The font's dark shadow smears dark text on the accent.
        self.label:SetShadowColor(0, 0, 0, self.selected and 0 or 1)
    end
    button:SetScript("OnEnter", function(self)
        if not self.selected then self.label:SetTextColor(C.text[1], C.text[2], C.text[3]) end
    end)
    button:SetScript("OnLeave", function(self) self:SetSelected(self.selected) end)
    button:SetSelected(false)
    return button
end

-- Options side by side from the left, 6 apart: { key, label } each. onPick(key) runs on a click. Returns the bar, sized
-- to fit, and its buttons by key.
function T:Options(parent, items, onPick)
    local bar = CreateFrame("Frame", nil, parent)
    bar.buttons, bar.order = {}, {}
    local x = 0
    for _, item in ipairs(items) do
        local button = self:Option(bar, item.label)
        button:SetPoint("LEFT", x, 0)
        button.key = item.key
        button:SetScript("OnClick", function() onPick(item.key) end)
        bar.buttons[item.key] = button
        bar.order[#bar.order + 1] = button
        x = x + button:GetWidth() + 6
    end
    bar:SetSize(math.max(1, x - 6), 24)
    function bar:Select(key)
        self.selected = key
        for buttonKey, button in pairs(self.buttons) do button:SetSelected(buttonKey == key) end
    end
    return bar
end

-- A full-width row: its label on the left and its options on the right.
function T:Choice(parent, width, label, items, onPick)
    local C = self.C
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetSize(width, 34)
    self:Flat(row, C.row, C.rowEdge)
    row:EnableMouse(true)
    row.label = self:Text(row, "GameFontHighlight")
    row.label:SetPoint("LEFT", 12, 0)
    row.label:SetText(label)
    row.options = self:Options(row, items, onPick)
    row.options:SetPoint("RIGHT", -6, 0)
    function row:Select(key)
        self.options:Select(key)
    end
    return row
end

-- A full-width row with a flat slider: the label, a thin groove filled with the accent up to a square thumb, and the
-- value. Drag it, click the groove, or use the wheel. limits: { from, to }, changed later with SetLimits. onChange runs
-- with each new value (snapped to the step, kept within the limits).
function T:Slider(parent, width, label, limits, step, onChange)
    local C = self.C
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetSize(width, 34)
    self:Flat(row, C.row, C.rowEdge)
    row:EnableMouse(true)
    row.label = self:Text(row, "GameFontHighlight")
    row.label:SetPoint("LEFT", 12, 0)
    row.label:SetText(label)
    row.value = self:Text(row, "GameFontHighlight")
    row.value:SetPoint("RIGHT", -12, 0)
    row.value:SetSize(48, 20)
    row.value:SetJustifyH("RIGHT")
    local track = CreateFrame("Frame", nil, row)
    track:SetPoint("LEFT", 150, 0)
    track:SetPoint("RIGHT", -70, 0)
    track:SetSize(width - 220, 16)
    track:EnableMouse(true)
    local groove = self:Block(track, C.groove)
    groove:SetPoint("LEFT")
    groove:SetPoint("RIGHT")
    groove:SetHeight(4)
    local fill = self:Block(track, self.ACCENT, "ARTWORK")
    fill:SetPoint("LEFT")
    fill:SetSize(1, 4)
    local thumb = self:Block(track, C.text, "OVERLAY")
    thumb:SetSize(10, 10)
    row.track, row.fill, row.thumb = track, fill, thumb
    row.limits = { limits[1], limits[2] }

    function row:SetLimits(from, to)
        self.limits = { from, math.max(from + step, to) }
        if self.current then self:Set(self.current) end
    end
    function row:Set(value)
        self.current = value
        self.value:SetText(F.Commas(value))
        local length = track:GetWidth() or 0
        local from, to = self.limits[1], self.limits[2]
        local share = math.max(0, math.min(1, (value - from) / (to - from)))
        fill:SetWidth(math.max(1, length * share))
        thumb:ClearAllPoints()
        thumb:SetPoint("CENTER", track, "LEFT", length * share, 0)
    end
    -- Snapped to the step and kept within the limits; only a new value is sent.
    function row:Choose(value)
        local from, to = self.limits[1], self.limits[2]
        value = from + math.floor((value - from) / step + .5) * step
        value = math.max(from, math.min(to - (to - from) % step, value))
        if value == self.current then return end
        self:Set(value)
        onChange(value)
    end
    local function FromCursor()
        local x = GetCursorPosition() / (track:GetEffectiveScale() or 1)
        local length = math.max(1, track:GetWidth() or 1)
        local from, to = row.limits[1], row.limits[2]
        row:Choose(from + (x - (track:GetLeft() or 0)) / length * (to - from))
    end
    track:SetScript("OnMouseDown", function()
        FromCursor()
        track:SetScript("OnUpdate", FromCursor)
    end)
    track:SetScript("OnMouseUp", function() track:SetScript("OnUpdate", nil) end)
    -- Hidden mid-drag (the window closed), it never hears the mouse let go.
    track:SetScript("OnHide", function() track:SetScript("OnUpdate", nil) end)
    -- The groove's width is only known once it's drawn.
    track:SetScript("OnSizeChanged", function() if row.current then row:Set(row.current) end end)
    row:EnableMouseWheel(true)
    row:SetScript("OnMouseWheel", function(self, delta) self:Choose((self.current or self.limits[1]) + delta * step) end)
    return row
end

-- A plain button sized to its label, the edge lit while the mouse is on it. accent: filled with the accent.
function T:Button(parent, label, accent)
    local C = self.C
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button.label = self:Text(button, "GameFontHighlight", accent and C.onAccent or C.text)
    button.label:SetPoint("CENTER")
    button.label:SetJustifyH("CENTER")
    button.label:SetText(label)
    if accent then button.label:SetShadowColor(0, 0, 0, 0) end
    button:SetSize(math.max(80, math.floor((button.label:GetStringWidth() or 60) + 28 + .5)), 30)
    local edge = accent and self.ACCENT or C.buttonEdge
    self:Flat(button, accent and self.ACCENT or C.button, edge)
    button:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(C.text[1], C.text[2], C.text[3], 1) end)
    button:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(edge[1], edge[2], edge[3], 1) end)
    return button
end

-- A small square button (a window's close).
function T:Square(parent, label)
    local C = self.C
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(22, 22)
    self:Flat(button, C.option, C.optionEdge)
    button.label = self:Text(button, "GameFontHighlight", C.soft)
    button.label:SetPoint("CENTER")
    button.label:SetJustifyH("CENTER")
    button.label:SetText(label)
    button:SetScript("OnEnter", function(self) self.label:SetTextColor(C.text[1], C.text[2], C.text[3]) end)
    button:SetScript("OnLeave", function(self) self.label:SetTextColor(C.soft[1], C.soft[2], C.soft[3]) end)
    return button
end

-- A list that scrolls with the mouse wheel, pinned by two corners to the parent (insets: left, top, right, bottom), with
-- a thin accent thumb. Its content is width wide; set its height once filled.
function T:Scroll(parent, insets, width)
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    -- Pinned again a moment after it shows: a scroll frame first laid out under a parent with no size can stay blank.
    function scroll:Pin()
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", parent, "TOPLEFT", insets[1], -insets[2])
        self:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -insets[3], insets[4])
    end
    scroll:Pin()
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(width, 1)
    scroll:SetScrollChild(content)
    scroll.content = content
    local thumb = parent:CreateTexture(nil, "ARTWORK")
    thumb:SetWidth(3)
    self:Fill(thumb, self.ACCENT, .8)
    thumb:Hide()
    scroll.thumb = thumb
    local function Range()
        local view = scroll:GetHeight() or 0
        if view <= 0 then return 0 end
        return math.max(0, (content:GetHeight() or 0) - view)
    end
    function scroll:UpdateThumb()
        local view, range = self:GetHeight() or 0, Range()
        if range <= 0 or view <= 0 then
            thumb:Hide()
            return
        end
        local size = math.max(16, view * view / (view + range))
        local offset = (view - size) * (self:GetVerticalScroll() or 0) / range
        thumb:SetHeight(size)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOPLEFT", self, "TOPRIGHT", 4, -offset)
        thumb:Show()
    end
    function scroll:ScrollTo(offset)
        self:SetVerticalScroll(math.max(0, math.min(Range(), offset)))
        self:UpdateThumb()
    end
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta) self:ScrollTo((self:GetVerticalScroll() or 0) - delta * 40) end)
    scroll:SetScript("OnSizeChanged", function(self) self:ScrollTo(self:GetVerticalScroll() or 0) end)
    return scroll
end

-- "Made with <heart> by Squirt", the heart and name in the accent. The font has no heart, so it's a small white texture
-- tinted inline.
function T:Credit()
    local A = F.ACCENT
    local r, g, b = math.floor(A[1] * 255 + .5), math.floor(A[2] * 255 + .5), math.floor(A[3] * 255 + .5)
    return ("Made with |T%sHeart.tga:0:0:0:0:32:32:0:32:0:32:%d:%d:%d|t by |cff%sSquirt|r"):format(F.MEDIA, r, g, b,
        F.ACCENT_HEX)
end
