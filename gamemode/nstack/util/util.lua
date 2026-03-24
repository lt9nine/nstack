local utilFolder = GM.FolderName .. "/gamemode/nstack/util"

-- Auto-include all files from util/shared
local sharedUtilCount = 0
local sharedFiles = file.Find( utilFolder .. "/shared/*.lua" , "LUA" )
for _ , fileName in ipairs( sharedFiles ) do
    AddCSLuaFile( GM.FolderName .. "/gamemode/nstack/util/shared/" .. fileName )
    include( "shared/" .. fileName )
    sharedUtilCount = sharedUtilCount + 1
end

-- Auto-include all files from util/client
local clientUtilCount = 0
local clientFiles = file.Find( utilFolder .. "/client/*.lua" , "LUA" )
for _ , fileName in ipairs( clientFiles ) do
    AddCSLuaFile( GM.FolderName .. "/gamemode/nstack/util/client/" .. fileName )
    if CLIENT then
        include( "client/" .. fileName )
    end
    clientUtilCount = clientUtilCount + 1
end

-- Auto-include all files from util/server
local serverUtilCount = 0
local serverFiles = file.Find( utilFolder .. "/server/*.lua" , "LUA" )
for _ , fileName in ipairs( serverFiles ) do
    if SERVER then
        include( "server/" .. fileName )
    end
    serverUtilCount = serverUtilCount + 1
end

nstack.core.log.info( "util" , "Included " .. sharedUtilCount .. " shared, " .. clientUtilCount .. " client, " .. serverUtilCount .. " server utilities" )