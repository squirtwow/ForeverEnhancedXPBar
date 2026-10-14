-- The /xpbar settings window: pages down the left, the page on the right and a footer that explains whatever is under the
-- mouse (at rest, "Made with <heart> by Squirt"). Every page but Good to know is drawn from Core.lua's rows: ticks in two
-- columns, choices, the width slider and the action buttons (Move the bar, Put the bar back, Start a new session). A row
-- that can't be used right now is greyed and the footer says why. Changes apply to the real bar at once. Reset all
-- settings and Start a new session ask first, inside the window. Escape closes it.
local _, F = ...

local T = F.Theme
local C = T.C

local WIDTH, HEIGHT, NAV, FOOTER = 820, 560, 190, 46
local PAGE_W, PAGE_H = WIDTH - NAV - 2, HEIGHT - FOOTER - 5
local PAD, BODY_TOP = 24, 82
local INNER = PAGE_W - PAD * 2
local GAP, ROW_H, ROW_GAP = 10, 30, 4
local COLUMN = math.floor((INNER - GAP) / 2)
local ASK_WAIT = .5 -- seconds a Yes ignores clicks after the question shows

F.WINDOW_SIZE = { WIDTH, HEIGHT }

-- The footer -----------------------------------------------------------------------------------------------------------

local function BuildFooter(window)
    local footer = CreateFrame("Frame", nil, window)
    footer:SetPoint("BOTTOMLEFT", NAV + 1, 1)
    footer:SetPoint("BOTTOMRIGHT", -1, 1)
    footer:SetSize(PAGE_W, FOOTER)
    local line = T:Block(footer, C.navEdge, "BORDER")
    line:SetPoint("TOPLEFT")
    line:SetPoint("TOPRIGHT")
    line:SetHeight(1)
    local note = T:Text(footer, "GameFontHighlightSmall", C.soft)
    note:SetPoint("TOPLEFT", PAD, -6)
    note:SetPoint("BOTTOMRIGHT", -PAD, 5)
    note:SetJustifyV("MIDDLE")
    note:SetWordWrap(true)
    window.note = note
    function window:ShowNote()
        local control = self.hovered
        if control and not control:IsVisible() then control, self.hovered = nil, nil end
        local text
        if control then
            local about = control.hintText
            if type(about) == "function" then about = about(control) end
            text = T:Paint(control.hintTitle, C.text) .. "  " .. (about or "")
        end
        note:SetText(text or self.message or T:Credit())
    end
    function window:Say(text)
        self.message = text
        self:ShowNote()
    end
    function window:Hint(control, title, text)
        control.hintTitle, control.hintText = title, text
        control:HookScript("OnEnter", function()
            window.hovered = control
            window:ShowNote()
        end)
        control:HookScript("OnLeave", function()
            if window.hovered == control then
                window.hovered = nil
                window:ShowNote()
            end
        end)
    end
end

-- The page list ----------------------------------------------------------------------------------------------------------

local function NavItem(window, nav, page, y)
    local item = CreateFrame("Button", nil, nav)
    item:SetPoint("TOPLEFT", 0, -y)
    item:SetSize(NAV, 32)
    item.fill = T:Block(item, C.navSelected)
    item.fill:SetAllPoints()
    item.hover = T:Block(item, C.navHover)
    item.hover:SetAllPoints()
    item.hover:Hide()
    item.mark = T:Block(item, T.ACCENT, "ARTWORK")
    item.mark:SetPoint("TOPLEFT")
    item.mark:SetPoint("BOTTOMLEFT")
    item.mark:SetWidth(3)
    item.label = T:Text(item, "GameFontHighlight", C.soft)
    item.label:SetPoint("LEFT", 18, 0)
    item.label:SetText(page.label)
    item.key = page.key
    item:SetScript("OnClick", function() window:Select(page.key) end)
    item:SetScript("OnEnter", function(self)
        if window.selected ~= self.key then
            self.hover:Show()
            self.label:SetTextColor(C.text[1], C.text[2], C.text[3])
        end
    end)
    item:SetScript("OnLeave", function(self)
        self.hover:Hide()
        local colour = window.selected == self.key and C.text or C.soft
        self.label:SetTextColor(colour[1], colour[2], colour[3])
    end)
    window:Hint(item, page.label, page.about)
    return item
