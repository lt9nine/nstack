local database = mysqloo.connect( "142.132.253.80", "u15_niGPIZGZKk", "Z!vT+zaY!KQTg!4wLINRpag3", "s15_swtor-orm", 3306 )
local handler = ORM.MysqlHandler( database )
ORM.setHandler( handler )