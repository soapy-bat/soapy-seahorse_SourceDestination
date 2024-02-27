-------------------
-- user settings --
-------------------

-- true = yes, false = no

local xfadeLen = 0.05 -- default: 50 milliseconds (0.05)

local bool_moveDstGateAfterEdit = true          -- move destination gate to end of last pasted item (recommended)

local bool_removeAllSourceGates = false         -- remove all source gates after the edit

local bool_experimentalAutoCrossfade = true    -- works, but is slower and makes the screen flicker.

---------------
-- variables --
---------------

local r = reaper

local sourceGateIn, sourceGateOut
local gateIsSet = true

local sourceLabelIn = "SRC_IN"
local sourceLabelOut = "SRC_OUT"
local destinationLabelIn = "DST_IN"
local destinationIdxIn = 996
local destinationLabelOut = "DST_OUT"
local destinationIdxOut = 997

local cursorPos_origin
local cursorPos_end

----------
-- main --
----------

-- at least one track that the items to be edited are on needs to be selected.
-- I recommend lokasenna: track selection follows item selection.

function main()

  r.Undo_BeginBlock()

  if not bool_experimentalAutoCrossfade then
    r.PreventUIRefresh( 1 )
  end

  ---######### START ##########---

  r.Main_OnCommand(41119, 0) -- disable autocrossfade (less weird when pasting items)
  cursorPos_origin = r.GetCursorPosition()
  
  gateIsSet = GetSourceGateIn()

    if gateIsSet then

          gateIsSet = GetSourceGateOut()

          if gateIsSet then
              
            SetTimeSelectionToSourceGates(sourceGateIn, sourceGateOut) -- time selection is used to copy items
             
            r.Main_OnCommand(40060, 0) -- copy selected area of items (source material)

            r.Main_OnCommand(40289, 0) -- Deselect all items
            r.Main_OnCommand(40020, 0) -- Time Selection: Remove

            PasteToTopLane()           -- paste source material

            cursorPos_end = r.GetCursorPosition()

            -- go to start of pasted item
            r.GoToMarker(0, destinationIdxIn, false)


            if bool_experimentalAutoCrossfade then
                SetCrossfade2(xfadeLen)
            end
              
            if not bool_experimentalAutoCrossfade then
                RemoveSourceGates()        -- delete take markers at destination in pasted material
                r.Main_OnCommand(40020, 0) -- Time Selection: Remove
            end
              
            if bool_moveDstGateAfterEdit then
                r.SetEditCurPos(cursorPos_end, false, false) -- go to end of pasted item
                SetDstGateIn()        -- move destination gate in to end of pasted material (assembly line style)
            end
              
            if bool_removeAllSourceGates or bool_experimentalAutoCrossfade then
                RemoveAllSourceGates()
            end

            r.Main_OnCommand(40289, 0) -- Deselect all items
            r.SetEditCurPos(cursorPos_origin, false, false) -- go to original cursor position

          else return

          end

  else return
  
  end
  
  r.Main_OnCommand(41118, 0) -- enable autocrossfade again

  ---######### END ##########---
  
  r.PreventUIRefresh(-1)
  r.UpdateArrange()
  r.Undo_EndBlock("ReaPyr 3 point assembly", -1)

end

---------------
-- functions --
---------------

function GetSourceGateIn() -- Find SRC_IN marker
  local sourceInPos = GetTakeMarkerPositionByName(sourceLabelIn)
  if sourceInPos then
      sourceGateIn = sourceInPos
      return true
  else
      r.ShowMessageBox(sourceLabelIn .. " not found.", "Take marker not found", 0)
      return false
  end
end

-------------------------------------------------------------------

function GetSourceGateOut() -- Find SRC_OUT marker
  local sourceOutPos = GetTakeMarkerPositionByName(sourceLabelOut)
  if sourceOutPos then
      sourceGateOut = sourceOutPos
      return true
  else
      r.ShowMessageBox(sourceLabelOut .. " not found.", "Take marker not found", 0)
      return false
  end
end

-------------------------------------------------------------------

-- Function to set a Time Selection based on given start and end points

function SetTimeSelectionToSourceGates(srcStart, srcEnd)

    if srcEnd <= srcStart then return false end
    
    r.GetSet_LoopTimeRange2(0, true, false, srcStart, srcEnd, true)
    
end

-------------------------------------------------------------------

function PasteToTopLane() -- needs a workaround because you can't (yet?) select lanes

  r.GoToMarker(0, destinationIdxIn, false)
  r.Main_OnCommand(42790, 0) -- play only first lane
  r.Main_OnCommand(43098, 0) -- show/play only one lane
  r.Main_OnCommand(42398, 0) -- Items: paste items/tracks
  r.Main_OnCommand(43099, 0) -- show/play all lanes

end

-------------------------------------------------------------------

function RemoveSourceGates()

  local numSelectedItems = r.CountSelectedMediaItems(0)
  
   -- Iterate through selected items
    for i = 0, numSelectedItems - 1 do

        -- Get the active media item
        local mediaItem = r.GetSelectedMediaItem(0, i)
        
        if mediaItem then
            -- Get the active take
            local activeTake = r.GetActiveTake(mediaItem)
        
            if activeTake then
                -- Remove existing Gate markers
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

