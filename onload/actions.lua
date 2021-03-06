local _, NeP = ...
local _G = _G
local LibDisp = _G.LibStub('LibDispellable-1.0')

local funcs = {
  noop = function() end,
  Cast = function(eva)
    NeP.Parser.LastCast = eva.spell
    NeP.Parser.LastGCD = not eva.nogcd and eva.spell or NeP.Parser.LastGCD
    NeP.Parser.LastTarget = eva.target
    NeP.Protected["Cast"](eva.spell, eva.target, eva)
    return true
  end,
  UseItem = function(eva) NeP.Protected["UseItem"](eva.spell, eva.target); return true end,
  Macro = function(eva) NeP.Protected["Macro"]("/"..eva.spell, eva.target); return true end,
  Lib = function(eva) return NeP.Library:Parse(eva.spell, eva.target, eva[1].args) end,
  C_Buff = function(eva) _G.CancelUnitBuff('player', _G.GetSpellInfo(eva[1].args)) end
}

local function IsSpellReady(spell)
  if _G.GetSpellBookItemInfo(spell) ~= 'FUTURESPELL'
  and (_G.GetSpellCooldown(spell) or 0) <= NeP.DSL:Get('gcd')() then
    return _G.IsUsableSpell(spell)
  end
end

-- Clip
NeP.Compiler:RegisterToken("!", function(_, ref)
    ref.interrupts = true
    ref.bypass = true
end)

-- No GCD
NeP.Compiler:RegisterToken("&", function(eval)
    eval.nogcd = true
end)

-- Castable while casting other spells
NeP.Compiler:RegisterToken("*", function(_, ref)
    ref.bypass = true
end)

-- Regular actions
NeP.Compiler:RegisterToken("%", function(eval, ref)
  eval.exe = funcs["noop"]
  ref.token = ref.spell
end)

local function FindDispell(eval, unit)
  if not _G.UnitExists(unit) then return end
  for _, spellID, _,_,_,_,_, duration, expires in LibDisp:IterateDispellableAuras(unit) do
    local spell = _G.GetSpellInfo(spellID)
    if IsSpellReady(spell) and (expires - eval.master.time) < (duration - math.random(1, 3)) then
      eval.spell = spell
      eval[3].target = unit
      eval.exe = funcs["Cast"]
      return true
    end
  end
end

-- DispelSelf
NeP.Actions:Add('dispelself', function(eval)
  return FindDispell(eval, 'player')
end)

-- Dispell all
NeP.Actions:Add('dispelall', function(eval)
  for _, Obj in pairs(NeP.OM:Get('Roster')) do
    if FindDispell(eval, Obj.key) then return true; end
  end
end)

-- Executes a users macro
NeP.Compiler:RegisterToken("/", function(eval, ref)
  ref.token = 'macro'
  eval.exe = funcs["Macro"]
end)

NeP.Actions:Add('macro', function()
  return true
end)

-- Executes a users macro
NeP.Actions:Add('function', function()
  return true
end)

-- Executes a users lib
NeP.Compiler:RegisterToken("@", function(eval, ref)
  ref.token = 'lib'
  eval.exe = funcs["Lib"]
end)

NeP.Actions:Add('lib', function()
  return true
end)

-- Cancel buff
NeP.Actions:Add('cancelbuff', function(eval)
  eval.exe = funcs["C_Buff"]
  return true
end)

-- Cancel Shapeshift Form
NeP.Actions:Add('cancelform', function(eval)
  eval.exe = _G.CancelShapeshiftForm
  return true
end)

-- Automated tauting
-- USAGE %taunt(SPELL)
NeP.Actions:Add('taunt', function(eval)
  if not IsSpellReady(eval[1].args) then return end
  for _, Obj in pairs(NeP.OM:Get('Enemy')) do
    if _G.UnitExists(Obj.key)
    and Obj.distance <= 30
    and NeP.Taunts:ShouldTaunt(Obj.key) then
      eval.spell = eval[1].args
      eval[3].target = Obj.key
      eval.exe = funcs["Cast"]
      return true
    end
  end
end)

