-- The bar (showBar, questSegment, restedSegment, lineUnder, questStripes, showAtMax, border, size, width, textShow,
-- textFormat), drawn to the user's mockup: a dark track with rounded ends (two end-cap masks on every piece, all square
-- if the game can't give every piece both), your XP in a blue-violet to violet gradient,
-- then the XP waiting in finished quests in solid amber (or amber stripes), then how far rested XP reaches in solid light
-- blue, each clamped to the bar's end; an optional thin dark edge (two one-pixel rings, rounded too); white outlined text
-- on it (your level at the left, your XP in the middle, your % at the right with, in brackets, your % once your finished
-- quests are handed in; a narrow bar drops the level, then the XP, before they overlap); and a line under it with the XP
-- in completed quests and your rested XP as shares of the level, in their parts' colours (short labels when the whole
-- line is wider than the bar). Hovering it (the line too) shows the addon's own box (Tip.lua). It is the addon's own frame,
-- under UIParent and anchored to it only, never protected; the mouse shows the box and a right-click opens a small menu
-- (unlock to move, settings, put it back), every other click goes through to the world.
--
-- Its spot is its track's middle from the screen's middle. On a first run (no spot saved) it waits 4 seconds after
-- entering the world, then sits just above whatever bottom bars cross the screen's middle, as wide as the action bar (or
-- EraUI's classic band); those frames are only read. "Put the bar back" and /xpbar reset do the same again; "Move the
-- bar" and /xpbar move show a box to drag it by.
local _, F = ...

local T, TR, QS, TP = F.Theme, F.Track, F.Quests, F.Tip
local COLOUR = T.B
local N = F.Number

local B = {}
F.Bar = B

local FLAT = T.FLAT
local STRIPES = F.MEDIA .. "Stripes.tga"
local STRIPE = 16 -- the stripes texture's size: its pattern repeats every 16 px
local DOT = "  \194\183  " -- a middle dot between two parts of the text
local PLACE_DELAY = 4 -- seconds after entering the world before a first run's placing
local PLACE_GAP = 6 -- between the highest bottom bar and the bar's track (the border takes 2 of it)
local CAST_LINE = 26 -- EraUI's band puts the player's cast bar this far above the highest bottom bar
local CAST_SLACK = 4 -- the most a bar placed under that line may pass it by (a Thick bar does)
local CAST_H = 16 -- the player cast bar's height when it can't be read
local CAST_CLEAR = 6 -- between the cast bar's top and a bar placed above it
local PLACE_SPAN = 200 -- frames must cross the middle 400 px of the screen
local PLACE_TOP = 300 -- frames whose top is higher than this aren't bottom bars
local PLACE_FROM = { "EraUIClassicBar", "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "StanceBar",
    "PetActionBar", "PossessActionBar", "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" }
