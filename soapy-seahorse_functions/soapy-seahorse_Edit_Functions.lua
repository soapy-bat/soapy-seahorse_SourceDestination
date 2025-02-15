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

local bool_RemoveAllSourceGates = true         -- remove all source gates after the edit

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
local dstLabelOut = "DST_OUT"
local dstIdxIn = 996
local dstIdxOut = 997

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
    local timeSelStart, timeSelEnd = so.GetTimeSelection()
    local loopStart, loopEnd = so.GetLoopPoints()

    if bool_TargetItemUnderMouse then
        r.Main_OnCommand(40289, 0) -- Item: Unselect (clear selection of) all items
        r.Main_OnCommand(40528, 0) -- Item: Select item under mouse cursor
    end

    local sourceItem = r.GetSelectedMediaItem(0,0)
    if not sourceItem then return end

    local sourceGateIn = so.GetSourceGate(sourceItem, srcLabelIn)
    if not sourceGateIn then return end

    local sourceGateOut = so.GetSourceGate(sourceItem, srcLabelOut)
    if not sourceGateOut then return end

    local targetTrack = r.GetMediaItem_Track(r.GetSelectedMediaItem(0, 0))
    r.SetOnlyTrackSelected(targetTrack)

    local tbl_PlayingLanes
    if bool_KeepLaneSolo then
        tbl_PlayingLanes = so.GetLaneSolo(targetTrack)
    end

    ---##### src copy routine #####---

    so.SetTimeSelectionToSourceGates(sourceGateIn, sourceGateOut) -- time selection is used to copy items

    r.Main_OnCommand(40060, 0) -- copy selected area of items (source material)

    r.Main_OnCommand(40289, 0) -- Deselect all items
    r.Main_OnCommand(40020, 0) -- Time Selection: Remove

    ---##### paste source to destination #####---

    if bool_Ripple then
        so.ToggleLockItemsInSourceLanes(1)
    end

    -- paste source material
    r.GoToMarker(0, dstIdxIn, false)
    r.Main_OnCommand(42790, 0) -- play only first lane / solo first lane (comp lane)
    r.Main_OnCommand(42398, 0) -- Items: paste items/tracks

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
        so.SetLaneSolo(sourceItem, tbl_PlayingLanes)
    end

    so.SetTimeSelection(timeSelStart, timeSelEnd)
    so.SetLoopPoints(loopStart, loopEnd)

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

