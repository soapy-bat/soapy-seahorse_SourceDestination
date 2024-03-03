-- user settings
local preRoll = 0                   -- audition pre-roll, in seconds
local postRoll = 2                  -- audition post-roll, in seconds
local fadeLenMultiplier = 0         -- 0, ..., 1 /// 0.5: center of fade
local bool_TransportAutoStop = true -- stops transport automatically after auditioning

-- variables
local r = reaper

local itemGUID_temp

local modulePath = ({r.get_action_context()})[2]:match("^.+[\\/]")
package.path = modulePath .. "?.lua"
local so = require("soapy-seahorse_Fades_Functions")

------------------------------------------------

function main()

  r.Undo_BeginBlock()
  r.PreventUIRefresh(1)

  local bool_success, item1GUID, item2GUID, firstOrSecond = so.GetItemsNearMouse(fadeLenMultiplier)

  if bool_success then

    so.ToggleItemMuteState(item1GUID, 1) -- 1 = extend, -1 = restore
    itemGUID_temp = item1GUID

    so.AuditionFade(preRoll, postRoll, bool_TransportAutoStop)

    CheckPlayState()

  else
    r.ShowMessageBox("Please hover the mouse over an item in order to audition fade.", "Audition unsuccessful", 0)
  end

  r.PreventUIRefresh(-1)
  r.UpdateArrange()
  r.Undo_EndBlock("Audition X Out", 0)

end

------------------------------------------------

function CheckPlayState()

  local playState = r.GetPlayState()

  local bool_success = false
  local bool_exit = false
    
  if playState == 0 then -- Transport is stopped

    bool_success = so.ToggleItemMuteState(itemGUID_temp, -1)

    if not bool_success then
      r.ShowMessageBox("Mute state change unsuccessful.", "sorry!", 0)
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