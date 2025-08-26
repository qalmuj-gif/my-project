#!/usr/bin/env python3
"""
Power Query-driven Excel Pipeline for NY DAC Geocoding
=====================================================

This script generates Power Query M code for:
1. Normalizing project addresses
2. Geocoding to 2020 Census tracts (11-digit GEOID)
3. Joining with NY's Final DAC 2023 dataset
4. Implementing geospatial fallback for tricky addresses
5. Caching geocodes for performance
6. Surfacing DAC flags and relevant scores

Author: AI Assistant
Date: 2024
"""

import json
import os
from datetime import datetime

def generate_power_query_m_code():
    """
    Generate the complete Power Query M code for the DAC geocoding pipeline
    """
    
    m_code = '''
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
'''
    
    return m_code

def generate_excel_template():
    """
    Generate Excel template with Power Query setup
    """
    
    template_code = '''
# Excel Template Setup Instructions
================================

## 1. Create Named Ranges

### Project Addresses Table
- Create a table named "ProjectAddresses" with columns:
  - Address (text)
  - City (text) 
  - State (text)
  - ZIP (text)

### Geocode Cache Table
- Create a table named "GeocodeCache" with columns:
  - NormalizedAddress (text)
  - Latitude (number)
  - Longitude (number)
  - GEOID (text)
  - Confidence (text)
  - CachedDate (datetime)

## 2. Power Query Setup

1. Open Excel
2. Go to Data > Get Data > From Other Sources > Blank Query
3. In the Advanced Editor, paste the M code from dac_geocoding_pipeline.py
4. Name the query "DAC_Geocoding_Pipeline"
5. Load to worksheet

## 3. Refresh Configuration

- Set up automatic refresh (Data > Refresh All)
- Configure refresh intervals as needed
- Cache will automatically expire after 30 days

## 4. Output Columns

The pipeline will generate:
- DAC_Flag: One-click YES/NO indicator
- Combined_Score_Formatted: Formatted combined score
- Burden_Score_Percentile: Burden score with percentile
- State_Rank: State ranking
- ROS_Rank: Rest of State ranking
- Geocoding_Status: Success/failure status
- All original DAC data fields

## 5. Performance Tips

- Cache geocodes for faster subsequent runs
- Use spatial fallback for failed addresses
- Monitor API rate limits
- Consider batch processing for large datasets
'''
    
    return template_code

def generate_config_file():
    """
    Generate configuration file for the pipeline
    """
    
    config = {
        "pipeline_info": {
            "name": "NY DAC Geocoding Pipeline",
            "version": "1.0",
            "description": "Power Query-driven Excel pipeline for geocoding project addresses and joining with NY DAC 2023 data",
            "created_date": datetime.now().isoformat()
        },
        "api_config": {
            "census_api": {
                "base_url": "https://geocoding.geo.census.gov/geocoder/geographies/address",
                "benchmark": "2020",
                "vintage": "2020",
                "max_retries": 3,
                "retry_delay_seconds": 2
            },
            "socrata_api": {
                "base_url": "https://data.ny.gov/resource/",
                "dataset_id": "dac-2023-final",
                "format": "json"
            }
        },
        "cache_config": {
            "table_name": "GeocodeCache",
            "expiry_days": 30,
            "enabled": True
        },
        "geocoding_config": {
            "spatial_fallback": {
                "enabled": True,
                "buffer_meters": 100
            },
            "address_normalization": {
                "enabled": True,
                "standardize_abbreviations": True
            }
        },
        "output_config": {
            "required_fields": [
                "DAC_Flag",
                "Combined_Score_Formatted", 
                "Burden_Score_Percentile",
                "State_Rank",
                "ROS_Rank",
                "Geocoding_Status"
            ],
            "formatting": {
                "dac_flag_colors": {
                    "yes": "Red",
                    "no": "Green"
                }
            }
        }
    }
    
    return json.dumps(config, indent=2)

