local addonName, ns = ...

-- The options page (Esc > Options > AddOns > Tylesser - Proc Glow), built from the toggle's option list in
-- ProcGlow.lua (the list Codex's Quality of life page shows): checks, choice pickers (with the style preview and a
-- Test button where the option has them), steppers, buttons and the per-ability sound list (a custom option). An
-- option's Disabled() greys it with the reason. /procglow opens it.

local T = ns.T
local Q = ns.qol
local P = Q.procglow

local LABEL_WIDTH, PICKER_WIDTH, ROW, GAP = 200, 220, 26, 6
local PROFILE_H, CONFIRM_TIME = 92, 4
local panel, content, rows, items = nil, nil, {}, {}

local function Value(key)
  return Q.DB()[key]
end

local function MainOn()
  return Value(Q.toggle.key) and true or false
end

-- One row per option, stacked; returns the row (with :Refresh()).
local function OptionRow(parent, option, width)
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(width, ROW)
  row.option = option
  local kind = option.kind or "check"
  local note = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  note:SetJustifyH("LEFT")
  row.note = note

  if kind == "check" then
    local check = T.Check(row, option.name)
    check:SetPoint("LEFT", row, "LEFT", 0, 0)
    check.Text:SetWidth(width - 40)
    check:SetScript("OnClick", function(self)
      Q.Set(option.key, self:GetChecked() and true or false)
    end)
    row.check = check
    note:SetPoint("TOPLEFT", check.Text, "BOTTOMLEFT", 0, -2)
    note:SetWidth(width - 40)
  elseif kind == "button" then
    local button = T.Button(row, 160, 22, option.name)
    button:SetPoint("LEFT", row, "LEFT", 4, 0)
    button:SetScript("OnClick", function()
      option.Click()
    end)
    row.button = button
    note:SetPoint("LEFT", button, "RIGHT", 10, 0)
  else
    local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", row, "LEFT", 4, 0)
    label:SetWidth(LABEL_WIDTH - 8)
    label:SetJustifyH("LEFT")
    label:SetText(option.name)
    row.label = label
    if kind == "choice" then
      local picker = ns.UI.Picker(row, PICKER_WIDTH, 22)
      picker:SetPoint("LEFT", row, "LEFT", LABEL_WIDTH, 0)
      picker:SetScript("OnClick", function(self)
        local choices = type(option.choices) == "function" and option.choices() or option.choices
        Q.OpenChoice(self, choices, Value(option.key), function(value)
          Q.Set(option.key, value)
        end)
      end)
      row.picker = picker
      local after = picker
      if option.button then
        local extra = T.Button(row, 60, 22, option.button.name)
        extra:SetPoint("LEFT", picker, "RIGHT", 8, 0)
        extra:SetScript("OnClick", function()
          option.button.Click()
        end)
        row.extra, after = extra, extra
      end
      if option.button2 then -- (a second one: the art colour's Reset)
        local extra2 = T.Button(row, 60, 22, option.button2.name)
        extra2:SetPoint("LEFT", after, "RIGHT", 8, 0)
        extra2:SetScript("OnClick", function()
          option.button2.Click()
        end)
        row.extra2, after = extra2, extra2
      end
      if option.preview then
        local holder = CreateFrame("Frame", nil, row)
        holder:SetSize(40, 40)
        holder:SetPoint("LEFT", after, "RIGHT", 16, 0)
        -- the preview frame is placed by the page (it came back unplaced and never showed: the user's screenshot,
        -- 2026-11-24)
        local ok, frame = pcall(option.preview, holder)
        if ok and type(frame) == "table" and frame.SetPoint then
          frame:SetPoint("CENTER", holder, "CENTER", 0, 0)
        end
        row.preview = ok and frame or nil
        row:SetHeight(math.max(ROW, option.rowHeight or ROW))
      end
      note:SetPoint("TOPLEFT", picker, "BOTTOMLEFT", 2, -2)
    elseif kind == "stepper" then
      local less = T.Button(row, 22, 22, "<")
      less:SetPoint("LEFT", row, "LEFT", LABEL_WIDTH, 0)
      local value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      value:SetPoint("LEFT", less, "RIGHT", 6, 0)
      value:SetWidth(100)
      local more = T.Button(row, 22, 22, ">")
      more:SetPoint("LEFT", value, "RIGHT", 6, 0)
      local function Step(delta)
        local values, at = option.values, 1
        values = type(values) == "function" and values() or values
        for index, entry in ipairs(values) do
          if entry[1] == Value(option.key) then
            at = index
          end
        end
        at = math.max(1, math.min(#values, at + delta))
        Q.Set(option.key, values[at][1])
      end
      less:SetScript("OnClick", function() Step(-1) end)
      more:SetScript("OnClick", function() Step(1) end)
      row.less, row.more, row.value = less, more, value
      note:SetPoint("LEFT", more, "RIGHT", 10, 0)
    end
  end

  function row.Refresh()
    local on = MainOn()
    local reason = option.Disabled and option.Disabled() or nil
    local enabled = on and not reason
    row:SetAlpha(enabled and 1 or 0.5)
    note:SetText(reason or (kind == "check" and option.desc) or "")
    if row.check then
      row.check:SetChecked(Value(option.key) and true or false)
      row.check:SetEnabled(on and true or false)
    end
    if row.button then
      row.button:SetEnabled(enabled and true or false)
    end
    if row.picker then
      local choices = type(option.choices) == "function" and option.choices() or option.choices
      row.picker:SetText(Q.ChoiceText({ choices = choices }, Value(option.key)))
      row.picker:SetEnabled(enabled and true or false)
      if row.extra then
        row.extra:SetEnabled(enabled and true or false)
      end
      if row.extra2 then
        row.extra2:SetEnabled(enabled and true or false)
      end
    end
    if row.value then
      local values = type(option.values) == "function" and option.values() or option.values
      row.value:SetText(Q.ChoiceText({ choices = values }, Value(option.key)))
      row.less:SetEnabled(enabled and true or false)
      row.more:SetEnabled(enabled and true or false)
    end
  end
  return row
end

-- Profiles at the top of the page (Profiles.lua): the one in use (a picker: switching applies at once), Delete
-- (two clicks), and a new one from the settings in use now. Never greyed by the main switch: a profile may be the
-- one that has the glow on. The note under them says what happened, else the hint.
local PROFILE_HINT = "Each character keeps its own profile. A new one starts as a copy of the settings in use."
local function ProfileBlock(parent, width)
  local R = Q.profiles
  local block = CreateFrame("Frame", nil, parent)
  block:SetSize(width, PROFILE_H)
  local function Label(text, y)
    local label = block:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", block, "TOPLEFT", 4, y - 5)
    label:SetWidth(LABEL_WIDTH - 8)
    label:SetJustifyH("LEFT")
    label:SetText(text)
    return label
  end
  Label("Profile", 0)
  Label("New profile", -(ROW + GAP))
  local note = block:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  note:SetPoint("TOPLEFT", block, "TOPLEFT", LABEL_WIDTH + 2, -(2 * (ROW + GAP)) - 2)
  note:SetWidth(width - LABEL_WIDTH - 10)
  note:SetJustifyH("LEFT")
  local said
  local function Say(text)
    said = text
    note:SetText(text or PROFILE_HINT)
  end

  local picker = ns.UI.Picker(block, PICKER_WIDTH, 22)
  picker:SetPoint("TOPLEFT", block, "TOPLEFT", LABEL_WIDTH, -2)
  picker:SetScript("OnClick", function(self)
    local choices = {}
    for _, name in ipairs(R.Names()) do
      choices[#choices + 1] = { name, name }
    end
    Q.OpenChoice(self, choices, R.Active(), function(name)
      local ok, why = R.Switch(name)
      Say(ok and ("This character uses \"%s\" now."):format(R.Active()) or why)
    end)
  end)

  local delete = T.Button(block, 70, 22, "Delete")
  delete:SetPoint("LEFT", picker, "RIGHT", 8, 0)
  local pending, pendingAt
  delete:SetScript("OnClick", function(self)
    local name = R.Active()
    if pending ~= name or GetTime() - (pendingAt or 0) > CONFIRM_TIME then
      pending, pendingAt = name, GetTime()
      self:SetText("Sure?")
      Say(("Click again to delete \"%s\". This character goes back to Default."):format(name))
      C_Timer.After(CONFIRM_TIME, function()
        if pending == name and GetTime() - pendingAt >= CONFIRM_TIME - 0.05 then
          pending = nil
          self:SetText("Delete")
        end
      end)
      return
    end
    pending = nil
    self:SetText("Delete")
    local ok, why = R.Delete(name)
    Say(ok and ("Deleted \"%s\". This character uses Default now."):format(name) or why)
  end)

  local box = ns.UI.EditBox(block, PICKER_WIDTH - 6, 22)
  box:SetPoint("TOPLEFT", block, "TOPLEFT", LABEL_WIDTH + 6, -(ROW + GAP) - 2)
  box:SetMaxLetters(R.MAX_NAME)
  local create = T.Button(block, 70, 22, "Create")
  create:SetPoint("TOPLEFT", block, "TOPLEFT", LABEL_WIDTH + PICKER_WIDTH + 8, -(ROW + GAP) - 2)
  local function Create()
    local name, why = R.Create(box:GetText())
    if name then
      box:SetText("")
      box:ClearFocus()
      Say(("Made \"%s\" from the settings in use; this character uses it now."):format(name))
    else
      Say(why)
    end
  end
  create:SetScript("OnClick", Create)
  box:SetScript("OnEnterPressed", Create)

  function block.Refresh()
    picker:SetText(R.Active())
    delete:SetEnabled(R.Active() ~= R.DEFAULT)
    if not said then
      note:SetText(PROFILE_HINT)
    end
  end
  block.picker, block.delete, block.box, block.create, block.note, block.Say = picker, delete, box, create, note, Say
  block.Refresh()
  return block
end

-- Stacks the rows and the per-ability lists (custom options) top down; a list's height changes as it opens.
local function Layout()
  local y = panel.top or 0
  for _, item in ipairs(items) do
    if item.row then
      item.row:ClearAllPoints()
      item.row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
      y = y + item.row:GetHeight() + GAP + item.extra
    else
      local holder = item.sub.holder
      if holder then
        holder:ClearAllPoints()
        holder:SetPoint("TOPLEFT", content, "TOPLEFT", 26, -y)
        holder:SetPoint("RIGHT", content, "RIGHT", 0, 0)
        local height = holder:GetHeight() or 0
        y = y + (height > 1 and height + GAP or 0)
      end
    end
  end
  content:SetHeight(y + 40)
end

local function Refresh()
  if not panel then
    return
  end
  if panel.main then
    panel.main:SetChecked(MainOn())
  end
  if panel.profiles then
    panel.profiles.Refresh()
  end
  for _, row in ipairs(rows) do
    row.Refresh()
  end
  for _, item in ipairs(items) do
    if item.sub and item.option.Refresh then
      item.option.Refresh(item.sub, MainOn())
    end
  end
  if content then
    Layout()
  end
  if P and P.ShowPreview then
    P.ShowPreview()
  end
end
Q.RefreshPage = Refresh

local function Build()
  local width = 560
  local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, T.OPTIONS_TOP)
  scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -30, 14)
  content = CreateFrame("Frame", nil, scroll)
  content:SetSize(width, 400)
  scroll:SetScrollChild(content)

  if Q.profiles then
    panel.profiles = ProfileBlock(content, width)
    panel.profiles:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
  end
  local top = panel.profiles and PROFILE_H or 0
  local toggle = Q.toggle
  local main = T.Check(content, toggle.name)
  main:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -top)
  main:SetScript("OnClick", function(self)
    Q.Set(toggle.key, self:GetChecked() and true or false)
  end)
  panel.main = main
  local desc = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  desc:SetPoint("TOPLEFT", main, "BOTTOMLEFT", 4, -4)
  desc:SetWidth(width - 10)
  desc:SetJustifyH("LEFT")
  desc:SetText(toggle.desc or "")
  local y = top + 30 + math.max(28, math.ceil((#(toggle.desc or "")) / 95) * 13) + 12

  panel.top, panel.items = y, items
  for _, option in ipairs(toggle.options or {}) do
    if option.kind == "custom" then
      local sub = {}
      option.Build(content, rows[#rows] or main, sub) -- (placed by Layout)
      items[#items + 1] = { option = option, sub = sub }
    else
      local row = OptionRow(content, option, width)
      rows[#rows + 1] = row
      local extra = (option.desc and (option.kind or "check") == "check") and 14 or 0
      items[#items + 1] = { option = option, row = row,
        extra = extra + (option.kind == "choice" and option.Disabled and 10 or 0) }
    end
  end
  Layout()
end

local function CreateOptions()
  panel = CreateFrame("Frame")
  panel.name = ns.TITLE
  T.OptionsPage(panel, "Proc Glow",
    "Action buttons glow when an ability procs, with art beside your character and an optional sound.")
  panel:SetScript("OnShow", function()
    if not content then
      Build()
    end
    Refresh()
  end)
  if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, ns.TITLE)
    Settings.RegisterAddOnCategory(category)
    ns.optionsCategory = category
  end
end

function ns.OpenOptions()
  if ns.optionsCategory and Settings and Settings.OpenToCategory then
    local id = ns.optionsCategory.GetID and ns.optionsCategory:GetID() or ns.optionsCategory.ID
    Settings.OpenToCategory(id)
  end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
  CreateOptions()
  T.AddCompartment({ text = ns.TITLE, onClick = ns.OpenOptions, tooltip = { "Click to open the options." } })
end)

SLASH_TYLESSERPROCGLOW1 = "/procglow"
SLASH_TYLESSERPROCGLOW2 = "/pglow"
SlashCmdList.TYLESSERPROCGLOW = function(msg)
  local command = strtrim(msg or ""):lower()
  if command == "" or command == "options" then
    ns.OpenOptions()
  elseif command == "feedback" then
    T.ShowFeedback()
  elseif command == "test" then
    if P.art then
      P.art.Test()
    end
  elseif command == "arts" or command == "gallery" then
    if P.art then
      P.art.Gallery()
    end
  elseif command == "report" then
    P.Report()
  elseif command == "profile" or command:match("^profile%s") then
    local R = Q.profiles
    local name = strtrim(msg or ""):match("^%S+%s+(.+)$")
    if not name then
      local list = {}
      for _, one in ipairs(R.Names()) do
        list[#list + 1] = one == R.Active() and ("[" .. one .. "]") or one
      end
      print(ns.PREFIX .. "Profiles: " .. table.concat(list, ", ") .. ". /procglow profile <name> switches.")
    else
      local ok, why = R.Switch(name)
      print(ns.PREFIX .. (ok and ("profile \"" .. R.Active() .. "\".") or why))
    end
  elseif command == "on" or command == "off" then
    Q.Set(Q.toggle.key, command == "on")
    print(ns.PREFIX .. (command == "on" and "on." or "off."))
  else
    print(ns.PREFIX .. "/procglow opens the options. /procglow test shows the art, /procglow arts every art, "
      .. "/procglow report what each glow is doing, /procglow profile <name> switches profile, "
      .. "/procglow on | off, /procglow feedback.")
  end
end