-- Ress all dead
-- USAGE: %ressdead(SPELL)
NeP.Actions:Add('ressdead', function(eval)
  if not IsSpellReady(eval[1].args) then return end
  for _, Obj in pairs(NeP.OM:Get("Dead")) do
    if Obj.distance < 40
    and _G.UnitExists(Obj.key)
    and _G.UnitIsPlayer(Obj.key)
    and _G.UnitIsDeadOrGhost(Obj.key)
    and _G.UnitPlayerOrPetInParty(Obj.key) then
      eval.spell = eval[1].args
      eval[3].target = Obj.key
      eval.exe = funcs["Cast"]
      return true
    end
  end
end)

-- Pause
NeP.Actions:Add('pause', function(eval)
  eval.exe = function() return true end
  return true
end)

-- Items
local invItems = {
  ['head']    = 'HeadSlot',
  ['helm']    = 'HeadSlot',
  ['neck']    = 'NeckSlot',
  ['shoulder']  = 'ShoulderSlot',
  ['shirt']    = 'ShirtSlot',
  ['chest']    = 'ChestSlot',
  ['belt']    = 'WaistSlot',
  ['waist']    = 'WaistSlot',
  ['legs']    = 'LegsSlot',
  ['pants']    = 'LegsSlot',
  ['feet']    = 'FeetSlot',
  ['boots']    = 'FeetSlot',
  ['wrist']    = 'WristSlot',
  ['bracers']    = 'WristSlot',
  ['gloves']    = 'HandsSlot',
  ['hands']    = 'HandsSlot',
  ['finger1']    = 'Finger0Slot',
  ['finger2']    = 'Finger1Slot',
  ['trinket1']  = 'Trinket0Slot',
  ['trinket2']  = 'Trinket1Slot',
  ['back']    = 'BackSlot',
  ['cloak']    = 'BackSlot',
  ['mainhand']  = 'MainHandSlot',
  ['offhand']    = 'SecondaryHandSlot',
  ['weapon']    = 'MainHandSlot',
  ['weapon1']    = 'MainHandSlot',
  ['weapon2']    = 'SecondaryHandSlot',
  ['ranged']    = 'RangedSlot'
}

NeP.Compiler:RegisterToken("#", function(eval, ref)
  local temp_spell = ref.spell
  ref.token = 'item'
  eval.bypass = true
  if invItems[temp_spell] then
    local invItem = _G.GetInventorySlotInfo(invItems[temp_spell])
    temp_spell = _G.GetInventoryItemID("player", invItem) or ref.spell
    ref.invitem = true
    ref.invslot = invItem
  end
  ref.id = tonumber(temp_spell) or NeP.Core:GetItemID(temp_spell)
  local itemName, itemLink, _,_,_,_,_,_,_, texture = _G.GetItemInfo(ref.id)
  ref.spell = itemName or ref.spell
  ref.icon = texture
  ref.link = itemLink
  eval.exe = funcs["UseItem"]
end)

NeP.Actions:Add('item', function(eval)
  local item = eval[1]
  if item.id then
    --Iventory invItems
    if item.invitem then
      return select(2,_G.GetInventoryItemCooldown('player', item.invslot)) == 0
      and _G.IsUsableItem(item.link)
    --regular
    else
      return _G.GetItemSpell(item.spell)
      and _G.IsUsableItem(item.spell)
      and select(2,_G.GetItemCooldown(item.id)) == 0
      and _G.GetItemCount(item.spell) > 0
    end
  end
end)

-- regular spell
NeP.Compiler:RegisterToken("spell_cast", function(eval, ref)
  ref.spell = NeP.Spells:Convert(ref.spell, eval.master.name)
  ref.icon = select(3,_G.GetSpellInfo(ref.spell))
  ref.id = NeP.Core:GetSpellID(ref.spell)
  eval.exe = funcs["Cast"]
  ref.token = 'spell_cast'
end)

local C = NeP.Cache.Spells

-- this forces the parser to stop until this spel is ready
local function POLLING_PARSER(eval, nomana)
  if not eval.master.pooling then return end
  eval.master.halt = eval.master.halt or nomana or false
  if eval.master.halt then eval.master.halt_spell = eval[1].spell end
end

NeP.Actions:Add('spell_cast', function(eval)
  -- cached
  if C[eval[1].spell] ~= nil then return C[eval[1].spell]; end
  -- normal stuff
  local ready, nomana = IsSpellReady(eval[1].spell)
  C[eval[1].spell] = ready or false
  POLLING_PARSER(eval, nomana)
  return ready or false
end)
