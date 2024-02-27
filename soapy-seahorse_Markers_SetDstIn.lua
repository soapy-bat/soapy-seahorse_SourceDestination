---------------
-- variables --
---------------

local r = reaper
local markerLabel = "DST_IN"
local markerColor = r.ColorToNative(22, 141, 195)

------------------------------------------
function main()
    local cursorPos = (r.GetPlayState() == 0) and r.GetCursorPosition() or r.GetPlayPosition()
    r.DeleteProjectMarker(NULL, 996, false)
    r.AddProjectMarker2(0, false, cursorPos, 0, markerLabel, 996, markerColor | 0x1000000)
end

------------------------------------------
main()