local WIDE_FROM = { EraUIClassicBar = true, MainActionBar = true } -- whose width the bar takes (the first one seen)
local PLACE_W = { 400, 1200 }
local FALLBACK_W, FALLBACK_UP = 800, 150
local EDGE_ROOM = 2 -- the border's two rings sit outside the track
local TEXT_GAP = 2 -- between the border and text outside the track (Thin's text above, the line under)
local FIT_GAP = 8 -- the least room between two of the bar's texts
local TICK = 1 -- seconds between the hover box's refreshes

-- Per size: the corners' radius, the text's size and its inset from the bar's ends, and the line's text size.
local RADIUS = { thin = 2, normal = 4, thick = 5, large = 7 }
local TEXT_SIZE = { thin = 10, normal = 10, thick = 12, large = 14 }
local TEXT_INSET = { thin = 2, normal = 5, thick = 7, large = 10 }
local LINE_SIZE = { thin = 10, normal = 10, thick = 11, large = 12 }

-- The rounded ends: one mask over each end of a piece, as tall as the piece and the radius wide, so a texture takes two
-- (the game allows three at most). Each: its top and bottom points and which way is out (x); then each size's art (its
-- arcs drawn for that size's radius and height by Tools/GenerateArt.mjs).
local CAPS = { { "TOPLEFT", "BOTTOMLEFT", -1 }, { "TOPRIGHT", "BOTTOMRIGHT", 1 } }
local CAP_ART = {
    thin = { "CapL_thin.tga", "CapR_thin.tga" }, normal = { "CapL_normal.tga", "CapR_normal.tga" },
    thick = { "CapL_thick.tga", "CapR_thick.tga" }, large = { "CapL_large.tga", "CapR_large.tga" },
}

local bar, mover, track, fill, gradient, quest, rested, edges, texts, line
local masks = {} -- the end caps: track (the track and its parts), inner and outer (the border's rings); {} when square
local masked = {} -- every { texture, mask } added, so they can all be taken off again
local graded, stripesOk = false, false
local questStyle -- "solid" or "stripes": what the quest part shows now
local fontsFor -- the size the text was last set up for
local hovered, placed, waiting, moving, reopen = false, false, false, false, false
local ticker

-- Sizes -------------------------------------------------------------------------------------------------------------------

local function Size()
    local size = F:Get("size")
    return F.SIZES[size] and size or F.DEFAULTS.size
end

function B:Height()
    return F.SIZES[Size()]
end

-- The width setting, never wider than the screen.
function B:Width()
    local width = N(F:Get("width")) or F.DEFAULTS.width
    local screen = N(UIParent:GetWidth())
    if screen and screen > 0 then width = math.min(width, screen) end
    return math.max(F.WIDTH[1], width)
end

-- How far the bar reaches past its track, above and below: the border's room, or Thin's text above and the line under
-- the bar. Worked out from the settings alone (not from what shows this moment), so its place and hover area hold still.
function B:Room()
    local text = F:Get("textShow") ~= "never"
    local size = Size()
    local above, below = EDGE_ROOM, EDGE_ROOM
    if text and size == "thin" then above = EDGE_ROOM + TEXT_GAP + TEXT_SIZE.thin + 2 end
    if text and F:Get("lineUnder") and (F:Get("questSegment") or F:Get("restedSegment")) then
        below = EDGE_ROOM + TEXT_GAP + LINE_SIZE[size] + 2
    end
    return above, below
end

-- One physical pixel in the bar's units.
local function Pixel(frame)
    local scale = N(frame:GetEffectiveScale())
    local factor = PixelUtil and PixelUtil.GetPixelToUIUnitFactor and N(PixelUtil.GetPixelToUIUnitFactor())
    if scale and scale > 0 and factor and factor > 0 then return factor / scale end
    return 1
end

-- What the bar shows (no frames, so the tests can ask) ------------------------------------------------------------------

-- The parts in XP, each { from, to } and clamped to the bar: xp, then quest (XP waiting in finished quests), then rested
-- (after the quest part when it shows). A part that would be empty is left out.
function B.Spans(st, waitingXP, wantQuest, wantRested)
    local max = N(st.max)
    if not max or max <= 0 then return {} end
    local cur = math.max(0, math.min(N(st.xp) or 0, max))
    local spans = { xp = { 0, cur } }
    local after = cur
    if wantQuest and (waitingXP or 0) > 0 then
        local to = math.min(cur + waitingXP, max)
        if to > cur then
            spans.quest = { cur, to }
            after = to
        end
    end
    if wantRested and (N(st.rested) or 0) > 0 then
        local to = math.min(after + st.rested, max)
        if to > after then spans.rested = { after, to } end
    end
    return spans
end

-- A part in pixels: its left edge and width, each rounded to whole pixels; nil when under half a pixel.
function B.Pixels(span, max, width, px)
    if not span or max <= 0 then return nil end
    if (span[2] - span[1]) / max * width < .5 then return nil end
    local left = math.floor(span[1] / max * width / px + .5) * px
    local right = math.floor(span[2] / max * width / px + .5) * px
    if right - left <= 0 then return nil end
    return left, right - left
end

-- The text on the bar: left, middle and right (nil for none). At max level: your level, "Max level" and the XP in finished
-- quests (with its part ticked); with XP gain off: your level and that it's off; else your level, your XP (Numbers or
-- Both) and your % (Percent or Both) with, in brackets, your % once your finished quests are handed in (with their part
-- ticked and something waiting; over 100% when they'd level you up).
function B.Texts(st, waitingXP, format, atMax, off, wantQuest)
    local level = "Level " .. F.Commas(st.level)
    local waiting = N(waitingXP) or 0
    if atMax then
        return level, "Max level", (wantQuest and waiting > 0) and (F.Commas(waiting) .. " XP in finished quests") or nil
    end
    if off then return level, "XP gain is turned off", nil end
    local numbers, percent
    if format ~= "percent" then numbers = F.Commas(st.xp) .. " / " .. F.Commas(st.max) end
    if format ~= "numbers" then
        percent = F.Percent(st.xp, st.max)
        if wantQuest and waiting > 0 then
            percent = percent .. " (" .. F.Percent((N(st.xp) or 0) + waiting, st.max) .. ")"
        end
    end
    return level, numbers, percent
end

-- The line under the bar: the XP in completed quests and the rested XP, each as a share of this level in its part's
-- colour; only the ticked ones. nil with neither, at max level or with XP gain off. short: the short labels ("Quests:",
-- "Rested:") for a bar too narrow for the whole line.
function B.Line(st, waitingXP, atMax, off, wantQuest, wantRested, short)
    if atMax or off or not (wantQuest or wantRested) then return nil end
    local parts = {}
    if wantQuest then
        parts[#parts + 1] = (short and "Quests: " or "Completed quests: ")
            .. T:Paint(F.Percent(N(waitingXP) or 0, st.max), COLOUR.quest)
    end
    if wantRested then
        parts[#parts + 1] = (short and "Rested: " or "Rested experience: ")
            .. T:Paint(F.Percent(N(st.rested) or 0, st.max), COLOUR.rested)
    end
    return table.concat(parts, DOT)
end

-- Whether the text shows: Always, On hover (or at max level), Never.
function B.TextShown(mode, isHovered, atMax)
    if mode == "never" then return false end
    return mode == "always" or atMax or isHovered == true
end

-- Building ------------------------------------------------------------------------------------------------------------------

-- A flat colour on the plain white texture: masks round it, and the gradient needs a texture to colour.
local function Paint(texture, colour)
    texture:SetTexture(FLAT)
    texture:SetVertexColor(colour[1], colour[2], colour[3], colour[4] or 1)
end

local function Plate(colour, layer, sublevel)
    local texture = bar:CreateTexture(nil, layer, nil, sublevel)
    Paint(texture, colour)
    return texture
end

-- The XP part's gradient, if the game can draw one (SetGradient with two colours from CreateColor). False leaves the XP
-- part a flat violet.
local function Gradient(texture)
    if type(CreateColor) ~= "function" or type(texture.SetGradient) ~= "function" then return false end
    local from, to = COLOUR.xpFrom, COLOUR.xpTo
    return (pcall(function()
        texture:SetGradient("HORIZONTAL", CreateColor(from[1], from[2], from[3], 1), CreateColor(to[1], to[2], to[3], 1))
    end))
end

-- Takes every mask added off again: the whole bar is square.
local function Square()
    for _, pair in ipairs(masked) do pcall(pair[1].RemoveMaskTexture, pair[1], pair[2]) end
    masked, masks = {}, {}
end

-- A texture's masks as the game counts them (nil if it can't say).
local function MaskCount(texture)
    if type(texture.GetNumMaskTextures) ~= "function" then return nil end
    local ok, count = pcall(texture.GetNumMaskTextures, texture)
    return ok and N(count) or nil
end

-- A pair of end caps for each group of textures ({ name, textures }), placed later by PlaceCorners. All or nothing: if
-- the game can't make a mask, or any texture ends up without both, every mask is taken off again and the whole bar
-- stays square ({}).
local function Corners(groups)
    if type(bar.CreateMaskTexture) ~= "function" then return {} end
    local sets = {}
    local ok = pcall(function()
        for _, group in ipairs(groups) do
            local set = {}
            for i = 1, #CAPS do set[i] = assert(bar:CreateMaskTexture()) end
            sets[group[1]] = set
            for _, texture in ipairs(group[2]) do
                for _, mask in ipairs(set) do
                    texture:AddMaskTexture(mask)
                    masked[#masked + 1] = { texture, mask }
                end
            end
        end
    end)
    for _, group in ipairs(groups) do
        for _, texture in ipairs(group[2]) do
            local count = MaskCount(texture)
            if count and count ~= #CAPS then ok = false end
        end
    end
    if ok then return sets end
    Square()
    return {}
end

-- A pair of end caps for a size: the radius wide (plus out), over the track's ends and out from them by out all round.
-- False if the size's art won't load.
local function PlaceCorners(set, out, radius, size)
    if not set then return true end
    for i, cap in ipairs(CAPS) do
        local mask = set[i]
        if set.size ~= size and mask:SetTexture(F.MEDIA .. CAP_ART[size][i], "CLAMPTOWHITE", "CLAMPTOWHITE") == false then
            return false
        end
        mask:ClearAllPoints()
        mask:SetPoint(cap[1], bar, cap[1], cap[3] * out, out)
        mask:SetPoint(cap[2], bar, cap[2], cap[3] * out, -out)
        mask:SetWidth(radius + out)
    end
    set.size = size
    return true
end

local function NewText(justify)
    local text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetTextColor(COLOUR.text[1], COLOUR.text[2], COLOUR.text[3])
    text:SetShadowOffset(1, -1)
    text:SetShadowColor(0, 0, 0, 1)
    text:SetWordWrap(false)
    text:SetJustifyH(justify)
    return text
end

-- White outlined text in the game's own font (so every language's letters are there), its size following the bar's.
local function SetFont(text, size)
    local file = GameFontHighlight and GameFontHighlight.GetFont and F.Text((GameFontHighlight:GetFont()))
    if file then
        text:SetFont(file, size, "OUTLINE")
    else
        text:SetFontObject(GameFontHighlight)
    end
end

local function StopTicker()
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
end

local function ShowTip()
    TP:Show(bar, TP:BarContent(), "bar", B:Room())
    StopTicker()
    if TP:Owner() ~= bar then return end
    ticker = C_Timer.NewTicker(TICK, F:Guard("hover box", function()
        if TP:Owner() ~= bar then return StopTicker() end
        TP:Update(bar, TP:BarContent())
    end))
end

local function Build()
    if bar then return end
    bar = CreateFrame("Frame", "ForeverEnhancedXPBarFrame", UIParent)
    bar:SetSize(B:Width(), B:Height())
    bar:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    bar:SetFrameStrata("MEDIUM")
    bar:SetClampedToScreen(true)
    bar:SetClampRectInsets(-EDGE_ROOM, EDGE_ROOM, EDGE_ROOM, -EDGE_ROOM)
    -- The mouse shows the box, and a right-click opens the bar's menu; every other click goes through to the world.
    bar:SetMouseMotionEnabled(true)
    bar:SetMouseClickEnabled(true)
    if bar.SetPassThroughButtons then pcall(bar.SetPassThroughButtons, bar, "LeftButton", "MiddleButton", "Button4", "Button5") end
    bar:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then B:ShowMenu() end
    end)
    -- The border: two plates behind the track, one and two pixels bigger all round, so their rims are the two rings.
    edges = { Plate(COLOUR.edgeInner, "BACKGROUND", -1), Plate(COLOUR.edgeOuter, "BACKGROUND", -2) }
    track = Plate(COLOUR.track, "BACKGROUND", 0)
    track:SetAllPoints()
    fill = Plate(COLOUR.xp, "ARTWORK", 1)
    gradient = Plate({ 1, 1, 1, 1 }, "ARTWORK", 1)
    graded = Gradient(gradient)
    quest = Plate(COLOUR.quest, "ARTWORK", 2)
    -- The stripes are tried once: a file the game can't load leaves the quest part plain amber whatever the tick says.
    stripesOk = quest:SetTexture(STRIPES, "REPEAT", "REPEAT") ~= false
    Paint(quest, COLOUR.quest)
    questStyle = "solid"
    rested = Plate(COLOUR.rested, "ARTWORK", 3)
    masks = Corners({ { "track", { track, fill, gradient, quest, rested } }, { "inner", { edges[1] } },
        { "outer", { edges[2] } } })
    texts = { NewText("LEFT"), NewText("CENTER"), NewText("RIGHT") }
    line = NewText("CENTER")
    bar:SetScript("OnEnter", function()
        hovered = true
        ShowTip()
        B:Refresh()
    end)
    bar:SetScript("OnLeave", function()
        hovered = false
        TP:Hide(bar)
        StopTicker()
        B:Refresh()
    end)
    bar:SetScript("OnHide", function()
        hovered = false
        TP:Hide(bar)
        StopTicker()
    end)
    bar:Hide()
end

-- Drawing --------------------------------------------------------------------------------------------------------------------

-- Puts a part where its pixels say, or hides it.
local function Draw(texture, span, max, width, height, px)
    local left, size = B.Pixels(span, max, width, px)
    if not left then
        texture:Hide()
        return nil
    end
    texture:ClearAllPoints()
    texture:SetPoint("LEFT", bar, "LEFT", left, 0)
    texture:SetSize(size, height)
    texture:Show()
    return left, size
end

-- The quest part: amber stripes (when ticked and loaded) or solid amber.
local function QuestStyle(stripes)
    local style = stripes and "stripes" or "solid"
    if style == questStyle then return end
    questStyle = style
    if stripes then
        quest:SetTexture(STRIPES, "REPEAT", "REPEAT")
        quest:SetVertexColor(1, 1, 1, 1)
    else
        Paint(quest, COLOUR.quest)
        quest:SetTexCoord(0, 1, 0, 1)
    end
end

local function DrawParts(width, height, px)
    local st = TR.now
    local atMax, off = TR:AtMax(), TR:Off()
    -- The XP part: the gradient, or a flat colour (gold at max level, grey with XP gain off, violet with no gradient).
    local flat = (atMax and COLOUR.max) or (off and COLOUR.off) or (not graded and COLOUR.xp) or nil
    local xpPart = gradient
    if flat then
        xpPart = fill
        fill:SetVertexColor(flat[1], flat[2], flat[3], flat[4] or 1)
        gradient:Hide()
    else
        fill:Hide()
    end
    if atMax then
        Draw(fill, { 0, 1 }, 1, width, height, px)
        quest:Hide()
        rested:Hide()
        return
    end
    local spans = B.Spans(st, QS.sum, F:Get("questSegment") and not off, F:Get("restedSegment") and not off)
    Draw(xpPart, spans.xp, st.max, width, height, px)
    local stripes = stripesOk and F:Get("questStripes") == true
    QuestStyle(stripes)
    local left, size = Draw(quest, spans.quest, st.max, width, height, px)
    if left and stripes then quest:SetTexCoord(left / STRIPE, (left + size) / STRIPE, 0, height / STRIPE) end
    Draw(rested, spans.rested, st.max, width, height, px)
end

-- The text's fonts and places for a size: inside the track, or just above it for Thin; the line under the bar.
local function SetUpText(size)
    fontsFor = size
    for _, text in ipairs(texts) do
        SetFont(text, TEXT_SIZE[size])
        text:ClearAllPoints()
    end
    SetFont(line, LINE_SIZE[size])
    local inset = TEXT_INSET[size]
    if size == "thin" then
        local up = EDGE_ROOM + TEXT_GAP
        texts[1]:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", inset, up)
        texts[2]:SetPoint("BOTTOM", bar, "TOP", 0, up)
        texts[3]:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", -inset, up)
    else
        texts[1]:SetPoint("LEFT", bar, "LEFT", inset, 0)
        texts[2]:SetPoint("CENTER", bar, "CENTER", 0, 0)
        texts[3]:SetPoint("RIGHT", bar, "RIGHT", -inset, 0)
    end
    line:ClearAllPoints()
    line:SetPoint("TOP", bar, "BOTTOM", 0, -(EDGE_ROOM + TEXT_GAP))
end

-- Which of the three texts fit side by side: left, middle and right are their widths (0 for one not shown). The % always
-- stays; your XP goes if it would run into the %; then your level goes if it would run into whichever is still beside it
-- (your XP, or with that gone the %). So a narrow bar shows the level beside the % for as long as they fit.
function B.Fit(width, inset, left, middle, right)
    local half = width / 2
    local keepLeft, keepMiddle = left > 0, middle > 0
    if keepMiddle and right > 0 and half + middle / 2 + FIT_GAP > width - inset - right then keepMiddle = false end
    if keepLeft and keepMiddle and inset + left + FIT_GAP > half - middle / 2 then keepLeft = false end
    if keepLeft and not keepMiddle and right > 0 and inset + left + FIT_GAP > width - inset - right then keepLeft = false end
    return keepLeft, keepMiddle
end

local function Words(size, width)
    if fontsFor ~= size then SetUpText(size) end
    local st, atMax, off = TR.now, TR:AtMax(), TR:Off()
    local wantQuest, wantRested = F:Get("questSegment"), F:Get("restedSegment")
    local shown = B.TextShown(F:Get("textShow"), hovered, atMax)
    local words = { B.Texts(st, QS.sum, F:Get("textFormat"), atMax, off, wantQuest) }
    local has, wide = {}, {}
    for i, text in ipairs(texts) do
        text:SetText(words[i] or "")
        has[i] = shown and words[i] ~= nil
        wide[i] = has[i] and (N(text:GetStringWidth()) or 0) or 0
    end
    -- A text the game hasn't measured (0 wide) takes no room and is never dropped.
    local keepLeft, keepMiddle = B.Fit(width, TEXT_INSET[size], wide[1], wide[2], wide[3])
    texts[1]:SetShown(has[1] and (keepLeft or wide[1] <= 0))
    texts[2]:SetShown(has[2] and (keepMiddle or wide[2] <= 0))
    texts[3]:SetShown(has[3])
    local under = F:Get("lineUnder") and B.Line(st, QS.sum, atMax, off, wantQuest, wantRested) or nil
    line:SetText(under or "")
    -- Wider than the bar, it would hang past both ends (outside the hover area and the screen clamp): the short labels.
    if under and (N(line:GetStringWidth()) or 0) > width then
        under = B.Line(st, QS.sum, atMax, off, wantQuest, wantRested, true)
        line:SetText(under)
    end
    line:SetShown(shown and under ~= nil)
end

local function Layout()
    local width, height, size = B:Width(), B:Height(), Size()
    bar:SetSize(width, height)
    local spot = F:Spot()
    bar:ClearAllPoints()
    bar:SetPoint("CENTER", UIParent, "CENTER", spot and spot.x or 0, spot and spot.y or 0)
    -- The text above and the line under are the bar's too: for the mouse, and kept on the screen.
    local above, below = B:Room()
    bar:SetHitRectInsets(0, 0, -above, -below)
    bar:SetClampRectInsets(-EDGE_ROOM, EDGE_ROOM, above, -below)
    local px = Pixel(bar)
    local border = F:Get("border") == true
    for n, edge in ipairs(edges) do
        edge:ClearAllPoints()
        edge:SetPoint("TOPLEFT", bar, "TOPLEFT", -n * px, n * px)
        edge:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", n * px, -n * px)
        edge:SetShown(border)
    end
    -- The rounded ends; art that won't load leaves the whole bar square.
    local radius = RADIUS[size]
    if not (PlaceCorners(masks.track, 0, radius, size) and PlaceCorners(masks.inner, px, radius, size)
        and PlaceCorners(masks.outer, 2 * px, radius, size)) then
        Square()
    end
    DrawParts(width, height, px)
    Words(size, width)
end

-- Shown with its tick, once placed and read, not while being moved, and at max level only with showAtMax.
function B:ShouldShow()
    if not F:Get("showBar") or not placed or moving or not TR.now.level then return false end
    return not TR:AtMax() or F:Get("showAtMax") == true
end

function B:Refresh()
    if not bar then return end
    local show = self:ShouldShow()
    bar:SetShown(show)
    if show then Layout() end
end

function B:Frame()
    return bar
end

-- The bar's pieces (for the tests).
function B:Parts()
    return { track = track, fill = fill, gradient = gradient, graded = graded, quest = quest, rested = rested,
        edges = edges, masks = masks, texts = texts, line = line, stripesOk = stripesOk }
end

-- Placing ---------------------------------------------------------------------------------------------------------------------

-- A frame's left, right and top in UIParent's units, if it's shown, visible and can be read (never a secret).
local function Span(frame, screen)
    if type(frame) ~= "table" then return nil end
    local ok, shown, visible, alpha, scale, left, right, top = pcall(function()
        return frame:IsShown(), frame:IsVisible(), frame:GetAlpha(), frame:GetEffectiveScale(), frame:GetLeft(),
            frame:GetRight(), frame:GetTop()
    end)
    if not ok or F.Bool(shown) ~= true or F.Bool(visible) ~= true then return nil end
    alpha, scale, left, right, top = N(alpha), N(scale), N(left), N(right), N(top)
    if not alpha or alpha <= 0 or not scale or scale <= 0 or not left or not right or not top then return nil end
    local k = scale / screen
    return left * k, right * k, top * k
end

-- The player cast bar's height in UIParent's units (read only, never a secret), or CAST_H if it can't be read.
local function CastHeight(screen)
    local frame = _G.PlayerCastingBarFrame
    if type(frame) ~= "table" then return CAST_H end
    local ok, height, scale = pcall(function() return frame:GetHeight(), frame:GetEffectiveScale() end)
    height, scale = ok and N(height), ok and N(scale)
    if not height or height <= 0 or not scale or scale <= 0 then return CAST_H end
    return height * scale / screen
end

-- The bottom bars that cross the screen's middle: the highest top among them, the action bar's (or band's) width, whether
-- EraUI's band is among them (it puts the cast bar on its line then) and the cast bar's height.
function B:Measure()
    local screen = N(UIParent:GetEffectiveScale())
    local wide, high = N(UIParent:GetWidth()), N(UIParent:GetHeight())
    if not screen or screen <= 0 or not wide or wide <= 0 or not high or high <= 0 then return nil end
    local centre = wide / 2
    local found = { screenW = wide, screenH = high, seen = {}, band = false }
    for _, name in ipairs(PLACE_FROM) do
        local left, right, top = Span(_G[name], screen)
        if left and left < centre + PLACE_SPAN and right > centre - PLACE_SPAN and top <= PLACE_TOP then
            found.seen[#found.seen + 1] = name
            if not found.top or top > found.top then found.top = top end
            if WIDE_FROM[name] and not found.width then found.width = right - left end
            if name == "EraUIClassicBar" then found.band = true end
        end
    end
    found.cast = CastHeight(screen)
    return found
end

-- Places the bar above the bottom bars (or 150 px up, 800 wide, with nothing to go by) and saves it like a drag.
function B:PutBack()
    local found = self:Measure()
    if not found then return false end
    local width = math.min(PLACE_W[2], found.width or FALLBACK_W, found.screenW - 40)
    width = math.floor(math.max(PLACE_W[1], width) / 10 + .5) * 10
    F:Set("width", width)
    -- From the bars' top to the bar's lowest edge (its border, or the line under it). A bar that fits under the cast-bar
    -- line keeps 4 px clear, closing up as it gets taller (so a Normal bar's top is on that line, and a Thick one, which
    -- can't fit, passes it by 4 px with its border on the bars). One taller than that goes above the cast bar when EraUI's
    -- band puts it on that line; without the band the line holds nothing, so it stays 4 px clear.
    local above, below = self:Room()
    local tall = above + self:Height() + below
    local base
    if not found.top then
        base = FALLBACK_UP - EDGE_ROOM
    elseif tall <= CAST_LINE + CAST_SLACK then
        base = found.top + math.max(0, math.min(PLACE_GAP - EDGE_ROOM, CAST_LINE - tall))
    elseif found.band then
        base = found.top + CAST_LINE + found.cast + CAST_CLEAR
    else
        base = found.top + PLACE_GAP - EDGE_ROOM
    end
    F:SetSpot(0, base + below + self:Height() / 2 - found.screenH / 2)
    placed = true
    F:DevLog("place", { t = GetTime(), top = found.top, width = found.width, seen = table.concat(found.seen, " "),
        band = found.band, cast = found.cast, tall = tall, spotY = F:Spot() and F:Spot().y, barWidth = width })
    self:Refresh()
    return true
end

local function OnEnterWorld()
    Build()
    if F:Spot() then
        placed = true
        return B:Refresh()
    end
    if waiting then return end
    waiting = true
    C_Timer.After(PLACE_DELAY, F:Guard("bar", function()
        waiting = false
        if F:Spot() then
            placed = true
            B:Refresh()
        else
            B:PutBack()
        end
    end))
end

-- Moving it -------------------------------------------------------------------------------------------------------------------
-- A box the bar's size (its text above and line under too) to drag. The settings window steps aside meanwhile; Done (or a
-- right-click) brings it back.

-- The box's middle from the track's: half the difference between the room above and below.
local function MoverShift()
    local above, below = B:Room()
    return (above - below) / 2
end

local function PlaceMover()
    local above, below = B:Room()
    local width, height = B:Width(), B:Height()
    mover:SetSize(width + 8, math.max(height + above + below + 4, 26))
    local spot = F:Spot()
    mover:ClearAllPoints()
    mover:SetPoint("CENTER", UIParent, "CENTER", spot and spot.x or 0, (spot and spot.y or 0) + MoverShift())
    mover.preview:ClearAllPoints()
    mover.preview:SetPoint("CENTER", mover, "CENTER", 0, -MoverShift())
    mover.preview:SetSize(width, height)
end

-- Lets go of the box where it is now: its middle from the screen's (less the shift) is the bar's new spot. Kept out of the
-- game's own layout.
local function Drop(frame)
    if not frame.dragging then return end
    frame.dragging = nil
    frame:StopMovingOrSizing()
    if frame.SetUserPlaced then frame:SetUserPlaced(false) end
    local x, y = frame:GetCenter()
    local cx, cy = UIParent:GetCenter()
    x, y, cx, cy = N(x), N(y), N(cx), N(cy)
    if x and y and cx and cy then F:SetSpot(x - cx, y - cy - MoverShift()) end
    placed = true
    PlaceMover()
end

local function BuildMover()
    if mover then return end
    local C = T.C
    mover = CreateFrame("Frame", "ForeverEnhancedXPBarMover", UIParent, "BackdropTemplate")
    mover:SetSize(B:Width() + 8, B:Height() + 8)
    mover:SetFrameStrata("DIALOG")
    mover:SetClampedToScreen(true)
    mover:SetMovable(true)
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")
    T:Flat(mover, { 0, 0, 0, .45 }, T.ACCENT)
    local preview = T:Block(mover, COLOUR.track, "ARTWORK")
    preview:SetPoint("CENTER")
    preview:SetSize(B:Width(), B:Height())
    mover.preview = preview
    local half = mover:CreateTexture(nil, "ARTWORK", nil, 1)
    T:Fill(half, COLOUR.xp, .7)
    half:SetPoint("TOPLEFT", preview, "TOPLEFT")
    half:SetPoint("BOTTOMRIGHT", preview, "BOTTOM")
    mover.title = T:Heading(mover, "XP bar")
    mover.title:SetPoint("BOTTOM", mover, "TOP", 0, 6)
    mover.title:SetJustifyH("CENTER")
    mover.done = T:Button(mover, "Done", true)
    mover.done:SetPoint("TOP", mover, "BOTTOM", 0, -6)
    mover.done:SetScript("OnClick", function() B:StopMove() end)
    mover.note = T:Text(mover, "GameFontHighlightSmall", C.soft)
    mover.note:SetPoint("TOP", mover.done, "BOTTOM", 0, -4)
    mover.note:SetJustifyH("CENTER")
    mover.note:SetText("Drag the bar, then click Done or right-click it.")
    mover:SetScript("OnDragStart", function(self)
        self.dragging = true
        self:StartMoving()
    end)
    -- Right-click finishes too, should Done be off the screen's edge.
    mover:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then B:StopMove() end
    end)
    mover:SetScript("OnDragStop", Drop)
    -- Hidden mid-drag, it would never hear the mouse let go.
    mover:SetScript("OnHide", Drop)
    mover:Hide()
end

function B:StartMove()
    Build()
    BuildMover()
    if not F:Spot() then self:PutBack() end
    moving = true
    PlaceMover()
    mover:Show()
    reopen = F.window ~= nil and F.window:IsShown()
    if reopen then F.window:Hide() end
    self:Refresh()
    return true
end

function B:StopMove()
    if not moving then return end
    Drop(mover)
    moving = false
    mover:Hide()
    self:Refresh()
    if reopen and F.ShowWindow then
        reopen = false
        F.ShowWindow()
        if F.window and F.window.Select then F.window:Select("bar") end
    end
end

function B:Moving()
    return moving
end

-- The right-click menu ----------------------------------------------------------------------------------------------------
-- Unlock to move, the settings, or the bar put back. It closes once the mouse has been off it and the bar (its text and
-- line too) a moment, or when one of its buttons is clicked.

local menu
local MENU_AWAY = .6 -- seconds off the menu and the bar before it closes
local MENU_ITEMS = {
    { label = "Unlock to move", run = function() B:StartMove() end },
    { label = "Settings", run = function() if F.ToggleWindow then F.ToggleWindow() end end },
    { label = "Put the bar back", run = function() B:PutBack() end },
}

local function BuildMenu()
    menu = CreateFrame("Frame", "ForeverEnhancedXPBarMenu", UIParent, "BackdropTemplate")
    menu:SetFrameStrata("DIALOG")
    menu:SetClampedToScreen(true)
    menu:EnableMouse(true)
    T:Flat(menu, T.C.window, T.ACCENT)
    local wide = 0
    menu.buttons = {}
    for i, item in ipairs(MENU_ITEMS) do
        local button = T:Button(menu, item.label)
        button:SetScript("OnClick", function()
            menu:Hide()
            item.run()
        end)
        button:SetPoint("TOP", menu, "TOP", 0, -8 - (i - 1) * 34)
        wide = math.max(wide, button:GetWidth() or 0)
        menu.buttons[i] = button
    end
    for _, button in ipairs(menu.buttons) do button:SetWidth(wide) end
    menu:SetSize(wide + 16, 16 + #MENU_ITEMS * 34 - 4)
    menu:SetScript("OnUpdate", function(self, elapsed)
        local above, below = B:Room()
        if self:IsMouseOver() or (bar and bar:IsMouseOver(above, -below, 0, 0)) then
            self.away = 0
            return
        end
        self.away = (self.away or 0) + elapsed
        if self.away > MENU_AWAY then self:Hide() end
    end)
    menu:Hide()
end

function B:ShowMenu()
    if not bar or moving then return end
    if not menu then BuildMenu() end
    TP:Hide(bar)
    local above = self:Room()
    menu:ClearAllPoints()
    menu:SetPoint("BOTTOM", bar, "TOP", 0, above + 6)
    menu.away = 0
    menu:Show()
end

function B:Menu()
    return menu
end

function B:Mover()
    return mover
end

-- Listening ----------------------------------------------------------------------------------------------------------------------

local REDRAW = { showBar = true, questSegment = true, restedSegment = true, lineUnder = true, questStripes = true,
    showAtMax = true, border = true, size = true, width = true, textShow = true, textFormat = true, xp = true,
    quests = true, spot = true, levelup = true }

F:Listen(function(what)
    if not bar then return end
    if what == "reset" then
        B:PutBack()
    elseif REDRAW[what] then
        B:Refresh()
        if moving then PlaceMover() end
    end
    if TP:Owner() == bar then TP:Update(bar, TP:BarContent()) end
end)

F:On("PLAYER_LOGIN", Build)
F:On("PLAYER_ENTERING_WORLD", OnEnterWorld)
F:On("UI_SCALE_CHANGED", function() B:Refresh() end)
F:On("DISPLAY_SIZE_CHANGED", function() B:Refresh() end)
