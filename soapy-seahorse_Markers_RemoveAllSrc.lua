local r = reaper
local so = {}

local markerLabelIn = "SRC_IN"
local markerLabelOut = "SRC_OUT"

-------------------------------------------

function RemoveAllSourceGates()

  r.Main_OnCommand(40182, 0) -- Select All

  local numSelectedItems = r.CountSelectedMediaItems(0)
  
   -- Iterate through selected items
   for i = 0, numSelectedItems - 1 do

    -- Get the active media item
    local mediaItem = r.GetSelectedMediaItem(0, i)
    
    if mediaItem then
        -- Get the active take
        local activeTake = r.GetActiveTake(mediaItem)
    
        if activeTake then
            -- Remove existing MarkerLabel markers
            local numMarkers = r.GetNumTakeMarkers(activeTake)
            for i = numMarkers, 0, -1 do
                local _, markerType, _, _, _ = r.GetTakeMarker(activeTake, i)
                if markerType == markerLabelIn then
                    r.DeleteTakeMarker(activeTake, i)
                end
                if markerType == markerLabelOut then
                    r.DeleteTakeMarker(activeTake, i)
                end
            end
    
            -- Update the arrangement
            r.UpdateArrange()
        end
    end
  end
  
  r.Main_OnCommand(40289, 0) -- Deselect all items
  
end

-------------------------------------------

RemoveAllSourceGates()
