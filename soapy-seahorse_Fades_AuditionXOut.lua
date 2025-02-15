--[[

source-destination fades: audition right side, mute left side

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

local preRoll = 0                    -- audition pre-roll, in seconds
local postRoll = 2                   -- audition post-roll, in seconds
local cursorBias = 0                 -- 0, ..., 2 /// 1: center of fade
local bool_TransportAutoStop = true  -- stops transport automatically after auditioning
local bool_KeepCursorPosition = true -- false: script will leave edit cursor at the center of the fade
local bool_RemoveFade = false        -- auditions without the fade

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

function AuditionFade_CrossfadeOut(preRoll, postRoll, timeAmount, cursorBias, bool_TransportAutoStop, bool_KeepCursorPosition, bool_RemoveFade)

  local tbl_mutedItems = {}
  local auditioningItems = {}
  local fadeLen, fadeLenAuto, fadeDir, fadeShape

  function AuditionFade_Main()

    r.Undo_BeginBlock()
    r.PreventUIRefresh(1)

    local curPos = r.GetCursorPosition()

    r.Main_OnCommand(42478, 0) -- play only lane under mouse

    local bool_success, item1GUID, item2GUID, firstOrSecond = so.GetItemsNearMouse(cursorBias)

    if bool_success then

      if bool_RemoveFade then

        auditioningItems = so.GetGroupedItems(item2GUID)
        fadeLen, fadeLenAuto, fadeDir, fadeShape, _ = so.GetFade(item2GUID, 2)

        for i = 1, #auditioningItems do
          so.SetFade(auditioningItems[i], 2, 0, 0, 0, 0)
        end

      end

      local _, tbl_itemsToMute = so.GetNeighbors(item2GUID, 2, 1)

      -- in case a new instance of an audition script has started before other scripts were able to complete
      -- so.ToggleItemMute() will get the grouped items anyway, so we only pass along one item:
      so.ToggleItemMute({item2GUID}, {}, 0)

      -- no need to pass along safe items:
      tbl_mutedItems = so.ToggleItemMute(tbl_itemsToMute, {}, 1)

      so.AuditionFade(preRoll, postRoll, bool_TransportAutoStop)

      CheckPlayState()

    else
      r.ShowMessageBox("Please hover the mouse over an item in order to audition fade.", "Audition unsuccessful", 0)
    end

    if bool_KeepCursorPosition then
      r.SetEditCurPos(curPos, false, false)
    end

    r.Undo_EndBlock("Audition X Out", 0)

  end

  ---------------
  -- functions --
  ---------------

  function CheckPlayState()

    r.PreventUIRefresh(1)

    local playState = r.GetPlayState()

    local bool_exit = false

    if playState == 0 then -- Transport is stopped

      so.ToggleItemMute(tbl_mutedItems, {}, 0)
      r.DeleteProjectMarker(0, 998, false)

      if bool_RemoveFade then
        for i = 1, #auditioningItems do
          so.SetFade(auditioningItems[i], 2, fadeLen, fadeLenAuto, fadeDir, fadeShape)
        end
      end

      r.PreventUIRefresh(-1)
      r.UpdateArrange()

      bool_exit = true
    end

    if bool_exit then return end

    -- Schedule the function to run continuously
    r.defer(CheckPlayState)

  end

  AuditionFade_Main()

end

--------------------------------
-- main execution starts here --
--------------------------------

AuditionFade_CrossfadeOut(preRoll, postRoll, _, cursorBias, bool_TransportAutoStop, bool_KeepCursorPosition, bool_RemoveFade)