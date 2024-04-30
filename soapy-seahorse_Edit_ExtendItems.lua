--[[

source-destination edit: extend items at crossfade

This script is part of the soapy-seahorse package.
It requires the file "soapy-seahorse_Fades_Functions.lua"

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

local bool_KeepCursorPosition = true
local bool_SelectRightItemAtCleanup = true

local extensionAmount = 1      -- time that the items get extended by, in seconds
local cursorBias = 0.5         -- 0, ..., 1 /// 0.5: center of fade

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

function main()

  r.Undo_BeginBlock()
  r.PreventUIRefresh(1)

  local curPos = r.GetCursorPosition()

  local saveXFadeState = r.NamedCommandLookup("_SWS_SAVEXFD")
  r.Main_OnCommand(saveXFadeState, 1) -- SWS: Save auto crossfade state
  r.Main_OnCommand(41119, 1) -- Options: Disable Auto Crossfades

  local item1GUID, item2GUID = ExtendRestoreItems(_, 1)

  if bool_SelectRightItemAtCleanup then

    local mediaItem1 = r.BR_GetMediaItemByGUID(0, item1GUID)
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

function ExtendRestoreItems(scriptCommand_rx, newToggleState_rx)

  local scriptCommand = scriptCommand_rx
  local newToggleState = newToggleState_rx

  local itemGUID = {}
  local bool_success = false

  bool_success, itemGUID[1], itemGUID[2] = so.GetItemsNearMouse(cursorBias)

  if bool_success then

    local mediaItem = {}

    for i = 1, 2 do
      mediaItem[i] = r.BR_GetMediaItemByGUID(0, itemGUID[i])
      if mediaItem[i] then
        if newToggleState == 0 then
          newToggleState = -1
        end
        bool_success = so.LenghtenItem(mediaItem[i], i, newToggleState, extensionAmount)
      end
    end

    if bool_success then
      return itemGUID[1], itemGUID[2]
    else
      r.ShowMessageBox("Item Extender unsuccessful.", "sorry!", 0)
      return
    end

  else
    r.ShowMessageBox("Please hover the mouse over an item in order to extend / restore items.", "Item Extender unsuccessful", 0)
  end

end

------------------------------------------------

function RescueExtender()

  local scriptCommand = r.NamedCommandLookup("_RS43a608374ea4fced06f7c4cf94c26724437b9a80")
  r.SetToggleCommandState(1, scriptCommand, -1)

end

--------------------------
-- deprecated functions --
--------------------------


function ToggleExtender_old()

  r.Undo_BeginBlock()
  r.PreventUIRefresh(1)

  -- get the scripts' toggle state
  local scriptCommand = r.NamedCommandLookup("_RS43a608374ea4fced06f7c4cf94c26724437b9a80")
  local toggleState = r.GetToggleCommandState(scriptCommand)
  local newToggleState

  -- #### --

  if toggleState == -1 or toggleState == 0 then
    newToggleState = 1
  else
    newToggleState = 0
  end

  if newToggleState == 0 then
    r.Main_OnCommand(41118, 1) -- Options: Enable auto-crossfades
  else
    r.Main_OnCommand(41119, 1) -- Options: Disable Auto Crossfades
  end

  ExtendRestoreItems(scriptCommand, newToggleState)

  -- #### --

  r.PreventUIRefresh(-1)
  r.UpdateArrange()

  if newToggleState == 1 then
    r.Undo_EndBlock("Extend items", 0)
  else
    r.Undo_EndBlock("Restore items", 0)
  end

end

--------------------------------
-- main execution starts here --
--------------------------------

if bool_rescueMe then
  RescueExtender()
  bool_rescueMe = false
else
  main()
end