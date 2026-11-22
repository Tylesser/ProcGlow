local addonName, ns = ...

-- Proc glow, part 2: art beside your character while an ability procs (the user's ask, 2026-11-19: "like in retail
-- for Blade of Justice there are 2 swords"), on top of the glowing buttons.
--
-- Forever facts (forever branch of Gethe/wow-ui-source): Blizzard_FrameXML/SpellActivationOverlay.lua is there and
-- shows art on SPELL_ACTIVATION_OVERLAY_SHOW (spellID, overlayFileDataID, locationType, scale, r, g, b), but
-- Forever's spell data sends that for next to nothing: the side art never shows, while the buttons still light on
-- SPELL_ACTIVATION_OVERLAY_GLOW_SHOW (spellID). So Codex draws its own: for every proc that is lit (Codex's own list,
-- and every spell the game lights with the glow event), the game's art for it from P.ART (its FileDataID; each
-- file's size, read from the BLP header, says where it goes: 128x256 = left and right, 256x128 = above), else
-- Codex's ProcSide arc in the glow colour. Placement and animation follow the game's frame: a 204.8 square box at
-- the screen centre, sides 0.8 x 128x256 against its left and right edge (the right one mirrored), the top one over it,
-- a 0.2 s fade in, a 1.08 pulse every 0.5 s and a 0.1 s fade out. Several procs share the places by count
-- (A.Show): one = both sides, two = left and right, three = + top, four = + bottom (side art turned a quarter).
-- Whatever the game's own frame shows (SPELL_ACTIVATION_OVERLAY_SHOW) is left to it.
-- The "spell's icon" look (also what the game's look falls back to): the arc, with the proc's own icon three
-- times along it on each side (big in the middle, two smaller up and down the curve, soft round edges from the
-- ProcIconMask mask; the right side mirrored), so the art says which ability lit. Plain textures on a frame of
-- ours on UIParent: nothing secure, works in combat.

local unpack = unpack or table.unpack
local Q = ns.qol
local P = Q.procglow
local A = {}
P.art = A

A.KEY, A.LOOK_KEY, A.SIZE_KEY, A.ALPHA_KEY = "procArt", "procArtLook", "procArtSize", "procArtAlpha"
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

-- The game's art (FileDataID, textures/spellactivationoverlays/*.blp) and where it goes: "sides" (a 128x256 file)
-- or "top" (256x128). Keyed by the lit ability's name or the buff that lit it, lower case.
local ART = {
  art_of_war = { 450913, "sides" }, nightfall = { 449492, "sides" }, sudden_death = { 449493, "sides" },
  arcane_missiles = { 449486, "sides" }, omen = { 510823, "sides" }, killing_machine = { 458740, "sides" },
  molten_core = { 458741, "sides" }, hot_streak = { 449490, "sides" }, frozen_fingers = { 449489, "sides" },
  grand_crusader = { 450925, "sides" }, sword_and_board = { 449494, "sides" }, surge_of_light = { 450933, "sides" },
  sudden_doom = { 450932, "sides" }, raging_blow = { 962497, "sides" }, brain_freeze = { 449488, "top" },
  rime = { 450930, "top" }, backlash = { 460830, "top" }, maelstrom = { 450927, "top" },
  master_marksman = { 450928, "top" }, lock_and_load = { 450926, "top" }, shooting_stars = { 463452, "top" },
  predatory = { 898423, "top" },
}
A.FILES = ART
P.ART = {
  ["blade of justice"] = "art_of_war", ["art of war"] = "art_of_war", ["the art of war"] = "art_of_war",
  ["exorcism"] = "art_of_war",
  ["shadow trance"] = "nightfall", ["nightfall"] = "nightfall", ["shadow bolt"] = "nightfall",
  ["execute"] = "sudden_death", ["sudden death"] = "sudden_death",
  ["arcane missiles"] = "arcane_missiles", ["missile barrage"] = "arcane_missiles",
  ["obliterate"] = "killing_machine", ["frost strike"] = "killing_machine", ["killing machine"] = "killing_machine",
  ["molten core"] = "molten_core", ["incinerate"] = "molten_core", ["soul fire"] = "molten_core",
  ["pyroblast"] = "hot_streak", ["hot streak"] = "hot_streak",
  ["ice lance"] = "frozen_fingers", ["fingers of frost"] = "frozen_fingers",
  ["avenger's shield"] = "grand_crusader", ["grand crusader"] = "grand_crusader",
  ["shield slam"] = "sword_and_board", ["sword and board"] = "sword_and_board",
  ["flash heal"] = "surge_of_light", ["surge of light"] = "surge_of_light",
  ["death coil"] = "sudden_doom", ["sudden doom"] = "sudden_doom",
  ["raging blow"] = "raging_blow",
  ["frostfire bolt"] = "brain_freeze", ["brain freeze"] = "brain_freeze", ["flurry"] = "brain_freeze",
  ["howling blast"] = "rime", ["rime"] = "rime",
  ["backlash"] = "backlash",
  ["maelstrom weapon"] = "maelstrom",
  ["aimed shot"] = "master_marksman", ["master marksman"] = "master_marksman",
  ["explosive shot"] = "lock_and_load", ["lock and load"] = "lock_and_load",
  ["starsurge"] = "shooting_stars", ["shooting stars"] = "shooting_stars",
  ["predatory swiftness"] = "predatory",
}
-- Clearcasting looks different per class.
A.CLEARCASTING = { MAGE = "arcane_missiles", DRUID = "omen" }

A.LOOKS = { { "codex", (ns.PROC_ART_NAME or "Codex art") }, { "game", "The game's art" }, { "icon", "The spell's icon" },
  { "arc", "An arc in the glow colour" } }

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

-- The art for a proc (its name, and its spell ID when known): { file, where, tint, icon, key }. "game": the game's
-- file, else the spell's icon on the arc, else the arc; "icon": the icon on the arc (else the arc); "arc": the arc.
-- The arc is tinted in the glow colour.
function A.ArtFor(name, id)
  local key = Lower(name)
  local look = Q.DB()[A.LOOK_KEY]
  if look == "codex" then
    local codex = A.CodexKey(name)
    if codex then
      return { file = A.CODEX_DIR .. codex, where = "sides", key = "codex:" .. codex }
    end
    look = "icon" -- no piece of ours for it: the spell's icon on the arc
  end
  if look ~= "arc" and look ~= "icon" and key then
    local pick = P.ART[key]
    if key == "clearcasting" then
      pick = A.CLEARCASTING[Class() or ""]
    end
    local art = pick and ART[pick]
    if art then
      return { file = art[1], where = art[2], key = pick }
    end
  end
  if look ~= "arc" then
    local icon = A.IconFor(name, id)
    if icon then
      return { file = A.ARC, where = "sides", tint = true, icon = icon, key = "icon" }
    end
  end
  return { file = A.ARC, where = "sides", tint = true, key = "arc" }
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

-- One piece per place: left, right, left2, right2, top, bottom.
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
}
A.PLACES = PLACES

-- The texture corners (UL, LL, UR, LR as SetTexCoord takes them) that turn an art file so its outer edge faces
-- `place`'s outside: a side file (outer edge left, the "(" arc) as it is on the left, mirrored on the right, a
-- quarter turn clockwise on top and that mirrored at the bottom; a top file (256x128, outer edge up) the other way.
local function Corners(place, where)
  local spot = PLACES[place]
  local turns = 0 -- quarter turns clockwise
  local outerTop = place == "top" or place == "bottom"
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
  piece:SetPoint(spot[3], A.anchor, spot[4], spot[5] * A.SHORT * size, 0)
  piece:SetSize(width, height)
  local ok = pcall(piece.texture.SetTexture, piece.texture, art.file)
  piece.texture:SetTexCoord(unpack(Corners(piece.place, art.where)))
  local color = art.tint and P.Color() or { 1, 1, 1 }
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

-- Where each of several procs goes, by how many there are (2026-11-22): one on both sides (or on top, for a top file
-- of the game's), two left and right, three adds the top, four the bottom.
A.SLOTS = { { "left", "right", "top", "bottom" } }

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
  if #list == 1 then
    local one = list[1]
    if one.art.where == "top" then
      wanted.top = one
    else
      wanted.left, wanted.right = one, one
    end
  else
    for index, one in ipairs(list) do
      wanted[A.SLOTS[1][index]] = one
    end
  end
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
  local codex = Q.DB()[A.LOOK_KEY] == "codex" and TEST_CODEX[Class() or ""]
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
local GALLERY_COLS, CELL_W, CELL_H = 5, 150, 190

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
    local rows = math.ceil(#A.CODEX / GALLERY_COLS)
    frame:SetSize(GALLERY_COLS * CELL_W + 32, rows * CELL_H + 70)
    frame:SetPoint("CENTER")
    UI.Panel(frame, { cornerSize = 14 })
    local title = UI.Text(frame, "head", 15, "accent")
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetText(ns.PROC_ART_NAME or "Codex art")
    local note = UI.Text(frame, "body", 11, "muted")
    note:SetPoint("LEFT", title, "RIGHT", 12, -1)
    note:SetText("The art beside your character for each proc " .. BRAND .. " knows. Other procs show their icon on the arc.")
    local close = UI.CloseButton(frame)
    close:SetPoint("TOPRIGHT", -10, -10)
    table.insert(UISpecialFrames, (ns.PROC_FRAMES or "Codex") .. "ProcArtGallery")
    frame.cells = {}
    for index, entry in ipairs(A.CODEX) do
      local col, row = (index - 1) % GALLERY_COLS, math.floor((index - 1) / GALLERY_COLS)
      local cell = CreateFrame("Frame", nil, frame)
      cell:SetSize(CELL_W - 10, CELL_H - 10)
      cell:SetPoint("TOPLEFT", 16 + col * CELL_W, -44 - row * CELL_H)
      local back = cell:CreateTexture(nil, "BACKGROUND")
      back:SetAllPoints()
      back:SetColorTexture(0, 0, 0, 0.35)
      local left = cell:CreateTexture(nil, "ARTWORK")
      left:SetSize(64, 128)
      left:SetPoint("TOPRIGHT", cell, "TOP", 0, -8)
      left:SetTexture(A.CODEX_DIR .. entry[1])
      local right = cell:CreateTexture(nil, "ARTWORK")
      right:SetSize(64, 128)
      right:SetPoint("TOPLEFT", cell, "TOP", 0, -8)
      right:SetTexture(A.CODEX_DIR .. entry[1])
      right:SetTexCoord(1, 0, 0, 1)
      local name = UI.Text(cell, "body", 12, "bright")
      name:SetPoint("TOP", left, "BOTTOM", 64 / 2 + 0, -6)
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
