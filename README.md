
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
