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

local bool_MoveDstGateAfterEdit = true          -- move destination gate to end of last pasted item (recommended)

local bool_RemoveAllSourceGates = false         -- remove all source gates after the edit

local bool_TargetItemUnderMouse = false         -- select item under mouse (no click to select required)

local bool_KeepLaneSolo = true                  -- if false, lane solo jumps to comp lane after the edit
                                                -- if multiple lanes were soloed, only last soloed lane will be selected

---------------
-- variables --
---------------

local r = reaper

local modulePath = ({r.get_action_context()})[2]:match("^.+[\\/]")
package.path = modulePath .. "?.lua"
local so = require("soapy-seahorse_Edit_Functions")

local srcLabelIn = "SRC_IN"
local srcLabelOut = "SRC_OUT"
local dstLabelIn = "DST_IN"
local dstLabelOut = "DST_OUT"
local dstIdxIn = 996
local dstIdxOut = 997

----------
-- main --
----------

function Main()

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
        tbl_PlayingLanes = so.GetLanesPlaying(targetTrack)
    end

    ---##### calculate offset and move items on comp lane accordingly #####---

    local destinationDifference = CalcDstOffset(sourceGateIn, sourceGateOut, dstInPos, dstOutPos)
    ClearDestinationArea(dstInPos, dstOutPos)
    ShiftDestinationItems(destinationDifference, dstOutPos)
    
    ---##### src copy routine #####---

    so.SetTimeSelectionToSourceGates(sourceGateIn, sourceGateOut) -- time selection is used to copy items

    r.SetMediaItemSelected(sourceItem, true)
    r.Main_OnCommand(40034, 0) -- Item grouping: Select all items in groups

    r.Main_OnCommand(40060, 0) -- copy selected area of items (source material)

    r.Main_OnCommand(40289, 0) -- Deselect all items
    r.Main_OnCommand(40020, 0) -- Time Selection: Remove

    ---##### paste source to destination #####---

    so.PasteToTopLane(dstIdxIn)           -- paste source material

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
        so.SetLanesPlaying(targetTrack, tbl_PlayingLanes)
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

function ClearDestinationArea(selStart, selEnd)

    r.Main_OnCommand(40020, 0) -- Time selection: Remove (unselect) time selection and loop points

    r.SetEditCurPos(selStart, false, false)
    r.Main_OnCommand(r.NamedCommandLookup("_XENAKIOS_SELITEMSUNDEDCURSELTX"), 0)
    r.Main_OnCommand(40757, 0) -- Item: Split items at edit cursor (no change selection)
    r.Main_OnCommand(40625, 0)        -- Time selection: Set start point

    r.SetEditCurPos(selEnd, false, false)
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

    r.Main_OnCommand(40020, 0) -- Time selection: Remove (unselect) time selection and loop points
    
end

-------------------------------------------------------------------

function ShiftDestinationItems(difference_rx, dstOutPos_rx)

    -- media item needs to be selected

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

    HealAllSplits()
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

function RemoveSourceGates_old()

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

--------------------------------
-- main execution starts here --
--------------------------------

Main()
