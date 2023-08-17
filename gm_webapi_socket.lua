--[[
	This is required because SOMEONE on the gmod dev team decided to remove how we can interact with sockets clientside using HTTP or dhtml panels. Thanks bro, real cool!


	This will likely need work done before it is in a production usable state!
	For now it is for testing only. Hopefully this can be used to serve as a socket based alternative to HTTP for the library

	This has to use a c++ module clientside. So the chances of this being used is not very likely for most clients. But if the module is available, we could in theory use it.

	If not, we can default back to the version of the library that uses HTTP instead. Once this is made to be just as usable I will work on making three versions of the library:
		Stand Alone HTTP Only(will not require players to install bromsock)
		Stand Alone Socket Only(Will require all players to have bromsock on their client)
		Hybrid prioritizing Socket(If bromsock is on the client we will use it, if not then we will use HTTP)
]]


require( "bromsock" )
local webAPIConn = BromSock()

--Localizations
local isstring		= isstring
local isnumber		= isnumber
local istable		= istable
local isfunction	= isfunction
local ErrorNoHalt	= ErrorNoHalt

local apiUrl		= ""

local methods		= {}



--[[
  Doccumentation: https://github.com/The-Lord-of-Owls/gm_webapi/tree/main#apiadd-id-route-cback-onerror-cachettl-customheaders-
]]
local function Add( id, route, cback, onError, cacheTTL )
	--Check if an id was provided
	if not id or not isstring( id ) then
		return ErrorNoHalt( "API ERROR: You must provide an id when setting up a new API method!" )
	end

	--Check if a route was provided
	if not route or not isstring( route ) then
		return ErrorNoHalt( "API ERROR: You must specify a route when setting up a new API method!" )
	end

	--Check if a callback function was provided
	if not cback or not isfunction( cback ) then
		return ErrorNoHalt( "API ERROR: You must provide a callback function when setting up a new API method!" )
	end


	--Setup method object
	local method = {
		route = route,
		method.cback = cback
	}

	--Optional error response
	if onError and isfunction( onError ) then
		method.onError = onError
	elseif onError then
		ErrorNoHalt( "API WARNING: Custom onError must be a function, the API method has been created without custom error handling!" )
	end

	--Handle if we will cache the value
	if cacheTTL and isnumber( cacheTTL ) then
		method.cacheRes = ""
		method.cacheTTL = cacheTTL
		method.lastCache = 0
	elseif cacheTTL then
		ErrorNoHalt( "API WARNING: cacheTTL for API methods must be a number value, the API method has been created with caching disabled!" )
	end

	--Make the method object accessible
	methods[ id ] = method
end

--[[
	Doccumentation: https://github.com/The-Lord-of-Owls/gm_webapi/tree/main#apiremove-id-
]]
local function Remove( id )
	if not id or not isstring( id ) then
		return ErrorNoHalt( "API WARNING: Please provide a id string for the method you want to remove!" )
	end

	methods[ id ] = nil
end

--[[
	Doccumentation: https://github.com/The-Lord-of-Owls/gm_webapi/tree/main#apicall-id-params-
]]
local function Call( id, params )
	--Check if the API url has been set
	if webAPIConn:IsValid() then
		return ErrorNoHalt( "API ERROR: API socket has not been initialized, aborting API call! Please make sure to run api.Init( url, port ) before calling any methods!" )
	end

	--Check if the API method exists
	if not methods[ id ] then
		return ErrorNoHalt( "API ERROR: The API method '" .. id .. "' does not exist!" )
	end

	--The API method
	local apiMethod = methods[ id ]

	--Check if the API has a proper callback function
	if not apiMethod.cback then
		return ErrorNoHalt( "API ERROR: The API method '" .. id .. "' does not have a callback function!")
	end

	--Check if should return cached value
	if apiMethod.cacheTTL and apiMethod.cacheTTL < CurTime() then
		apiMethod.cback( method.cacheRes )

		return
	end

	--Handle API calls with socket connection
	local packet = BromPacket()
		packet:WriteLine( "Route: " .. apiMethod.route )
		packet:WriteLine( util.TableToJSON( params ) or "{}" )
		packet:WriteLine( "" )

	webAPIConn:Send( packet, true )
end

--[[
  Doccumentation: https://github.com/The-Lord-of-Owls/gm_webapi/tree/main#apigettable
]]
local function GetTable()
	return methods or {}
end

--[[
	Initializes connection
]]
local function Init( url, port, timeout, ssl )
	if not url and isstring( url ) then
		return ErrorNoHalt( "API ERROR: Please provide a valid url string for the API!" )
	end

	if not port and isnumber( port ) then
		return ErrorNoHalt( "API ERROR: Please provide a valid port number for the API!" )
	end

	--Handling connection successfull and SSL
	webAPIConn:SetCallbackConnect( function( _, connected, ip, port )
		if not connected then
			return ErrorNoHalt( "API ERROR: Unable to successfully connect to the API socket!")
		end

		--Switch to SSL
		if ssl then webAPIConn:StartSSLClient() end
	end)

	--Handling Response from API
	webAPIConn:SetCallbackReceive( function( _, packetIncoming )
		local response = packetIncoming:ReadStringAll():Trim()
			packetIncoming = nil
			webAPIConn:Receive( #response )

		local responseData = util.JSONToTable( response ) or {}

		if not responseData.id then
			return ErrorNoHalt( "API ERROR: The API did not include the id! Aborting callback handling" )
		end

		local apiMethod = methods[ responseData.id ]

		if not apiMethod.cback then
			return ErrorNoHalt( "API ERROR: The API method '" .. responseData.id .. "' does not have a callback function!")
		end

		--Update the cache
		if apiMethod.cacheTTL then
			apiMethod.lastCache = CurTime() + apiMethod.cacheTTL
			apiMethod.cacheRes = res
		end

		--Run the callback
		apiMethod.cback( responseData.resParams )
	end)

	--Initialize the connection
	apiUrl = url
	webAPIConn:Connect( url, port )

	--Set timeoute in seconds
	if timeoute and isnumber( timeoute ) then
		webAPIConn:SetTimeout( timeoute * 1000 )
	else
		webAPIConn:SetTimeout( 60 * 1000 )
	end
end


--[[
	Setting up our API library table
	Doccumentation: https://github.com/The-Lord-of-Owls/gm_webapi/blob/main/README.md#apicall-id-params-
]]
api = setmetatable( {
	Add = Add,
	Remove = Remove,
	Call = Call,
	GetTable = GetTable,
	Init = Init
}, {
	__metatable = "WebAPI Handler",
	__call = function( self, ... )
		Call( ... )
	end
} )


