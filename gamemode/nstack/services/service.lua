local serviceFolder = GM.FolderName .. "/gamemode/nstack/services"
local files , folders = file.Find( serviceFolder .. "/*" , "LUA" )
local serviceCount = 0

function nstack.services.register( service )
    if service and service.name and service.files then
        if table.Count( service.files ) > 0 then
            if service.environment then
                for _ , fileEntry in ipairs( service.files ) do
                    local isCompatible = false
                    if ( service.environment == "shared" ) then
                        isCompatible = fileEntry.environment == "server" or fileEntry.environment == "client" or fileEntry.environment == "shared"
                    else
                        isCompatible = fileEntry.environment == service.environment
                    end

                    if ( not isCompatible ) then
                        nstack.core.log.error( "services" , "service " .. service.name .. " is environment '" .. service.environment .. "' but file '" .. ( fileEntry.file or "?" ) .. "' has environment '" .. ( fileEntry.environment or "?" ) .. "', skipping..." )
                        return false
                    end
                end
            else
                nstack.core.log.error( "services" , "service " .. service.name .. " has no environment set, skipping..." )
                return false
            end
            nstack.services[ service.name ] = service
            nstack.services[ service.name ].status = "stopped" -- default
            nstack.core.log.debug( "services" , "registered service " .. service.name .. " with " .. table.Count( service.files ) .. " files." )
            return true
        else
            nstack.core.log.error( "services" , "service " .. service.name .. " wants to register without files, skipping..." )
        end
    end

    nstack.core.log.error( "services" , "service configuration faulty, skipping..." )
    return false
end

for _ , folderName in ipairs( folders ) do
    local servicePath = serviceFolder .. "/" .. folderName .. "/_service.lua"
    if file.Exists( servicePath , "LUA" ) then
        AddCSLuaFile( serviceFolder .. "/" .. folderName .. "/_service.lua" )
        local service = include( folderName .. "/_service.lua" )

        if nstack.services.register( service ) then -- cancel here if service is faulty
            serviceCount = serviceCount + 1
            for _ , fileEntry in ipairs( service.files ) do
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
