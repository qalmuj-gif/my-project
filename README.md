## Power Query pipeline: NYS DAC join via Census geocoding and Socrata

This repo includes ready-to-paste Power Query (M) that:

- Normalizes project addresses
- Geocodes to 2020 Census tracts (11-digit GEOID)
- Caches geocodes to avoid repeat API calls
- Joins to NY’s Final DAC 2023 dataset (via Socrata SODA API), with local CSV fallback
- Surfaces a one-click DAC flag and key scores for portfolio triage

### Files

- `powerquery/DAC_Pipeline.m`: Power Query M script (paste into Excel Power Query Advanced Editor)
- `data/sample_projects.csv`: Example projects input (Address, City, State, Zip)
- `data/geocode_cache.csv`: Optional cache table seed (empty by default)
- `NYS_Disadvantaged_Communities_(DAC).csv`: Local DAC CSV (join fallback if Socrata is not configured)

### Prereqs

- Excel (or Power BI). In Excel: Data > Get Data > Launch Power Query Editor.
- Internet access to call the US Census Geocoder and Socrata APIs.

### Set up in Excel (recommended)

1) Prepare tables in the workbook

- Import your projects into a table named `Projects` with columns:
  - `ProjectID` (optional but recommended)
  - `Address` (street line)
  - `City`
  - `State` (use `NY` for New York)
  - `Zip`

- Create an (optional) table named `Geocode_Cache` with columns:
  - `AddressKey`, `Latitude`, `Longitude`, `GEOID`
  - You can seed it by importing `data/geocode_cache.csv` (it is empty with headers).

2) Create Parameters (optional but recommended)

- `SocrataBaseUrl` (Text): `https://data.ny.gov`
- `DAC_4x4` (Text): Socrata dataset ID for NYS Final DAC 2023 (leave blank to use local CSV fallback)
- `SocrataAppToken` (Text): Optional Socrata app token (empty is fine)
- `RequestsPerSecond` (Number): 5
- `UseSampleData` (Logical): false (set true to use `data/sample_projects.csv` instead of the `Projects` table)

3) Add the M code

- Open Power Query > New Query > Blank Query > Advanced Editor.
- Paste the contents of `powerquery/DAC_Pipeline.m` and click Done.
- If prompted for data source privacy/credentials, allow anonymous for Census and Socrata.

4) Get the DAC dataset ID (4x4) on Socrata (optional)

- Open New York Open Data portal and search for "NYS Disadvantaged Communities (DAC)". On the dataset page, pick API > SODA API and copy the 4x4 ID from the URL (format like `abcd-1234`).
- Set the `DAC_4x4` parameter. With `DAC_4x4` set, the query will pull DAC data via Socrata; if blank, it will join using the included CSV `NYS_Disadvantaged_Communities_(DAC).csv`.

5) Refresh

- Click Refresh All. The output query `Projects_With_DAC` returns:
  - Address columns + `Latitude`, `Longitude`, `GEOID`
  - `DAC_Flag` (true/false)
  - `Comb_Sc`, `Burden_Pct`, `Rank_State`, `Rank_ROS`

### Geocoding details

- Uses US Census Geocoder (2020 Public_AR benchmark and 2020 vintage) to return coordinates and the tract GEOID.
- If the initial address match fails, the pipeline tries a reverse-geography call (coordinates → tract) when coordinates are available.
- Optional spatial fallback via Socrata: if you set `DAC_4x4`, the function can use `intersects(the_geom, 'POINT(lon lat)')` against the DAC tract geometry for tricky addresses.

### Caching

- The query checks a table named `Geocode_Cache` to reuse prior results. New geocodes are surfaced as a separate `NewCacheEntries` output so you can append them to your cache table.

### Local DAC fallback

- If you do not set `DAC_4x4`, the query joins to the included `NYS_Disadvantaged_Communities_(DAC).csv` by `GEOID` and returns the same flag and score fields.

### Notes

- API rate limits: the query spaces requests using a simple delay. Adjust `RequestsPerSecond` as needed.
- Excel cannot write back to the cache automatically. After refresh, copy rows from `NewCacheEntries` into your `Geocode_Cache` table to persist.

