--[[

source-destination markers / gates: remove all source gates

This file is part of the soapy-seahorse package.
It requires the file "soapy-seahorse_Edit_Functions.lua"

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

---------------
-- variables --
---------------

local sourceLabelIn = "SRC_IN"
local sourceLabelOut = "SRC_OUT"

local r = reaper

local modulePath = ({r.get_action_context()})[2]:match("^.+[\\/]")
package.path = modulePath .. "?.lua"
local so = require("soapy-seahorse_Edit_Functions")

---------------
-- functions --
---------------

function Main()

    r.Undo_BeginBlock()
    r.PreventUIRefresh(1)

    so.RemoveSourceGates(0, sourceLabelIn, sourceLabelOut)

    r.PreventUIRefresh(-1)
    r.UpdateArrange()
    r.Undo_EndBlock("Remove All Source Gates", -1)
end

---------------------------
-- execution starts here --
---------------------------

Main()