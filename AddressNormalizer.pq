// Address Normalizer Module
// Standardizes and cleans project addresses for geocoding

let
    // Address standardization function
    NormalizeAddress = (address as text, city as text, state as text, zip as text) as record =>
    let
        // Clean and standardize address components
        CleanAddress = Text.Trim(Text.Upper(address)),
        CleanCity = Text.Trim(Text.Proper(city)),
        CleanState = Text.Trim(Text.Upper(state)),
        CleanZip = Text.Trim(zip),
        
        // Standardize common abbreviations
        StandardizedAddress = Text.Replace(
            Text.Replace(
                Text.Replace(
                    Text.Replace(
                        Text.Replace(
                            Text.Replace(
                                Text.Replace(
                                    Text.Replace(CleanAddress, " STREET", " ST"),
                                    " AVENUE", " AVE"),
                                " BOULEVARD", " BLVD"),
                            " DRIVE", " DR"),
                        " ROAD", " RD"),
                    " LANE", " LN"),
                " PLACE", " PL"),
            " CIRCLE", " CIR"),
        
        // Extract ZIP+4 if present
        ZipCode = if Text.Contains(CleanZip, "-") then 
            Text.BeforeDelimiter(CleanZip, "-") 
        else 
            CleanZip,
            
        // Create full normalized address
        FullAddress = StandardizedAddress & ", " & CleanCity & ", " & CleanState & " " & ZipCode,
        
        // Create geocoding query string
        GeocodingQuery = Text.Replace(FullAddress, " ", "+")
    in
        [
            Address = StandardizedAddress,
            City = CleanCity,
            State = CleanState,
            ZIP = ZipCode,
            FullAddress = FullAddress,
            GeocodingQuery = GeocodingQuery
        ],
    
    // Main function to normalize a table of addresses
    NormalizeAddressTable = (InputTable as table) as table =>
    let
        // Add normalized address columns
        WithNormalizedAddresses = Table.AddColumn(
            InputTable,
            "NormalizedAddress",
            each NormalizeAddress([Address], [City], [State], [ZIP]),
            type record
        ),
        
        // Expand the record into separate columns
        ExpandedColumns = Table.ExpandRecordColumn(
            WithNormalizedAddresses,
            "NormalizedAddress",
            {"Address", "City", "State", "ZIP", "FullAddress", "GeocodingQuery"},
            {"Norm_Address", "Norm_City", "Norm_State", "Norm_ZIP", "Full_Address", "Geocoding_Query"}
        )
    in
        ExpandedColumns
in
    NormalizeAddressTable