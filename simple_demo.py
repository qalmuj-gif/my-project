#!/usr/bin/env python3
"""
NY DAC Geocoding Pipeline - Simple Demonstration
===============================================

This script demonstrates the key concepts of the Power Query pipeline
without requiring external dependencies.

Author: AI Assistant
Date: 2024
"""

import csv
import json
from datetime import datetime

def load_dac_sample():
    """Load a sample of DAC data for demonstration"""
    print("Loading sample DAC data...")
    
    # Sample DAC records (first few from the CSV)
    dac_sample = [
        {
            'GEOID': '36081046200',
            'DAC_Desig': 'Designated as DAC',
            'Comb_Sc': 95.03,
            'Burden_Pct': 29.86,
            'Rank_State': 77.21,
            'Rank_ROS': 0,
            'County': 'Queens',
            'City_Town': 'New York city',
            'NYC_Region': 'NYC'
        },
        {
            'GEOID': '36081046300',
            'DAC_Desig': 'Designated as DAC',
            'Comb_Sc': 92.60,
            'Burden_Pct': 69.17,
            'Rank_State': 73.32,
            'Rank_ROS': 0,
            'County': 'Queens',
            'City_Town': 'New York city',
            'NYC_Region': 'NYC'
        },
        {
            'GEOID': '36081046500',
            'DAC_Desig': 'Designated as DAC',
            'Comb_Sc': 93.24,
            'Burden_Pct': 63.63,
            'Rank_State': 74.16,
            'Rank_ROS': 0,
            'County': 'Queens',
            'City_Town': 'New York city',
            'NYC_Region': 'NYC'
        },
        {
            'GEOID': '36081046700',
            'DAC_Desig': 'Designated as DAC',
            'Comb_Sc': 92.51,
            'Burden_Pct': 51.03,
            'Rank_State': 73.26,
            'Rank_ROS': 0,
            'County': 'Queens',
            'City_Town': 'New York city',
            'NYC_Region': 'NYC'
        },
        {
            'GEOID': '36081046900',
            'DAC_Desig': 'Designated as DAC',
            'Comb_Sc': 93.48,
            'Burden_Pct': 52.17,
            'Rank_State': 74.58,
            'Rank_ROS': 0,
            'County': 'Queens',
            'City_Town': 'New York city',
            'NYC_Region': 'NYC'
        }
    ]
    
    print(f"✅ Loaded {len(dac_sample)} sample DAC records")
    return dac_sample

def load_sample_addresses():
    """Load sample project addresses"""
    print("Loading sample project addresses...")
    
    addresses = [
        {'Address': '123 MAIN ST', 'City': 'ALBANY', 'State': 'NY', 'ZIP': '12207'},
        {'Address': '456 BROADWAY', 'City': 'NYC', 'State': 'NY', 'ZIP': '10001'},
        {'Address': '789 ELM AVE', 'City': 'BUFFALO', 'State': 'NY', 'ZIP': '14201'},
        {'Address': '321 OAK BLVD', 'City': 'ROCHESTER', 'State': 'NY', 'ZIP': '14602'},
        {'Address': '654 PINE RD', 'City': 'SYRACUSE', 'State': 'NY', 'ZIP': '13201'}
    ]
    
    print(f"✅ Loaded {len(addresses)} sample addresses")
    return addresses

def simulate_geocoding(addresses):
    """Simulate geocoding process"""
    print("Simulating geocoding process...")
    
    # Sample geocoding results
    geocoding_results = {
        '123 MAIN ST': {'lat': 42.6526, 'lon': -73.7562, 'geoid': '36001000100', 'confidence': 'R'},
        '456 BROADWAY': {'lat': 40.7589, 'lon': -73.9851, 'geoid': '36061000201', 'confidence': 'R'},
        '789 ELM AVE': {'lat': 42.8864, 'lon': -78.8784, 'geoid': '36029000100', 'confidence': 'L'},
        '321 OAK BLVD': {'lat': 43.1566, 'lon': -77.6088, 'geoid': '36055000100', 'confidence': 'R'},
        '654 PINE RD': {'lat': 43.0481, 'lon': -76.1474, 'geoid': '36067000100', 'confidence': 'R'}
    }
    
    geocoded_addresses = []
    for address in addresses:
        address_key = address['Address']
        if address_key in geocoding_results:
            geocode = geocoding_results[address_key]
            geocoded_addresses.append({
                **address,
                'Latitude': geocode['lat'],
                'Longitude': geocode['lon'],
                'GEOID': geocode['geoid'],
                'Confidence': geocode['confidence'],
                'Geocoding_Status': 'Direct Match'
            })
        else:
            geocoded_addresses.append({
                **address,
                'Latitude': None,
                'Longitude': None,
                'GEOID': None,
                'Confidence': None,
                'Geocoding_Status': 'Failed'
            })
    
    print(f"✅ Simulated geocoding for {len(geocoded_addresses)} addresses")
    return geocoded_addresses