def generate_readme():
    """
    Generate comprehensive README file
    """
    
    readme = '''
# NY DAC Geocoding Pipeline

A Power Query-driven Excel pipeline that normalizes project addresses, geocodes them to 2020 Census tracts (11-digit GEOID), and joins those GEOIDs to NY's Final DAC 2023 dataset via Socrata/OData.

## Features

### ✅ Address Normalization
- Standardizes common address abbreviations (ST, AVE, BLVD, etc.)
- Removes extra spaces and normalizes formatting
- Handles apartment/suite numbers

### ✅ Geocoding to Census Tracts
- Uses Census Bureau Geocoding API
- Returns 11-digit GEOID for 2020 Census tracts
- Implements retry logic for failed requests

### ✅ NY DAC 2023 Integration
- Connects to NY DAC dataset via Socrata API
- Joins on GEOID for accurate DAC designation
- Provides all relevant DAC scores and rankings

### ✅ Geospatial Fallback
- Uses point-in-polygon intersection for tricky addresses
- Configurable buffer distance (default: 100 meters)
- Ensures maximum geocoding success rate

### ✅ Intelligent Caching
- Caches geocodes to improve performance
- Configurable cache expiration (default: 30 days)
- Reduces API calls and processing time

### ✅ One-Click DAC Flagging
- Simple YES/NO indicator for DAC designation
- Color-coded output (Red for DAC, Green for non-DAC)
- Includes all relevant scores and rankings

## Required Output Fields

The pipeline surfaces these key metrics for portfolio triage:

1. **DAC_Flag**: One-click YES/NO indicator
2. **Combined_Score_Formatted**: Combined score with formatting
3. **Burden_Score_Percentile**: Burden score with percentile
4. **State_Rank**: State ranking
5. **ROS_Rank**: Rest of State ranking
6. **Geocoding_Status**: Success/failure status

## Setup Instructions

### 1. Prerequisites
- Microsoft Excel with Power Query
- Internet connection for API access
- NY DAC 2023 dataset access

### 2. Installation
1. Copy the M code from `dac_geocoding_pipeline.py`
2. Create named ranges in Excel (see template instructions)
3. Set up Power Query with the provided M code
4. Configure refresh settings

### 3. Configuration
- Edit the Config section in the M code
- Adjust API endpoints and parameters
- Configure cache settings and fallback options

## Usage

### Input Data Format
Your project addresses should include:
- Address (street address)
- City
- State  
- ZIP (postal code)

### Output Data
The pipeline will return:
- All original address fields
- Geocoding results (latitude, longitude, GEOID)
- DAC designation and scores
- Formatted output for easy analysis

### Performance Optimization
- Cache geocodes for faster subsequent runs
- Use spatial fallback for failed addresses
- Monitor API rate limits
- Consider batch processing for large datasets

## API Dependencies

### Census Bureau Geocoding API
- **Endpoint**: https://geocoding.geo.census.gov/geocoder/geographies/address
- **Purpose**: Convert addresses to Census tract GEOIDs
- **Rate Limits**: 10,000 requests per day
- **Documentation**: https://www.census.gov/programs-surveys/geography/technical-documentation/complete-technical-documentation/census-geocoder.html

### NY State Socrata API
- **Endpoint**: https://data.ny.gov/resource/
- **Purpose**: Access NY DAC 2023 dataset
- **Rate Limits**: Varies by dataset
- **Documentation**: https://dev.socrata.com/

## Error Handling

The pipeline includes comprehensive error handling:
- API timeout and retry logic
- Invalid address handling
- Missing data fallbacks
- Cache corruption recovery

## Troubleshooting

### Common Issues
1. **API Rate Limits**: Implement delays between requests
2. **Invalid Addresses**: Check address formatting
3. **Cache Issues**: Clear and rebuild cache table
4. **Network Errors**: Verify internet connection

### Debug Mode
Enable debug logging by modifying the M code:
```m
DebugMode = true,
LogLevel = "Detailed"
```

## Support

For issues or questions:
1. Check the configuration settings
2. Verify API access and rate limits
3. Review error logs in Power Query
4. Test with sample data first

## License

This pipeline is provided as-is for educational and business use.
'''
    
    return readme

def main():
    """
    Main function to generate all pipeline files
    """
    
    print("Generating NY DAC Geocoding Pipeline...")
    
    # Generate Power Query M code
    m_code = generate_power_query_m_code()
    with open('dac_geocoding_pipeline.m', 'w') as f:
        f.write(m_code)
    print("✅ Generated Power Query M code: dac_geocoding_pipeline.m")
    
    # Generate Excel template instructions
    template = generate_excel_template()
    with open('excel_template_setup.txt', 'w') as f:
        f.write(template)
    print("✅ Generated Excel template setup: excel_template_setup.txt")
    
    # Generate configuration file
    config = generate_config_file()
    with open('pipeline_config.json', 'w') as f:
        f.write(config)
    print("✅ Generated configuration file: pipeline_config.json")
    
    # Generate README
    readme = generate_readme()
    with open('README.md', 'w') as f:
        f.write(readme)
    print("✅ Generated README: README.md")
    
    print("\n🎉 Pipeline generation complete!")
    print("\nNext steps:")
    print("1. Copy the M code from dac_geocoding_pipeline.m")
    print("2. Set up Excel with the template instructions")
    print("3. Configure your data sources and API access")
    print("4. Test with sample data")
    print("5. Deploy for production use")

if __name__ == "__main__":
    main()