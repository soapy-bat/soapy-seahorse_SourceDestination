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

function main()

  r.Undo_BeginBlock()
  r.PreventUIRefresh(1)

  local bool_success, item1GUID, item2GUID, firstOrSecond = so.GetItemsNearMouse(cursorBias)

  if bool_success then
    so.AuditionFade(preRoll, postRoll, bool_TransportAutoStop)
  else
    r.ShowMessageBox("Please hover the mouse over an item in order to audition fade.", "Audition unsuccessful", 0)
  end

  r.PreventUIRefresh(-1)
  r.UpdateArrange()
  r.Undo_EndBlock("Audition Crossfade", 0)

end

--------------------------------
-- main execution starts here --
--------------------------------

main()