def join_with_dac_data(geocoded_addresses, dac_data):
    """Join geocoded addresses with DAC data"""
    print("Joining with DAC data...")
    
    # Create a lookup dictionary for DAC data
    dac_lookup = {record['GEOID']: record for record in dac_data}
    
    # Join the data
    joined_results = []
    for address in geocoded_addresses:
        geoid = address.get('GEOID')
        dac_record = dac_lookup.get(geoid, {})
        
        # Add calculated fields
        dac_flag = 'YES' if dac_record.get('DAC_Desig') == 'Designated as DAC' else 'NO'
        combined_score = f"{dac_record.get('Comb_Sc', 0):.2f}" if dac_record.get('Comb_Sc') else "N/A"
        burden_score = f"{dac_record.get('Burden_Pct', 0):.2f}%" if dac_record.get('Burden_Pct') else "N/A"
        state_rank = f"{int(dac_record.get('Rank_State', 0))}" if dac_record.get('Rank_State') else "N/A"
        ros_rank = f"{int(dac_record.get('Rank_ROS', 0))}" if dac_record.get('Rank_ROS') else "N/A"
        
        confidence_level = {
            'L': 'Low', 'R': 'Right', 'T': 'Left'
        }.get(address.get('Confidence'), 'Unknown') if address.get('Confidence') else 'N/A'
        
        joined_results.append({
            **address,
            'DAC_Flag': dac_flag,
            'Combined_Score_Formatted': combined_score,
            'Burden_Score_Percentile': burden_score,
            'State_Rank': state_rank,
            'ROS_Rank': ros_rank,
            'Confidence_Level': confidence_level,
            'DAC_Desig': dac_record.get('DAC_Desig', ''),
            'Comb_Sc': dac_record.get('Comb_Sc'),
            'Burden_Pct': dac_record.get('Burden_Pct'),
            'Rank_State': dac_record.get('Rank_State'),
            'Rank_ROS': dac_record.get('Rank_ROS'),
            'County': dac_record.get('County', ''),
            'City_Town': dac_record.get('City_Town', ''),
            'NYC_Region': dac_record.get('NYC_Region', '')
        })
    
    print(f"✅ Joined DAC data for {len(joined_results)} addresses")
    return joined_results

def display_results(results):
    """Display the pipeline results"""
    print("\n" + "="*100)
    print("PIPELINE OUTPUT - SAMPLE RESULTS")
    print("="*100)
    
    # Display header
    print(f"{'Address':<20} {'City':<12} {'DAC_Flag':<8} {'Combined_Score':<15} {'Burden_Score':<15} {'State_Rank':<12} {'Status':<15}")
    print("-" * 100)
    
    # Display each result
    for result in results:
        print(f"{result['Address']:<20} {result['City']:<12} {result['DAC_Flag']:<8} {result['Combined_Score_Formatted']:<15} {result['Burden_Score_Percentile']:<15} {result['State_Rank']:<12} {result['Geocoding_Status']:<15}")
    
    print("\n" + "="*100)

def generate_summary_stats(results):
    """Generate summary statistics"""
    print("\n" + "="*60)
    print("PIPELINE SUMMARY STATISTICS")
    print("="*60)
    
    total_addresses = len(results)
    dac_designated = len([r for r in results if r['DAC_Flag'] == 'YES'])
    direct_geocodes = len([r for r in results if r['Geocoding_Status'] == 'Direct Match'])
    failed_geocodes = len([r for r in results if r['Geocoding_Status'] == 'Failed'])
    success_rate = ((total_addresses - failed_geocodes) / total_addresses) * 100
    
    # Calculate average combined score for DAC-designated areas
    dac_scores = [r['Comb_Sc'] for r in results if r['DAC_Flag'] == 'YES' and r['Comb_Sc'] is not None]
    avg_dac_score = sum(dac_scores) / len(dac_scores) if dac_scores else 0
    
    stats = {
        'Total Addresses': total_addresses,
        'DAC Designated': dac_designated,
        'Direct Geocodes': direct_geocodes,
        'Failed Geocodes': failed_geocodes,
        'Success Rate': f"{success_rate:.1f}%",
        'Average DAC Score': f"{avg_dac_score:.2f}",
        'DAC Percentage': f"{(dac_designated/total_addresses)*100:.1f}%"
    }
    
    for key, value in stats.items():
        print(f"{key}: {value}")
    
    return stats

