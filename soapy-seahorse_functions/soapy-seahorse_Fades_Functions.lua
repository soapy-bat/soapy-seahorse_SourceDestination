--[[

source-destination fades: functions

This file is part of the soapy-seahorse package.
It is required by the various audition scripts.

(C) 2025 the soapy zoo
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
local sf = {}

local modulePath = ({r.get_action_context()})[2]:match("^.+[\\/]")
package.path = modulePath .. "soapy-seahorse_functions/?.lua"
local st = require("soapy-seahorse_Settings")

local bool_ShowHoverWarnings = st.bool_ShowHoverWarnings
local bool_TransportAutoStop = st.bool_TransportAutoStop
local bool_KeepCursorPosition = st.bool_KeepCursorPosition
local bool_RemoveFade = st.bool_RemoveFade

------------------------------------------
-- functions:: major audition functions --
--          audition crossfade          --
------------------------------------------

function sf.AuditionCrossfade()

  local preRoll, postRoll, cursorBias = 2, 2, 1

  local auditioningItems1, auditioningItems2 = {}, {}
  local fadeLen1, fadeLenAuto1, fadeDir1, fadeShape1
  local fadeLen2, fadeLenAuto2, fadeDir2, fadeShape2

  function AuditionCrossfade_Main()

    r.Undo_BeginBlock()
    r.PreventUIRefresh(1)

    local curPos = r.GetCursorPosition()

    r.Main_OnCommand(42478, 0) -- play only lane under mouse

    local bool_success, item1GUID, item2GUID = sf.GetItemsNearMouse(cursorBias)

    if bool_success then

      if bool_RemoveFade then

        auditioningItems1 = sf.GetGroupedItems(item1GUID)
        auditioningItems2 = sf.GetGroupedItems(item2GUID)
        fadeLen1, fadeLenAuto1, fadeDir1, fadeShape1, _ = sf.GetFade(item1GUID, 1)
        fadeLen2, fadeLenAuto2, fadeDir2, fadeShape2, _ = sf.GetFade(item2GUID, 2)

        for i = 1, #auditioningItems1 do
          sf.SetFade(auditioningItems1[i], 1, 0, 0, 0, 0)
          sf.SetFade(auditioningItems2[i], 2, 0, 0, 0, 0)
        end

      end

      -- in case a new instance of an audition script has started before other scripts were able to complete
      local tbl_safeItems1 = sf.GetGroupedItems(item1GUID)
      local tbl_safeItems2 = sf.GetGroupedItems(item2GUID)
      sf.ToggleItemMute(tbl_safeItems1, {}, 0)
      sf.ToggleItemMute(tbl_safeItems2, {}, 0)

      sf.AuditionFade(preRoll, postRoll, bool_TransportAutoStop)
      AuditionCrossfade_CheckPlayState()
    else
      if bool_ShowHoverWarnings then sf.ErrMsgHover() end
    end

    if bool_KeepCursorPosition then
      r.SetEditCurPos(curPos, false, false)
    end

    r.PreventUIRefresh(-1)
    r.UpdateArrange()
    r.Undo_EndBlock("Audition Crossfade", 0)

  end

  function AuditionCrossfade_CheckPlayState()

    local playState = r.GetPlayState()

    local bool_success = false
    local bool_exit = false

    if playState == 0 then -- Transport is stopped

      r.DeleteProjectMarker(0, 998, false)

      if bool_RemoveFade then
        for i = 1, #auditioningItems1 do
          sf.SetFade(auditioningItems1[i], 1, fadeLen1, fadeLenAuto1, fadeDir1, fadeShape1)
          sf.SetFade(auditioningItems2[i], 2, fadeLen2, fadeLenAuto2, fadeDir2, fadeShape2)
        end
      end

      bool_exit = true
    end

    if bool_exit then return end

    -- Schedule the function to run continuously
    r.defer(AuditionCrossfade_CheckPlayState)

  end

  AuditionCrossfade_Main()

end

------------------------------------------
-- functions:: major audition functions --
-- audition to fade in or from fade out --
------------------------------------------

function sf.AuditionFade_Crossfade(targetItem)

  local preRoll, postRoll, cursorBias = 2, 2, 1

  local tbl_mutedItems = {}
  local auditioningItems = {}
  local fadeLen, fadeLenAuto, fadeDir, fadeShape

  local myItemGUID, bool_success

  function AuditionFade_Main()

    r.Undo_BeginBlock()
    r.PreventUIRefresh(1)

    local curPos = r.GetCursorPosition()

    r.Main_OnCommand(42478, 0) -- play only lane under mouse

    -- this will be taken care of later (TM)
    if targetItem == 1 then
      preRoll = 2
      postRoll = 0
      cursorBias = 2
    elseif targetItem == 2 then
      preRoll = 0
      postRoll = 2
      cursorBias = 0
    end

    if targetItem == 1 then
      bool_success, myItemGUID, _ = sf.GetItemsNearMouse(cursorBias)
    elseif targetItem == 2 then
      bool_success, _, myItemGUID = sf.GetItemsNearMouse(cursorBias)
    end

    if bool_success then

      if bool_RemoveFade then

        auditioningItems = sf.GetGroupedItems(myItemGUID)
        fadeLen, fadeLenAuto, fadeDir, fadeShape, _ = sf.GetFade(myItemGUID, targetItem)

        for i = 1, #auditioningItems do
          sf.SetFade(auditioningItems[i], targetItem, 0, 0, 0, 0)
        end

      end

      local _, tbl_itemsToMute = sf.GetItemNeighbors(myItemGUID, targetItem, 1)

      -- in case a new instance of an audition script has started before other scripts were able to complete
      -- sf.ToggleItemMute() will get the grouped items anyway, so we only pass along one item:
      sf.ToggleItemMute({myItemGUID}, {}, 0)

      -- no need to pass along safe items:
      tbl_mutedItems = sf.ToggleItemMute(tbl_itemsToMute, {}, 1)

      sf.AuditionFade(preRoll, postRoll, bool_TransportAutoStop)

      AuditionFade_CheckPlayState()

    else
      if bool_ShowHoverWarnings then sf.ErrMsgHover() end
    end

    if bool_KeepCursorPosition then
      r.SetEditCurPos(curPos, false, false)
    end

    r.Undo_EndBlock("Audition X In", 0)

  end

  function AuditionFade_CheckPlayState()

    r.PreventUIRefresh(1)

    local playState = r.GetPlayState()

    local bool_exit = false

    if playState == 0 then -- Transport is stopped

      sf.ToggleItemMute(tbl_mutedItems, {}, 0)
      r.DeleteProjectMarker(0, 998, false)

      if bool_RemoveFade then
        for i = 1, #auditioningItems do
          sf.SetFade(auditioningItems[i], targetItem, fadeLen, fadeLenAuto, fadeDir, fadeShape)
        end
      end

      r.PreventUIRefresh(-1)
      r.UpdateArrange()

      bool_exit = true
    end

    if bool_exit then return end

    -- Schedule the function to run continuously
    r.defer(AuditionFade_CheckPlayState)

  end

  AuditionFade_Main()

end

------------------------------------------
-- functions:: major audition functions --
--    audition orig. src. in or out     --
------------------------------------------

function sf.AuditionFade_Original(targetItem)

  local preRoll, postRoll, cursorBias, extensionAmountSeconds = 2, 2, 1, 2

  local item1GUID_temp, item2GUID_temp, extensionAmountSeconds_temp, targetItem_temp
  local tbl_mutedItems = {}
  local rippleStateAll, rippleStatePer

  function AuditionOriginal_Main()

    r.Undo_BeginBlock()
    r.PreventUIRefresh(1)

    if targetItem == 1 then
      cursorBias = 0.5
    elseif targetItem == 2 then
      cursorBias = 1.5
    end

    if preRoll > postRoll then
      extensionAmountSeconds = preRoll
    else
      extensionAmountSeconds = postRoll
    end

    local curPos = r.GetCursorPosition()

    r.Main_OnCommand(42478, 0) -- play only lane under mouse

    local bool_success, item1GUID, item2GUID = sf.GetItemsNearMouse(cursorBias)

    if bool_success then

      rippleStateAll, rippleStatePer = sf.SaveEditStates() -- save autocrossfade state

      -- in case a new instance of an audition script has started before other scripts were able to complete
      -- sf.ToggleItemMute() will get the grouped items anyway, so we only pass along one item:
      if targetItem == 1 then
        sf.ToggleItemMute({item1GUID}, {}, 0)
      elseif targetItem == 2 then
        sf.ToggleItemMute({item2GUID}, {}, 0)
      end

      item1GUID_temp, item2GUID_temp, extensionAmountSeconds_temp, targetItem_temp, tbl_mutedItems = sf.ItemExtender(item1GUID, item2GUID, extensionAmountSeconds, targetItem, 1)

      sf.AuditionFade(preRoll, postRoll, bool_TransportAutoStop)

      AuditionOriginal_CheckPlayState()

    else
      if bool_ShowHoverWarnings then sf.ErrMsgHover() end
    end

    if bool_KeepCursorPosition then
      r.SetEditCurPos(curPos, false, false)
    end

    r.Undo_EndBlock("Audition Original In", 0)

  end

  function AuditionOriginal_CheckPlayState()

    r.PreventUIRefresh(1)

    local playState = r.GetPlayState()

    local bool_exit = false

    if playState == 0 then -- Transport is stopped

      sf.ItemExtender(item1GUID_temp, item2GUID_temp, extensionAmountSeconds_temp, targetItem_temp, -1, tbl_mutedItems)

      r.DeleteProjectMarker(0, 998, false)

      sf.RestoreEditStates(rippleStateAll, rippleStatePer)

      r.PreventUIRefresh(-1)
      r.UpdateArrange()

      bool_exit = true

    end

    if bool_exit then return end

    -- Schedule the function to run continuously
    r.defer(AuditionOriginal_CheckPlayState)

  end

  AuditionOriginal_Main()

end

--------------------------------------------
-- functions: information retrieval (get) --
--------------------------------------------

function sf.GetItemsNearMouse(cursorBias_rx, range_rx)

  local cursorBias = cursorBias_rx
  local range = range_rx
  if not range then
    range = 1
  end

  local bool_success = false
  local tbl_itemGUID = {}

  -- mouseX and transport location are compatible

  -- Berücksichtigung der Position nur, wenn Maus auf Item ist
  local mediaItem, mouseX = r.BR_ItemAtMouseCursor()
  if not mediaItem then return false end

  local itemStart = r.GetMediaItemInfo_Value(mediaItem, "D_POSITION")
  local itemEnd = itemStart + r.GetMediaItemInfo_Value(mediaItem, "D_LENGTH")

  local distanceToStart = math.abs(mouseX - itemStart)
  local distanceToEnd = math.abs(itemEnd - mouseX)

  local pri, sec -- temporary indices for item GUID table

  if distanceToStart > distanceToEnd then
    -- mouse over 1st item
    pri = 1
    sec = 2
  else
    -- mouse over 2nd item
    pri = 2
    sec = 1
  end

  tbl_itemGUID[pri] = r.BR_GetMediaItemGUID(mediaItem)
  if range == 1 then
    tbl_itemGUID[sec], _ = sf.GetItemNeighbors(tbl_itemGUID[pri], pri, range)
  else
    _, tbl_itemGUID = sf.GetItemNeighbors(tbl_itemGUID[pri], pri, range)
  end

  if not tbl_itemGUID then
    bool_success = false
    return bool_success
  end

  if tbl_itemGUID[1] == tbl_itemGUID[2] then
    r.ShowMessageBox("You probably tried to audition the last fade of the project, which is not (yet) supported.", "No fade to audition", 0)
    return
  end

  bool_success = sf.SetEditCurPosCenterEdges(tbl_itemGUID[1], tbl_itemGUID[2], cursorBias)

  return bool_success, tbl_itemGUID[1], tbl_itemGUID[2], pri, tbl_itemGUID

end

-------------------------------------------------------

function sf.GetItemNeighbors(flaggedGUID_rx, auditionTarget_rx, range_rx)

  -- audition target tells us if the flagged item is the first or the second one (in or out of the targeted fade)
  local flaggedGUID = flaggedGUID_rx
  local auditionTarget = auditionTarget_rx
  local range = range_rx

  local flaggedIndex, neighborGUID
  local tbl_neighborGUID = {}

  -- get array of items on fixed lane

  local tbl_laneItemsGUID = sf.GetItemsOnLane(flaggedGUID)
  if not tbl_laneItemsGUID then return end

  -- get index of flagged item

  for i = 0, #tbl_laneItemsGUID do

    if tbl_laneItemsGUID[i] == flaggedGUID then
      flaggedIndex = i
    end

  end

  if not flaggedIndex then
    r.ShowMessageBox("Something went wrong: Index is nil", "Could not retrieve targeted item", 0)
    return
  end

  -- if item is the last item in the lane, return input
  if flaggedIndex == #tbl_laneItemsGUID and auditionTarget == 1 then
    return flaggedGUID
  end

  -- if item is the second to last item in the lane and looking for neighbors to the right, adapt range
  if flaggedIndex == #tbl_laneItemsGUID - 1 and auditionTarget == 1 then
    range = 1
  end

  -- if item is the second item in the lane and looking for neighbors to the left, adapt range
  if flaggedIndex == 2 and auditionTarget == 2 then
    range = 1
  end

  -- find neighbor:

  -- map value of 1 or 2 to value of 1 or (-1)
  auditionTarget = ((auditionTarget * 2) - 3) * (-1)

  for i = 1, range do

    local mediaItem = r.BR_GetMediaItemByGUID(0, tbl_laneItemsGUID[flaggedIndex + (i * auditionTarget)])
    neighborGUID = r.BR_GetMediaItemGUID(mediaItem)
    table.insert(tbl_neighborGUID, r.BR_GetMediaItemGUID(mediaItem))

  end

  return neighborGUID, tbl_neighborGUID

end

-------------------------------------------------------

function sf.GetItemsOnLane(flaggedGUID_rx)

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

function sf.GetItemsOnTrack(flaggedGUID_rx)

  local flaggedGUID = flaggedGUID_rx

  -- get media track and fixed lane of flagged item
  local flaggedItem = r.BR_GetMediaItemByGUID(0, flaggedGUID)
  if not flaggedItem then return end

  local mediaTrack = r.GetMediaItem_Track(flaggedItem)
  if not mediaTrack then return end

  local itemCount = r.CountTrackMediaItems(mediaTrack)

  local tbl_trackItemsGUID = {}

  for i = 0, itemCount - 1 do

    local mediaItem = r.GetTrackMediaItem(mediaTrack, i)
    if mediaItem then

      local newGUID = r.BR_GetMediaItemGUID(mediaItem)
      table.insert(tbl_trackItemsGUID, newGUID)

    end
  end

  return tbl_trackItemsGUID

end

-------------------------------------------------------

---Get (vertically) grouped items
---@return table tbl_groupedItemsGUID
function sf.GetGroupedItems(itemGUID)
-- working with select states is more efficient in this case but causes the items to flicker

  local tbl_groupedItemsGUID = {}

  local mediaItem = r.BR_GetMediaItemByGUID(0, itemGUID)
  if not mediaItem then return tbl_groupedItemsGUID end

  r.Main_OnCommand(40289, 0) -- Deselect all items

  r.SetMediaItemSelected(mediaItem, true)

  r.Main_OnCommand(40034, 0) -- Item grouping: Select all items in group

  local numSelectedItems = r.CountSelectedMediaItems(0)

  for i = 0, numSelectedItems - 1 do

    local mediaItem = r.GetSelectedMediaItem(0, i)

    if mediaItem then

      -- table.insert indexes from 1, not from 0 (lua convention)
      table.insert(tbl_groupedItemsGUID, r.BR_GetMediaItemGUID(mediaItem))

    end
  end

  r.Main_OnCommand(40289, 0) -- Deselect all items

  return tbl_groupedItemsGUID

end

------------------------------------------------------
-- functions: parameter manipulation (set / toggle) --
------------------------------------------------------

---sets the edit cursor in the center between two item edges
---@param item1GUID_rx any
---@param item2GUID_rx any
---@param cursorBias_rx any
---@return boolean bool_success
function sf.SetEditCurPosCenterEdges(item1GUID_rx, item2GUID_rx, cursorBias_rx)

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

function sf.ItemExtender(item1GUID_rx, item2GUID_rx, extensionAmountSeconds_rx, itemToExtend_rx, extendRestoreSwitch_rx, tbl_mutedItems_rx)

  local tbl_itemGUID = {}
  tbl_itemGUID[1] = item1GUID_rx
  tbl_itemGUID[2] = item2GUID_rx

  local extensionAmountSeconds = extensionAmountSeconds_rx
  local itemToExtend = itemToExtend_rx
  local extendRestoreSwitch = extendRestoreSwitch_rx    -- 1 = extend, -1 = restore // to make it easier when calculating new item edges (see sf.LenghtenItem)
  local tbl_mutedItems = tbl_mutedItems_rx

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

  -- ###### mute secondary item ###### --

  local muteState = extendRestoreSwitch
  local itemsToMute

  if muteState == -1 then
    muteState = 0
    itemsToMute = tbl_mutedItems
  elseif muteState == 1 then
    _, itemsToMute = sf.GetItemNeighbors(tbl_itemGUID[pri], pri, 2)
  end

  tbl_mutedItems = sf.ToggleItemMute(itemsToMute, {}, muteState)

  -- ###### lenghten primary item ###### --

  mediaItem[pri] = r.BR_GetMediaItemByGUID(0, tbl_itemGUID[pri])

  if mediaItem[pri] then
    sf.LenghtenItem(mediaItem[pri], pri, extendRestoreSwitch, extensionAmountSeconds)
  end
  
  return tbl_itemGUID[1], tbl_itemGUID[2], extensionAmountSeconds, itemToExtend, tbl_mutedItems

end

-------------------------------------------------------

function sf.LenghtenItem(mediaItem_rx, pri_rx, extendRestoreSwitch_rx, extensionAmountSeconds_rx)

  -- function assumes all items in group to be at the same length and position

  local mediaItem = mediaItem_rx
  local pri = pri_rx
  local extendRestoreSwitch = extendRestoreSwitch_rx
  local extensionAmountSeconds = extensionAmountSeconds_rx

  local bool_success = false

  r.Main_OnCommand(40289, 0) -- Deselect all items
  r.SetMediaItemSelected(mediaItem, true)
  r.Main_OnCommand(40034, 0) -- Item grouping: Select all items in groups
  
  local itemStart = r.GetMediaItemInfo_Value(mediaItem, "D_POSITION")
  local itemLength = r.GetMediaItemInfo_Value(mediaItem, "D_LENGTH")
  local itemEnd = itemStart + itemLength

  -- the magic happens here
  if pri == 1 then

    local newEnd = itemEnd + (extensionAmountSeconds * extendRestoreSwitch)
  
    for t = 0, r.CountSelectedMediaItems(0) - 1 do
      local currentItem = r.GetSelectedMediaItem(0, t)
      r.BR_SetItemEdges(currentItem, itemStart, newEnd)
    end

    bool_success = true

  -- ...and here
  elseif pri == 2 then

    local newStart = itemStart - (extensionAmountSeconds * extendRestoreSwitch)
  
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

function sf.ToggleItemMute(tbl_mediaItemGUIDs_rx, tbl_safeItemsGUID_rx, muteState_rx)

  local tbl_mediaItemGUIDs = tbl_mediaItemGUIDs_rx
  local tbl_safeItemsGUID = tbl_safeItemsGUID_rx
  local muteState = muteState_rx

  local tbl_mutedItems = {}

  for h = 1, #tbl_mediaItemGUIDs do

    local tbl_groupedItems = sf.GetGroupedItems(tbl_mediaItemGUIDs[h])

    for k = 1, #tbl_groupedItems do

      local bool_foundSafeItem = false

      -- for i = 1, #tbl_safeItemsGUID do
      --   if tbl_groupedItems[k] == tbl_safeItemsGUID[i] then
      --     bool_foundSafeItem = true
      --     break
      --   end
      -- end

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

function sf.AuditionFade(preRoll_rx, postRoll_rx, bool_TransportAutoStop_rx)

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

--------------------------------------------------
-- functions: peanuts (small get / set helpers) --
--------------------------------------------------

function sf.SaveEditStates()

  local saveXFadeCommand = r.NamedCommandLookup("_SWS_SAVEXFD")
  r.Main_OnCommand(saveXFadeCommand, 1) -- SWS: Save auto crossfade state

  local xFadeOffCommand = r.NamedCommandLookup("_SWS_XFDOFF")
  r.Main_OnCommand(xFadeOffCommand, 0) -- SWS: Set auto crossfade off

  local rippleStateAll = r.GetToggleCommandState(41991) -- Toggle ripple editing all tracks
  local rippleStatePer = r.GetToggleCommandState(41990) -- Toggle ripple editing per-track
  r.Main_OnCommand(40309, 1) -- Set ripple editing off

  return rippleStateAll, rippleStatePer
  
end

-------------------------------------------------------

function sf.RestoreEditStates(rippleStateAll, rippleStatePer)

  local restoreXFadeCommand = r.NamedCommandLookup("_SWS_RESTOREXFD")
  r.Main_OnCommand(restoreXFadeCommand, 1) -- SWS: Restore auto crossfade state

  if rippleStateAll == 1 then
    r.Main_OnCommand(41991, 1)
  elseif rippleStatePer == 1 then
    r.Main_OnCommand(41991, 1)
  end

end

-------------------------------------------------------

function sf.GetFade(itemGUID_rx, inOrOut_rx)

  local itemGUID = itemGUID_rx
  local inOrOut = inOrOut_rx

  local fadeLen, fadeLenAuto, fadeDir, fadeShape

  local mediaItem = r.BR_GetMediaItemByGUID(0, itemGUID)
  if not mediaItem then return end

  if inOrOut == 2 then

    -- looking for fade IN
    fadeLen = r.GetMediaItemInfo_Value(mediaItem, "D_FADEINLEN")
    fadeLenAuto = r.GetMediaItemInfo_Value(mediaItem, "D_FADEINLEN_AUTO")
    fadeDir = r.GetMediaItemInfo_Value(mediaItem, "D_FADEINDIR")
    fadeShape = r.GetMediaItemInfo_Value(mediaItem, "C_FADEINSHAPE")

  elseif inOrOut == 1 then

    -- looking for fade OUT
    fadeLen = r.GetMediaItemInfo_Value(mediaItem, "D_FADEOUTLEN")
    fadeLenAuto = r.GetMediaItemInfo_Value(mediaItem, "D_FADEOUTLEN_AUTO")
    fadeDir = r.GetMediaItemInfo_Value(mediaItem, "D_FADEOUTDIR")
    fadeShape = r.GetMediaItemInfo_Value(mediaItem, "C_FADEOUTSHAPE")

  end

  return fadeLen, fadeLenAuto, fadeDir, fadeShape, inOrOut

end

-------------------------------------------------------

function sf.SetFade(itemGUID, inOrOut, fadeLen, fadeLenAuto, fadeDir, fadeShape)

  local mediaItem = r.BR_GetMediaItemByGUID(0, itemGUID)
  if not mediaItem then return end

  if inOrOut == 2 then

    -- set fade IN
    r.SetMediaItemInfo_Value(mediaItem, "D_FADEINLEN", fadeLen)
    r.SetMediaItemInfo_Value(mediaItem, "D_FADEINLEN_AUTO", fadeLenAuto)
    r.SetMediaItemInfo_Value(mediaItem, "D_FADEINDIR", fadeDir)
    r.SetMediaItemInfo_Value(mediaItem, "C_FADEINSHAPE", fadeShape)

  elseif inOrOut == 1 then

    -- set fade OUT
    r.SetMediaItemInfo_Value(mediaItem, "D_FADEOUTLEN", fadeLen)
    r.SetMediaItemInfo_Value(mediaItem, "D_FADEOUTLEN_AUTO", fadeLenAuto)
    r.SetMediaItemInfo_Value(mediaItem, "D_FADEOUTDIR", fadeDir)
    r.SetMediaItemInfo_Value(mediaItem, "C_FADEOUTSHAPE", fadeShape)

  end

end

--------------------------
-- deprecated functions --
--------------------------

function sf.SetEditCurPosCenterFade(mediaItem_rx, mouseTarget_rx, cursorBias_rx)

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

function sf.GetGroupedItems2(itemGUID_rx) -- warning: inefficient!

  local itemGUID = itemGUID_rx
  local mediaItem = r.BR_GetMediaItemByGUID(0, itemGUID)

  local tbl_groupedItemsGUID = {}

  local groupID = r.GetMediaItemInfo_Value(mediaItem, "I_GROUPID")
  if groupID ~= 0 then

    local tbl_allItemsGUID = sf.GetAllItemsGUID()

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

-------------------------------------------------------

function sf.ToggleItemMuteState(itemGUID_rx, extendRestoreSwitch_rx)

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
  r.SetMediaItemSelected(mediaItem, true)
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

function sf.GetNeighbor2(flaggedGUID_rx, mouseTarget_rx)

  -- mouse target tells us if the selected item is the first or the second one (in or out of the targeted fade)
  local flaggedGUID = flaggedGUID_rx
  local mouseTarget = mouseTarget_rx

  local flaggedIndex

  -- get array of items on fixed lane

  local tbl_laneItemsGUID = sf.GetItemsOnLane(flaggedGUID)
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

  -- if item is the last item in the lane, return input
  if flaggedIndex == #tbl_laneItemsGUID and mouseTarget == 1 then
    return flaggedGUID
  end  

  -- find neighbor

  if mouseTarget == 1 then
  
    local mediaItem = r.BR_GetMediaItemByGUID(0, tbl_laneItemsGUID[flaggedIndex + 1])
    local neighborGUID = r.BR_GetMediaItemGUID(mediaItem)
    
    return neighborGUID
    
  elseif mouseTarget == 2 then
  
    local mediaItem = r.BR_GetMediaItemByGUID(0, tbl_laneItemsGUID[flaggedIndex - 1])
    local neighborGUID = r.BR_GetMediaItemGUID(mediaItem)
    
    return neighborGUID
  
  end

end

-------------------------------------------------------

function sf.GetAllItemsGUID()

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

function sf.ErrMsgHover()

  r.ShowMessageBox("Please hover the mouse over an item in order to audition fade.", "Audition unsuccessful", 0)

end
-------------------------------------------------------

function sf.Test()

  r.ShowMessageBox("Functions found!", "Success!", 0)

end


--------------
-- required --
--------------

return sf
