# Forever Enhanced XP Bar: notes

Squirt's addon for World of Warcraft: Forever (Interface 16001). An XP bar with the XP waiting in finished quests and the
rested XP on it, and a hover box with XP this level, rested, quests waiting and done, time on this level, this session,
XP per hour, next level in, kills to level and quests to level.
The approved build plan is `C:\AddonDev\_Toolchain\gamedata\forever-xpbar\PLAN.md` (research in `apis.md` and
`overlap.md` beside it). The first approved look was the mockup `xp-bar-canvas/project/Main.dc.html` (its numbers are
examples); the bar itself now follows the user's own mockup of 2026-10-14 (see "The mockup look" below). The hover box
and the settings window keep the first look.

## File map (TOC order; the harness loads the same list and TestRules checks they match)

| File | What it does |
|---|---|
| `Core.lua` | Namespace `F`, the settings rows (pages, sections; the window and the defaults are built from them; button rows are actions, not settings), saved variables and their clean-up, `F:Char()` (per character, keyed by GUID, pruned after 180 days unseen), the bar's spot, Get/Set/Listen/Notify, Print/Say/Guard (every C_Timer callback goes through `F:Guard`), `Number`/`Text`/`Bool`/`IsSecret`, `Commas`/`Percent`/`Duration`/`Eta`, one event hub (`F:On`, each handler under pcall), `/xpbar` and `/fexb`, the AddOns settings entry, dev log. |
| `Theme.lua` | The family window look (`T.C`), the bar's palette (`T.B`, the user's mockup) and the hover box's (`T.TIP`); ticks (with a blocked state), choices, the flat slider, buttons, scroll, credit. |
| `Track.lua` | Reading XP, rested, level, cap, XP off; gains from UnitXP differences; the session; time on this level; XP per hour; next level in; askPlayed. |
| `Quests.lua` | XP waiting in finished quests (one scan a frame), hand-ins counted, the average and quests to level. |
| `Kills.lua` | Kill lines read with patterns built from the game's own strings; the last 20 kills' base XP; kills to level with both rested sums (`KL.MODEL`). |
| `Tip.lua` | The addon's own hover box (never GameTooltip) and the bar's ten details. |
| `Bar.lua` | The bar: its parts (gradient XP, gradient or striped amber, gradient blue), rounded corners (masks), the border, four sizes, the text on it and the line under it, the room they take (`B:Room`), hover, the right-click menu; first-run placing; Put the bar back; the mover. |
| `GameBar.lua` | Hiding the game's own XP bar: SetAlpha and post-hooks only, put back exactly, steps aside for EraUI's classic band. |
| `Window.lua` | `/xpbar`: pages from Core's rows, footer help, credit, blocked rows, the action buttons, Reset all settings (asks first). |
| `MinimapButton.lua` | The minimap button (left-click settings, right-click shows or hides the bar, drag round the edge). |

Media: `Icon.tga` (AddOns list), `Logo.tga` (window header), `MinimapIcon.tga`, `Stripes.tga` (16 x 16 stripes in
#ffa500 and #cc8400, tiled), `CapL_<size>.tga` and `CapR_<size>.tga` (32 x 128 end-cap masks, a pair for each of thin,
normal, thick and large), `Heart.tga` (credit). All drawn by `Tools/GenerateArt.mjs`, with `Tools/CurseForgeAvatar.png`
(400 x 400). Re-running it leaves the logo, icons, stripes and heart byte for byte the same. TestRules checks nothing
else is in Media.

## Tests

- `node Tools/RunTests.mjs` runs every `Tools/Test*.lua` in fengari (a pass is the last line "TestX: N checks passed";
  a failure can still exit 0), then `TestLuaLimits.mjs` and `TestRules.mjs`.
- Parser: `node C:\AddonDev\_Toolchain\lua-check\check.js *.lua Tools\*.lua`.
- `Tools/Harness.lua` seals the game's frames: only reads, HookScript, cosmetic text setters, SetAlpha on the pieces
  GameBar may fade, and hooksecurefunc on a container's UpdateDividers. Secrets keep their type, and asking
  `issecretvalue` about nil is a violation. Like the game, a texture takes at most three masks (a fourth raises the
  game's error), and a vertex colour and a gradient overwrite each other. GetStringWidth leaves colour codes out.

## Rules kept

- The game's frames are touched only in `GameBar.lua`: read, SetAlpha on the two XP bars (and the frame art and dividers
  of the container holding XP, only if showing), HookScript OnShow/OnHide on the XP bars, hooksecurefunc on each
  container's UpdateDividers. State in weak tables. Never Hide/SetPoint/SetParent/SetScale, never the containers' alpha,
  never the reputation or vehicle bars, never the mouse.
- With EraUI's classic band active (or predicted from its settings for the first 3.5 s after entering the world) the
  game's bar is left alone and the tick is greyed with the reason. If the band arrives later, the XP bars' alpha is put
  back and the art is left to EraUI.
