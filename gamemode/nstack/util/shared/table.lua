---Returns true if the value exists anywhere in the table
---@param tbl table
---@param value any
---@return boolean
function nstack.util.tableContains( tbl , value )
    for _ , v in pairs( tbl ) do
        if v == value then return true end
    end
    return false
end
