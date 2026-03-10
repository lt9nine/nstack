nstack.core.log = {}

nstack.core.log.levels = {
    { name = "trace", ansiColor = "\27[34m", msgcColor = Color( 0 , 0 , 255 ) },        -- Blue
    { name = "debug", ansiColor = "\27[36m", msgcColor = Color( 0 , 183 , 255 ) },      -- Cyan
    { name = "info",  ansiColor = "\27[32m", msgcColor = Color( 33 , 185 , 33 ) },      -- Green
    { name = "warn",  ansiColor = "\27[33m", msgcColor = Color( 255 , 170 , 0 ) },      -- Orange
    { name = "error", ansiColor = "\27[31m", msgcColor = Color( 255 , 104 , 104 ) },    -- Light Red
    { name = "fatal", ansiColor = "\27[35m", msgcColor = Color( 255 , 0 , 0 ) },        -- Red
}

local function getLogFileName()
    local date = os.date( "%Y-%m-%d" )
    return "nstack_" .. date .. ".txt"
end

local function writeToLogFile( level , category , message )
    local filename = getLogFileName()
    local timestamp = os.date( "%Y-%m-%d %H:%M:%S" )
    local logEntry = string.format ("[%-6s %s] %s: %s\n" , level , timestamp , category , message )
    
    if file.Exists( filename , "DATA" ) then
        file.Append( filename , logEntry )
    else
        file.Write( filename , logEntry )
    end
end

for i , x in ipairs( nstack.core.log.levels ) do
    local nameupper = x.name:upper()
    nstack.core.log[ x.name ] = function( category , ... )
        local message = tostring( ... )
        local categoryUpper = string.upper( category )

        if SERVER then
            print( 
                string.format(
                    "%s[%-6s%s]%s %s: %s" ,
                    x.ansiColor ,
                    nameupper ,
                    os.date( "%H:%M:%S" ) ,
                    "\27[0m" ,
                    categoryUpper ,
                    message
                )
            )
        else
            MsgC(
                x.msgcColor ,
                string.format( "[%-6s" , nameupper ) ,
                Color( 255 , 255 , 255 ) ,
                os.date( "%H:%M:%S" ) ,
                x.msgcColor ,
                "]" ,
                Color( 255 , 255 , 255 ) ,
                " " ,
                categoryUpper ,
                ": " ,
                message ,
                "\n"
            )
        end

        writeToLogFile( nameupper , categoryUpper , message )
    end
end