---Returns whether a value is contained in a list
---@param list table
---@param value any
---@return boolean
function nstack.util.tableContains( list , value )
    for _ , v in pairs( list ) do
        if v == value then return true end
    end
    return false
end