end

local function BuildNav(window)
    local nav = CreateFrame("Frame", nil, window, "BackdropTemplate")
    nav:SetPoint("TOPLEFT", 1, -4)
    nav:SetPoint("BOTTOMLEFT", 1, 1)
    nav:SetSize(NAV, HEIGHT - 5)
    T:Flat(nav, C.nav, C.nav)
    local edge = T:Block(nav, C.navEdge, "BORDER")
    edge:SetPoint("TOPRIGHT")
    edge:SetPoint("BOTTOMRIGHT")
    edge:SetWidth(1)
    local logo = nav:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(F.MEDIA .. "Logo.tga")
    logo:SetSize(36, 36)
    logo:SetPoint("TOPLEFT", 16, -16)
    local title = T:Text(nav, "GameFontNormalLarge", T.ACCENT)
    title:SetPoint("TOPLEFT", 58, -16)
    title:SetWidth(NAV - 66)
    title:SetText(F.TITLE)
    window.title = title
    local status = T:Text(nav, "GameFontHighlightSmall", C.muted)
    status:SetPoint("TOPLEFT", 18, -64)
    status:SetWidth(NAV - 30)
    window.status = status
    window.nav = {}
    local y = 88
    for _, page in ipairs(F.PAGES) do
        window.nav[page.key] = NavItem(window, nav, page, y)
        y = y + 32
    end
    local open = T:Text(nav, "GameFontHighlightSmall", C.dim)
    open:SetPoint("BOTTOMLEFT", 18, 16)
    open:SetText(F.SLASH .. " to open")
end

-- Asking first ----------------------------------------------------------------------------------------------------------------
-- A button that asks "Are you sure?" with a Yes (yesLabel) and Cancel, here in the window. Yes ignores clicks for a
-- moment after the question shows, so a double click can't do it. Cancel, another page or closing the window puts the
-- button back.

