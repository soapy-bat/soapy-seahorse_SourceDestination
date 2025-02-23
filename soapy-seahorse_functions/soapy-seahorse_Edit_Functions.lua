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

---------------
-- variables --
---------------

local r = reaper
local se = {}

local modulePath = ({r.get_action_context()})[2]:match("^.+[\\/]")
package.path = modulePath .. "soapy-seahorse_functions/?.lua"
local sf = require("soapy-seahorse_Fades_Functions")

modulePath = ({r.get_action_context()})[2]:match("^.+[\\/]")
package.path = modulePath .. "soapy-seahorse_functions/?.lua"
local st = require("soapy-seahorse_Settings")

local markerLabel_SrcIn
local markerLabel_SrcOut
local markerLabel_DstIn
local markerLabel_DstOut
local markerIndex_DstIn
local markerIndex_Dstout

local bool_ShowHoverWarnings

-- three and four point edits

local xFadeLen
local bool_AutoCrossfade
local bool_MoveDstGateAfterEdit
local bool_RemoveAllSourceGates
local bool_TargetItemUnderMouse
local bool_KeepLaneSolo

-- item extender and quick fade

local bool_PreserveEditCursorPosition
local bool_SelectRightItemAtCleanup
local bool_AvoidCollision
local bool_PreserveExistingCrossfade
local bool_TargetMouseInsteadOfCursor

local extensionAmount
local collisionPadding
local cursorBias_Extender
local cursorBias_QuickFade

local xFadeShape

----------------------
-- three point edit --
----------------------

function se.ThreePointEdit(bool_Ripple)

    r.Undo_BeginBlock()
    r.PreventUIRefresh(1)

    ---######### START ##########---

    ---##### buffer and set various edit states #####---

    local saveXFadeState = r.NamedCommandLookup("_SWS_SAVEXFD")
    r.Main_OnCommand(saveXFadeState, 1) -- SWS: Save auto crossfade state

    local rippleStateAll, rippleStatePer, trimContentState = se.GetEditStates()

    if bool_Ripple then
        if rippleStatePer == 0 then
            r.Main_OnCommand(41990, 0) -- Set ripple editing per track on
        end
        r.Main_OnCommand(41120, 1)     -- Options: Enable trim content behind media items when editing
    end

    ---##### get coordinates #####---

    local cursorPos_origin = r.GetCursorPosition()
    local timeSelStart, timeSelEnd = se.GetTimeSelectionStartEnd()
    local loopStart, loopEnd = se.GetLoopStartEnd()

    if bool_TargetItemUnderMouse then
        r.Main_OnCommand(40289, 0) -- Item: Unselect (clear selection of) all items
        r.Main_OnCommand(40528, 0) -- Item: Select item under mouse cursor
    end

    local sourceItem = r.GetSelectedMediaItem(0,0)
    if not sourceItem then return end

    local sourceGateIn = se.GetSourceGate(sourceItem, markerLabel_SrcIn)
    if not sourceGateIn then return end

    local sourceGateOut = se.GetSourceGate(sourceItem, markerLabel_SrcOut)
    if not sourceGateOut then return end

    local targetTrack = r.GetMediaItem_Track(r.GetSelectedMediaItem(0, 0))
    r.SetOnlyTrackSelected(targetTrack)

    local tbl_PlayingLanes
    if bool_KeepLaneSolo then
        tbl_PlayingLanes = se.GetLaneSolo(targetTrack)
    end

    ---##### src copy routine #####---

    se.SetTimeSelectionToSourceGates(sourceGateIn, sourceGateOut) -- time selection is used to copy items

    r.Main_OnCommand(40060, 0) -- copy selected area of items (source material)

    se.DeselectAllItems()
    r.Main_OnCommand(40020, 0) -- Time Selection: Remove

    ---##### paste source to destination #####---

    if bool_Ripple then
        se.ToggleLockItemsInSourceLanes(1)
    end

    -- paste source material
    r.GoToMarker(0, markerIndex_DstIn, false)
    r.Main_OnCommand(42790, 0) -- play only first lane / solo first lane (comp lane)
    r.Main_OnCommand(42398, 0) -- Items: paste items/tracks

    if bool_Ripple then
        se.ToggleLockItemsInSourceLanes(0)
    end

    ---##### cleanup: set new dst gate, set xfade, clean up src gates #####---

    local cursorPos_end = r.GetCursorPosition()

    if bool_AutoCrossfade then
        -- go to start of pasted item, set fade
        r.GoToMarker(0, markerIndex_DstIn, false)
        se.SetCrossfade(xFadeLen)
    end

    se.RemoveSourceGates(-1, markerLabel_SrcIn, markerLabel_SrcOut)    -- remove src gates from newly pasted material

    if not bool_AutoCrossfade then
        r.Main_OnCommand(40020, 0) -- Time Selection: Remove
    end

    if bool_MoveDstGateAfterEdit then
        r.SetEditCurPos(cursorPos_end, false, false) -- go to end of pasted item
        se.SetDstGateIn(markerLabel_DstIn, markerIndex_DstIn)  -- move destination gate in to end of pasted material (assembly line style)
    end

    if bool_RemoveAllSourceGates then
        se.RemoveSourceGates(0, markerLabel_SrcIn, markerLabel_SrcOut)
    end

    se.DeselectAllItems()
    r.SetEditCurPos(cursorPos_origin, false, false) -- go to original cursor position

    if bool_KeepLaneSolo then
        se.SetLaneSolo(sourceItem, tbl_PlayingLanes)
    end

    se.SetTimeSelection(timeSelStart, timeSelEnd)
    se.SetLoopPoints(loopStart, loopEnd)

    se.ResetEditStates(rippleStateAll, rippleStatePer, trimContentState)

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

