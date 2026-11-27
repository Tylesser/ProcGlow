local addonName, ns = ...

-- Profiles (2026-11-25, the user's request: "so user can easily switch between them"): named sets of Proc Glow's
-- settings, every option on the page, the main switch, your own procs and the art's place included. Each character
-- remembers the profile it uses; one that never picked uses "Default", so the settings from before profiles are the
-- Default profile and nothing changes until a player makes another.
--
-- ProcGlowDB                = the settings of the profile in use right now (what Q.DB() returns, read live by
--                             ProcGlow.lua and ProcArt.lua)
-- ProcGlowDB.profileActive  = that profile's name
-- ProcGlowDB.profiles[name] = the settings of every other profile
-- ProcGlowCharDB.profile    = this character's profile (nil = Default)
--
-- A character whose profile isn't the one in ProcGlowDB swaps at ADDON_LOADED, before the defaults are filled in.
-- Switching while playing swaps the same way and applies at once (no reload): the glow stops and starts again,
-- glows are repainted, the art moves to its place. Not in a fight. Codex has profiles of its own (Profiles.lua
-- there) that already hold its proc glow settings: this file is the standalone's only.

local L = ns.L
local Q = ns.qol
local R = {}
Q.profiles = R

R.DEFAULT = "Default"
R.MAX_NAME = 32
local META = { profiles = true, profileActive = true }
local KEEP = { procEachFolded = true } -- which lists are folded on the page: how it looks, not a setting
local MAX_DEPTH = 20

local function Saved()
  if type(ProcGlowDB) ~= "table" then
    ProcGlowDB = {}
  end
  return ProcGlowDB
end

local function CharDB()
  if type(ProcGlowCharDB) ~= "table" then
    ProcGlowCharDB = {}
  end
  return ProcGlowCharDB
end

local function Store()
  local db = Saved()
  if type(db.profiles) ~= "table" then
    db.profiles = {}
  end
  return db.profiles
end

local function Trim(text)
  return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- A deep copy of plain values (string or number keys).
local function Copy(value, depth)
  if type(value) ~= "table" then
    return value
  end
  depth = depth or 0
  if depth > MAX_DEPTH then
    return nil
  end
  local out = {}
  for key, inner in pairs(value) do
    local kind = type(key)
    if kind == "string" or kind == "number" then
      out[key] = Copy(inner, depth + 1)
    end
  end
  return out
end

-- The settings in a saved table, copied (never the profile list, its name or the page's folds).
function R.Snapshot(db)
  local out = {}
  for key, value in pairs(db) do
    if not META[key] and not KEEP[key] then
      out[key] = Copy(value)
    end
  end
  return out
end

-- Replaces the settings in ProcGlowDB in place (the table Q.DB() hands out stays the same table).
local function Put(db, settings)
  local old = {}
  for key in pairs(db) do
    if not META[key] and not KEEP[key] then
      old[#old + 1] = key
    end
  end
  for _, key in ipairs(old) do
    db[key] = nil
  end
  for key, value in pairs(type(settings) == "table" and settings or {}) do
    if not META[key] and not KEEP[key] then
      db[key] = Copy(value)
    end
  end
end

function R.Active()
  local name = Saved().profileActive
  return type(name) == "string" and name ~= "" and name or R.DEFAULT
end

-- Every profile's name, Default first, then A-Z.
function R.Names()
  local names, active = {}, R.Active()
  local seen = { [active] = true }
  names[1] = active
  for name in pairs(Store()) do
    if type(name) == "string" and not seen[name] then
      seen[name] = true
      names[#names + 1] = name
    end
  end
  if not seen[R.DEFAULT] then
    names[#names + 1] = R.DEFAULT
  end
  table.sort(names, function(a, b)
    if (a == R.DEFAULT) ~= (b == R.DEFAULT) then
      return a == R.DEFAULT
    end
    return a:lower() < b:lower()
  end)
  return names
end

-- The profile's own spelling for a name typed in any case, or nil.
function R.Find(name)
  name = Trim(name):lower()
  if name == "" then
    return nil
  end
  for _, real in ipairs(R.Names()) do
    if real:lower() == name then
      return real
    end
  end
end

-- The live settings go into their profile, the named one's come out.
local function Swap(name)
  local db, store = Saved(), Store()
  local active = R.Active()
  if name == active then
    return
  end
  store[active] = R.Snapshot(db)
  local settings = store[name] -- nil: Default before it was ever stored = every option at its default
  store[name] = nil
  Put(db, settings)
  db.profileActive = name
end

-- At ADDON_LOADED (Shim.lua), before the defaults are filled in: this character's profile into ProcGlowDB.
function R.Load()
  local db = Saved()
  Store()
  db.profileActive = R.Active()
  local wanted = CharDB().profile
  wanted = type(wanted) == "string" and R.Find(wanted) or R.DEFAULT -- (a deleted one: Default)
  Swap(wanted)
end

-- What the addon does with the settings now in place.
function R.Apply()
  Q.Fill(Saved())
  local P = Q.procglow
  if P then
    if P.Stop then
      P.Stop()
    end
    P.lookup = nil -- your own procs may differ
    if Q.toggle and Q.On(Q.toggle.key) and P.Start then
      P.Start()
    end
    if P.Repaint then
      P.Repaint()
    end
    local art = P.art
    if art then
      if art.PlaceAnchor then
        art.PlaceAnchor()
      end
      if art.Refresh then
        art.Refresh()
      end
    end
  end
  if Q.RefreshPage then
    Q.RefreshPage()
  end
end

local function InFight()
  return InCombatLockdown and InCombatLockdown() and true or false
end

-- Returns true, or false and why.
function R.Switch(name)
  local real = R.Find(name)
  if not real then
    return false, L["There is no profile named \"%s\"."]:format(Trim(name))
  end
  if real == R.Active() then
    CharDB().profile = real ~= R.DEFAULT and real or nil
    return true
  end
  if InFight() then
    return false, L["Profiles switch after the fight."]
  end
  CharDB().profile = real ~= R.DEFAULT and real or nil
  Swap(real)
  R.Apply()
  return true
end

-- A name a new profile may have, or nil and why.
function R.CheckName(name)
  name = Trim(name)
  if name == "" then
    return nil, L["Type a name for the new profile."]
  end
  if #name > R.MAX_NAME then
    return nil, L["A name has at most %d letters."]:format(R.MAX_NAME)
  end
  if name:find("|", 1, true) then
    return nil, L["A name can't have a | in it."]
  end
  local taken = R.Find(name)
  if taken then
    return nil, L["There is already a profile named \"%s\"."]:format(taken)
  end
  return name
end

-- A new profile with the settings in use now; this character uses it from now on. Returns the name, or nil and why.
function R.Create(name)
  local checked, why = R.CheckName(name)
  if not checked then
    return nil, why
  end
  local db = Saved()
  Store()[R.Active()] = R.Snapshot(db) -- the old one keeps its settings
  db.profileActive = checked -- the same settings, so nothing to apply
  CharDB().profile = checked
  if Q.RefreshPage then
    Q.RefreshPage()
  end
  return checked
end

-- Deletes a profile (never Default). The one in use: this character goes back to Default first. Other characters
-- that used it get Default at their next login. Returns true, or false and why.
function R.Delete(name)
  local real = R.Find(name)
  if not real then
    return false, L["There is no profile named \"%s\"."]:format(Trim(name))
  end
  if real == R.DEFAULT then
    return false, L["The Default profile can't be deleted."]
  end
  if real == R.Active() then
    local ok, why = R.Switch(R.DEFAULT)
    if not ok then
      return false, why
    end
  end
  Store()[real] = nil
  if CharDB().profile == real then
    CharDB().profile = nil
  end
  if Q.RefreshPage then
    Q.RefreshPage()
  end
  return true
end
