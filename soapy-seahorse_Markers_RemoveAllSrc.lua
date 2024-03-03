--[[

source-destination markers / gates: remove all source gates

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

local markerLabelIn = "SRC_IN"
local markerLabelOut = "SRC_OUT"

---------------
-- functions --
---------------

function RemoveAllSourceGates()

  r.Main_OnCommand(40182, 0) -- Select All

  local numSelectedItems = r.CountSelectedMediaItems(0)
  
   -- Iterate through selected items
   for i = 0, numSelectedItems - 1 do

        -- Get the active media item
        local mediaItem = r.GetSelectedMediaItem(0, i)
        
        if mediaItem then
            -- Get the active take
            local activeTake = r.GetActiveTake(mediaItem)
        
            if activeTake then
                -- Remove existing MarkerLabel markers
                local numMarkers = r.GetNumTakeMarkers(activeTake)
                for i = numMarkers, 0, -1 do
                    local _, markerType, _, _, _ = r.GetTakeMarker(activeTake, i)
                    if markerType == markerLabelIn then
                        r.DeleteTakeMarker(activeTake, i)
                    end
                    if markerType == markerLabelOut then
                        r.DeleteTakeMarker(activeTake, i)
                    end
                end
            end
        end
    end
  
  r.Main_OnCommand(40289, 0) -- Deselect all items
  
end

---------------------------
-- execution starts here --
---------------------------

r.Undo_BeginBlock()

RemoveAllSourceGates()

r.UpdateArrange()
r.Undo_EndBlock("Remove All Source Gates", -1)
