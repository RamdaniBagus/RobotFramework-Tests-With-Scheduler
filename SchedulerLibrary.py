"""
Custom Robot Framework Library untuk Scheduling
Menggunakan library bawaan Python saja (tanpa dependency eksternal)
"""

import time
import subprocess
import sys
import threading
import os
from datetime import datetime, timedelta

class SchedulerLibrary:
    """Library untuk menjalankan Robot Framework test secara terjadwal"""
    
    ROBOT_LIBRARY_SCOPE = 'GLOBAL'
    
    def __init__(self):
        self.is_running = False
        self.scheduler_thread = None
    
    def start_scheduler(self, robot_file, interval_minutes=15):
        """
        Memulai scheduler untuk menjalankan Robot Framework test
        
        Args:
            robot_file: Nama file robot yang akan dijalankan
            interval_minutes: Interval waktu dalam menit (default: 15)
        
        Example:
            | Start Scheduler | test.robot | 15 |
        """
        interval = int(interval_minutes)
        interval_seconds = interval * 60
        
        # Buat folder results jika belum ada
        os.makedirs("results", exist_ok=True)
        
        print(f"\n{'='*70}")
        print(f"Robot Framework Scheduler Started")
        print(f"File: {robot_file}")
        print(f"Interval: Every {interval} minutes ({interval_seconds} seconds)")
        print(f"Started at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"{'='*70}\n")
        print("Press Ctrl+C to stop the scheduler\n")
        
        def run_test():
            """Fungsi untuk menjalankan test"""
            start_time = datetime.now()
            print(f"\n{'='*70}")
            print(f"Executing test at: {start_time.strftime('%Y-%m-%d %H:%M:%S')}")
            print(f"{'='*70}\n")
            
            try:
                # Jalankan robot dengan output real-time
                result = subprocess.run([
                    sys.executable, "-m", "robot",
                    "--outputdir", "results",
                    "--loglevel", "INFO",
                    "--name", f"Scheduled_Test_{start_time.strftime('%Y%m%d_%H%M%S')}",
                    "--consolecolors", "on",
                    robot_file
                ])
                
                end_time = datetime.now()
                duration = (end_time - start_time).total_seconds()
                
                if result.returncode == 0:
                    print("\n" + "="*70)
                    print("✓ Test execution completed successfully!")
                    print(f"Duration: {duration:.2f} seconds")
                    print("="*70)
                else:
                    print("\n" + "="*70)
                    print(f"✗ Test execution failed with return code: {result.returncode}")
                    print(f"Duration: {duration:.2f} seconds")
                    print("="*70)
                    print("\nCheck the log files in 'results/' folder for details:")
                    print("  - results/log.html (detailed log)")
                    print("  - results/report.html (summary report)")
                
                # Calculate next run time from current time
                next_run = datetime.now() + timedelta(minutes=interval)
                print(f"\nNext execution scheduled at: {next_run.strftime('%Y-%m-%d %H:%M:%S')}")
                print(f"(in {interval} minutes)")
                print(f"{'='*70}\n")
                
            except Exception as e:
                print(f"\n✗ Error during test execution: {str(e)}")
                import traceback
                print(traceback.format_exc())
        
        def scheduler_loop():
            """Loop utama scheduler"""
            while self.is_running:
                run_test()
                
                # Tunggu sesuai interval
                if self.is_running:
                    print(f"Waiting {interval} minutes until next execution...")
                    time.sleep(interval_seconds)
        
        # Jalankan scheduler di thread terpisah
        self.is_running = True
        self.scheduler_thread = threading.Thread(target=scheduler_loop, daemon=True)
        self.scheduler_thread.start()
        
        # Keep main thread alive
        try:
            while self.is_running:
                time.sleep(1)
        except KeyboardInterrupt:
            print("\n\n" + "="*70)
            print("Scheduler stopped by user")
            print(f"Stopped at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
            print("="*70 + "\n")
            self.stop_scheduler()
    
    def stop_scheduler(self):
        """Stop the scheduler"""
        self.is_running = False
        if self.scheduler_thread:
            self.scheduler_thread.join(timeout=2)
        print("Scheduler has been stopped.")