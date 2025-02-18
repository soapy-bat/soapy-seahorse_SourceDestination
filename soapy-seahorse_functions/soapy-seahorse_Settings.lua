--[[

source-destination: settings

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

local r = reaper
local st = {}

-----------------------------
-- edit functions settings --
-----------------------------

st.bool_ShowHoverWarnings = true                  -- show error message if mouse is hovering over empty space

-- three and four point edits 

st.xFadeLen = 0.05                                -- default: 50 milliseconds (0.05)
st.bool_AutoCrossfade = true                      -- fade newly edited items
st.bool_MoveDstGateAfterEdit = true               -- move destination gate to end of last pasted item (recommended)
st.bool_RemoveAllSourceGates = true               -- remove all source gates after the edit
st.bool_EditTargetsItemUnderMouse = false         -- select item under mouse (no click to select required). for quick fade:
st.bool_KeepLaneSolo = true                       -- if false, lane solo jumps to comp lane after the edit
                                                  -- if multiple lanes were soloed, only last soloed lane will be selected

-- item extender and quick fade 
 
st.bool_PreserveEditCursorPosition = true         -- if false, cursor will jump to the center between items
st.bool_SelectRightItemAtCleanup = true           -- keeps right item selected after script finished manipulating the items
st.bool_AvoidCollision = true                     -- experimental: avoids overlap of more than 2 items by adjusting the amout of extension automatically (if the items to be extended are very short)
st.bool_PreserveExistingCrossfade = true          -- experimental, sets a fade of the same length if there already is a crossfade
st.bool_EditTargetsMouseInsteadOfCursor = true    -- true: sets fade at mouse cursor. false: sets fade at edit cursor

st.extensionAmount = 0.5                          -- time that the items get extended by, in seconds
st.collisionPadding = 0.001                       -- leaves a tiny gap if collision detection is on
st.cursorBias_Extender = 0.5                      -- 0, ..., 1 /// 0.5: center of fade
st.cursorBias_QuickFade = 1                       -- 0, ..., 1 /// 0.5: center of fade

st.xFadeShape = 1                                 -- default: equal power

------------------------------
-- fades functions settings --
------------------------------

st.bool_TransportAutoStop = true                  -- stop transport automatically after auditioning
st.bool_KeepCursorPosition = true                 -- false: script will leave edit cursor at the center of the fade
st.bool_RemoveFade = false                        -- audition without fade

-------------------------------
-- marker functions settings --
-------------------------------

st.bool_GatesTargetItemUnderMouse = false         -- select *item* under mouse (no click to select required)
st.bool_GatesTargetMouseInsteadOfCursor = false   -- place src gate at mouse position instead of edit cursor position

---------------
-- constants --
---------------

st.markerLabel_SrcIn = "SRC_IN"
st.markerLabel_SrcOut = "SRC_OUT"
st.markerLabel_DstIn = "DST_IN"
st.markerLabel_DstOut = "DST_OUT"
st.markerIndex_DstIn = 996
st.markerIndex_DstOut = 997
st.markerColor_Src = r.ColorToNative(255,0,0)        -- red
st.markerColor_Dst = r.ColorToNative(22, 141, 195)   -- kind of blue

--------------
-- required --
--------------

return st