---------------------
-- four point edit --
---------------------

function se.FourPointEdit()

    r.Undo_BeginBlock()
    r.PreventUIRefresh(1)

    ---######### START ##########---

    ---##### buffer and set various edit states #####---

    local saveXFadeState = r.NamedCommandLookup("_SWS_SAVEXFD")
    r.Main_OnCommand(saveXFadeState, 1) -- SWS: Save auto crossfade state

    local rippleStateAll, rippleStatePer, trimContentState = se.GetEditStates()

    r.Main_OnCommand(40309, 1) -- Set ripple editing off
    r.Main_OnCommand(41120, 1) -- Options: Enable trim content behind media items when editing

    ---##### get all coordinates #####---

    local cursorPos_origin = r.GetCursorPosition()
    local timeSelStart, timeSelEnd = se.GetTimeSelectionStartEnd()
    local loopStart, loopEnd = se.GetLoopStartEnd()

    if bool_TargetItemUnderMouse then
        r.Main_OnCommand(40289, 0) -- Item: Unselect (clear selection of) all items
        r.Main_OnCommand(40528, 0) -- Item: Select item under mouse cursor
    end

    -- future routines (ShiftDestinationItems) will deselect the item,
    -- that's why we will get this one first:
    local sourceItem = r.GetSelectedMediaItem(0, 0)
    if not sourceItem then return end

    local sourceGateIn = se.GetSourceGate(sourceItem, markerLabel_SrcIn)
    if not sourceGateIn then return end

    local sourceGateOut = se.GetSourceGate(sourceItem, markerLabel_SrcOut)
    if not sourceGateOut then return end

    local dstInPos = se.GetDstGate(markerIndex_DstIn)
    if not dstInPos then return end

    local dstOutPos = se.GetDstGate(markerIndex_Dstout)
    if not dstOutPos then return end

    local targetTrack = r.GetMediaItem_Track(sourceItem)
    r.SetOnlyTrackSelected(targetTrack)

    local tbl_PlayingLanes
    if bool_KeepLaneSolo then
        tbl_PlayingLanes = se.GetLaneSolo(targetTrack)
    end

    ---##### calculate offset and move items on comp lane accordingly #####---

    local destinationDifference = se.CalcDstOffset(sourceGateIn, sourceGateOut, dstInPos, dstOutPos)
    se.ClearDestinationArea(dstInPos, dstOutPos)
    se.ShiftDestinationItems(destinationDifference, dstOutPos)

    ---##### src copy routine #####---

    se.SetTimeSelectionToSourceGates(sourceGateIn, sourceGateOut) -- time selection is used to copy items

    r.SetMediaItemSelected(sourceItem, true)
    r.Main_OnCommand(40034, 0) -- Item grouping: Select all items in groups

    r.Main_OnCommand(40060, 0) -- copy selected area of items (source material)

    se.DeselectAllItems()
    r.Main_OnCommand(40020, 0) -- Time Selection: Remove

    ---##### paste source to destination #####---

    r.GoToMarker(0, markerIndex_DstIn, false)
    r.Main_OnCommand(42790, 0) -- play only first lane
    r.Main_OnCommand(42398, 0) -- Items: paste items/tracks

    ---##### cleanup: set new dst gate, set xfade, clean up src gates #####---

    local cursorPos_end = r.GetCursorPosition()

    if bool_AutoCrossfade then
        r.GoToMarker(0, markerIndex_DstIn, false) -- go to start of pasted item
        se.SetCrossfade(xFadeLen)

        r.SetEditCurPos(cursorPos_end, false, false) -- go to end of pasted item
        se.SetCrossfade(xFadeLen)
    end

    se.RemoveSourceGates(-1, markerLabel_SrcIn, markerLabel_SrcOut)    -- remove src gates from newly pasted material

    if not bool_AutoCrossfade then
        r.Main_OnCommand(40020, 0) -- Time Selection: Remove
    end

    if bool_MoveDstGateAfterEdit then
        r.SetEditCurPos(cursorPos_end, false, false) -- go to end of pasted item
        se.SetDstGateIn(markerLabel_DstIn, markerIndex_DstIn)        -- move destination gate in to end of pasted material (assembly line style)
    end

    if bool_RemoveAllSourceGates then
        se.RemoveSourceGates(0, markerLabel_SrcIn, markerLabel_SrcOut)
    end

    r.DeleteProjectMarker(0, markerIndex_Dstout, false)

    se.DeselectAllItems()
    r.SetEditCurPos(cursorPos_origin, false, false) -- go to original cursor position

    if bool_KeepLaneSolo then
        se.SetLaneSolo(sourceItem, tbl_PlayingLanes)
    end

    se.SetTimeSelection(timeSelStart, timeSelEnd)
    se.SetLoopPoints(loopStart, loopEnd)

    se.ResetEditStates(rippleStateAll, rippleStatePer, trimContentState)

    local restoreXFadeState = r.NamedCommandLookup("_SWS_RESTOREXFD")
    r.Main_OnCommand(restoreXFadeState, 0) -- SWS: Restore auto crossfade state

    ---######### END ##########---

    r.PreventUIRefresh(-1)
    r.UpdateArrange()
    r.Undo_EndBlock("ReaPyr 4 point edit", -1)


