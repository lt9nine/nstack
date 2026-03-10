function nstack.core.include( filename , environment )
    if environment == "server" then
        if SERVER then
            include( filename )
        end
    elseif environment == "client" then
        if CLIENT then
            include( filename )
        end
    elseif environment == "shared" then
        AddCSLuaFile( filename )
        include( filename )
    end
end