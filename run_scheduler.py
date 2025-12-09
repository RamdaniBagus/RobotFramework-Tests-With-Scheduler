#!/usr/bin/env python
"""
Script untuk menjalankan Robot Framework test dengan scheduler
Jalankan dengan: python run_scheduler.py
"""

import sys
import os

# Import custom library
from SchedulerLibrary import SchedulerLibrary

def main():
    """Main function"""
    # Nama file robot yang akan dijalankan
    robot_file = "test_scheduled.robot"
    
    # Interval dalam menit (ubah sesuai kebutuhan)
    interval = 5
    
    print("\n" + "="*70)
    print("ROBOT FRAMEWORK AUTOMATED SCHEDULER")
    print("="*70)
    print(f"Configuration:")
    print(f"  - Test File    : {robot_file}")
    print(f"  - Interval     : {interval} minutes")
    print(f"  - Output Dir   : results/")
    print("="*70 + "\n")
    
    # Check if robot file exists
    if not os.path.exists(robot_file):
        print(f"❌ Error: File '{robot_file}' tidak ditemukan!")
        print(f"   Pastikan file {robot_file} ada di folder yang sama dengan script ini.")
        print(f"\n   Current directory: {os.getcwd()}")
        print(f"   Files in directory:")
        for file in os.listdir('.'):
            print(f"     - {file}")
        sys.exit(1)
    
    # Check if SchedulerLibrary exists
    if not os.path.exists("SchedulerLibrary.py"):
        print("❌ Error: File 'SchedulerLibrary.py' tidak ditemukan!")
        print("   Pastikan file SchedulerLibrary.py ada di folder yang sama.")
        sys.exit(1)
    
    print("✓ All required files found")
    print("✓ Starting scheduler...\n")
    
    # Buat instance scheduler
    scheduler = SchedulerLibrary()
    
    # Jalankan scheduler
    try:
        scheduler.start_scheduler(robot_file, interval)
    except KeyboardInterrupt:
        print("\n\nScheduler stopped by user (Ctrl+C)")
        scheduler.stop_scheduler()
    except Exception as e:
        print(f"\n❌ Error: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    main()