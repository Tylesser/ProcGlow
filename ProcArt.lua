local addonName, ns = ...

-- Proc glow, part 2: art beside your character while an ability procs (the user's ask, 2026-11-19: "like in retail
-- for Blade of Justice there are 2 swords"), on top of the glowing buttons.
--
-- Forever facts (forever branch of Gethe/wow-ui-source): Blizzard_FrameXML/SpellActivationOverlay.lua is there and
-- shows art on SPELL_ACTIVATION_OVERLAY_SHOW (spellID, overlayFileDataID, locationType, scale, r, g, b), but
-- Forever's spell data sends that for next to nothing: the side art never shows, while the buttons still light on
-- SPELL_ACTIVATION_OVERLAY_GLOW_SHOW (spellID). So Codex draws its own: for every proc that is lit (Codex's own list,
-- and every spell the game lights with the glow event), Codex's own piece for it, else the spell's icon on Codex's
-- ProcSide arc, else the arc alone, in the glow colour. (The game's own art files were a look of their own until
-- 2026-11-23; the user had that option removed.) Placement and animation follow the game's frame: a 204.8 square box at
-- the screen centre, sides 0.8 x 128x256 against its left and right edge (the right one mirrored), the top one over it,
-- a 0.2 s fade in, a 1.08 pulse every 0.5 s and a 0.1 s fade out. Several procs share the places by count
-- (A.Show): one = both sides, two = left and right, three = + top, four = + bottom (side art turned a quarter);
-- or all on one side (A.Side: left, right, top or bottom).
-- Whatever the game's own frame shows (SPELL_ACTIVATION_OVERLAY_SHOW) is left to it.
-- The "spell's icon" look (also what Codex art falls back to): the arc, with the proc's own icon three
-- times along it on each side (big in the middle, two smaller up and down the curve, soft round edges from the
-- ProcIconMask mask; the right side mirrored), so the art says which ability lit. Plain textures on a frame of
-- ours on UIParent: nothing secure, works in combat.

local unpack = unpack or table.unpack
local Q = ns.qol
local P = Q.procglow
local A = {}
P.art = A

A.KEY, A.LOOK_KEY, A.SIZE_KEY, A.ALPHA_KEY = "procArt", "procArtLook", "procArtSize", "procArtAlpha"
A.SIDE_KEY = "procArtSide" -- both sides, or only the left / right / top / bottom one (a player's wish, 2026-11-23)
A.SIDE_EACH_KEY, A.SIDE_FOR_KEY = "procArtSideEach", "procArtSideFor" -- a side per ability (the same player, 2026-11-23)
A.LOOK_EACH_KEY, A.LOOK_FOR_KEY = "procArtLookEach", "procArtLookFor" -- an art per ability (the user, 2026-11-23)
A.COLOR_KEY, A.CUSTOM_KEY = "procArtColor", "procArtCustom" -- the tint of styles, arc and icon looks (2026-11-23)
local BRAND = ns.PROC_BRAND or "Codex" -- (the standalone: "Proc Glow")
local MEDIA = ns.PROC_MEDIA or ("Interface\\AddOns\\" .. addonName .. "\\Modules\\QoL\\Media\\")
A.ARC = MEDIA .. "ProcSide"
A.ICON_MASK = MEDIA .. "ProcIconMask"
A.LONG, A.SHORT = 256 * 0.8, 128 * 0.8
-- the icon look: { y, size, alpha } in the 128x256 side file, each just inside the arc (the circle round (230, 128)
-- with radius 190 that ProcSide.tga draws)
A.SPOTS = { { 128, 64, 1 }, { 52, 38, 0.7 }, { 204, 38, 0.7 } }
A.MAX = 4 -- procs shown at once (2026-11-22, the user's request: one proc on both sides; two = left and right; three
-- = left, right, top; four = left, right, top, bottom; more wait their turn: the first four lit show)
A.ROTATE = 2 -- (the old one-at-a-time rotation, 2026-11-20; kept for A.Rotate, no longer used by A.Update)

-- Clearcasting looks different per class.
A.CLEARCASTING = { MAGE = "arcane_missiles", DRUID = "omen" }

-- Styles (2026-11-23, the user's "generate more arts and let the user select between those arts"): one piece for any
-- proc, white, tinted in the glow colour (branding/source/proc-art-styles.py writes Media/ProcArt/style_<key>.tga).
-- { key, name, sample colour (the gallery's, while each proc keeps its own colour) }. The second eight (the user's
-- "more related to the game", the same day): weapons, claws and the schools of magic.
A.STYLES = { { "flames", "Flames", { 1, 0.45, 0.12 } }, { "runes", "Runes", { 0.45, 0.7, 1 } },
  { "feathers", "Feathers", { 1, 0.85, 0.45 } }, { "moons", "Crescent moons", { 0.7, 0.75, 1 } },
  { "lightning", "Lightning", { 0.3, 0.75, 1 } }, { "vines", "Vines", { 0.35, 0.85, 0.35 } },
  { "crystals", "Crystal shards", { 0.75, 0.45, 1 } }, { "stars", "Stars", { 0.85, 0.85, 1 } },
  { "swords", "Swords", { 1, 0.4, 0.2 } }, { "daggers", "Daggers", { 0.95, 0.9, 0.4 } },
  { "arrows", "Arrows", { 0.55, 0.85, 0.35 } }, { "claws", "Claw marks", { 0.95, 0.25, 0.2 } },
  { "skulls", "Skulls", { 0.6, 0.3, 0.95 } }, { "snowflakes", "Snowflakes", { 0.5, 0.8, 1 } },
  { "light", "Rays of light", { 1, 0.85, 0.35 } }, { "sigils", "Arcane sigils", { 0.8, 0.45, 1 } } }
A.styleKeys = {}
for _, style in ipairs(A.STYLES) do
  A.styleKeys["style:" .. style[1]] = style
end
A.LOOKS = { { "codex", (ns.PROC_ART_NAME or "Codex art") }, { "icon", "The spell's icon" },
  { "arc", "A plain arc" }, { title = "Styles" } }
for _, style in ipairs(A.STYLES) do
  A.LOOKS[#A.LOOKS + 1] = { "style:" .. style[1], style[2] }
end

-- Codex art (the default look since 2026-11-20, the user's request): an original piece per proc Codex knows, the
-- arc in the proc's colours with its emblem (branding/source/proc-codex-art.py writes Media/ProcArt/<key>.tga, the
-- left side; the right one is the same file mirrored). Procs without a piece (what the game lights itself) get the
-- spell's icon on the arc. In gallery order: { key, proc name, class }.
A.CODEX_DIR = MEDIA .. "ProcArt\\"
A.CODEX = {
  { "overpower", "Overpower", "Warrior" }, { "revenge", "Revenge", "Warrior" }, { "execute", "Execute", "Warrior" },
  { "victory_rush", "Victory Rush", "Warrior" }, { "riposte", "Riposte", "Rogue" },
  { "counterattack", "Counterattack", "Hunter" }, { "mongoose_bite", "Mongoose Bite", "Hunter" },
  { "hammer_of_wrath", "Hammer of Wrath", "Paladin" },
  { "echo_of_command", "Echo of Command", "Paladin" }, { "echo_of_righteousness", "Echo of Righteousness", "Paladin" },
  { "echo_of_justice", "Echo of Justice", "Paladin" }, { "echo_of_fury", "Echo of Fury", "Paladin" },
  { "echo_of_light", "Echo of Light", "Paladin" }, { "echo_of_wisdom", "Echo of Wisdom", "Paladin" },
  { "shadow_trance", "Shadow Trance", "Warlock" }, { "clearcasting_mage", "Clearcasting", "Mage" },
  { "clearcasting_druid", "Clearcasting", "Druid" }, { "clearcasting_shaman", "Clearcasting", "Shaman" },
  { "missile_barrage", "Missile Barrage", "Mage" }, { "heating_up", "Heating Up", "Mage" },
}
A.codexKeys = {}
for _, entry in ipairs(A.CODEX) do
  A.codexKeys[entry[1]] = entry
end

A.SIZES = { { 0.8, "Small" }, { 1, "Normal" }, { 1.25, "Large" } }
A.ALPHAS = { { 0.4, "40 %" }, { 0.6, "60 %" }, { 0.8, "80 %" }, { 1, "100 %" } }
A.SIDES = { { "both", "Both sides" }, { "left", "Left side only" }, { "right", "Right side only" },
  { "top", "Top only" }, { "bottom", "Bottom only" } }
A.COLOR_CHOICES = { { "proc", "Each proc's own colour" }, { "glow", "The glow colour" }, { "custom", "Your colour" } }
-- the option lists in ProcGlow.lua were made before this file ran: fill them in place
for name, list in pairs(P.artLists or {}) do
  for index, entry in ipairs(A[name] or {}) do
    list[index] = entry
  end
end

local function Readable(value)
  if issecretvalue and issecretvalue(value) then
    return false
  end
  return true
end

local function Num(value)
  return Readable(value) and type(value) == "number" and value or nil
end

local function Lower(text)
  return Readable(text) and type(text) == "string" and text:lower() or nil
end

local function SpellName(id)
  local name
  if C_Spell and C_Spell.GetSpellName then
    local ok, value = pcall(C_Spell.GetSpellName, id)
    name = ok and value or nil
  elseif GetSpellInfo then
    local ok, value = pcall(GetSpellInfo, id)
    name = ok and value or nil
  end
  return Readable(name) and type(name) == "string" and name or nil
end

local function Class()
  if type(UnitClass) ~= "function" then
    return nil
  end
  local ok, _, class = pcall(UnitClass, "player")
  return ok and Readable(class) and class or nil
end

-- The Codex art key for a proc name ("Clearcasting" is per class), or nil.
function A.CodexKey(name)
  local key = Lower(name)
  if not key then
    return nil
  end
  key = key:gsub("[^%w]+", "_")
  if key == "clearcasting" then
    key = "clearcasting_" .. (Class() or ""):lower()
  end
  return A.codexKeys[key] and key or nil
end

function A.On()
  return Q.DB()[A.KEY] ~= false
end

function A.Size()
  local value = Num(Q.DB()[A.SIZE_KEY])
  return value and math.max(0.5, math.min(2, value)) or 1
end

function A.Alpha()
  local value = Num(Q.DB()[A.ALPHA_KEY])
  return value and math.max(0.1, math.min(1, value)) or 0.8
end

-- "both", "left", "right", "top" or "bottom".
function A.Side()
  local value = Q.DB()[A.SIDE_KEY]
  return A.ONE_SIDE[value] and value or "both"
end

-- The colours: tinted looks (styles, the arc, the icon's arc) take each proc's own colour by default (2026-11-23, the
-- user's "make them with their colours to give them a meaning"): the glow colour of its Codex art piece (the same
-- palette as branding/source/proc-codex-art.py), else a related proc's, else its class colour. "glow" = the proc glow
-- colour, "custom" = one picked in the game's colour picker (A.PickColor). Codex art pieces keep their own colours.
A.COLORS = {
  overpower = { 1.00, 0.36, 0.14 }, revenge = { 0.94, 0.43, 0.16 }, execute = { 0.82, 0.08, 0.12 },
  victory_rush = { 0.90, 0.71, 0.16 }, riposte = { 0.47, 0.67, 1.00 }, counterattack = { 0.90, 0.59, 0.16 },
  mongoose_bite = { 0.47, 0.82, 0.24 }, hammer_of_wrath = { 1.00, 0.77, 0.24 },
  echo_of_command = { 1.00, 0.59, 0.12 }, echo_of_righteousness = { 1.00, 0.81, 0.35 },
  echo_of_justice = { 0.35, 0.59, 1.00 }, echo_of_fury = { 0.94, 0.24, 0.12 }, echo_of_light = { 1.00, 0.89, 0.31 },
  echo_of_wisdom = { 0.27, 0.67, 0.94 }, shadow_trance = { 0.51, 0.16, 0.86 },
  clearcasting_mage = { 0.35, 0.47, 1.00 }, clearcasting_druid = { 0.24, 0.75, 0.35 },
  clearcasting_shaman = { 0.16, 0.71, 0.94 }, missile_barrage = { 0.78, 0.31, 1.00 }, heating_up = { 1.00, 0.38, 0.08 },
}
-- procs without a piece of ours that share one's meaning (lower case)
A.COLOR_LIKE = { ["blade of justice"] = "hammer_of_wrath", ["art of war"] = "hammer_of_wrath",
  ["exorcism"] = "hammer_of_wrath", ["pyroblast"] = "heating_up", ["hot streak"] = "heating_up",
  ["nightfall"] = "shadow_trance", ["shadow bolt"] = "shadow_trance", ["arcane missiles"] = "missile_barrage",
  ["unsealed wrath"] = "echo_of_command" }

function A.ColorMode()
  local value = Q.DB()[A.COLOR_KEY]
  return (value == "glow" or value == "custom") and value or "proc"
end

function A.CustomColor()
  local c = Q.DB()[A.CUSTOM_KEY]
  if type(c) == "table" and Num(c[1]) and Num(c[2]) and Num(c[3]) then
    return { c[1], c[2], c[3] }
  end
  return { 1, 0.82, 0.3 }
end

local function ClassColor()
  local class = Class()
  local get = C_ClassColor and C_ClassColor.GetClassColor
  if class and type(get) == "function" then
    local ok, color = pcall(get, class)
    if ok and type(color) == "table" and Num(color.r) then
      return { color.r, color.g, color.b }
    end
  end
  return nil
end

-- A proc's own colour (its name), or nil when it has none.
function A.ProcColor(name)
  local key = A.CodexKey(name) or A.COLOR_LIKE[Lower(name) or ""]
  return key and A.COLORS[key] or nil
end

-- The tint for a proc's styled / arc art.
function A.TintFor(name)
  local mode = A.ColorMode()
  if mode == "custom" then
    return A.CustomColor()
  end
  if mode == "proc" then
    local own = A.ProcColor(name) or ClassColor()
    if own then
      return own
    end
  end
  return P.Color()
end

-- The game's colour picker for "Your colour": every change shows at once, Cancel puts the old colour back.
function A.PickColor()
  local picker = ColorPickerFrame
  if type(picker) ~= "table" or type(picker.SetupColorPickerAndShow) ~= "function" then
    return false
  end
  local db = Q.DB()
  local before = A.CustomColor()
  local beforeMode = db[A.COLOR_KEY]
  local function Changed()
    if Q.RefreshPage then
      Q.RefreshPage()
    end
    A.Refresh()
  end
  picker:SetupColorPickerAndShow({
    r = before[1], g = before[2], b = before[3], hasOpacity = false,
    swatchFunc = function()
      local r, g, b = picker:GetColorRGB()
      if Num(r) and Num(g) and Num(b) then
        db[A.CUSTOM_KEY] = { r, g, b }
        db[A.COLOR_KEY] = "custom"
        Changed()
      end
    end,
    cancelFunc = function()
      db[A.CUSTOM_KEY] = before
      db[A.COLOR_KEY] = beforeMode
      Changed()
    end,
  })
  return true
end

-- An ability's own art (a look, as A.Look), or nil: it follows A.Look(). Only while "Choose the art per ability" is
-- on.
function A.LookFor(name)
  local db = Q.DB()
  local own = db[A.LOOK_EACH_KEY] and type(name) == "string" and type(db[A.LOOK_FOR_KEY]) == "table"
    and db[A.LOOK_FOR_KEY][name]
  if own == "codex" or own == "icon" or own == "arc" or A.styleKeys[own] then
    return own
  end
  return nil
end

-- An ability's own side ("both", "left", "right", "top", "bottom"), or nil: it follows A.Side(). Only while
-- "Choose the side per ability" is on.
function A.SideFor(name)
  local db = Q.DB()
  local own = db[A.SIDE_EACH_KEY] and type(name) == "string" and type(db[A.SIDE_FOR_KEY]) == "table"
    and db[A.SIDE_FOR_KEY][name]
  if own == "both" or A.ONE_SIDE[own] then
    return own
  end
  return nil
end

-- "codex", "icon", "arc" or "style:<key>". A saved "game" (the game's art, a look until 2026-11-23) becomes Codex
-- art.
function A.Look()
  local db = Q.DB()
  local value = db[A.LOOK_KEY]
  if value == "icon" or value == "arc" or A.styleKeys[value] then
    return value
  end
  if value ~= "codex" then
    db[A.LOOK_KEY] = "codex"
  end
  return "codex"
end

-- A spell's icon (file ID or path), or nil; secret = none.
local function Texture(spell)
  local get = C_Spell and C_Spell.GetSpellTexture
  if type(get) ~= "function" then
    get = GetSpellTexture
  end
  if type(get) ~= "function" or spell == nil then
    return nil
  end
  local ok, icon = pcall(get, spell)
  if not ok or not Readable(icon) then
    return nil
  end
  if (type(icon) == "number" and icon > 0) or (type(icon) == "string" and icon ~= "") then
    return icon
  end
  return nil
end

-- The icon of a proc: its spell ID when the game lit it, else the buff's or reactive ability's IDs from the proc
-- glow's lists, else its name (spells you know).
function A.IconFor(name, id)
  local icon = id and Texture(id)
  if icon then
    return icon
  end
  local key = Lower(name)
  if not key then
    return nil
  end
  P.Lookup()
  local aura = P.auraNames and P.auraNames[key]
  for _, auraID in ipairs(aura and aura.ids or {}) do
    icon = Texture(auraID)
    if icon then
      return icon
    end
  end
  for _, entry in ipairs(P.REACTIVE or {}) do
    if Lower(entry.name) == key then
      for _, spellID in ipairs(entry.ids) do
        icon = Texture(spellID)
        if icon then
          return icon
        end
      end
    end
  end
  return Texture(name)
end

-- The art for a proc (its name, and its spell ID when known): { file, where, tint, icon, key }. A style: its piece,
-- tinted; "codex": Codex's piece,
-- else the spell's icon on the arc; "icon": the icon on the arc (else the arc); "arc": the arc. The arc is tinted in the
-- glow colour. Every file is a side file (128x256, outer edge left).
function A.ArtFor(name, id)
  local look = A.LookFor(name) or A.Look()
  local style = A.styleKeys[look]
  if style then
    return { file = A.CODEX_DIR .. "style_" .. style[1], where = "sides", tint = true, key = look, color = A.TintFor(name) }
  end
  if look == "codex" then
    local codex = A.CodexKey(name)
    if codex then
      return { file = A.CODEX_DIR .. codex, where = "sides", key = "codex:" .. codex }
    end
    look = "icon" -- no piece of ours for it: the spell's icon on the arc
  end
  if look ~= "arc" then
    local icon = A.IconFor(name, id)
    if icon then
      return { file = A.ARC, where = "sides", tint = true, icon = icon, key = "icon", color = A.TintFor(name) }
    end
  end
  return { file = A.ARC, where = "sides", tint = true, key = "arc", color = A.TintFor(name) }
end

-- Frames ----------------------------------------------------------------------------------------------------------

local function Anchor()
  if A.anchor then
    return A.anchor
  end
  local anchor = CreateFrame("Frame", nil, UIParent)
  anchor:SetSize(A.LONG, A.LONG)
  anchor:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  anchor:SetFrameStrata("BACKGROUND")
  if anchor.EnableMouse then
    anchor:EnableMouse(false)
  end
  A.anchor, A.pieces = anchor, {}
  return anchor
end

local function Animate(piece)
  if type(piece.CreateAnimationGroup) ~= "function" then
    return
  end
  pcall(function()
    local fadeIn = piece:CreateAnimationGroup()
    local alpha = fadeIn:CreateAnimation("Alpha")
    alpha:SetFromAlpha(0)
    alpha:SetToAlpha(1)
    alpha:SetDuration(0.2)
    fadeIn:SetScript("OnFinished", function()
      piece:SetAlpha(1)
      if piece.pulse then
        piece.pulse:Play()
      end
    end)
    piece.fadeIn = fadeIn
    local pulse = piece:CreateAnimationGroup()
    pulse:SetLooping("REPEAT")
    local grow = pulse:CreateAnimation("Scale")
    grow:SetScale(1.08, 1.08)
    grow:SetDuration(0.5)
    grow:SetOrder(1)
    local shrink = pulse:CreateAnimation("Scale")
    shrink:SetScale(1 / 1.08, 1 / 1.08)
    shrink:SetDuration(0.5)
    shrink:SetOrder(2)
    if grow.SetSmoothing then
      grow:SetSmoothing("IN_OUT")
      shrink:SetSmoothing("IN_OUT")
    end
    piece.pulse = pulse
    local fadeOut = piece:CreateAnimationGroup()
    local out = fadeOut:CreateAnimation("Alpha")
    out:SetFromAlpha(1)
    out:SetToAlpha(0)
    out:SetDuration(0.1)
    fadeOut:SetScript("OnFinished", function()
      if piece.pulse then
        piece.pulse:Stop()
      end
      piece:Hide()
      piece.key = nil
    end)
    piece.fadeOut = fadeOut
  end)
end

-- One piece per place: left, right, left2, right2, top, bottom, top2, bottom2.
local function Piece(place)
  local anchor = Anchor()
  local piece = A.pieces[place]
  if piece then
    return piece
  end
  piece = CreateFrame("Frame", nil, anchor)
  piece:Hide()
  piece.place = place
  piece.texture = piece:CreateTexture(nil, "ARTWORK")
  piece.texture:SetAllPoints()
  -- the icon look's icons, under the arc, each with a soft round mask
  piece.icons = {}
  for index = 1, #A.SPOTS do
    local icon = piece:CreateTexture(nil, "BORDER")
    icon:Hide()
    if type(piece.CreateMaskTexture) == "function" and type(icon.AddMaskTexture) == "function" then
      pcall(function()
        local mask = piece:CreateMaskTexture()
        mask:SetTexture(A.ICON_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(icon)
        icon:AddMaskTexture(mask)
        icon.mask = mask
      end)
    end
    piece.icons[index] = icon
  end
  Animate(piece)
  A.pieces[place] = piece
  return piece
end

-- Where a place sits against the box (0.8 x 256 square, as the game's own frame sets itself) (as the game's own frame): width, height, point, x, flips.
local PLACES = {
  left = { "short", "long", "RIGHT", "LEFT", 0 },
  right = { "short", "long", "LEFT", "RIGHT", 0, flipX = true },
  left2 = { "short", "long", "RIGHT", "LEFT", -1 },
  right2 = { "short", "long", "LEFT", "RIGHT", 1, flipX = true },
  top = { "long", "short", "BOTTOM", "TOP", 0 },
  bottom = { "long", "short", "TOP", "BOTTOM", 0, flipY = true },
  top2 = { "long", "short", "BOTTOM", "TOP", 0, y = 1 },
  bottom2 = { "long", "short", "TOP", "BOTTOM", 0, y = -1, flipY = true },
}
A.PLACES = PLACES

-- The texture corners (UL, LL, UR, LR as SetTexCoord takes them) that turn an art file so its outer edge faces
-- `place`'s outside: a side file (outer edge left, the "(" arc) as it is on the left, mirrored on the right, a
-- quarter turn clockwise on top and that mirrored at the bottom; a top file (256x128, outer edge up) the other way.
local function Corners(place, where)
  local spot = PLACES[place]
  local turns = 0 -- quarter turns clockwise
  local outerTop = spot[1] == "long" -- top, bottom and the ones further out
  if where == "top" and not outerTop then
    turns = 3
  elseif where ~= "top" and outerTop then
    turns = 1
  end
  local out = {}
  for _, corner in ipairs({ { 0, 0 }, { 0, 1 }, { 1, 0 }, { 1, 1 } }) do
    local u, v = corner[1], corner[2]
    if spot.flipX then
      u = 1 - u
    end
    if spot.flipY then
      v = 1 - v
    end
    for _ = 1, turns do
      u, v = v, 1 - u -- the display point's place in the file before a clockwise quarter turn
    end
    out[#out + 1] = u
    out[#out + 1] = v
  end
  return out
end
A.Corners = Corners

local function Place(piece, art)
  local spot = PLACES[piece.place]
  local size = A.Size()
  local width = (spot[1] == "long" and A.LONG or A.SHORT) * size
  local height = (spot[2] == "long" and A.LONG or A.SHORT) * size
  A.anchor:SetSize(A.LONG * size, A.LONG * size)
  piece:ClearAllPoints()
  piece:SetPoint(spot[3], A.anchor, spot[4], spot[5] * A.SHORT * size, (spot.y or 0) * A.SHORT * size)
  piece:SetSize(width, height)
  local ok = pcall(piece.texture.SetTexture, piece.texture, art.file)
  piece.texture:SetTexCoord(unpack(Corners(piece.place, art.where)))
  local color = art.tint and (art.color or P.Color()) or { 1, 1, 1 }
  piece.texture:SetVertexColor(color[1], color[2], color[3])
  if art.tint and piece.texture.SetBlendMode then
    piece.texture:SetBlendMode("ADD")
  elseif piece.texture.SetBlendMode then
    piece.texture:SetBlendMode("BLEND")
  end
  -- the icons along the arc (icon look), in the side file's own coordinates (128x256) scaled to the piece
  local scale = width / 128
  for index, icon in ipairs(piece.icons or {}) do
    local spot = A.SPOTS[index]
    if art.icon and spot and piece.place ~= "top" and piece.place ~= "bottom" then
      local y, side, alpha = spot[1], spot[2], spot[3]
      local x = 230 - math.sqrt(190 * 190 - (y - 128) * (y - 128)) + side * 0.55
      icon:ClearAllPoints()
      icon:SetSize(side * scale, side * scale)
      if PLACES[piece.place].flipX then
        icon:SetPoint("CENTER", piece, "TOPRIGHT", -x * scale, -y * scale)
        icon:SetTexCoord(0.92, 0.08, 0.08, 0.92)
      else
        icon:SetPoint("CENTER", piece, "TOPLEFT", x * scale, -y * scale)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      end
      pcall(icon.SetTexture, icon, art.icon)
      icon:SetAlpha(alpha)
      icon:Show()
    else
      icon:Hide()
    end
  end
  return ok
end

local function ShowPiece(place, art, name)
  local piece = Piece(place)
  local again = piece:IsShown() and piece.key == name and not piece.leaving
  piece.key, piece.art, piece.leaving = name, art, nil
  Place(piece, art)
  if piece.fadeOut and piece.fadeOut.Stop then
    piece.fadeOut:Stop()
  end
  if again then
    return piece
  end
  piece:SetAlpha(piece.fadeIn and 0 or 1)
  piece:Show()
  if piece.fadeIn and piece.fadeIn.Play then
    piece.fadeIn:Play()
  end
  return piece
end

local function HidePiece(piece)
  if not piece:IsShown() or piece.leaving then
    return
  end
  piece.leaving = true
  if piece.fadeIn and piece.fadeIn.Stop then
    piece.fadeIn:Stop() -- else its end would start the pulse again
  end
  if piece.pulse and piece.pulse.Pause then
    piece.pulse:Pause()
  end
  if piece.fadeOut and piece.fadeOut.Play then
    piece.fadeOut:Play()
  else
    piece:Hide()
    piece.key = nil
  end
end

-- The game's own spells -------------------------------------------------------------------------------------------

A.gameLit, A.gameArt = {}, {} -- [spellID] = when it lit (a count) / true: shown by the game's own side art
A.count = 0

-- Called from ProcGlow's events (before its update).
function A.OnEvent(event, spellID)
  local id = Num(spellID)
  if event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
    if id and not A.gameLit[id] then
      A.count = A.count + 1
      A.gameLit[id] = A.count
    end
  elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
    if id then
      A.gameLit[id] = nil
    end
  elseif event == "SPELL_ACTIVATION_OVERLAY_SHOW" then
    if id then
      A.gameArt[id] = true
    end
  elseif event == "SPELL_ACTIVATION_OVERLAY_HIDE" then
    if id then
      A.gameArt[id] = nil
    else
      A.gameArt = {}
    end
  elseif event == "PLAYER_ENTERING_WORLD" then
    A.gameLit, A.gameArt = {}, {}
  end
end

-- Still lit by the game? (the API says no = drop it; secret or missing = trust the event)
local function StillLit(id)
  local check = C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed
  if type(check) ~= "function" then
    return true
  end
  local ok, value = pcall(check, id)
  if ok and Readable(value) and value == false then
    return false
  end
  return true
end

-- The procs to show ({ name, id }), in order: Codex's lit procs (their names), then the spells the game lights itself; the ones
-- the game's own frame already shows art for are left out.
function A.Names(order)
  local names, seen, skip = {}, {}, {}
  for id in pairs(A.gameArt) do
    local name = Lower(SpellName(id))
    if name then
      skip[name] = true
    end
  end
  local function Add(name, id)
    local key = Lower(name)
    if key and not seen[key] and not skip[key] then
      seen[key] = true
      names[#names + 1] = { name = name, id = id }
    end
  end
  for _, key in ipairs(order or {}) do
    Add(key)
  end
  local ids = {}
  for id in pairs(A.gameLit) do
    ids[#ids + 1] = id
  end
  table.sort(ids, function(a, b)
    return A.gameLit[a] < A.gameLit[b] -- first lit first
  end)
  for _, id in ipairs(ids) do
    if not StillLit(id) then
      A.gameLit[id] = nil
    else
      local can, ends = P.Castable(id) -- shown only while it can be cast (mana, cooldowns)
      if can then
        Add(SpellName(id), id)
      elseif P.WakeAt then
        P.WakeAt(ends)
      end
    end
  end
  return names
end

-- Showing ---------------------------------------------------------------------------------------------------------

-- Where each of several procs goes, by how many there are (2026-11-22): one on both sides, two left and right, three
-- adds the top, four the bottom. With one side chosen (A.Side): the first on that side (turned to face it), the second
-- further out on the same side, then the two sides next to it.
A.SLOTS = { { "left", "right", "top", "bottom" } }
A.ONE_SIDE = {
  left = { "left", "left2", "top", "bottom" },
  right = { "right", "right2", "top", "bottom" },
  top = { "top", "top2", "left", "right" },
  bottom = { "bottom", "bottom2", "left", "right" },
}

-- Puts each proc ({ art, name }, in order) on its places in `wanted` ([place] = proc). An ability with a side of its own
-- (A.SideFor) goes there first: that side, then further out on it ("both": left and right, while both are free);
-- when those are taken it joins the others. The others follow Art side as before: one side = its places in order
-- (A.ONE_SIDE), both = one alone on both sides, several left, right, top, bottom; taken places are skipped, and the
-- places further out are the last resort.
A.OWN = { left = { "left", "left2" }, right = { "right", "right2" }, top = { "top", "top2" },
  bottom = { "bottom", "bottom2" } }
A.SPARE = { "left2", "right2", "top2", "bottom2" }
function A.Place(list, wanted)
  local rest = {}
  for _, one in ipairs(list) do
    local own, placed = A.SideFor(one.name), false
    if own == "both" then
      if not wanted.left and not wanted.right then
        wanted.left, wanted.right, placed = one, one, true
      end
    elseif own then
      for _, place in ipairs(A.OWN[own]) do
        if not placed and not wanted[place] then
          wanted[place], placed = one, true
        end
      end
    end
    if not placed then
      rest[#rest + 1] = one
    end
  end
  local order = A.ONE_SIDE[A.Side()]
  if not order then
    if #rest == 1 and not next(wanted) then
      wanted.left, wanted.right = rest[1], rest[1]
      return wanted
    end
    order = A.SLOTS[1]
  end
  local function Next(places)
    for _, place in ipairs(places) do
      if not wanted[place] then
        return place
      end
    end
  end
  for _, one in ipairs(rest) do
    local place = Next(order) or Next(A.SPARE)
    if place then
      wanted[place] = one
    end
  end
  return wanted
end

-- Shows the art for these procs (names or { name, id }, in order; at most A.MAX) and fades out the rest.
function A.Show(names)
  local wanted = {}
  local list = {}
  for _, entry in ipairs(names) do
    if #list >= A.MAX then
      break
    end
    local name, id = entry, nil
    if type(entry) == "table" then
      name, id = entry.name, entry.id
    end
    list[#list + 1] = { art = A.ArtFor(name, id), name = name }
  end
  A.Place(list, wanted)
  if next(wanted) then
    Anchor()
    A.anchor:SetAlpha(A.Alpha())
    A.anchor:Show()
  end
  for place, want in pairs(wanted) do
    ShowPiece(place, want.art, want.name)
  end
  for place, piece in pairs(A.pieces or {}) do
    if not wanted[place] then
      HidePiece(piece)
    end
  end
  A.shown = wanted
  return wanted
end

local function KeyOf(entry)
  return Lower(type(entry) == "table" and entry.name or entry)
end

-- The old rotation (2026-11-20: one at a time, the next every A.ROTATE seconds). A.Update no longer uses it since
-- several procs share the places (A.Show); A.Rotate is kept for the Test button's history and the tests.
A.rotation = { names = {}, index = 1, gen = 0 }

local function ShowCurrent()
  local rotation = A.rotation
  local entry = rotation.names[rotation.index]
  A.Show(entry and { entry } or {})
end

local function Tick(gen)
  local rotation = A.rotation
  if rotation.gen ~= gen or #rotation.names < 2 or A.testing then
    return
  end
  rotation.index = rotation.index % #rotation.names + 1
  ShowCurrent()
  C_Timer.After(A.ROTATE, function()
    Tick(gen)
  end)
end

function A.Rotate(names)
  local rotation = A.rotation
  local current = rotation.names[rotation.index]
  local key = current and KeyOf(current)
  rotation.names, rotation.index = names, 1
  for index, entry in ipairs(names) do
    if key and KeyOf(entry) == key then
      rotation.index = index -- the one showing stays
    end
  end
  if #names >= 2 then
    if not rotation.running then
      rotation.running = true
      rotation.gen = rotation.gen + 1
      local gen = rotation.gen
      C_Timer.After(A.ROTATE, function()
        Tick(gen)
      end)
    end
  else
    rotation.running = false
    rotation.gen = rotation.gen + 1 -- stops a waiting tick
  end
  ShowCurrent()
end

-- From ProcGlow's update: `order` = the proc names Codex lit, first started first.
function A.Update(order)
  if A.testing then
    return
  end
  if not (P.started and A.On()) then
    A.Rotate({})
    A.HideAll()
    return
  end
  -- no rotation any more: up to A.MAX procs show together (a waiting tick of an older rotation is stopped)
  local rotation = A.rotation
  rotation.running, rotation.gen, rotation.names = false, rotation.gen + 1, {}
  A.Show(A.Names(order))
end

function A.HideAll()
  for _, piece in pairs(A.pieces or {}) do
    HidePiece(piece)
  end
  A.shown = {}
end

-- Settings changed (size, opacity, look): redraw what shows.
function A.Refresh()
  if A.testing then
    A.Show(A.testNames)
    return
  end
  if P.started then
    P.Update()
  end
end

-- The option's Test button: a few seconds of art for one of your class's procs.
local TEST = { PALADIN = "Blade of Justice", WARLOCK = "Shadow Trance", WARRIOR = "Execute", MAGE = "Pyroblast",
  DRUID = "Clearcasting", DEATHKNIGHT = "Obliterate", HUNTER = "Aimed Shot", PRIEST = "Flash Heal",
  SHAMAN = "Maelstrom Weapon" }
A.TEST = TEST
-- with Codex art: a proc of your class that has a piece
local TEST_CODEX = { PALADIN = "Echo of Command", WARLOCK = "Shadow Trance", WARRIOR = "Overpower", MAGE = "Clearcasting",
  DRUID = "Clearcasting", HUNTER = "Mongoose Bite", ROGUE = "Riposte", SHAMAN = "Clearcasting" }
A.TEST_CODEX = TEST_CODEX
function A.Test()
  A.testing = true
  local codex = A.Look() == "codex" and TEST_CODEX[Class() or ""]
  A.testNames = { codex or TEST[Class() or ""] or "Blade of Justice" }
  A.Show(A.testNames)
  local token = {}
  A.testToken = token
  local function Done()
    if A.testToken ~= token then
      return
    end
    A.testing = false
    A.HideAll()
    if P.started then
      P.Update()
    end
  end
  if C_Timer and C_Timer.After then
    C_Timer.After(3, Done)
  end
  return A.testNames[1]
end

-- The gallery: every Codex art piece, both sides, with its proc and class (the option's "Show all arts").
local GALLERY_COLS, CELL_W, CELL_H = 9, 130, 176

function A.Gallery()
  local UI = ns.UI
  local frame = A.gallery
  if not frame then
    frame = CreateFrame("Frame", (ns.PROC_FRAMES or "Codex") .. "ProcArtGallery", UIParent)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    local entries = {}
    for _, entry in ipairs(A.CODEX) do
      entries[#entries + 1] = entry
    end
    for _, style in ipairs(A.STYLES) do -- the styles after the pieces, in the glow colour
      entries[#entries + 1] = { "style_" .. style[1], style[2], "Style, any proc", tint = style[3] }
    end
    local rows = math.ceil(#entries / GALLERY_COLS)
    frame:SetSize(GALLERY_COLS * CELL_W + 32, rows * CELL_H + 70)
    frame:SetPoint("CENTER")
    UI.Panel(frame, { cornerSize = 14 })
    local title = UI.Text(frame, "head", 15, "accent")
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetText(ns.PROC_ART_NAME or "Codex art")
    local note = UI.Text(frame, "body", 11, "muted")
    note:SetPoint("LEFT", title, "RIGHT", 12, -1)
    note:SetText("The art beside your character for each proc " .. BRAND .. " knows, then the styles any proc can use.")
    local close = UI.CloseButton(frame)
    close:SetPoint("TOPRIGHT", -10, -10)
    table.insert(UISpecialFrames, (ns.PROC_FRAMES or "Codex") .. "ProcArtGallery")
    frame.cells = {}
    for index, entry in ipairs(entries) do
      local col, row = (index - 1) % GALLERY_COLS, math.floor((index - 1) / GALLERY_COLS)
      local cell = CreateFrame("Frame", nil, frame)
      cell:SetSize(CELL_W - 10, CELL_H - 10)
      cell:SetPoint("TOPLEFT", 16 + col * CELL_W, -44 - row * CELL_H)
      local back = cell:CreateTexture(nil, "BACKGROUND")
      back:SetAllPoints()
      back:SetColorTexture(0, 0, 0, 0.35)
      local left = cell:CreateTexture(nil, "ARTWORK")
      left:SetSize(56, 112)
      left:SetPoint("TOPRIGHT", cell, "TOP", 0, -8)
      left:SetTexture(A.CODEX_DIR .. entry[1])
      local right = cell:CreateTexture(nil, "ARTWORK")
      right:SetSize(56, 112)
      right:SetPoint("TOPLEFT", cell, "TOP", 0, -8)
      right:SetTexture(A.CODEX_DIR .. entry[1])
      right:SetTexCoord(1, 0, 0, 1)
      if entry.tint then
        local mode = A.ColorMode()
        local color = mode == "custom" and A.CustomColor() or mode == "glow" and P.Color() or entry.tint
        for _, side in ipairs({ left, right }) do
          side:SetVertexColor(color[1], color[2], color[3])
          if side.SetBlendMode then
            side:SetBlendMode("ADD")
          end
        end
      end
      local name = UI.Text(cell, "body", 12, "bright")
      name:SetPoint("TOP", left, "BOTTOM", 56 / 2 + 0, -6)
      name:SetPoint("LEFT", cell, "LEFT", 4, 0)
      name:SetPoint("RIGHT", cell, "RIGHT", -4, 0)
      name:SetJustifyH("CENTER")
      name:SetText(entry[2])
      local class = UI.Text(cell, "body", 11, "muted")
      class:SetPoint("TOP", name, "BOTTOM", 0, -2)
      class:SetPoint("LEFT", cell, "LEFT", 4, 0)
      class:SetPoint("RIGHT", cell, "RIGHT", -4, 0)
      class:SetJustifyH("CENTER")
      class:SetText(entry[3])
      cell.key, cell.left, cell.right, cell.name = entry[1], left, right, name
      frame.cells[index] = cell
    end
    frame:Hide()
    A.gallery = frame
  end
  frame:SetShown(not frame:IsShown())
  return frame
end
