GM.Name = "nstack"
GM.Author = "https://github.com/lt9nine"
GM.Website = "https://github.com/lt9nine/nstack"
GM.Version = "dev-0.1" -- GitHub version checker in the future?
GM.Initialized = false

if SERVER then require( "mysqloo" ) end
if SERVER then require( "gwsockets" ) end

require( "class" )

DeriveGamemode( "sandbox" )
DEFINE_BASECLASS( "gamemode_sandbox" )

_G.nstack = {
    core = {} ,
    modules = {} ,
    services = {} ,
    util = {} ,
}

AddCSLuaFile( "nstack/core/core.lua" )
include( "nstack/core/core.lua" )

AddCSLuaFile( "nstack/util/util.lua" )
include( "nstack/util/util.lua" )

AddCSLuaFile( "nstack/services/service.lua" )
include( "nstack/services/service.lua" )

-- AddCSLuaFile( "nstack/modules/module.lua" )
-- include( "nstack/modules/module.lua" )

-- initializes the server
-- gets called SERVERSIDE from core/identifier.lua
-- server and client startup obviously run async
-- ! CANT' run AddCSLuaFile() or include() operations !
function nstack.core.initialize()
    if table.Count( nstack.services ) > 0 then
        for name , service in pairs( nstack.services ) do
            if type( service ) == "table" and service._init then
                if service.status == "stopped" then
                    local env = service.environment
                    if env == "shared"
                    or ( env == "server" and SERVER )
                    or ( env == "client" and CLIENT ) then
                        service._init()
                    end
                end
            end
        end
    end

    hook.Run( "NStack.Initialized" )
end

if CLIENT then nstack.core.initialize() end