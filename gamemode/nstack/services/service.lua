local serviceFolder = GM.FolderName .. "/gamemode/nstack/services"
local files , folders = file.Find( serviceFolder .. "/*" , "LUA" )

local serviceCount = 0

for _, folderName in ipairs( folders ) do
    -- Ignore files, only proceed if it's a folder
    local servicePath = serviceFolder .. "/" .. folderName .. "/_service.lua"
    if file.Exists( servicePath , "LUA" ) then
        AddCSLuaFile( serviceFolder .. "/" .. folderName .. "/_service.lua" )
        local service = include( folderName .. "/_service.lua" )
        nstack.services[ service.name ] = service
        nstack.services[ service.name ].status = "stopped" -- default
        serviceCount = serviceCount + 1

        -- Only register as lifecycle pending if this service has files for the current environment
        local hasFilesForEnv = false
        for _, fileEntry in ipairs( service.files or {} ) do
            if fileEntry.environment == "shared"
            or ( fileEntry.environment == "server" and SERVER )
            or ( fileEntry.environment == "client" and CLIENT ) then
                hasFilesForEnv = true
                break
            end
        end

        if hasFilesForEnv then
            nstack.core.lifecycle.registerService( service.name )
        end
        
        -- Include all files declared in the service's files table
        if service and service.files then
            for _, fileEntry in ipairs( service.files ) do
                if fileEntry.file and fileEntry.environment then
                    local filePath = folderName .. "/" .. fileEntry.file
                    local fullPath = serviceFolder .. "/" .. filePath
                    
                    if fileEntry.environment == "server" then
                        if SERVER then
                            include( filePath )
                        end
                    elseif fileEntry.environment == "client" then
                        if SERVER then
                            AddCSLuaFile( fullPath )
                        end
                        if CLIENT then
                            include( filePath )
                        end
                    elseif fileEntry.environment == "shared" then
                        if SERVER then
                            AddCSLuaFile( fullPath )
                        end
                        include( filePath )
                    end
                end
            end
        end
    end
end

nstack.core.log.info( "services" , "Included " .. serviceCount .. " service" .. ( serviceCount == 1 and "" or "s" ) )

--[[
    Resolves the start order of all registered services using DFS topological sort.
    Detects dependency loops and unknown dependencies.

    Returns: orderedList (table) on success
    Returns: nil, errorMessage (string) on failure
]]
function nstack.services.resolveLoadOrder()
    local order = {}
    local state = {}   -- tracks per-service DFS state: "visiting" | "visited"
    local path  = {}   -- current DFS path, used to reconstruct cycle in error message

    local function visit( name )
        if state[ name ] == "visiting" then
            local cycleNodes = {}
            local inCycle = false

            for _, node in ipairs( path ) do
                if node == name then inCycle = true end
                if inCycle then table.insert( cycleNodes , node ) end
            end

            table.insert( cycleNodes , name )
            return false , "Dependency loop detected: " .. table.concat( cycleNodes , " -> " )
        end

        if state[ name ] == "visited" then return true end

        if not istable( nstack.services[ name ] ) then
            return false , "Unknown service: '" .. name .. "'"
        end

        state[ name ] = "visiting"
        table.insert( path , name )

        local service = nstack.services[ name ]

        if service.dependencies then
            for _, dependency in ipairs( service.dependencies ) do
                local ok , err = visit( dependency )
                if not ok then return false , err end
            end
        end

        table.remove( path )
        state[ name ] = "visited"
        table.insert( order , name )

        return true
    end

    for name , entry in pairs( nstack.services ) do
        if istable( entry ) and not state[ name ] then
            local ok , err = visit( name )
            if not ok then return nil , err end
        end
    end

    return order
end