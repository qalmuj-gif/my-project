# DAC Portfolio Analysis Pipeline - Excel Implementation Guide

## Overview
This Power Query-driven Excel pipeline normalizes project addresses, geocodes them to 2020 Census tracts, and joins to NY's Final DAC 2023 dataset to provide comprehensive disadvantaged community analysis for portfolio triage.

## Features
- ✅ Address normalization and standardization
- ✅ Census geocoding with 11-digit GEOID tract identification
- ✅ Geocoding cache for performance optimization
- ✅ Geospatial fallback using point-in-polygon intersects
- ✅ NY DAC 2023 dataset integration via local CSV
- ✅ One-click DAC flag and priority scoring
- ✅ Investment recommendation engine
- ✅ Data quality assessment

## Files Included
1. `Complete_DAC_Pipeline.pq` - Master Power Query M code
2. `sample_project_addresses.csv` - Sample project data
3. `NYS_Disadvantaged_Communities_(DAC).csv` - NY DAC 2023 dataset
4. `Excel_Setup_Instructions.md` - Detailed setup guide

## Quick Setup Instructions

### Step 1: Prepare Your Data Files
1. Place your project addresses CSV in a known location
2. Ensure the NY DAC dataset CSV is accessible
3. Create an empty `geocoding_cache.csv` file (optional - will be auto-created)

### Step 2: Set Up Excel Workbook
1. Open Excel and create a new workbook
2. Go to **Data** > **Get Data** > **Blank Query**
3. In the Power Query Editor, go to **Home** > **Advanced Editor**
4. Replace the default code with the contents of `Complete_DAC_Pipeline.pq`
5. Update the file paths in the `Config` section:
   ```m
   Config = [
       ProjectDataPath = "C:\YourPath\sample_project_addresses.csv",
       DACDataPath = "C:\YourPath\NYS_Disadvantaged_Communities_(DAC).csv",
       CacheDataPath = "C:\YourPath\geocoding_cache.csv",
       // ... other settings
   ],
   ```

### Step 3: Configure and Run
1. Click **Done** to close the Advanced Editor
2. Click **Close & Load** to execute the pipeline
3. The results will appear in a new worksheet

## Expected Output Columns

| Column | Description |
|--------|-------------|
| `Project_ID` | Original project identifier |
| `Project_Name` | Project name/description |
| `Priority` | Original project priority |
| `Address`, `City`, `State`, `ZIP` | Original address components |
| `Full_Address` | Normalized full address |
| `Matched_Address` | Geocoder-matched address |
| `Latitude`, `Longitude` | Geocoded coordinates |
| `Final_GEOID_Tract` | 11-digit Census tract GEOID |
| `Is_DAC` | DAC designation (Yes/No) |
| `DAC_Priority_Tier` | Critical/High/Medium/Standard/Low |
| `Investment_Recommendation` | Strategic recommendation |
| `DAC_Combined_Score` | NY DAC combined environmental/social score |
| `DAC_Burden_Percentile` | Environmental burden percentile |
| `DAC_Vulnerability_Percentile` | Social vulnerability percentile |
| `DAC_Rank_State` | Statewide DAC ranking |
| `DAC_Rank_ROS` | Rest-of-State DAC ranking |
| `DAC_County`, `DAC_City_Town` | Census geography |
| `REDC_Region` | Regional Economic Development Council region |
| `Data_Quality_Flag` | Data quality assessment |
| `Match_Quality` | Geocoding match quality |
| `Analysis_Summary` | Comprehensive analysis summary |

## Investment Recommendation Logic

The pipeline provides strategic recommendations based on DAC status and scoring:

### DAC Communities (Is_DAC = "Yes")
- **IMMEDIATE PRIORITY - Critical DAC Community**: Combined Score ≥ 90
- **HIGH PRIORITY - DAC Community**: Combined Score ≥ 75
- **MEDIUM PRIORITY - DAC Community**: Combined Score ≥ 60
- **STANDARD PRIORITY - DAC Community**: Combined Score < 60

### Non-DAC Areas (Is_DAC = "No")
- **CONSIDER - Moderate Environmental/Social Need**: Combined Score > 50
- **STANDARD PRIORITY - Non-DAC Area**: Combined Score ≤ 50

### Data Quality Issues
- **DATA REVIEW REQUIRED**: Missing geocoding, Census tract, or DAC data

## Geocoding and Caching

### API Usage
- Uses US Census Geocoding Services (free, no API key required)
- Respects rate limits with built-in delays
- Automatically retries failed requests

### Caching System
- Stores successful geocodes in `geocoding_cache.csv`
- Dramatically improves performance on subsequent runs
- Cache format: Geocoding_Query, Latitude, Longitude, GEOID_Tract, etc.

### Geospatial Fallback
- For addresses that don't geocode directly
- Uses point-in-polygon intersection with Census tract boundaries
- Provides backup GEOID identification

## Dashboard Creation

### Summary Metrics
Create PivotTables or summary tables to show:
- Total projects by DAC status
- Projects by priority tier
- Geographic distribution by county/region
- Data quality assessment summary

### Visualization Recommendations
1. **Map Visualization**: Plot projects by DAC status using lat/long
2. **Priority Matrix**: DAC status vs. Combined Score scatter plot
3. **Regional Analysis**: Projects by REDC region and DAC tier
4. **Quality Dashboard**: Data completeness and geocoding success rates

## Refresh and Automation

### Manual Refresh
- **Data** > **Refresh All** to update with new project data
- Power Query will only geocode new addresses (thanks to caching)

### Scheduled Refresh
- Save workbook to SharePoint/OneDrive
- Use Power Automate for scheduled refreshes
- Email reports to stakeholders

## Troubleshooting

### Common Issues
1. **File Path Errors**: Ensure all paths in Config section are correct
2. **Geocoding Failures**: Check internet connection and address format
3. **DAC Data Mismatches**: Verify NY DAC CSV is current version
4. **Performance Issues**: Consider reducing MaxAPICallsPerRun setting

### Data Quality Checks
- Review `Data_Quality_Flag` column for issues
- Investigate addresses with "Not Found" match quality
- Validate Census tract assignments for critical projects

## Advanced Customization

### Adding New Data Sources
- Modify the pipeline to include additional environmental justice datasets
- Add state-specific DAC definitions from other states
- Integrate with EJ Screen or other EPA tools

### Custom Scoring
- Adjust DAC_Priority_Score calculation in LoadDACData function
- Add project-specific weighting factors
- Include additional criteria (e.g., community engagement level)

### API Enhancements
- Integrate with Google Maps or Mapbox for additional geocoding
- Add address validation services
- Include demographic data from American Community Survey

## Support and Updates

For technical support or feature requests:
1. Check the troubleshooting section above
2. Review Power Query documentation for M language syntax
3. Test changes with small datasets before full implementation

## Version History

- **v1.0**: Initial implementation with core DAC analysis
- **v1.1**: Added geospatial fallback and enhanced caching
- **v1.2**: Improved error handling and data quality flags

---

*This pipeline was designed to support environmental justice and equitable investment decision-making. Regular updates ensure compatibility with evolving DAC definitions and Census data.*