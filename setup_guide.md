# NY DAC Geocoding Pipeline - Setup Guide

## Overview

This Power Query-driven Excel pipeline provides a complete solution for:
1. **Normalizing project addresses** with intelligent abbreviation handling
2. **Geocoding to 2020 Census tracts** (11-digit GEOID) using Census Bureau API
3. **Joining with NY DAC 2023 data** for accurate designation and scoring
4. **Geospatial fallback** for tricky addresses using point-in-polygon intersection
5. **Intelligent caching** to keep processing fast and reduce API calls
6. **One-click DAC flagging** with all relevant scores for portfolio triage

## Quick Start

### Step 1: Prepare Your Data

1. **Project Addresses**: Create a CSV file or Excel table with columns:
   - `Address` (street address)
   - `City` 
   - `State`
   - `ZIP` (postal code)

2. **DAC Data**: The pipeline uses your existing `NYS_Disadvantaged_Communities_(DAC).csv` file

### Step 2: Set Up Excel

1. Open Excel and create a new workbook
2. Go to **Data** > **Get Data** > **From Other Sources** > **Blank Query**
3. In the **Advanced Editor**, paste the M code from `enhanced_dac_pipeline.m`
4. Name the query "DAC_Geocoding_Pipeline"
5. Click **Done** and **Load To** > **Table**

### Step 3: Configure Data Sources

The pipeline automatically detects your data sources:
- **DAC Data**: Uses `NYS_Disadvantaged_Communities_(DAC).csv` in the same folder
- **Project Addresses**: Uses `sample_project_addresses.csv` or Excel table named "ProjectAddresses"

### Step 4: Run the Pipeline

1. Click **Refresh All** in the Data tab
2. The pipeline will:
   - Normalize your addresses
   - Geocode them to Census tracts
   - Join with DAC data
   - Apply spatial fallback for failed geocodes
   - Cache results for future use

## Output Fields

The pipeline generates these key fields for portfolio triage:

| Field | Description | Example |
|-------|-------------|---------|
| `DAC_Flag` | One-click YES/NO indicator | "YES" or "NO" |
| `Combined_Score_Formatted` | Combined score with formatting | "95.03" |
| `Burden_Score_Percentile` | Burden score with percentile | "29.86%" |
| `State_Rank` | State ranking | "77" |
| `ROS_Rank` | Rest of State ranking | "0" |
| `Geocoding_Status` | Success/failure status | "Direct Match" |
| `Confidence_Level` | Geocoding confidence | "Right", "Left", "Low" |

## Advanced Features

### Address Normalization

The pipeline automatically standardizes addresses:
- **Abbreviations**: "STREET" → "ST", "AVENUE" → "AVE", etc.
- **Spacing**: Removes extra spaces and normalizes formatting
- **Case**: Converts to uppercase for consistency

### Geocoding with Fallback

1. **Primary**: Census Bureau Geocoding API
2. **Cache**: Checks local cache first for speed
3. **Spatial Fallback**: Uses point-in-polygon intersection for failed addresses
4. **Error Handling**: Comprehensive error handling with retry logic

### Intelligent Caching

- **Automatic**: Caches all geocoding results
- **Expiration**: 30-day cache expiration (configurable)
- **Performance**: Dramatically reduces API calls and processing time

## Configuration Options

Edit the `Config` section in the M code to customize:

```m
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
]
```

## Performance Optimization

### For Large Datasets

1. **Batch Processing**: Process addresses in batches of 50-100
2. **Cache Management**: Monitor cache size and clear old entries
3. **API Limits**: Census API has 10,000 requests/day limit
4. **Refresh Strategy**: Use incremental refresh for new addresses only

### Best Practices

1. **Address Quality**: Ensure addresses are complete and accurate
2. **ZIP Codes**: Include ZIP codes for better geocoding accuracy
3. **Regular Updates**: Refresh data regularly to capture new DAC designations
4. **Error Monitoring**: Review failed geocodes and address quality issues

## Troubleshooting

### Common Issues

1. **API Rate Limits**
   - Solution: Implement delays between requests
   - Monitor: Check API response headers for rate limit info

2. **Invalid Addresses**
   - Solution: Review and clean address data
   - Check: Ensure ZIP codes match city/state combinations

3. **Cache Issues**
   - Solution: Clear and rebuild cache table
   - Location: Excel table named "GeocodeCache"

4. **Network Errors**
   - Solution: Check internet connection
   - Retry: Pipeline includes automatic retry logic

### Debug Mode

Enable detailed logging by modifying the M code:

```m
DebugMode = true,
LogLevel = "Detailed"
```

## Sample Output

Here's what the pipeline produces:

| Address | City | State | ZIP | DAC_Flag | Combined_Score | Burden_Score | State_Rank | Geocoding_Status |
|---------|------|-------|-----|----------|----------------|--------------|------------|------------------|
| 123 MAIN ST | ALBANY | NY | 12207 | YES | 95.03 | 29.86% | 77 | Direct Match |
| 456 BROADWAY | NYC | NY | 10001 | YES | 92.60 | 69.17% | 73 | Direct Match |
| 789 ELM AVE | BUFFALO | NY | 14201 | NO | 45.20 | 12.50% | 25 | Direct Match |

## API Dependencies

### Census Bureau Geocoding API
- **Endpoint**: https://geocoding.geo.census.gov/geocoder/geographies/address
- **Rate Limit**: 10,000 requests per day
- **Documentation**: https://www.census.gov/programs-surveys/geography/technical-documentation/complete-technical-documentation/census-geocoder.html

### Local DAC Data
- **Source**: `NYS_Disadvantaged_Communities_(DAC).csv`
- **Fields**: GEOID, DAC_Desig, Comb_Sc, Burden_Pct, Rank_State, Rank_ROS
- **Format**: CSV with 11-digit GEOID as primary key

## Support and Maintenance

### Regular Tasks

1. **Cache Management**: Clear expired cache entries monthly
2. **Data Updates**: Refresh DAC data when new designations are released
3. **Performance Monitoring**: Track geocoding success rates
4. **Error Review**: Analyze failed geocodes for data quality issues

### Monitoring Metrics

- **Geocoding Success Rate**: Target >95%
- **Cache Hit Rate**: Target >80% for repeat addresses
- **API Usage**: Monitor daily request counts
- **Processing Time**: Track end-to-end pipeline performance

## Next Steps

1. **Test with Sample Data**: Use the provided sample addresses
2. **Customize Configuration**: Adjust settings for your specific needs
3. **Scale for Production**: Implement batch processing for large datasets
4. **Integrate with Workflows**: Connect to existing portfolio management systems

## Files Included

- `enhanced_dac_pipeline.m`: Main Power Query M code
- `sample_project_addresses.csv`: Sample address data
- `NYS_Disadvantaged_Communities_(DAC).csv`: NY DAC 2023 dataset
- `setup_guide.md`: This comprehensive setup guide
- `pipeline_config.json`: Configuration file
- `README.md`: Overview documentation

---

**Ready to get started?** Follow the Quick Start steps above to begin geocoding your project addresses and identifying DAC designations for portfolio triage.