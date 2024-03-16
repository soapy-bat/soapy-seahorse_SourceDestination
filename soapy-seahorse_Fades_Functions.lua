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

---------------
-- functions --
---------------

function so.GetItemsNearMouse(cursorBias_rx)

  local bool_success = false

  local cursorBias = cursorBias_rx

  local mediaItem, itemStart, itemEnd
  local distanceToStart, distanceToEnd
  local mouseTarget
  local itemGUID = {}
  for i = 1, 2 do
    itemGUID[i] = "empty"
  end

  local mouseX

  -- mouseX and transport location are compatible
  
  -- bis jetzt nur Berücksichtigung der Position, wenn Maus auf Item ist
  mediaItem, mouseX = r.BR_ItemAtMouseCursor()
  
  if mediaItem then
  
    itemStart = r.GetMediaItemInfo_Value(mediaItem, "D_POSITION")
    itemEnd = itemStart + r.GetMediaItemInfo_Value(mediaItem, "D_LENGTH")
    
    distanceToStart = math.abs(mouseX - itemStart)
    distanceToEnd = math.abs(itemEnd - mouseX)
    
    if distanceToStart < distanceToEnd then
      
      -- mouse over 2nd item

      itemGUID[2] = r.BR_GetMediaItemGUID(mediaItem)
      mouseTarget = 2
      itemGUID[1] = so.GetNeighbor(itemGUID[2], mouseTarget)

      bool_success = so.SetEditCurPosCenterEdges(itemGUID[1], itemGUID[2], cursorBias)

      return bool_success, itemGUID[1], itemGUID[2], mouseTarget

    else

      -- mouse over 1st item

      itemGUID[1] = r.BR_GetMediaItemGUID(mediaItem)
      mouseTarget = 1
      itemGUID[2] = so.GetNeighbor(itemGUID[1], mouseTarget)

      bool_success = so.SetEditCurPosCenterEdges(itemGUID[1], itemGUID[2], cursorBias)

      return bool_success, itemGUID[1], itemGUID[2], mouseTarget

    end

  else
    bool_success = false
    return bool_success
  end
end

-------------------------------------------------------

function so.SetEditCurPosCenterEdges(item1GUID_rx, item2GUID_rx, cursorBias_rx)

  local bool_success = false

  local itemGUID = {}
  itemGUID[1] = item1GUID_rx
  itemGUID[2] = item2GUID_rx

  local cursorBias = cursorBias_rx

  local mediaItem = {}
  local itemStart = {}
  local itemEnd = {}

  for i = 1, 2 do
    mediaItem[i] = r.BR_GetMediaItemByGUID(0, itemGUID[i])
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

function so.GetNeighbor(flaggedGUID_rx, mouseTarget_rx)

  -- mouse target tells us if the selected item is the first or the second one (in or out of the targeted fade)
  local flaggedGUID = flaggedGUID_rx
  local mouseTarget = mouseTarget_rx

  local compItemsGUID = {}

  -- get media track and fixed lane of flagged item
  local flaggedItem = r.BR_GetMediaItemByGUID(0, flaggedGUID)
  local mediaTrack = r.GetMediaItem_Track(flaggedItem)
  local flaggedLane = r.GetMediaItemInfo_Value(flaggedItem, "I_FIXEDLANE")

  local flaggedIndex

  -- get array of items on fixed lane
  -- what will the order of the items be?
  if mediaTrack then

    local itemCount = r.CountTrackMediaItems(mediaTrack)

    for i = 0, itemCount - 1 do

        local mediaItem = r.GetTrackMediaItem(mediaTrack, i)

        if mediaItem then

            local itemLane = r.GetMediaItemInfo_Value(mediaItem, "I_FIXEDLANE")

            if itemLane == flaggedLane then
                compItemsGUID[i] = r.BR_GetMediaItemGUID(mediaItem)
            end

        end

    end

    -- get index of flagged item

    for i = 0, #compItemsGUID - 1 do

      local GUID = compItemsGUID[i]

      if GUID == flaggedGUID then

        flaggedIndex = i

      end

    end

    -- find neighbor

    if mouseTarget == 1 then
    
      mediaItem = r.BR_GetMediaItemByGUID(0, compItemsGUID[flaggedIndex + 1])
      local neighborGUID = r.BR_GetMediaItemGUID(mediaItem)
      
      return neighborGUID
      
    elseif mouseTarget == 2 then
    
      mediaItem = r.BR_GetMediaItemByGUID(0, compItemsGUID[flaggedIndex - 1])
      local neighborGUID = r.BR_GetMediaItemGUID(mediaItem)
      
      return neighborGUID
    
    end

  end

