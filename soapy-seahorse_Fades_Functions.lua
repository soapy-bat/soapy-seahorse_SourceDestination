-- thanks chmaha, fricia, X-Raym, GPT3.5

-- variables
local r = reaper
local so = {}

-------------------------------------------------------

function so.GetItemsNearMouse(fadeLenMultiplier_rx)

  local fadeLenMultiplier = fadeLenMultiplier_rx
  local fadeLenMultStart = fadeLenMultiplier
  local fadeLenMultEnd = fadeLenMultiplier - 1

  local mediaItem, itemStart, itemEnd
  local distanceToStart, distanceToEnd
  local firstOrSecond
  local itemGUID = {}
  for i = 1, 2 do
    itemGUID[i] = "empty"
  end

  local bool_success = false

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

      -- there are 2 types of fade in/out lengths
      -- the script will only use the larger value of the two
      local fadeInLen = r.GetMediaItemInfo_Value(mediaItem, "D_FADEINLEN")
      local fadeInLenAuto = r.GetMediaItemInfo_Value(mediaItem, "D_FADEINLEN_AUTO")

      if fadeInLen <= fadeInLenAuto then
        fadeInLen = fadeInLenAuto
      end

      local newCurPos = itemStart + (fadeInLen * fadeLenMultStart)

      r.SetEditCurPos(newCurPos, false, false)
      itemGUID[2] = r.BR_GetMediaItemGUID(mediaItem)
      firstOrSecond = 2
      itemGUID[1] = so.GetNeighbor(itemGUID[2], firstOrSecond)

      bool_success = true

      return bool_success, itemGUID[1], itemGUID[2], firstOrSecond

    else
      -- mouse over 1st item

      -- there are 2 types of fade in/out lengths
      -- the script will only use the larger value of the two
      local fadeOutLen = r.GetMediaItemInfo_Value(mediaItem, "D_FADEOUTLEN_AUTO")
      local fadeOutLenAuto = r.GetMediaItemInfo_Value(mediaItem, "D_FADEOUTLEN")

      if fadeOutLen <= fadeOutLenAuto then
        fadeOutLen = fadeOutLenAuto
      end

      local newCurPos = itemEnd + (fadeOutLen * fadeLenMultEnd)

      r.SetEditCurPos(newCurPos, false, false)
      itemGUID[1] = r.BR_GetMediaItemGUID(mediaItem)
      firstOrSecond = 1
      itemGUID[2] = so.GetNeighbor(itemGUID[1], firstOrSecond)

      bool_success = true

      return bool_success, itemGUID[1], itemGUID[2], firstOrSecond

    end

  else
    bool_success = false
    return bool_success
  end
end

-------------------------------------------------------

function so.GetNeighbor(mediaItemGUID_rx, firstOrSecond_rx)

  local mediaItemGUID = mediaItemGUID_rx
  local firstOrSecond = firstOrSecond_rx
  local flaggedGUID = mediaItemGUID
  local neighborGUID

  local workingLane = 0
  
  -- script is not taking into account lane show / hide state!
  -- solution: check neighbor using lane number.
  r.Main_OnCommand(40289, 0) -- Deselect all items
  r.Main_OnCommand(40421, 0) -- Item: Select all items in track
  r.Main_OnCommand(40034, 0) -- Item grouping: Select all items in groups
  
  local numSelectedItems = r.CountSelectedMediaItems(0)
  
  for i = 0, numSelectedItems - 1 do
  
    local mediaItem = r.GetSelectedMediaItem(0, i)

    local itemLane = r.GetMediaItemInfo_Value(mediaItem, "I_FIXEDLANE")
    
    if mediaItem then
    
      mediaItemGUID = r.BR_GetMediaItemGUID(mediaItem)
      
      if mediaItemGUID == flaggedGUID and itemLane == workingLane then
      
        if firstOrSecond == 1 then

          local nextItem = i+1
        
          mediaItem = r.GetSelectedMediaItem(0, nextItem)
          neighborGUID = r.BR_GetMediaItemGUID(mediaItem)

          r.Main_OnCommand(40289, 0) -- Deselect all items
          
          return neighborGUID
          
        elseif firstOrSecond == 2 then

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

function so.SetTrimXFadeState(autoXFadeState, trimBehindState)

  if autoXFadeState then
    r.Main_OnCommand(40041, 0) -- Options: Auto-crossfade media items when editing
  end
  if trimBehindState then
    r.Main_OnCommand(41117, 0) -- Options: Trim content behind media items when editing
  end

end

-------------------------------------------------------

function so.ResetTrimXFadeState(autoXFadeState, trimBehindState)

  if r.GetToggleCommandState(40041) ~= autoXFadeState then
    r.Main_OnCommand(40041, 0) -- Options: Auto-crossfade media items when editing
  end
  if r.GetToggleCommandState(41117) ~= trimBehindState then
    r.Main_OnCommand(41117, 0) -- Options: Trim content behind media items when editing
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

-------------------------------------------------------

function so.Test()

  r.ShowMessageBox("Functions found!", "Success!", 0)

end

-------------------------------------------------------

return so