--[[

source-destination edit: 3 point assembly

This file is part of the soapy-seahorse package.

(C) 2024 the soapy zoo

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

-- true = yes, false = no

local xfadeLen = 0.05                           -- default: 50 milliseconds (0.05)

local bool_AutoCrossfade = true                 -- fade newly edited items

local bool_moveDstGateAfterEdit = true          -- move destination gate to end of last pasted item (recommended)

local bool_removeAllSourceGates = false         -- remove all source gates after the edit

local bool_TargetItemUnderMouse = false         -- select item under mouse (no click to select required)


---------------
-- variables --
---------------

local r = reaper

local sourceLabelIn = "SRC_IN"
local sourceLabelOut = "SRC_OUT"
local destinationLabelIn = "DST_IN"
local destinationIdxIn = 996

local modulePath = ({r.get_action_context()})[2]:match("^.+[\\/]")
package.path = modulePath .. "?.lua"
local so = require("soapy-seahorse_Edit_Functions")

----------
-- main --
----------

function main()

    so.ThreePointAssembly(bool_AutoCrossfade, bool_moveDstGateAfterEdit, bool_removeAllSourceGates, bool_TargetItemUnderMouse, destinationIdxIn, xfadeLen)

end

main()
