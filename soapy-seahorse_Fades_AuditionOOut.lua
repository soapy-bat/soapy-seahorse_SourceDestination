--[[

source-destination fades: audition out original material (left side extender)

This script is part of the soapy-seahorse package.
It requires the file "soapy-seahorse_Fades_Functions.lua"

(C) 2024 the soapy zoo
copyleft: chmaha
thanks: fricia, X-Raym, GPT3.5

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
You should have received a copy of the GNU General Public License
along with this program. If not, see <https://www.gnu.org/licenses/>.
]]

-------------------
-- user settings --
-------------------

local preRoll = 2                    -- audition pre-roll, in seconds
local postRoll = 2                   -- audition post-roll, in seconds
local timeAmount = 2                 -- time that the items get extended by, in seconds
local cursorBias = 1.5               -- 0, ..., 2 /// 1: center of fade
local bool_TransportAutoStop = true  -- stops transport automatically after auditioning
local bool_KeepCursorPosition = true -- false: script will leave edit cursor at the center of the fade

---------------
-- variables --
---------------

local r = reaper

local modulePath = ({r.get_action_context()})[2]:match("^.+[\\/]")
package.path = modulePath .. "?.lua"
local so = require("soapy-seahorse_Fades_Functions")

----------
-- main --
----------

function AuditionFade_OriginalOut(preRoll, postRoll, timeAmount, cursorBias, bool_TransportAutoStop, bool_KeepCursorPosition)

  local item1GUID_temp, item2GUID_temp, timeAmount_temp, targetItem_temp
  local tbl_mutedItems = {}
  local targetItem = 2
  local rippleStateAll, rippleStatePer

  function AuditionOriginal_Main()

    r.Undo_BeginBlock()
    r.PreventUIRefresh(1)

    local curPos = r.GetCursorPosition()

    r.Main_OnCommand(42478, 0) -- play only lane under mouse

    local bool_success, item1GUID, item2GUID = so.GetItemsNearMouse(cursorBias)

    if bool_success then

      rippleStateAll, rippleStatePer = so.SaveEditStates() -- save autocrossfade state

      -- in case a new instance of an audition script has started before other scripts were able to complete
      -- so.ToggleItemMute() will get the grouped items anyway, so we only pass along one item:
      so.ToggleItemMute({item2GUID}, {}, 0)

      item1GUID_temp, item2GUID_temp, timeAmount_temp, targetItem_temp, tbl_mutedItems = so.ItemExtender(item1GUID, item2GUID, timeAmount, targetItem, 1)

      so.AuditionFade(preRoll, postRoll, bool_TransportAutoStop)

      CheckPlayState()
      
    else
      r.ShowMessageBox("Please hover the mouse over an item in order to audition fade.", "Audition unsuccessful", 0)
    end

    if bool_KeepCursorPosition then
      r.SetEditCurPos(curPos, false, false)
    end

    r.Undo_EndBlock("Audition Original Out", 0)

  end

  ---------------
  -- functions --
  ---------------

  function CheckPlayState()

    r.PreventUIRefresh(1)

    local playState = r.GetPlayState()

    local bool_exit = false

    if playState == 0 then -- Transport is stopped

      so.ItemExtender(item1GUID_temp, item2GUID_temp, timeAmount_temp, targetItem_temp, -1, tbl_mutedItems)

      r.DeleteProjectMarker(0, 998, false)

      so.RestoreEditStates(rippleStateAll, rippleStatePer)

      r.PreventUIRefresh(-1)
      r.UpdateArrange()

      bool_exit = true
    end

    if bool_exit then return end

    -- Schedule the function to run continuously
    r.defer(CheckPlayState)

  end

  AuditionOriginal_Main()

end

--------------------------------
-- main execution starts here --
--------------------------------

AuditionFade_OriginalOut(preRoll, postRoll, timeAmount, cursorBias, bool_TransportAutoStop, bool_KeepCursorPosition)