function so.FourPointEdit()

    r.Undo_BeginBlock()
    r.PreventUIRefresh(1)

    ---######### START ##########---

    ---##### buffer and set various edit states #####---

    local saveXFadeState = r.NamedCommandLookup("_SWS_SAVEXFD")
    r.Main_OnCommand(saveXFadeState, 1) -- SWS: Save auto crossfade state

    local rippleStateAll, rippleStatePer, trimContentState = so.PrepareEditStates()

    r.Main_OnCommand(40309, 1) -- Set ripple editing off
    r.Main_OnCommand(41120, 1) -- Options: Enable trim content behind media items when editing

    ---##### get all coordinates #####---

    local cursorPos_origin = r.GetCursorPosition()
    local timeSelStart, timeSelEnd = so.GetTimeSelection()
    local loopStart, loopEnd = so.GetLoopPoints()

    if bool_TargetItemUnderMouse then
        r.Main_OnCommand(40289, 0) -- Item: Unselect (clear selection of) all items
        r.Main_OnCommand(40528, 0) -- Item: Select item under mouse cursor
    end

    -- future routines (ShiftDestinationItems) will deselect the item,
    -- that's why we will get this one first:
    local sourceItem = r.GetSelectedMediaItem(0, 0)
    if not sourceItem then return end

    local sourceGateIn = so.GetSourceGate(sourceItem, srcLabelIn)
    if not sourceGateIn then return end

    local sourceGateOut = so.GetSourceGate(sourceItem, srcLabelOut)
    if not sourceGateOut then return end

    local dstInPos = so.GetDstGate(dstIdxIn)
    if not dstInPos then return end

    local dstOutPos = so.GetDstGate(dstIdxOut)
    if not dstOutPos then return end

    local targetTrack = r.GetMediaItem_Track(sourceItem)
    r.SetOnlyTrackSelected(targetTrack)

    local tbl_PlayingLanes
    if bool_KeepLaneSolo then
        tbl_PlayingLanes = so.GetLaneSolo(targetTrack)
    end

    ---##### calculate offset and move items on comp lane accordingly #####---

    local destinationDifference = so.CalcDstOffset(sourceGateIn, sourceGateOut, dstInPos, dstOutPos)
    so.ClearDestinationArea(dstInPos, dstOutPos)
    so.ShiftDestinationItems(destinationDifference, dstOutPos)

    ---##### src copy routine #####---

    so.SetTimeSelectionToSourceGates(sourceGateIn, sourceGateOut) -- time selection is used to copy items

    r.SetMediaItemSelected(sourceItem, true)
    r.Main_OnCommand(40034, 0) -- Item grouping: Select all items in groups

    r.Main_OnCommand(40060, 0) -- copy selected area of items (source material)

    r.Main_OnCommand(40289, 0) -- Deselect all items
    r.Main_OnCommand(40020, 0) -- Time Selection: Remove

    ---##### paste source to destination #####---

    r.GoToMarker(0, dstIdxIn, false)
    r.Main_OnCommand(42790, 0) -- play only first lane
    r.Main_OnCommand(42398, 0) -- Items: paste items/tracks

    ---##### cleanup: set new dst gate, set xfade, clean up src gates #####---

    local cursorPos_end = r.GetCursorPosition()

    if bool_AutoCrossfade then
        r.GoToMarker(0, dstIdxIn, false) -- go to start of pasted item
        so.SetCrossfade(xfadeLen)

        r.SetEditCurPos(cursorPos_end, false, false) -- go to end of pasted item
        so.SetCrossfade(xfadeLen)
    end

    so.RemoveSourceGates(-1, srcLabelIn, srcLabelOut)    -- remove src gates from newly pasted material

    if not bool_AutoCrossfade then
        r.Main_OnCommand(40020, 0) -- Time Selection: Remove
    end

    if bool_MoveDstGateAfterEdit then
        r.SetEditCurPos(cursorPos_end, false, false) -- go to end of pasted item
        so.SetDstGateIn(dstLabelIn, dstIdxIn)        -- move destination gate in to end of pasted material (assembly line style)
    end

    if bool_RemoveAllSourceGates then
        so.RemoveSourceGates(0, srcLabelIn, srcLabelOut)
    end

    r.DeleteProjectMarker(0, dstIdxOut, false)

    r.Main_OnCommand(40289, 0) -- Deselect all items
    r.SetEditCurPos(cursorPos_origin, false, false) -- go to original cursor position

    if bool_KeepLaneSolo then
        so.SetLaneSolo(sourceItem, tbl_PlayingLanes)
    end

    so.SetTimeSelection(timeSelStart, timeSelEnd)
    so.SetLoopPoints(loopStart, loopEnd)

    so.ResetEditStates(rippleStateAll, rippleStatePer, trimContentState)

    local restoreXFadeState = r.NamedCommandLookup("_SWS_RESTOREXFD")
    r.Main_OnCommand(restoreXFadeState, 0) -- SWS: Restore auto crossfade state

    ---######### END ##########---

    r.PreventUIRefresh(-1)
    r.UpdateArrange()
    r.Undo_EndBlock("ReaPyr 4 point edit", -1)


end

-----------
-- utils --
-----------

function so.GetTimeSelection()

    local timeSelStart, timeSelEnd = r.GetSet_LoopTimeRange2(0, false, false, 0, 0, true)

    return timeSelStart, timeSelEnd

end

-------------------------------------------

function so.SetTimeSelection(timeSelStart, timeSelEnd)

    if not timeSelStart or not timeSelEnd then return end

    r.GetSet_LoopTimeRange2(0, true, false, timeSelStart, timeSelEnd, true)

end

-------------------------------------------

---Get start and end position of loop points in session using r.GetSet_LoopTimeRange2()
---@return number loopStart
---@return number loopEnd
function so.GetLoopPoints()

    local loopStart, loopEnd = r.GetSet_LoopTimeRange2(0, false, true, 0, 0, true)

    return loopStart, loopEnd

end