local function Asker(window, holder, button, yesLabel, onYes, help)
    local ask = T:Text(holder, "GameFontHighlight")
    ask:SetText("Are you sure?")
    local yes = T:Button(holder, yesLabel, true)
    local no = T:Button(holder, "Cancel")
    local asker = { button = button, ask = ask, yes = yes, no = no, asking = false }
    function asker:Ask(asking)
        self.asking = asking and true or false
        if self.asking then self.askedAt = GetTime() end
        button:SetShown(not self.asking)
        ask:SetShown(self.asking)
        yes:SetShown(self.asking)
        no:SetShown(self.asking)
        window:ShowNote()
    end
    button:SetScript("OnClick", function() asker:Ask(true) end)
    no:SetScript("OnClick", function() asker:Ask(false) end)
    yes:SetScript("OnClick", function()
        if GetTime() - (asker.askedAt or 0) < ASK_WAIT then return end
        asker:Ask(false)
        onYes()
    end)
    window:Hint(yes, yesLabel, help)
    window:Hint(no, "Cancel", "Leaves things as they are.")
    window.askers[#window.askers + 1] = asker
    asker:Ask(false)
    return asker
end

-- The list pages ---------------------------------------------------------------------------------------------------------

local function Heading(parent, label, y)
    local heading = T:Heading(parent, label)
    heading:SetPoint("TOPLEFT", 0, -y)
    return heading
end

-- The footer's text for a row: why it can't be used, or what it does.
local function About(row)
    return function()
        local reason = row.blocked and row.blocked()
        if reason then return reason end
        return row.desc .. (row.tag and (" (" .. row.tag .. ")") or "")
    end
end

local function TickControl(window, content, row, x, y)
    local tick = T:Tick(content, COLUMN, row.label, row.tag)
    tick:SetPoint("TOPLEFT", x, -y)
    tick:SetScript("OnClick", function(self)
        if self.blocked then return window:ShowNote() end
        F:Set(row.key, not F:Get(row.key))
    end)
    return tick
end

local function ChoiceControl(window, content, row, y)
    local choice = T:Choice(content, INNER, row.label, row.options, function(key) F:Set(row.key, key) end)
    choice:SetPoint("TOPLEFT", 0, -y)
    for _, button in ipairs(choice.options.order) do
        window:Hint(button, row.label .. ": " .. button.label:GetText(), row.desc)
    end
    return choice
end

local function SliderControl(window, content, row, y)
    local limits = row.slider
    local slider = T:Slider(content, INNER, row.label, { limits[1], limits[2] }, limits[3],
        function(value) F:Set(row.key, value) end)
    slider:SetPoint("TOPLEFT", 0, -y)
    window:Hint(slider.track, row.label, row.desc)
    return slider
end

-- What each action button does.
local ACTIONS = {
    move = function() if F.Bar then F.Bar:StartMove() end end,
    putBack = function(window)
        if F.Bar and F.Bar:PutBack() then window:Say("The bar is back above your action bars.") end
    end,
    newSession = function(window)
        if F.Track then F.Track:NewSession() end
        window:Say("A new session has started.")
    end,
}

local function ButtonsControl(window, content, row, y)
    local holder = CreateFrame("Frame", nil, content)
    holder:SetPoint("TOPLEFT", 0, -y)
    holder:SetSize(INNER, 30)
    local x = 0
    for _, item in ipairs(row.buttons) do
        local button = T:Button(holder, item.label)
        button:SetPoint("LEFT", x, 0)
        x = x + button:GetWidth() + 8
        window:Hint(button, item.label, item.desc)
        window.actions[item.key] = button
        local run = function() ACTIONS[item.key](window) end
        if item.ask then
            local asker = Asker(window, holder, button, "Start", run, item.desc)
            asker.ask:SetPoint("LEFT", button, "LEFT", 0, 0)
            asker.yes:SetPoint("LEFT", asker.ask, "RIGHT", 12, 0)
            asker.no:SetPoint("LEFT", asker.yes, "RIGHT", 6, 0)
            window.asks[item.key] = asker
        else
            button:SetScript("OnClick", run)
        end
    end
    return holder
end

local function BuildList(window, page, sections)
    local scroll = T:Scroll(page, { PAD, BODY_TOP, PAD, 46 }, INNER)
    page.scroll = scroll
    local content = scroll.content
    local y = 0
    for _, section in ipairs(sections) do
        Heading(content, section.title, y)
        y = y + 20
        local column = 0
        for _, row in ipairs(section.rows) do
            local full = row.options or row.slider or row.buttons
            if full and column == 1 then y, column = y + ROW_H + ROW_GAP, 0 end
            if row.buttons then
                ButtonsControl(window, content, row, y)
                y = y + 30 + ROW_GAP
            elseif row.options then
                window.controls[row.key] = ChoiceControl(window, content, row, y)
                y = y + 34 + ROW_GAP
            elseif row.slider then
                window.controls[row.key] = SliderControl(window, content, row, y)
                y = y + 34 + ROW_GAP
            else
                local tick = TickControl(window, content, row, column * (COLUMN + GAP), y)
                window:Hint(tick, row.label, About(row))
                window.controls[row.key] = tick
                if column == 1 then y, column = y + ROW_H + ROW_GAP, 0 else column = 1 end
            end
        end
        if column == 1 then y = y + ROW_H + ROW_GAP end
        y = y + 14
    end
    content:SetHeight(y)
end

local function BuildGoodToKnow(window, page)
    local scroll = T:Scroll(page, { PAD, BODY_TOP, PAD, 46 }, INNER)
    page.scroll = scroll
    local content = scroll.content
    local width = math.min(INNER, 560)
    local y = 0
    window.cards = {}
    for i, card in ipairs(F.GOOD_TO_KNOW) do
        local frame = CreateFrame("Frame", nil, content, "BackdropTemplate")
        frame:SetSize(width, 60)
        T:Flat(frame, C.row, C.rowEdge)
        frame:SetPoint("TOPLEFT", 0, -y)
        local title = T:Text(frame, "GameFontHighlight")
        title:SetPoint("TOPLEFT", 14, -12)
        title:SetText(card.title)
        local text = T:Text(frame, "GameFontHighlightSmall", C.soft)
        text:SetPoint("TOPLEFT", 14, -32)
        text:SetWidth(width - 28)
        text:SetText(card.text)
        local height = math.max(60, 32 + math.ceil(text:GetStringHeight() or 14) + 12)
        frame:SetHeight(height)
        y = y + height + 10
        window.cards[i] = frame
    end
    content:SetHeight(y)
end

-- Reset all settings, at the bottom right.
local RESET_HELP = "Every option goes back to how it started and the bar is placed again. Your numbers stay."

local function BuildReset(window)
    local row = CreateFrame("Frame", nil, window)
    row:SetPoint("BOTTOMRIGHT", -PAD, FOOTER + 8)
    row:SetSize(PAGE_W - PAD * 2, 30)
    local button = T:Button(row, "Reset all settings")
    button:SetPoint("RIGHT")
    local asker = Asker(window, row, button, "Reset", function() F:Reset() end, RESET_HELP)
    asker.no:SetPoint("RIGHT")
    asker.yes:SetPoint("RIGHT", asker.no, "LEFT", -6, 0)
    asker.ask:SetPoint("RIGHT", asker.yes, "LEFT", -12, 0)
    window:Hint(button, "Reset all settings", RESET_HELP)
    window.reset = asker
end

-- The window -------------------------------------------------------------------------------------------------------------

local function BuildPage(window, page)
    local frame = CreateFrame("Frame", nil, window)
    frame:SetPoint("TOPLEFT", NAV + 1, -4)
    frame:SetPoint("BOTTOMRIGHT", -1, FOOTER + 1)
    frame:SetSize(PAGE_W, PAGE_H)
    frame:Hide()
    local title = T:Text(frame, "GameFontNormalHuge", C.gold)
    title:SetPoint("TOPLEFT", PAD, -22)
    title:SetText(page.label)
    local about = T:Text(frame, "GameFontHighlight", C.soft)
    about:SetPoint("TOPLEFT", PAD, -52)
    about:SetWidth(INNER - 30)
    about:SetText(page.about)
    if page.key == "limits" then
        BuildGoodToKnow(window, frame)
    else
        BuildList(window, frame, F.SECTIONS[page.key])
    end
    -- Pinned again a moment after it shows (see Theme.lua's T:Scroll).
    frame:SetScript("OnShow", function(self)
        local scroll = self.scroll
        if scroll then
            C_Timer.After(0, F:Guard("window", function()
                scroll:Pin()
                scroll:ScrollTo(scroll:GetVerticalScroll() or 0)
            end))
        end
    end)
    window.pages[page.key] = frame
end

-- At the largest UI scales the screen is smaller than the window: then it shrinks to fit.
local EDGE = 8
local function Fit(window)
    local wide, high = F.Number(UIParent:GetWidth()), F.Number(UIParent:GetHeight())
    local scale = 1
    if wide and wide > 0 then scale = math.min(scale, (wide - EDGE * 2) / WIDTH) end
    if high and high > 0 then scale = math.min(scale, (high - EDGE * 2) / HEIGHT) end
    window:SetScale(math.max(.5, scale))
end

-- "Level 24: 63.2%".
local function Status()
    local TR = F.Track
    local st = TR.now
    if not st.level then return "" end
    if TR:AtMax() then return "Level " .. F.Commas(st.level) .. ", max level" end
    if TR:Off() then return "Level " .. F.Commas(st.level) .. ", XP gain off" end
    return "Level " .. F.Commas(st.level) .. ": " .. F.Percent(st.xp, st.max)
end

-- The width slider goes up to the screen's width.
local function WidthLimit()
    local wide = F.Number(UIParent:GetWidth()) or F.WIDTH[2]
    return math.max(F.WIDTH[1] + F.WIDTH[3], math.min(F.WIDTH[2], math.floor(wide / F.WIDTH[3]) * F.WIDTH[3]))
end

local function RefreshControls(window)
    for key, control in pairs(window.controls) do
        local row = F.ROWS[key]
        if row.options then
            control:Select(F:Get(key))
        elseif row.slider then
            control:SetLimits(row.slider[1], WidthLimit())
            control:Set(F:Get(key))
        else
            control:SetChecked(F:Get(key))
            control:SetBlocked(row.blocked ~= nil and row.blocked() ~= nil)
        end
    end
end

local function Build()
    local window = CreateFrame("Frame", "ForeverEnhancedXPBarSettings", UIParent, "BackdropTemplate")
    window:SetSize(WIDTH, HEIGHT)
    window:SetPoint("CENTER", 0, 30)
    window:SetFrameStrata("DIALOG")
    window:SetToplevel(true)
    window:SetClampedToScreen(true)
    window:EnableMouse(true)
    window:SetMovable(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if self.SetUserPlaced then self:SetUserPlaced(false) end
    end)
    T:Flat(window, C.window, C.edge)
    local accent = T:Block(window, T.ACCENT, "ARTWORK")
    accent:SetPoint("TOPLEFT", 1, -1)
    accent:SetPoint("TOPRIGHT", -1, -1)
    accent:SetHeight(3)
    window:Hide()
    -- Escape closes it, through the game's own list of windows it closes (never by changing key bindings).
    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "ForeverEnhancedXPBarSettings") end
    window.pages, window.controls, window.actions, window.asks, window.askers = {}, {}, {}, {}, {}
    BuildFooter(window)
    BuildNav(window)
    for _, page in ipairs(F.PAGES) do BuildPage(window, page) end
    BuildReset(window)
    local close = T:Square(window, "x")
    close:SetPoint("TOPRIGHT", -10, -12)
    close:SetScript("OnClick", function() window:Hide() end)
    window:Hint(close, "Close", "Escape closes it too, and " .. F.SLASH .. " opens it again.")
    window.close = close

    window.selected = "bar"
    function window:Select(key)
        if not self.pages[key] then return end
        if key ~= self.selected then
            for _, asker in ipairs(self.askers) do asker:Ask(false) end
        end
        self.selected = key
        self.hovered = nil
        self:Refresh()
    end
    function window:Refresh()
        self.status:SetText(Status())
        for key, item in pairs(self.nav) do
            local chosen = key == self.selected
            item.fill:SetShown(chosen)
            item.mark:SetShown(chosen)
            local colour = chosen and C.text or C.soft
            item.label:SetTextColor(colour[1], colour[2], colour[3])
        end
        for key, page in pairs(self.pages) do page:SetShown(key == self.selected) end
        RefreshControls(self)
        self:ShowNote()
    end
    window:SetScript("OnShow", function(self)
        Fit(self)
        self:Refresh()
    end)
    window:SetScript("OnHide", function(self)
        self:StopMovingOrSizing()
        for _, asker in ipairs(self.askers) do asker:Ask(false) end
        self.hovered, self.message = nil, nil
    end)
    return window
end

function F.ShowWindow()
    F.window = F.window or Build()
    F.window:Show()
    F.window:Refresh()
end

function F.ToggleWindow()
    if F.window and F.window:IsShown() then
        F.window:Hide()
    else
        F.ShowWindow()
    end
end

-- Settings, the game's XP bar's state and the numbers in the status line: redrawn while it's open.
F:Listen(function(what)
    if F.window and F.window:IsShown() and what ~= "kills" then F.window:Refresh() end
end)
