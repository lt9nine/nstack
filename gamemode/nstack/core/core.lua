AddCSLuaFile( "log.lua" )
include( "log.lua" ) -- shared

if SERVER then include( "identifier.lua" ) end -- server