end

-------------------
-- item extender --
-------------------

function se.ItemExtender()

  r.Undo_BeginBlock()
  r.PreventUIRefresh(1)

  local curPos = r.GetCursorPosition()

  local saveXFadeState = r.NamedCommandLookup("_SWS_SAVEXFD")
  r.Main_OnCommand(saveXFadeState, 1) -- SWS: Save auto crossfade state
  r.Main_OnCommand(41119, 1) -- Options: Disable Auto Crossfades

  local item1GUID, item2GUID = se.ExtendItems(_, 1)
  if not item1GUID or not item2GUID then return end

  if bool_SelectRightItemAtCleanup then

    local mediaItem2 = r.BR_GetMediaItemByGUID(0, item2GUID)
    if not mediaItem2 then return end

    se.DeselectAllItems()
    r.SetMediaItemSelected(mediaItem2, true)

  end

  local restoreXFadeState = r.NamedCommandLookup("_SWS_RESTOREXFD")
  r.Main_OnCommand(restoreXFadeState, 0) -- SWS: Restore auto crossfade state

  if bool_PreserveEditCursorPosition then
    r.SetEditCurPos(curPos, false, false)
  end

  r.PreventUIRefresh(-1)
  r.UpdateArrange()
  r.Undo_EndBlock("Extend items", 0)

end

-------------------------------------------

function se.ExtendItems(scriptCommand_rx, newToggleState_rx)

  -- ## get items ## --
  local _, _, _, _, itemGUID = sf.GetItemsNearMouse(cursorBias_Extender)

  if not itemGUID then
    if bool_ShowHoverWarnings then se.ErrMsgHover() end
    return
  end

  -- ## extend items ## --
  local mediaItem = {}
  for i = 1, #itemGUID do
    mediaItem[i] = r.BR_GetMediaItemByGUID(0, itemGUID[i])
  end
  for i = 1, #mediaItem do
    if not mediaItem[i] then
      if bool_ShowHoverWarnings then se.ErrMsgHover() end
      return
    end
  end

  if bool_AvoidCollision then

    -- ## avoid collision: get item edges ## --
    local itemStart, itemEnd, itemFade = {}, {}, {}

    itemStart[1], _, itemEnd[1] = se.GetItemStartLengthEnd(mediaItem[1])
    itemStart[2], _, itemEnd[2] = se.GetItemStartLengthEnd(mediaItem[2])

    itemFade[1], _ = se.GetItemLargestFade(mediaItem[1])
    _, itemFade[2] = se.GetItemLargestFade(mediaItem[2])

    -- avoid crashing right item's starts into left item's start
    local gapLeft = itemStart[2] - itemStart[1] - itemFade[1] - collisionPadding
    -- avoid crashing left item's end into right item's end
    local gapRight = itemEnd[2] - itemEnd[1] - itemFade[2] - collisionPadding

    -- ## avoid collision: calculate ## --

    local smallestGap
    if gapLeft < gapRight then
      smallestGap = gapLeft
    else
      smallestGap = gapRight
    end

    if smallestGap < extensionAmount then
      extensionAmount = smallestGap
    end

  end

  local bool_success = sf.LenghtenItem(mediaItem[1], 1, 1, extensionAmount)
  bool_success = sf.LenghtenItem(mediaItem[2], 2, 1, extensionAmount)

  if bool_success then
    return itemGUID[1], itemGUID[2]
  else
    r.ShowMessageBox("Item Extender unsuccessful.", "sorry!", 0)
    return
  end

