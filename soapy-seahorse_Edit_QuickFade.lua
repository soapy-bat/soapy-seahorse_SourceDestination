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

local bool_TargetMouseInsteadOfCursor = true    -- true: sets fade at mouse cursor. false: sets fade at edit cursor
local bool_SelectRightItemAtCleanup = true      -- keeps right item selected after execution of the script
local bool_PreserveFadeLength = true            -- experimental, sets a fade of the same length if there already is a crossfade

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

    local saveXFadeState = r.NamedCommandLookup("_SWS_SAVEXFD")
    r.Main_OnCommand(saveXFadeState, 1) -- SWS: Save auto crossfade state
    r.Main_OnCommand(41119, 1) -- Options: Disable Auto Crossfades

    -- ## get / set cursor position ## --

    if bool_TargetMouseInsteadOfCursor then
        r.Main_OnCommand(40514, 0) -- View: Move edit cursor to mouse cursor (no snapping)
    end

    local curPos = r.GetCursorPosition()

    -- ## get items ## --

    local _, item1GUID, item2GUID, _ = sf.GetItemsNearMouse(cursorBias)
    if not item1GUID then Cleanup(curPos) return end
    if not item2GUID then Cleanup(curPos) return end

    local mediaItem1 = r.BR_GetMediaItemByGUID(0, item1GUID)
    local mediaItem2 = r.BR_GetMediaItemByGUID(0, item2GUID)
    if not mediaItem1 then Cleanup(curPos) return end
    if not mediaItem2 then Cleanup(curPos) return end

    -- ## get fade length ## --
    if bool_PreserveFadeLength then
        local item1FadeLen = r.GetMediaItemInfo_Value(mediaItem1, "D_FADEOUTLEN")
        local item1FadeLenAuto = r.GetMediaItemInfo_Value(mediaItem1, "D_FADEOUTLEN_AUTO")

        local item2FadeLen = r.GetMediaItemInfo_Value(mediaItem2, "D_FADEINLEN")
        local item2FadeLenAuto = r.GetMediaItemInfo_Value(mediaItem2, "D_FADEINLEN_AUTO")

        if item1FadeLen < item1FadeLenAuto then
            item1FadeLen = item1FadeLenAuto
        end

        if item2FadeLen < item2FadeLenAuto then
            item2FadeLen = item2FadeLenAuto
        end

        if item1FadeLen == item2FadeLen then
            xfadeLen = item1FadeLen
        end
    end

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

    if item1End < curPos then

        r.Main_OnCommand(40289, 0) -- Deselect all items
        r.SetMediaItemSelected(mediaItem1, true)
        r.Main_OnCommand(40034, 0) -- Item grouping: Select all items in groups

        for i = 0, r.CountSelectedMediaItems(0) - 1 do

            local selItem = r.GetSelectedMediaItem(0, i)

            if selItem then
                r.BR_SetItemEdges(selItem, item1Start, curPos)
            end
        end
    end

    local item2Start = r.GetMediaItemInfo_Value(mediaItem2, "D_POSITION")
    local item2Len = r.GetMediaItemInfo_Value(mediaItem2, "D_LENGTH")
    local item2End = item2Start + item2Len

    if item2Start > curPos then

        r.Main_OnCommand(40289, 0) -- Deselect all items
        r.SetMediaItemSelected(mediaItem2, true)
        r.Main_OnCommand(40034, 0) -- Item grouping: Select all items in groups

        for i = 0, r.CountSelectedMediaItems(0) - 1 do

            local selItem = r.GetSelectedMediaItem(0, i)

            if selItem then
                r.BR_SetItemEdges(selItem, curPos, item2End)
            end
        end

    end

    -- ## select items ## --

    r.Main_OnCommand(40289, 0) -- Deselect all items

    r.SetMediaItemSelected(mediaItem1, true)
    r.SetMediaItemSelected(mediaItem2, true)
    r.Main_OnCommand(40034, 0) -- Item grouping: Select all items in groups

    -- ## perform fade (amagalma: smart crossfade) ## --

    --r.Main_OnCommand(r.NamedCommandLookup("_RSabf54948a2041f5c9ae0f28267706b226a23b598"), 0)
    r.Main_OnCommand(40916, 0) -- Item: Crossfade items within time selection

    -- ## clean up ## --

    Cleanup(curPos, mediaItem1, mediaItem2)

    r.PreventUIRefresh(-1)
    r.UpdateArrange()
    r.Undo_EndBlock("ReaPyr Quick Fade", 0)

end

function Cleanup(curPos, mediaItem1, mediaItem2)

    local restoreXFadeState = r.NamedCommandLookup("_SWS_RESTOREXFD")
    r.Main_OnCommand(restoreXFadeState, 0) -- SWS: Restore auto crossfade state

    r.Main_OnCommand(40020, 0) -- Time Selection: Remove

    r.Main_OnCommand(40289, 0) -- Deselect all items
    if bool_SelectRightItemAtCleanup then
        r.SetMediaItemSelected(mediaItem2, true)
    end

    r.SetEditCurPos(curPos, false, false)

end

--------------------------------
-- main execution starts here --
--------------------------------

main()