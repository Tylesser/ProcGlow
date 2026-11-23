local addonName, ns = ...

-- Tylesser - Proc Glow: Codex's proc glow as an addon of its own (2026-11-22, the user's request). ProcGlow.lua and
-- ProcArt.lua are the same files as Codex's Modules/QoL ones (twins: a fix goes into both). This file gives them
-- what Codex would: the settings store and toggle (ns.qol), a few widgets (ns.UI, on the shared Tylesser look), the
-- theme's accent, the chat prefix, and where the media lives (flat in Media/). WoW Forever only, as Codex.

local T = ns.T
local MEDIA = "Interface\\AddOns\\" .. addonName .. "\\Media\\"

ns.TITLE = "Tylesser - Proc Glow"
ns.PREFIX = T.Prefix("Proc Glow")
ns.PROC_BRAND = "Proc Glow"
ns.PROC_ART_NAME = "Proc Glow art"
ns.PROC_FRAMES = "TylesserProcGlow"
ns.PROC_MEDIA = MEDIA
ns.PROC_CIRCLE = MEDIA .. "Circle"
ns.PROC_RING = MEDIA .. "Ring"

-- Settings and the toggle -------------------------------------------------------------------------------------------

local Q = { toggles = {} }
ns.qol = Q

-- ProcGlowDB (account wide), filled with the toggle's and options' defaults on first use.
function Q.DB()
  if Q.db then
    return Q.db
  end
  if type(ProcGlowDB) ~= "table" then
    ProcGlowDB = {}
  end
  local db = ProcGlowDB
  for _, toggle in ipairs(Q.toggles) do
    if db[toggle.key] == nil then
      db[toggle.key] = true -- the addon is installed for this: on from the start
    end
    for _, option in ipairs(toggle.options or {}) do
      if db[option.key] == nil and option.kind ~= "button" then
        if option.kind == "choice" or option.kind == "stepper" or option.kind == "custom" then
          db[option.key] = option.default
        else
          db[option.key] = option.default ~= false
        end
      end
    end
  end
  if Q.loaded then
    Q.db = db -- (before ADDON_LOADED the saved table isn't there yet: filled again then)
  end
  return db
end

function Q.AddToggle(toggle)
  Q.toggles[#Q.toggles + 1] = toggle
  Q.toggle = toggle
end

function Q.Toggle(key)
  for _, toggle in ipairs(Q.toggles) do
    if toggle.key == key then
      return toggle
    end
  end
end

function Q.Option(key)
  for _, toggle in ipairs(Q.toggles) do
    for _, option in ipairs(toggle.options or {}) do
      if option.key == key then
        return option
      end
    end
  end
end

function Q.On(key)
  return Q.running and Q.DB()[key] and true or false
end

function Q.Set(key, value)
  local entry = Q.Toggle(key) or Q.Option(key)
  if entry and not (entry.kind == "choice" or entry.kind == "stepper" or entry.kind == "custom") then
    value = value and true or false
  end
  Q.DB()[key] = value
  if Q.running and entry and entry.Changed then
    entry.Changed(value)
  end
  if Q.RefreshPage then
    Q.RefreshPage()
  end
end

function Q.ChoiceText(option, value)
  for _, choice in ipairs(option.choices or option.values or {}) do
    if not choice.title and choice[1] == value then
      return choice[2]
    end
  end
  return tostring(value or "")
end

-- A menu of choices under a picker (the game's own menus); pick(value) on a click.
function Q.OpenChoice(picker, choices, current, pick)
  if MenuUtil and MenuUtil.CreateContextMenu then
    MenuUtil.CreateContextMenu(picker, function(_, root)
      for _, choice in ipairs(choices or {}) do
        if choice.title then
          root:CreateTitle(choice.title)
        else
          local value = choice[1]
          root:CreateRadio(choice[2], function()
            return value == current
          end, function()
            pick(value)
          end)
        end
      end
    end)
    return
  end
  -- no menu API: the next choice
  local list, at = {}, 0
  for _, choice in ipairs(choices or {}) do
    if not choice.title then
      list[#list + 1] = choice[1]
      if choice[1] == current then
        at = #list
      end
    end
  end
  if #list > 0 then
    pick(list[at % #list + 1])
  end
end

-- Widgets (what ProcGlow.lua and ProcArt.lua ask of Codex's ns.UI) --------------------------------------------------

local UI = {}
ns.UI = UI
local COLORS = { text = T.PARCHMENT, muted = T.MUTED, accent = T.GOLD, bright = { 1, 1, 1 } }

function UI.Text(parent, kind, size, color, layer)
  local text = parent:CreateFontString(nil, layer or "OVERLAY")
  if kind == "head" then
    T.Font(text, size or 14, COLORS[color] or T.GOLD)
  else
    text:SetFont("Fonts\\FRIZQT__.TTF", size or 12, "")
    local c = COLORS[color] or T.PARCHMENT
    text:SetTextColor(c[1], c[2], c[3])
  end
  text:SetJustifyH("LEFT")
  return text
end

function UI.Button(parent, width, height, text)
  return T.Button(parent, width, height, text)
end

-- A picker: a button showing the current choice (the caller opens the menu on click).
function UI.Picker(parent, width, height)
  local button = T.Button(parent, width, height, "")
  button.label:SetJustifyH("LEFT")
  button.label:SetPoint("LEFT", 8, 0)
  return button
end

function UI.Panel(frame)
  T.Stone(frame)
end

function UI.CloseButton(parent)
  local button = T.CloseButton(parent)
  button:SetScript("OnClick", function()
    parent:Hide()
  end)
  return button
end

-- An edit box on the shared look (your own procs' buff and spell boxes).
function UI.EditBox(parent, width, height)
  local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  box:SetSize(width or 160, height or 22)
  box:SetAutoFocus(false)
  T.EditBox(box)
  box:SetScript("OnEscapePressed", box.ClearFocus)
  box:SetScript("OnEnterPressed", box.ClearFocus)
  return box
end

-- Codex's fold arrow (Media/FoldArrow.tga, a smooth triangle pointing right, turned a quarter for "open"): the
-- per-ability lists' headers.
function UI.FoldArrow(parent)
  local arrow = CreateFrame("Frame", nil, parent)
  arrow:SetSize(9, 9)
  arrow.icon = arrow:CreateTexture(nil, "ARTWORK")
  arrow.icon:SetTexture(MEDIA .. "FoldArrow")
  arrow.icon:SetSize(18, 18)
  arrow.icon:SetPoint("CENTER")
  arrow.icon:SetVertexColor(T.MUTED[1], T.MUTED[2], T.MUTED[3])
  function arrow:SetOpen(open)
    self.open = open and true or false
    if self.icon.SetRotation then
      self.icon:SetRotation(self.open and -math.pi / 2 or 0)
    end
  end
  arrow:SetOpen(false)
  return arrow
end

-- Codex's rounded themes don't exist here: everything square.
function UI.Radius()
  return nil
end

ns.Theme = function()
  return { accent = T.GOLD }
end

-- Start-up ------------------------------------------------------------------------------------------------------------

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, name)
  if event == "ADDON_LOADED" and name == addonName then
    Q.loaded = true
    Q.db = nil
    Q.DB()
  elseif event == "PLAYER_LOGIN" then
    Q.running = true
    for _, toggle in ipairs(Q.toggles) do
      if toggle.Enable then
        toggle.Enable()
      end
    end
  end
end)