-------------------------------------------
---Set start and end position of loop points in session using r.GetSet_LoopTimeRange2()
---@param loopStart number
---@param loopEnd number
function so.SetLoopPoints(loopStart, loopEnd)

    if not loopStart or not loopEnd then return end

    r.GetSet_LoopTimeRange2(0, true, true, loopStart, loopEnd, true)

end

-------------------------------------------
---Get solo states of a given media track using r.GetMediaTrackInfo_Value()
---@param selTrack MediaTrack
---@return table tbl_playingLanes
function so.GetLaneSolo(selTrack)

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
---sets lane solo for first active lane (impossible to set multiple lane solos via script)
---@param selItem MediaItem
---@param tbl_PlayingLanes table
function so.SetLaneSolo(selItem, tbl_PlayingLanes)

    local tbl_groupedTracks = so.GetTracksOfItemGroup(selItem)

    for i = 1, #tbl_groupedTracks do

        local selTrack = tbl_groupedTracks[i]

        local parmName = tostring("C_LANEPLAYS:" .. tbl_PlayingLanes[1])
        r.SetMediaTrackInfo_Value(selTrack, parmName, 1)
    end

end

-------------------------------------------------------------------

---get list of tracks based on grouped items (usually the main editing group)
---@param selItem MediaItem
---@return table tbl_groupedTracks
function so.GetTracksOfItemGroup(selItem)

    local tbl_groupedTracks = {}

    r.Main_OnCommand(40289, 0) -- Deselect all items
    r.Main_OnCommand(40297, 0) -- Track: Unselect (clear selection of) all tracks

    r.SetMediaItemSelected(selItem, true)
    r.Main_OnCommand(40034, 0) -- Item grouping: Select all items in groups

    for i = 0, r.CountSelectedMediaItems(0) - 1 do
        local selTrack = r.GetMediaItemTrack(r.GetSelectedMediaItem(0, i))
        r.SetTrackSelected(selTrack, true)
    end

    for i = 0, r.CountSelectedTracks(0) - 1 do
        local selTrack = r.GetSelectedTrack(0, i)
        table.insert(tbl_groupedTracks, selTrack)
    end

    r.Main_OnCommand(40289, 0) -- Deselect all items
    r.Main_OnCommand(40297, 0) -- Track: Unselect (clear selection of) all tracks

    return tbl_groupedTracks
end

-------------------------------------------------------------------

function so.GetGroupedTracks(selTrack)

    -- only checks first 32 groups atm

    local isEditLead = r.GetSetTrackGroupMembership(selTrack, "MEDIA_EDIT_LEAD", 0, 0)
    local isEditFollow = r.GetSetTrackGroupMembership(selTrack, "MEDIA_EDIT_FOLLOW", 0, 0)

    isEditLead = so.DecToBin(isEditLead)
    isEditFollow = so.DecToBin(isEditFollow)

    return isEditLead, isEditFollow
end

-------------------------------------------------------------------

