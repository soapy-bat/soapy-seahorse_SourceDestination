--[[

source-destination markers / gates: set source out

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
local markerLabel = "SRC_OUT"
local markerColor = r.ColorToNative(255,0,0)

---------------
-- functions --
---------------

function CreateSyncMarker()

    r.Main_OnCommand(40034, 0) -- Item grouping: Select all items in groups

    local numSelectedItems = r.CountSelectedMediaItems(0)

    -- Iterate through selected items
    for i = 0, numSelectedItems - 1 do

        -- Get the active media item
        local mediaItem = r.GetSelectedMediaItem(0, i)
        if not mediaItem then return end

        -- Get the active take
        local activeTake = r.GetActiveTake(mediaItem)

        if not activeTake then return end
        -- Remove existing MarkerLabel markers
        local numMarkers = r.GetNumTakeMarkers(activeTake)
        for i = numMarkers, 0, -1 do
            local _, markerType, _, _, _ = r.GetTakeMarker(activeTake, i)
            if markerType == markerLabel then
                r.DeleteTakeMarker(activeTake, i)
            end
        end

        -- Get the relative cursor position within the active take, even when the playhead is moving
        local cursorPos = (r.GetPlayState() == 0) and r.GetCursorPosition() or r.GetPlayPosition()
        local takeStartPos = r.GetMediaItemInfo_Value(mediaItem, "D_POSITION")
        local cursorPosInTake = cursorPos - takeStartPos + r.GetMediaItemTakeInfo_Value(activeTake, "D_STARTOFFS")

        -- Add a take marker at the cursor position
        r.SetTakeMarker(activeTake, -1, markerLabel, cursorPosInTake, markerColor|0x1000000)

    end
end

---------------------------
-- execution starts here --
---------------------------

r.Undo_BeginBlock()

CreateSyncMarker()

r.UpdateArrange()  
r.Undo_EndBlock("Create Sync Out Marker", -1)
