-- user settings
local preRoll = 2                   -- audition pre-roll, in seconds
local postRoll = 2                  -- audition post-roll, in seconds
local fadeLenMultiplier = 0.5       -- 0, ..., 1 /// 0.5: center of fade
local bool_TransportAutoStop = true -- stops transport automatically after auditioning

-- variables
local r = reaper

local modulePath = ({r.get_action_context()})[2]:match("^.+[\\/]")
package.path = modulePath .. "?.lua"
local so = require("soapy-seahorse_Fades_Functions")

------------------------------------------------

function main()

  r.Undo_BeginBlock()
  r.PreventUIRefresh(1)

  local bool_success, item1GUID, item2GUID, firstOrSecond = so.GetItemsNearMouse(fadeLenMultiplier)

  if bool_success then
    so.AuditionFade(preRoll, postRoll, bool_TransportAutoStop)
  else
    r.ShowMessageBox("Please hover the mouse over an item in order to audition fade.", "Audition unsuccessful", 0)
  end

  r.PreventUIRefresh(-1)
  r.UpdateArrange()
  r.Undo_EndBlock("Audition Crossfade", 0)

end

------------------------------------------------

main()