end

----------------
-- quick fade --
----------------

function se.QuickFade()

    r.Undo_BeginBlock()
    r.PreventUIRefresh(1)

    local saveXFadeState = r.NamedCommandLookup("_SWS_SAVEXFD")
    r.Main_OnCommand(saveXFadeState, 1) -- SWS: Save auto crossfade state
    r.Main_OnCommand(41119, 1) -- Options: Disable Auto Crossfades

    local curPosOrigin = r.GetCursorPosition()
    local timeSelStart, timeSelEnd = se.GetTimeSelectionStartEnd()
    local loopStart, loopEnd = se.GetLoopStartEnd()

    -- ## get / set cursor position ## --

    if bool_TargetMouseInsteadOfCursor then
        r.Main_OnCommand(40514, 0) -- View: Move edit cursor to mouse cursor (no snapping)
    end

    local curPos = r.GetCursorPosition()

    -- ## get items ## --

    local _, item1GUID, item2GUID, _ = sf.GetItemsNearMouse(cursorBias_QuickFade)
    if not item1GUID then se.QuickFade_Cleanup(_, curPos, curPosOrigin) return end
    if not item2GUID then se.QuickFade_Cleanup(_, curPos, curPosOrigin) return end

    local tbl_mediaItem = {}
    table.insert(tbl_mediaItem, r.BR_GetMediaItemByGUID(0, item1GUID))
    table.insert(tbl_mediaItem, r.BR_GetMediaItemByGUID(0, item2GUID))

    for i = 1, #tbl_mediaItem do
        if not tbl_mediaItem[i] then se.QuickFade_Cleanup(_, curPos) return end
    end

    -- ## if requested: get fade length ## --

    if bool_PreserveExistingCrossfade then

        local success, fadeLen, fadeShape1, fadeShape2 = se.GetCrossfade(tbl_mediaItem, xFadeLen)

        if success then

            xFadeLen = fadeLen

            if fadeShape1 == fadeShape2 then
                xFadeShape = fadeShape1
            end
        end

    end

    -- ## manipulate items in order to be able to fade ## --

    se.QuickFade_SetItemsEdges(tbl_mediaItem, curPos)

    -- ## select items ## --
    se.SetGroupedItemsSelectedOnly(tbl_mediaItem)

    -- ## perform crossfade ## --
    se.SetCrossfade2(curPos, xFadeLen)

    if bool_PreserveExistingCrossfade then
        se.ResetFadeShape(tbl_mediaItem, xFadeShape)
    end

    -- ## clean up ## --

    se.QuickFade_Cleanup(tbl_mediaItem, curPos, curPosOrigin, timeSelStart, timeSelEnd, loopStart, loopEnd)

    r.PreventUIRefresh(-1)
    r.UpdateArrange()
    r.Undo_EndBlock("ReaPyr Quick Fade", 0)

end

-------------------------------------------

function se.QuickFade_SetItemsEdges(tbl_mediaItem, curPos)

    for i = 1, #tbl_mediaItem do
        if not tbl_mediaItem[i] then return end
    end
    if not curPos then return end

    local item1Start = r.GetMediaItemInfo_Value(tbl_mediaItem[1], "D_POSITION")
    local item1Len = r.GetMediaItemInfo_Value(tbl_mediaItem[1], "D_LENGTH")
    local item1End = item1Start + item1Len

    if item1End < curPos then

        se.SetSingleItemGroupSelectedOnly(tbl_mediaItem[1])

        for i = 0, r.CountSelectedMediaItems(0) - 1 do

            local selItem = r.GetSelectedMediaItem(0, i)

            if selItem then
                r.BR_SetItemEdges(selItem, item1Start, curPos)
            end
        end
    end

    local item2Start = r.GetMediaItemInfo_Value(tbl_mediaItem[2], "D_POSITION")
    local item2Len = r.GetMediaItemInfo_Value(tbl_mediaItem[2], "D_LENGTH")
    local item2End = item2Start + item2Len

    if item2Start > curPos then

        se.SetSingleItemGroupSelectedOnly(tbl_mediaItem[2])

        for i = 0, r.CountSelectedMediaItems(0) - 1 do

            local selItem = r.GetSelectedMediaItem(0, i)

            if selItem then
                r.BR_SetItemEdges(selItem, curPos, item2End)
            end
        end

    end

end

-------------------------------------------

