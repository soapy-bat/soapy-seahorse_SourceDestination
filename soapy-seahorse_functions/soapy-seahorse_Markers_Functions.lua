--[[

source-destination markers: functions

This file is part of the soapy-seahorse package.
It is required by the various marker scripts.

(C) 2024 the soapy zoo
thanks: chmaha, fricia, X-Raym, GPT3.5

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

local bool_TargetItemUnderMouse = false        -- select item under mouse (no click to select required)
local bool_TargetMouseInsteadOfCursor = false  -- place src gate at mouse position instead of edit cursor position

---------------
-- variables --
---------------

local r = reaper

local modulePath = ({r.get_action_context()})[2]:match("^.+[\\/]")
package.path = modulePath .. "soapy-seahorse_functions/?.lua"
local sf = require("soapy-seahorse_Edit_Functions")

local sm = {}

local markerLabel_SrcIn = "SRC_IN"
local markerLabel_SrcOut = "SRC_OUT"
local markerLabel_DstIn = "DST_IN"
local markerLabel_DstOut = "DST_OUT"
local markerColor_Src = r.ColorToNative(255,0,0)
local markerColor_Dst = r.ColorToNative(22, 141, 195)

---------------
-- functions --
---------------

function sm.SetSrcIn()

    r.Undo_BeginBlock()

    if bool_TargetItemUnderMouse then
        r.Main_OnCommand(40289, 0) -- Item: Unselect (clear selection of) all items
        r.Main_OnCommand(40528, 0) -- Item: Select item under mouse cursor
    end

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
            if markerType == markerLabel_SrcIn then
                r.DeleteTakeMarker(activeTake, i)
            end
        end

        -- Get the relative cursor position within the active take, even when the playhead is moving
        local cursorPos

        if bool_TargetMouseInsteadOfCursor then
            _, cursorPos = r.BR_ItemAtMouseCursor()
        else
            cursorPos = (r.GetPlayState() == 0) and r.GetCursorPosition() or r.GetPlayPosition()
        end

        local takeStartPos = r.GetMediaItemInfo_Value(mediaItem, "D_POSITION")
        local cursorPosInTake = cursorPos - takeStartPos + r.GetMediaItemTakeInfo_Value(activeTake, "D_STARTOFFS")


        -- Add a take marker at the cursor position
        r.SetTakeMarker(activeTake, -1, markerLabel_SrcIn, cursorPosInTake, markerColor_Src|0x1000000)

    end

    r.UpdateArrange()
    r.Undo_EndBlock("Create Sync In Marker", -1)

end

----------------------------------------------------------------------

function sm.SetSrcOut()

    r.Undo_BeginBlock()

    if bool_TargetItemUnderMouse then
        r.Main_OnCommand(40289, 0) -- Item: Unselect (clear selection of) all items
        r.Main_OnCommand(40528, 0) -- Item: Select item under mouse cursor
    end

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
            if markerType == markerLabel_SrcOut then
                r.DeleteTakeMarker(activeTake, i)
            end
        end

        -- Get the relative cursor position within the active take, even when the playhead is moving
        local cursorPos

        if bool_TargetMouseInsteadOfCursor then
            _, cursorPos = r.BR_ItemAtMouseCursor()
        else
            cursorPos = (r.GetPlayState() == 0) and r.GetCursorPosition() or r.GetPlayPosition()
        end

        local takeStartPos = r.GetMediaItemInfo_Value(mediaItem, "D_POSITION")
        local cursorPosInTake = cursorPos - takeStartPos + r.GetMediaItemTakeInfo_Value(activeTake, "D_STARTOFFS")

        -- Add a take marker at the cursor position
        r.SetTakeMarker(activeTake, -1, markerLabel_SrcOut, cursorPosInTake, markerColor_Src|0x1000000)

    end

    r.UpdateArrange()
    r.Undo_EndBlock("Create Sync Out Marker", -1)

end

----------------------------------------------------------------------

function sm.SetDstIn() -- thanks chmaha
    r.Undo_BeginBlock()

    local cursorPos = (r.GetPlayState() == 0) and r.GetCursorPosition() or r.GetPlayPosition()
    r.DeleteProjectMarker(0, 996, false)
    r.AddProjectMarker2(0, false, cursorPos, 0, markerLabel_DstIn, 996, markerColor_Dst | 0x1000000)

    r.Undo_EndBlock("Set Destination In", -1)
end

----------------------------------------------------------------------

function sm.SetDstOut()
    r.Undo_BeginBlock()

    local cursorPos = (r.GetPlayState() == 0) and r.GetCursorPosition() or r.GetPlayPosition()
    r.DeleteProjectMarker(0, 997, false)
    r.AddProjectMarker2(0, false, cursorPos, 0, markerLabel_DstOut, 997, markerColor_Dst | 0x1000000)

    r.Undo_EndBlock("Set Destination Out", -1)
end

----------------------------------------------------------------------

function sm.RemoveAllSourceGates()

    r.Undo_BeginBlock()
    r.PreventUIRefresh(1)

    sf.RemoveSourceGates(0, markerLabel_SrcIn, markerLabel_SrcOut)

    r.PreventUIRefresh(-1)
    r.UpdateArrange()
    r.Undo_EndBlock("Remove All Source Gates", -1)
end

--------------
-- required --
--------------

return sm