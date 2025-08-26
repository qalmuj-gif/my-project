// DAC Data Joiner Module
// Joins geocoded addresses to NY Final DAC 2023 dataset

let
    // Function to load and prepare DAC dataset
    LoadDACData = (DACFilePath as text) as table =>
    let
        // Load DAC CSV data
        DACSource = Csv.Document(File.Contents(DACFilePath), [Delimiter=",", Columns=61, Encoding=65001, QuoteStyle=QuoteStyle.None]),
        
        // Promote headers
        DACWithHeaders = Table.PromoteHeaders(DACSource, [PromoteAllScalars=true]),
        
        // Clean and type the key columns we need
        DACTyped = Table.TransformColumnTypes(
            DACWithHeaders,
            {
                {"GEOID", type text},
                {"DAC_Desig", type text},
                {"County", type text},
                {"City_Town", type text},
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
        
        // Add simplified DAC flag
        WithDACFlag = Table.AddColumn(
            DACTyped,
            "Is_DAC",
            each if [DAC_Desig] = "Designated as DAC" then "Yes" else "No"
        ),
        
        // Add priority scoring based on DAC status and scores
        WithPriorityScore = Table.AddColumn(
            WithDACFlag,
            "DAC_Priority_Score",
            each if [Is_DAC] = "Yes" then
                // For DAC areas, use combined score (higher is worse/higher priority)
                if [Comb_Sc] <> null then [Comb_Sc] else 50
            else
                // For non-DAC areas, use much lower priority score
                if [Comb_Sc] <> null then [Comb_Sc] * 0.3 else 15
        ),
        
        // Add priority tier
        WithPriorityTier = Table.AddColumn(
            WithPriorityScore,
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
        WithPriorityTier,
    
    // Function to join project data with DAC data
    JoinProjectsWithDAC = (ProjectTable as table, DACTable as table) as table =>
    let
        // Perform left join on GEOID_Tract
        JoinedData = Table.NestedJoin(
            ProjectTable,
            {"Final_GEOID_Tract"},
            DACTable,
            {"GEOID"},
            "DACData",
            JoinKind.LeftOuter
        ),
        
        // Expand key DAC columns
        ExpandedDAC = Table.ExpandTableColumn(
            JoinedData,
            "DACData",
            {
                "DAC_Desig", "County", "City_Town", "Is_DAC", 
                "Rank_State", "Rank_NYC", "Rank_ROS",
                "Comb_Sc", "Burden_Pct", "Vulner_Pct", "Burden_Sc", "Vulner_Sc",
                "DAC_Priority_Score", "DAC_Priority_Tier"
            },
            {
                "DAC_Designation", "DAC_County", "DAC_City_Town", "Is_DAC",
                "DAC_Rank_State", "DAC_Rank_NYC", "DAC_Rank_ROS", 
                "DAC_Combined_Score", "DAC_Burden_Percentile", "DAC_Vulnerability_Percentile",
                "DAC_Burden_Score", "DAC_Vulnerability_Score",
                "DAC_Priority_Score", "DAC_Priority_Tier"
            }
        ),
        
        // Add data quality flags
        WithQualityFlags = Table.AddColumn(
            ExpandedDAC,
            "Data_Quality_Flag",
            each if [Final_GEOID_Tract] = null then "No Census Tract"
                else if [Is_DAC] = null then "No DAC Data"
                else if [Match_Quality] = "Not Found" then "Poor Geocoding"
                else if [Fallback_Method] = "Point-in-Polygon" then "Fallback Geocoding"
                else "Good"
        ),
        
        // Add investment recommendation
        WithRecommendation = Table.AddColumn(
            WithQualityFlags,
            "Investment_Recommendation",
            each if [Data_Quality_Flag] <> "Good" and [Data_Quality_Flag] <> "Fallback Geocoding" then "Data Review Needed"
                else if [Is_DAC] = "Yes" then
                    if [DAC_Priority_Tier] = "Critical" then "Immediate Priority - Critical DAC"
                    else if [DAC_Priority_Tier] = "High" then "High Priority - DAC Community"
                    else "Medium Priority - DAC Community"
                else if [DAC_Combined_Score] <> null and [DAC_Combined_Score] > 50 then "Consider - Moderate Need"
                else "Standard Priority"
        )
    in
        WithRecommendation,
    
    // Main function that orchestrates the DAC joining process
    MainDACJoiner = (ProjectTable as table, DACFilePath as text) as table =>
    let
        DACData = LoadDACData(DACFilePath),
        Result = JoinProjectsWithDAC(ProjectTable, DACData)
    in
        Result
in
    MainDACJoiner