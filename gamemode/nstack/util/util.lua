-- Auto-include all files from util/shared
local sharedUtilCount = 0
local sharedFiles = file.Find( GM.FolderName .. "/gamemode/nstack/util/shared/*.lua" , "LUA" )
for _, filename in ipairs( sharedFiles ) do
    AddCSLuaFile( GM.FolderName .. "/gamemode/nstack/util/shared/" .. filename )
    nstack.core.include( "shared/" .. filename , "shared" )
    sharedUtilCount = sharedUtilCount + 1
end

-- Auto-include all files from util/client
if CLIENT then
    local clientUtilCount = 0
    local clientFiles = file.Find( GM.FolderName .. "/gamemode/nstack/util/client/*.lua" , "LUA" )
    for _, filename in ipairs( clientFiles ) do
        AddCSLuaFile( "nstack/util/client/" .. filename )
        nstack.core.include( "client/" .. filename , "client" )
        clientUtilCount = clientUtilCount + 1
    end
    nstack.core.log.info( "util" , "Included " .. clientUtilCount .. " client utilities and " .. sharedUtilCount .. " shared utilities" )
end

-- Auto-include all files from util/server
if SERVER then
    local serverUtilCount = 0
    local serverFiles = file.Find( GM.FolderName .. "/gamemode/nstack/util/server/*.lua" , "LUA" )
    for _, filename in ipairs( serverFiles ) do
        nstack.core.include( "server/" .. filename , "server" )
        serverUtilCount = serverUtilCount + 1
    end
    nstack.core.log.info( "util" , "Included " .. serverUtilCount .. " server utilities and " .. sharedUtilCount .. " shared utilities" )
end