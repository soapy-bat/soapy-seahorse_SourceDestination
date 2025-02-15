--[[

source-destination edit: extend items at crossfade

This script is part of the soapy-seahorse package.
It requires the file "soapy-seahorse_Edit_Functions.lua"

(C) 2024 the soapy zoo
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

-------------------
-- user settings --
-------------------

local bool_KeepCursorPosition = true        -- if false, cursor will jump to the center between items
local bool_SelectRightItemAtCleanup = true  -- keeps right item selected after script finished manipulating the items
local bool_AvoidCollision = true            -- experimental: avoids overlap of more than 2 items by adjusting the amout of extension automatically (if the items to be extended are very short)

local extensionAmount = 0.5                 -- time that the items get extended by, in seconds
local collisionPadding = 0.001              -- leaves a tiny gap if collision detection is on
local cursorBias = 0.5                      -- 0, ..., 1 /// 0.5: center of fade

---------------
-- variables --
---------------

local r = reaper

local modulePath = ({r.get_action_context()})[2]:match("^.+[\\/]")
package.path = modulePath .. "?.lua"
local so = require("soapy-seahorse_Fades_Functions")

local bool_rescueMe = false

----------
-- main --
----------

function Main()

  r.Undo_BeginBlock()
  r.PreventUIRefresh(1)

  local curPos = r.GetCursorPosition()

  local saveXFadeState = r.NamedCommandLookup("_SWS_SAVEXFD")
  r.Main_OnCommand(saveXFadeState, 1) -- SWS: Save auto crossfade state
  r.Main_OnCommand(41119, 1) -- Options: Disable Auto Crossfades

  local item1GUID, item2GUID = ExtendItems(_, 1)
  if not item1GUID or not item2GUID then return end

  if bool_SelectRightItemAtCleanup then

    local mediaItem2 = r.BR_GetMediaItemByGUID(0, item2GUID)
    if not mediaItem2 then return end

    r.Main_OnCommand(40289, 0) -- Deselect all items
    r.SetMediaItemSelected(mediaItem2, true)

  end

  local restoreXFadeState = r.NamedCommandLookup("_SWS_RESTOREXFD")
  r.Main_OnCommand(restoreXFadeState, 0) -- SWS: Restore auto crossfade state

  if bool_KeepCursorPosition then
    r.SetEditCurPos(curPos, false, false)
  end

  r.PreventUIRefresh(-1)
  r.UpdateArrange()
  r.Undo_EndBlock("Extend items", 0)

end

-----------
-- utils --
-----------

function ExtendItems(scriptCommand_rx, newToggleState_rx)

  -- ## get items ## --
  local _, _, _, _, itemGUID = so.GetItemsNearMouse(cursorBias)

  if not itemGUID then ErrMsgHover() return end

  -- ## extend items ## --
  local mediaItem = {}
  for i = 1, #itemGUID do
    mediaItem[i] = r.BR_GetMediaItemByGUID(0, itemGUID[i])
  end
  for i = 1, #mediaItem do
    if not mediaItem[i] then ErrMsgHover() return end
  end

  if bool_AvoidCollision then

    -- ## avoid collision: get item edges ## --
    local itemStart, itemEnd, itemFade = {}, {}, {}

    itemStart[1], _, itemEnd[1] = GetItemStartLengthEnd(mediaItem[1])
    itemStart[2], _, itemEnd[2] = GetItemStartLengthEnd(mediaItem[2])

    itemFade[1], _ = GetItemLargestFade(mediaItem[1])
    _, itemFade[2] = GetItemLargestFade(mediaItem[2])

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

  local bool_success = so.LenghtenItem(mediaItem[1], 1, 1, extensionAmount)
  bool_success = so.LenghtenItem(mediaItem[2], 2, 1, extensionAmount)

  if bool_success then
    return itemGUID[1], itemGUID[2]
  else
    r.ShowMessageBox("Item Extender unsuccessful.", "sorry!", 0)
    return
  end

end

------------------------------------------------

function GetItemStartLengthEnd(mediaItem)

  local itemStart = r.GetMediaItemInfo_Value(mediaItem, "D_POSITION")
  local itemLength = r.GetMediaItemInfo_Value(mediaItem, "D_LENGTH")
  local itemEnd = itemStart + itemLength

  return itemStart, itemLength, itemEnd

end

------------------------------------------------

function GetItemLargestFade(mediaItem)

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

------------------------------------------------

function ErrMsgHover()

  r.ShowMessageBox("Please hover the mouse over an item in order to extend items.", "Item Extender unsuccessful", 0)

end

------------------------------------------------

function RescueExtender()

  local scriptCommand = r.NamedCommandLookup("_RS43a608374ea4fced06f7c4cf94c26724437b9a80")
  r.SetToggleCommandState(1, scriptCommand, -1)

end

--------------------------------
-- main execution starts here --
--------------------------------

if bool_rescueMe then
  RescueExtender()
  bool_rescueMe = false
else
  Main()
end