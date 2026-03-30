net.Receive( "nstack:service:chat:message" , function()
    local entries = net.ReadTable()
    local args = {}

    for _ , entry in ipairs( entries ) do
        if ( entry.isColor ) then
            args[ #args + 1 ] = Color( entry.r , entry.g , entry.b )
        else
            args[ #args + 1 ] = entry.value
        end
    end

    chat.AddText( unpack( args ) )
end )
