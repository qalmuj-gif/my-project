# 🚀 DAC Portfolio Analysis Pipeline - Complete Setup Guide

## 📋 What You're Getting

A complete Power Query-driven Excel solution that:
- ✅ **Normalizes** project addresses automatically
- ✅ **Geocodes** addresses to Census tracts (11-digit GEOID) 
- ✅ **Caches** geocoding results for blazing-fast subsequent runs
- ✅ **Falls back** to geospatial intersection for tricky addresses
- ✅ **Joins** to NY's Final DAC 2023 dataset via your local CSV
- ✅ **Provides** one-click DAC flags and priority scoring
- ✅ **Delivers** actionable investment recommendations

## 🎯 5-Minute Quick Start

### Step 1: File Setup
1. **Copy** all files from this workspace to your local machine:
   - `Complete_DAC_Pipeline.pq` (the main Power Query code)
   - `sample_project_addresses.csv` (replace with your actual project data)
   - `NYS_Disadvantaged_Communities_(DAC).csv` (your DAC dataset)
   - `geocoding_cache.csv` (performance cache)

### Step 2: Excel Setup
1. **Open Excel** and create a new workbook
2. **Go to** Data → Get Data → Blank Query
3. **Click** Advanced Editor
4. **Copy-paste** the entire contents of `Complete_DAC_Pipeline.pq`
5. **Update file paths** in the Config section (lines 10-12):
   ```m
   ProjectDataPath = "C:\YourPath\sample_project_addresses.csv",
   DACDataPath = "C:\YourPath\NYS_Disadvantaged_Communities_(DAC).csv", 
   CacheDataPath = "C:\YourPath\geocoding_cache.csv",
   ```

### Step 3: Execute
1. **Click Done** → Close & Load
2. **Watch the magic** as your addresses get geocoded and analyzed
3. **Get results** in a new worksheet with full DAC analysis

## 📊 Output Columns Explained

| Column | What It Tells You |
|--------|-------------------|
| `Is_DAC` | **"Yes"** = Disadvantaged Community, **"No"** = Not DAC |
| `DAC_Priority_Tier` | **Critical** > **High** > **Medium** > **Standard** > **Low** |
| `Investment_Recommendation` | Strategic guidance for portfolio decisions |
| `DAC_Combined_Score` | Environmental + Social burden score (higher = more disadvantaged) |
| `Final_GEOID_Tract` | 11-digit Census tract ID for regulatory compliance |
| `Data_Quality_Flag` | "Good Data Quality" = ready to use, others need review |

## 🎨 Building Your Dashboard

### Create These Summary Views:
```excel
=COUNTIF(Is_DAC:Is_DAC,"Yes")  // Count of DAC projects
=COUNTIF(DAC_Priority_Tier:DAC_Priority_Tier,"Critical")  // Critical projects
=AVERAGE(DAC_Combined_Score:DAC_Combined_Score)  // Average burden score
```

### Recommended Charts:
1. **Pie Chart**: DAC vs Non-DAC project distribution
2. **Bar Chart**: Projects by Priority Tier
3. **Scatter Plot**: Combined Score vs Project Priority
4. **Map**: Projects plotted by Latitude/Longitude colored by DAC status

## ⚡ Performance Features

### Smart Caching
- First run: Geocodes all addresses (~2-3 seconds per address)
- Subsequent runs: Uses cache (instant for known addresses)
- Only new addresses get geocoded

### Rate Limiting
- Respects Census API limits
- Built-in delays prevent overwhelming the service
- Configurable max calls per run

### Fallback Systems
- Primary: Direct address geocoding
- Secondary: Point-in-polygon intersection with Census boundaries
- Ensures maximum coverage even for difficult addresses

## 🔧 Customization Options

### Adjust Geocoding Limits
```m
MaxAPICallsPerRun = 25,  // Increase for faster bulk processing
```

### Modify Priority Scoring
```m
// In LoadDACData function, adjust this logic:
"DAC_Priority_Score",
each if [DAC_Desig] = "Designated as DAC" then
    (if [Comb_Sc] <> null then [Comb_Sc] else 50)  // Customize scoring
```

### Add Custom Columns
Insert additional analysis fields in the final pipeline step.

## 🚨 Troubleshooting

### "File not found" error
- Double-check all file paths in the Config section
- Use full absolute paths (C:\folder\file.csv)
- Ensure files exist and are accessible

### Slow performance
- Reduce `MaxAPICallsPerRun` setting
- Check internet connection
- Verify geocoding cache is being used

### Missing DAC data
- Confirm NY DAC CSV file is the correct/current version
- Check for GEOID format mismatches
- Review `Data_Quality_Flag` column for specifics

### Geocoding failures
- Review addresses in `sample_project_addresses.csv`
- Check for incomplete/malformed addresses
- Use `Match_Quality` column to identify issues

## 📈 Advanced Features

### Batch Processing
- Process thousands of addresses efficiently
- Automatic progress tracking
- Resume capability via caching

### Data Validation
- Built-in address standardization
- Quality scoring for each geocoding result
- Comprehensive error handling

### Integration Ready
- Compatible with SharePoint/OneDrive
- Power Automate scheduling support
- API endpoints for external systems

## 🎯 Pro Tips

1. **Start Small**: Test with 10-15 addresses first
2. **Cache Everything**: Let the cache build up over time for maximum performance
3. **Regular Updates**: Refresh when you add new projects
4. **Quality Check**: Always review `Data_Quality_Flag` before making decisions
5. **Backup Cache**: Save your `geocoding_cache.csv` - it's valuable!

## 📞 Need Help?

### Common Issues & Solutions
- **API timeouts**: Reduce MaxAPICallsPerRun to 10-15
- **Permission errors**: Run Excel as administrator for file access
- **Data mismatches**: Ensure CSV files have headers matching the expected format

### Your Data Format
Your project CSV should have these columns:
```csv
Project_ID,Project_Name,Address,City,State,ZIP,Priority
PROJ001,Solar Installation,123 Main St,Albany,NY,12210,High
```

## 🏆 Success Metrics

After setup, you should see:
- ✅ 95%+ geocoding success rate
- ✅ Complete DAC analysis for all valid addresses
- ✅ Clear investment recommendations
- ✅ Sub-second refresh times (after initial geocoding)

---

**🎉 You're now ready to make data-driven, equitable investment decisions with comprehensive disadvantaged community analysis!**

*For additional support, refer to the detailed implementation guide and Power Query documentation.*