--[[

source-destination markers / gates: set destination in

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

---------------
-- variables --
---------------

local r = reaper
local markerLabel = "DST_IN"
local markerColor = r.ColorToNative(22, 141, 195)

---------------
-- functions --
---------------

function main() -- thanks chmaha
    local cursorPos = (r.GetPlayState() == 0) and r.GetCursorPosition() or r.GetPlayPosition()
    r.DeleteProjectMarker(0, 996, false)
    r.AddProjectMarker2(0, false, cursorPos, 0, markerLabel, 996, markerColor | 0x1000000)
end

---------------------------
-- execution starts here --
---------------------------

r.Undo_BeginBlock()
main()
r.Undo_EndBlock("Set Destination In", -1)
