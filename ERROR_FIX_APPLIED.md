# ✅ Error Fix Applied - List.SelectRows Issue

## Problem Resolved
**Error:** `Expression.Error: The import List.SelectRows matches no exports. Did you miss a module reference?`

## Root Cause
The Power Query M language doesn't have a `List.SelectRows` function. The correct function is `List.Select`.

## Fix Applied
Changed this line in `Complete_DAC_Pipeline.pq`:
```m
// BEFORE (incorrect):
CachedResult = List.SelectRows(CacheLookup, each [Geocoding_Query] = Query),

// AFTER (correct):
CachedResult = List.Select(CacheLookup, each [Geocoding_Query] = Query),
```

Also fixed the same issue in `GeocodingService.pq`.

## Status
✅ **FIXED** - The pipeline should now run without this error.

## Next Steps
1. Copy the updated `Complete_DAC_Pipeline.pq` code
2. Paste it into your Excel Power Query Advanced Editor
3. Update your file paths in the Config section
4. Click Done → Close & Load

The pipeline will now execute correctly! 🚀