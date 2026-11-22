local addonName, ns = ...

-- The options page (Esc > Options > AddOns > Tylesser - Proc Glow), built from the toggle's option list in
-- ProcGlow.lua (the list Codex's Quality of life page shows): checks, choice pickers (with the style preview and a
-- Test button where the option has them), steppers, buttons and the per-ability sound list (a custom option). An
-- option's Disabled() greys it with the reason. /procglow opens it.

local T = ns.T
local Q = ns.qol
local P = Q.procglow

local LABEL_WIDTH, PICKER_WIDTH, ROW, GAP = 200, 220, 26, 6
local panel, content, rows = nil, nil, {}

local function Value(key)
  return Q.DB()[key]
end

local function MainOn()
  return Value(Q.toggle.key) and true or false
end

-- One row per option, stacked; returns the row (with :Refresh()).
local function OptionRow(parent, option, y, width)
  local row = CreateFrame("Frame", nil, parent)
  row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
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
      if option.preview then
        local holder = CreateFrame("Frame", nil, row)
        holder:SetSize(40, 40)
        holder:SetPoint("LEFT", after, "RIGHT", 16, 0)
        option.preview(holder)
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

local function Refresh()
  if not panel then
    return
  end
  if panel.main then
    panel.main:SetChecked(MainOn())
  end
  for _, row in ipairs(rows) do
    row.Refresh()
  end
  if panel.custom then
    local option, sub = panel.custom.option, panel.custom.sub
    if option.Refresh then
      option.Refresh(sub, MainOn())
    end
    local height = sub.holder and sub.holder:GetHeight() or 0
    content:SetHeight(panel.custom.top + height + 40)
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

  local toggle = Q.toggle
  local main = T.Check(content, toggle.name)
  main:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
  main:SetScript("OnClick", function(self)
    Q.Set(toggle.key, self:GetChecked() and true or false)
  end)
  panel.main = main
  local desc = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  desc:SetPoint("TOPLEFT", main, "BOTTOMLEFT", 4, -4)
  desc:SetWidth(width - 10)
  desc:SetJustifyH("LEFT")
  desc:SetText(toggle.desc or "")
  local y = 30 + math.max(28, math.ceil((#(toggle.desc or "")) / 95) * 13) + 12

  for _, option in ipairs(toggle.options or {}) do
    if option.kind == "custom" then
      local last = rows[#rows] or main
      local sub = {}
      option.Build(content, last, sub)
      panel.custom = { option = option, sub = sub, top = y }
    else
      local row = OptionRow(content, option, y, width)
      rows[#rows + 1] = row
      local extra = (option.desc and (option.kind or "check") == "check") and 14 or 0
      y = y + row:GetHeight() + GAP + extra + (option.kind == "choice" and option.Disabled and 10 or 0)
    end
  end
  content:SetHeight(y + 40)
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
  elseif command == "on" or command == "off" then
    Q.Set(Q.toggle.key, command == "on")
    print(ns.PREFIX .. (command == "on" and "on." or "off."))
  else
    print(ns.PREFIX .. "/procglow opens the options. /procglow test shows the art, /procglow arts every art, "
      .. "/procglow report what each glow is doing, /procglow on | off, /procglow feedback.")
  end
end
