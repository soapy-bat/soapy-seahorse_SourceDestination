--[[

source-destination edit: 4 point

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

local srcLabelIn = "SRC_IN"
local srcLabelOut = "SRC_OUT"
local dstLabelIn = "DST_IN"
local dstLabelOut = "DST_OUT"
local dstIdxIn = 996
local dstIdxOut = 997

----------
-- main --
----------

function main()

    r.Undo_BeginBlock()
    r.PreventUIRefresh(1)

    ---######### START ##########---

    ---##### buffer and set various edit states #####---

    local saveXFadeState = r.NamedCommandLookup("_SWS_SAVEXFD")
    r.Main_OnCommand(saveXFadeState, 1) -- SWS: Save auto crossfade state

    local rippleStateAll, rippleStatePer, trimContentState = SaveEditStates()

    r.Main_OnCommand(40309, 1) -- Set ripple editing off
    r.Main_OnCommand(41120, 1) -- Options: Enable trim content behind media items when editing

    ---##### get all coordinates #####---

    local cursorPos_origin = r.GetCursorPosition()

    -- future routines (MoveDstOut) will deselect the item,
    -- that's why we will get this one first:
    local sourceItem = r.GetSelectedMediaItem(0, 0)
    if not sourceItem then return end

    local sourceGateIn = GetSourceGateIn()
    if not sourceGateIn then return end

    local sourceGateOut = GetSourceGateOut()
    if not sourceGateOut then return end

    local dstInPos = GetDstGateIn()
    if not dstInPos then return end

    local dstOutPos = GetDstGateOut()
    if not dstOutPos then return end

    local targetTrack = r.GetMediaItem_Track(sourceItem)
    r.SetOnlyTrackSelected(targetTrack)

    ---##### calculate offset and move items on comp lane accordingly #####---

    local destinationDifference = CalcDstOffset(sourceGateIn, sourceGateOut, dstInPos, dstOutPos)
    MoveDstOut(destinationDifference, dstOutPos)

    ---##### continue src copy routine #####---

    SetTimeSelectionToSourceGates(sourceGateIn, sourceGateOut) -- time selection is used to copy items

    r.SetMediaItemSelected(sourceItem, true)
    r.Main_OnCommand(40034, 0) -- Item grouping: Select all items in groups

    r.Main_OnCommand(40060, 0) -- copy selected area of items (source material)

    r.Main_OnCommand(40289, 0) -- Deselect all items

    r.Main_OnCommand(40020, 0) -- Time Selection: Remove

    ---##### paste source to destination #####---

    ToggleLockItemsInSourceLanes(1)

    PasteToTopLane()           -- paste source material

    ToggleLockItemsInSourceLanes(0)

    ---##### cleanup: set new dst gate, set xfade, clean up src gates #####---

    local cursorPos_end = r.GetCursorPosition()

    if bool_AutoCrossfade then
        -- go to start of pasted item
        r.GoToMarker(0, dstIdxIn, false)
        SetCrossfade(xfadeLen)

        r.SetEditCurPos(cursorPos_end, false, false) -- go to end of pasted item
        SetCrossfade(xfadeLen)
    end

    RemoveSourceGates(-1)    -- remove src gates from newly pasted material

    if not bool_AutoCrossfade then
        r.Main_OnCommand(40020, 0) -- Time Selection: Remove
    end

    if bool_moveDstGateAfterEdit then
        r.SetEditCurPos(cursorPos_end, false, false) -- go to end of pasted item
        SetDstGateIn()        -- move destination gate in to end of pasted material (assembly line style)
    end

    if bool_removeAllSourceGates then
        RemoveSourceGates(0)
    end

    r.DeleteProjectMarker(0, dstIdxOut, false)

    r.Main_OnCommand(40289, 0) -- Deselect all items
    r.SetEditCurPos(cursorPos_origin, false, false) -- go to original cursor position

    ResetEditStates(rippleStateAll, rippleStatePer, trimContentState)

    local restoreXFadeState = r.NamedCommandLookup("_SWS_RESTOREXFD")
    r.Main_OnCommand(restoreXFadeState, 0) -- SWS: Restore auto crossfade state

    ---######### END ##########---

    r.PreventUIRefresh(-1)
    r.UpdateArrange()
    r.Undo_EndBlock("ReaPyr 4 point edit", -1)

end

---------------
-- functions --
---------------

function CalcDstOffset(srcStart, srcEnd, dstStart, dstEnd)

    -- get amount that destination out needs to be moved by

    if srcEnd <= srcStart then return end
    if dstEnd <= dstStart then return end

    local srcLen = srcEnd - srcStart
    local dstLen = dstEnd - dstStart

    local difference = srcLen - dstLen

    return difference
end

-------------------------------------------------------------------

function GetSourceGateIn() -- Find SRC_IN marker
  local sourceInPos = GetTakeMarkerPositionByName(srcLabelIn)
  if sourceInPos then
      return sourceInPos
  else
      r.ShowMessageBox(srcLabelIn .. " not found.", "Take marker not found", 0)
      return
  end
end

-------------------------------------------------------------------

function GetSourceGateOut() -- Find SRC_OUT marker
  local sourceOutPos = GetTakeMarkerPositionByName(srcLabelOut)
  if sourceOutPos then
      return sourceOutPos
  else
      r.ShowMessageBox(srcLabelOut .. " not found.", "Take marker not found", 0)
      return
  end
end

-------------------------------------------------------------------

function GetDstGateIn() -- Find DST_IN marker

    local _, numMarkers, numRegions = r.CountProjectMarkers(0)

    for i = 0, numMarkers + numRegions do

        local _, _, dstInPos, _, _, markerIndex = r.EnumProjectMarkers(i)

        if markerIndex == dstIdxIn then
            return dstInPos
        end
    end

end

-------------------------------------------------------------------

function GetDstGateOut() -- Find DST_OUT marker

    local _, numMarkers, numRegions = r.CountProjectMarkers(0)

    for i = 0, numMarkers + numRegions do

        local _, _, dstOutPos, _, _, markerIndex = r.EnumProjectMarkers(i)

        if markerIndex == dstIdxOut then
            return dstOutPos
        end
    end

end

-------------------------------------------------------------------

function SetTimeSelectionToSourceGates(srcStart, srcEnd)

    -- Function to set a Time Selection based on given start and end points

    if srcEnd <= srcStart then return false end

    r.GetSet_LoopTimeRange2(0, true, false, srcStart, srcEnd, true)

end

-------------------------------------------------------------------

function PasteToTopLane()

    r.Main_OnCommand(42790, 0) -- play only first lane
    r.Main_OnCommand(43098, 0) -- show/play only one lane

    r.GoToMarker(0, dstIdxIn, false)
    r.Main_OnCommand(42398, 0) -- Items: paste items/tracks

    r.Main_OnCommand(43099, 0) -- show/play all lanes

end

-------------------------------------------------------------------

function MoveDstOut(difference_rx, dstOutPos_rx)

    local difference = difference_rx
    local dstOutPos = dstOutPos_rx

    r.GoToMarker(0, dstIdxIn, false)
    r.Main_OnCommand(r.NamedCommandLookup("_XENAKIOS_SELITEMSUNDEDCURSELTX"), 0)
    r.Main_OnCommand(40757, 0) -- Item: Split items at edit cursor (no change selection)
    r.Main_OnCommand(40625, 0)        -- Time selection: Set start point

    r.GoToMarker(0, dstIdxOut, false)
    r.Main_OnCommand(r.NamedCommandLookup("_XENAKIOS_SELITEMSUNDEDCURSELTX"), 0)
    r.Main_OnCommand(40757, 0) -- Item: Split items at edit cursor (no change selection)
    r.Main_OnCommand(40626, 0)        -- Time selection: Set end point

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

    HealAllSplits()
    r.Main_OnCommand(40289, 0) -- Deselect all items

end

-------------------------------------------------------------------

function GetItemsOnLane(flaggedGUID_rx)

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

function RemoveSourceGates()

    local numSelectedItems = r.CountSelectedMediaItems(0)

    -- Iterate through selected items
    for i = 0, numSelectedItems - 1 do

        -- Get the active media item
        local mediaItem = r.GetSelectedMediaItem(0, i)

        if not mediaItem then return end

        -- Get the active take
        local activeTake = r.GetActiveTake(mediaItem)

        if activeTake then
            -- Remove existing Gate markers
            local numMarkers = r.GetNumTakeMarkers(activeTake)
            for i = numMarkers, 0, -1 do
                local _, markerType, _, _, _ = r.GetTakeMarker(activeTake, i)
                if markerType == srcLabelIn then
                    r.DeleteTakeMarker(activeTake, i)
                end
                if markerType == srcLabelOut then
                    r.DeleteTakeMarker(activeTake, i)
                end
            end
        end
    end
end

-------------------------------------------------------------------

function SetDstGateIn()       -- thanks chmaha <3
    local markerLabel = dstLabelIn
    local markerColor = r.ColorToNative(22, 141, 195)

    local cursorPosition = (r.GetPlayState() == 0) and r.GetCursorPosition() or r.GetPlayPosition()
    r.DeleteProjectMarker(0, dstIdxIn, false)
    r.AddProjectMarker2(0, false, cursorPosition, 0, markerLabel, dstIdxIn, markerColor | 0x1000000)
end

-------------------------------------------------------------------

function SetCrossfade(xfadeLen)    -- thanks chmaha <3

    -- assumes that the cursor is at the center of the "fade in spe"

    local currentCursorPos = r.GetCursorPosition()

    r.Main_OnCommand(40020, 0)        -- Time Selection: Remove

    r.SetEditCurPos(currentCursorPos - xfadeLen/2, false, false)

    r.Main_OnCommand(40625, 0)        -- Time selection: Set start point

    r.SetEditCurPos(currentCursorPos + xfadeLen/2, false, false)

    r.Main_OnCommand(40626, 0)        -- Time selection: Set end point

    r.Main_OnCommand(40289, 0) -- Deselect all items
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

    for i = 1, #selectedItemsGUID do

        local mediaItem = r.BR_GetMediaItemByGUID(0, selectedItemsGUID[i])
        if mediaItem then
            r.SetMediaItemSelected(mediaItem, false)
        end
    end

    r.Main_OnCommand(40916, 0) -- Item: Crossfade items within time selection

    r.Main_OnCommand(40635, 0) -- Time selection: Remove time selection

end

------------------------------------------

function RemoveSourceGates(safeLane_rx)

    -- (-1): remove ONLY topmost lanes' src gates
    local safeLane = safeLane_rx

    r.Main_OnCommand(40289, 0) -- Deselect all items

    r.SelectAllMediaItems(0, true)

    local numSelectedItems = r.CountSelectedMediaItems(0)

    for i = 0, numSelectedItems - 1 do

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
                    if markerType == srcLabelIn then
                        r.DeleteTakeMarker(activeTake, i)
                    end
                    if markerType == srcLabelOut then
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
                        if markerType == srcLabelIn then
                            r.DeleteTakeMarker(activeTake, i)
                        end
                        if markerType == srcLabelOut then
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

function SaveEditStates()

    local rippleStateAll = r.GetToggleCommandState(41991) -- Toggle ripple editing all tracks
    local rippleStatePer = r.GetToggleCommandState(41990) -- Toggle ripple editing per-track
    local trimContentState = r.GetToggleCommandState(41117) -- Options: Trim content behind media items when editing

    return rippleStateAll, rippleStatePer, trimContentState

end

------------------------------------------

function ResetEditStates(rippleStateAll, rippleStatePer, trimContentState)

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

function ToggleLockItemsInSourceLanes(lockState_rx)

    local lockState = lockState_rx

    local safeLanes = 1 -- Lanes that will not be locked, indexed from the topmost lane

    r.Main_OnCommand(40289, 0) -- Deselect all items

    r.SelectAllMediaItems(0, true)

    for i = 0, r.CountSelectedMediaItems(0) - 1 do

      local mediaItem = r.GetSelectedMediaItem(0, i)

      local itemLane = r.GetMediaItemInfo_Value(mediaItem, "I_FIXEDLANE")

      if itemLane >= safeLanes then

        r.SetMediaItemInfo_Value(mediaItem, "C_LOCK", lockState)

      end

    end

    r.Main_OnCommand(40289, 0) -- Deselect all items

  end

-------------------------------------------------------------------

function HealAllSplits()

    r.Main_OnCommand(40182, 0) -- Select All
    r.Main_OnCommand(40548, 0) -- Heal splits in items
    r.Main_OnCommand(40289, 0) -- Deselect all items

  end

--------------------------
-- deprecated functions --
--------------------------

function SplitItemAtDstGateIn()       -- split item at destination gate in, thanks chmaha <3

    r.Main_OnCommand(40927, 0)        -- Options: Enable auto-crossfade on split
    r.Main_OnCommand(40939, 0)        -- Track: Select track 01
    r.GoToMarker(0, dstIdxIn, false)
    local selectUnder = r.NamedCommandLookup("_XENAKIOS_SELITEMSUNDEDCURSELTX")
    r.Main_OnCommand(selectUnder, 0)  -- Xenakios/SWS: Select items under edit cursor on selected tracks
    r.Main_OnCommand(40034, 0)        -- Item grouping: Select all items in groups
    local selectedItems = r.CountSelectedMediaItems(0)
    r.Main_OnCommand(40912, 0)        -- Options: Toggle auto-crossfade on split (OFF)
    if selectedItems > 0 then
        r.Main_OnCommand(40186, 0)    -- Item: Split items at edit or play cursor (ignoring grouping)
    end
    r.Main_OnCommand(40289, 0)        -- Item: Unselect all items

end

-------------------------------------------------------------------

function SplitItemAtDstGateIn2()       -- split item at destination gate in, thanks chmaha <3

    --r.Main_OnCommand(40927, 0)       -- Options: Enable auto-crossfade on split
    --r.Main_OnCommand(40939, 0)       -- Track: Select track 01
    r.GoToMarker(0, dstIdxIn, false)
    local selectUnder = r.NamedCommandLookup("_XENAKIOS_SELITEMSUNDEDCURSELTX")
    r.Main_OnCommand(selectUnder, 0)   -- Xenakios/SWS: Select items under edit cursor on selected tracks
    r.Main_OnCommand(40034, 0)         -- Item grouping: Select all items in groups
    local selectedItems = r.CountSelectedMediaItems(0)
    --r.Main_OnCommand(40912, 0)        -- Options: Toggle auto-crossfade on split (OFF)
    if selectedItems > 0 then
        r.Main_OnCommand(40186, 0)     -- Item: Split items at edit or play cursor (ignoring grouping)
    end
    r.Main_OnCommand(40289, 0)         -- Item: Unselect all items

end

-------------------------------------------------------------------

function SetRazorEditToSourceGates(srcStart, srcEnd)
-- Function to set a Razor Edit Area based on given start and end points

    if srcEnd <= srcStart then return false end

    local countSelTrks = r.CountSelectedTracks( 0 )
    local countAllTrks = r.CountTracks( 0 )

    for i = 0, countAllTrks - 1 do
      local track = r.GetTrack(0, i)
      if countSelTrks == 0 or r.IsTrackSelected( track ) then
        local razorStr = srcStart .. " " .. srcEnd .. ' ""'
        local retval, stringNeedBig = r.GetSetMediaTrackInfo_String( track, "P_RAZOREDITS", razorStr, true )
      end
    end

end

-------------------------------------------------------------------

function GetTakeMarkerPositionByName(name)
-- Function to search for take markers by name in selected items, allows for multiple sources

    if bool_TargetItemUnderMouse then
        r.Main_OnCommand(40289, 0) -- Item: Unselect (clear selection of) all items
        r.Main_OnCommand(40528, 0) -- Item: Select item under mouse cursor
    end

    r.Main_OnCommand(40034, 0) -- Item grouping: Select all items in groups

    local numSelectedItems = r.CountSelectedMediaItems(0)

     -- Iterate through selected items
     for i = 0, numSelectedItems - 1 do
         local selectedItem = r.GetSelectedMediaItem(0, i)
         local take = r.GetActiveTake(selectedItem)

        local numMarkers = r.GetNumTakeMarkers(take)

        for k = 0, numMarkers - 1 do
            local pos, name_, _  = r.GetTakeMarker(take, k)
            if name_ == name then
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

--------------------------------
-- main execution starts here --
--------------------------------

main()