function se.QuickFade_Cleanup(tbl_mediaItem, curPos, curPosOrigin, timeSelStart, timeSelEnd, loopStart, loopEnd)

    local restoreXFadeState = r.NamedCommandLookup("_SWS_RESTOREXFD")
    r.Main_OnCommand(restoreXFadeState, 0) -- SWS: Restore auto crossfade state

    r.Main_OnCommand(40020, 0) -- Time selection: Remove (unselect) time selection and loop points

    se.SetTimeSelection(timeSelStart, timeSelEnd)
    se.SetLoopPoints(loopStart, loopEnd)

    if bool_PreserveEditCursorPosition then
        r.SetEditCurPos(curPosOrigin, false, false)
    else
        r.SetEditCurPos(curPos, false, false)
    end

    se.DeselectAllItems()
    if bool_SelectRightItemAtCleanup then

        if not tbl_mediaItem then
            if bool_ShowHoverWarnings then se.ErrMsgHover() end
            return
        end

        r.SetMediaItemSelected(tbl_mediaItem[2], true)
    end

end

-----------
-- utils --
-----------

function GetSettings()

    local tbl_Settings = st.GetSettings()

    markerLabel_SrcIn = tbl_Settings.markerLabel_SrcIn
    markerLabel_SrcOut = tbl_Settings.markerLabel_SrcOut
    markerLabel_DstIn =tbl_Settings.markerIndex_DstIn
    markerLabel_DstOut = tbl_Settings.markerLabel_DstOut
    markerIndex_DstIn = tonumber(tbl_Settings.markerIndex_DstIn)
    markerIndex_Dstout = tonumber(tbl_Settings.markerIndex_DstOut)

    bool_ShowHoverWarnings = tonumber(tbl_Settings.bool_ShowHoverWarnings)

    -- three and four point edits

    xFadeLen = tonumber(tbl_Settings.xFadeLen)
    bool_AutoCrossfade = tonumber(tbl_Settings.bool_AutoCrossfade)
    bool_MoveDstGateAfterEdit = tonumber(tbl_Settings.bool_MoveDstGateAfterEdit)
    bool_RemoveAllSourceGates = tonumber(tbl_Settings.bool_RemoveAllSourceGates)
    bool_TargetItemUnderMouse = tonumber(tbl_Settings.bool_EditTargetsItemUnderMouse)
    bool_KeepLaneSolo = tonumber(tbl_Settings.bool_KeepLaneSolo)

    -- item extender and quick fade

    bool_PreserveEditCursorPosition = tonumber(tbl_Settings.bool_PreserveEditCursorPosition)
    bool_SelectRightItemAtCleanup = tonumber(tbl_Settings.bool_SelectRightItemAtCleanup)
    bool_AvoidCollision = tonumber(tbl_Settings.bool_AvoidCollision)
    bool_PreserveExistingCrossfade = tonumber(tbl_Settings.bool_PreserveExistingCrossfade)
    bool_TargetMouseInsteadOfCursor = tonumber(tbl_Settings.bool_EditTargetsMouseInsteadOfCursor)

    extensionAmount = tonumber(tbl_Settings.extensionAmount)
    collisionPadding = tonumber(tbl_Settings.collisionPadding)
    cursorBias_Extender = tonumber(tbl_Settings.cursorBias_Extender)
    cursorBias_QuickFade = tonumber(tbl_Settings.cursorBias_QuickFade)

    xFadeShape = tonumber(tbl_Settings.xFadeShape)

end

-------------------------------------------

function se.GetTimeSelectionStartEnd()

    local timeSelStart, timeSelEnd = r.GetSet_LoopTimeRange2(0, false, false, 0, 0, true)

    return timeSelStart, timeSelEnd

end

-------------------------------------------

function se.SetTimeSelection(timeSelStart, timeSelEnd)

    if not timeSelStart or not timeSelEnd then return end

    r.GetSet_LoopTimeRange2(0, true, false, timeSelStart, timeSelEnd, true)

end

-------------------------------------------

---Get start and end position of loop points in session using r.GetSet_LoopTimeRange2()
---@return number loopStart
---@return number loopEnd
function se.GetLoopStartEnd()

    local loopStart, loopEnd = r.GetSet_LoopTimeRange2(0, false, true, 0, 0, true)

    return loopStart, loopEnd

end

-------------------------------------------
---Set start and end position of loop points in session using r.GetSet_LoopTimeRange2()
---@param loopStart number
---@param loopEnd number
function se.SetLoopPoints(loopStart, loopEnd)

    if not loopStart or not loopEnd then return end

    r.GetSet_LoopTimeRange2(0, true, true, loopStart, loopEnd, true)

end

-------------------------------------------
---Get solo states of a given media track using r.GetMediaTrackInfo_Value()
---@param selTrack MediaTrack
---@return table tbl_playingLanes
function se.GetLaneSolo(selTrack)

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
function se.SetLaneSolo(selItem, tbl_PlayingLanes)

    local tbl_groupedTracks = se.GetTracksOfItemGroup(selItem)

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
function se.GetTracksOfItemGroup(selItem)

    local tbl_groupedTracks = {}

    se.DeselectAllItems()
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

    se.DeselectAllItems()
    r.Main_OnCommand(40297, 0) -- Track: Unselect (clear selection of) all tracks

    return tbl_groupedTracks
