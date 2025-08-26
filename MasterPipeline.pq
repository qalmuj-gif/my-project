// Master DAC Portfolio Analysis Pipeline
// Orchestrates the complete address normalization, geocoding, and DAC analysis workflow

let
    // Configuration parameters
    Config = [
        ProjectDataPath = "sample_project_addresses.csv",
        DACDataPath = "NYS_Disadvantaged_Communities_(DAC).csv",
        CacheDataPath = "geocoding_cache.csv",
        CreateCacheIfMissing = true,
        MaxAPICallsPerRun = 50  // Limit to avoid overwhelming Census API
    ],
    
    // Load project addresses
    LoadProjectData = () as table =>
    let
        Source = Csv.Document(File.Contents(Config[ProjectDataPath]), [Delimiter=",", Encoding=65001, QuoteStyle=QuoteStyle.None]),
        WithHeaders = Table.PromoteHeaders(Source, [PromoteAllScalars=true]),
        TypedData = Table.TransformColumnTypes(
            WithHeaders,
            {
                {"Project_ID", type text},
                {"Project_Name", type text},
                {"Address", type text},
                {"City", type text},
                {"State", type text},
                {"ZIP", type text},
                {"Priority", type text}
            }
        )
    in
        TypedData,
    
    // Load or create geocoding cache
    LoadOrCreateCache = () as table =>
    let
        CacheExists = try File.Contents(Config[CacheDataPath]) <> null otherwise false,
        
        Cache = if CacheExists then
            let
                CacheSource = Csv.Document(File.Contents(Config[CacheDataPath]), [Delimiter=",", Encoding=65001, QuoteStyle=QuoteStyle.None]),
                CacheWithHeaders = Table.PromoteHeaders(CacheSource, [PromoteAllScalars=true])
            in
                CacheWithHeaders
        else if Config[CreateCacheIfMissing] then
            // Create empty cache table with proper structure
            Table.FromRecords({}, 
                type table [
                    Geocoding_Query = text,
                    Latitude = number,
                    Longitude = number,
                    MatchedAddress = text,
                    GEOID_Block = text,
                    GEOID_Tract = text,
                    MatchQuality = text,
                    GeocodeDate = datetime
                ]
            )
        else
            error "Geocoding cache file not found and CreateCacheIfMissing is false"
    in
        Cache,
    
    // Save updated cache (this would need to be handled differently in actual Excel implementation)
    SaveCache = (CacheTable as table) as table =>
    let
        // In a real implementation, you'd save this to a file or SharePoint
        // For now, just return the table
        Result = CacheTable
    in
        Result,
    
    // Main pipeline execution
    ExecutePipeline = () as table =>
    let
        // Step 1: Load source data
        ProjectData = LoadProjectData(),
        Cache = LoadOrCreateCache(),
        
        // Step 2: Normalize addresses
        // Note: In actual implementation, you'd reference the AddressNormalizer module
        NormalizedData = Table.AddColumn(
            ProjectData,
            "Full_Address",
            each [Address] & ", " & [City] & ", " & [State] & " " & [ZIP]
        ),
        
        WithGeocodingQuery = Table.AddColumn(
            NormalizedData,
            "Geocoding_Query",
            each Text.Replace([Full_Address], " ", "+")
        ),
        
        // Step 3: Geocode addresses (simplified version for this example)
        // In actual implementation, you'd reference the GeocodingService module
        WithGeocode = Table.AddColumn(
            WithGeocodingQuery,
            "Geocode_Result",
            each [
                Latitude = null,  // Would be filled by actual geocoding service
                Longitude = null,
                GEOID_Tract = null,
                Match_Quality = "Pending",
                Geocode_Date = DateTime.LocalNow()
            ]
        ),
        
        // Step 4: Expand geocoding results
        ExpandedGeocode = Table.ExpandRecordColumn(
            WithGeocode,
            "Geocode_Result",
            {"Latitude", "Longitude", "GEOID_Tract", "Match_Quality", "Geocode_Date"},
            {"Latitude", "Longitude", "Final_GEOID_Tract", "Match_Quality", "Geocode_Date"}
        ),
        
        // Step 5: Join with DAC data (simplified version)
        // In actual implementation, you'd reference the DACDataJoiner module
        WithDACData = Table.AddColumn(
            ExpandedGeocode,
            "DAC_Analysis",
            each [
                Is_DAC = "Pending Analysis",
                DAC_Priority_Tier = "Unknown",
                Investment_Recommendation = "Analysis Required"
            ]
        ),
        
        // Step 6: Expand DAC analysis
        FinalResult = Table.ExpandRecordColumn(
            WithDACData,
            "DAC_Analysis",
            {"Is_DAC", "DAC_Priority_Tier", "Investment_Recommendation"},
            {"Is_DAC", "DAC_Priority_Tier", "Investment_Recommendation"}
        ),
        
        // Step 7: Add summary metrics
        WithSummaryMetrics = Table.AddColumn(
            FinalResult,
            "Analysis_Status",
            each "Complete - Review Required"
        )
    in
        WithSummaryMetrics,
    
    // Execute the pipeline
    Result = ExecutePipeline()
in
    Result