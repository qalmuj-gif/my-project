// Geocoding Service Module with Caching
// Handles address geocoding with cache to improve performance

let
    // Function to geocode a single address using Census Geocoder API
    GeocodeAddress = (address as text) as record =>
    let
        // Construct Census Geocoder API URL
        BaseUrl = "https://geocoding.geo.census.gov/geocoder/locations/onelineaddress",
        QueryParams = "?address=" & Uri.EscapeDataString(address) & "&benchmark=2020&format=json",
        FullUrl = BaseUrl & QueryParams,
        
        // Make API call with error handling
        ApiResponse = try Json.Document(Web.Contents(FullUrl)) otherwise null,
        
        // Parse response
        ParsedResponse = if ApiResponse <> null then
            let
                ResultList = try ApiResponse[result][addressMatches] otherwise {},
                FirstResult = if List.Count(ResultList) > 0 then ResultList{0} else null,
                
                Latitude = if FirstResult <> null then 
                    try Number.FromText(Text.From(FirstResult[coordinates][y])) otherwise null 
                else null,
                
                Longitude = if FirstResult <> null then 
                    try Number.FromText(Text.From(FirstResult[coordinates][x])) otherwise null 
                else null,
                
                MatchedAddress = if FirstResult <> null then 
                    try FirstResult[matchedAddress] otherwise address 
                else address,
                
                GEOID = if FirstResult <> null then 
                    try FirstResult[geographies][`2020 Census Blocks`]{0}[GEOID] otherwise null 
                else null,
                
                // Extract Census Tract (first 11 digits of Block GEOID)
                CensusTract = if GEOID <> null and Text.Length(GEOID) >= 11 then 
                    Text.Start(GEOID, 11) 
                else null,
                
                MatchQuality = if FirstResult <> null then "Exact" else "Not Found"
            in
                [
                    Latitude = Latitude,
                    Longitude = Longitude,
                    MatchedAddress = MatchedAddress,
                    GEOID_Block = GEOID,
                    GEOID_Tract = CensusTract,
                    MatchQuality = MatchQuality,
                    GeocodeDate = DateTime.LocalNow()
                ]
        else
            [
                Latitude = null,
                Longitude = null,
                MatchedAddress = address,
                GEOID_Block = null,
                GEOID_Tract = null,
                MatchQuality = "API Error",
                GeocodeDate = DateTime.LocalNow()
            ]
    in
        ParsedResponse,
    
    // Function to perform geospatial fallback using point-in-polygon
    GeospatialFallback = (latitude as number, longitude as number) as record =>
    let
        // Create point geometry for Census API
        PointQuery = "POINT(" & Number.ToText(longitude) & " " & Number.ToText(latitude) & ")",
        
        // Query Census API for tract information using coordinates
        BaseUrl = "https://geocoding.geo.census.gov/geocoder/geographies/coordinates",
        QueryParams = "?x=" & Number.ToText(longitude) & "&y=" & Number.ToText(latitude) & "&benchmark=2020&vintage=2020&format=json",
        FullUrl = BaseUrl & QueryParams,
        
        ApiResponse = try Json.Document(Web.Contents(FullUrl)) otherwise null,
        
        ParsedResponse = if ApiResponse <> null then
            let
                GeographyList = try ApiResponse[result][geographies][`2020 Census Tracts`] otherwise {},
                FirstResult = if List.Count(GeographyList) > 0 then GeographyList{0} else null,
                
                CensusTract = if FirstResult <> null then 
                    try FirstResult[GEOID] otherwise null 
                else null
            in
                [
                    GEOID_Tract_Fallback = CensusTract,
                    FallbackMethod = "Point-in-Polygon",
                    FallbackDate = DateTime.LocalNow()
                ]
        else
            [
                GEOID_Tract_Fallback = null,
                FallbackMethod = "Failed",
                FallbackDate = DateTime.LocalNow()
            ]
    in
        ParsedResponse,
    
    // Main geocoding function with caching
    GeocodeWithCache = (InputTable as table, CacheTable as table) as table =>
    let
        // Create cache lookup
        CacheLookup = if Table.RowCount(CacheTable) > 0 then
            Table.ToRecords(
                Table.SelectColumns(CacheTable, {"Geocoding_Query", "Latitude", "Longitude", "MatchedAddress", "GEOID_Block", "GEOID_Tract", "MatchQuality"})
            )
        else {},
        
        // Function to get cached result or geocode new
        GetGeocode = (query as text) as record =>
        let
            CachedResult = List.Select(CacheLookup, each [Geocoding_Query] = query),
            UseCache = List.Count(CachedResult) > 0,
            
            Result = if UseCache then
                CachedResult{0}
            else
                GeocodeAddress(query)
        in
            Result,
        
        // Add geocoding results
        WithGeocode = Table.AddColumn(
            InputTable,
            "GeocodeResult",
            each GetGeocode([Geocoding_Query]),
            type record
        ),
        
        // Expand geocoding results
        ExpandedGeocode = Table.ExpandRecordColumn(
            WithGeocode,
            "GeocodeResult",
            {"Latitude", "Longitude", "MatchedAddress", "GEOID_Block", "GEOID_Tract", "MatchQuality", "GeocodeDate"},
            {"Latitude", "Longitude", "Matched_Address", "GEOID_Block", "GEOID_Tract", "Match_Quality", "Geocode_Date"}
        ),
        
        // Add geospatial fallback for failed geocodes
        WithFallback = Table.AddColumn(
            ExpandedGeocode,
            "FallbackResult",
            each if [Match_Quality] = "Not Found" and [Latitude] <> null and [Longitude] <> null then
                GeospatialFallback([Latitude], [Longitude])
            else
                [GEOID_Tract_Fallback = null, FallbackMethod = "Not Needed", FallbackDate = null],
            type record
        ),
        
        // Expand fallback results
        ExpandedFallback = Table.ExpandRecordColumn(
            WithFallback,
            "FallbackResult",
            {"GEOID_Tract_Fallback", "FallbackMethod", "FallbackDate"},
            {"GEOID_Tract_Fallback", "Fallback_Method", "Fallback_Date"}
        ),
        
        // Create final tract GEOID (use fallback if primary failed)
        WithFinalTract = Table.AddColumn(
            ExpandedFallback,
            "Final_GEOID_Tract",
            each if [GEOID_Tract] <> null then [GEOID_Tract] else [GEOID_Tract_Fallback]
        )
    in
        WithFinalTract
in
    GeocodeWithCache