end

-------------------------------------------------------------------
---check if a track has set flags for edit lead and follow
---@param selTrack MediaTrack
---@return number isEditLead
---@return number isEditFollow
function se.GetTrackGroupFlags(selTrack)

    -- only checks first 32 groups atm

    local isEditLead = r.GetSetTrackGroupMembership(selTrack, "MEDIA_EDIT_LEAD", 0, 0)
    local isEditFollow = r.GetSetTrackGroupMembership(selTrack, "MEDIA_EDIT_FOLLOW", 0, 0)

    isEditLead = se.DecToBin(isEditLead)
    isEditFollow = se.DecToBin(isEditFollow)

    return isEditLead, isEditFollow
end

------------------------------------------------

function se.GetItemStartLengthEnd(mediaItem)

    local itemStart = r.GetMediaItemInfo_Value(mediaItem, "D_POSITION")
    local itemLength = r.GetMediaItemInfo_Value(mediaItem, "D_LENGTH")
    local itemEnd = itemStart + itemLength

    return itemStart, itemLength, itemEnd

end

------------------------------------------------

---returns the larger fade length between Reaper's FadeLen and FadeLen_auto
---@return any fadeInLen
---@return any fadeOutLen
function se.GetItemLargestFade(mediaItem)

    local fadeInLen = r.GetMediaItemInfo_Value(mediaItem, "D_FADEINLEN")
    local fadeInLenAuto = r.GetMediaItemInfo_Value(mediaItem, "D_FADEINLEN_AUTO")
    local fadeOutLen = r.GetMediaItemInfo_Value(mediaItem, "D_FADEOUTLEN")
    local fadeOutLenAuto = r.GetMediaItemInfo_Value(mediaItem, "D_FADEOUTLEN_AUTO")

    if fadeInLen < fadeInLenAuto then
        fadeInLen = fadeInLenAuto
    end

    if fadeOutLen < fadeOutLenAuto then
        fadeOutLen = fadeOutLenAuto
    end

    return fadeInLen, fadeOutLen

end

-------------------------------------------

function se.SetGroupedItemsSelectedOnly(tbl_mediaItem)

    for i = 1, #tbl_mediaItem do
        if not tbl_mediaItem[i] then return end
    end

    se.DeselectAllItems()

    for i = 1, #tbl_mediaItem do
        r.SetMediaItemSelected(tbl_mediaItem[i], true)
        r.Main_OnCommand(40034, 0) -- Item grouping: Select all items in groups
    end
end

-------------------------------------------

function se.SetSingleItemGroupSelectedOnly(mediaItem)

    se.DeselectAllItems()
    r.SetMediaItemSelected(mediaItem, true)
    r.Main_OnCommand(40034, 0) -- Item grouping: Select all items in groups

end

-------------------------------------------------------------------

---Convert base 10 number to base 2 number
---@param num integer
---@return number result
function se.DecToBin(num)

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
function se.GetSourceGate(sourceItem, markerLabel)

    local sourceMarkerPos = se.GetTakeMarkerPositionByName(sourceItem, markerLabel)

    if sourceMarkerPos then
        return sourceMarkerPos
    else
        r.ShowMessageBox(markerLabel .. " not found.", "Take marker not found", 0)
        return
    end
end

-------------------------------------------------------------------

function se.GetTakeMarkerPositionByName(sourceItem, markerName)

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

function se.GetDstGate(gateIdx) -- Find DST marker

    local _, numMarkers, numRegions = r.CountProjectMarkers(0)

    for i = 0, numMarkers + numRegions do

        local _, _, dstInPos, _, _, markerIndex = r.EnumProjectMarkers(i)

        if markerIndex == gateIdx then
            return dstInPos
        end
    end

end

-------------------------------------------------------------------

function se.SetTimeSelectionToSourceGates(srcStart, srcEnd)
    -- Function to set a Time Selection based on given start and end points
    if srcEnd <= srcStart then return false end

    r.GetSet_LoopTimeRange2(0, true, false, srcStart, srcEnd, true)

end

-------------------------------------------------------------------

function se.SetDstGateIn(dstInLabel_rx, dstInIdx_rx)       -- thanks chmaha <3

    local dstInLabel = dstInLabel_rx
    local dstInIdx = dstInIdx_rx

    local markerLabel = dstInLabel
    local markerColor = r.ColorToNative(22, 141, 195)

    local cursorPosition = (r.GetPlayState() == 0) and r.GetCursorPosition() or r.GetPlayPosition()
    r.DeleteProjectMarker(0, dstInIdx, false)
    r.AddProjectMarker2(0, false, cursorPosition, 0, markerLabel, dstInIdx, markerColor | 0x1000000)
end

-------------------------------------------

