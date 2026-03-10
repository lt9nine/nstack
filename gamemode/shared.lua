GM.Name = "nstack"
GM.Author = "https://github.com/lt9nine"
GM.Website = "https://github.com/nineware-dev"
GM.Version = "0.0.0"

DeriveGamemode( "sandbox" )
DEFINE_BASECLASS( "gamemode_sandbox" )

_G.nstack = {
    core = {} ,
    class = {} ,
    modules = {} ,
    services = {} ,
    util = {} ,
}

AddCSLuaFile( "nstack/core/core.lua" )
include( "nstack/core/core.lua" )

-- State 0: load — include all framework files
nstack.core.lifecycle.start()

AddCSLuaFile( "nstack/util/util.lua" )
include( "nstack/util/util.lua" )

AddCSLuaFile( "nstack/services/service.lua" )
include( "nstack/services/service.lua" )

-- TODO: include modules here once the module system is implemented
-- AddCSLuaFile( "nstack/modules/module.lua" )
-- include( "nstack/modules/module.lua" )

-- State 1: init — validate dependency graph and resolve load order
-- TODO: check which services are actually required by active modules
-- TODO (multiserver): check which services should run on THIS server instance
nstack.core.lifecycle.set( 1 )

local loadOrder , err = nstack.services.resolveLoadOrder()

if not loadOrder then
    nstack.core.log.fatal( "services" , err )
    return
end

nstack.core.log.info( "services" , "Service load order: " .. table.concat( loadOrder , " -> " ) )
nstack.core.lifecycle.loadOrder = loadOrder

-- State 2: start — launch services (and modules in the future)
nstack.core.lifecycle.set( 2 )

for _ , name in ipairs( loadOrder ) do
    if nstack.services[ name ].start then
        nstack.services[ name ].start()
    end
end

-- TODO: start modules here once the module system is implemented

-- State 3: live — set automatically once all pending services report ready via
-- nstack.core.lifecycle.reportServiceReady. If no services are pending for this
-- environment (e.g. a client with only server-side services), checkReady advances
-- to live immediately.
nstack.core.lifecycle.checkReady()