end

-------------------------------------------------------

function so.ItemExtender(item1GUID_rx, item2GUID_rx, extendedTime_rx, itemToExtend_rx, extendRestoreSwitch_rx)

  local itemGUID = {}
  itemGUID[1] = item1GUID_rx
  itemGUID[2] = item2GUID_rx

  local extendedTime = extendedTime_rx
  local itemToExtend = itemToExtend_rx
  local extendRestoreSwitch = extendRestoreSwitch_rx    -- 1 = extend, -1 = restore // to make it easier when calculating new item edges (see so.LenghtenItem)

  item1GUID_temp = itemGUID[1]
  item2GUID_temp = itemGUID[2]
  extendedTime_temp = extendedTime

  local bool_success = false

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

  mediaItem[pri] = r.BR_GetMediaItemByGUID(0, itemGUID[pri])

  if mediaItem[pri] then
    bool_success = so.LenghtenItem(mediaItem[pri], pri, extendRestoreSwitch, extendedTime)
  end
  
  -- ###### mute secondary item ###### --

  mediaItem[sec] = r.BR_GetMediaItemByGUID(0, itemGUID[sec])
  
  if mediaItem[sec] then
    bool_success = so.ToggleItemMuteState(itemGUID[sec],extendRestoreSwitch)
  end

  r.Main_OnCommand(40289, 0) -- Deselect all items

  return bool_success, itemGUID[1], itemGUID[2], extendedTime, itemToExtend

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

    -- sometimes weird fades occur with SetItemEdges?
    --local newLength = itemLength + (extendedTime * extendRestoreSwitch)
    local newEnd = itemEnd + (extendedTime * extendRestoreSwitch)
  
    for t = 0, r.CountSelectedMediaItems(0) - 1 do
      local currentItem = r.GetSelectedMediaItem(0, t)
      --r.SetMediaItemInfo_Value(currentItem, "D_LENGTH", newLength)
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

function so.ToggleItemMuteState(itemGUID_rx, extendRestoreSwitch_rx)

  -- if first then mute all items to the right
  -- if second then mute all items to the left

  -- if item is in target lane
  -- and if item has start point before / after target item
  -- and if mediaitem
  -- then mute

  local itemGUID = itemGUID_rx
  local extendRestoreSwitch = extendRestoreSwitch_rx

  local bool_success = false

  local mediaItem = r.BR_GetMediaItemByGUID(0, itemGUID)

  if mediaItem then

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

  end

  return bool_success, itemGUID, extendRestoreSwitch

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
  
  r.DeleteProjectMarker(0, 999, false)
  r.DeleteProjectMarker(0, 998, false)

  if bool_TransportAutoStop then
    -- SWS marker actions are executed in ascending order of their marker indices.
    r.AddProjectMarker2(0, false, stopPos, stopPos, "!1016", 998, r.ColorToNative(10, 10, 10) | 0x1000000) -- sws action marker: Transport Stop
    r.AddProjectMarker2(0, false, stopPos, stopPos, "!_SWSMARKERLIST9", 999, r.ColorToNative(10, 10, 10) | 0x1000000) -- sws: Delete All Markers
  end

  r.SetEditCurPos(startPos, false, false)
  r.OnPlayButton()
  r.SetEditCurPos(curPos, false, false)

  r.BR_SetArrangeView(0, arngViewStart, arngViewEnd)
  r.Main_OnCommand(40036, 1) -- View: Toggle auto-view-scroll during playback

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