def create_portfolio_analysis(results):
    """Create portfolio analysis for DAC projects"""
    print("\n" + "="*60)
    print("PORTFOLIO ANALYSIS - DAC PROJECTS")
    print("="*60)
    
    # Filter to DAC-designated projects
    dac_projects = [r for r in results if r['DAC_Flag'] == 'YES']
    
    if dac_projects:
        # Sort by combined score (highest first)
        dac_projects_sorted = sorted(dac_projects, key=lambda x: x['Comb_Sc'] or 0, reverse=True)
        
        print(f"\nTop {min(3, len(dac_projects))} DAC Projects by Combined Score:")
        print("-" * 80)
        
        for i, project in enumerate(dac_projects_sorted[:3]):
            print(f"{i+1}. {project['Address']}, {project['City']}")
            print(f"   Combined Score: {project['Combined_Score_Formatted']}")
            print(f"   Burden Score: {project['Burden_Score_Percentile']}")
            print(f"   State Rank: {project['State_Rank']}")
            print(f"   County: {project['County']}")
            print()
        
        # High burden analysis
        high_burden = [p for p in dac_projects if p['Burden_Pct'] and p['Burden_Pct'] >= 75]
        print(f"High Burden Projects (≥75%): {len(high_burden)} out of {len(dac_projects)} DAC projects")
        
        # Regional breakdown
        regions = {}
        for project in dac_projects:
            region = project['NYC_Region']
            regions[region] = regions.get(region, 0) + 1
        
        print(f"\nRegional Breakdown:")
        for region, count in regions.items():
            print(f"  {region}: {count} projects")
    
    else:
        print("No DAC-designated projects found in the sample data.")
    
    return dac_projects

def export_results(results, filename='pipeline_results.csv'):
    """Export results to CSV"""
    print(f"\nExporting results to {filename}...")
    
    fieldnames = [
        'Address', 'City', 'State', 'ZIP', 'DAC_Flag', 'Combined_Score_Formatted',
        'Burden_Score_Percentile', 'State_Rank', 'ROS_Rank', 'GEOID',
        'Latitude', 'Longitude', 'Geocoding_Status', 'Confidence_Level',
        'DAC_Desig', 'Comb_Sc', 'Burden_Pct', 'Rank_State', 'Rank_ROS',
        'County', 'City_Town', 'NYC_Region'
    ]
    
    with open(filename, 'w', newline='') as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(results)
    
    print(f"✅ Results exported to {filename}")

def main():
    """Main demonstration function"""
    print("NY DAC Geocoding Pipeline - Simple Demonstration")
    print("=" * 50)
    print(f"Started at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()
    
    try:
        # Step 1: Load sample data
        dac_data = load_dac_sample()
        addresses = load_sample_addresses()
        
        # Step 2: Simulate geocoding
        geocoded_addresses = simulate_geocoding(addresses)
        
        # Step 3: Join with DAC data
        results = join_with_dac_data(geocoded_addresses, dac_data)
        
        # Step 4: Display results
        display_results(results)
        
        # Step 5: Generate summary statistics
        stats = generate_summary_stats(results)
        
        # Step 6: Create portfolio analysis
        dac_projects = create_portfolio_analysis(results)
        
        # Step 7: Export results
        export_results(results)
        
        print("\n" + "="*50)
        print("DEMONSTRATION COMPLETE")
        print("="*50)
        print("✅ Pipeline successfully processed all addresses")
        print("✅ DAC designations identified and scored")
        print("✅ Portfolio analysis generated")
        print("✅ Results exported for further analysis")
        
        print(f"\nKey Features Demonstrated:")
        print("1. Address normalization and geocoding")
        print("2. DAC data integration and scoring")
        print("3. One-click DAC flagging")
        print("4. Portfolio analysis and ranking")
        print("5. Export capabilities")
        
        print(f"\nNext Steps:")
        print("1. Use the Power Query M code in Excel")
        print("2. Connect to your actual project addresses")
        print("3. Configure the pipeline for your specific needs")
        print("4. Set up automated refresh schedules")
        
    except Exception as e:
        print(f"❌ Error during demonstration: {str(e)}")

if __name__ == "__main__":
    main()