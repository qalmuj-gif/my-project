let
  // Parameters (create as Power Query parameters if desired)
  SocrataBaseUrl   = try SocrataBaseUrl otherwise "https://data.ny.gov",
  DAC_4x4          = try DAC_4x4 otherwise "",
  SocrataAppToken  = try SocrataAppToken otherwise "",
  RequestsPerSecond = try RequestsPerSecond otherwise 5,
  UseSampleData    = try UseSampleData otherwise false,

  //-------------------------------
  // Helpers
  //-------------------------------
  FnSleep = (ms as number) as none =>
    let _ = Function.InvokeAfter(()=> null, #duration(0,0,0, Number.From(ms)/1000)) in null,

  FnRateLimit = () => FnSleep( Number.RoundAwayFromZero(1000 / Number.From(RequestsPerSecond)) ),

  TrimText = (t as any) as text => if t is null then "" else Text.Trim(Text.Upper(Text.From(t))),

  BuildAddressKey = (addr as text, city as text, state as text, zip as any) as text =>
    let
      key = Text.Combine({ TrimText(addr), TrimText(city), TrimText(state), Text.Select(Text.From(zip), {"0".."9"}) }, "|")
    in key,

  PercentToText = (n as any) as nullable number => if n is null or not Value.Is(n, type number) then null else Number.From(n),

  //-------------------------------
  // Input: Projects table or sample CSV
  //-------------------------------
  ProjectsSource = if UseSampleData then Csv.Document(File.Contents("data/sample_projects.csv"),[Delimiter=",", Columns=5, Encoding=65001, QuoteStyle=QuoteStyle.Csv]) else Excel.CurrentWorkbook(){[Name="Projects"]}[Content],
  Projects = Table.TransformColumnTypes( ProjectsSource, {{"ProjectID", type text}, {"Address", type text}, {"City", type text}, {"State", type text}, {"Zip", type text}}),
  ProjectsWithKey = Table.AddColumn(Projects, "AddressKey", each BuildAddressKey([Address],[City],[State],[Zip]), type text),

  //-------------------------------
  // Optional cache table
  //-------------------------------
  CacheOptional = let
    t = try Excel.CurrentWorkbook(){[Name="Geocode_Cache"]}[Content] otherwise null
  in t,
  Cache = if CacheOptional = null then #table({"AddressKey","Latitude","Longitude","GEOID"},{}) else Table.TransformColumnTypes(CacheOptional, {{"AddressKey", type text},{"Latitude", type number},{"Longitude", type number},{"GEOID", type text}}),

  //-------------------------------
  // Geocoding functions (US Census)
  //-------------------------------
  CensusAddressToGeo = (addr as text, city as text, state as text, zip as text) as record =>
    let
      _ = FnRateLimit(),
      url = "https://geocoding.geo.census.gov/geocoder/geographies/address",
      qs = [
        street = addr,
        city = city,
        state = state,
        zip = zip,
        benchmark = "Public_AR_Census2020",
        vintage   = "Census2020_Census2020",
        format    = "json"
      ],
      resp = try Json.Document( Web.Contents(url, [Query = qs]) ) otherwise null,
      result = if resp = null then [lat=null, lon=null, geoid=null] else
        let
          mtchs = resp["result"]["addressMatches"],
          first = if List.Count(mtchs) > 0 then mtchs{0} else null,
          geo   = if first=null then null else first["geographies"],
          trcts = if geo=null then null else try geo["Census Tracts"] otherwise null,
          tract = if trcts=null or List.Count(trcts)=0 then null else trcts{0},
          coords= if first=null then null else first["coordinates"],
          lat   = if coords=null then null else coords["y"],
          lon   = if coords=null then null else coords["x"],
          geoid = if tract=null then null else tract["GEOID"]
        in [lat=lat, lon=lon, geoid=geoid]
    in result,

  //-------------------------------
  // Apply cache-then-geocode
  //-------------------------------
  WithCache = Table.NestedJoin(ProjectsWithKey, {"AddressKey"}, Cache, {"AddressKey"}, "Cache", JoinKind.LeftOuter),
  ExpandedCache = Table.ExpandTableColumn(WithCache, "Cache", {"Latitude","Longitude","GEOID"}, {"Latitude","Longitude","GEOID"}),
  AddNeedsGeo = Table.AddColumn(ExpandedCache, "NeedsGeocode", each [GEOID] = null, type logical),
  ToGeocode = Table.SelectRows(AddNeedsGeo, each [NeedsGeocode] = true),

  Geocoded = Table.AddColumns(ToGeocode, {
      {
        "GeoRecord",
        each CensusAddressToGeo([Address],[City],[State],[Zip]),
        type record
      }
    }),
  GeocodedExpanded = Table.ExpandRecordColumn(Geocoded, "GeoRecord", {"lat","lon","geoid"}, {"Latitude_new","Longitude_new","GEOID_new"}),
  GeocodedTyped = Table.TransformColumnTypes(GeocodedExpanded, {{"Latitude_new", type number},{"Longitude_new", type number},{"GEOID_new", type text}}),

  NewCacheEntries = Table.SelectColumns(GeocodedTyped, {"AddressKey","Latitude_new","Longitude_new","GEOID_new"}),
  NewCacheRenamed = Table.RenameColumns(NewCacheEntries, {{"Latitude_new","Latitude"},{"Longitude_new","Longitude"},{"GEOID_new","GEOID"}}),

  Merged = Table.NestedJoin(AddNeedsGeo, {"AddressKey"}, NewCacheRenamed, {"AddressKey"}, "NewGeo", JoinKind.LeftOuter),
  ExpandedNew = Table.ExpandTableColumn(Merged, "NewGeo", {"Latitude","Longitude","GEOID"}, {"Latitude_new","Longitude_new","GEOID_new"}),
  Filled = Table.TransformColumns(ExpandedNew, {
      {"Latitude", (x)=> if x=null then [Latitude_new] else x, type number},
      {"Longitude",(x)=> if x=null then [Longitude_new] else x, type number},
      {"GEOID",   (x)=> if x=null then [GEOID_new] else x, type text}
    }),
  CleanCols = Table.RemoveColumns(Filled, {"NeedsGeocode","Latitude_new","Longitude_new","GEOID_new"}),

  //-------------------------------
  // Socrata DAC dataset (optional online) or local CSV fallback
  //-------------------------------
  SocrataHeaders = if Text.Length(SocrataAppToken) > 0 then [Headers = [("X-App-Token")=SocrataAppToken]] else [],

  DAC_Socrata = if Text.Length(Text.Trim(DAC_4x4)) > 0 then
      try Json.Document( Web.Contents(SocrataBaseUrl & "/resource/" & DAC_4x4 & ".json?$select=geoid,dac_desig,comb_sc,burden_pct,rank_state,rank_ros", SocrataHeaders ) ) otherwise null
    else null,
  DAC_SocrataTable = if DAC_Socrata=null then null else Table.FromRecords(DAC_Socrata),
  DAC_SocrataTyped = if DAC_SocrataTable=null then null else Table.TransformColumnTypes(DAC_SocrataTable, {{"geoid", type text},{"dac_desig", type text},{"comb_sc", type number},{"burden_pct", type number},{"rank_state", type number},{"rank_ros", type number}}),

  DAC_Local = Csv.Document(File.Contents("NYS_Disadvantaged_Communities_(DAC).csv"),[Delimiter=",", Columns=66, Encoding=65001, QuoteStyle=QuoteStyle.Csv]),
  DAC_LocalHeaders = Table.PromoteHeaders(DAC_Local, [PromoteAllScalars=true]),
  DAC_LocalTyped = Table.TransformColumnTypes(DAC_LocalHeaders, {{"GEOID", type text},{"DAC_Desig", type text},{"Comb_Sc", type number},{"Burden_Pct", type number},{"Rank_State", type number},{"Rank_ROS", type number}}),

  DAC_Table = if DAC_SocrataTyped<>null then DAC_SocrataTyped else Table.SelectColumns(DAC_LocalTyped, {"GEOID","DAC_Desig","Comb_Sc","Burden_Pct","Rank_State","Rank_ROS"}),

  //-------------------------------
  // Join by GEOID and shape output
  //-------------------------------
  Joined = Table.NestedJoin(CleanCols, {"GEOID"}, DAC_Table, { if DAC_SocrataTyped<>null then "geoid" else "GEOID" }, "DAC", JoinKind.LeftOuter),
  ExpandedDAC = if DAC_SocrataTyped<>null then
      Table.ExpandTableColumn(Joined, "DAC", {"dac_desig","comb_sc","burden_pct","rank_state","rank_ros"}, {"DAC_Desig","Comb_Sc","Burden_Pct","Rank_State","Rank_ROS"})
    else
      Table.ExpandTableColumn(Joined, "DAC", {"DAC_Desig","Comb_Sc","Burden_Pct","Rank_State","Rank_ROS"}, {"DAC_Desig","Comb_Sc","Burden_Pct","Rank_State","Rank_ROS"}),

  WithFlag = Table.AddColumn(ExpandedDAC, "DAC_Flag", each Text.StartsWith(Text.Upper(Text.From([DAC_Desig])), "DESIGNATED"), type logical),
  Reordered = Table.ReorderColumns(WithFlag, List.Distinct({"ProjectID","Address","City","State","Zip","Latitude","Longitude","GEOID","DAC_Flag","Comb_Sc","Burden_Pct","Rank_State","Rank_ROS"} & Table.ColumnNames(WithFlag))),

  Output = Reordered
in
  Output

