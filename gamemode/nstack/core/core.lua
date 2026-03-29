AddCSLuaFile( "log.lua" )
include( "log.lua" ) -- shared

if SERVER then 
    include( "identifier.lua" )
    include( "connect_reject.lua" )
end