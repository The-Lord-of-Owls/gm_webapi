--Localizations
local isstring		= isstring
local isnumber		= isnumber
local istable		= istable
local isfunction	= isfunction
local ErrorNoHalt	= ErrorNoHalt
local HTTP 		= HTTP

local apiUrl		= ""
local apiHeaders	= {}

local methods		= {}


--[[
  Doccumentation: https://github.com/The-Lord-of-Owls/gm_webapi/tree/main#apiadd-id-route-cback-onerror-cachettl-customheaders-
]]
local function Add( id, route, cback, onError, cacheTTL, customHeaders )
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

	--Specify optional custom headers for method
	if customHeaders and istable( customHeaders ) then
		method.headers = customHeaders
	elseif customHeaders then
		ErrorNoHalt( "API WARNING: Custom route headers must be in a keyvalue table format. The API method has been created but custom headers have not been set for it!" )
	end

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
	if apiUrl == "" then
		return ErrorNoHalt( "API ERROR: API URL has not been set, aborting API call! Please make sure to run api.SetURL before calling any methods!" )
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

	HTTP( {
		failed = method.onError or ErrorNoHalt,
		success = function( code, res, headers )
			--Update the cache
			if apiMethod.cacheTTL then
				apiMethod.lastCache = CurTime() + apiMethod.cacheTTL
				apiMethod.cacheRes = res
			end

			apiMethod.cback( res )
		end,
		method = "POST",
		url = apiUrl .. apiMethod.route,
		parameters = params or {},
		headers = apiMethod.headers or apiHeaders,
		timeoute = apiMethod.timeoute or 60
	} )
end

--[[
  Doccumentation: https://github.com/The-Lord-of-Owls/gm_webapi/tree/main#apigettable
]]
local function GetTable()
	return methods or {}
end


--[[
	Doccumentation: https://github.com/The-Lord-of-Owls/gm_webapi/tree/main#apiseturl-url-
]]
local function SetUrl( url )
	if not url and isstring( url ) then
		return ErrorNoHalt( "API ERROR: Please provide a valid url string for the API!" )
	end

	apiUrl = url
end


--[[
	Doccumentation: https://github.com/The-Lord-of-Owls/gm_webapi/tree/main#apiaddheader-header-value-
]]
local function AddHeader( header, value )
	if not header or not isstring( header ) then
		return ErrorNoHalt( "API ERROR: Please provide a proper header string!" )
	end

	if not value or not isstring( value ) then
		return ErrorNoHalt( "API ERROR: Please provide a proper header string value!" )
	end

	apiHeaders[ header ] = value
end

--[[
	Doccumentation: https://github.com/The-Lord-of-Owls/gm_webapi/tree/main#apisetheader-header-value-
]]
local function SetHeader( header, value )
	if not header or not isstring( header ) then
		return ErrorNoHalt( "API ERROR: Please provide a proper header string!" )
	end

	if not value or not isstring( value ) then
		return ErrorNoHalt( "API ERROR: Please provide a proper header string value!" )
	end

	apiHeaders[ header ] = value
end

--[[
  Doccumentation: https://github.com/The-Lord-of-Owls/gm_webapi/tree/main#apiremoveheader-header-
]]
local function RemoveHeader( header )
	if not header or not isstring( header ) then
		return ErrorNoHalt( "API ERROR: Please provide a proper header string!" )
	end

	apiHeaders[ header ] = nil
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
	SetUrl = SetUrl,
	AddHeader = AddHeader,
	SetHeader = SetHeader,
	RemoveHeader = RemoveHeader
}, {
	__metatable = "WebAPI Handler",
	__call = function( self, ... )
		Call( ... )
	end
} )