- Our frames hang from UIParent and anchor to it (the minimap button to the minimap). The bar takes no clicks.
- The minimap gets one `HookScript("OnSizeChanged")`, as the family's buttons do. The settings window joins
  `UISpecialFrames` (Escape).
- `RequestTimePlayed` only behind the askPlayed tick (off by default), at a login, while the level timer isn't exact.
  `CHAT_MSG_SYSTEM` is never listened to (secret in fights). `CHAT_MSG_COMBAT_XP_GAIN` is checked with issecretvalue.
- Lua 5.1 limits checked by `Tools/TestLuaLimits.mjs`.

## Decisions taken while building (beyond the plan)

- A container "holds XP" while its XP bar is shown (`bar:IsShown()`), not by `shownBarIndex`: the game sets
  `shownBarIndex` only after the bar's OnShow has run, so the hook would read the old value.
- Kill patterns: a later `%s` (the bonus, the rest state) never takes a comma or bracket, and every group or raid
  variant is tried before the plain ones. Without that, a tired kill with a group bonus read as a rested kill (found by
  the tests).
- First-run placing puts the track's bottom (not the border's) 6 px above the highest bottom bar, so a Normal bar's
  border ends 26 px up, exactly where EraUI's band puts the player's cast bar. Thick (30 px with its border) can't fit
  under that line: Put the bar back at Thick brings the track down to 2 px, so its border meets the bars below and its
  top passes the line by 4 px (the least it can). Thin keeps the 6 px gap. (Since the mockup look this counts the whole
  bar, line and Thin's text included; see below.)
- A size change keeps the bar's middle (as the width does). A review suggested keeping its bottom edge instead; that
  would put a Thick bar's top 8 px past EraUI's cast-bar line instead of 4, and with the middle kept, Normal to Thick
  lands exactly where Put the bar back puts a Thick bar.
- A level-up read in halves waits for the other half, in either order: the new level with the old numbers (the old
  max, XP not lower), or the new level's numbers (a new max) with the old level. The wait ends after 5 s (a look is
  scheduled then): the numbers are taken as they are, the difference at the same level, else nothing. Every level-up
  also re-reads after 1 s. Dev mode logs each half ("half" in `levelups`), which settles the game's order.
- A handed-in quest is left out of the XP waiting for 2 s, should the log still list it after its XP has come (it
  would count twice).
- Dev records are dropped when dev mode is turned off, and at load unless it's on.
- Gains within 5 s share one rate entry, so an hour is at most 720 entries without dropping XP.
- A login also takes a new snapshot, so XP gained while the addon wasn't watching is never this session's.
- "In N quests" counts only finished quests that give XP.
- The rested factor is the game's own when it says more than 1 (up to 10), else 2.
- The two text rows are labelled "When it shows" and "What it shows" under the heading "Text on the bar".
- The hover box's footer says "/xpbar opens the settings" when the minimap button is hidden.
- The hide tick is also greyed (with a reason) if the game's XP bar can't be found.

## The mockup look (2026-10-14)

The user drew the bar they want: tall, a dark rounded track with a thin dark edge, XP in a #6a6af7 to #c56ef7 gradient,
then solid #ffa500 for finished quests and solid #5aa0ff for rested; white outlined text "Level 57" left, "204931 /
311490" middle, "65.8% (70.6%)" right; and under the bar "Completed Quests: 4.8% - Rested Experience: 6.4%" with the two
numbers in amber and blue. What was built, and the choices made:

- Sizes 10, 18, 26 and a new **Large 34**, the default. Text 10/10/12/14 high (line 10/10/11/12), outlined with a shadow,
  in the game's own font file (so every language's letters are there). Text inset 2/5/7/10 from the ends.
- **Thin** has no room inside: its three texts sit just above it (2 px over the border). They still follow When it shows,
  and the hover box and the right-click menu move up to clear them.
- **Thousands separators kept** ("204,931 / 311,490"); the mockup has none, but they're easier to read.
- The bracketed % is (XP + finished quests) / level and isn't capped: past 100% means handing in levels you up. Left out
  when nothing is waiting or Show XP waiting in finished quests is off.
- Numbers shows the middle, Percent the right (with its bracket), Both both; the level shows with either.
- **The line under the bar** has its own tick ("Show quests and rested under the bar", on; the suggested "Show finished
  quests and rested under the bar" is too long for the window's tick column). Its words are British and close to the
  user's: "Completed quests: 4.8%  ·  Rested experience: 6.4%". It also follows When it shows (the bar's text is all of
  it), each half goes with its part's tick, it reads 0.0% rather than vanishing when nothing is waiting (so it doesn't
  jump), and it's hidden at max level and with XP gain off (no level to share). It's a child of the bar: hidden with it,
  hovered and right-clicked as the bar (hit rect insets), kept on the screen (clamp insets) and inside the mover's box.
  It's measured: wider than the bar (about 320 px whole at 12 high; the width goes down to 200) it switches to short
  labels, "Quests: 4.8%  ·  Rested: 6.4%" (about 185 px), so it never hangs past the bar's ends, where it would be
  outside the hover area and the screen clamp. A line the game reports 0 wide keeps its whole words.
