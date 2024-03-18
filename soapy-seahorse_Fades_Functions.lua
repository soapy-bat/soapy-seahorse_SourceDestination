--[[

source-destination fades: functions

This file is part of the soapy-seahorse package.
It is required by the various audition scripts.

(C) 2024 the soapy zoo
copyleft: chmaha
thanks: fricia, X-Raym, GPT3.5

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
local so = {}

--------------------------------------------
-- functions: information retrieval (get) --
--------------------------------------------

function so.GetItemsNearMouse(cursorBias_rx)

  local bool_success = false

  local cursorBias = cursorBias_rx

  local mouseTarget
  local tbl_itemGUID = {}

  -- mouseX and transport location are compatible
  
  -- Berücksichtigung der Position nur, wenn Maus auf Item ist
  local mediaItem, mouseX = r.BR_ItemAtMouseCursor()
  if not mediaItem then return false end
  
  local itemStart = r.GetMediaItemInfo_Value(mediaItem, "D_POSITION")
  local itemEnd = itemStart + r.GetMediaItemInfo_Value(mediaItem, "D_LENGTH")
  
  local distanceToStart = math.abs(mouseX - itemStart)
  local distanceToEnd = math.abs(itemEnd - mouseX)

  if distanceToStart > distanceToEnd then

    -- mouse over 1st item

    tbl_itemGUID[1] = r.BR_GetMediaItemGUID(mediaItem)
    mouseTarget = 1
    tbl_itemGUID[2] = so.GetNeighbor(tbl_itemGUID[1], mouseTarget)

    bool_success = so.SetEditCurPosCenterEdges(tbl_itemGUID[1], tbl_itemGUID[2], cursorBias)

    return bool_success, tbl_itemGUID[1], tbl_itemGUID[2], mouseTarget

  else

    -- mouse over 2nd item

    tbl_itemGUID[2] = r.BR_GetMediaItemGUID(mediaItem)
    mouseTarget = 2
    tbl_itemGUID[1] = so.GetNeighbor(tbl_itemGUID[2], mouseTarget)

    bool_success = so.SetEditCurPosCenterEdges(tbl_itemGUID[1], tbl_itemGUID[2], cursorBias)

    return bool_success, tbl_itemGUID[1], tbl_itemGUID[2], mouseTarget

  end

end

-------------------------------------------------------

function so.GetNeighbor(flaggedGUID_rx, mouseTarget_rx)

  -- mouse target tells us if the selected item is the first or the second one (in or out of the targeted fade)
  local flaggedGUID = flaggedGUID_rx
  local mouseTarget = mouseTarget_rx

  local flaggedIndex

  -- get array of items on fixed lane
  local tbl_laneItemsGUID = so.GetItemsOnSameLane(flaggedGUID)
  if not tbl_laneItemsGUID then return end

  -- get index of flagged item

  for i = 0, #tbl_laneItemsGUID do

    local GUID = tbl_laneItemsGUID[i]

    if GUID == flaggedGUID then
      flaggedIndex = i
    end

  end

  if not flaggedIndex then
    r.ShowMessageBox("Something went wrong: Index is nil", "Could not retrieve targeted item", 0)
    return
  end

  if flaggedIndex == #tbl_laneItemsGUID and mouseTarget == 1 then
    r.ShowMessageBox("You probably tried to audition the last fade of the project, which is not (yet) supported.", "No fade to audition", 0)
    return
  end  

  -- find neighbor

  if mouseTarget == 1 then
  
    mediaItem = r.BR_GetMediaItemByGUID(0, tbl_laneItemsGUID[flaggedIndex + 1])
    local neighborGUID = r.BR_GetMediaItemGUID(mediaItem)
    
    return neighborGUID
    
  elseif mouseTarget == 2 then
  
    mediaItem = r.BR_GetMediaItemByGUID(0, tbl_laneItemsGUID[flaggedIndex - 1])
    local neighborGUID = r.BR_GetMediaItemGUID(mediaItem)
    
    return neighborGUID
  
  end

end

-------------------------------------------------------

function so.GetItemsOnSameLane(flaggedGUID_rx)

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

-------------------------------------------------------

function so.GetAllItemsGUID()

  local itemCount = r.CountMediaItems(0)
  local tbl_projectItemsGUID = {}

  for i = 0, itemCount - 1 do

    local mediaItem = r.GetMediaItem(0, i)
    if mediaItem then
      local itemGUID = r.BR_GetMediaItemGUID(mediaItem)
      if itemGUID then

        table.insert(tbl_projectItemsGUID, itemGUID)

      end
    end
  end

  return tbl_projectItemsGUID

end

-------------------------------------------------------

function so.GetGroupedItems(itemGUID_rx)

  local itemGUID = itemGUID_rx
  local mediaItem = r.BR_GetMediaItemByGUID(0, itemGUID)

  local tbl_groupedItemsGUID = {}

  local groupID = r.GetMediaItemInfo_Value(mediaItem, "I_GROUPID")
  if groupID ~= 0 then

    local tbl_allItemsGUID = so.GetAllItemsGUID()

    for i = 1, #tbl_allItemsGUID do

      local mediaItem = r.BR_GetMediaItemByGUID(0, tbl_allItemsGUID[i])

      if mediaItem then

        if r.GetMediaItemInfo_Value(mediaItem, "I_GROUPID") == groupID then
          -- table.insert indexes from 1, not from 0 (lua convention)
          table.insert(tbl_groupedItemsGUID, r.BR_GetMediaItemGUID(mediaItem))
        end

      end
    end
  end

  return tbl_groupedItemsGUID

end

------------------------------------------------------
-- functions: parameter manipulation (set / toggle) --
------------------------------------------------------

function so.SetEditCurPosCenterEdges(item1GUID_rx, item2GUID_rx, cursorBias_rx)

  local bool_success = false

  local tbl_itemGUID = {}
  tbl_itemGUID[1] = item1GUID_rx
  tbl_itemGUID[2] = item2GUID_rx

  local cursorBias = cursorBias_rx

  local mediaItem = {}
  local itemStart = {}
  local itemEnd = {}

  for i = 1, 2 do
    mediaItem[i] = r.BR_GetMediaItemByGUID(0, tbl_itemGUID[i])
    if mediaItem[i] then
      itemStart[i] = r.GetMediaItemInfo_Value(mediaItem[i], "D_POSITION")
      itemEnd[i] = itemStart[i] + r.GetMediaItemInfo_Value(mediaItem[i], "D_LENGTH")
    end
  end

  if mediaItem[1] and mediaItem[2] then
    -- find center between item edges even if they are not faded / asymmetrically faded

    local newCurPos

    if itemStart[2] <= itemEnd[1] then
      newCurPos = itemStart[2]
    else
      newCurPos = itemEnd[1]
    end

    newCurPos = newCurPos + (((itemEnd[1] - itemStart[2]) * cursorBias) / 2)

    r.SetEditCurPos(newCurPos, false, false)
    bool_success = true

  else
    bool_success = false
  end

  return bool_success

end

-------------------------------------------------------

function so.ItemExtender(item1GUID_rx, item2GUID_rx, extendedTime_rx, itemToExtend_rx, extendRestoreSwitch_rx)

  local tbl_itemGUID = {}
  tbl_itemGUID[1] = item1GUID_rx
  tbl_itemGUID[2] = item2GUID_rx

  local extendedTime = extendedTime_rx
  local itemToExtend = itemToExtend_rx
  local extendRestoreSwitch = extendRestoreSwitch_rx    -- 1 = extend, -1 = restore // to make it easier when calculating new item edges (see so.LenghtenItem)

  local mediaItem = {}
  local itemStart = {}
  local itemEnd = {}
  local itemLength = {}

  local pri, sec

  if itemToExtend == 1 then
    pri = 1
    sec = 2
  elseif itemToExtend == 2 then
    pri = 2
    sec = 1
  end

  -- ###### lenghten primary item ###### --

  mediaItem[pri] = r.BR_GetMediaItemByGUID(0, tbl_itemGUID[pri])

  if mediaItem[pri] then
    bool_success = so.LenghtenItem(mediaItem[pri], pri, extendRestoreSwitch, extendedTime)
  end
  
  -- ###### mute secondary item ###### --

  local itemsToMute = so.GetAllItemsGUID()
  local safeItems = so.GetGroupedItems(tbl_itemGUID[pri])
  local muteState = extendRestoreSwitch

  if muteState == -1 then
    muteState = 0
  end

  local mutedItems = so.ToggleItemMute(itemsToMute, safeItems, muteState)

  r.Main_OnCommand(40289, 0) -- Deselect all items

  return tbl_itemGUID[1], tbl_itemGUID[2], extendedTime, itemToExtend, mutedItems

end

-------------------------------------------------------

function so.LenghtenItem(mediaItem_rx, pri_rx, extendRestoreSwitch_rx, extendedTime_rx)

  -- function assumes all items in group to be at the same length and position

  local mediaItem = mediaItem_rx
  local pri = pri_rx
  local extendRestoreSwitch = extendRestoreSwitch_rx
  local extendedTime = extendedTime_rx

  local bool_success = false

  r.Main_OnCommand(40289, 0) -- Deselect all items
  r.SetMediaItemSelected(mediaItem, 1)
  r.Main_OnCommand(40034, 0) -- Item grouping: Select all items in groups
  
  local itemStart = r.GetMediaItemInfo_Value(mediaItem, "D_POSITION")
  local itemLength = r.GetMediaItemInfo_Value(mediaItem, "D_LENGTH")
  local itemEnd = itemStart + itemLength

  -- the magic happens here
  if pri == 1 then

    local newEnd = itemEnd + (extendedTime * extendRestoreSwitch)
  
    for t = 0, r.CountSelectedMediaItems(0) - 1 do
      local currentItem = r.GetSelectedMediaItem(0, t)
      r.BR_SetItemEdges(currentItem, itemStart, newEnd)
    end

    bool_success = true

  -- ...and here
  elseif pri == 2 then

    local newStart = itemStart - (extendedTime * extendRestoreSwitch)
  
    for t = 0, r.CountSelectedMediaItems(0) - 1 do
      local currentItem = r.GetSelectedMediaItem(0, t)
      r.BR_SetItemEdges(currentItem, newStart, itemEnd)
    end

    bool_success = true

  end

  r.Main_OnCommand(40289, 0) -- Deselect all items

  return bool_success, mediaItem, pri, extendRestoreSwitch

end

-------------------------------------------------------

function so.ToggleItemMute(tbl_mediaItemGUIDs_rx, tbl_safeItemsGUID_rx, muteState_rx)

  local tbl_mediaItemGUIDs = tbl_mediaItemGUIDs_rx
  local tbl_safeItemsGUID = tbl_safeItemsGUID_rx
  local muteState = muteState_rx

  local tbl_mutedItems = {}

  for h = 1, #tbl_mediaItemGUIDs do

    local tbl_groupedItems = so.GetGroupedItems(tbl_mediaItemGUIDs[h])

    for k = 1, #tbl_groupedItems do

      local bool_foundSafeItem = false

      for i = 1, #tbl_safeItemsGUID do
        if tbl_groupedItems[k] == tbl_safeItemsGUID[i] then
          bool_foundSafeItem = true
          break
        end
      end

      if not bool_foundSafeItem then
        local mediaItem = r.BR_GetMediaItemByGUID(0, tbl_groupedItems[k])
        if mediaItem then
          table.insert(tbl_mutedItems, tbl_groupedItems[k])
          r.SetMediaItemInfo_Value(mediaItem, "B_MUTE", muteState)
        end
      end

    end
  end

  return tbl_mutedItems

end

-------------------------------------------------------

function so.ToggleItemMuteState(itemGUID_rx, extendRestoreSwitch_rx)

  -- if item is in target lane
  -- and if item has start point before / after target item
  -- and if mediaitem
  -- then mute

  local itemGUID = itemGUID_rx
  local extendRestoreSwitch = extendRestoreSwitch_rx

  local bool_success = false

  local mediaItem = r.BR_GetMediaItemByGUID(0, itemGUID)
  if not mediaItem then return end

  r.Main_OnCommand(40289, 0) -- Deselect all items
  r.SetMediaItemSelected(mediaItem, 1)
  r.Main_OnCommand(40034, 0) -- Item grouping: Select all items in groups

  local muteState

  if extendRestoreSwitch == 1 then
    muteState = 1
  elseif extendRestoreSwitch == -1 then
    muteState = 0
  end

  for g = 0, r.CountSelectedMediaItems(0) - 1 do
    local currentItem = r.GetSelectedMediaItem(0, g)
    r.SetMediaItemInfo_Value(currentItem, "B_MUTE", muteState)
  end

  bool_success = true

  r.Main_OnCommand(40289, 0) -- Deselect all items

  return bool_success, itemGUID, extendRestoreSwitch

end

-------------------------------------------------------

function so.AuditionFade(preRoll_rx, postRoll_rx, bool_TransportAutoStop_rx)

  local preRoll = preRoll_rx
  local postRoll = postRoll_rx
  local bool_TransportAutoStop = bool_TransportAutoStop_rx

  local startPos, stopPos

  local arngViewStart, arngViewEnd = r.BR_GetArrangeView(0)
  r.Main_OnCommand(40036, 0) -- View: Toggle auto-view-scroll during playback

  local curPos = r.GetCursorPosition()

  startPos = curPos - preRoll
  stopPos = curPos + postRoll
  
  r.DeleteProjectMarker(0, 998, false)

  if bool_TransportAutoStop then
    -- SWS marker actions are executed in ascending order of their marker indices.
    r.AddProjectMarker2(0, false, stopPos, stopPos, "!1016", 998, r.ColorToNative(10, 10, 10) | 0x1000000) -- sws action marker: Transport Stop
  end

  r.SetEditCurPos(startPos, false, false)
  r.OnPlayButton()
  r.SetEditCurPos(curPos, false, false)

  r.BR_SetArrangeView(0, arngViewStart, arngViewEnd)
  r.Main_OnCommand(40036, 1) -- View: Toggle auto-view-scroll during playback

end

-------------------------------------------------------

function so.SaveEditStates()

  local saveXFadeCommand = r.NamedCommandLookup("_SWS_SAVEXFD")
  r.Main_OnCommand(saveXFadeCommand, 1) -- SWS: Save auto crossfade state

  local rippleStateAll = r.GetToggleCommandState(41991) -- Toggle ripple editing all tracks
  local rippleStatePer = r.GetToggleCommandState(41990) -- Toggle ripple editing per-track
  r.Main_OnCommand(40309, 1) -- Set ripple editing off

  return rippleStateAll, rippleStatePer
  
end

-------------------------------------------------------

function so.RestoreEditStates(rippleStateAll, rippleStatePer)

  local restoreXFadeCommand = r.NamedCommandLookup("_SWS_RESTOREXFD")
  r.Main_OnCommand(restoreXFadeCommand, 1) -- SWS: Restore auto crossfade state

  if rippleStateAll == 1 then
    r.Main_OnCommand(41991, 1)
  elseif rippleStatePer == 1 then
    r.Main_OnCommand(41991, 1)
  end

end

--------------------------
-- deprecated functions --
--------------------------

function so.GetNeighbor_old(flaggedGUID_rx, mouseTarget_rx)

  local mouseTarget = mouseTarget_rx
  local flaggedGUID = flaggedGUID_rx
  local mediaItemGUID, neighborGUID

  local workingLane = 0
  
  -- script is not taking into account lane show / hide state!
  -- solution: check neighbor using lane number.
  r.Main_OnCommand(40289, 0) -- Deselect all items
  r.Main_OnCommand(40421, 0) -- Item: Select all items in track
  r.Main_OnCommand(40034, 0) -- Item grouping: Select all items in groups
  
  local numSelectedItems = r.CountSelectedMediaItems(0)
  
  for i = 0, numSelectedItems - 1 do
  
    local mediaItem = r.GetSelectedMediaItem(0, i)
    local itemLane = r.GetMediaItemInfo_Value(mediaItem, "I_FIXEDLANE") -- great starting point, but it happens in the wrong place
    
    if mediaItem then
    
      mediaItemGUID = r.BR_GetMediaItemGUID(mediaItem)
      
      if mediaItemGUID == flaggedGUID and itemLane == workingLane then
      
        if mouseTarget == 1 then

          local nextItem = i+1
        
          mediaItem = r.GetSelectedMediaItem(0, nextItem)
          neighborGUID = r.BR_GetMediaItemGUID(mediaItem)

          r.Main_OnCommand(40289, 0) -- Deselect all items
          
          return neighborGUID
          
        elseif mouseTarget == 2 then

          local prevItem = i-1
        
          mediaItem = r.GetSelectedMediaItem(0, prevItem)
          neighborGUID = r.BR_GetMediaItemGUID(mediaItem)
          
          r.Main_OnCommand(40289, 0) -- Deselect all items

          return neighborGUID
        
        end
      end
    end
  end

  r.Main_OnCommand(40289, 0) -- Deselect all items
  r.UpdateArrange()

end

-------------------------------------------------------

function so.SetEditCurPosCenterFade(mediaItem_rx, mouseTarget_rx, cursorBias_rx)

  -- there are 2 types of fade in/out lengths
  -- the script will only use the larger value of the two

  local mediaItem = mediaItem_rx
  local cursorBias = cursorBias_rx

  local itemStart = r.GetMediaItemInfo_Value(mediaItem, "D_POSITION")
  local itemEnd = itemStart + r.GetMediaItemInfo_Value(mediaItem, "D_LENGTH")

  if mouseTarget_rx == 2 then

    local fadeInLen = r.GetMediaItemInfo_Value(mediaItem, "D_FADEINLEN")
    local fadeInLenAuto = r.GetMediaItemInfo_Value(mediaItem, "D_FADEINLEN_AUTO")

    if fadeInLen <= fadeInLenAuto then
      fadeInLen = fadeInLenAuto
    end

    local newCurPos = itemStart + (fadeInLen * cursorBias)

    r.SetEditCurPos(newCurPos, false, false)

  elseif mouseTarget_rx == 1 then

    local fadeOutLen = r.GetMediaItemInfo_Value(mediaItem, "D_FADEOUTLEN_AUTO")
    local fadeOutLenAuto = r.GetMediaItemInfo_Value(mediaItem, "D_FADEOUTLEN")

    if fadeOutLen <= fadeOutLenAuto then
      fadeOutLen = fadeOutLenAuto
    end

    local newCurPos = itemEnd + (fadeOutLen * cursorBias)

    r.SetEditCurPos(newCurPos, false, false)

  end

end

-------------------------------------------------------

function so.Test()

  r.ShowMessageBox("Functions found!", "Success!", 0)

end


--------------
-- required --
--------------

return so