-------------------------------------------------------------------

function SetDstGateIn()       -- thanks chmaha <3
    local markerLabel = destinationLabelIn
    local markerColor = r.ColorToNative(22, 141, 195)

    local cursorPosition = (r.GetPlayState() == 0) and r.GetCursorPosition() or r.GetPlayPosition()
    r.DeleteProjectMarker(NULL, destinationIdxIn, false)
    r.AddProjectMarker2(0, false, cursorPosition, 0, markerLabel, destinationIdxIn, markerColor | 0x1000000)
end

------------------------------------------

function SetCrossfade2(xfadeLen)    -- thanks chmaha <3
    
    -- experimental, because the UI needs to be constantly updated
    
    -- assumes that the cursor is at the center of the "fade in spe"

    local currentCursorPos = r.GetCursorPosition()

    r.Main_OnCommand(40020, 0)        -- Time Selection: Remove

    r.SetEditCurPos(currentCursorPos - xfadeLen/2, false, false)

    r.Main_OnCommand(40625, 0)        -- Time selection: Set start point

    r.SetEditCurPos(currentCursorPos + xfadeLen/2, false, false)

    r.Main_OnCommand(40626, 0)        -- Time selection: Set end point

    -- the following workaround is necessary because you cannot select individual lanes
    -- I would have used: select items on selected tracks in time selection (40718)

    r.Main_OnCommand(42790, 0) -- play only first lane
    r.Main_OnCommand(43098, 0) -- show/play only one lane

    r.Main_OnCommand(40421, 0) -- Item: Select all items in track
    r.Main_OnCommand(40034, 0) -- Item grouping: Select all items in groups 
    r.Main_OnCommand(40916, 0) -- Item: Crossfade items within time selection

    r.Main_OnCommand(40635, 0) -- Time selection: Remove time selection

    r.Main_OnCommand(43099, 0) -- show/play all lanes


end

------------------------------------------

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
  
  r.Main_OnCommand(40289, 0) -- Deselect all items
  
end


--------------------------
-- deprecated functions --
--------------------------

function SetCrossfade(xfadeLen)    -- thanks chmaha <3
    
    -- assumes that the cursor is at the center of the "fade in spe"
    -- MoveEditCursor is not silent

    r.Main_OnCommand(40020, 0)        -- Time Selection: Remove

    r.MoveEditCursor(-xfadeLen/2, false) -- try using SetEditCurPos()
    r.Main_OnCommand(40625, 0)        -- Time selection: Set start point
    r.MoveEditCursor(xfadeLen, false)
    r.Main_OnCommand(40626, 0)        -- Time selection: Set end point
    r.Main_OnCommand(40718, 0)        -- select items on selected tracks in time selection
    r.Main_OnCommand(40916, 0)        -- Item: Crossfade items within time selection

    r.Main_OnCommand(40635, 0)        -- Time selection: Remove time selection

    -- _XENAKIOS_SELFIRSTOFSELTRAX select first of selected tracks

end

-------------------------------------------------------------------

function SplitItemAtDstGateIn()       -- split item at destination gate in, thanks chmaha <3

    r.Main_OnCommand(40927, 0)        -- Options: Enable auto-crossfade on split
    r.Main_OnCommand(40939, 0)        -- Track: Select track 01
    r.GoToMarker(0, destinationIdxIn, false)
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
    r.GoToMarker(0, destinationIdxIn, false)
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

------------------------------------------

function SetCursorToSrcStart(srcStart)
  
  r.SetEditCurPos(srcStart, false, false)

end

-------------------------------------------------------------------

-- Function to set a Razor Edit Area based on given start and end points

function SetRazorEditToSourceGates(srcStart, srcEnd)

    if srcEnd <= srcStart then return false end

    countSelTrks = r.CountSelectedTracks( 0 )
    countAllTrks = r.CountTracks( 0 )

    for i = 0, count_tracks - 1 do
      local track = r.GetTrack(0, i)
      if countSelTrks == 0 or r.IsTrackSelected( track ) then
        local razorStr = srcStart .. " " .. srcEnd .. ' ""'
        local retval, stringNeedBig = r.GetSetMediaTrackInfo_String( track, "P_RAZOREDITS", razorStr, true )
      end
    end

end

-------------------------------------------------------------------

-- Function to search for take markers by name in selected items, allows for multiple sources
function GetTakeMarkerPositionByName(name)

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

-------------------------------------------------------------------

function HealAllSplits()

  r.Main_OnCommand(40182, 0) -- Select All
  r.Main_OnCommand(40548, 0) -- Heal splits in items
  r.Main_OnCommand(40289, 0) -- Deselect all items

end

-------------------------------------------------------------------

function SelectAllItemsInTopLane() -- only works if the UI is allowed to refresh

    r.Main_OnCommand(42790, 0) -- play only first lane
    r.Main_OnCommand(43098, 0) -- show/play only one lane

    r.Main_OnCommand(40421, 0) -- Item: Select all items in track
    r.Main_OnCommand(40034, 0) -- Item grouping: Select all items in groups
  
    r.Main_OnCommand(43099, 0) -- show/play all lanes

end

-------------------------------------------------------------------

--------------------------------
-- main execution starts here --
--------------------------------

main()
