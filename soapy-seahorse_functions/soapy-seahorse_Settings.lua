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

    -- using booleans in Lua, anything but nil and false evaluate to true (also 0)

local sectionName = "soapy-seahorse"
local tbl_defaultSettings = {

    bool_ShowHoverWarnings = 1,                  -- show error message if mouse is hovering over empty space

    -- three and four point edits 

    xFadeLen = 0.05,                                -- default: 50 milliseconds (0.05)
    bool_AutoCrossfade = 1,                      -- fade newly edited items
    bool_MoveDstGateAfterEdit = 1,               -- move destination gate to end of last pasted item (recommended)
    bool_RemoveAllSourceGates = 1,               -- remove all source gates after the edit
    bool_EditTargetsItemUnderMouse = false,         -- select item under mouse (no click to select required). for quick fade:
    bool_KeepLaneSolo = 1,                       -- if false, lane solo jumps to comp lane after the edit
                                                    -- if multiple lanes were soloed, only last soloed lane will be selected

    -- item extender and quick fade 

    bool_PreserveEditCursorPosition = 1,         -- if false, cursor will jump to the center between items
    bool_SelectRightItemAtCleanup = 1,           -- keeps right item selected after script finished manipulating the items
    bool_AvoidCollision = 1,                     -- experimental: avoids overlap of more than 2 items by adjusting the amout of extension automatically (if the items to be extended are very short)
    bool_PreserveExistingCrossfade = 1,          -- experimental, sets a fade of the same length if there already is a crossfade
    bool_EditTargetsMouseInsteadOfCursor = 1,    -- true: sets fade at mouse cursor. false: sets fade at edit cursor

    extensionAmount = 0.5,                          -- time that the items get extended by, in seconds
    collisionPadding = 0.001,                       -- leaves a tiny gap if collision detection is on
    cursorBias_Extender = 0.5,                      -- 0, ..., 1 /// 0.5: center of fade
    cursorBias_QuickFade = 1,                       -- 0, ..., 1 /// 0.5: center of fade

    xFadeShape = 1,                                 -- default: equal power

    ------------------------------
    -- fades functions settings --
    ------------------------------

    bool_TransportAutoStop = 1,                  -- stop transport automatically after auditioning
    bool_KeepCursorPosition = 1,                 -- false: script will leave edit cursor at the center of the fade
    bool_RemoveFade = false,                        -- audition without fade

    -------------------------------
    -- marker functions settings --
    -------------------------------

    bool_GatesTargetItemUnderMouse = false,         -- select *item* under mouse (no click to select required)
    bool_GatesTargetMouseInsteadOfCursor = false,   -- place src gate at mouse position instead of edit cursor position

    ---------------
    -- constants --
    ---------------

    markerLabel_SrcIn = "SRC_IN",
    markerLabel_SrcOut = "SRC_OUT",
    markerLabel_DstIn = "DST_IN",
    markerLabel_DstOut = "DST_OUT",
    markerIndex_DstIn = 996,
    markerIndex_DstOut = 997,
    markerColor_Src = "255,0,0",        -- red
    markerColor_Dst = "22,141,195"   -- kind of blue
}

---------------
-- functions --
---------------
function st.SetDefaultSettings()
    for k, v in pairs(tbl_defaultSettings) do
        r.SetExtState(sectionName, k, tostring(v), true)
    end
end

--------------------------------------------------------------

function st.DeleteAllSettings()

    local checkDelete = r.MB("Are you sure you want to delete all stored settings? \nThe settings will be restored to their defaults next time a seahorse script is run.", "Warning", 4)
    if checkDelete == 6 then
        for k, _ in pairs(tbl_defaultSettings) do
           r.DeleteExtState(sectionName, k, true)
        end
        r.MB("All settings deleted!", "Success", 0)
    end

end

--------------------------------------------------------------

function st.GetSettings()
    local tbl_mySettings = tbl_defaultSettings

    for k, _ in pairs(tbl_mySettings) do
        if not r.HasExtState(sectionName, k) then
            r.MB("Settings not found. Default will be restored. \nThis is normal if you're using the script for the first time.", "Info", 0)
            st.SetDefaultSettings()
        end
        local settingValue = r.GetExtState(sectionName, k)
        if settingValue == "false" then
            settingValue = false
        end
        tbl_mySettings[k] = settingValue
    end
    return tbl_mySettings
end

--------------------------------------------------------------

-- Einstellungen nach diesem Muster abrufen
function ReceiveSettings()
    local tbl_Settings = st.GetSettings()
    local bool_ShowHoverWarnings = tbl_Settings.bool_ShowHoverWarnings
    r.ShowConsoleMsg(tostring(bool_ShowHoverWarnings))
end

--------------
-- required --
--------------

return st
