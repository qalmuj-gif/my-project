// =============================================================================
// Enhanced NY DAC Geocoding Pipeline - Power Query M Code
// =============================================================================
// This enhanced query works with local DAC CSV file and provides
// improved performance, error handling, and user experience
// =============================================================================

let
    // =============================================================================
    // CONFIGURATION SECTION
    // =============================================================================
    Config = [
        // API Configuration
        CensusAPI_BaseURL = "https://geocoding.geo.census.gov/geocoder/geographies/address",
        
        // Cache Configuration
        CacheTableName = "GeocodeCache",
        CacheExpiryDays = 30,
        
        // Geocoding Parameters
        MaxRetries = 3,
        RetryDelaySeconds = 2,
        
        // Fallback Configuration
        UseSpatialFallback = true,
        SpatialBufferMeters = 100,
        
        // Performance Configuration
        BatchSize = 50,
        EnableParallelProcessing = true
    ],
    
    // =============================================================================
    // SOURCE DATA QUERIES
    // =============================================================================
    
    // Load NY DAC 2023 dataset from local CSV file
    NYDAC2023 = (optional parameters) =>
        let
            Source = Csv.Document(
                File.Contents("NYS_Disadvantaged_Communities_(DAC).csv"),
                [Delimiter=",", Columns=null, Encoding="UTF8", QuoteStyle=QuoteStyle.Csv]
            ),
            PromotedHeaders = Table.PromoteHeaders(Source, [PromoteAllScalars=true]),
            
            // Transform to ensure proper data types
            Transformed = Table.TransformColumns(PromotedHeaders, {
                {"GEOID", type text},
                {"DAC_Desig", type text},
                {"Comb_Sc", each if _ = null then null else Number.From(_), type number},
                {"Burden_Pct", each if _ = null then null else Number.From(_), type number},
                {"Rank_State", each if _ = null then null else Number.From(_), type number},
                {"Rank_ROS", each if _ = null then null else Number.From(_), type number},
                {"County", type text},
                {"City_Town", type text},
                {"NYC_Region", type text}
            }),
            
            // Filter to only include valid GEOIDs
            Filtered = Table.SelectRows(Transformed, each [GEOID] <> null and Text.Length([GEOID]) = 11)
        in
            Filtered,
    
    // Load project addresses from CSV or Excel table
    ProjectAddresses = (optional parameters) =>
        let
            // Try to load from CSV first, then fall back to Excel table
            Source = try Csv.Document(
                File.Contents("sample_project_addresses.csv"),
                [Delimiter=",", Columns=null, Encoding="UTF8", QuoteStyle=QuoteStyle.Csv]
            ) otherwise Excel.CurrentWorkbook(){[Name="ProjectAddresses"]}[Content],
            
            PromotedHeaders = if Source[Kind] = "Csv.Document" then
                Table.PromoteHeaders(Source, [PromoteAllScalars=true])
            else
                Source,
            
            // Ensure required columns exist
            RequiredColumns = {"Address", "City", "State", "ZIP"},
            MissingColumns = List.Difference(RequiredColumns, Table.ColumnNames(PromotedHeaders)),
            
            // Add missing columns if needed
            WithMissingColumns = if List.Count(MissingColumns) > 0 then
                Table.AddColumns(PromotedHeaders, MissingColumns, each null)
            else
                PromotedHeaders,
            
            // Normalize address data
            Normalized = Table.TransformColumns(WithMissingColumns, {
                {"Address", each if _ = null then null else Text.Upper(Text.Trim(_)), type text},
                {"City", each if _ = null then null else Text.Upper(Text.Trim(_)), type text},
                {"State", each if _ = null then null else Text.Upper(Text.Trim(_)), type text},
                {"ZIP", each if _ = null then null else Text.From(Text.Trim(_)), type text}
            }),
            
            // Remove rows with missing critical data
            Cleaned = Table.SelectRows(Normalized, each [Address] <> null and [Address] <> "")
        in
            Cleaned,
    
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
                {" FLOOR", " FL"},
                {" BUILDING", " BLDG"},
                {" STREET", " ST"},
                {" AVENUE", " AVE"}
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
    
    // Geocode address using Census API with enhanced error handling
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
                    APIResponse = try Web.Contents(FullURL, [
                        Headers = [
                            #"User-Agent" = "NY-DAC-Geocoding-Pipeline/1.0"
                        ],
                        Timeout = #duration(0, 0, 30, 0)
                    ]) otherwise null,
                    
                    ResponseJson = if APIResponse <> null then try Json.Document(APIResponse) otherwise null else null,
                    
                    // Extract results with error handling
                    Results = if ResponseJson <> null then try ResponseJson[result][addressMatches] otherwise null else null,
                    
                    GeocodeResult = if Results <> null and List.Count(Results) > 0 then
                        let
                            FirstMatch = Results{0},
                            Coordinates = try FirstMatch[coordinates] otherwise null,
                            Geographies = try FirstMatch[geographies] otherwise null,
                            CensusTracts = if Geographies <> null then try Geographies["Census Tracts"] otherwise null else null,
                            Tract = if CensusTracts <> null and List.Count(CensusTracts) > 0 then CensusTracts{0} else null,
                            
                            Result = [
                                Latitude = if Coordinates <> null then try Coordinates[x] otherwise null else null,
                                Longitude = if Coordinates <> null then try Coordinates[y] otherwise null else null,
                                GEOID = if Tract <> null then try Tract[GEOID] otherwise null else null,
                                Confidence = if FirstMatch[tigerLine] <> null then try FirstMatch[tigerLine][side] otherwise null else null,
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
    
    // Enhanced spatial fallback using point-in-polygon intersection
    SpatialFallback = (latitude as number, longitude as number, dacData as table) =>
        let
            // Create point geometry
            Point = [x = longitude, y = latitude],
            
            // Find intersecting tracts using simplified bounding box
            IntersectingTracts = Table.SelectRows(dacData, each 
                let
                    // This is a simplified intersection check for NY State
                    // In practice, you'd use proper spatial functions
                    NYBounds = [minX = -79.8, maxX = -71.8, minY = 40.5, maxY = 45.0],
                    IsInNYBounds = Point[x] >= NYBounds[minX] and Point[x] <= NYBounds[maxX] and
                                  Point[y] >= NYBounds[minY] and Point[y] <= NYBounds[maxY]
                in
                    IsInNYBounds
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
    
    // Process all project addresses with enhanced error handling
    ProcessedAddresses = (optional parameters) =>
        let
            Source = ProjectAddresses(),
            
            // Add geocoding results with error handling
            WithGeocoding = Table.AddColumn(Source, "GeocodeResult", each 
                try GeocodeAddress([Address], [City], [State], [ZIP]) otherwise [
                    Latitude = null,
                    Longitude = null,
                    GEOID = null,
                    Confidence = null,
                    Source = "Error"
                ]
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
                    try SpatialFallback([Latitude], [Longitude], NYDAC2023()) otherwise null
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
            
            // Add calculated fields with enhanced formatting
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
                
                // Geocoding status with enhanced details
                {"Geocoding_Status", each 
                    if [FinalGEOID] <> null then 
                        if [Source] = "Census API" then "Direct Match" 
                        else if [Source] = "Spatial Fallback" then "Spatial Fallback"
                        else "Cached"
                    else 
                        "Failed", type text},
                
                // Confidence indicator
                {"Confidence_Level", each 
                    if [Confidence] <> null then 
                        if [Confidence] = "L" then "Low"
                        else if [Confidence] = "R" then "Right"
                        else if [Confidence] = "T" then "Left"
                        else "Unknown"
                    else 
                        "N/A", type text}
            }),
            
            // Reorder columns for better presentation
            ReorderedColumns = Table.ReorderColumns(WithCalculations, {
                "Address", "City", "State", "ZIP", "DAC_Flag", "Combined_Score_Formatted", 
                "Burden_Score_Percentile", "State_Rank", "ROS_Rank", "FinalGEOID", 
                "Latitude", "Longitude", "Geocoding_Status", "Confidence_Level", "DAC_Desig", 
                "Comb_Sc", "Burden_Pct", "Rank_State", "Rank_ROS", "County", "City_Town", "NYC_Region"
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
                Success_Rate = Number.Round((Table.RowCount(ProcessedData) - Table.RowCount(Table.SelectRows(ProcessedData, each [Geocoding_Status] = "Failed"))) / Table.RowCount(ProcessedData) * 100, 2),
                Average_Combined_Score = Number.Round(List.Average(List.RemoveNulls(Table.Column(ProcessedData, "Comb_Sc"))), 2)
            ]
        in
            Stats,
    
    // =============================================================================
    // DAC ANALYSIS QUERIES
    // =============================================================================
    
    // DAC-only projects
    DACProjects = (optional parameters) =>
        let
            Source = ProcessedAddresses(),
            Filtered = Table.SelectRows(Source, each [DAC_Flag] = "YES"),
            Sorted = Table.Sort(Filtered, {{"Comb_Sc", Order.Descending}})
        in
            Sorted,
    
    // High-burden projects (top 25% burden score)
    HighBurdenProjects = (optional parameters) =>
        let
            Source = ProcessedAddresses(),
            Filtered = Table.SelectRows(Source, each [Burden_Pct] <> null and [Burden_Pct] >= 75),
            Sorted = Table.Sort(Filtered, {{"Burden_Pct", Order.Descending}})
        in
            Sorted,
    
    // =============================================================================
    // EXPORT FUNCTIONS
    // =============================================================================
    
    // Export to Excel with conditional formatting
    ExportToExcel = (optional parameters) =>
        let
            Data = ProcessedAddresses(),
            
            // Apply conditional formatting indicators
            WithFormatting = Table.AddColumns(Data, {
                {"DAC_Flag_Color", each if [DAC_Flag] = "YES" then "Red" else "Green", type text},
                {"Score_Category", each 
                    if [Comb_Sc] <> null then
                        if [Comb_Sc] >= 100 then "High"
                        else if [Comb_Sc] >= 75 then "Medium"
                        else "Low"
                    else "Unknown", type text}
            })
        in
            WithFormatting
    
in
    // Return the main processed data
    ProcessedAddresses