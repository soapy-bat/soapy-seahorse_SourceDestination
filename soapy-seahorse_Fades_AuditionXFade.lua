--[[

source-destination fades: audition crossfade

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

local preRoll = 2                   -- audition pre-roll, in seconds
local postRoll = 2                  -- audition post-roll, in seconds
local cursorBias = 1                -- 0, ..., 2 /// 1: center of fade
local bool_TransportAutoStop = true -- stops transport automatically after auditioning
local bool_RemoveFade = false       -- experimental: auditions without the fade

---------------
-- variables --
---------------

local r = reaper

local auditioningItems1, auditioningItems2 = {}, {}
local fadeLen1, fadeLenAuto1, fadeDir1, fadeShape1
local fadeLen2, fadeLenAuto2, fadeDir2, fadeShape2

local modulePath = ({r.get_action_context()})[2]:match("^.+[\\/]")
package.path = modulePath .. "?.lua"
local so = require("soapy-seahorse_Fades_Functions")

----------
-- main --
----------

function main()

  r.Undo_BeginBlock()
  r.PreventUIRefresh(1)

  r.Main_OnCommand(42478, 0) -- play only lane under mouse

  local bool_success, item1GUID, item2GUID, firstOrSecond = so.GetItemsNearMouse(cursorBias)

  if bool_success then

    if bool_RemoveFade then

      auditioningItems1 = so.GetGroupedItems(item1GUID)
      auditioningItems2 = so.GetGroupedItems(item2GUID)
      fadeLen1, fadeLenAuto1, fadeDir1, fadeShape1, _ = so.GetFade(item1GUID, 1)
      fadeLen2, fadeLenAuto2, fadeDir2, fadeShape2, _ = so.GetFade(item2GUID, 2)

      for i = 1, #auditioningItems1 do
        so.SetFade(auditioningItems1[i], 1, 0, 0, 0, 0)
        so.SetFade(auditioningItems2[i], 2, 0, 0, 0, 0)
      end

    end
    
    -- in case a new instance of an audition script has started before other scripts were able to complete
    local tbl_safeItems1 = so.GetGroupedItems(item1GUID)
    local tbl_safeItems2 = so.GetGroupedItems(item2GUID)
    so.ToggleItemMute(tbl_safeItems1, {}, 0)
    so.ToggleItemMute(tbl_safeItems2, {}, 0)

    so.AuditionFade(preRoll, postRoll, bool_TransportAutoStop)
    CheckPlayState()
  else
    r.ShowMessageBox("Please hover the mouse over an item in order to audition fade.", "Audition unsuccessful", 0)
  end

  r.PreventUIRefresh(-1)
  r.UpdateArrange()
  r.Undo_EndBlock("Audition Crossfade", 0)

end

---------------
-- functions --
---------------

function CheckPlayState()

  local playState = r.GetPlayState()

  local bool_success = false
  local bool_exit = false
    
  if playState == 0 then -- Transport is stopped

    r.DeleteProjectMarker(0, 998, false)

    if bool_RemoveFade then
      for i = 1, #auditioningItems1 do
        so.SetFade(auditioningItems1[i], 1, fadeLen1, fadeLenAuto1, fadeDir1, fadeShape1)
        so.SetFade(auditioningItems2[i], 2, fadeLen2, fadeLenAuto2, fadeDir2, fadeShape2)
      end
    end

    bool_exit = true
  end

  if bool_exit then return end

  -- Schedule the function to run continuously
  r.defer(CheckPlayState)

end

--------------------------------
-- main execution starts here --
--------------------------------

main()
