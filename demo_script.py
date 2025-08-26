#!/usr/bin/env python3
"""
NY DAC Geocoding Pipeline - Demonstration Script
================================================

This script demonstrates how the Power Query pipeline would work
with sample project addresses and the NY DAC 2023 dataset.

Author: AI Assistant
Date: 2024
"""

import pandas as pd
import json
from datetime import datetime

def load_dac_data():
    """Load and prepare the NY DAC 2023 dataset"""
    print("Loading NY DAC 2023 dataset...")
    
    # Load the DAC CSV file
    dac_df = pd.read_csv('NYS_Disadvantaged_Communities_(DAC).csv')
    
    # Clean and prepare the data
    dac_df['GEOID'] = dac_df['GEOID'].astype(str)
    dac_df['Comb_Sc'] = pd.to_numeric(dac_df['Comb_Sc'], errors='coerce')
    dac_df['Burden_Pct'] = pd.to_numeric(dac_df['Burden_Pct'], errors='coerce')
    dac_df['Rank_State'] = pd.to_numeric(dac_df['Rank_State'], errors='coerce')
    dac_df['Rank_ROS'] = pd.to_numeric(dac_df['Rank_ROS'], errors='coerce')
    
    # Filter to valid GEOIDs
    dac_df = dac_df[dac_df['GEOID'].str.len() == 11]
    
    print(f"✅ Loaded {len(dac_df)} DAC records")
    return dac_df

def load_sample_addresses():
    """Load sample project addresses"""
    print("Loading sample project addresses...")
    
    # Load sample addresses
    addresses_df = pd.read_csv('sample_project_addresses.csv')
    
    # Normalize addresses (simulate Power Query normalization)
    addresses_df['Address'] = addresses_df['Address'].str.upper().str.strip()
    addresses_df['City'] = addresses_df['City'].str.upper().str.strip()
    addresses_df['State'] = addresses_df['State'].str.upper().str.strip()
    addresses_df['ZIP'] = addresses_df['ZIP'].astype(str).str.strip()
    
    print(f"✅ Loaded {len(addresses_df)} project addresses")
    return addresses_df

def simulate_geocoding(addresses_df):
    """Simulate geocoding process with sample results"""
    print("Simulating geocoding process...")
    
    # Sample geocoding results (in real pipeline, this would come from Census API)
    sample_geocodes = {
        '123 MAIN ST': {'lat': 42.6526, 'lon': -73.7562, 'geoid': '36001000100', 'confidence': 'R'},
        '456 BROADWAY': {'lat': 40.7589, 'lon': -73.9851, 'geoid': '36061000201', 'confidence': 'R'},
        '789 ELM AVE': {'lat': 42.8864, 'lon': -78.8784, 'geoid': '36029000100', 'confidence': 'L'},
        '321 OAK BLVD': {'lat': 43.1566, 'lon': -77.6088, 'geoid': '36055000100', 'confidence': 'R'},
        '654 PINE RD': {'lat': 43.0481, 'lon': -76.1474, 'geoid': '36067000100', 'confidence': 'R'},
        '987 MAPLE DR': {'lat': 40.9312, 'lon': -73.8987, 'geoid': '36119000100', 'confidence': 'L'},
        '147 CEDAR LN': {'lat': 41.0340, 'lon': -73.7629, 'geoid': '36119000200', 'confidence': 'R'},
        '258 BIRCH WAY': {'lat': 40.9115, 'lon': -73.7826, 'geoid': '36119000300', 'confidence': 'R'},
        '369 SPRUCE CIR': {'lat': 40.9126, 'lon': -73.8378, 'geoid': '36119000400', 'confidence': 'L'},
        '741 WILLOW CT': {'lat': 41.2895, 'lon': -73.9204, 'geoid': '36119000500', 'confidence': 'R'},
        '852 ASPEN PL': {'lat': 41.1629, 'lon': -73.8615, 'geoid': '36119000600', 'confidence': 'R'},
        '963 CHESTNUT ST': {'lat': 41.5048, 'lon': -73.9696, 'geoid': '36119000700', 'confidence': 'L'},
        '159 POPLAR AVE': {'lat': 41.5034, 'lon': -74.0104, 'geoid': '36119000800', 'confidence': 'R'},
        '357 SYCAMORE BLVD': {'lat': 41.4459, 'lon': -74.4229, 'geoid': '36119000900', 'confidence': 'R'},
        '468 HICKORY RD': {'lat': 41.3306, 'lon': -74.1868, 'geoid': '36119001000', 'confidence': 'L'}
    }
    
    # Add geocoding results to addresses
    geocoding_results = []
    for _, row in addresses_df.iterrows():
        address_key = row['Address']
        if address_key in sample_geocodes:
            geocode = sample_geocodes[address_key]
            geocoding_results.append({
                'Address': row['Address'],
                'City': row['City'],
                'State': row['State'],
                'ZIP': row['ZIP'],
                'Latitude': geocode['lat'],
                'Longitude': geocode['lon'],
                'GEOID': geocode['geoid'],
                'Confidence': geocode['confidence'],
                'Geocoding_Status': 'Direct Match'
            })
        else:
            geocoding_results.append({
                'Address': row['Address'],
                'City': row['City'],
                'State': row['State'],
                'ZIP': row['ZIP'],
                'Latitude': None,
                'Longitude': None,
                'GEOID': None,
                'Confidence': None,
                'Geocoding_Status': 'Failed'
            })
    
    geocoded_df = pd.DataFrame(geocoding_results)
    print(f"✅ Simulated geocoding for {len(geocoded_df)} addresses")
    return geocoded_df

