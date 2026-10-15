-- Bar.lua: the bar's frame (the addon's own, under UIParent, motion only), its parts (XP in a gradient, then the XP waiting
-- in finished quests in an amber gradient, then rested in a blue one; each clamped to the end, an empty or sub-pixel part
-- hidden, rounded to whole pixels, as tall as the track and on its middle), flat violet, amber and blue when the game has
-- no gradient or refuses one (even later on), the XP gradient never tinted over and the other two put back on every
-- redraw, the stripes as a choice (in their own colours, still as the part grows, the amber gradient if the texture won't load),
-- the rounded ends (two end-cap masks on every piece, within the game's three; all square when the game can't make,
-- add or load them, even partway), the border's two rings, the four sizes and their fonts, the text (level, XP and %;
-- Always, On hover, Never; Numbers, Percent, Both; the bracketed % with finished quests; max level and XP off; a narrow
-- bar dropping your XP, then the level if it won't fit beside the %), the line under the bar (its colours, its ticks,
-- hidden with the text, short labels when it's wider than the bar), the shadows, the room it all takes (hover area,
-- screen clamp), when it shows, first-run placing (with EraUI's band,
-- without, with nothing readable; hidden, faded, secret, scaled and high frames; each size with and without the line
-- against EraUI's cast-bar line, and above the cast bar when too tall), the mover, the width, Put the bar back and a reset.
-- Run with fengari: Tools/TestBar.lua
local H = assert(loadfile("Tools/Harness.lua"))()
local S, Equal, True = H.S, H.Equal, H.True
local F, B, P, bar

local FLAT = "Interface\\Buttons\\WHITE8X8"
local MEDIA = "Interface\\AddOns\\ForeverEnhancedXPBar\\Media\\"
local DOT = "  \194\183  "

-- saved: a table, or "placed" for a new one with the bar's spot already saved (never shared between loads).
local function Fresh(saved, setup)
    H.Environment()
    H.pixelFactor = 1
    if setup then setup() end
    if saved == "placed" then saved = { version = 1, spot = { x = 0, y = -300 } } end
    F = H.Load(saved)
    B = F.Bar
    bar = B:Frame()
    P = B:Parts()
    return F
end

-- A part: its left edge, width, and whether it's shown.
local function Box(texture)
    local p = S[texture].points[1]
    return p and p[4], S[texture].width, texture:IsShown()
end

local function Waiting(xp)
    H.quests = { { questID = 1, title = "Done", complete = true, xp = xp } }
    H.Fire("QUEST_LOG_UPDATE")
    H.Frame()
end

-- A colour as hex, from a texture's tint or a theme colour.
local function Hex(c)
    return string.format("%02x%02x%02x", math.floor(c[1] * 255 + .5), math.floor(c[2] * 255 + .5), math.floor(c[3] * 255 + .5))
end

-- A texture's gradient as "orientation from to" (hex), or "none".
local function Ends(texture)
    local g = S[texture].gradient
    if not g then return "none" end
    return g[1] .. " " .. Hex({ g[2].r, g[2].g, g[2].b }) .. " " .. Hex({ g[3].r, g[3].g, g[3].b })
end
local AMBER, BLUE = "HORIZONTAL f0821e ffbe3c", "HORIZONTAL 3a7ff0 80c4ff"

-- The three texts on the bar and the line under it, "" for one that's hidden.
local function Words()
    local out = {}
    for i, text in ipairs(P.texts) do out[i] = text:IsShown() and (H.Text(text) or "") or "" end
    out[4] = P.line:IsShown() and (H.Text(P.line) or "") or ""
    return out
end

-- The line under the bar as it should read; short: the short labels for a narrow bar.
local function Line(quests, rested, short)
    local parts = {}
    if quests then parts[#parts + 1] = (short and "Quests" or "Completed quests") .. ": |cffffa500" .. quests .. "|r" end
    if rested then parts[#parts + 1] = (short and "Rested" or "Rested experience") .. ": |cff5aa0ff" .. rested .. "|r" end
    return table.concat(parts, DOT)
end

-- The frame ---------------------------------------------------------------------------------------------------------------------

Fresh()
True(bar, "made at login")
Equal(ForeverEnhancedXPBarFrame, bar, "named ForeverEnhancedXPBarFrame")
Equal(S[bar].parent, UIParent, "under UIParent")
Equal(S[bar].strata, "MEDIUM", "in the MEDIUM strata")
Equal(S[bar].width .. "x" .. S[bar].height, "800x34", "sized when made: Large by default")
Equal(H.Last(bar, "SetClampedToScreen"), true, "kept on the screen")
Equal(tostring(S[bar].motion) .. " " .. tostring(S[bar].click), "true true", "the mouse shows the box and takes a right-click")
Equal(H.Last(bar, "SetPassThroughButtons") .. " " .. H.Last(bar, "SetPassThroughButtons", 4), "LeftButton Button5",
    "every other click goes through to the world")
Equal(bar:IsShown(), false, "hidden until placed on a first run")
H.Advance(3.9)
Equal(bar:IsShown(), false, "the first run waits 4 seconds")
H.Advance(.2)
True(bar:IsShown(), "then placed and shown")
for i = 1, bar:GetNumPoints() do
    local _, relative = bar:GetPoint(i)
    Equal(relative, UIParent, "anchored to UIParent only")
end

-- The parts ---------------------------------------------------------------------------------------------------------------------

Fresh("placed")
True(bar:IsShown(), "a saved spot: shown at once")
Equal(select(2, bar:GetPoint(1)) == UIParent and select(5, bar:GetPoint(1)), -300, "at its spot")
Waiting(1860)
True(P.graded, "the game can draw a gradient")
Equal(P.fill:IsShown(), false, "so the flat XP part is hidden")
local left, width, shown = Box(P.gradient)
Equal(left, 0, "XP from the start")
Equal(width, 506, "XP: 12,450 of 19,700 is 506 of 800 px")
True(shown, "and shown")
local grad = S[P.gradient].gradient
Equal(grad[1], "HORIZONTAL", "a gradient left to right")
Equal(Hex({ grad[2].r, grad[2].g, grad[2].b }) .. " " .. Hex({ grad[3].r, grad[3].g, grad[3].b }), "6a6af7 c56ef7",
    "blue-violet to violet")
Equal(S[P.gradient].texture, FLAT, "on the plain white texture")
left, width, shown = Box(P.quest)
Equal(left, 506, "finished quests straight after")
Equal(width, 75, "1,860 XP")
True(shown, "shown")
Equal(S[P.quest].texture, FLAT, "not striped by default: the plain white texture")
Equal(Ends(P.quest), AMBER, "in its own gradient, deep orange to warm gold")
Equal(S[P.quest].tint, nil, "not tinted over")
left, width, shown = Box(P.rested)
Equal(left, 581, "rested after the quest part")
Equal(width, 171, "4,200 XP")
True(shown, "shown")
Equal(Ends(P.rested), BLUE, "in its own gradient, deeper blue to sky blue")
local restedEnds = S[P.rested].gradient
Equal(restedEnds[2].a .. " " .. restedEnds[3].a, "1 1", "not see-through")
Equal(S[P.rested].texture, FLAT, "on the plain white texture")
Equal(tostring(P.shaded.quest) .. " " .. tostring(P.shaded.rested), "true true", "the game draws both")
-- Each flat colour (no gradient, and the line's) about halfway between its gradient's ends, so the two looks agree.
for _, part in ipairs({ "xp", "quest", "rested" }) do
    local flat, from, to = F.Theme.B[part], F.Theme.B[part .. "From"], F.Theme.B[part .. "To"]
    for i = 1, 3 do
        H.Near(flat[i] * 255, (from[i] + to[i]) / 2 * 255, 48, part .. ": its flat colour near the middle (" .. i .. ")")
    end
end
Equal(Hex(S[P.track].tint), "121017", "on a dark track")
True(S[P.gradient].sublevel < S[P.quest].sublevel and S[P.quest].sublevel < S[P.rested].sublevel, "drawn in that order")
Equal(S[P.fill].sublevel, S[P.gradient].sublevel, "the flat XP part in the same place")
for _, text in ipairs(P.texts) do Equal(S[text].layer, "OVERLAY", "the text over them") end
-- Each part as tall as the track and on its middle (nothing poking out above or below the rounded ends).
for name, part in pairs({ gradient = P.gradient, quest = P.quest, rested = P.rested }) do
    Equal(S[part].height, 34, name .. ": as tall as the track")
    local point, on, to, _, y = part:GetPoint(1)
    Equal(point .. " " .. to .. " " .. y, "LEFT LEFT 0", name .. ": on the track's middle")
    Equal(on, bar, name .. ": on the bar")
end
-- The gradient is never tinted over (a vertex colour would wipe it in the game), not even by a redraw.
F:Set("width", 900)
True(S[P.gradient].gradient ~= nil, "the gradient still there after a redraw")
F:Set("width", 800)
True(S[P.gradient].gradient ~= nil, "and after another")
-- The quest and rested gradients survive a redraw, and go on again at every draw, so a vertex colour (anything tinting
-- them) never leaves them flat.
Equal(Ends(P.quest) .. " | " .. Ends(P.rested), AMBER .. " | " .. BLUE, "the quest and rested gradients after a redraw")
for name, part in pairs({ quest = P.quest, rested = P.rested }) do
    part:SetVertexColor(1, 0, 0, 1)
    Equal(Ends(part), "none", name .. ": a vertex colour wipes its gradient (as in the game)")
end
F:Set("width", 900)
Equal(Ends(P.quest) .. " | " .. Ends(P.rested), AMBER .. " | " .. BLUE, "both put back by the next redraw")
True(S[P.quest].tint == nil and S[P.rested].tint == nil, "with no tint left over")
Waiting(0)
Equal(P.quest:IsShown(), false, "nothing waiting: the quest part hidden")
P.quest:SetVertexColor(1, 0, 0, 1)
Waiting(1860)
True(P.quest:IsShown(), "something waiting again: shown")
Equal(Ends(P.quest) .. " | " .. Ends(P.rested), AMBER .. " | " .. BLUE, "its gradient back as it shows again")
F:Set("width", 800)

-- The rounded ends: two end caps on every piece of the track (the game allows three masks a texture at most), one pair
-- each for the border's two rings.
local function Masks(texture)
    local list = S[texture].masks or {}
    return #list, list
end
for name, texture in pairs({ track = P.track, fill = P.fill, gradient = P.gradient, quest = P.quest, rested = P.rested }) do
    local count, list = Masks(texture)
    Equal(count, 2, name .. ": two end caps")
    for i = 1, 2 do Equal(list[i], P.masks.track[i], name .. ": the track's caps") end
    Equal(texture:GetNumMaskTextures(), 2, name .. ": as the game counts them")
end
for name, edge in pairs({ inner = P.edges[1], outer = P.edges[2] }) do
    local count, list = Masks(edge)
    Equal(count, 2, "the " .. name .. " ring: two end caps")
    True(list[1] == P.masks[name][1] and list[2] == P.masks[name][2], "the " .. name .. " ring rounded by its own")
end
-- A point as numbers: its name, what it's on, that one's point, x and y.
local function Point(region, i)
    return region:GetPoint(i or 1)
end
local cap = P.masks.track[1]
Equal(S[cap].texture, MEDIA .. "CapL_large.tga", "the left cap's art, drawn for a Large bar")
Equal(S[cap].wrap .. " " .. S[cap].wrapV, "CLAMPTOWHITE CLAMPTOWHITE", "white past its edge, so nothing else is cut")
local name, on, to, x, y0 = Point(cap)
Equal(name .. " " .. to, "TOPLEFT TOPLEFT", "from the track's top-left corner")
Equal(on, bar, "of the bar")
Equal(x, 0, "exactly (x)")
Equal(y0, 0, "(y)")
name, on, to, x, y0 = Point(cap, 2)
Equal(name .. " " .. to .. " " .. x .. " " .. y0, "BOTTOMLEFT BOTTOMLEFT 0 0", "to its bottom-left: the track's whole height")
Equal(on, bar, "of the bar too")
Equal(S[cap].width, 7, "the 7 px radius wide on a Large bar")
local far = P.masks.track[2]
Equal(S[far].texture, MEDIA .. "CapR_large.tga", "the right cap's art")
name, on, to, x, y0 = Point(far)
Equal(name .. " " .. to .. " " .. x .. " " .. y0, "TOPRIGHT TOPRIGHT 0 0", "from the track's top-right corner")
name, on, to, x, y0 = Point(far, 2)
Equal(name .. " " .. to .. " " .. x .. " " .. y0, "BOTTOMRIGHT BOTTOMRIGHT 0 0", "to its bottom-right")
Equal(S[far].width, 7, "the radius wide")
local outer = P.masks.outer[2]
name, on, to, x, y0 = Point(outer)
True(name == "TOPRIGHT" and x == 2 and y0 == 2, "the outer ring's right cap: two pixels out (top)")
name, on, to, x, y0 = Point(outer, 2)
True(name == "BOTTOMRIGHT" and x == 2 and y0 == -2, "(bottom)")
Equal(S[outer].width, 9, "and two pixels wider")
Equal(S[outer].texture, MEDIA .. "CapR_large.tga", "the same art")
local innerCap = P.masks.inner[1]
name, on, to, x, y0 = Point(innerCap)
True(name == "TOPLEFT" and x == -1 and y0 == 1, "the inner ring's left cap: one pixel out (top)")
name, on, to, x, y0 = Point(innerCap, 2)
True(name == "BOTTOMLEFT" and x == -1 and y0 == -1, "(bottom)")
Equal(S[innerCap].width, 8, "and one pixel wider")
-- The game's limit is real in the harness: a fourth mask on one texture is refused with the game's error.
local probe = bar:CreateTexture(nil, "ARTWORK")
for _ = 1, 3 do probe:AddMaskTexture(bar:CreateMaskTexture()) end
local added, refused = pcall(probe.AddMaskTexture, probe, bar:CreateMaskTexture())
Equal(added, false, "a fourth mask refused")
True(tostring(refused):find("Texture already has the maximum number of mask textures (3)", 1, true) ~= nil,
    "with the game's error")
probe:Hide()

-- The stripes, as a choice.
Equal(P.stripesOk, true, "the stripes loaded")
F:Set("questStripes", true)
Equal(S[P.quest].texture, MEDIA .. "Stripes.tga", "Stripes on finished-quest XP: the stripes texture")
Equal(S[P.quest].wrap .. " " .. S[P.quest].wrapV, "REPEAT REPEAT", "repeated")
Equal(Hex(S[P.quest].tint), "ffffff", "in its own colours")
Equal(Ends(P.quest), "none", "with no gradient over them")
True(P.quest:IsShown(), "the stripes shown")
Equal(Ends(P.rested), BLUE, "rested keeps its gradient")
local coords = S[P.quest].texCoord
Equal(coords[1] * 16, 506, "from the part's own pixels (left), so they stay still as it grows")
Equal(coords[2] * 16, 581, "(right)")
Equal(coords[3], 0, "(top)")
Equal(coords[4] * 16, 34, "(bottom: the bar's height)")
Waiting(3000)
coords = S[P.quest].texCoord
Equal(coords[1] * 16, 506, "the stripes start where they did")
Equal(S[P.quest].texture .. " " .. Hex(S[P.quest].tint) .. " " .. Ends(P.quest), MEDIA .. "Stripes.tga ffffff none",
    "still the stripes in their own colours after a redraw")
True(P.quest:IsShown(), "and still shown")
F:Set("questStripes", false)
Equal(S[P.quest].texture .. " " .. Ends(P.quest), FLAT .. " " .. AMBER, "unticked: the amber gradient again")
Equal(S[P.quest].tint, nil, "with no tint over it")
Equal(table.concat(S[P.quest].texCoord, ","), "0,1,0,1", "the whole texture")
Equal(#(S[P.quest].masks or {}), 2, "still rounded")

-- Clamped at the end.
Waiting(9000)
left, width = Box(P.quest)
Equal(left + width, 800, "more quest XP than the level: clamped at the bar's end")
Equal(P.rested:IsShown(), false, "and no room for rested")
F:Set("questSegment", false)
Equal(P.quest:IsShown(), false, "quest part off")
left, width, shown = Box(P.rested)
Equal(left, 506, "rested then starts straight after your XP")
Equal(width, 170, "the same XP (each edge rounded on its own)")
True(shown, "and shown")
F:Set("restedSegment", false)
Equal(P.rested:IsShown(), false, "rested part off: hidden, with room for it")
F:Set("restedSegment", true)
True(P.rested:IsShown(), "and back")
F:Set("questSegment", true)
H.p.rested = 30000
H.Fire("UPDATE_EXHAUSTION")
Waiting(0)
Equal(P.quest:IsShown(), false, "nothing waiting: no quest part")
left, width = Box(P.rested)
Equal(left + width, 800, "rested past the level: clamped at the end")
Waiting(5)
Equal(P.quest:IsShown(), false, "under half a pixel: hidden")

-- The pure sums, any width.
local spans = B.Spans({ xp = 100, max = 1000, rested = 50 }, 0, true, true)
Equal(spans.xp[2], 100, "XP")
Equal(spans.quest, nil, "nothing waiting: no quest part")
Equal(spans.rested[1] * 1000 + spans.rested[2], 100150, "rested from your XP")
spans = B.Spans({ xp = 1200, max = 1000, rested = 0 }, 10, true, true)
Equal(spans.xp[2], 1000, "XP over the max clamped")
Equal(spans.quest == nil and spans.rested == nil, true, "and no room for the rest")
Equal(next(B.Spans({ xp = 1, max = 0, rested = 0 }, 1, true, true)), nil, "no max: nothing")
local l, w = B.Pixels({ 0, 12450 }, 19700, 800, .5)
Equal(l, 0, "rounded to whole pixels of any size (left)")
Equal(w, 505.5, "(width)")
Equal(B.Pixels({ 0, 6 }, 19700, 800, 1), nil, "a quarter pixel: hidden")
Equal(B.Pixels({ 3, 7 }, 10000, 1000, 1), nil, "0.4 px across a pixel's edge: still hidden (it would round to 1 px)")
l, w = B.Pixels({ 3, 9 }, 10000, 1000, 1)
Equal(l .. " " .. w, "0 1", "0.6 px: shown, a whole pixel")

-- The plain amber gradient when the stripes won't load, whatever the tick says.
Fresh("placed", function() H.missingFiles[MEDIA .. "Stripes.tga"] = true end)
Equal(P.stripesOk, false, "the stripes didn't load")
F:Set("questStripes", true)
Waiting(1860)
Equal(S[P.quest].texture .. " " .. Ends(P.quest), FLAT .. " " .. AMBER, "the amber gradient instead")
True(P.quest:IsShown(), "and shown")

-- Each part is given its gradient as it's made, before anything is drawn on it.
Fresh("placed", function() H.p.rested = nil end)
True(not P.quest:IsShown() and not P.rested:IsShown(), "nothing waiting and no rested XP: neither part shown")
Equal(Ends(P.quest) .. " | " .. Ends(P.rested), AMBER .. " | " .. BLUE, "yet each has its gradient from the start")

-- Flat violet, amber and blue when the game can't draw a gradient.
-- The quest and rested parts flat in their colours (shown, no gradient), after a few redraws.
local function FlatParts(label)
    Waiting(1860)
    F:Set("width", 900)
    F:Set("width", 800)
    True(P.quest:IsShown() and P.rested:IsShown(), label .. ": the quest and rested parts shown")
    Equal(Ends(P.quest) .. " " .. Ends(P.rested), "none none", label .. ": with no gradient")
    Equal(Hex(S[P.quest].tint) .. " " .. Hex(S[P.rested].tint), "ffa500 5aa0ff", label .. ": flat amber and blue")
    Equal(S[P.quest].tint[4] .. " " .. S[P.rested].tint[4], "1 1", label .. ": not see-through")
    Equal(H.Problems(), "", label .. ": and nothing went wrong")
end
Fresh("placed", function() _G.CreateColor = nil end)
Equal(P.graded, false, "no CreateColor: no gradient")
Equal(tostring(P.shaded.quest) .. " " .. tostring(P.shaded.rested), "false false", "for any part")
Equal(P.gradient:IsShown(), false, "the gradient part hidden")
left, width, shown = Box(P.fill)
True(left == 0 and width == 506 and shown, "the flat XP part in its place")
Equal(Hex(S[P.fill].tint), "986cf7", "a flat violet, halfway between the gradient's ends")
Equal(H.Problems(), "", "and nothing went wrong")
FlatParts("no CreateColor")
Fresh("placed", function() _G.CreateColor = function() return nil end end)
Equal(P.graded, false, "SetGradient refusing the colours: no gradient")
True(P.fill:IsShown() and not P.gradient:IsShown(), "the flat violet instead")
Equal(H.Problems(), "", "and its error kept quiet")
FlatParts("SetGradient refusing")
-- The game drawing the gradients at first, then refusing them on a later redraw: flat from then on, quietly, even once
-- it would draw them again. The XP part's gradient, put on once, stays.
Fresh("placed")
Waiting(1860)
Equal(Ends(P.quest) .. " | " .. Ends(P.rested), AMBER .. " | " .. BLUE, "drawn at first")
local setGradient = H.Proto.SetGradient
H.Proto.SetGradient = function() error("SetGradient refused", 2) end
FlatParts("SetGradient refusing later")
Equal(tostring(P.shaded.quest) .. " " .. tostring(P.shaded.rested), "false false", "given up on for the session")
H.Proto.SetGradient = setGradient
FlatParts("SetGradient working again")
Equal(Ends(P.gradient), "HORIZONTAL 6a6af7 c56ef7", "the XP gradient untouched")
True(P.gradient:IsShown(), "and shown")

-- Square corners when the game can't make masks, or can't add them all: all or nothing, the whole bar square.
local function AllSquare(label)
    local pieces = { track = P.track, fill = P.fill, gradient = P.gradient, quest = P.quest, rested = P.rested,
        inner = P.edges[1], outer = P.edges[2] }
    for piece, texture in pairs(pieces) do Equal(#(S[texture].masks or {}), 0, label .. ": " .. piece .. " square") end
    local parts = B:Parts()
    Equal(next(parts.masks), nil, label .. ": no caps kept")
    Waiting(1860)
    True(P.gradient:IsShown() and P.quest:IsShown() and P.rested:IsShown(), label .. ": the bar still draws")
    Equal(H.Problems(), "", label .. ": and nothing went wrong")
end
Fresh("placed", function() H.noMasks = true end)
Equal(P.masks.track, nil, "no mask textures: no corners")
AllSquare("no mask textures")
Fresh("placed", function() H.maskCap = 1 end)
AllSquare("the second mask refused on the first piece")
Fresh("placed", function() H.maskCap, H.maskSilent = 1, true end)
AllSquare("the second mask dropped without an error (the count tells)")
Fresh("placed", function() H.maskBudget = 11 end)
AllSquare("the masks running out partway through the bar")
Fresh("placed", function() H.missingFiles[MEDIA .. "CapR_large.tga"] = true end)
AllSquare("the caps' art won't load")
-- Art for another size that won't load: square from then on, at every size.
Fresh("placed", function() H.missingFiles[MEDIA .. "CapL_thin.tga"] = true end)
Equal(#(S[P.track].masks or {}), 2, "Large's art loads: rounded")
F:Set("size", "thin")
AllSquare("Thin's art won't load")
F:Set("size", "large")
Equal(#(S[P.track].masks or {}), 0, "back to Large: still square")
Equal(H.Problems(), "", "and nothing went wrong")

-- The border, sizes and text -------------------------------------------------------------------------------------------------------

Fresh("placed")
local inner, outerRing = P.edges[1], P.edges[2]
name, on, to, x, y0 = Point(inner)
True(name == "TOPLEFT" and on == bar and x == -1 and y0 == 1, "the inner ring: one pixel out from the track")
name, on, to, x, y0 = Point(inner, 2)
True(name == "BOTTOMRIGHT" and x == 1 and y0 == -1, "all round")
name, on, to, x, y0 = Point(outerRing)
True(x == -2 and y0 == 2, "the outer ring two pixels out")
True(S[outerRing].sublevel < S[inner].sublevel and S[inner].sublevel < S[P.track].sublevel, "each behind the one inside it")
Equal(Hex(S[inner].tint) .. " " .. Hex(S[outerRing].tint), "000000 2e2a38", "a thin dark edge")
True(inner:IsShown() and outerRing:IsShown(), "shown by default")
F:Set("border", false)
Equal(inner:IsShown() or outerRing:IsShown(), false, "Border round the bar off: no ring")
F:Set("border", true)
H.pixelFactor = .5
F:Set("size", "thin")
Equal(select(4, inner:GetPoint(1)), -.5, "one physical pixel at any scale")
Equal(S[P.masks.inner[1]].width, 2.5, "its corners too")
H.pixelFactor = 1
Equal(S[bar].height, 10, "Thin: 10 px")
Equal(S[P.masks.track[1]].width, 2, "a 2 px radius")
Equal(S[P.masks.track[1]].texture .. " " .. S[P.masks.outer[2]].texture, MEDIA .. "CapL_thin.tga " .. MEDIA .. "CapR_thin.tga",
    "the caps drawn for Thin")
for _, piece in ipairs({ P.track, P.gradient, P.edges[1], P.edges[2] }) do
    Equal(#(S[piece].masks or {}), 2, "still two caps a piece after a size change")
end
Equal(S[P.texts[1]].fontSize .. " " .. S[P.texts[1]].fontFlags, "10 OUTLINE", "outlined text, 10 high")
Equal(S[P.texts[1]].fontFile, "font", "in the game's own font")
local p1 = { P.texts[1]:GetPoint(1) }
Equal(p1[1] .. " " .. p1[3] .. " " .. p1[4] .. " " .. p1[5], "BOTTOMLEFT TOPLEFT 2 4", "Thin: no room inside, so just above it")
Equal(select(3, P.texts[3]:GetPoint(1)) .. " " .. select(4, P.texts[3]:GetPoint(1)), "TOPRIGHT -2", "the % above its right end")
F:Set("size", "thick")
Equal(S[bar].height, 26, "Thick: 26 px")
Equal(S[P.texts[2]].fontSize .. " " .. S[P.line].fontSize, "12 11", "with 12 high text and an 11 high line")
F:Set("size", "normal")
Equal(S[bar].height, 18, "Normal: 18 px")
Equal(S[P.texts[2]].fontSize, 10, "with 10 high text")
F:Set("size", "large")
Equal(S[bar].height, 34, "Large: 34 px")
Equal(S[P.texts[2]].fontSize .. " " .. S[P.line].fontSize, "14 12", "with 14 high text and a 12 high line")
p1 = { P.texts[1]:GetPoint(1) }
Equal(p1[1] .. " " .. p1[3] .. " " .. p1[4] .. " " .. p1[5], "LEFT LEFT 10 0", "the level inside its left end")
Equal(select(1, P.texts[2]:GetPoint(1)) .. " " .. select(4, P.texts[2]:GetPoint(1)), "CENTER 0", "your XP in the middle")
Equal(select(1, P.texts[3]:GetPoint(1)) .. " " .. select(4, P.texts[3]:GetPoint(1)), "RIGHT -10", "your % inside its right end")
p1 = { P.line:GetPoint(1) }
Equal(p1[1] .. " " .. p1[3] .. " " .. p1[4] .. " " .. p1[5], "TOP BOTTOM 0 -4", "the line just under the border, centred")
Equal(Hex({ S[P.texts[1]].colour[1], S[P.texts[1]].colour[2], S[P.texts[1]].colour[3] }), "ffffff", "white text")
Equal(S[P.line].shadow, 1, "with a dark shadow")
for i, text in ipairs({ P.texts[1], P.texts[2], P.texts[3], P.line }) do
    local offset = S[text].shadowOffset or {}
    Equal(tostring(offset[1]) .. "," .. tostring(offset[2]), "1,-1", "text " .. i .. ": its shadow one pixel down and right")
end
F:Set("width", 1000)
Equal(S[bar].width, 1000, "the width")
Equal(select(4, bar:GetPoint(1)) * 1000 + select(5, bar:GetPoint(1)), -300, "the middle kept where it was")
F:Set("width", 4000)
Equal(S[bar].width, 1024, "never wider than the screen")
F:Set("width", 800)

-- The text, as in the mockup: level at the left, XP in the middle, % at the right (bracketed: once handed in).
local words = Words()
Equal(words[1] .. " | " .. words[2] .. " | " .. words[3], "Level 24 | 12,450 / 19,700 | 63.2%",
    "Both, nothing waiting: no bracketed %")
Equal(words[4], Line("0.0%", "21.3%"), "the line under: nothing in completed quests, rested in blue")
Waiting(1860)
words = Words()
Equal(words[3], "63.2% (72.6%)", "with finished quests: your % once they're handed in")
Equal(words[4], Line("9.4%", "21.3%"), "the line: completed quests in amber, rested in blue")
F:Set("questSegment", false)
words = Words()
Equal(words[3], "63.2%", "Show XP waiting in finished quests off: no bracketed %")
Equal(words[4], Line(nil, "21.3%"), "and no quest part in the line")
F:Set("restedSegment", false)
Equal(Words()[4], "", "both off: no line")
Equal(select(2, B:Room()), 2, "and no room kept for it")
F:Set("questSegment", true)
Equal(Words()[4], Line("9.4%"), "Show rested XP off: no rested in the line")
F:Set("restedSegment", true)
F:Set("textFormat", "numbers")
words = Words()
Equal(words[1] .. " | " .. words[2] .. " | " .. words[3], "Level 24 | 12,450 / 19,700 | ", "Numbers: the middle only")
F:Set("textFormat", "percent")
words = Words()
Equal(words[1] .. " | " .. words[2] .. " | " .. words[3], "Level 24 |  | 63.2% (72.6%)", "Percent: the right only")
Equal(words[4], Line("9.4%", "21.3%"), "the line either way")
Waiting(9000)
Equal(Words()[3], "63.2% (108.9%)", "finished quests that would level you up: past 100%")
Waiting(1860)
F:Set("textFormat", "both")
F:Set("lineUnder", false)
Equal(Words()[4], "", "Show quests and rested under the bar off: no line")
Equal(select(2, B:Room()), 2, "and no room kept for it")
F:Set("lineUnder", true)
local all = function() local t = Words() return t[1] .. t[2] .. t[3] .. t[4] end
True(P.texts[1]:IsShown() and P.line:IsShown(), "Always: shown")
F:Set("textShow", "hover")
Equal(all(), "", "On hover: all of it hidden, the line too")
H.Script(bar, "OnEnter")
True(P.texts[1]:IsShown() and P.texts[2]:IsShown() and P.texts[3]:IsShown() and P.line:IsShown(),
    "all shown while the mouse is on it")
H.Script(bar, "OnLeave")
Equal(all(), "", "and hidden again")
F:Set("textShow", "never")
H.Script(bar, "OnEnter")
Equal(all(), "", "Never: never")
H.Script(bar, "OnLeave")
F:Set("textShow", "always")

-- A narrow bar drops the level first, then your XP; the % stays. (The harness's letters are 6 px wide: "Level 24" 48,
-- "12,450 / 19,700" 90, "63.2% (72.6%)" 78.)
local function Three()
    local t = Words()
    return t[1] .. " | " .. t[2] .. " | " .. t[3]
end
F:Set("width", 300)
Equal(Three(), "Level 24 | 12,450 / 19,700 | 63.2% (72.6%)", "300 wide: all three fit")
F:Set("width", 250)
Equal(Three(), "Level 24 |  | 63.2% (72.6%)", "250: your XP would touch the %, so it goes; the level still fits")
F:Set("width", 200)
Equal(Three(), "Level 24 |  | 63.2% (72.6%)", "200 (the narrowest): your XP goes, the level still fits beside the %")
F:Set("textFormat", "numbers")
Equal(Three(), " | 12,450 / 19,700 | ", "Numbers at 200: the level goes, your XP stays")
F:Set("textFormat", "both")
-- The line under the bar (312 px whole, 186 px short) never hangs past the bar's ends.
Equal(Words()[4], Line("9.4%", "21.3%", true), "200: the whole line is wider than the bar, so the short labels")
F:Set("width", 300)
Equal(Words()[4], Line("9.4%", "21.3%", true), "300: still too narrow for it")
F:Set("width", 320)
Equal(Words()[4], Line("9.4%", "21.3%"), "320: the whole line fits")
F:Set("width", 200)
F:Set("restedSegment", false)
Equal(Words()[4], Line("9.4%"), "200 with one part: it fits whole")
F:Set("restedSegment", true)
local measure = H.Proto.GetStringWidth
H.Proto.GetStringWidth = function() return 0 end
F:Set("width", 210)
Equal(Three(), "Level 24 | 12,450 / 19,700 | 63.2% (72.6%)", "text the game hasn't measured is never dropped")
Equal(Words()[4], Line("9.4%", "21.3%"), "nor the line shortened")
H.Proto.GetStringWidth = measure
F:Set("width", 800)
Equal(Three(), "Level 24 | 12,450 / 19,700 | 63.2% (72.6%)", "wide again: all three back")
Equal(Words()[4], Line("9.4%", "21.3%"), "and the whole line")
Equal(B.Line({ max = 1000, rested = 100 }, 50, false, false, true, true, true), Line("5.0%", "10.0%", true),
    "B.Line: the short labels when asked")
local keepLeft, keepMiddle = B.Fit(800, 10, 48, 90, 78)
True(keepLeft and keepMiddle, "B.Fit: room for all")
keepLeft, keepMiddle = B.Fit(200, 10, 48, 90, 78)
True(keepLeft and not keepMiddle, "B.Fit at 200: your XP goes first, then the level fits beside the %")
keepLeft, keepMiddle = B.Fit(150, 10, 60, 90, 78)
True(not keepLeft and not keepMiddle, "a level wider than the room beside the %: neither")
keepLeft, keepMiddle = B.Fit(300, 10, 90, 90, 78)
True(not keepLeft and keepMiddle, "your XP fits beside the % but the level doesn't fit beside your XP: the level goes")
keepLeft, keepMiddle = B.Fit(220, 10, 48, 90, 0)
True(not keepLeft and keepMiddle, "no %: the level goes before your XP")
keepLeft, keepMiddle = B.Fit(200, 10, 48, 0, 78)
Equal(keepLeft, true, "no middle: the level and the % side by side")
keepLeft = B.Fit(150, 10, 48, 0, 78)
Equal(keepLeft, false, "until they'd touch")

-- The room it all takes: the mouse and the screen's edge count the line under it (and Thin's text above) as the bar's.
Equal(table.concat({ B:Room() }, " "), "2 18", "Large: the border above, the line below")
Equal(H.Last(bar, "SetHitRectInsets", 3) .. " " .. H.Last(bar, "SetHitRectInsets", 4), "-2 -18", "hovered over the line too")
Equal(H.Last(bar, "SetClampRectInsets", 3) .. " " .. H.Last(bar, "SetClampRectInsets", 4), "2 -18", "kept on the screen")
F:Set("size", "thin")
Equal(table.concat({ B:Room() }, " "), "16 16", "Thin: its text above as well")
F:Set("textShow", "never")
Equal(table.concat({ B:Room() }, " "), "2 2", "no text: just the border")
Equal(H.Last(bar, "SetHitRectInsets", 3) .. " " .. H.Last(bar, "SetHitRectInsets", 4), "-2 -2", "and the hover area follows")
F:Set("textShow", "always")
F:Set("size", "large")
-- The pure text, any numbers.
local a, b2, c = B.Texts({ level = 24, xp = 100, max = 1000 }, 50, "both", false, false, true)
Equal(a .. " | " .. b2 .. " | " .. c, "Level 24 | 100 / 1,000 | 10.0% (15.0%)", "B.Texts")
a, b2, c = B.Texts({ level = 24, xp = 100, max = 1000 }, 50, "both", false, false, false)
Equal(c, "10.0%", "no bracket without the quest part")
Equal(B.Line({ max = 1000, rested = 0 }, 0, false, false, false, false), nil, "B.Line: nothing ticked, no line")
Equal(B.Line({ max = 1000, rested = 0 }, 10, true, false, true, true), nil, "none at max level")
Equal(B.Line({ max = 1000, rested = 0 }, 10, false, true, true, true), nil, "none with XP gain off")

-- When it shows ---------------------------------------------------------------------------------------------------------------------

F:Set("showBar", false)
Equal(bar:IsShown(), false, "Show the XP bar off: hidden")
Equal(P.line:IsVisible(), false, "the line with it")
H.GainXP(100)
Equal(F:Char().session.xp, 100, "XP still counted while it's hidden")
F:Set("showBar", true)
True(bar:IsShown(), "back")

-- XP off.
H.p.rested = 4200
H.p.off = true
H.Fire("DISABLE_XP_GAIN")
Waiting(1860)
words = Words()
Equal(words[1] .. " | " .. words[2] .. " | " .. words[3] .. " | " .. words[4], "Level 24 | XP gain is turned off |  | ",
    "XP off: says so, no % and no line")
Equal(P.gradient:IsShown(), false, "no gradient")
True(P.fill:IsShown(), "a flat fill")
Equal(Hex(S[P.fill].tint), "5e5a68", "in grey")
Equal(Ends(P.fill), "none", "flat grey, no gradient")
Equal(P.quest:IsShown(), false, "no quest part")
Equal(P.rested:IsShown(), false, "and no rested part, though there's rested XP and room")
H.p.off = false
H.Fire("ENABLE_XP_GAIN")
H.Frame()
True(P.gradient:IsShown() and not P.fill:IsShown(), "XP back on: the gradient again")
True(P.quest:IsShown() and P.rested:IsShown(), "the quest and rested parts back")
Equal(Ends(P.quest) .. " | " .. Ends(P.rested), AMBER .. " | " .. BLUE, "in their gradients")

-- Max level.
Fresh("placed", function() H.p.level, H.p.xp, H.p.max = 30, 0, 22200 end)
Equal(bar:IsShown(), false, "at max level: hidden by default")
F:Set("showAtMax", true)
True(bar:IsShown(), "Show the bar at max level: shown")
local fl, fw = Box(P.fill)
Equal(fl, 0, "from the start")
Equal(fw, 800, "full")
Equal(Hex(S[P.fill].tint), "a8873e", "and gold")
Equal(Ends(P.fill), "none", "flat gold, no gradient")
Equal(P.gradient:IsShown(), false, "not the gradient")
words = Words()
Equal(words[1] .. " | " .. words[2] .. " | " .. words[3] .. " | " .. words[4], "Level 30 | Max level |  | ", "Level 30, max level")
Waiting(4000)
Equal(Words()[3], "4,000 XP in finished quests", "with the XP waiting at the right")
Equal(Words()[4], "", "no line: there's no level to share")
Equal(P.quest:IsShown() or P.rested:IsShown(), false, "no other parts")
F:Set("questSegment", false)
Equal(Words()[3], "", "Show XP waiting in finished quests off: not in the text")
F:Set("questSegment", true)
F:Set("textShow", "hover")
True(P.texts[1]:IsShown() and P.texts[2]:IsShown(), "its text shows even set to On hover")
F:Set("textShow", "never")
Equal(P.texts[1]:IsShown(), false, "but not set to Never")

-- First-run placing --------------------------------------------------------------------------------------------------------------------
-- The old sizes without the line first (their numbers are the first version's), then the line and Large.

-- Normal without the line (a fresh table each time: the addon keeps its settings in the one it's given).
local function Old() return { size = "normal", lineUnder = false } end

local function Placed(layout, settings, setup)
    Fresh(settings and { version = 1, settings = settings } or nil, function()
        H.BottomSetup(layout)
        if setup then setup() end
    end)
    H.Advance(4.1)
    local spot = F:Spot()
    return spot and spot.y, F:Get("width")
end

local y, wide = Placed({}, Old())
Equal(y .. " " .. wide, (150 + 9 - 384) .. " 800", "nothing to go by: 800 wide, 150 px up")
y, wide = Placed({ MainActionBar = { 312, 712, 50 }, MultiBarBottomLeft = { 312, 712, 92 }, PetActionBar = { 350, 600, 130 },
    MultiBarBottomRight = { 800, 1000, 290 }, StanceBar = { 100, 300, 140 } }, Old())
Equal(y, 130 + 6 + 9 - 384, "6 px above the highest bar crossing the middle (the pet bar)")
Equal(wide, 400, "as wide as the action bar")
True(F:Spot().x == 0, "in the middle")
y, wide = Placed({ EraUIClassicBar = { 212, 812, 70 }, MainActionBar = { 312, 712, 50 } }, Old())
Equal(y .. " " .. wide, (70 + 6 + 9 - 384) .. " 600", "above EraUI's band, as wide as it")
y, wide = Placed({ MainActionBar = { 312, 712, 50 }, MultiBarBottomLeft = { 312, 712, 200, hidden = true },
    PetActionBar = { 312, 712, 180, alpha = 0 }, MultiBarBottomRight = { 312, 712, 400 } }, Old())
Equal(y, 50 + 6 + 9 - 384, "hidden, faded and high frames left out")
y = Placed({ MainActionBar = { 312, 712, 50 }, StanceBar = { 312, 712, 120 } }, Old(),
    function() S[StanceBar].top = H.SecretNumber() end)
Equal(y, 50 + 6 + 9 - 384, "a secret position left out")
Equal(#H.violations, 0, "and never touched")
y, wide = Placed({ MainActionBar = { 390, 890, 62.5, scale = .8 } }, Old())
Equal(y .. " " .. wide, (50 + 6 + 9 - 384) .. " 400", "a scaled frame measured in the screen's units")
y, wide = Placed({ MainActionBar = { 362, 662, 50 } }, Old())
Equal(wide, 400, "never narrower than 400")
y, wide = Placed({ EraUIClassicBar = { 0, 1024, 70 } }, Old())
Equal(wide, 980, "never wider than the screen less a margin")
-- The track 6 px up puts a Normal bar's border top 26 px up, EraUI's cast-bar line. Thick (30 px with its border) can't
-- fit under it: it comes down until its border meets the bars, its top 4 px past the line.
y = Placed({ MainActionBar = { 312, 712, 50 } }, { size = "thick", lineUnder = false })
Equal(y, 50 + 2 + 13 - 384, "a Thick bar's track 2 px up: its border meets the bars below")
Equal(y + 384 + 13 + 2, 50 + 30, "and its border top 30 px up, 4 past the cast-bar line")
y = Placed({ MainActionBar = { 312, 712, 50 } }, { size = "thin", lineUnder = false, textShow = "never" })
Equal(y, 50 + 6 + 5 - 384, "a Thin bar with no text keeps the 6 px gap")
y = Placed({ MainActionBar = { 312, 712, 50 } }, { size = "thin", lineUnder = false })
Equal(y, 50 + 2 + 5 - 384, "a Thin bar's text above it (28 px in all): it comes down like a Thick one")
F:Set("size", "normal")
B:PutBack()
local normalY = F:Spot().y
Equal(normalY + 384 + 9 + 2, 50 + 26, "a Normal bar's border top on the cast-bar line")
F:Set("size", "thick")
Equal(F:Spot().y, normalY, "a size change keeps the middle")
B:PutBack()
Equal(F:Spot().y, normalY, "which is just where Put the bar back puts a Thick bar")
Equal(H.Problems(), "", "nothing went wrong placing")

-- The new default: Large with the line under it (2 + 34 + 18 = 54 px), far too tall for the 26 px under the cast bar.
y, wide = Placed({ MainActionBar = { 312, 712, 50 } })
Equal(y, 50 + 4 + 18 + 17 - 384, "no EraUI band: the line 4 px clear of the bars (no cast bar on that line)")
Equal(wide, 400, "as wide as the action bar")
y = Placed({ EraUIClassicBar = { 212, 812, 70 } })
Equal(y, 70 + 26 + 16 + 6 + 18 + 17 - 384, "with EraUI's band: above the cast bar's spot (16 px tall when it can't be read)")
y = Placed({ EraUIClassicBar = { 212, 812, 70 } }, nil, function()
    local cast = H.BlizzardFrame("Frame", "PlayerCastingBarFrame", UIParent)
    S[cast].height, S[cast].effScale = 10, 1.2
end)
Equal(y, 70 + 26 + 12 + 6 + 18 + 17 - 384, "the cast bar's own height when it can be read (scaled)")
Equal(#H.violations, 0, "the cast bar only read")
y = Placed({ EraUIClassicBar = { 212, 812, 70 } }, nil, function()
    local cast = H.BlizzardFrame("Frame", "PlayerCastingBarFrame", UIParent)
    S[cast].height = H.SecretNumber()
end)
Equal(y, 70 + 26 + 16 + 6 + 18 + 17 - 384, "a secret height: the usual 16")
Equal(#H.violations, 0, "and never touched")
y = Placed({ EraUIClassicBar = { 212, 812, 70 } }, { lineUnder = false })
Equal(y, 70 + 26 + 16 + 6 + 2 + 17 - 384, "Large without the line (38 px) is still too tall: above the cast bar")
y = Placed({ EraUIClassicBar = { 212, 812, 70 } }, { size = "normal" })
Equal(y, 70 + 26 + 16 + 6 + 16 + 9 - 384, "so is Normal with the line (36 px)")
y = Placed({}, nil)
Equal(y, 148 + 18 + 17 - 384, "nothing to go by: the line's bottom 148 px up, as a bare border's would be")
Equal(H.Problems(), "", "nothing went wrong placing")

-- Put the bar back, and a reset.
Fresh(nil, function() H.BottomSetup({ MainActionBar = { 312, 712, 50 } }) end)
H.Advance(4.1)
H.BottomSetup({ MainActionBar = { 312, 712, 80 } })
F:SetSpot(100, 100)
True(B:PutBack(), "Put the bar back")
Equal(F:Spot().x .. "," .. F:Spot().y, "0," .. (80 + 4 + 18 + 17 - 384), "measured again")
F:SetSpot(100, 100)
F:Set("width", 1200)
F:Set("size", "thin")
F:Reset()
Equal(F:Spot().y .. " " .. F:Get("width") .. " " .. F:Get("size"), (80 + 4 + 18 + 17 - 384) .. " 400 large",
    "a reset places it again (and back to Large)")
H.printed = {}

-- Moving it --------------------------------------------------------------------------------------------------------------------------

Fresh("placed")
F.ShowWindow()
True(B:StartMove(), "Move the bar")
local mover = B:Mover()
Equal(ForeverEnhancedXPBarMover, mover, "named ForeverEnhancedXPBarMover")
Equal(S[mover].strata, "DIALOG", "above the game")
True(mover:IsShown(), "the mover shows")
Equal(bar:IsShown(), false, "in place of the bar")
Equal(F.window:IsShown(), false, "the settings step aside")
Equal(S[mover].width .. "x" .. S[mover].height, "808x58", "the bar's size, the line under it too")
Equal(select(5, mover:GetPoint(1)), -308, "its middle 8 px under the track's (the line is below)")
Equal(select(5, mover.preview:GetPoint(1)), 8, "the track's preview where the track is")
Equal(S[mover.preview].width .. "x" .. S[mover.preview].height, "800x34", "the track's size")
F:Set("width", 600)
Equal(S[mover].width, 608, "and follows the width")
H.Script(mover, "OnDragStart")
True(S[mover].moving, "dragged")
S[mover].center = { 600, 300 }
H.Script(mover, "OnDragStop")
Equal(F:Spot().x .. "," .. F:Spot().y, "88,-76", "let go: the bar's new spot (the box's middle less the shift)")
Equal(S[mover].userPlaced, false, "kept out of the game's own layout")
Equal(select(5, mover:GetPoint(1)), -84, "the box stays where it was let go")
mover.done:Click()
Equal(mover:IsShown(), false, "Done")
True(bar:IsShown(), "the bar back")
Equal(select(4, bar:GetPoint(1)), 88, "at its new spot (x)")
Equal(select(5, bar:GetPoint(1)), -76, "(y)")
True(F.window:IsShown(), "and the settings back")
F.window:Hide()
F:Set("lineUnder", false)
B:StartMove()
Equal(S[mover].height, 42, "no line: the bar's own size")
Equal(select(5, mover:GetPoint(1)), -76, "on its middle")
Equal(F.window:IsShown(), false, "opened from /xpbar move: the settings stay shut")
H.Script(mover, "OnMouseUp", "RightButton")
Equal(mover:IsShown(), false, "a right-click finishes too")
Equal(F.window:IsShown(), false, "and doesn't open the settings")
F:Set("lineUnder", true)
-- The bar's right-click menu: unlock to move, the settings, put it back.
H.Script(bar, "OnMouseUp", "LeftButton")
Equal(B:Menu(), nil, "a left-click opens nothing")
H.Script(bar, "OnMouseUp", "RightButton")
local menu = B:Menu()
True(menu and menu:IsShown(), "a right-click opens the menu")
Equal(S[menu].strata .. " " .. #menu.buttons, "DIALOG 3", "above the game, three buttons")
Equal(select(5, menu:GetPoint(1)), 8, "just over the bar")
Equal(menu.buttons[1].label:GetText() .. " / " .. menu.buttons[2].label:GetText() .. " / " .. menu.buttons[3].label:GetText(),
    "Unlock to move / Settings / Put the bar back", "its buttons")
menu.buttons[1]:Click()
Equal(tostring(menu:IsShown()) .. " " .. tostring(B:Moving()) .. " " .. tostring(B:Mover():IsShown()), "false true true",
    "Unlock to move: the menu shuts and the mover shows")
H.Script(bar, "OnMouseUp", "RightButton")
Equal(menu:IsShown(), false, "no menu while moving")
B:StopMove()
H.Script(bar, "OnMouseUp", "RightButton")
menu.buttons[2]:Click()
Equal(tostring(menu:IsShown()) .. " " .. tostring(F.window:IsShown()), "false true", "Settings opens the settings")
F.window:Hide()
H.Script(bar, "OnMouseUp", "RightButton")
H.Script(menu, "OnUpdate", .4)
Equal(menu:IsShown(), true, "a moment off the menu keeps it")
H.Script(menu, "OnUpdate", .4)
Equal(menu:IsShown(), false, "then it closes")
S[bar].mouseOver = true
H.Script(bar, "OnMouseUp", "RightButton")
H.Script(menu, "OnUpdate", 1)
Equal(menu:IsShown(), true, "the mouse on the bar keeps it")
S[bar].mouseOver = false
menu:Hide()
F:Set("size", "thin")
H.Script(bar, "OnMouseUp", "RightButton")
Equal(select(5, menu:GetPoint(1)), 22, "over Thin's text")
menu:Hide()
-- Moving at max level.
Fresh("placed", function() H.p.level, H.p.xp = 30, 0 end)
Equal(bar:IsShown(), false, "hidden at max level")
B:StartMove()
True(B:Mover():IsShown(), "the mover still shows")
B:StopMove()
Equal(bar:IsShown(), false, "and the bar stays hidden")

-- The hover box ----------------------------------------------------------------------------------------------------------------------

Fresh("placed")
H.Script(bar, "OnEnter")
local box = F.Tip:Box()
True(box and box:IsShown(), "hovering shows the box")
Equal(H.Text(box.title), "Level 24 to 25", "titled")
local rows = 0
for _, label in ipairs(box.labels) do if label:IsShown() then rows = rows + 1 end end
Equal(rows, 10, "every detail")
local seconds = H.Text(box.values[5])
H.Advance(61)
True(H.Text(box.values[5]) ~= seconds, "the times tick on while it's up")
H.Script(bar, "OnLeave")
Equal(box:IsShown(), false, "gone on leave")
local tickers = 0
-- (The hover box ticks every second; GameBar's short watch after a loading screen ticks every 0.05 s on its own.)
for _, timer in ipairs(H.timers) do if timer.every == 1 and not timer.cancelled then tickers = tickers + 1 end end
Equal(tickers, 0, "and its ticker stopped")
H.Script(bar, "OnEnter")
F:Set("showBar", false)
Equal(box:IsShown(), false, "the bar hidden under the mouse: the box goes too")

H.printed = {}
Equal(#H.violations, 0, "Blizzard's frames only read")
Equal(H.Problems(), "", "nothing went wrong")
io.stdout:write("TestBar: " .. H.checks .. " checks passed\n")
