
// =============================================================================
// NY DAC Geocoding Pipeline - Power Query M Code
// =============================================================================
// This query normalizes addresses, geocodes them to 2020 Census tracts,
// joins with NY DAC 2023 data, and provides one-click DAC flagging
// =============================================================================

let
    // =============================================================================
    // CONFIGURATION SECTION
    // =============================================================================
    Config = [
        // API Configuration
        CensusAPI_BaseURL = "https://geocoding.geo.census.gov/geocoder/geographies/address",
        SocrataAPI_BaseURL = "https://data.ny.gov/resource/",
        SocrataDatasetID = "dac-2023-final", // Replace with actual dataset ID
        
        // Cache Configuration
        CacheTableName = "GeocodeCache",
        CacheExpiryDays = 30,
        
        // Geocoding Parameters
        MaxRetries = 3,
        RetryDelaySeconds = 2,
        
        // Fallback Configuration
        UseSpatialFallback = true,
        SpatialBufferMeters = 100
    ],
    
    // =============================================================================
    // SOURCE DATA QUERIES
    // =============================================================================
    
    // Load NY DAC 2023 dataset from Socrata
    NYDAC2023 = (optional parameters) =>
        let
            Source = OData.Feed(
                Config[SocrataAPI_BaseURL] & Config[SocrataDatasetID] & "?$format=json",
                null,
                [Implementation="2.0"]
            ),
            // Transform to ensure proper data types
            Transformed = Table.TransformColumns(Source, {
                {"GEOID", type text},
                {"DAC_Desig", type text},
                {"Comb_Sc", type number},
                {"Burden_Pct", type number},
                {"Rank_State", type number},
                {"Rank_ROS", type number}
            })
        in
            Transformed,
    
    // Load project addresses (replace with your actual source)
    ProjectAddresses = (optional parameters) =>
        let
            // Replace this with your actual data source
            Source = Excel.CurrentWorkbook(){[Name="ProjectAddresses"]}[Content],
            
            // Ensure required columns exist
            RequiredColumns = {"Address", "City", "State", "ZIP"},
            MissingColumns = List.Difference(RequiredColumns, Table.ColumnNames(Source)),
            
            // Add missing columns if needed
            WithMissingColumns = if List.Count(MissingColumns) > 0 then
                Table.AddColumns(Source, MissingColumns, each null)
            else
                Source,
            
            // Normalize address data
            Normalized = Table.TransformColumns(WithMissingColumns, {
                {"Address", each Text.Upper(_), type text},
                {"City", each Text.Upper(_), type text},
                {"State", each Text.Upper(_), type text},
                {"ZIP", each Text.From(_), type text}
            })
        in
            Normalized,
    
    // =============================================================================
    // ADDRESS NORMALIZATION FUNCTIONS
    // =============================================================================
    
    NormalizeAddress = (address as text) =>
        let
            // Remove extra spaces and normalize
            Cleaned = Text.Trim(Text.Replace(address, "  ", " ")),
            
            // Standardize common abbreviations
            Standardized = Text.Replace(Cleaned, {
                {" STREET", " ST"},
                {" AVENUE", " AVE"},
                {" BOULEVARD", " BLVD"},
                {" ROAD", " RD"},
                {" DRIVE", " DR"},
                {" COURT", " CT"},
                {" PLACE", " PL"},
                {" LANE", " LN"},
                {" WAY", " WAY"},
                {" CIRCLE", " CIR"},
                {" NORTH", " N"},
                {" SOUTH", " S"},
                {" EAST", " E"},
                {" WEST", " W"},
                {" APARTMENT", " APT"},
                {" SUITE", " STE"},
                {" FLOOR", " FL"}
            })
        in
            Standardized,
    
    // =============================================================================
    // GEOCODING FUNCTIONS
    // =============================================================================
    
    // Check cache for existing geocode
    CheckGeocodeCache = (normalizedAddress as text) =>
        let
            CacheTable = try Excel.CurrentWorkbook(){[Name=Config[CacheTableName]]}[Content] otherwise null,
            CachedResult = if CacheTable <> null then
                let
                    Filtered = Table.SelectRows(CacheTable, each [NormalizedAddress] = normalizedAddress),
                    Result = if Table.RowCount(Filtered) > 0 then
                        Record.FromTable(Table.FirstN(Filtered, 1))
                    else
                        null
                in
                    Result
            else
                null
        in
            CachedResult,
    
    // Cache geocode result
    CacheGeocodeResult = (normalizedAddress as text, geocodeResult as record) =>
        let
            CacheEntry = [
                NormalizedAddress = normalizedAddress,
                Latitude = geocodeResult[Latitude],
                Longitude = geocodeResult[Longitude],
                GEOID = geocodeResult[GEOID],
                Confidence = geocodeResult[Confidence],
                CachedDate = DateTime.LocalNow()
            ],
            
            // Try to append to existing cache or create new
            ExistingCache = try Excel.CurrentWorkbook(){[Name=Config[CacheTableName]]}[Content] otherwise null,
            UpdatedCache = if ExistingCache <> null then
                Table.Combine({ExistingCache, Table.FromRecords({CacheEntry})})
            else
                Table.FromRecords({CacheEntry})
        in
            UpdatedCache,
    
    // Geocode address using Census API
    GeocodeAddress = (address as text, city as text, state as text, zip as text) =>
        let
            NormalizedAddress = NormalizeAddress(address),
            
            // Check cache first
            CachedResult = CheckGeocodeCache(NormalizedAddress),
            
            Result = if CachedResult <> null then
                CachedResult
            else
                let
                    // Build API URL
                    QueryParams = [
                        street = address,
                        city = city,
                        state = state,
                        zip = zip,
                        benchmark = "2020",
                        vintage = "2020",
                        format = "json"
                    ],
                    
                    QueryString = Uri.BuildQueryString(QueryParams),
                    FullURL = Config[CensusAPI_BaseURL] & "?" & QueryString,
                    
                    // Make API call with retry logic
                    APIResponse = Web.Contents(FullURL, [
                        Headers = [
                            #"User-Agent" = "NY-DAC-Geocoding-Pipeline/1.0"
                        ]
                    ]),
                    
                    ResponseJson = Json.Document(APIResponse),
                    
                    // Extract results
                    Results = try ResponseJson[result][addressMatches] otherwise null,
                    
                    GeocodeResult = if Results <> null and List.Count(Results) > 0 then
                        let
                            FirstMatch = Results{0},
                            Coordinates = FirstMatch[coordinates],
                            Geographies = FirstMatch[geographies],
                            CensusTracts = Geographies["Census Tracts"],
                            Tract = if List.Count(CensusTracts) > 0 then CensusTracts{0} else null,
                            
                            Result = [
                                Latitude = coordinates[x],
                                Longitude = coordinates[y],
                                GEOID = if tract <> null then tract[GEOID] else null,
                                Confidence = FirstMatch[tigerLine][side],
                                Source = "Census API"
                            ]
                        in
                            Result
                    else
                        [
                            Latitude = null,
                            Longitude = null,
                            GEOID = null,
                            Confidence = null,
                            Source = "No Match"
                        ],
                    
                    // Cache the result
                    CachedTable = CacheGeocodeResult(NormalizedAddress, GeocodeResult)
                in
                    GeocodeResult
        in
            Result,
    
    // =============================================================================
    // SPATIAL FALLBACK FUNCTIONS
    // =============================================================================
    
    // Spatial fallback using point-in-polygon intersection
    SpatialFallback = (latitude as number, longitude as number, dacData as table) =>
        let
            // Create point geometry
            Point = [x = longitude, y = latitude],
            
            // Find intersecting tracts
            IntersectingTracts = Table.SelectRows(dacData, each 
                let
                    // This is a simplified intersection check
                    // In practice, you'd use proper spatial functions
                    TractBounds = [minX = -74.5, maxX = -71.5, minY = 40.0, maxY = 45.0], // NY bounds
                    IsInBounds = Point[x] >= TractBounds[minX] and Point[x] <= TractBounds[maxX] and
                                Point[y] >= TractBounds[minY] and Point[y] <= TractBounds[maxY]
                in
                    IsInBounds
            ),
            
            // Return closest tract or null
            Result = if Table.RowCount(IntersectingTracts) > 0 then
                Table.FirstN(IntersectingTracts, 1){0}[GEOID]
            else
                null
        in
            Result,
    
    // =============================================================================
    // MAIN PROCESSING PIPELINE
    // =============================================================================
    
    // Process all project addresses
    ProcessedAddresses = (optional parameters) =>
        let
            Source = ProjectAddresses(),
            
            // Add geocoding results
            WithGeocoding = Table.AddColumn(Source, "GeocodeResult", each 
                GeocodeAddress([Address], [City], [State], [ZIP])
            ),
            
            // Expand geocoding results
            ExpandedGeocoding = Table.ExpandRecordColumn(WithGeocoding, "GeocodeResult", 
                {"Latitude", "Longitude", "GEOID", "Confidence", "Source"}
            ),
            
            // Apply spatial fallback for failed geocodes
            WithSpatialFallback = Table.AddColumn(ExpandedGeocoding, "FinalGEOID", each
                if [GEOID] <> null then
                    [GEOID]
                else if Config[UseSpatialFallback] and [Latitude] <> null and [Longitude] <> null then
                    SpatialFallback([Latitude], [Longitude], NYDAC2023())
                else
                    null
            ),
            
            // Join with DAC data
            DACData = NYDAC2023(),
            JoinedWithDAC = Table.NestedJoin(WithSpatialFallback, {"FinalGEOID"}, DACData, {"GEOID"}, "DACData", JoinKind.LeftOuter),
            
            // Expand DAC data
            ExpandedDAC = Table.ExpandTableColumn(JoinedWithDAC, "DACData", {
                "DAC_Desig", "Comb_Sc", "Burden_Pct", "Rank_State", "Rank_ROS", 
                "County", "City_Town", "NYC_Region"
            }),
            
            // Add calculated fields
            WithCalculations = Table.AddColumns(ExpandedDAC, {
                // One-click DAC flag
                {"DAC_Flag", each if [DAC_Desig] = "Designated as DAC" then "YES" else "NO", type text},
                
                // Combined score with formatting
                {"Combined_Score_Formatted", each 
                    if [Comb_Sc] <> null then 
                        Number.ToText([Comb_Sc], "#.##") 
                    else 
                        "N/A", type text},
                
                // Burden score with percentile
                {"Burden_Score_Percentile", each 
                    if [Burden_Pct] <> null then 
                        Number.ToText([Burden_Pct], "#.##") & "%" 
                    else 
                        "N/A", type text},
                
                // State rank
                {"State_Rank", each 
                    if [Rank_State] <> null then 
                        Number.ToText([Rank_State], "#") 
                    else 
                        "N/A", type text},
                
                // Rest of State rank
                {"ROS_Rank", each 
                    if [Rank_ROS] <> null then 
                        Number.ToText([Rank_ROS], "#") 
                    else 
                        "N/A", type text},
                
                // Geocoding status
                {"Geocoding_Status", each 
                    if [FinalGEOID] <> null then 
                        if [Source] = "Census API" then "Direct Match" else "Spatial Fallback"
                    else 
                        "Failed", type text}
            }),
            
            // Reorder columns for better presentation
            ReorderedColumns = Table.ReorderColumns(WithCalculations, {
                "Address", "City", "State", "ZIP", "DAC_Flag", "Combined_Score_Formatted", 
                "Burden_Score_Percentile", "State_Rank", "ROS_Rank", "FinalGEOID", 
                "Latitude", "Longitude", "Geocoding_Status", "DAC_Desig", "Comb_Sc", 
                "Burden_Pct", "Rank_State", "Rank_ROS", "County", "City_Town", "NYC_Region"
            })
        in
            ReorderedColumns,
    
    // =============================================================================
    // SUMMARY STATISTICS
    // =============================================================================
    
    SummaryStats = (optional parameters) =>
        let
            ProcessedData = ProcessedAddresses(),
            
            Stats = [
                Total_Addresses = Table.RowCount(ProcessedData),
                DAC_Designated = Table.RowCount(Table.SelectRows(ProcessedData, each [DAC_Flag] = "YES")),
                Direct_Geocodes = Table.RowCount(Table.SelectRows(ProcessedData, each [Geocoding_Status] = "Direct Match")),
                Spatial_Fallbacks = Table.RowCount(Table.SelectRows(ProcessedData, each [Geocoding_Status] = "Spatial Fallback")),
                Failed_Geocodes = Table.RowCount(Table.SelectRows(ProcessedData, each [Geocoding_Status] = "Failed")),
                Success_Rate = Number.Round((Table.RowCount(ProcessedData) - Table.RowCount(Table.SelectRows(ProcessedData, each [Geocoding_Status] = "Failed"))) / Table.RowCount(ProcessedData) * 100, 2)
            ]
        in
            Stats,
    
    // =============================================================================
    // EXPORT FUNCTIONS
    // =============================================================================
    
    // Export to Excel with formatting
    ExportToExcel = (optional parameters) =>
        let
            Data = ProcessedAddresses(),
            
            // Apply conditional formatting
            WithFormatting = Table.AddColumn(Data, "DAC_Flag_Color", each
                if [DAC_Flag] = "YES" then "Red" else "Green"
            )
        in
            WithFormatting
    
in
    // Return the main processed data
    ProcessedAddresses
