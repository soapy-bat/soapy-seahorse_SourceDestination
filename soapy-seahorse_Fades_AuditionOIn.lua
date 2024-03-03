-- user settings
local preRoll = 2                   -- audition pre-roll, in seconds
local postRoll = 2                  -- audition post-roll, in seconds
local extendedTime = 2              -- time that the items get extended by, in seconds
local fadeLenMultiplier = 1         -- 0, ..., 1 /// 0.5: center of fade
local bool_TransportAutoStop = true -- stops transport automatically after auditioning

-- variables
local r = reaper

local modulePath = ({r.get_action_context()})[2]:match("^.+[\\/]")
package.path = modulePath .. "?.lua"
local so = require("soapy-seahorse_Fades_Functions")

local item1GUID_temp, item2GUID_temp, extendedTime_temp, targetItem_temp

local targetItem = 1

------------------------------------------------

function main()

  r.Undo_BeginBlock()
  r.PreventUIRefresh(1)

  local bool_success, item1GUID, item2GUID, firstOrSecond = so.GetItemsNearMouse(fadeLenMultiplier)

  if bool_success then

    local autoXFadeState = r.GetToggleCommandState(40041)
    local trimBehindState = r.GetToggleCommandState(41117)

    so.SetTrimXFadeState(autoXFadeState, trimBehindState)

    bool_success, item1GUID_temp, item2GUID_temp, extendedTime_temp, targetItem_temp = so.ItemExtender(item1GUID, item2GUID, extendedTime, targetItem, 1)
    
    if not bool_success then
      r.ShowMessageBox("ItemExtender unsuccessful.", "sorry!", 0)
      return
    end

    so.AuditionFade(preRoll, postRoll, bool_TransportAutoStop)

    CheckPlayState()

    so.ResetTrimXFadeState(autoXFadeState, trimBehindState)

  else
    r.ShowMessageBox("Please hover the mouse over an item in order to audition fade.", "Audition unsuccessful", 0)
  end

  r.PreventUIRefresh(-1)
  r.UpdateArrange()
  r.Undo_EndBlock("Audition Original In", 0)

end

------------------------------------------------

function CheckPlayState()

  local playState = r.GetPlayState()

  local bool_success = false
  local bool_exit = false
    
  if playState == 0 then -- Transport is stopped

    bool_success = so.ItemExtender(item1GUID_temp, item2GUID_temp, extendedTime_temp, targetItem_temp, -1)
    
    if not bool_success then
      r.ShowMessageBox("Item restoration unsuccessful.", "sorry!", 0)
      return
    end

    bool_exit = true
  end

  if bool_exit then return end

  -- Schedule the function to run continuously
  r.defer(CheckPlayState)

end

------------------------------------------------

main()