---Convert base 10 number to base 2 number
---@param num integer
---@return number result
function so.DecToBin(num)

	local bin = ""  -- Create an empty string to store the binary form
	local rem  -- Declare a variable to store the remainder

	-- This loop iterates over the number, dividing it by 2 and storing the remainder each time
	-- It stops when the number has been divided down to 0
	while num > 0 do
		rem = num % 2  -- Get the remainder of the division
		bin = rem .. bin  -- Add the remainder to the string (in front, since we're iterating backwards)
		num = math.floor(num / 2)  -- Divide the number by 2
	end

    local result = tonumber(bin) -- string to number

	return result
end

-------------------------------------------------------------------

---find flagged take marker in given item
---@param sourceItem MediaItem
---@param markerLabel string
---@return number|nil sourceMarkerPosition
function so.GetSourceGate(sourceItem, markerLabel)

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

function so.GetDstGate(gateIdx) -- Find DST marker

    local _, numMarkers, numRegions = r.CountProjectMarkers(0)

    for i = 0, numMarkers + numRegions do

        local _, _, dstInPos, _, _, markerIndex = r.EnumProjectMarkers(i)

        if markerIndex == gateIdx then
            return dstInPos
        end
    end

end

-------------------------------------------------------------------

function so.SetTimeSelectionToSourceGates(srcStart, srcEnd)
    -- Function to set a Time Selection based on given start and end points
    if srcEnd <= srcStart then return false end

    r.GetSet_LoopTimeRange2(0, true, false, srcStart, srcEnd, true)

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
---* Creates a time selection
---* Selects only items in the top lane
---* Fades selected items in time selection using action 40916 (Item: Crossfade items within time selection)
---
---If curPos is nil, current cursor position will be used.
---@param xfadeLen number
---@param curPos number|nil
function so.SetCrossfade(xfadeLen, curPos)

    local currentCursorPos
    if curPos then
        currentCursorPos = curPos
    else
        currentCursorPos = r.GetCursorPosition()
    end

    local fadeStart = currentCursorPos - xfadeLen/2
    local fadeEnd = currentCursorPos + xfadeLen/2

    r.GetSet_LoopTimeRange2(0, true, false, fadeStart, fadeEnd, true)

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
---* safeLane = (-1): remove only topmost lanes' source gates
---* safeLane = 0: remove ALL source gates
---@param safeLane integer
---@param sourceLabelIn string
---@param sourceLabelOut string
function so.RemoveSourceGates(safeLane, sourceLabelIn, sourceLabelOut)

    r.SelectAllMediaItems(0, true)

    local numSelectedItems = r.CountSelectedMediaItems(0)

    local mediaItem, activeTake

    -- Iterate through selected items
    for i = 0, numSelectedItems - 1 do

        mediaItem = r.GetSelectedMediaItem(0, i)
        if not mediaItem then return end

        activeTake = r.GetActiveTake(mediaItem)
        if not activeTake then return end

        local itemLane = r.GetMediaItemInfo_Value(mediaItem, "I_FIXEDLANE")

        if itemLane >= safeLane and safeLane ~= -1 then

            -- Remove existing MarkerLabel markers
            local numMarkers = r.GetNumTakeMarkers(activeTake)
            for h = numMarkers, 0, -1 do
                local _, markerType, _, _, _ = r.GetTakeMarker(activeTake, h)
                if markerType == sourceLabelIn then
                    r.DeleteTakeMarker(activeTake, h)
                end
                if markerType == sourceLabelOut then
                    r.DeleteTakeMarker(activeTake, h)
                end
            end

        elseif safeLane == -1 then

            if itemLane == 0 then

                -- Remove existing MarkerLabel markers
                local numMarkers = r.GetNumTakeMarkers(activeTake)
                for h = numMarkers, 0, -1 do
                    local _, markerType, _, _, _ = r.GetTakeMarker(activeTake, h)
                    if markerType == sourceLabelIn then
                        r.DeleteTakeMarker(activeTake, h)
                    end
                    if markerType == sourceLabelOut then
                        r.DeleteTakeMarker(activeTake, h)
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

------------------------------------------

function so.DebugBreakpoint()

    r.ShowMessageBox("this is a breakpoint message", "Debugging in Progress...", 0)

end

------------------------------------------

function so.ErrMsgMissingData()

    r.ShowMessageBox("Something went wrong while handling data.", "Missing Data", 0)

end

------------------------------------------


function so.CalcDstOffset(srcStart, srcEnd, dstStart, dstEnd)

    -- get amount that destination out needs to be moved by

    if srcEnd <= srcStart then return end
    if dstEnd <= dstStart then return end

    local srcLen = srcEnd - srcStart
    local dstLen = dstEnd - dstStart

    local difference = srcLen - dstLen

    return difference
end

-------------------------------------------------------------------

function so.ClearDestinationArea(selStart, selEnd)

    -- clear area between destination markers using time and item selections

    if not selStart then so.ErrMsgMissingData() return end
    if not selEnd then so.ErrMsgMissingData() return end

    r.SetEditCurPos(selStart, false, false)
    r.Main_OnCommand(r.NamedCommandLookup("_XENAKIOS_SELITEMSUNDEDCURSELTX"), 0)
    r.Main_OnCommand(40757, 0) -- Item: Split items at edit cursor (no change selection)

    r.SetEditCurPos(selEnd, false, false)
    r.Main_OnCommand(r.NamedCommandLookup("_XENAKIOS_SELITEMSUNDEDCURSELTX"), 0)
    r.Main_OnCommand(40757, 0) -- Item: Split items at edit cursor (no change selection)

    so.SetTimeSelection(selStart, selEnd)

    r.Main_OnCommand(40289, 0) -- Deselect all items
    r.Main_OnCommand(40718, 0) -- Item: Select all items on selected tracks in current time selection
    r.Main_OnCommand(40034, 0) -- Item grouping: Select all items in groups

    local itemsToCut = {}

    for i = 0, r.CountSelectedMediaItems(0) - 1 do

        local mediaItem = r.GetSelectedMediaItem(0, i)

        if mediaItem then

            local itemLane = r.GetMediaItemInfo_Value(mediaItem, "I_FIXEDLANE")

            if itemLane == 0 then
                table.insert(itemsToCut, mediaItem)
            end
        end
    end

    for i = 1, #itemsToCut do

        local mediaItem = itemsToCut[i]

        if mediaItem then

            local mediaTrack = r.GetMediaItem_Track(mediaItem)
            r.DeleteTrackMediaItem(mediaTrack, mediaItem)

        end
    end

    r.Main_OnCommand(40020, 0) -- Time selection: Remove (unselect) time selection and loop points
    
end

-------------------------------------------------------------------

function so.ShiftDestinationItems(difference_rx, dstOutPos_rx)

    -- shift items only on topmost lane one by one (ripple only works with graphical input)
    -- media track needs to be selected

    local difference = difference_rx
    local dstOutPos = dstOutPos_rx

    r.Main_OnCommand(40289, 0) -- Deselect all items
    r.Main_OnCommand(40421, 0) -- Item: Select all items in track
    r.Main_OnCommand(40034, 0) -- Item grouping: Select all items in groups

    local targetItems = {}

    for i = 0, r.CountSelectedMediaItems(0) - 1 do

        local mediaItem = r.GetSelectedMediaItem(0, i)

        if not mediaItem then return end

        local itemLane = r.GetMediaItemInfo_Value(mediaItem, "I_FIXEDLANE")
        local itemPos = r.GetMediaItemInfo_Value(mediaItem, "D_POSITION")

        if itemLane == 0 and itemPos >= dstOutPos then
            table.insert(targetItems, mediaItem)
        end

    end

    for i = 1, #targetItems do

        local mediaItem = targetItems[i]

        if mediaItem then

            local itemPos = r.GetMediaItemInfo_Value(mediaItem, "D_POSITION")
            local newPos = itemPos + difference

            r.SetMediaItemInfo_Value(mediaItem, "D_POSITION", newPos)

        end

    end

    so.HealAllSplits()
    r.Main_OnCommand(40289, 0) -- Deselect all items

end

-------------------------------------------------------------------

function so.HealAllSplits()

    r.Main_OnCommand(40182, 0) -- Select All
    r.Main_OnCommand(40548, 0) -- Heal splits in items
    r.Main_OnCommand(40289, 0) -- Deselect all items

end

--------------------------
-- deprecated functions --
--------------------------

function so.GetItemsOnLane(flaggedGUID_rx)

    local flaggedGUID = flaggedGUID_rx

    -- get media track and fixed lane of flagged item
    local flaggedItem = r.BR_GetMediaItemByGUID(0, flaggedGUID)
    if not flaggedItem then return end
    local flaggedLane = r.GetMediaItemInfo_Value(flaggedItem, "I_FIXEDLANE")

    local mediaTrack = r.GetMediaItem_Track(flaggedItem)
    if not mediaTrack then return end
    local itemCount = r.CountTrackMediaItems(mediaTrack)

    local tbl_laneItemsGUID = {}

    for i = 0, itemCount - 1 do

        local mediaItem = r.GetTrackMediaItem(mediaTrack, i)
        if mediaItem then

        local itemLane = r.GetMediaItemInfo_Value(mediaItem, "I_FIXEDLANE")

        if itemLane == flaggedLane then
            local newGUID = r.BR_GetMediaItemGUID(mediaItem)
            table.insert(tbl_laneItemsGUID, newGUID)
        end
        end
    end

    return tbl_laneItemsGUID

end

-------------------------------------------------------------------

return so