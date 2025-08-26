// Complete DAC Portfolio Analysis Pipeline
// Integrated solution for address normalization, geocoding, and DAC analysis

let
    // ============================================================================
    // CONFIGURATION SECTION
    // ============================================================================
    
    Config = [
        // File paths (adjust these to your actual file locations)
        ProjectDataPath = "C:\YourPath\sample_project_addresses.csv",
        DACDataPath = "C:\YourPath\NYS_Disadvantaged_Communities_(DAC).csv",
        CacheDataPath = "C:\YourPath\geocoding_cache.csv",
        
        // API settings
        MaxAPICallsPerRun = 25,  // Limit to avoid overwhelming Census API
        UseCache = true,
        CreateCacheIfMissing = true,
        
        // Geocoding settings
        EnableGeospatialFallback = true,
        RequireHighAccuracyMatches = false
    ],
    
    // ============================================================================
    // ADDRESS NORMALIZATION FUNCTIONS
    // ============================================================================
    
    NormalizeAddress = (address as text, city as text, state as text, zip as text) as record =>
    let
        // Clean and standardize address components
        CleanAddress = Text.Trim(Text.Upper(address)),
        CleanCity = Text.Trim(Text.Proper(city)),
        CleanState = Text.Trim(Text.Upper(state)),
        CleanZip = Text.Trim(zip),
        
        // Standardize common street abbreviations
        StandardizedAddress = 
            Text.Replace(
                Text.Replace(
                    Text.Replace(
                        Text.Replace(
                            Text.Replace(
                                Text.Replace(
                                    Text.Replace(
                                        Text.Replace(
                                            Text.Replace(
                                                Text.Replace(CleanAddress, " STREET", " ST"),
                                                " AVENUE", " AVE"),
                                            " BOULEVARD", " BLVD"),
                                        " DRIVE", " DR"),
                                    " ROAD", " RD"),
                                " LANE", " LN"),
                            " PLACE", " PL"),
                        " CIRCLE", " CIR"),
                    " COURT", " CT"),
                " PARKWAY", " PKWY"),
        
        // Extract 5-digit ZIP if ZIP+4 is provided
        ZipCode = if Text.Contains(CleanZip, "-") then 
            Text.BeforeDelimiter(CleanZip, "-") 
        else 
            CleanZip,
            
        // Create standardized full address
        FullAddress = StandardizedAddress & ", " & CleanCity & ", " & CleanState & " " & ZipCode,
        
        // Create URL-encoded geocoding query
        GeocodingQuery = Text.Replace(FullAddress, " ", "+")
    in
        [
            Normalized_Address = StandardizedAddress,
            Normalized_City = CleanCity,
            Normalized_State = CleanState,
            Normalized_ZIP = ZipCode,
            Full_Address = FullAddress,
            Geocoding_Query = GeocodingQuery
        ],
    
    // ============================================================================
    // GEOCODING FUNCTIONS
    // ============================================================================
    
    GeocodeAddress = (address as text) as record =>
    let
        // Construct Census Geocoder API URL
        BaseUrl = "https://geocoding.geo.census.gov/geocoder/locations/onelineaddress",
        QueryParams = "?address=" & Uri.EscapeDataString(address) & "&benchmark=2020&format=json",
        FullUrl = BaseUrl & QueryParams,
        
        // Make API call with comprehensive error handling
        ApiResponse = try 
            let
                WebResult = Web.Contents(FullUrl, [Timeout=#duration(0,0,0,30)]),
                JsonResult = Json.Document(WebResult)
            in
                JsonResult
        otherwise null,
        
        // Parse geocoding response
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
                    try Text.From(FirstResult[matchedAddress]) otherwise address 
                else address,
                
                TigerLineId = if FirstResult <> null then 
                    try Text.From(FirstResult[tigerLine][tigerLineId]) otherwise null 
                else null,
                
                // Extract geography information
                Geographies = if FirstResult <> null then 
                    try FirstResult[geographies] otherwise null 
                else null,
                
                // Get 2020 Census Block GEOID (15 digits)
                CensusBlocks = if Geographies <> null then 
                    try Geographies[#"2020 Census Blocks"] otherwise {} 
                else {},
                
                BlockGEOID = if List.Count(CensusBlocks) > 0 then 
                    try Text.From(CensusBlocks{0}[GEOID]) otherwise null 
                else null,
                
                // Extract Census Tract GEOID (first 11 digits of Block GEOID)
                TractGEOID = if BlockGEOID <> null and Text.Length(BlockGEOID) >= 11 then 
                    Text.Start(BlockGEOID, 11) 
                else null,
                
                // Determine match quality
                MatchQuality = if FirstResult <> null then 
                    let
                        MatchType = try Text.From(FirstResult[matchedAddress]) otherwise "",
                        Score = try Number.From(FirstResult[addressComponents][zip]) otherwise 0
                    in
                        if TractGEOID <> null then "Exact" else "Partial"
                else "Not Found"
            in
                [
                    Latitude = Latitude,
                    Longitude = Longitude,
                    Matched_Address = MatchedAddress,
                    GEOID_Block = BlockGEOID,
                    GEOID_Tract = TractGEOID,
                    Tiger_Line_ID = TigerLineId,
                    Match_Quality = MatchQuality,
                    Geocode_Date = DateTime.LocalNow(),
                    API_Response_Status = "Success"
                ]
        else
            [
                Latitude = null,
                Longitude = null,
                Matched_Address = address,
                GEOID_Block = null,
                GEOID_Tract = null,
                Tiger_Line_ID = null,
                Match_Quality = "API Error",
                Geocode_Date = DateTime.LocalNow(),
                API_Response_Status = "Failed"
            ]
    in
        ParsedResponse,
    
    // Geospatial fallback function using point-in-polygon
    GeospatialFallback = (latitude as number, longitude as number) as record =>
    let
        // Construct coordinates API URL
        BaseUrl = "https://geocoding.geo.census.gov/geocoder/geographies/coordinates",
        QueryParams = "?x=" & Number.ToText(longitude) & "&y=" & Number.ToText(latitude) & "&benchmark=2020&vintage=2020&format=json",
        FullUrl = BaseUrl & QueryParams,
        
        ApiResponse = try Json.Document(Web.Contents(FullUrl, [Timeout=#duration(0,0,0,30)])) otherwise null,
        
        ParsedResponse = if ApiResponse <> null then
            let
                GeographyData = try ApiResponse[result][geographies] otherwise null,
                CensusTracts = if GeographyData <> null then 
                    try GeographyData[#"2020 Census Tracts"] otherwise {} 
                else {},
                
                FirstTract = if List.Count(CensusTracts) > 0 then CensusTracts{0} else null,
                
                TractGEOID = if FirstTract <> null then 
                    try Text.From(FirstTract[GEOID]) otherwise null 
                else null,
                
                TractName = if FirstTract <> null then 
                    try Text.From(FirstTract[NAME]) otherwise null 
                else null
            in
                [
                    GEOID_Tract_Fallback = TractGEOID,
                    Tract_Name = TractName,
                    Fallback_Method = "Point-in-Polygon",
                    Fallback_Date = DateTime.LocalNow(),
                    Fallback_Status = if TractGEOID <> null then "Success" else "Failed"
                ]
        else
            [
                GEOID_Tract_Fallback = null,
                Tract_Name = null,
                Fallback_Method = "API Error",
                Fallback_Date = DateTime.LocalNow(),
                Fallback_Status = "Failed"
            ]
    in
        ParsedResponse,
    
    // ============================================================================
    // CACHE MANAGEMENT FUNCTIONS
    // ============================================================================
    
    LoadGeocodingCache = () as table =>
    let
        CacheExists = try 
            let TestFile = File.Contents(Config[CacheDataPath]) in true
        otherwise false,
        
        Cache = if CacheExists then
            let
                CacheSource = Csv.Document(File.Contents(Config[CacheDataPath]), [Delimiter=",", Encoding=65001, QuoteStyle=QuoteStyle.None]),
                CacheWithHeaders = Table.PromoteHeaders(CacheSource, [PromoteAllScalars=true]),
                TypedCache = Table.TransformColumnTypes(
                    CacheWithHeaders,
                    {
                        {"Geocoding_Query", type text},
                        {"Latitude", type number},
                        {"Longitude", type number},
                        {"Matched_Address", type text},
                        {"GEOID_Block", type text},
                        {"GEOID_Tract", type text},
                        {"Match_Quality", type text},
                        {"Geocode_Date", type datetime}
                    }
                )
            in
                TypedCache
        else if Config[CreateCacheIfMissing] then
            // Create empty cache with proper schema
            #table(
                type table [
                    Geocoding_Query = text,
                    Latitude = number,
                    Longitude = number,
                    Matched_Address = text,
                    GEOID_Block = text,
                    GEOID_Tract = text,
                    Match_Quality = text,
                    Geocode_Date = datetime
                ],
                {}
            )
        else
            error "Geocoding cache file not found and CreateCacheIfMissing is false"
    in
        Cache,
    
    // ============================================================================
    // DAC DATA FUNCTIONS
    // ============================================================================
    
    LoadDACData = () as table =>
    let
        // Load DAC CSV data
        DACSource = Csv.Document(File.Contents(Config[DACDataPath]), [Delimiter=",", Encoding=65001, QuoteStyle=QuoteStyle.None]),
        DACWithHeaders = Table.PromoteHeaders(DACSource, [PromoteAllScalars=true]),
        
        // Type key columns for analysis
        DACTyped = Table.TransformColumnTypes(
            DACWithHeaders,
            {
                {"GEOID", type text},
                {"DAC_Desig", type text},
                {"REDC", type text},
                {"County", type text},
                {"City_Town", type text},
                {"NYC_Region", type text},
                {"Urb_Rural", type text},
                {"Rank_State", type number},
                {"Rank_NYC", type number},
                {"Rank_ROS", type number},
                {"Comb_Sc", type number},
                {"Burden_Pct", type number},
                {"Vulner_Pct", type number},
                {"Burden_Sc", type number},
                {"Vulner_Sc", type number}
            }
        ),
        
        // Add calculated fields for analysis
        WithCalculatedFields = Table.AddColumn(
            Table.AddColumn(
                Table.AddColumn(
                    DACTyped,
                    "Is_DAC",
                    each if [DAC_Desig] = "Designated as DAC" then "Yes" else "No"
                ),
                "DAC_Priority_Score",
                each if [DAC_Desig] = "Designated as DAC" then
                    (if [Comb_Sc] <> null then [Comb_Sc] else 50)
                else
                    (if [Comb_Sc] <> null then [Comb_Sc] * 0.3 else 15)
            ),
            "DAC_Priority_Tier",
            each if [Is_DAC] = "Yes" then
                if [DAC_Priority_Score] >= 90 then "Critical"
                else if [DAC_Priority_Score] >= 75 then "High"
                else if [DAC_Priority_Score] >= 60 then "Medium"
                else "Standard"
            else
                "Low"
        )
    in
        WithCalculatedFields,
    
    // ============================================================================
    // MAIN PIPELINE FUNCTION
    // ============================================================================
    
    ExecuteMainPipeline = () as table =>
    let
        // STEP 1: Load source data
        ProjectSource = Csv.Document(File.Contents(Config[ProjectDataPath]), [Delimiter=",", Encoding=65001, QuoteStyle=QuoteStyle.None]),
        ProjectData = Table.PromoteHeaders(ProjectSource, [PromoteAllScalars=true]),
        
        // STEP 2: Normalize addresses
        // First, ensure we don't have conflicting column names
        PotentialConflicts = {"Geocoding_Query", "Full_Address", "Norm_Address", "Norm_City", "Norm_State", "Norm_ZIP", 
                              "Latitude", "Longitude", "Final_GEOID_Tract", "Is_DAC", "DAC_Priority_Tier"},
        ExistingConflicts = List.Select(PotentialConflicts, each Table.HasColumns(ProjectData, {_})),
        CleanProjectData = if List.Count(ExistingConflicts) > 0 then
            Table.RemoveColumns(ProjectData, ExistingConflicts)
        else
            ProjectData,
            
        WithNormalizedAddresses = Table.AddColumn(
            CleanProjectData,
            "AddressNormalization",
            each NormalizeAddress([Address], [City], [State], [ZIP]),
            type record
        ),
        
        ExpandedNormalization = Table.ExpandRecordColumn(
            WithNormalizedAddresses,
            "AddressNormalization",
            {"Normalized_Address", "Normalized_City", "Normalized_State", "Normalized_ZIP", "Full_Address", "Geocoding_Query"},
            {"Norm_Address", "Norm_City", "Norm_State", "Norm_ZIP", "Full_Address", "Geocoding_Query"}
        ),
        
        // STEP 3: Load cache and prepare for geocoding
        GeocodingCache = LoadGeocodingCache(),
        CacheLookup = Table.ToRecords(GeocodingCache),
        
        // STEP 4: Geocode addresses with cache lookup
        WithGeocode = Table.AddColumn(
            ExpandedNormalization,
            "GeocodeResult",
            each 
                let
                    Query = [Geocoding_Query],
                    CachedResult = List.Select(CacheLookup, each [Geocoding_Query] = Query),
                    UseCache = Config[UseCache] and List.Count(CachedResult) > 0,
                    
                    Result = if UseCache then
                        let CachedRecord = CachedResult{0} in
                        [
                            Latitude = CachedRecord[Latitude],
                            Longitude = CachedRecord[Longitude],
                            Matched_Address = CachedRecord[Matched_Address],
                            GEOID_Block = CachedRecord[GEOID_Block],
                            GEOID_Tract = CachedRecord[GEOID_Tract],
                            Tiger_Line_ID = null,
                            Match_Quality = CachedRecord[Match_Quality] & " (Cached)",
                            Geocode_Date = CachedRecord[Geocode_Date],
                            API_Response_Status = "Cached"
                        ]
                    else
                        GeocodeAddress(Query)
                in
                    Result,
            type record
        ),
        
        // STEP 5: Expand geocoding results
        ExpandedGeocode = Table.ExpandRecordColumn(
            WithGeocode,
            "GeocodeResult",
            {"Latitude", "Longitude", "Matched_Address", "GEOID_Block", "GEOID_Tract", "Tiger_Line_ID", "Match_Quality", "Geocode_Date", "API_Response_Status"},
            {"Latitude", "Longitude", "Matched_Address", "GEOID_Block", "GEOID_Tract", "Tiger_Line_ID", "Match_Quality", "Geocode_Date", "API_Response_Status"}
        ),
        
        // STEP 6: Apply geospatial fallback where needed
        WithFallback = if Config[EnableGeospatialFallback] then
            Table.AddColumn(
                ExpandedGeocode,
                "FallbackResult",
                each if [GEOID_Tract] = null and [Latitude] <> null and [Longitude] <> null then
                    GeospatialFallback([Latitude], [Longitude])
                else
                    [
                        GEOID_Tract_Fallback = null,
                        Tract_Name = null,
                        Fallback_Method = "Not Needed",
                        Fallback_Date = null,
                        Fallback_Status = "Not Needed"
                    ],
                type record
            )
        else
            Table.AddColumn(
                ExpandedGeocode,
                "FallbackResult",
                each [
                    GEOID_Tract_Fallback = null,
                    Tract_Name = null,
                    Fallback_Method = "Disabled",
                    Fallback_Date = null,
                    Fallback_Status = "Disabled"
                ],
                type record
            ),
        
        ExpandedFallback = Table.ExpandRecordColumn(
            WithFallback,
            "FallbackResult",
            {"GEOID_Tract_Fallback", "Tract_Name", "Fallback_Method", "Fallback_Date", "Fallback_Status"},
            {"GEOID_Tract_Fallback", "Tract_Name", "Fallback_Method", "Fallback_Date", "Fallback_Status"}
        ),
        
        // STEP 7: Determine final Census Tract GEOID
        WithFinalTract = Table.AddColumn(
            ExpandedFallback,
            "Final_GEOID_Tract",
            each if [GEOID_Tract] <> null then [GEOID_Tract] else [GEOID_Tract_Fallback]
        ),
        
        // STEP 8: Load DAC data and join
        DACData = LoadDACData(),
        
        JoinedWithDAC = Table.NestedJoin(
            WithFinalTract,
            {"Final_GEOID_Tract"},
            DACData,
            {"GEOID"},
            "DACInfo",
            JoinKind.LeftOuter
        ),
        
        // STEP 9: Expand DAC information
        ExpandedDAC = Table.ExpandTableColumn(
            JoinedWithDAC,
            "DACInfo",
            {
                "DAC_Desig", "REDC", "County", "City_Town", "NYC_Region", "Urb_Rural",
                "Is_DAC", "Rank_State", "Rank_NYC", "Rank_ROS",
                "Comb_Sc", "Burden_Pct", "Vulner_Pct", "Burden_Sc", "Vulner_Sc",
                "DAC_Priority_Score", "DAC_Priority_Tier"
            },
            {
                "DAC_Designation", "REDC_Region", "DAC_County", "DAC_City_Town", "NYC_Region", "Urban_Rural",
                "Is_DAC", "DAC_Rank_State", "DAC_Rank_NYC", "DAC_Rank_ROS",
                "DAC_Combined_Score", "DAC_Burden_Percentile", "DAC_Vulnerability_Percentile", 
                "DAC_Burden_Score", "DAC_Vulnerability_Score",
                "DAC_Priority_Score", "DAC_Priority_Tier"
            }
        ),
        
        // STEP 10: Add analysis and recommendation fields
        WithAnalysis = Table.AddColumn(
            Table.AddColumn(
                Table.AddColumn(
                    ExpandedDAC,
                    "Data_Quality_Flag",
                    each if [Final_GEOID_Tract] = null then "No Census Tract"
                        else if [Is_DAC] = null then "No DAC Data Match"
                        else if Text.Contains([Match_Quality], "API Error") then "Geocoding Failed"
                        else if Text.Contains([Match_Quality], "Not Found") then "Address Not Found"
                        else if [Fallback_Method] = "Point-in-Polygon" then "Fallback Geocoding Used"
                        else "Good Data Quality"
                ),
                "Investment_Recommendation",
                each if [Data_Quality_Flag] <> "Good Data Quality" and [Data_Quality_Flag] <> "Fallback Geocoding Used" then 
                    "DATA REVIEW REQUIRED"
                    else if [Is_DAC] = "Yes" then
                        if [DAC_Priority_Tier] = "Critical" then "IMMEDIATE PRIORITY - Critical DAC Community"
                        else if [DAC_Priority_Tier] = "High" then "HIGH PRIORITY - DAC Community"
                        else if [DAC_Priority_Tier] = "Medium" then "MEDIUM PRIORITY - DAC Community"
                        else "STANDARD PRIORITY - DAC Community"
                    else if [DAC_Combined_Score] <> null and [DAC_Combined_Score] > 50 then 
                        "CONSIDER - Moderate Environmental/Social Need"
                    else 
                        "STANDARD PRIORITY - Non-DAC Area"
            ),
            "Analysis_Summary",
            each [Investment_Recommendation] & " | Quality: " & [Data_Quality_Flag] & 
                (if [Is_DAC] = "Yes" then " | DAC Score: " & Number.ToText([DAC_Combined_Score]) else "")
        ),
        
        // STEP 11: Final column ordering and cleanup
        FinalColumns = Table.SelectColumns(
            WithAnalysis,
            {
                "Project_ID", "Project_Name", "Priority",
                "Address", "City", "State", "ZIP",
                "Full_Address", "Matched_Address",
                "Latitude", "Longitude", "Final_GEOID_Tract",
                "Is_DAC", "DAC_Priority_Tier", "Investment_Recommendation",
                "DAC_Combined_Score", "DAC_Burden_Percentile", "DAC_Vulnerability_Percentile",
                "DAC_Rank_State", "DAC_Rank_ROS",
                "DAC_County", "DAC_City_Town", "REDC_Region",
                "Data_Quality_Flag", "Match_Quality", "Analysis_Summary",
                "Geocode_Date"
            }
        )
    in
        FinalColumns,
    
    // Execute the complete pipeline
    FinalResult = ExecuteMainPipeline()
in
    FinalResult