def join_with_dac_data(geocoded_df, dac_df):
    """Join geocoded addresses with DAC data"""
    print("Joining with DAC data...")
    
    # Join on GEOID
    merged_df = pd.merge(
        geocoded_df, 
        dac_df[['GEOID', 'DAC_Desig', 'Comb_Sc', 'Burden_Pct', 'Rank_State', 'Rank_ROS', 'County', 'City_Town', 'NYC_Region']], 
        on='GEOID', 
        how='left'
    )
    
    # Add calculated fields (simulate Power Query calculations)
    merged_df['DAC_Flag'] = merged_df['DAC_Desig'].apply(lambda x: 'YES' if x == 'Designated as DAC' else 'NO')
    merged_df['Combined_Score_Formatted'] = merged_df['Comb_Sc'].apply(lambda x: f"{x:.2f}" if pd.notna(x) else "N/A")
    merged_df['Burden_Score_Percentile'] = merged_df['Burden_Pct'].apply(lambda x: f"{x:.2f}%" if pd.notna(x) else "N/A")
    merged_df['State_Rank'] = merged_df['Rank_State'].apply(lambda x: f"{int(x)}" if pd.notna(x) else "N/A")
    merged_df['ROS_Rank'] = merged_df['Rank_ROS'].apply(lambda x: f"{int(x)}" if pd.notna(x) else "N/A")
    merged_df['Confidence_Level'] = merged_df['Confidence'].apply(lambda x: {
        'L': 'Low', 'R': 'Right', 'T': 'Left'
    }.get(x, 'Unknown') if x else 'N/A')
    
    print(f"✅ Joined DAC data for {len(merged_df)} addresses")
    return merged_df

def generate_summary_stats(merged_df):
    """Generate summary statistics"""
    print("\n" + "="*60)
    print("PIPELINE SUMMARY STATISTICS")
    print("="*60)
    
    total_addresses = len(merged_df)
    dac_designated = len(merged_df[merged_df['DAC_Flag'] == 'YES'])
    direct_geocodes = len(merged_df[merged_df['Geocoding_Status'] == 'Direct Match'])
    failed_geocodes = len(merged_df[merged_df['Geocoding_Status'] == 'Failed'])
    success_rate = ((total_addresses - failed_geocodes) / total_addresses) * 100
    
    # Calculate average combined score for DAC-designated areas
    dac_scores = merged_df[merged_df['DAC_Flag'] == 'YES']['Comb_Sc'].dropna()
    avg_dac_score = dac_scores.mean() if len(dac_scores) > 0 else 0
    
    stats = {
        'Total_Addresses': total_addresses,
        'DAC_Designated': dac_designated,
        'Direct_Geocodes': direct_geocodes,
        'Failed_Geocodes': failed_geocodes,
        'Success_Rate': f"{success_rate:.1f}%",
        'Average_DAC_Score': f"{avg_dac_score:.2f}",
        'DAC_Percentage': f"{(dac_designated/total_addresses)*100:.1f}%"
    }
    
    for key, value in stats.items():
        print(f"{key.replace('_', ' ').title()}: {value}")
    
    return stats

def display_sample_output(merged_df):
    """Display sample output in a formatted table"""
    print("\n" + "="*100)
    print("SAMPLE PIPELINE OUTPUT")
    print("="*100)
    
    # Select key columns for display
    display_columns = [
        'Address', 'City', 'State', 'DAC_Flag', 'Combined_Score_Formatted', 
        'Burden_Score_Percentile', 'State_Rank', 'Geocoding_Status'
    ]
    
    display_df = merged_df[display_columns].head(10)
    
    # Format the display
    pd.set_option('display.max_columns', None)
    pd.set_option('display.width', None)
    pd.set_option('display.max_colwidth', 15)
    
    print(display_df.to_string(index=False))
    
    return display_df

