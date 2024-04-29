--[[

source-destination edit: quick crossfade

This script is part of the soapy-seahorse package.

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

local bool_TargetMouseInsteadOfCursor = true

local xfadeLen = 0.05                            -- default: 50 milliseconds (0.05)
local cursorBias = 1                             -- 0, ..., 1 /// 0.5: center of fade

---------------
-- variables --
---------------

local r = reaper

local modulePath = ({r.get_action_context()})[2]:match("^.+[\\/]")
package.path = modulePath .. "?.lua"
local sf = require("soapy-seahorse_Fades_Functions")

local modulePath = ({r.get_action_context()})[2]:match("^.+[\\/]")
package.path = modulePath .. "?.lua"
local se = require("soapy-seahorse_Edit_Functions")

----------
-- main --
----------

function main()

    r.Undo_BeginBlock()
    r.PreventUIRefresh(1)

    -- ## get & select items, get cursor position ## --

    if bool_TargetMouseInsteadOfCursor then
        r.Main_OnCommand(40514, 0) -- View: Move edit cursor to mouse cursor (no snapping)
    end

    local curPos = r.GetCursorPosition()

    local _, item1GUID, item2GUID, _ = sf.GetItemsNearMouse(cursorBias)
    if not item1GUID then return end
    if not item2GUID then return end

    local mediaItem1 = r.BR_GetMediaItemByGUID(0, item1GUID)
    local mediaItem2 = r.BR_GetMediaItemByGUID(0, item2GUID)
    if not mediaItem1 then return end
    if not mediaItem2 then return end

    r.Main_OnCommand(40289, 0) -- Deselect all items

    r.SetMediaItemSelected(mediaItem1, true)
    r.SetMediaItemSelected(mediaItem2, true)

    -- ## set time selection ## --

    r.Main_OnCommand(40020, 0)        -- Time Selection: Remove

    r.SetEditCurPos(curPos - xfadeLen/2, false, false)
    r.Main_OnCommand(40625, 0)        -- Time selection: Set start point

    r.SetEditCurPos(curPos + xfadeLen/2, false, false)
    r.Main_OnCommand(40626, 0)        -- Time selection: Set end point

    -- ## manipulate items in order to be able to fade ## --
    local item1Start = r.GetMediaItemInfo_Value(mediaItem1, "D_POSITION")
    local item1Len = r.GetMediaItemInfo_Value(mediaItem1, "D_LENGTH")
    local item1End = item1Start + item1Len

    if item1End < (curPos - xfadeLen/2) then
        r.BR_SetItemEdges(mediaItem1, item1Start, curPos)
    end

    local item2Start = r.GetMediaItemInfo_Value(mediaItem2, "D_POSITION")
    local item2Len = r.GetMediaItemInfo_Value(mediaItem2, "D_LENGTH")
    local item2End = item2Start + item2Len

    if item2Start > (curPos + xfadeLen/2) then
        r.BR_SetItemEdges(mediaItem2, curPos, item2End)
    end

    -- ## perform fade (amagalma: smart crossfade) ## --
    r.Main_OnCommand(r.NamedCommandLookup("_RSabf54948a2041f5c9ae0f28267706b226a23b598"), 0)

    -- ## clean up ## --

    r.Main_OnCommand(40020, 0)        -- Time Selection: Remove

    r.PreventUIRefresh(-1)
    r.UpdateArrange()
    r.Undo_EndBlock("ReaPyr Quick Fade", 0)

end

--------------------------------
-- main execution starts here --
--------------------------------

main()