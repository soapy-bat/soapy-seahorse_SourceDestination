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

---------------
-- variables --
---------------

local r = reaper
local sm = {}

local modulePath = ({r.get_action_context()})[2]:match("^.+[\\/]")
package.path = modulePath .. "soapy-seahorse_functions/?.lua"
local sf = require("soapy-seahorse_Edit_Functions")

modulePath = ({r.get_action_context()})[2]:match("^.+[\\/]")
package.path = modulePath .. "soapy-seahorse_functions/?.lua"
local st = require("soapy-seahorse_Settings")

local bool_TargetItemUnderMouse, bool_TargetMouseInsteadOfCursor, markerLabel_SrcIn, markerLabel_SrcOut, markerLabel_DstIn, markerLabel_DstOut, markerColor_Src, markerColor_Dst, markerIndex_DstIn, markerIndex_DstOut, srcCol_R, srcCol_G, srcCol_B, dstCol_R, dstCol_G, dstCol_B

function GetSettings()

    local tbl_Settings = st.GetSettings()

    bool_TargetItemUnderMouse = tonumber(tbl_Settings.bool_GatesTargetItemUnderMouse)
    bool_TargetMouseInsteadOfCursor = tonumber(tbl_Settings.bool_GatesTargetMouseInsteadOfCursor)

    markerLabel_SrcIn = tbl_Settings.markerLabel_SrcIn
    markerLabel_SrcOut = tbl_Settings.markerLabel_SrcOut
    markerLabel_DstIn = tbl_Settings.markerLabel_DstIn
    markerLabel_DstOut = tbl_Settings.markerLabel_DstOut
    markerIndex_DstIn = tonumber(tbl_Settings.markerIndex_DstIn)
    markerIndex_DstOut = tonumber(tbl_Settings.markerIndex_DstOut)
    markerColor_Src = tbl_Settings.markerColor_Src
    markerColor_Dst = tbl_Settings.markerColor_Dst

    srcCol_R, srcCol_G, srcCol_B = sm.SplitRGB(markerColor_Src)
    dstCol_R, dstCol_G, dstCol_B = sm.SplitRGB(markerColor_Dst)

end

---------------
-- functions --
---------------

function sm.SetSourceGate(markerType)

    r.Undo_BeginBlock()
    r.PreventUIRefresh(1)

    local markerLabel
    if markerType == 1 then markerLabel = markerLabel_SrcIn
    elseif markerType == 2 then markerLabel = markerLabel_SrcOut
    else sm.ErrMsg() return end

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
            local _, currentLabel, _, _, _ = r.GetTakeMarker(activeTake, i)
            if currentLabel == markerLabel then
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
        r.SetTakeMarker(activeTake, -1, markerLabel, cursorPosInTake, r.ColorToNative(srcCol_R, srcCol_G, srcCol_B)|0x1000000)

    end

    r.PreventUIRefresh(-1)
    r.UpdateArrange()
    if markerType == 1 then r.Undo_EndBlock("Create Sync In Marker", -1)
    elseif markerType == 2 then r.Undo_EndBlock("Create Sync Out Marker", -1)
    else sm.ErrMsg() return end

end

----------------------------------------------------------------------

function sm.SetDstGate(markerType) -- thanks chmaha

    r.Undo_BeginBlock()

    local markerLabel, markerIndex
    if markerType == 1 then
        markerLabel = markerLabel_DstIn
        markerIndex = markerIndex_DstIn
    elseif markerType == 2 then
        markerLabel = markerLabel_DstOut
        markerIndex = markerIndex_DstOut
    else sm.ErrMsg() return end

    local cursorPos = (r.GetPlayState() == 0) and r.GetCursorPosition() or r.GetPlayPosition()
    r.DeleteProjectMarker(0, markerIndex, false)
    r.AddProjectMarker2(0, false, cursorPos, 0, markerLabel, markerIndex, r.ColorToNative(dstCol_R, dstCol_G, dstCol_B)| 0x1000000)

    if markerType == 1 then r.Undo_EndBlock("Create Destination In", -1)
    elseif markerType == 2 then r.Undo_EndBlock("Create Destination Out", -1)
    else sm.ErrMsg() return end

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

----------------------------------------------------------------------

function sm.SplitRGB(rgbString)
    -- Split the string by commas
    local col_R, col_G, col_B = rgbString:match('(%d+),(%d+),(%d+)')

    col_R = tonumber(col_R)
    col_G = tonumber(col_G)
    col_B = tonumber(col_B)

    return col_R, col_G, col_B
end

----------------------------------------------------------------------

function sm.ErrMsg()

    r.ShowMessageBox("Gate Creation unsuccessful", "Something went wrong.", 0)

end

--------------
-- required --
--------------
GetSettings()
return sm