def create_portfolio_analysis(merged_df):
    """Create portfolio analysis for DAC projects"""
    print("\n" + "="*60)
    print("PORTFOLIO ANALYSIS - DAC PROJECTS")
    print("="*60)
    
    # Filter to DAC-designated projects
    dac_projects = merged_df[merged_df['DAC_Flag'] == 'YES'].copy()
    
    if len(dac_projects) > 0:
        # Sort by combined score (highest first)
        dac_projects_sorted = dac_projects.sort_values('Comb_Sc', ascending=False)
        
        # Display top DAC projects
        print(f"\nTop {min(5, len(dac_projects))} DAC Projects by Combined Score:")
        print("-" * 80)
        
        for i, (_, project) in enumerate(dac_projects_sorted.head(5).iterrows()):
            print(f"{i+1}. {project['Address']}, {project['City']}")
            print(f"   Combined Score: {project['Combined_Score_Formatted']}")
            print(f"   Burden Score: {project['Burden_Score_Percentile']}")
            print(f"   State Rank: {project['State_Rank']}")
            print(f"   County: {project['County']}")
            print()
        
        # High burden analysis
        high_burden = dac_projects[dac_projects['Burden_Pct'] >= 75]
        print(f"High Burden Projects (≥75%): {len(high_burden)} out of {len(dac_projects)} DAC projects")
        
        # Regional breakdown
        regional_breakdown = dac_projects['NYC_Region'].value_counts()
        print(f"\nRegional Breakdown:")
        for region, count in regional_breakdown.items():
            print(f"  {region}: {count} projects")
    
    else:
        print("No DAC-designated projects found in the sample data.")
    
    return dac_projects

def export_results(merged_df, output_file='pipeline_results.csv'):
    """Export results to CSV"""
    print(f"\nExporting results to {output_file}...")
    
    # Reorder columns for better presentation
    column_order = [
        'Address', 'City', 'State', 'ZIP', 'DAC_Flag', 'Combined_Score_Formatted',
        'Burden_Score_Percentile', 'State_Rank', 'ROS_Rank', 'GEOID',
        'Latitude', 'Longitude', 'Geocoding_Status', 'Confidence_Level',
        'DAC_Desig', 'Comb_Sc', 'Burden_Pct', 'Rank_State', 'Rank_ROS',
        'County', 'City_Town', 'NYC_Region'
    ]
    
    # Only include columns that exist
    existing_columns = [col for col in column_order if col in merged_df.columns]
    export_df = merged_df[existing_columns]
    
    export_df.to_csv(output_file, index=False)
    print(f"✅ Results exported to {output_file}")
    
    return export_df

def main():
    """Main demonstration function"""
    print("NY DAC Geocoding Pipeline - Demonstration")
    print("=" * 50)
    print(f"Started at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()
    
    try:
        # Step 1: Load DAC data
        dac_df = load_dac_data()
        
        # Step 2: Load sample addresses
        addresses_df = load_sample_addresses()
        
        # Step 3: Simulate geocoding
        geocoded_df = simulate_geocoding(addresses_df)
        
        # Step 4: Join with DAC data
        merged_df = join_with_dac_data(geocoded_df, dac_df)
        
        # Step 5: Generate summary statistics
        stats = generate_summary_stats(merged_df)
        
        # Step 6: Display sample output
        display_df = display_sample_output(merged_df)
        
        # Step 7: Create portfolio analysis
        dac_projects = create_portfolio_analysis(merged_df)
        
        # Step 8: Export results
        export_df = export_results(merged_df)
        
        print("\n" + "="*50)
        print("DEMONSTRATION COMPLETE")
        print("="*50)
        print("✅ Pipeline successfully processed all addresses")
        print("✅ DAC designations identified and scored")
        print("✅ Portfolio analysis generated")
        print("✅ Results exported for further analysis")
        
        print(f"\nNext Steps:")
        print("1. Use the Power Query M code in Excel")
        print("2. Connect to your actual project addresses")
        print("3. Configure the pipeline for your specific needs")
        print("4. Set up automated refresh schedules")
        
    except Exception as e:
        print(f"❌ Error during demonstration: {str(e)}")
        print("Please check that all required files are present:")
        print("- NYS_Disadvantaged_Communities_(DAC).csv")
        print("- sample_project_addresses.csv")

if __name__ == "__main__":
    main()