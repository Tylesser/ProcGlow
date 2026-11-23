local addonName, ns = ...

-- Glow on proc abilities. An action button glows while a reactive ability on it can be used (Overpower after a
-- dodge, Revenge after a block, dodge or parry, Execute and Hammer of Wrath on a target under 20 %, Riposte,
-- Counterattack, Mongoose Bite, Victory Rush where the game has it) or while one of your buffs makes it free or
-- instant (Shadow Trance: Shadow Bolt; Clearcasting: a short list per class). Optional: a sound when one starts.
--
-- Forever facts (forever branch of Gethe/wow-ui-source, Blizzard_ActionBar): Blizzard's action buttons glow by
-- themselves on SPELL_ACTIVATION_OVERLAY_GLOW_SHOW / _HIDE (ActionButtonSpellAlertManager:ShowAlert, the
-- "UI-HUD-ActionBar-Proc-*-Flipbook" alert). Whatever the game lights that way is left to it: a button is skipped
-- while C_SpellActivationOverlay.IsSpellOverlayed(spell) or the manager's HasAlert(button) says it glows. For the
-- Classic reactive abilities the signal is the usable state: C_ActionBar.IsUsableAction(slot) (the global
-- IsUsableAction exists only with the deprecation fallbacks), re-read on ACTION_USABLE_CHANGED (what Forever's
-- buttons listen to; ACTIONBAR_UPDATE_USABLE is commented out there), ACTIONBAR_UPDATE_USABLE,
-- SPELL_UPDATE_USABLE, UNIT_AURA (player), PLAYER_TARGET_CHANGED and UNIT_HEALTH (target). Buff procs are read
-- from the player's buffs (C_UnitAuras.GetAuraDataByIndex), by spell ID or name.
--
-- The glow is ours: a frame of our own on the button. ActionButtonSpellAlertManager is never called (it writes
-- its own state table from our tainted code, and Blizzard's buttons read it in their own updates); with the
-- game's look we only build Blizzard's ActionButtonSpellAlertTemplate on a frame of ours. With Codex's action bar
-- restyle on, a square pulsing border in the theme's accent instead (the restyled buttons are square). Nothing
-- secure is touched (no attributes, no Blizzard methods, only `button.action` is read), so it works in combat.
-- Secret values count as "not lit". Off = no events, no frames.

local Q = ns.qol
local P = {}
Q.procglow = P

local KEY = "procGlow"
local SOUND_KEY, KIT_KEY, COMBAT_KEY, MASTER_KEY = "procSound", "procSoundKit", "procSoundCombat", "procSoundMaster"
local EACH_KEY, FOR_KEY = "procSoundEach", "procSoundFor"
local STYLE_KEY, COLOR_KEY, SPEED_KEY, THICK_KEY = "procGlowStyle", "procGlowColor", "procGlowSpeed", "procGlowThickness"
local CDM_KEY = "procGlowCDM"
local GAME_KEY = "procGlowCDMGame" -- Codex's glow instead of the game's own alert on the cooldown manager
P.SOUND_GAP = 1.5 -- seconds between two proc sounds, across all procs
P.PULSE = 0.5

-- Reactive abilities: usable = lit. IDs are every rank (Classic Era); names catch the rest.
P.REACTIVE = {
  { name = "Overpower", ids = { 7384, 7887, 11584, 11585 } },
  { name = "Revenge", ids = { 6572, 6574, 7379, 11600, 11601, 25288 } },
  { name = "Execute", ids = { 5308, 20658, 20660, 20661, 20662 } },
  { name = "Victory Rush", ids = { 34428 } },
  { name = "Riposte", ids = { 14251 } },
  { name = "Counterattack", ids = { 19306, 20909, 20910 } },
  { name = "Mongoose Bite", ids = { 1495, 14269, 14270, 14271 } },
  { name = "Hammer of Wrath", ids = { 24275, 24274, 24239 } },
}

-- Buff procs: while the buff is on you, these spells glow (class = only for that class; stacks = only from that many
-- stacks of the buff; notActive = not a spell whose own buff is on you; artOnly = the art beside you and the sound,
-- no glow on the buttons: Clearcasting, the user's request 2026-11-22).
P.AURAS = {
  { name = "Shadow Trance", ids = { 17941 }, spells = { "Shadow Bolt" },
    spellIDs = { 686, 695, 705, 1088, 1106, 7641, 11659, 11660, 11661, 25307 } },
  { name = "Clearcasting", ids = { 12536 }, class = "MAGE", artOnly = true,
    spells = { "Arcane Missiles", "Arcane Explosion", "Blizzard", "Flamestrike" } },
  { name = "Clearcasting", ids = { 16870 }, class = "DRUID", artOnly = true,
    spells = { "Shred", "Maul", "Healing Touch", "Regrowth" } },
  { name = "Clearcasting", ids = { 16246 }, class = "SHAMAN", artOnly = true,
    spells = { "Lightning Bolt", "Chain Lightning", "Chain Heal" } },
  -- Missile Barrage (the user's request, 2026-11-22): the buff makes the next Arcane Missiles faster. Forever's own
  -- buff 1326083 and the older Season of Discovery ones (wago.tools wowf SpellName / SpellEffect); notIDs: the talent
  -- and rune themselves (400588 the passive, 401736 the rune), also named "Missile Barrage", never light it.
  -- Heating Up (the user's request, 2026-11-22): Forever's buff 400625 (wago.tools wowf build 1.60.1.71037: stacks
  -- up to 3, each cutting the next Pyroblast's cast time) lights Pyroblast at 3 stacks. notIDs: 400624 is the
  -- talent's passive of that name, 460878 a boss aura (Molten Core). A count hidden in combat comes from the
  -- cooldown manager when the buff is tracked there (secretStacks), as for the paladin echoes.
  { name = "Heating Up", ids = { 400625 }, notIDs = { [400624] = true, [460878] = true }, class = "MAGE",
    stacks = 3, secretStacks = true, spells = { "Pyroblast" },
    spellIDs = { 11366, 12505, 12522, 12523, 12524, 12525, 12526, 18809 } },
  { name = "Missile Barrage", ids = { 1326083, 400589, 467409 }, notIDs = { [400588] = true, [401736] = true },
    class = "MAGE", spells = { "Arcane Missiles" },
    spellIDs = { 5143, 5144, 5145, 8416, 8417, 10211, 10212, 25345 } },
}

-- Unsealed Wrath (Forever paladin talent 1310735): melee attacks store copies of your seal as an "Echo of <seal>"
-- buff, one per seal ("Empowers your next melee attack without Seal of X active"); landing an attack with a
-- different seal spends them. At 3 stacks (the user's request, 2026-11-20) the seals you could switch to glow, not
-- the one you have on, and each echo has its own art (Codex art: Media/ProcArt/echo_of_<seal>.tga). The first
-- version knew only Echo of Fury; the user's Seal of Command gave Echo of Command (seen with /codex procglow).
-- secretStacks: a stack count the game hides (a secret value in combat) counts as reached: there is no other way
-- to know it then, and the art showed nothing in a fight.
P.SEALS = { "Seal of Righteousness", "Seal of the Crusader", "Seal of Command", "Seal of Justice", "Seal of Light",
  "Seal of Wisdom", "Seal of Fury" }
for _, echo in ipairs({ { "Fury", 1311701 }, { "Command", 1311703 }, { "Righteousness", 1311704 },
  { "Justice", 1311705 }, { "Light", 1328198 }, { "Wisdom", 1328206 } }) do
  P.AURAS[#P.AURAS + 1] = { name = "Echo of " .. echo[1], ids = { echo[2] }, class = "PALADIN", stacks = 3,
    secretStacks = true, notActive = true, spells = P.SEALS, seal = "Seal of " .. echo[1] }
end

-- The sounds: { key, text, SOUNDKIT name, its ID, group }; the game's own (names and IDs from
-- Blizzard_SharedXML/Mainline/SoundKitConstants.lua, the file Forever loads; the ID is used when SOUNDKIT lacks one),
-- and Codex's own (group "codex", `file` in Media/Sounds: made by branding/source/proc-sounds.py from sine waves and
-- noise, 2026-11-23: the user's "more suitable sounds for procs", then "more related to spells, not random sounds"),
-- played with PlaySoundFile. "match" plays each proc the sound made for it (P.PROC_SOUNDS).
P.SOUNDS = {
  { "match", "Each proc's own sound", group = "codex" },
  { "sword_clash", "Blades clash", group = "codex", file = "sword_clash" },
  { "shield_bash", "Shield bash", group = "codex", file = "shield_bash" },
  { "axe_chop", "Axe blow", group = "codex", file = "axe_chop" },
  { "victory", "Victory horn", group = "codex", file = "victory" },
  { "parry", "Parry", group = "codex", file = "parry" },
  { "beast_snap", "Beast snap", group = "codex", file = "beast_snap" },
  { "holy_hammer", "Holy hammer", group = "codex", file = "holy_hammer" },
  { "holy_echo", "Holy echo", group = "codex", file = "holy_echo" },
  { "shadow", "Shadow whisper", group = "codex", file = "shadow" },
  { "arcane", "Arcane shimmer", group = "codex", file = "arcane" },
  { "missiles", "Arcane missiles", group = "codex", file = "missiles" },
  { "fire", "Fire catching", group = "codex", file = "fire" },
  { "nature", "Nature chimes", group = "codex", file = "nature" },
  { "lightning", "Lightning crackle", group = "codex", file = "lightning" },
  { "ping", "Map ping", "MAP_PING", 3175, "soft" },
  { "whisper", "Whisper", "TELL_MESSAGE", 3081, "soft" },
  { "coin", "Loot coin", "LOOT_WINDOW_COIN_SOUND", 120, "soft" },
  { "questdone", "Quest complete", "IG_QUEST_LIST_COMPLETE", 878, "soft" },
  { "invite", "Group invite", "IG_PLAYER_INVITE", 880, "soft" },
  { "aura", "Power aura", "UI_POWER_AURA_GENERIC", 23287, "soft" },
  { "toast", "Friend toast", "UI_BNET_TOAST", 18019, "soft" },
  { "raidwarning", "Raid warning", "RAID_WARNING", 8959, "loud" },
  { "readycheck", "Ready check", "READY_CHECK", 8960, "loud" },
  { "bossemote", "Boss emote", "RAID_BOSS_EMOTE_WARNING", 12197, "loud" },
  { "bosswhisper", "Boss whisper", "UI_RAID_BOSS_WHISPER_WARNING", 37666, "loud" },
  { "alarm", "Alarm clock", "ALARM_CLOCK_WARNING_3", 12889, "loud" },
  { "pvpqueue", "Battleground ready", "PVP_THROUGH_QUEUE", 8459, "loud" },
  { "epicloot", "Epic loot", "UI_EPICLOOT_TOAST", 31578, "loud" },
  { "none", "None" },
}

local BUTTONS = { "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton",
  "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button" }

local UPDATE_EVENTS = { "ACTION_USABLE_CHANGED", "ACTIONBAR_UPDATE_USABLE", "SPELL_UPDATE_USABLE",
  "SPELL_UPDATE_COOLDOWN", -- the art waits for the spell's cooldown and the global cooldown (P.Castable)
  "PLAYER_TARGET_CHANGED", "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE",
  "SPELL_ACTIVATION_OVERLAY_SHOW", "SPELL_ACTIVATION_OVERLAY_HIDE", "PLAYER_ENTERING_WORLD",
  "PLAYER_REGEN_ENABLED" }
local SCAN_EVENTS = { "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR",
  "UPDATE_OVERRIDE_ACTIONBAR", "UPDATE_SHAPESHIFT_FORM", "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED" }

local function Readable(value)
  if value == nil then
    return false
  end
  if issecretvalue and issecretvalue(value) then
    return false
  end
  if canaccessvalue and not canaccessvalue(value) then
    return false
  end
  return true
end

local function Pass(ok, ...)
  if ok then
    return ...
  end
  return nil
end

local function Ask(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  return Pass(pcall(fn, ...))
end

local function Num(value)
  return Readable(value) and type(value) == "number" and value or nil
end

local function Str(value)
  return Readable(value) and type(value) == "string" and value ~= "" and value or nil
end

-- true / false when readable, else nil
local function Bool(value)
  if not Readable(value) then
    return nil
  end
  return value and true or false
end

local function Lower(text)
  return text and text:lower() or nil
end

local function SpellName(id)
  if C_Spell and C_Spell.GetSpellName then
    return Str(Ask(C_Spell.GetSpellName, id))
  end
  return nil
end

local function PlayerClass()
  return select(2, UnitClass("player"))
end

-- Lookup ---------------------------------------------------------------------------------------------------------

-- byID / byName (lower case) -> { key, reactive = true } or { key, auras = { aura, ... } }. English names and the
-- client's own (from the first ID), so other languages match too.
function P.Lookup()
  if P.lookup then
    return P.lookup
  end
  local byID, byName = {}, {}
  local function Names(name, ids)
    local list = { Lower(name) }
    local own = ids and ids[1] and Lower(SpellName(ids[1]))
    if own and own ~= list[1] then
      list[2] = own
    end
    return list
  end
  for _, entry in ipairs(P.REACTIVE) do
    local item = { key = entry.name, reactive = true }
    for _, id in ipairs(entry.ids) do
      byID[id] = item
    end
    for _, name in ipairs(Names(entry.name, entry.ids)) do
      byName[name] = item
    end
  end
  local class = PlayerClass()
  P.auraNames, P.auraIDs = {}, {}
  for _, aura in ipairs(P.AURAS) do
    if not aura.class or aura.class == class then
      for _, id in ipairs(aura.ids) do
        P.auraIDs[id] = aura
      end
      for _, name in ipairs(Names(aura.name, aura.ids)) do
        P.auraNames[name] = aura
      end
      for index, spell in ipairs(aura.spells) do
        local key = Lower(spell)
        local item = byName[key]
        if not item then
          item = { key = spell, auras = {} }
          byName[key] = item
        end
        if item.auras then
          item.auras[#item.auras + 1] = aura
        end
        if index == 1 then
          for _, id in ipairs(aura.spellIDs or {}) do
            byID[id] = item
          end
        end
      end
    end
  end
  P.lookup = { byID = byID, byName = byName }
  return P.lookup
end

-- The spell on an action slot (a spell, or a macro that casts one), or nil.
local function SlotSpell(slot)
  if type(GetActionInfo) ~= "function" then
    return nil
  end
  local kind, id, sub = Pass(pcall(GetActionInfo, slot))
  if not Readable(kind) then
    return nil
  end
  if kind == "spell" or (kind == "macro" and Readable(sub) and sub == "spell") then
    return Num(id)
  end
  return nil
end

function P.Entry(id)
  local lookup = P.Lookup()
  local entry = lookup.byID[id]
  if entry then
    return entry
  end
  local name = Lower(SpellName(id))
  return name and lookup.byName[name] or nil
end

-- Buttons --------------------------------------------------------------------------------------------------------

function P.Buttons()
  local list = {}
  for _, prefix in ipairs(BUTTONS) do
    for index = 1, 12 do
      local button = _G[prefix .. index]
      if type(button) == "table" and type(button.GetObjectType) == "function" then
        list[#list + 1] = button
      end
    end
  end
  return list
end

P.watch = {}
P.glows = setmetatable({}, { __mode = "k" }) -- [button] = our glow frame

-- Which buttons hold a listed spell now.
function P.Scan()
  P.queued = false
  if not P.started then
    return
  end
  local watch = {}
  for _, button in ipairs(P.Buttons()) do
    local slot = Num(rawget(button, "action"))
    local id = slot and SlotSpell(slot)
    local entry = id and P.Entry(id)
    if entry then
      watch[#watch + 1] = { button = button, slot = slot, id = id, entry = entry }
      if not InCombatLockdown() then
        P.Glow(button) -- made out of combat where we can
      end
    end
  end
  if Q.DB()[CDM_KEY] then
    P.HookViewers()
    for _, item in ipairs(P.CDMItems()) do
      local id = P.ItemSpell(item)
      local entry = id and P.Entry(id)
      if id and not entry and P.ReplaceGame() then
        -- not on our list: lit only while the game lights it (P.Lit)
        entry = { key = SpellName(id) or tostring(id), game = true }
      end
      if entry then
        watch[#watch + 1] = { button = item, id = id, entry = entry, cdm = true }
        if not InCombatLockdown() then
          P.Glow(item)
        end
      end
    end
  end
  P.watch = watch
  P.Update()
end

-- Cooldown manager (Blizzard_CooldownViewer, forever branch) -----------------------------------------------------
-- Its Essential / Utility viewers already show the game's own spell alert on their items for what the game lights
-- (RefreshOverlayGlow -> ActionButtonSpellAlertManager): those are skipped like the action buttons (P.GameGlows).
-- For our list, an item's spell comes from its cooldownID (a plain field Blizzard sets) through
-- C_CooldownViewer.GetCooldownViewerCooldownInfo (overrideSpellID, else spellID); nothing of the item is written,
-- only read. The viewers pool their items (RefreshLayout releases and acquires them, RefreshData sets new
-- cooldownIDs in place): post hooks on those re-scan a frame later, and a pooled item that now holds another
-- spell loses our glow. The bars viewer (BuffBarCooldownViewer) shows buff bars, not spells: left out.

P.VIEWERS = { "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer" }
P.hookedViewers = {}

-- The game's alert on a cooldown manager item (ActionButtonSpellAlertManager, forever branch: a child frame
-- `item.SpellActivationAlert` made by ShowAlert, 1.4x the item, round the square icon; with the round / rounded
-- icons of Codex's restyle it doesn't fit). With "Codex's glow instead of the game's" its alpha goes to 0 while our
-- glow shows, and back to 1 after. Only the alpha of that plain frame is set: the manager's own state
-- (activeAlerts, which HasAlert reads) is never written, and the frame is never shown, hidden or moved.
function P.ReplaceGame()
  local db = Q.DB()
  return db[CDM_KEY] and db[GAME_KEY] ~= false and true or false
end

function P.GameAlertAlpha(item, hidden)
  local alert = type(item) == "table" and rawget(item, "SpellActivationAlert")
  if type(alert) == "table" and type(alert.SetAlpha) == "function" then
    if hidden then
      alert.codexHidden = true
      pcall(alert.SetAlpha, alert, 0)
    elseif alert.codexHidden then
      alert.codexHidden = nil
      pcall(alert.SetAlpha, alert, 1)
    end
  end
end

local function HookAlerts()
  local manager = _G.ActionButtonSpellAlertManager
  if P.alertsHooked or type(manager) ~= "table" or type(manager.ShowAlert) ~= "function" then
    return
  end
  P.alertsHooked = true
  hooksecurefunc(manager, "ShowAlert", function(_, button)
    if P.started and P.cdmItems[button] then
      if P.ReplaceGame() then
        P.GameAlertAlpha(button, true) -- at once: no frame of the game's square glow
      end
      P.UpdateSoon()
    end
  end)
  hooksecurefunc(manager, "HideAlert", function(_, button)
    if P.started and P.cdmItems[button] then
      P.UpdateSoon()
    end
  end)
end

-- One Update on the next frame (the game sets its alerts in its own handlers of the overlay events).
function P.UpdateSoon()
  if P.updateQueued then
    return
  end
  P.updateQueued = true
  C_Timer.After(0, function()
    P.updateQueued = false
    P.Update()
  end)
end

function P.HookViewers()
  HookAlerts()
  for _, name in ipairs(P.VIEWERS) do
    local viewer = _G[name]
    if type(viewer) == "table" and not P.hookedViewers[viewer] then
      P.hookedViewers[viewer] = true
      for _, method in ipairs({ "OnAcquireItemFrame", "RefreshLayout", "RefreshData" }) do
        if type(viewer[method]) == "function" then
          hooksecurefunc(viewer, method, function()
            if P.started and Q.DB()[CDM_KEY] then
              P.QueueScan()
            end
          end)
        end
      end
    end
  end
end

-- The viewers' items in use (their pools), each remembered with its icon as the glow's anchor.
function P.CDMItems()
  local list = {}
  for _, name in ipairs(P.VIEWERS) do
    local viewer = _G[name]
    local pool = type(viewer) == "table" and rawget(viewer, "itemFramePool")
    if type(pool) == "table" and type(pool.EnumerateActive) == "function" then
      pcall(function()
        for item in pool:EnumerateActive() do
          list[#list + 1] = item
        end
      end)
    end
  end
  for _, item in ipairs(list) do
    P.cdmItems[item] = true
    local icon = rawget(item, "Icon")
    if type(icon) == "table" and type(icon.GetSize) == "function" then
      P.anchors[item] = icon
    end
  end
  return list
end

-- The spell an item shows (override first), or nil; secret = nil.
function P.ItemSpell(item)
  local id = Num(rawget(item, "cooldownID"))
  local read = C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo
  if not id or type(read) ~= "function" then
    return nil
  end
  local info = Ask(read, id)
  if type(info) ~= "table" then
    return nil
  end
  return Num(info.overrideSpellID) or Num(info.spellID)
end

-- Scans once, on the next frame: Blizzard's buttons take their new action in their own handlers of these events.
function P.QueueScan()
  if P.queued then
    return
  end
  P.queued = true
  C_Timer.After(0, function()
    if P.queued then
      P.Scan()
    end
  end)
end

-- Glow frames ----------------------------------------------------------------------------------------------------

-- (the standalone Tylesser - Proc Glow sets ns.PROC_MEDIA / PROC_CIRCLE / PROC_RING: its files are flat in Media)
local BRAND = ns.PROC_BRAND or "Codex" -- (the standalone: "Proc Glow")
local MEDIA = ns.PROC_MEDIA or ("Interface\\AddOns\\" .. addonName .. "\\Modules\\QoL\\Media\\")
local WHITE = "Interface\\Buttons\\WHITE8X8"
local CIRCLE = ns.PROC_CIRCLE or ("Interface\\AddOns\\" .. addonName .. "\\Media\\Circle")
local RING = ns.PROC_RING or ("Interface\\AddOns\\" .. addonName .. "\\Modules\\Buffs\\Media\\Ring")
P.anchors = setmetatable({}, { __mode = "k" }) -- [frame] = the region a glow on it goes round (cooldown icons)
P.cdmItems = setmetatable({}, { __mode = "k" }) -- [cooldown manager item] = true

-- Styles (the picker's order). "auto" = the game's spell alert, or the pulsing border with Codex's bar restyle.
P.STYLES = {
  { "auto", "Default for your bars" },
  { "alert", "Game's spell alert" },
  { "border", "Pulsing border" },
  { "sparkles", "Marching sparkles" },
  { "soft", "Soft glow" },
  { "flash", "Flash" },
  { "ring", "Ring" },
}
P.COLORS = {
  { "accent", "Theme accent" },
  { "gold", "Gold (the game's)" },
  { "class", "Class colour" },
  { "red", "Red" },
  { "green", "Green" },
  { "blue", "Blue" },
  { "purple", "Purple" },
  { "white", "White" },
}
local FIXED = { gold = { 1, 0.82, 0 }, red = { 1, 0.22, 0.18 }, green = { 0.3, 1, 0.35 }, blue = { 0.3, 0.62, 1 },
  purple = { 0.76, 0.42, 1 }, white = { 1, 1, 1 } }
P.SPEEDS = { { "slow", "Slow" }, { "normal", "Normal" }, { "fast", "Fast" } }
P.SPEED_FACTOR = { slow = 1.7, normal = 1, fast = 0.55 }
P.THICKNESS = { { 1, "Thin" }, { 2, "Medium" }, { 3, "Thick" } }

local function RestyledBars()
  return ns.SkinPartOn and ns.db and ns.db.skins and ns.SkinPartOn("actionbars") and true or false
end

-- Action buttons are square in the four older looks ("Round icons" rounds buffs and cooldowns, not action buttons),
-- so their glows are square. A theme with rounded slots (round.slot: Dusk, Dawn) rounds the restyled action buttons'
-- corners, and the border, ring, sparkles and flash glows follow with rounded corners (key "<style>:round").
function P.Rounded()
  if not RestyledBars() or not (ns.UI and ns.UI.Radius) then
    return nil
  end
  return ns.UI.Radius("slot", ns.InkTheme and ns.InkTheme() or ns.Theme())
end

-- The cooldown manager's icons: round with Codex's cooldown restyle and its "Round icons" part (unlike action
-- buttons, Skins/Cooldowns.lua cuts them to a circle), rounded corners with a rounded theme's slot radius, else square.
function P.CDMShape()
  if not (ns.SkinPartOn and ns.db and ns.db.skins and ns.SkinPartOn("cooldowns")) then
    return ""
  end
  if ns.SkinPartOn("roundicons") then
    return ":circle"
  end
  local radius = ns.UI and ns.UI.Radius and ns.UI.Radius("slot", ns.InkTheme and ns.InkTheme() or ns.Theme())
  return radius and ":round" or ""
end

function P.CDMRadius()
  return ns.UI and ns.UI.Radius and ns.UI.Radius("slot", ns.InkTheme and ns.InkTheme() or ns.Theme()) or 6
end

-- The style in use: the player's pick, else the default for the bars.
function P.Style()
  local pick = Q.DB()[STYLE_KEY]
  if pick and pick ~= "auto" then
    return pick
  end
  return RestyledBars() and "border" or "alert"
end

-- The glow colour { r, g, b }.
function P.Color()
  local pick = Q.DB()[COLOR_KEY] or "accent"
  if FIXED[pick] then
    return FIXED[pick]
  end
  if pick == "class" then
    local class = PlayerClass()
    local color = class and C_ClassColor and C_ClassColor.GetClassColor and Ask(C_ClassColor.GetClassColor, class)
    color = color or (class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
    if type(color) == "table" and Num(color.r) then
      return { color.r, color.g, color.b }
    end
  end
  local theme = ns.InkTheme and ns.InkTheme() or ns.Theme and ns.Theme() or {} -- on the action bars: ink
  return theme.accent or FIXED.gold
end

-- The pulse time of one fade (seconds), from the speed setting.
function P.Pulse()
  return P.PULSE * (P.SPEED_FACTOR[Q.DB()[SPEED_KEY]] or 1)
end

function P.Thickness()
  local value = Num(Q.DB()[THICK_KEY])
  return value and math.max(1, math.min(3, math.floor(value))) or 2
end

local function Additive(texture)
  if texture.SetBlendMode then
    texture:SetBlendMode("ADD")
  end
  return texture
end

local function Tint(textures, color, alpha)
  for _, texture in ipairs(textures or {}) do
    texture:SetVertexColor(color[1], color[2], color[3], alpha or texture.codexAlpha or 1)
  end
end

-- An alpha bounce on the frame (from -> to), kept on frame.fade so its speed can change.
local function Pulse(frame, from, to)
  if type(frame.CreateAnimationGroup) ~= "function" then
    return nil
  end
  local ok, group = pcall(frame.CreateAnimationGroup, frame)
  if not ok or type(group) ~= "table" then
    return nil
  end
  pcall(function()
    group:SetLooping("BOUNCE")
    local fade = group:CreateAnimation("Alpha")
    fade:SetFromAlpha(from)
    fade:SetToAlpha(to)
    fade:SetDuration(P.Pulse())
    if fade.SetSmoothing then
      fade:SetSmoothing("IN_OUT")
    end
    frame.fade = fade
  end)
  frame.pulse = group
  return group
end

local function Level(frame, button, plus)
  local level = Num(button.GetFrameLevel and button:GetFrameLevel())
  if level then
    frame:SetFrameLevel(level + plus)
  end
  if frame.EnableMouse then
    frame:EnableMouse(false)
  end
end

local function Size(button)
  local anchor = P.anchors[button] or button
  local width, height = anchor:GetSize()
  return Num(width) or 36, Num(height) or 36
end

-- A frame of ours on the button: Start / Stop play our pulse; Apply(color, pulse, thickness) repaints.
local function NewGlow(button, style, outset)
  local frame = CreateFrame("Frame", nil, button)
  local anchor = P.anchors[button] or button
  outset = outset or 0
  frame:SetPoint("TOPLEFT", anchor, "TOPLEFT", -outset, outset)
  frame:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", outset, -outset)
  Level(frame, button, 4)
  frame:Hide()
  frame.style, frame.tinted = style, {}
  function frame:Start()
    self:Show()
    if self.pulse and self.pulse.Play then
      self.pulse:Play()
    end
  end
  function frame:Stop()
    if self.pulse and self.pulse.Stop then
      self.pulse:Stop()
    end
    self:Hide()
  end
  function frame:Apply(color, pulse, thickness)
    Tint(self.tinted, color)
    if self.fade and self.fade.SetDuration then
      self.fade:SetDuration(pulse)
    end
    if self.Thicken then
      self:Thicken(thickness)
    end
  end
  return frame
end

-- Square lines `inset` px inside the frame's edge, `size` thick.
local function SquareLines(frame, inset, size, alpha, list)
  local edges = {
    { "TOPLEFT", "TOPRIGHT", false }, { "BOTTOMLEFT", "BOTTOMRIGHT", false },
    { "TOPLEFT", "BOTTOMLEFT", true }, { "TOPRIGHT", "BOTTOMRIGHT", true },
  }
  for _, edge in ipairs(edges) do
    local line = Additive(frame:CreateTexture(nil, "OVERLAY"))
    line:SetTexture(WHITE)
    line.codexAlpha = alpha
    line.edge, line.inset = edge, inset
    line:SetPoint(edge[1], frame, edge[1], edge[1]:find("LEFT") and inset or -inset, edge[1]:find("TOP") and -inset or inset)
    line:SetPoint(edge[2], frame, edge[2], edge[2]:find("LEFT") and inset or -inset, edge[2]:find("TOP") and -inset or inset)
    if edge[3] then
      line:SetWidth(size)
    else
      line:SetHeight(size)
    end
    list[#list + 1] = line
    frame.tinted[#frame.tinted + 1] = line
  end
end

-- Rounded lines (the rounded themes): white pieces of a UI.RoundLine `inset` px inside the frame's edge with a
-- `radius` corner, additive and tinted like the square lines.
local function RoundLines(frame, radius, inset, alpha, list)
  local pieces = ns.UI.RoundLine(frame, frame, math.max(1, radius), { 1, 1, 1, 1 }, { inset = inset, layer = "OVERLAY" })
  for _, piece in ipairs(pieces) do
    Additive(piece)
    piece.codexAlpha = alpha
    list[#list + 1] = piece
    frame.tinted[#frame.tinted + 1] = piece
  end
  return pieces
end

-- Thickness for rounded lines: 1-3 rounded lines side by side (a quarter can't grow thicker), shown up to `size`.
local function ShowSets(sets, size)
  for index, set in ipairs(sets) do
    for _, piece in ipairs(set) do
      piece:SetShown(index <= size)
    end
  end
end

local function Resize(lines, size)
  for _, line in ipairs(lines) do
    if line.edge[3] then
      line:SetWidth(size)
    else
      line:SetHeight(size)
    end
  end
end

-- "Pulsing border": a bright line just outside the icon (thickness 1-3 px) and a soft one round it.
local function BorderGlow(button, radius)
  if radius then
    -- rounded: a soft line round the outside (radius + 3) and the bright one in 1-3 rounded lines inside it
    local frame = NewGlow(button, "border", 3)
    frame.outer, frame.inner, frame.round = {}, {}, radius
    RoundLines(frame, radius + 3, 0, 0.45, frame.outer)
    frame.sets = {}
    for index = 1, 3 do
      frame.sets[index] = RoundLines(frame, radius + 3 - index, index, 1, frame.inner)
    end
    function frame:Thicken(thickness)
      ShowSets(self.sets, thickness)
      self.thickness = thickness
    end
    Pulse(frame, 1, 0.35)
    return frame
  end
  local frame = NewGlow(button, "border", 3)
  frame.outer, frame.inner = {}, {}
  SquareLines(frame, 0, 1, 0.45, frame.outer)
  SquareLines(frame, 1, 2, 1, frame.inner)
  function frame:Thicken(thickness)
    Resize(self.inner, thickness)
    self.thickness = thickness
  end
  Pulse(frame, 1, 0.35)
  return frame
end

-- "Ring": two square lines a little way out from the icon (a double ring, as square as the buttons), pulsing.
local function RingGlow(button, radius)
  if radius then
    -- rounded: the near and far lines 2 and 5 px out, each 1-3 rounded lines thick (growing inwards)
    local frame = NewGlow(button, "ring", 0)
    frame.near, frame.far, frame.round = {}, {}, radius
    frame.nearSets, frame.farSets = {}, {}
    for index = 1, 3 do
      frame.nearSets[index] = RoundLines(frame, radius + 3 - index, index - 3, 1, frame.near)
      frame.farSets[index] = RoundLines(frame, radius + 6 - index, index - 6, 0.8, frame.far)
    end
    function frame:Thicken(thickness)
      ShowSets(self.nearSets, thickness)
      ShowSets(self.farSets, thickness)
      self.thickness = thickness
    end
    Pulse(frame, 1, 0.3)
    return frame
  end
  local frame = NewGlow(button, "ring", 0)
  frame.near, frame.far = {}, {}
  SquareLines(frame, -2, 1, 1, frame.near)
  SquareLines(frame, -5, 1, 0.8, frame.far)
  function frame:Thicken(thickness)
    Resize(self.near, thickness)
    Resize(self.far, thickness)
    self.thickness = thickness
  end
  Pulse(frame, 1, 0.3)
  return frame
end

-- "Soft glow": a blurred halo round the icon (clear over the icon itself), breathing.
local function SoftGlow(button)
  local frame = NewGlow(button, "soft", 0)
  local width, height = Size(button)
  frame.halo = Additive(frame:CreateTexture(nil, "OVERLAY"))
  frame.halo:SetTexture(MEDIA .. "GlowSquare")
  frame.halo:SetSize(width * 2, height * 2)
  frame.halo:SetPoint("CENTER", frame, "CENTER", 0, 0)
  frame.tinted[1] = frame.halo
  Pulse(frame, 1, 0.45)
  return frame
end

-- "Flash": the icon brightens and dims (a tinted additive layer over it).
local function FlashGlow(button, radius)
  local frame = NewGlow(button, "flash", 0)
  frame.flash = Additive(frame:CreateTexture(nil, "OVERLAY"))
  frame.flash:SetTexture(WHITE)
  frame.flash:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
  frame.flash:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
  frame.flash.codexAlpha = 0.55
  frame.tinted[1] = frame.flash
  if radius then
    -- rounded: the layer cut to the icon's corners
    frame.round = radius
    frame.mask = ns.UI.RoundMask(frame, frame.flash, math.max(2, radius - 2), { frame.flash })
  end
  Pulse(frame, 0.05, 1)
  return frame
end

-- "Marching sparkles" with our own dots (the game's art missing): 8 soft dots running round the edge, on an OnUpdate
-- that only runs while the frame is shown.
local DOTS = 8

-- A point `d` along the edge of a w x h rectangle with corners of radius r, from the top edge's left end (after the
-- top-left corner) clockwise; x, y from the centre.
local function RoundedPoint(d, width, height, r)
  local sw, sh, arc = width - 2 * r, height - 2 * r, math.pi * r / 2
  local hw, hh = width / 2, height / 2
  local function Arc(cx, cy, from, t)
    local angle = from - (t / arc) * (math.pi / 2)
    return cx + r * math.cos(angle), cy + r * math.sin(angle)
  end
  if d < sw then
    return -hw + r + d, hh
  end
  d = d - sw
  if d < arc then
    return Arc(hw - r, hh - r, math.pi / 2, d)
  end
  d = d - arc
  if d < sh then
    return hw, hh - r - d
  end
  d = d - sh
  if d < arc then
    return Arc(hw - r, -hh + r, 0, d)
  end
  d = d - arc
  if d < sw then
    return hw - r - d, -hh
  end
  d = d - sw
  if d < arc then
    return Arc(-hw + r, -hh + r, -math.pi / 2, d)
  end
  d = d - arc
  if d < sh then
    return -hw, -hh + r + d
  end
  d = d - sh
  return Arc(-hw + r, hh - r, math.pi, math.min(d, arc))
end
P.RoundedPoint = RoundedPoint

local function DotGlow(button, radius)
  local frame = NewGlow(button, "sparkles", 2)
  frame.round = radius and radius + 2 or nil -- the frame sits 2 px outside the button
  frame.dots = {}
  for index = 1, DOTS do
    local dot = Additive(frame:CreateTexture(nil, "OVERLAY"))
    dot:SetTexture(MEDIA .. "GlowDot")
    dot:SetSize(9, 9)
    frame.dots[index] = dot
    frame.tinted[index] = dot
  end
  frame.phase = 0
  local function Place(self)
    local width, height = self:GetSize()
    width, height = Num(width) or 40, Num(height) or 40
    local r = self.round and math.min(self.round, width / 2, height / 2)
    local perimeter = r and (2 * (width - 2 * r) + 2 * (height - 2 * r) + 2 * math.pi * r)
    for index, dot in ipairs(self.dots) do
      local t = (self.phase + (index - 1) / DOTS) % 1
      local x, y
      local d = t * 2 * (width + height)
      if r then
        x, y = RoundedPoint(t * perimeter, width, height, r)
      elseif d < width then
        x, y = d - width / 2, height / 2
      elseif d < width + height then
        x, y = width / 2, height / 2 - (d - width)
      elseif d < 2 * width + height then
        x, y = width / 2 - (d - width - height), -height / 2
      else
        x, y = -width / 2, -height / 2 + (d - 2 * width - height)
      end
      dot:ClearAllPoints()
      dot:SetPoint("CENTER", self, "CENTER", x, y)
    end
  end
  frame.Place = Place
  frame:SetScript("OnUpdate", function(self, elapsed)
    self.phase = (self.phase + (Num(elapsed) or 0) / (self.period or 2)) % 1
    Place(self)
  end)
  local apply = frame.Apply
  function frame:Apply(color, pulse, thickness)
    apply(self, color, pulse, thickness)
    self.period = 4 * pulse -- one lap: 2 s at normal speed
  end
  Place(frame)
  return frame
end

-- "Marching sparkles" with the game's own art (AutoCastOverlayTemplate, the pet autocast ants; Forever has it in
-- Blizzard_UIPanelTemplates): square icons only. Its rotation's duration follows the speed.
local function AutoCastGlow(button)
  local ok, frame = pcall(CreateFrame, "Frame", nil, button, "AutoCastOverlayTemplate")
  if not ok or type(frame) ~= "table" or type(frame.Shine) ~= "table" or type(frame.ShowAutoCastEnabled) ~= "function" then
    if ok and type(frame) == "table" and frame.Hide then
      frame:Hide()
    end
    return nil
  end
  frame:ClearAllPoints()
  frame:SetAllPoints(P.anchors[button] or button)
  Level(frame, button, 4)
  frame:Hide()
  frame.style, frame.tinted, frame.blizzard = "sparkles", { frame.Shine, frame.Corners }, true
  function frame:Start()
    self:Show()
    pcall(self.ShowAutoCastEnabled, self, true)
  end
  function frame:Stop()
    pcall(self.ShowAutoCastEnabled, self, false)
    self:Hide()
  end
  function frame:Apply(color, pulse)
    Tint(self.tinted, color)
    local anim = self.Shine.Anim
    if type(anim) == "table" and type(anim.GetAnimations) == "function" then
      for _, part in ipairs({ anim:GetAnimations() }) do
        if part.SetDuration then
          part:SetDuration(8 * pulse) -- the game's 4 s turn at normal speed
        end
      end
    end
    self.lap = 8 * pulse
  end
  return frame
end

-- "Game's spell alert": Blizzard's ActionButtonSpellAlertTemplate on a frame of ours (its own animations; colour
-- and speed don't apply). Square icons only.
local function AlertGlow(button)
  local ok, frame = pcall(CreateFrame, "Frame", nil, button, "ActionButtonSpellAlertTemplate")
  if not ok or type(frame) ~= "table" or type(frame.ProcStartAnim) ~= "table" then
    if ok and type(frame) == "table" and frame.Hide then
      frame:Hide()
    end
    return nil
  end
  local width, height = Size(button)
  frame:SetSize(width * 1.4, height * 1.4)
  frame:SetPoint("CENTER", P.anchors[button] or button, "CENTER", 0, 0)
  frame:Hide()
  frame.style, frame.blizzard = "alert", true
  function frame:Start()
    self:Show()
    if self.ProcStartAnim.Play then
      self.ProcStartAnim:Play()
    end
  end
  function frame:Stop()
    if self.ProcStartAnim.Stop then
      self.ProcStartAnim:Stop()
    end
    if self.ProcLoop and self.ProcLoop.Stop then
      self.ProcLoop:Stop()
    end
    self:Hide()
  end
  function frame:Apply() end
  return frame
end

-- Round icons (the cooldown manager with "Round icons"): circle variants of the styles.
local function CircleBorder(button)
  local frame = NewGlow(button, "border", 3)
  frame.circle = true
  frame.ring = Additive(frame:CreateTexture(nil, "OVERLAY"))
  frame.ring:SetAllPoints(frame)
  frame.tinted[1] = frame.ring
  function frame:Thicken(thickness)
    self.ring:SetTexture(MEDIA .. "GlowRing" .. thickness)
    self.thickness = thickness
  end
  Pulse(frame, 1, 0.35)
  return frame
end

-- Buff Tracker's double ring round the icon; thicker = 1-3 rings, 3 px apart.
local function CircleRing(button)
  local frame = NewGlow(button, "ring", 0)
  frame.circle, frame.rings = true, {}
  local width = Size(button)
  for index = 1, 3 do
    local ring = Additive(frame:CreateTexture(nil, "OVERLAY"))
    ring:SetTexture(RING)
    local size = width * 1.2 + (index - 1) * 3
    ring:SetSize(size, size)
    ring:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.rings[index] = ring
    frame.tinted[index] = ring
  end
  function frame:Thicken(thickness)
    for index, ring in ipairs(self.rings) do
      ring:SetShown(index <= thickness)
    end
    self.thickness = thickness
  end
  Pulse(frame, 1, 0.3)
  return frame
end

local function CircleSoft(button)
  local frame = SoftGlow(button)
  frame.circle = true
  frame.halo:SetTexture(MEDIA .. "GlowRound")
  return frame
end

local function CircleFlash(button)
  local frame = FlashGlow(button)
  frame.circle = true
  frame.flash:SetTexture(CIRCLE)
  return frame
end

local CIRCLE_BUILD = { border = CircleBorder, ring = CircleRing, soft = CircleSoft, flash = CircleFlash }

local BUILD = { border = BorderGlow, ring = RingGlow, soft = SoftGlow, flash = FlashGlow }

-- A glow frame of the given style for any button-like frame (an action button or the page's preview). Falls back:
-- the game's alert without its template -> the pulsing border; sparkles without the game's art -> our dots. A key
-- ending in ":round" (P.Wanted on a rounded theme) builds the rounded variant: sparkles are then always our dots
-- (the game's ants run round a square), the alert and the soft halo stay as they are.
-- ":circle" (round cooldown icons) builds the circle variants: the alert falls back to the round border there, the
-- sparkles run round a circle.
function P.MakeGlow(button, key)
  key = key or ""
  local style = key:gsub(":%a+$", "")
  local frame
  if key:find(":circle$") then
    if style == "sparkles" then
      frame = DotGlow(button, 1000) -- a corner radius of half the size: a circle
      frame.circle = true
    else
      frame = (CIRCLE_BUILD[style] or CircleBorder)(button)
    end
    frame.key = key
    frame:Apply(P.Color(), P.Pulse(), P.Thickness())
    return frame
  end
  local radius
  if key:find(":round$") then
    radius = P.cdmItems[button] and P.CDMRadius() or (P.Rounded() or 6)
  end
  if style == "alert" then
    frame = AlertGlow(button)
  elseif style == "sparkles" then
    frame = not radius and AutoCastGlow(button) or DotGlow(button, radius)
  elseif BUILD[style] then
    frame = BUILD[style](button, radius)
  end
  frame = frame or BorderGlow(button, radius)
  frame.key = key
  frame:Apply(P.Color(), P.Pulse(), P.Thickness())
  return frame
end

-- The glow key in use: the style, with ":round" while the restyled action buttons have rounded corners.
local function Wanted(target)
  if target and P.cdmItems[target] then
    return P.Style() .. P.CDMShape()
  end
  return P.Style() .. (P.Rounded() and ":round" or "")
end
P.Wanted = Wanted

-- Our glow frame for a button, in the current style (made again when the style or shape changed).
function P.Glow(button)
  local key = Wanted(button)
  local glow = P.glows[button]
  if glow and glow.wanted == key then
    return glow
  end
  local lit = glow and glow.lit
  if glow then
    glow.lit = false
    glow:Stop()
  end
  local ok, made = pcall(P.MakeGlow, button, key)
  if not ok then
    return nil
  end
  made.wanted = key
  P.glows[button] = made
  if lit then
    made.lit = true
    made:Start()
  end
  return made
end

local function SetGlow(button, on)
  local glow = on and P.Glow(button) or P.glows[button]
  if not glow then
    return
  end
  if on and not glow.lit then
    glow.lit = true
    glow:Start()
  elseif not on and glow.lit then
    glow.lit = false
    glow:Stop()
  end
end

-- After a style / colour / speed / thickness change: every glow (and the page's preview) at once.
function P.Repaint()
  for button, glow in pairs(P.glows) do
    if glow.wanted ~= Wanted(button) then
      if glow.lit then
        P.Glow(button)
      end
    else
      glow:Apply(P.Color(), P.Pulse(), P.Thickness())
    end
  end
  if P.preview then
    P.ShowPreview()
  end
end

-- The page's preview: a still icon of ours with the chosen glow always on.
function P.BuildPreview(parent)
  local box = CreateFrame("Frame", nil, parent)
  box:SetSize(36, 36)
  box.icon = box:CreateTexture(nil, "ARTWORK")
  box.icon:SetAllPoints(box)
  box.icon:SetTexture("Interface\\Icons\\Ability_MeleeDamage")
  if box.icon.SetTexCoord then
    box.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  end
  local radius = P.Rounded()
  if radius then
    box.mask = ns.UI.RoundMask(box, box.icon, radius, { box.icon }) -- as the rounded action buttons
  end
  P.preview = box
  P.ShowPreview()
  return box
end

function P.ShowPreview()
  local box = P.preview
  if not box then
    return
  end
  local key = Wanted()
  if box.glow and box.glow.key ~= key then
    box.glow:Stop()
    box.glow = nil
  end
  if not box.glow then
    local ok, made = pcall(P.MakeGlow, box, key)
    box.glow = ok and made or nil
  else
    box.glow:Apply(P.Color(), P.Pulse(), P.Thickness())
  end
  if box.glow then
    box.glow:Start()
  end
end

-- Signals --------------------------------------------------------------------------------------------------------

-- The player's buffs that make a listed spell glow: [aura] = true (with enough stacks where the entry asks for them),
-- and active.names[lower name] = true for every buff (notActive entries skip a spell whose buff is on you). Secret
-- buffs are skipped.
function P.ActiveAuras()
  local active = { names = {} }
  local read = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
  if type(read) ~= "function" then
    return active
  end
  P.Lookup()
  for index = 1, 40 do
    local ok, aura = pcall(read, "player", index, "HELPFUL")
    if not ok or type(aura) ~= "table" then
      break
    end
    local id, name = Num(aura.spellId), Str(aura.name)
    if name then
      active.names[Lower(name)] = true
      P.NoteSeal(name)
    end
    local match = (id and P.auraIDs[id]) or (name and P.auraNames[Lower(name)])
    if match and id and match.notIDs and match.notIDs[id] then
      match = nil -- a talent's own passive with the proc's name
    end
    if match and match.stacks then
      local count = aura.applications
      if count ~= nil and not Readable(count) then
        if not match.secretStacks or not P.StacksReached(match) then
          match = nil -- hidden, and this proc can't do without it (or the counted stacks aren't there yet)
        end
      else
        P.SeenStacks(match, Num(count) or 0)
        if (Num(count) or 0) < match.stacks then
          match = nil
        end
      end
    end
    if match then
      active[match] = true
    end
  end
  P.ViewerAuras(active)
  return active
end

-- In a fight the game hides most of your buffs' spell IDs, names and stack counts (secret values; the by-ID lookup
-- GetPlayerAuraBySpellID is RequiresNonSecretAura), so Echo of Command looked missing in combat (the user's report,
-- 2026-11-20). The cooldown manager's buff rows (BuffIconCooldownViewer, BuffBarCooldownViewer, forever branch
-- Blizzard_CooldownViewer) know their spell from their settings (C_CooldownViewer.GetCooldownViewerCooldownInfo:
-- spellID, overrideSpellID, linkedSpellIDs, readable) and keep a plain `isActive`: an active item of a listed buff
-- counts, with its stack count when the game lets us read it, else as reached (secretStacks). Read only. An item
-- linked to several listed buffs counts only when its own aura's spell is readable (nothing is guessed).
P.BUFF_VIEWERS = { "BuffIconCooldownViewer", "BuffBarCooldownViewer" }

local function ViewerMatch(item)
  local own = Num(rawget(item, "auraSpellID"))
  if own and P.auraIDs[own] then
    return P.auraIDs[own]
  end
  local info = C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo
    and Ask(C_CooldownViewer.GetCooldownViewerCooldownInfo, rawget(item, "cooldownID"))
  if type(info) ~= "table" then
    return nil
  end
  local found, several
  local ids = { info.overrideSpellID, info.spellID }
  for _, id in ipairs(type(info.linkedSpellIDs) == "table" and info.linkedSpellIDs or {}) do
    ids[#ids + 1] = id
  end
  for index = 1, 2 + (type(info.linkedSpellIDs) == "table" and #info.linkedSpellIDs or 0) do
    local id = Num(ids[index])
    local match = id and P.auraIDs[id]
    if match and found and found ~= match then
      several = true
    elseif match then
      found = match
    end
  end
  if several then
    -- one item for several listed buffs: Forever's "Unsealed Wrath" item is linked to every Echo of <seal> (the
    -- user's /codex procglow, 2026-11-21). Its own aura can't be read in a fight; the echo is the one of your seal
    -- (P.lastSeal: the seal buff read while it can be, or the seal you cast). Unknown seal: nothing is guessed.
    local seal = P.lastSeal and P.echoBySeal[P.lastSeal]
    return seal and P.ItemLinks(info, seal) and seal or nil
  end
  return found
end

-- Does this item's info list the aura entry's spell?
function P.ItemLinks(info, match)
  local ids = { info.overrideSpellID, info.spellID }
  for _, id in ipairs(type(info.linkedSpellIDs) == "table" and info.linkedSpellIDs or {}) do
    ids[#ids + 1] = id
  end
  for index = 1, 2 + (type(info.linkedSpellIDs) == "table" and #info.linkedSpellIDs or 0) do
    local id = Num(ids[index])
    if id and P.auraIDs[id] == match then
      return true
    end
  end
  return false
end

-- Seal name -> its echo's aura entry; P.lastSeal = the seal you have on, as far as can be told.
P.echoBySeal = {}
for _, aura in ipairs(P.AURAS) do
  if aura.seal then
    P.echoBySeal[aura.seal] = aura
  end
end

local SEAL_NAMES = {}
for _, name in ipairs(P.SEALS) do
  SEAL_NAMES[name] = true
end

function P.NoteSeal(name)
  if type(name) == "string" and SEAL_NAMES[name] then
    P.lastSeal = name -- a seal without an echo (the Crusader) clears it: P.echoBySeal has none
  end
end

-- Stack counts in a fight (the user's question, 2026-11-21: "can we use this for in-combat Echo"): the count is a
-- secret then, but the cooldown manager is told about each change of the buff it shows, and only of that buff:
-- its UNIT_AURA handler finds the item by the aura's own instance (forever Blizzard_CooldownViewer
-- CooldownViewerMixin:OnUnitAura) and calls the item's OnUnitAuraUpdatedEvent for an update (a stack gained, or the
-- buff refreshed) and OnUnitAuraRemovedEvent when it goes. Post hooks on those two count without reading anything
-- hidden: a new buff = 1, each update +1 (up to the entry's `stacks`), removed or not active = 0, and a readable
-- count (outside a fight) always replaces the guess. A pasted idea counted every UNIT_AURA of the player in a fight,
-- which also counts every other buff and debuff. Entries without hooks (no such method on the item) keep the old
-- rule: active = reached.
P.stackGuess = {} -- [aura entry] = { count, at, hooked }
P.hookedItems = {}

local function Guess(match)
  local guess = P.stackGuess[match]
  if not guess then
    guess = { count = 0 }
    P.stackGuess[match] = guess
  end
  return guess
end

-- A hidden count: reached when counted that far, or always when nothing counts it (no hooks: the old rule).
function P.StacksReached(match)
  local guess = P.stackGuess[match]
  return not (guess and guess.hooked) or guess.count >= (match.stacks or 0)
end

function P.SeenStacks(match, count)
  Guess(match).count = count
end

local function CountedMatch(item)
  local match = ViewerMatch(item)
  if match and match.stacks and match.secretStacks then
    return match
  end
end

local function OnItemAuraUpdated(item)
  local match = P.started and CountedMatch(item)
  if not match then
    return
  end
  local guess = Guess(match)
  local now = GetTime()
  if guess.at == now then
    return -- the same change seen by a second item (an icon and a bar of the same buff)
  end
  guess.at = now
  guess.count = math.min(match.stacks, math.max(guess.count, 1) + 1)
  P.UpdateSoon()
end

local function OnItemAuraRemoved(item)
  local match = P.started and CountedMatch(item)
  if match then
    Guess(match).count = 0
    if match.seal then
      for _, echo in pairs(P.echoBySeal) do
        Guess(echo).count = 0 -- one item for every echo: whichever was on is gone
      end
    end
    P.UpdateSoon()
  end
end

function P.HookStacks(item, match)
  if P.hookedItems[item] then
    Guess(match).hooked = true
    return
  end
  if type(item.OnUnitAuraUpdatedEvent) == "function" and type(item.OnUnitAuraRemovedEvent) == "function" then
    P.hookedItems[item] = true
    hooksecurefunc(item, "OnUnitAuraUpdatedEvent", OnItemAuraUpdated)
    hooksecurefunc(item, "OnUnitAuraRemovedEvent", OnItemAuraRemoved)
    Guess(match).hooked = true
  end
end

function P.ViewerAuras(active)
  for _, name in ipairs(P.BUFF_VIEWERS) do
    local viewer = _G[name]
    local pool = type(viewer) == "table" and rawget(viewer, "itemFramePool")
    if type(pool) == "table" and type(pool.EnumerateActive) == "function" then
      pcall(function()
        for item in pool:EnumerateActive() do
          local on = rawget(item, "isActive")
          local match = Readable(on) and ViewerMatch(item)
          if match and match.stacks and match.secretStacks then
            P.HookStacks(item, match)
          end
          if match and on == true and not active[match] then
            local cached = rawget(item, "auraDataCached")
            local count = type(cached) == "table" and cached.applications or nil
            if match.stacks and Readable(count) then
              P.SeenStacks(match, Num(count) or 0)
              if (Num(count) or 0) >= match.stacks then
                active[match] = true
              end
            elseif not match.stacks then
              active[match] = true
            elseif match.secretStacks then
              local guess = Guess(match)
              if guess.count < 1 then
                guess.count = 1 -- it is on: at least one
              end
              if not guess.hooked or guess.count >= match.stacks then
                active[match] = true
              end
            end
          elseif match and on == false and match.secretStacks then
            Guess(match).count = 0
          end
        end
      end)
    end
  end
end

-- The game already lights this button (its own spell alert): leave it to the game.
function P.GameGlows(item)
  local overlay = C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed
  if Bool(Ask(overlay, item.id)) then
    return true
  end
  local manager = _G.ActionButtonSpellAlertManager
  if type(manager) == "table" and type(manager.HasAlert) == "function" then
    if Bool(Ask(manager.HasAlert, manager, item.button)) then
      return true
    end
  end
  return false
end

-- Whether a reactive ability's slot is usable now; secret = no.
function P.Usable(slot, id)
  local usable
  if C_ActionBar and C_ActionBar.IsUsableAction then
    usable = Bool(Ask(C_ActionBar.IsUsableAction, slot))
  elseif IsUsableAction then
    usable = Bool(Ask(IsUsableAction, slot))
  end
  if usable == nil and C_Spell and C_Spell.IsSpellUsable then
    usable = Bool(Ask(C_Spell.IsSpellUsable, id))
  end
  return usable == true
end

-- Can the spell be cast right now? Not while it lacks mana (rage, energy) or is otherwise unusable, nor while its
-- own cooldown runs (the user's request, 2026-11-20: the proc art only when the proc can be used). The global
-- cooldown doesn't count (2026-11-23: Heating Up's art blinked out after every Fireball): a cooldown the game says is
-- the global one (activeCategory = Constants.SpellCooldownConsts.GLOBAL_RECOVERY_CATEGORY, or isOnGCD, as
-- Blizzard_CooldownViewer reads them), or one of 1.5 s or less, keeps it lit. Returns castable, and when a cooldown
-- is what stops it, the time it ends. Secret or missing values count as castable (the art shows as before).
P.GCD_MAX = 1.5
function P.OnGCD(cooldown, duration)
  local consts = Constants and Constants.SpellCooldownConsts
  local category = Num(cooldown.activeCategory)
  if category and consts and category == consts.GLOBAL_RECOVERY_CATEGORY then
    return true
  end
  if cooldown.isOnGCD == true then
    return true
  end
  return duration <= P.GCD_MAX
end

function P.Castable(id)
  if not id then
    return true
  end
  if C_Spell and C_Spell.IsSpellUsable then
    local ok, usable, noMana = pcall(C_Spell.IsSpellUsable, id)
    if ok then
      if Readable(noMana) and noMana == true then
        return false
      end
      if Readable(usable) and usable == false then
        return false
      end
    end
  end
  local cooldown = C_Spell and C_Spell.GetSpellCooldown and Ask(C_Spell.GetSpellCooldown, id)
  if type(cooldown) == "table" then
    local start, duration = Num(cooldown.startTime), Num(cooldown.duration)
    if start and duration and start > 0 and duration > 0 and not P.OnGCD(cooldown, duration) then
      local ends = start + duration
      if ends - GetTime() > 0.05 then
        return false, ends
      end
    end
  end
  return true
end

-- A buff proc's spells you know (by name, the client's spell ID): castable now? (notActive: not the one whose own
-- buff is on you.) Returns castable, and the earliest cooldown end when cooldowns are what stop them.
function P.AuraCastable(aura, auras)
  local wake
  for _, name in ipairs(aura.spells or {}) do
    if not (aura.notActive and auras.names and auras.names[Lower(name)]) then
      local info = C_Spell and C_Spell.GetSpellInfo and Ask(C_Spell.GetSpellInfo, name)
      local id = type(info) == "table" and Num(info.spellID)
      if id then
        local can, ends = P.Castable(id)
        if can then
          return true
        end
        if ends and (not wake or ends < wake) then
          wake = ends
        end
      end
    end
  end
  return false, wake
end

-- Lit or not, and the proc's name (the ability, or the buff that lit it: the per-ability sound's key).
function P.Lit(item, auras)
  local entry = item.entry
  if P.GameGlows(item) then
    -- the game lights it: on the cooldown manager our glow takes its place (its alert is hidden), else the game's
    if item.cdm and P.ReplaceGame() then
      return true, entry.key
    end
    return false
  end
  if entry.game then
    return false
  end
  if entry.reactive then
    if not item.slot then
      local usable = C_Spell and C_Spell.IsSpellUsable and Bool(Ask(C_Spell.IsSpellUsable, item.id))
      return usable == true, entry.key
    end
    return P.Usable(item.slot, item.id), entry.key
  end
  for _, aura in ipairs(entry.auras or {}) do
    if auras[aura] then
      local own = aura.notActive and auras.names and Lower(SpellName(item.id) or entry.key)
      if not (own and auras.names[own]) then
        return true, aura.name, aura.artOnly
      end
    end
  end
  return false
end

P.litKeys = {}
function P.Update()
  if not P.started then
    return
  end
  local auras = P.ActiveAuras()
  local lit, shown, order = {}, {}, {}
  local ready, artOrder, wake = {}, {}, nil
  for _, item in ipairs(P.watch) do
    local ok, on, key, artOnly = pcall(P.Lit, item, auras)
    if ok and on then
      if not artOnly then
        shown[item.button] = true -- (an art-only proc lights no button: Clearcasting)
      end
      key = key or item.entry.key
      if not lit[key] then
        lit[key] = true
        order[#order + 1] = key
      end
      -- the art: only for a proc one of whose lit spells can be cast now
      if not ready[key] then
        local can, ends = P.Castable(item.id)
        if can then
          ready[key] = true
        elseif ends and (not wake or ends < wake) then
          wake = ends
        end
      end
    end
  end
  for _, key in ipairs(order) do
    if ready[key] then
      artOrder[#artOrder + 1] = key
    end
  end
  -- a buff proc shows its art from the buff itself, also with none of its spells on your bars (Echo of Fury at 3
  -- stacks with no other seal on a bar showed nothing, 2026-11-20): when one of its spells is known and castable
  for aura in pairs(auras) do
    if type(aura) == "table" and aura.spells and not ready[aura.name] then
      local can, ends = P.AuraCastable(aura, auras)
      if can then
        ready[aura.name] = true
        artOrder[#artOrder + 1] = aura.name
      elseif ends and (not wake or ends < wake) then
        wake = ends
      end
    end
  end
  P.WakeAt(wake)
  for button in pairs(P.glows) do
    if not shown[button] then
      SetGlow(button, false)
    end
  end
  for button in pairs(shown) do
    SetGlow(button, true)
  end
  -- the game's alert is see-through only while it is up and our glow shows in its place
  local replace, hide = P.ReplaceGame(), {}
  for _, item in ipairs(P.watch) do
    if replace and item.cdm and shown[item.button] and P.glows[item.button] and P.glows[item.button].lit
      and P.GameGlows(item) then
      hide[item.button] = true
    end
  end
  for item in pairs(P.cdmItems) do
    P.GameAlertAlpha(item, hide[item] == true)
  end
  local started
  for _, key in ipairs(order) do
    if not P.litKeys[key] then
      started = started or key
    end
  end
  P.litKeys = lit
  if started then
    P.ProcSound(started)
  end
  if P.art then
    P.art.Update(artOrder) -- the art beside your character (ProcArt.lua): castable procs only
  end
end

-- One check again when the first cooldown keeping a proc's art away ends (SPELL_UPDATE_COOLDOWN does not always
-- come at the end of the global cooldown).
function P.WakeAt(ends)
  if not ends then
    return
  end
  if P.wakeAt and P.wakeAt <= ends + 0.01 and P.wakeAt > GetTime() then
    return -- an earlier or equal check is already waiting
  end
  P.wakeAt = ends
  C_Timer.After(math.max(0.05, ends - GetTime() + 0.02), function()
    if P.wakeAt == ends then
      P.wakeAt = nil
      if P.started then
        P.Update()
      end
    end
  end)
end

-- Sound ----------------------------------------------------------------------------------------------------------

-- Which of our sounds was made for which proc (lower-case proc name); a proc not listed (one the game lights, such
-- as Blade of Justice) gets its class's.
P.PROC_SOUNDS = {
  ["overpower"] = "sword_clash", ["revenge"] = "shield_bash", ["execute"] = "axe_chop", ["victory rush"] = "victory",
  ["riposte"] = "parry", ["counterattack"] = "parry", ["mongoose bite"] = "beast_snap",
  ["hammer of wrath"] = "holy_hammer", ["blade of justice"] = "holy_hammer", ["art of war"] = "holy_hammer",
  ["unsealed wrath"] = "holy_echo", ["shadow trance"] = "shadow", ["nightfall"] = "shadow",
  ["missile barrage"] = "missiles", ["heating up"] = "fire", ["hot streak"] = "fire", ["pyroblast"] = "fire",
}
P.CLEARCASTING_SOUNDS = { MAGE = "arcane", DRUID = "nature", SHAMAN = "lightning" }
P.CLASS_SOUNDS = { WARRIOR = "sword_clash", ROGUE = "parry", HUNTER = "beast_snap", PALADIN = "holy_echo",
  PRIEST = "holy_echo", WARLOCK = "shadow", MAGE = "arcane", DRUID = "nature", SHAMAN = "lightning",
  DEATHKNIGHT = "sword_clash" }

-- The sound made for a proc (its name; nil = the class's).
function P.MatchSound(key)
  local name = Lower(key)
  local class = PlayerClass() or ""
  if name and name:find("^echo of ") then
    return "holy_echo"
  end
  if name == "clearcasting" then
    return P.CLEARCASTING_SOUNDS[class] or "arcane"
  end
  return (name and P.PROC_SOUNDS[name]) or P.CLASS_SOUNDS[class] or "arcane"
end

-- A picked sound for a proc: "match" becomes the proc's own.
function P.ResolveSound(choice, key)
  if choice == "match" then
    return P.MatchSound(key)
  end
  return choice
end

-- Codex's own sound files (the standalone: its flat Media folder).
P.SOUND_DIR = MEDIA .. "Sounds\\"

-- A choice's sound: the SOUNDKIT ID of one of the game's, or the path of one of ours (second return true).
local function SoundKit(choice)
  for _, sound in ipairs(P.SOUNDS) do
    if sound[1] == choice then
      if sound.file then
        return P.SOUND_DIR .. sound.file .. ".ogg", true
      end
      if not sound[3] then
        return nil
      end
      local kit = type(SOUNDKIT) == "table" and Num(SOUNDKIT[sound[3]])
      return kit or sound[4]
    end
  end
  return nil
end
P.SoundKit = SoundKit

-- The sound a proc plays: its own pick (with "Choose a sound per ability" on), else the main one.
function P.SoundFor(key)
  local db = Q.DB()
  local own = db[EACH_KEY] and key and type(db[FOR_KEY]) == "table" and db[FOR_KEY][key]
  if own and own ~= "same" then
    return P.ResolveSound(own, key)
  end
  return P.ResolveSound(db[KIT_KEY], key)
end

-- Plays a sound once (choice: a P.SOUNDS key, default the main one). True when a sound was played.
function P.Play(choice)
  local db = Q.DB()
  local kit, file = SoundKit(P.ResolveSound(choice or db[KIT_KEY]))
  local channel = db[MASTER_KEY] and "Master" or "SFX"
  if file then
    if type(PlaySoundFile) ~= "function" then
      return false
    end
    local ok = pcall(PlaySoundFile, kit, channel)
    return ok
  end
  if not kit or type(PlaySound) ~= "function" then
    return false
  end
  local ok = pcall(PlaySound, kit, channel)
  return ok
end

local function InCombat()
  if InCombatLockdown() then
    return true
  end
  return UnitAffectingCombat and Bool(Ask(UnitAffectingCombat, "player")) or false
end

-- A proc started (key: its name): the sound, when wanted, at most once per P.SOUND_GAP seconds across all procs.
function P.ProcSound(key)
  local db = Q.DB()
  if not db[SOUND_KEY] then
    return false
  end
  if db[COMBAT_KEY] and not InCombat() then
    return false
  end
  local now = GetTime()
  if P.lastSound and now - P.lastSound < P.SOUND_GAP then
    return false
  end
  if P.Play(P.SoundFor(key)) then
    P.lastSound = now
    return true
  end
  return false
end

-- Start / stop ---------------------------------------------------------------------------------------------------

local function OnEvent(_, event, unit, ...)
  if P.art then
    P.art.OnEvent(event, unit) -- the spells the game lights (unit = their spell ID)
  end
  if event == "UNIT_AURA" then
    if unit == "player" then
      P.Update()
      P.UpdateSoon() -- again after the cooldown manager's own UNIT_AURA handler has set its items (P.ViewerAuras)
    end
  elseif event == "UNIT_HEALTH" then
    if unit == "target" then
      P.Update()
    end
  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    -- a seal you cast: which echo the Unsealed Wrath item shows (the ID may be secret: then nothing changes)
    local spellID = Num(select(2, ...))
    if unit == "player" and spellID then
      P.NoteSeal(SpellName(spellID))
    end
  elseif event == "SPELLS_CHANGED" then
    P.lookup = nil
    P.QueueScan()
  elseif event == "ADDON_LOADED" then
    if unit == "Blizzard_CooldownViewer" and Q.DB()[CDM_KEY] then
      P.QueueScan()
    end
  elseif P.scanEvents[event] then
    P.QueueScan()
  else
    P.Update()
    if event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" or event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
      P.UpdateSoon()
    end
  end
end

P.scanEvents = {}
for _, event in ipairs(SCAN_EVENTS) do
  P.scanEvents[event] = true
end

-- "/codex procglow": one chat line per cooldown manager icon (spell, whether it is on our list, usable, the game's
-- own alert, our glow), so a report from the game shows where it stops. Read only; secret values print as "?".
function P.Report()
  local function Say(text)
    print(ns.PREFIX .. " " .. text)
  end
  local function Show(value)
    if value == nil then
      return "-"
    end
    return Readable(value) and tostring(value) or "?"
  end
  local db = Q.DB()
  Say(("your seal (for the echoes): %s"):format(P.lastSeal or "not known yet"))
  for match, guess in pairs(P.stackGuess) do
    Say(("%s: %d of %d stacks (%s)"):format(match.name, guess.count, match.stacks or 0,
      guess.hooked and "counted from the cooldown manager" or "not counted: active = reached"))
  end
  Say(("proc glow %s, cooldown manager %s, " .. BRAND .. "'s glow instead of the game's %s, style %s"):format(
    db[KEY] and "on" or "off", db[CDM_KEY] and "on" or "off", P.ReplaceGame() and "on" or "off", Show(P.Wanted())))
  for _, name in ipairs(P.VIEWERS) do
    local viewer = _G[name]
    local pool = type(viewer) == "table" and rawget(viewer, "itemFramePool")
    Say(("%s: %s, %s"):format(name, type(viewer) == "table" and "found" or "missing",
      type(pool) == "table" and "pool found" or "no pool"))
  end
  -- your buffs, as the proc list reads them (secret values show as "?")
  P.Lookup()
  local read = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
  for index = 1, 40 do
    local ok, aura = false, nil
    if type(read) == "function" then
      ok, aura = pcall(read, "player", index, "HELPFUL")
    end
    if not ok or type(aura) ~= "table" then
      break
    end
    local id, name = Num(aura.spellId), Str(aura.name)
    local match = (id and P.auraIDs[id]) or (name and P.auraNames[Lower(name)])
    Say(("buff %d: spell %s, %s, stacks %s%s"):format(index, Show(aura.spellId), Show(aura.name), Show(aura.applications),
      match and (", proc " .. match.name .. (match.stacks and (" from " .. match.stacks .. " stacks") or "")) or ""))
  end
  local active = P.ActiveAuras()
  for aura in pairs(active) do
    if type(aura) == "table" and aura.name then
      local can = P.AuraCastable(aura, active)
      Say(("proc %s active, a spell of it castable now: %s"):format(aura.name, can and "yes" or "no"))
    end
  end
  local watched = {}
  for _, item in ipairs(P.watch or {}) do
    watched[item.button] = item
  end
  local items = P.CDMItems()
  if #items == 0 then
    Say("no cooldown manager icons in use")
  end
  for index, item in ipairs(items) do
    local id = P.ItemSpell(item)
    local entry = id and P.Entry(id)
    local usable = id and C_Spell and C_Spell.IsSpellUsable and Ask(C_Spell.IsSpellUsable, id)
    local game = id and P.GameGlows({ id = id, button = item })
    local glow = P.glows[item]
    Say(("%d. cooldownID %s, spell %s %s: %s, usable %s, game alert %s, watched %s, glow %s"):format(index,
      Show(rawget(item, "cooldownID")), Show(id), Show(id and SpellName(id)),
      entry and ("listed as " .. tostring(entry.key)) or "not on the list", Show(usable), Show(game),
      watched[item] and "yes" or "no", glow and (glow.lit and "lit" or "made") or "none"))
  end
end

function P.Start()
  if P.started then
    return
  end
  P.started = true
  if not P.events then
    P.events = CreateFrame("Frame")
    P.events:SetScript("OnEvent", function(...)
      local ok, err = pcall(OnEvent, ...)
      if not ok then
        geterrorhandler()(err)
      end
    end)
  end
  local events = P.events
  for _, event in ipairs(UPDATE_EVENTS) do
    pcall(events.RegisterEvent, events, event)
  end
  for _, event in ipairs(SCAN_EVENTS) do
    pcall(events.RegisterEvent, events, event)
  end
  pcall(events.RegisterUnitEvent, events, "UNIT_AURA", "player")
  pcall(events.RegisterUnitEvent, events, "UNIT_HEALTH", "target")
  pcall(events.RegisterUnitEvent, events, "UNIT_SPELLCAST_SUCCEEDED", "player") -- seals (only paladins have any)
  pcall(events.RegisterEvent, events, "ADDON_LOADED")
  P.Scan()
end

function P.Stop()
  if not P.started then
    return
  end
  P.started = false
  P.queued = false
  if P.events then
    P.events:UnregisterAllEvents()
  end
  for button in pairs(P.glows) do
    SetGlow(button, false)
  end
  for item in pairs(P.cdmItems) do
    P.GameAlertAlpha(item, false)
  end
  P.watch, P.litKeys = {}, {}
  if P.art then
    P.art.HideAll()
    P.art.gameLit, P.art.gameArt = {}, {}
  end
end

function P.Enable()
  if Q.On(KEY) then -- (on, and not left to the standalone Tylesser - Proc Glow: Q.On knows Elsewhere)
    P.Start()
  end
end

function P.Changed(on)
  if on then
    P.Start()
  else
    P.Stop()
  end
end

-- The sound picker's entries, grouped "Soft" / "Loud" (first = "Same as the main sound" for the per-ability list).
function P.SoundChoices(withSame)
  local list = {}
  if withSame then
    list[#list + 1] = { "same", "Same as the main sound" }
  end
  for _, group in ipairs({ { "codex", BRAND .. "'s own" }, { "soft", "Soft" }, { "loud", "Loud" } }) do
    list[#list + 1] = { title = group[2] }
    for _, sound in ipairs(P.SOUNDS) do
      if (sound.group or sound[5]) == group[1] then
        list[#list + 1] = { sound[1], sound[2] }
      end
    end
  end
  list[#list + 1] = { "none", "None" }
  return list
end

-- The procs a sound can be picked for: every reactive ability, then the buffs.
function P.SoundKeys()
  local keys, seen = {}, {}
  for _, entry in ipairs(P.REACTIVE) do
    keys[#keys + 1] = entry.name
    seen[entry.name] = true
  end
  for _, aura in ipairs(P.AURAS) do
    if not seen[aura.name] then
      keys[#keys + 1] = aura.name
      seen[aura.name] = true
    end
  end
  return keys
end

local ROW = 26

-- A per-ability list on the page: one row per proc (name, a picker, optionally a Test button); shown while its
-- switch (eachKey) is on. The choice is saved in db[forKey][proc name]; "same" (the first choice) saves nothing.
-- Used for the sound per ability and the art side per ability.
local function EachList(eachKey, forKey, Choices, Test, Off)
  local function Build(parent, last, sub)
    local box = CreateFrame("Frame", nil, parent)
    box:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 26, -4)
    box:SetPoint("RIGHT", 0, 0)
    box:SetHeight(1)
    sub.holder, sub.rows = box, {}
    for index, key in ipairs(P.SoundKeys()) do
      local row = CreateFrame("Frame", nil, box)
      row:SetHeight(ROW - 2)
      row:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -(index - 1) * ROW)
      row:SetPoint("RIGHT", 0, 0)
      row.key = key
      row.label = ns.UI.Text(row, "body", 12, "text")
      row.label:SetPoint("LEFT", 0, 0)
      row.label:SetWidth(130)
      row.label:SetJustifyH("LEFT")
      row.label:SetText(key)
      row.picker = ns.UI.Picker(row, 190, 22)
      row.picker:SetPoint("LEFT", 136, 0)
      row.picker:SetScript("OnClick", function(self)
        Q.OpenChoice(self, Choices(), (Q.DB()[forKey] or {})[key] or "same", function(value)
          P.SetFor(forKey, key, value)
        end)
      end)
      if Test then
        row.test = ns.UI.Button(row, 60, 22, "Test")
        row.test:SetPoint("LEFT", row.picker, "RIGHT", 8, 0)
        row.test:SetScript("OnClick", function()
          Test(key)
        end)
      end
      sub.rows[index] = row
    end
    sub.count = #sub.rows
    return box
  end
  local function Refresh(sub, on)
    local db = Q.DB()
    local open = db[eachKey] and true or false
    local enabled = on and not (Off and Off()) and true or false
    sub.holder:SetHeight(open and sub.count * ROW or 1)
    local choices = Choices()
    for _, row in ipairs(sub.rows) do
      row:SetShown(open)
      local value = (db[forKey] or {})[row.key] or "same"
      row.picker:SetText(Q.ChoiceText({ choices = choices }, value))
      row.picker:SetEnabled(enabled)
      if row.test then
        row.test:SetEnabled(enabled)
      end
      row:SetAlpha(enabled and 1 or 0.5)
    end
  end
  return Build, Refresh
end

function P.SetFor(forKey, key, value)
  local db = Q.DB()
  db[forKey] = type(db[forKey]) == "table" and db[forKey] or {}
  db[forKey][key] = value ~= "same" and value or nil
  local option = Q.Option(forKey)
  if option and option.Changed then
    option.Changed()
  end
  if Q.RefreshPage then
    Q.RefreshPage()
  end
end

function P.SetSoundFor(key, value)
  P.SetFor(FOR_KEY, key, value)
end

local BuildEach, RefreshEach = EachList(EACH_KEY, FOR_KEY, function() return P.SoundChoices(true) end,
  function(key)
    local db = Q.DB()
    local own = (db[FOR_KEY] or {})[key]
    P.Play(P.ResolveSound(own and own ~= "same" and own or db[KIT_KEY], key))
  end)

local function Repainted()
  if Q.running then
    P.Repaint()
  end
end

-- The art's options (ProcArt.lua loads after this file; its tables are read when the page is built).
local function ArtOff()
  if Q.DB().procArt == false then
    return "Needs \"Art beside your character\"."
  end
  return nil
end

local function ArtRefresh()
  if P.art then
    P.art.Refresh()
  end
end

-- ProcArt.lua's list, filled in place once it loads (the options table is made before it runs).
local artLists = { LOOKS = {}, SIZES = {}, ALPHAS = {}, SIDES = {}, COLOR_CHOICES = {} }
P.artLists = artLists
local function ArtChoice(name)
  return artLists[name]
end

-- The art side per ability: "Same as Art side" first, then the sides.
local function SideChoices()
  local list = { { "same", "Same as Art side" } }
  for _, side in ipairs(artLists.SIDES) do
    list[#list + 1] = side
  end
  return list
end
local BuildSides, RefreshSides = EachList("procArtSideEach", "procArtSideFor", SideChoices, nil, ArtOff)

-- The art per ability: "Same as Art" first, then every look and style.
local function LookChoices()
  local list = { { "same", "Same as Art" } }
  for _, look in ipairs(artLists.LOOKS) do
    list[#list + 1] = look
  end
  return list
end
local BuildLooks, RefreshLooks = EachList("procArtLookEach", "procArtLookFor", LookChoices, nil, ArtOff)

local function NotForAlert(what)
  return function()
    if P.Style() == "alert" then
      return ("%s doesn't apply to the game's spell alert."):format(what)
    end
    return nil
  end
end

Q.AddToggle({
  key = KEY,
  name = "Glow on proc abilities",
  desc = "Action buttons glow while a reactive ability can be used: Overpower, Revenge, Execute, Riposte, "
    .. "Counterattack, Mongoose Bite, Hammer of Wrath (and Victory Rush where the game has it). Also Shadow Bolt "
    .. "with Shadow Trance (Nightfall), Arcane Missiles with Missile Barrage and Pyroblast at 3 stacks of Heating Up "
    .. "(mage). Clearcasting shows only its art beside you, no glow on the buttons. What the game already lights itself "
    .. "keeps the game's glow. With the art on, the "
    .. "game's proc art shows beside your character too (two swords for Blade of Justice), on both sides or one.",
  order = 50,
  -- (Codex: left to the standalone Tylesser - Proc Glow while it is loaded; the standalone has no ns.IsAddOnLoaded)
  Elsewhere = function()
    if ns.IsAddOnLoaded and ns.PROC_BRAND == nil and ns.IsAddOnLoaded("ProcGlow") then
      return "Tylesser - Proc Glow"
    end
  end,
  Enable = P.Enable,
  Changed = P.Changed,
  options = {
    { key = STYLE_KEY, kind = "choice", name = "Glow style", default = "auto", choices = P.STYLES, rowHeight = 44,
      preview = function(holder) return P.BuildPreview(holder) end, Changed = Repainted },
    { key = COLOR_KEY, kind = "choice", name = "Glow colour", default = "accent", choices = P.COLORS,
      Changed = Repainted, Disabled = NotForAlert("Colour") },
    { key = SPEED_KEY, kind = "stepper", name = "Pulse speed", default = "normal", values = P.SPEEDS,
      Changed = Repainted, Disabled = NotForAlert("Speed") },
    { key = THICK_KEY, kind = "stepper", name = "Thickness", default = 2, values = P.THICKNESS, Changed = Repainted,
      Disabled = function()
        local style = P.Style()
        if style ~= "border" and style ~= "ring" then
          return "Only for the pulsing border and the ring."
        end
        return nil
      end },
    { key = CDM_KEY, name = "Also on the cooldown manager", default = true,
      Changed = function()
        if P.started then
          P.Scan()
        end
      end },
    { key = GAME_KEY, name = "On the cooldown manager, " .. BRAND .. "'s glow instead of the game's", default = true,
      desc = "The game's own proc glow is square and doesn't fit the rounded icons; this shows the glow style above there instead.",
      Changed = function()
        if P.started then
          P.Scan()
        end
      end,
      Disabled = function()
        return not Q.DB()[CDM_KEY] and "Needs \"Also on the cooldown manager\"." or nil
      end },
    { key = "procArt", name = "Art beside your character while an ability procs", default = true,
      Changed = function() if P.art then P.art.Refresh() end end },
    { key = "procArtTest", kind = "button", name = "Show the art", Click = function() if P.art then P.art.Test() end end,
      Disabled = ArtOff },
    { key = "procArtLook", kind = "choice", name = "Art", default = "codex", choices = ArtChoice("LOOKS"),
      Changed = ArtRefresh, Disabled = ArtOff },
    { key = "procArtColor", kind = "choice", name = "Art colour", default = "proc", choices = ArtChoice("COLOR_CHOICES"),
      button = { name = "Pick", Click = function() if P.art then P.art.PickColor() end end },
      Changed = ArtRefresh, Disabled = ArtOff },
    { key = "procArtSide", kind = "choice", name = "Art side", default = "both", choices = ArtChoice("SIDES"),
      Changed = ArtRefresh, Disabled = ArtOff },
    { key = "procArtSideEach", name = "Choose the side per ability", default = false, Changed = ArtRefresh,
      Disabled = ArtOff },
    { key = "procArtSideFor", kind = "custom", default = {}, Build = BuildSides, Refresh = RefreshSides,
      Changed = ArtRefresh },
    { key = "procArtLookEach", name = "Choose the art per ability", default = false, Changed = ArtRefresh,
      Disabled = ArtOff },
    { key = "procArtLookFor", kind = "custom", default = {}, Build = BuildLooks, Refresh = RefreshLooks,
      Changed = ArtRefresh },
    { key = "procArtGallery", kind = "button", name = "Show all arts",
      Click = function() if P.art then P.art.Gallery() end end },
    { key = "procArtSize", kind = "stepper", name = "Art size", default = 1, values = ArtChoice("SIZES"),
      Changed = ArtRefresh, Disabled = ArtOff },
    { key = "procArtAlpha", kind = "stepper", name = "Art opacity", default = 0.8, values = ArtChoice("ALPHAS"),
      Changed = ArtRefresh, Disabled = ArtOff },
    { key = SOUND_KEY, name = "Play a sound when an ability procs", default = false },
    { key = KIT_KEY, kind = "choice", name = "Sound", default = "ping", choices = P.SoundChoices(false),
      button = { name = "Test", Click = function() P.Play() end } },
    { key = COMBAT_KEY, name = "Only in combat", default = true },
    { key = MASTER_KEY, name = "Play it on the Master channel (heard even with sound effects off)", default = false },
    { key = EACH_KEY, name = "Choose a sound per ability", default = false },
    { key = FOR_KEY, kind = "custom", default = {}, Build = BuildEach, Refresh = RefreshEach },
  },
})