function se.GetCrossfade(tbl_mediaItem, xFadeLen)

    -- only works with symmetrical crossfades

    for i = 1, #tbl_mediaItem do
        if not tbl_mediaItem[i] then return end
    end
    if not xFadeLen then return end

    local item1FadeLen = r.GetMediaItemInfo_Value(tbl_mediaItem[1], "D_FADEOUTLEN")
    local item1FadeLenAuto = r.GetMediaItemInfo_Value(tbl_mediaItem[1], "D_FADEOUTLEN_AUTO")
    local item1FadeShape = r.GetMediaItemInfo_Value(tbl_mediaItem[1], "C_FADEOUTSHAPE")

    local item2FadeLen = r.GetMediaItemInfo_Value(tbl_mediaItem[2], "D_FADEINLEN")
    local item2FadeLenAuto = r.GetMediaItemInfo_Value(tbl_mediaItem[2], "D_FADEINLEN_AUTO")
    local item2FadeShape = r.GetMediaItemInfo_Value(tbl_mediaItem[2], "C_FADEINSHAPE")

    if item1FadeLen < item1FadeLenAuto then
        item1FadeLen = item1FadeLenAuto
    end

    if item2FadeLen < item2FadeLenAuto then
        item2FadeLen = item2FadeLenAuto
    end

    if item1FadeLen == item2FadeLen then
        return true, item1FadeLen, item1FadeShape, item2FadeShape
    else
        return false, xFadeLen
    end

end

-------------------------------------------------------------------
---* Creates a time selection
---* Selects only items in the top lane
---* Fades selected items in time selection using action 40916 (Item: Crossfade items within time selection)
---
---If curPos is nil, current cursor position will be used.
---@param xFadeLen number
---@param curPos number|nil
function se.SetCrossfade(xFadeLen, curPos)

    local currentCursorPos
    if curPos then
        currentCursorPos = curPos
    else
        currentCursorPos = r.GetCursorPosition()
    end

    local fadeStart = currentCursorPos - xFadeLen/2
    local fadeEnd = currentCursorPos + xFadeLen/2

    r.GetSet_LoopTimeRange2(0, true, false, fadeStart, fadeEnd, true)

    r.Main_OnCommand(40421, 0) -- Item: Select all items in track
    r.Main_OnCommand(40034, 0) -- Item grouping: Select all items in groups

    -- make sure only items in the topmost lane are affected
    se.DeselectItemsNotInTopLane()

    r.Main_OnCommand(40916, 0) -- Item: Crossfade items within time selection
    r.Main_OnCommand(40635, 0) -- Time selection: Remove time selection

end

-------------------------------------------

function se.SetCrossfade2(curPos, xFadeLen)

    -- ## set time selection ## --

    r.Main_OnCommand(40020, 0)        -- Time Selection: Remove

    r.SetEditCurPos(curPos - xFadeLen/2, false, false)
    r.Main_OnCommand(40625, 0)        -- Time selection: Set start point

    r.SetEditCurPos(curPos + xFadeLen/2, false, false)
    r.Main_OnCommand(40626, 0)        -- Time selection: Set end point

    -- ## perform fade (amagalma: smart crossfade) ## --

    r.Main_OnCommand(40916, 0) -- Item: Crossfade items within time selection

end
-------------------------------------------

function se.ResetFadeShape(tbl_mediaItem, xFadeShape)

    se.SetSingleItemGroupSelectedOnly(tbl_mediaItem[1])

    for i = 0, r.CountSelectedMediaItems(0) - 1 do

        local selItem = r.GetSelectedMediaItem(0, i)

        if selItem then
            r.SetMediaItemInfo_Value(selItem, "C_FADEOUTSHAPE", xFadeShape)
        end
    end

    se.SetSingleItemGroupSelectedOnly(tbl_mediaItem[2])

    for i = 0, r.CountSelectedMediaItems(0) - 1 do

        local selItem = r.GetSelectedMediaItem(0, i)

        if selItem then
            r.SetMediaItemInfo_Value(selItem, "C_FADEINSHAPE", xFadeShape)
        end
    end

end

------------------------------------------
---* safeLane = (-1): remove only topmost lanes' source gates
---* safeLane = 0: remove ALL source gates
---@param safeLane integer
---@param sourceLabelIn string
---@param sourceLabelOut string
function se.RemoveSourceGates(safeLane, sourceLabelIn, sourceLabelOut)

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

  se.DeselectAllItems()

end

------------------------------------------

function se.GetEditStates()

    local rippleStateAll = r.GetToggleCommandState(41991) -- Toggle ripple editing all tracks
    local rippleStatePer = r.GetToggleCommandState(41990) -- Toggle ripple editing per-track
    local trimContentState = r.GetToggleCommandState(41117) -- Options: Trim content behind media items when editing

    return rippleStateAll, rippleStatePer, trimContentState

end

------------------------------------------

function se.ResetEditStates(rippleStateAll, rippleStatePer, trimContentState)

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

