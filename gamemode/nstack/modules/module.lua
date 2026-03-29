local moduleFolder = GM.FolderName .. "/gamemode/nstack/modules"
local files , folders = file.Find( moduleFolder .. "/*" , "LUA" )
local moduleCount = 0

function nstack.modules.register( module )
    if module and module.name and module.files then
        if table.Count( module.files ) > 0 then
            if module.environment then
                for _ , fileEntry in ipairs( module.files ) do
                    if fileEntry.environment ~= module.environment then
                        nstack.core.log.error( "modules" , "module " .. module.name .. " is environment '" .. module.environment .. "' but file '" .. ( fileEntry.file or "?" ) .. "' has environment '" .. ( fileEntry.environment or "?" ) .. "', skipping..." )
                        return false
                    end
                end
            else
                nstack.core.log.error( "modules" , "module " .. module.name .. " has no environment set, skipping..." )
                return false
            end
            nstack.modules[ module.name ] = module
            nstack.modules[ module.name ].status = "stopped" -- default
            nstack.core.log.debug( "modules" , "registered module " .. module.name .. " with " .. table.Count( module.files ) .. " files." )
            return true
        else
            nstack.core.log.error( "modules" , "module " .. module.name .. " wants to register without files, skipping..." )
        end
    end

    nstack.core.log.error( "modules" , "module configuration faulty, skipping..." )
    return false
end

for _ , folderName in ipairs( folders ) do
    local modulePath = moduleFolder .. "/" .. folderName .. "/_module.lua"
    if file.Exists( modulePath , "LUA" ) then
        AddCSLuaFile( moduleFolder .. "/" .. folderName .. "/_module.lua" )
        local module = include( folderName .. "/_module.lua" )
        
        if nstack.modules.register( module ) then
            moduleCount = moduleCount + 1
            for _ , fileEntry in ipairs( module.files ) do
                if fileEntry.file and fileEntry.environment then
                    local filePath = folderName .. "/" .. fileEntry.file
                    local fullPath = moduleFolder .. "/" .. filePath

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

nstack.core.log.info( "modules" , "Included " .. moduleCount .. " module" .. ( moduleCount == 1 and "" or "s" ) )