- `B:Room()` (how far the bar reaches past its track: 2 px of border, Thin's text above, the line below) comes from the
  settings alone, not from what shows this moment, so the hover area and the bar's place hold still.
- **Rounded corners** (radius 2/4/5/7): **two end-cap masks per texture**, never more. The game allows at most three
  masks on a texture (a Blizzard UI developer's word, quoted on WoWInterface; a fourth raises "Texture already has the
  maximum number of mask textures (3)"), so the first build's four corner masks would have left every bottom-right
  corner square, and the parts unmasked, with no error shown (a review caught it; the harness now has the cap). Each
  cap is anchored to a piece's top and bottom corners at one end (so it's the piece's height) and is the radius wide;
  its art (`CapL_<size>` / `CapR_<size>`, 32 x 128) is white except outside a quarter circle at the top and at the
  bottom of its outer end, the arcs drawn for that size's radius and height so they come out round. `CLAMPTOWHITE`, so
  past the cap nothing is cut (its inner side is white anyway). The track and every part share one pair; the border is
  two plates behind the track (one and two pixels bigger), each rounded by its own pair, one and two pixels out and
  wider. The rings' caps use the track's art over a slightly taller piece, so their arcs are a fraction of a pixel
  oval: not visible. Every coloured piece is the plain white texture with a vertex colour (masks and SetGradient need
  a texture).
- **All or nothing**: after adding, every texture's `GetNumMaskTextures()` must say 2. If the game can't make a mask,
  refuses or drops one (even partway through), or a size's art won't load (`SetTexture` false, on any later size
  change too), every mask added is taken off again (`RemoveMaskTexture`) and the whole bar is square for the session;
  nothing else changes. `AddMaskTexture`, `RemoveMaskTexture`, `GetNumMaskTextures` and `GetMaskTexture` are all in
  the forever branch's `SimpleTextureAPIDocumentation`. Needs an in-game look.
- **Gradient**: `SetGradient("HORIZONTAL", CreateColor(...), CreateColor(...))` (the forever branch of the UI source:
  orientation, minColor, maxColor as ColorMixin) on its own texture across the XP part. The flat fill is used for the
  gold max-level bar, the grey XP-off bar, and a flat violet (#986cf7, halfway) if CreateColor or SetGradient is missing
  or errors.
- **Quest and rested gradients too** (2026-10-15, the user asked for the amber and blue to fade like the XP): quest
  #f0821e (deeper orange) to #ffbe3c (warm gold), rested #3a7ff0 (deeper blue) to #80c4ff (sky blue), left to right,
  not see-through. The mockup's #ffa500 and #5aa0ff (about the middle of each) stay as the flat fallback and the line's
  colours. Same guarded SetGradient as the XP part, but put on again every time the part is drawn, since a vertex colour
  wipes a gradient (the stripes' white tint does, going back to solid does). Given at build, so each has it before it's
  first drawn. If the game refuses one (at build or on a later draw) that part goes flat in its colour for the session,
  quietly.
- Quest part not striped by default; **stripes kept as a choice** ("Stripes on finished-quest XP", off), in their own
  two ambers with no gradient over them (a gradient tints the texture, and could only darken the stripes); unticked, the
  gradient comes back. Outer border ring darker (#2e2a38) for the mockup's "thin dark edge".
- **A narrow bar** keeps the texts 8 px apart at least: the % always stays; your XP goes if it would touch the %; then
  the level goes if it would touch whichever is still beside it (your XP, or the % once your XP has gone). So at the
  narrowest (200) "Level 24" still shows beside "63.2% (72.6%)". (The first build checked the level first and dropped
  both at 200 to 270 px, though the level fitted beside the %; a review caught it.) With Numbers (no %) the level goes
  before your XP. A text the game reports 0 wide (not measured) is never dropped.
- **Placing** now counts the whole bar (border, Thin's text, the line). One that fits under EraUI's cast-bar line (within
  4 px, as Thick did) sits as before. One taller (Large with the line is 54 px; even Normal with the line is 36) goes
  above the cast bar's spot when EraUI's band is measured (26 px line + the cast bar's own height, read only, else 16 +
  6 px), and 4 px clear of the bars without the band (Blizzard's own cast bar isn't on that line). Nothing to go by: the
  bar's lowest edge 148 px up (where a bare border's was).
- A bar placed before this change keeps its saved middle, so at Large with the line its bottom can sit on the action
  bars: Put the bar back (right-click the bar) places it again.

## Probes still open (see apis.md section 11)

P1 caps and rest states, P2 which container holds XP, P3 the game's hover text over the faded slot, P5 delivery quests
and IsComplete, P6 the rested sum per kill (sets `KL.MODEL`) and event order, P8 session clock, P9 frame art alpha, P10
the experience preset.
