--[[

source-destination edit: functions

This file is part of the soapy-seahorse package.
It is required by the various edit scripts.

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

-- true = yes, false = no

local xfadeLen = 0.05                           -- default: 50 milliseconds (0.05)

local bool_AutoCrossfade = true                 -- fade newly edited items

local bool_MoveDstGateAfterEdit = true          -- move destination gate to end of last pasted item (recommended)

local bool_RemoveAllSourceGates = false         -- remove all source gates after the edit

local bool_TargetItemUnderMouse = false         -- select item under mouse (no click to select required)

local bool_KeepLaneSolo = true                  -- if false, lane solo jumps to comp lane after the edit
                                                -- if multiple lanes were soloed, only last soloed lane will be selected

---------------
-- variables --
---------------

local r = reaper
local so = {}

local srcLabelIn = "SRC_IN"
local srcLabelOut = "SRC_OUT"
local dstLabelIn = "DST_IN"
local dstIdxIn = 996

---------------
-- functions --
---------------

function so.ThreePointEdit(bool_Ripple)

    r.Undo_BeginBlock()
    r.PreventUIRefresh(1)

    ---######### START ##########---

    ---##### buffer and set various edit states #####---

    local saveXFadeState = r.NamedCommandLookup("_SWS_SAVEXFD")
    r.Main_OnCommand(saveXFadeState, 1) -- SWS: Save auto crossfade state

    local rippleStateAll, rippleStatePer, trimContentState = so.PrepareEditStates()

    if bool_Ripple then
        if rippleStatePer == 0 then
            r.Main_OnCommand(41990, 0) -- Set ripple editing per track on
        end
        r.Main_OnCommand(41120, 1)     -- Options: Enable trim content behind media items when editing
    end

    ---##### get coordinates #####---

    local cursorPos_origin = r.GetCursorPosition()

    if bool_TargetItemUnderMouse then
        r.Main_OnCommand(40289, 0) -- Item: Unselect (clear selection of) all items
        r.Main_OnCommand(40528, 0) -- Item: Select item under mouse cursor
    end

    local sourceItem = r.GetSelectedMediaItem(0,0)

    local sourceGateIn = so.GetSourceGate(sourceItem, srcLabelIn)
    if not sourceGateIn then return end

    local sourceGateOut = so.GetSourceGate(sourceItem, srcLabelOut)
    if not sourceGateOut then return end

    local targetTrack = r.GetMediaItem_Track(r.GetSelectedMediaItem(0, 0))

    local tbl_PlayingLanes
    if bool_KeepLaneSolo then
        tbl_PlayingLanes = so.GetLanesPlaying(targetTrack)
    end

    ---##### src copy routine #####---

    r.SetOnlyTrackSelected(targetTrack)

    so.SetTimeSelectionToSourceGates(sourceGateIn, sourceGateOut) -- time selection is used to copy items

    r.Main_OnCommand(40060, 0) -- copy selected area of items (source material)

    r.Main_OnCommand(40289, 0) -- Deselect all items
    r.Main_OnCommand(40020, 0) -- Time Selection: Remove

    ---##### paste source to destination #####---

    if bool_Ripple then
        so.ToggleLockItemsInSourceLanes(1)
    end

    so.PasteToTopLane(dstIdxIn)           -- paste source material

    if bool_Ripple then
        so.ToggleLockItemsInSourceLanes(0)
    end

    ---##### cleanup: set new dst gate, set xfade, clean up src gates #####---

    local cursorPos_end = r.GetCursorPosition()

    if bool_AutoCrossfade then
        -- go to start of pasted item, set fade
        r.GoToMarker(0, dstIdxIn, false)
        so.SetCrossfade(xfadeLen)
    end

    so.RemoveSourceGates(-1, srcLabelIn, srcLabelOut)    -- remove src gates from newly pasted material

    if not bool_AutoCrossfade then
        r.Main_OnCommand(40020, 0) -- Time Selection: Remove
    end

    if bool_MoveDstGateAfterEdit then
        r.SetEditCurPos(cursorPos_end, false, false) -- go to end of pasted item
        so.SetDstGateIn(dstLabelIn, dstIdxIn)  -- move destination gate in to end of pasted material (assembly line style)
    end

    if bool_RemoveAllSourceGates then
        so.RemoveSourceGates(0, srcLabelIn, srcLabelOut)
    end

    r.Main_OnCommand(40289, 0) -- Deselect all items
    r.SetEditCurPos(cursorPos_origin, false, false) -- go to original cursor position

    if bool_KeepLaneSolo then
        so.SetLanesPlaying(targetTrack, tbl_PlayingLanes)
    end

    so.ResetEditStates(rippleStateAll, rippleStatePer, trimContentState)

    local restoreXFadeState = r.NamedCommandLookup("_SWS_RESTOREXFD")
    r.Main_OnCommand(restoreXFadeState, 0) -- SWS: Restore auto crossfade state

    ---######### END ##########---

    r.PreventUIRefresh(-1)
    r.UpdateArrange()
    if bool_Ripple then
        r.Undo_EndBlock("ReaPyr 3 point ripple", -1)
    else
        r.Undo_EndBlock("ReaPyr 3 point edit", -1)
    end
end

-----------
-- utils --
-----------


function so.GetLanesPlaying(selTrack)

    local tbl_PlayingLanes = {}

    local numLanes =  r.GetMediaTrackInfo_Value(selTrack, "I_NUMFIXEDLANES")

    for i = 0, numLanes - 1 do

        local parmName = tostring("C_LANEPLAYS:" .. i)
        local activeLane = r.GetMediaTrackInfo_Value(selTrack, parmName)

        if activeLane == 1 or activeLane == 2 then
            table.insert(tbl_PlayingLanes, i)
        end

    end

    return tbl_PlayingLanes

end

-------------------------------------------------------------------

function so.SetLanesPlaying(selTrack, tbl_PlayingLanes)

    local numLanes =  r.GetMediaTrackInfo_Value(selTrack, "I_NUMFIXEDLANES")

    if #tbl_PlayingLanes > 1 then

        for i = 0, numLanes - 1 do

            local parmName = tostring("C_LANEPLAYS:" .. i)
            local laneIsActive = false

            for h = 1, #tbl_PlayingLanes do
                if i == tbl_PlayingLanes[h] then
                    laneIsActive = true
                else
                    laneIsActive = false
                end
            end

            if laneIsActive then
                r.SetMediaTrackInfo_Value(selTrack, parmName, 2)
            else
                r.SetMediaTrackInfo_Value(selTrack, parmName, 0)
            end

        end

    elseif #tbl_PlayingLanes == 1 then

        local parmName = tostring("C_LANEPLAYS:" .. tbl_PlayingLanes[1])
        r.SetMediaTrackInfo_Value(selTrack, parmName, 1)

    end

end

-------------------------------------------------------------------

function so.GetSourceGate(sourceItem_rx, markerLabel_rx) -- Find SRC_OUT marker
    local sourceItem = sourceItem_rx
    local markerLabel = markerLabel_rx

    local sourceMarkerPos = so.GetTakeMarkerPositionByName(sourceItem, markerLabel)

    if sourceMarkerPos then
        return sourceMarkerPos
    else
        r.ShowMessageBox(markerLabel .. " not found.", "Take marker not found", 0)
        return
    end
end

-------------------------------------------------------------------

function so.GetTakeMarkerPositionByName(sourceItem_rx, markerName_rx)

    local sourceItem = sourceItem_rx
    local markerName = markerName_rx

    r.SetMediaItemSelected(sourceItem, true)

    r.Main_OnCommand(40034, 0) -- Item grouping: Select all items in groups

    local numSelectedItems = r.CountSelectedMediaItems(0)

     -- Iterate through selected items
     for i = 0, numSelectedItems - 1 do
        local selectedItem = r.GetSelectedMediaItem(0, i)
        local take = r.GetActiveTake(selectedItem)

        local numMarkers = r.GetNumTakeMarkers(take)

        for k = 0, numMarkers - 1 do
            local pos, markerName_, _  = r.GetTakeMarker(take, k)
            if markerName_ == markerName then
                -- Get necessary locations
                local itemPos = r.GetMediaItemInfo_Value(selectedItem, "D_POSITION")
                -- take markers are referenced from the item source media, not from the item edges:
                local itemEdgeOffset =  r.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
                local newMarkerPos = itemPos + pos - itemEdgeOffset
                return newMarkerPos
            end
        end
    end
end

-------------------------------------------------------------------


-- Function to set a Time Selection based on given start and end points

function so.SetTimeSelectionToSourceGates(srcStart, srcEnd)

    if srcEnd <= srcStart then return false end

    r.GetSet_LoopTimeRange2(0, true, false, srcStart, srcEnd, true)

end

-------------------------------------------------------------------

function so.PasteToTopLane(dstInIdx_rx)

    local dstInIdx = dstInIdx_rx

    r.GoToMarker(0, dstInIdx, false)
    r.Main_OnCommand(42790, 0) -- play only first lane
    r.Main_OnCommand(43098, 0) -- show/play only one lane
    r.Main_OnCommand(42398, 0) -- Items: paste items/tracks
    r.Main_OnCommand(43099, 0) -- show/play all lanes

end

-------------------------------------------------------------------

function so.SetDstGateIn(dstInLabel_rx, dstInIdx_rx)       -- thanks chmaha <3

    local dstInLabel = dstInLabel_rx
    local dstInIdx = dstInIdx_rx

    local markerLabel = dstInLabel
    local markerColor = r.ColorToNative(22, 141, 195)

    local cursorPosition = (r.GetPlayState() == 0) and r.GetCursorPosition() or r.GetPlayPosition()
    r.DeleteProjectMarker(0, dstInIdx, false)
    r.AddProjectMarker2(0, false, cursorPosition, 0, markerLabel, dstInIdx, markerColor | 0x1000000)
end

-------------------------------------------------------------------

function so.SetCrossfade(xfadeLen)    -- thanks chmaha <3

    -- assumes that the cursor is at the center of the "fade in spe"

    local currentCursorPos = r.GetCursorPosition()

    r.Main_OnCommand(40020, 0)        -- Time Selection: Remove

    r.SetEditCurPos(currentCursorPos - xfadeLen/2, false, false)

    r.Main_OnCommand(40625, 0)        -- Time selection: Set start point

    r.SetEditCurPos(currentCursorPos + xfadeLen/2, false, false)

    r.Main_OnCommand(40626, 0)        -- Time selection: Set end point

    r.Main_OnCommand(40421, 0) -- Item: Select all items in track
    r.Main_OnCommand(40034, 0) -- Item grouping: Select all items in groups

    -- make sure only items in the topmost lane are affected

    local selectedItemsGUID = {}

    for i = 0, r.CountSelectedMediaItems(0) - 1 do

        local mediaItem = r.GetSelectedMediaItem(0, i)

        if not mediaItem then return end

        local itemLane = r.GetMediaItemInfo_Value(mediaItem, "I_FIXEDLANE")

        if itemLane >= 1 then
            table.insert(selectedItemsGUID, r.BR_GetMediaItemGUID(mediaItem))
        end

    end

    for i = 0, #selectedItemsGUID do

        local mediaItem = r.BR_GetMediaItemByGUID(0, selectedItemsGUID[i])

        if mediaItem then
            r.SetMediaItemSelected(mediaItem, false)
        end

    end

    r.Main_OnCommand(40916, 0) -- Item: Crossfade items within time selection
    r.Main_OnCommand(40635, 0) -- Time selection: Remove time selection

end

------------------------------------------

function so.RemoveSourceGates(safeLane_rx, sourceLabelIn_rx, sourceLabelOut_rx)

    -- (-1): remove ONLY topmost lanes' src gates
    local safeLane = safeLane_rx
    local sourceLabelIn = sourceLabelIn_rx
    local sourceLabelOut = sourceLabelOut_rx

    r.Main_OnCommand(40289, 0) -- Deselect all items

    r.SelectAllMediaItems(0, true)

    local numSelectedItems = r.CountSelectedMediaItems(0)

    -- Iterate through selected items
    for i = 0, numSelectedItems - 1 do

        -- Get the active media item
        local mediaItem = r.GetSelectedMediaItem(0, i)
        if not mediaItem then return end

        local itemLane = r.GetMediaItemInfo_Value(mediaItem, "I_FIXEDLANE")

        if itemLane >= safeLane and safeLane ~= -1 then

            -- Get the active take
            local activeTake = r.GetActiveTake(mediaItem)

            if activeTake then
                -- Remove existing MarkerLabel markers
                local numMarkers = r.GetNumTakeMarkers(activeTake)
                for i = numMarkers, 0, -1 do
                    local _, markerType, _, _, _ = r.GetTakeMarker(activeTake, i)
                    if markerType == sourceLabelIn then
                        r.DeleteTakeMarker(activeTake, i)
                    end
                    if markerType == sourceLabelOut then
                        r.DeleteTakeMarker(activeTake, i)
                    end
                end
            end

        elseif safeLane == -1 then

            if itemLane == 0 then

                -- Get the active take
                local activeTake = r.GetActiveTake(mediaItem)

                if activeTake then
                    -- Remove existing MarkerLabel markers
                    local numMarkers = r.GetNumTakeMarkers(activeTake)
                    for i = numMarkers, 0, -1 do
                        local _, markerType, _, _, _ = r.GetTakeMarker(activeTake, i)
                        if markerType == sourceLabelIn then
                            r.DeleteTakeMarker(activeTake, i)
                        end
                        if markerType == sourceLabelOut then
                            r.DeleteTakeMarker(activeTake, i)
                        end
                    end
                end
            end
        end
        
    end

  r.Main_OnCommand(40289, 0) -- Deselect all items

end

------------------------------------------

function so.PrepareEditStates()

    local rippleStateAll = r.GetToggleCommandState(41991) -- Toggle ripple editing all tracks
    local rippleStatePer = r.GetToggleCommandState(41990) -- Toggle ripple editing per-track
    local trimContentState = r.GetToggleCommandState(41117) -- Options: Trim content behind media items when editing

    return rippleStateAll, rippleStatePer, trimContentState

end

------------------------------------------

function so.ResetEditStates(rippleStateAll, rippleStatePer, trimContentState)

    if rippleStateAll == 1 then
        r.Main_OnCommand(41991, 1)
    elseif rippleStatePer == 1 then
        r.Main_OnCommand(41990, 1)
    elseif rippleStateAll == 0 and rippleStatePer == 0 then
        r.Main_OnCommand(40309, 1) -- Set ripple editing off
    end

    if trimContentState == 0 then
        r.Main_OnCommand(41121, 1) -- Options: Disable trim content behind media items when editing
    end

end

------------------------------------------

function so.ToggleLockItemsInSourceLanes(lockState_rx)

    local lockState = lockState_rx

    local safeLanes = 1 -- Lanes that will not be locked, indexed from the topmost lane

    r.Main_OnCommand(40289, 0) -- Deselect all items

    r.SelectAllMediaItems(0, true)

    for i = 0, r.CountSelectedMediaItems(0) - 1 do

      local mediaItem = r.GetSelectedMediaItem(0, i)
      if not mediaItem then return end

      local itemLane = r.GetMediaItemInfo_Value(mediaItem, "I_FIXEDLANE")

      if itemLane >= safeLanes then

        r.SetMediaItemInfo_Value(mediaItem, "C_LOCK", lockState)

      end

    end

    r.Main_OnCommand(40289, 0) -- Deselect all items

  end

  return so