function se.ToggleLockItemsInSourceLanes(lockState_rx)

    local lockState = lockState_rx

    local safeLanes = 1 -- Lanes that will not be locked, indexed from the topmost lane

    se.DeselectAllItems()

    r.SelectAllMediaItems(0, true)

    for i = 0, r.CountSelectedMediaItems(0) - 1 do

      local mediaItem = r.GetSelectedMediaItem(0, i)
      if not mediaItem then return end

      local itemLane = r.GetMediaItemInfo_Value(mediaItem, "I_FIXEDLANE")

      if itemLane >= safeLanes then

        r.SetMediaItemInfo_Value(mediaItem, "C_LOCK", lockState)

      end

    end

    se.DeselectAllItems()

end

------------------------------------------

function se.DebugBreakpoint()

    r.ShowMessageBox("this is a breakpoint message", "Debugging in Progress...", 0)

end

------------------------------------------

function se.ErrMsgMissingData()

    r.ShowMessageBox("Something went wrong while handling data.", "Missing Data", 0)

end

------------------------------------------

function se.ErrMsgHover()

    r.ShowMessageBox("Please hover the mouse over an item in order to extend items.", "Item Extender or Quick Fade unsuccessful", 0)

end

------------------------------------------------

function se.RescueExtender()

    local scriptCommand = r.NamedCommandLookup("_RS43a608374ea4fced06f7c4cf94c26724437b9a80")
    r.SetToggleCommandState(1, scriptCommand, -1)

end

------------------------------------------------

function se.CalcDstOffset(srcStart, srcEnd, dstStart, dstEnd)

    -- get amount that destination out needs to be moved by

    if srcEnd <= srcStart then return end
    if dstEnd <= dstStart then return end

    local srcLen = srcEnd - srcStart
    local dstLen = dstEnd - dstStart

    local difference = srcLen - dstLen

    return difference
end

-------------------------------------------------------------------

function se.ClearDestinationArea(selStart, selEnd)

    -- clear area between destination markers using time and item selections

    if not selStart then se.ErrMsgMissingData() return end
    if not selEnd then se.ErrMsgMissingData() return end

    r.SetEditCurPos(selStart, false, false)
    r.Main_OnCommand(r.NamedCommandLookup("_XENAKIOS_SELITEMSUNDEDCURSELTX"), 0)
    se.DeselectItemsNotInTopLane()
    r.Main_OnCommand(40757, 0) -- Item: Split items at edit cursor (no change selection)
    
    r.SetEditCurPos(selEnd, false, false)
    r.Main_OnCommand(r.NamedCommandLookup("_XENAKIOS_SELITEMSUNDEDCURSELTX"), 0)
    se.DeselectItemsNotInTopLane()
    r.Main_OnCommand(40757, 0) -- Item: Split items at edit cursor (no change selection)

    se.SetTimeSelection(selStart, selEnd)

    se.DeselectAllItems()
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

function se.ShiftDestinationItems(difference_rx, dstOutPos_rx)

    -- shift items only on topmost lane one by one (ripple only works with graphical input)
    -- media track needs to be selected

    local difference = difference_rx
    local dstOutPos = dstOutPos_rx

    se.DeselectAllItems()
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

    se.HealAllSplits()
    se.DeselectAllItems()

end

-------------------------------------------------------------------

function se.HealAllSplits()

    r.Main_OnCommand(40182, 0) -- Select All
    r.Main_OnCommand(40548, 0) -- Heal splits in items
    se.DeselectAllItems()

end

-------------------------------------------

function se.DeselectItemsNotInTopLane()

    local selectedItemsGUID = {}

    -- get all selected items

    for i = 0, r.CountSelectedMediaItems(0) - 1 do

        local mediaItem = r.GetSelectedMediaItem(0, i)

        if not mediaItem then return end

        local itemLane = r.GetMediaItemInfo_Value(mediaItem, "I_FIXEDLANE")

        if itemLane >= 1 then
            table.insert(selectedItemsGUID, r.BR_GetMediaItemGUID(mediaItem))
        end

    end

    -- perform selection / de-selection based on lane number

    for i = 0, #selectedItemsGUID do

        local mediaItem = r.BR_GetMediaItemByGUID(0, selectedItemsGUID[i])

        if mediaItem then
            r.SetMediaItemSelected(mediaItem, false)
        end

    end

end

-------------------------------------------------------------------

--- using Reaper Command ID 40289
function se.DeselectAllItems()

    r.Main_OnCommand(40289, 0) -- Deselect all items

end

-------------------------------------------------------------------

function se.ErrMsgStep()

    r.ShowMessageBox("step", "Debug Message", 0)

end

--------------------------
-- deprecated functions --
--------------------------

function se.GetItemsOnLane(flaggedGUID)

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

--------------
-- required --
--------------

GetSettings()
return se