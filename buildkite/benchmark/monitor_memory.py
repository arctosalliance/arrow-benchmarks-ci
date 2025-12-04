import sys
import time

import psutil

from utils import generate_uuid

from .run_utils import post_logs_to_arrow_bci

current_process_pid = psutil.Process().pid
parent_process_id = int(sys.argv[1])
benchmark_group_execution_id = sys.argv[2]
total_machine_memory = psutil.virtual_memory().total
child_processes_still_running = True

while child_processes_still_running:
    child_processes_still_running = False

    for proc in psutil.process_iter():
        try:
            if proc.pid != current_process_pid and parent_process_id in [
                parent.pid for parent in proc.parents()
            ]:
                child_processes_still_running = True
                mem_rss_bytes = psutil.Process(proc.pid).memory_info().rss
                memory_percent = mem_rss_bytes / total_machine_memory * 100.00

                if memory_percent > 1.00:
                    data = {
                        "type": "MemoryUsage",
                        "id": generate_uuid(),
                        "benchmark_group_execution_id": benchmark_group_execution_id,
                        "process_pid": int(proc.pid),
                        "parent_process_pid": parent_process_id,
                        "process_name": proc.name(),
                        "process_cmdline": proc.cmdline(),
                        "mem_rss_bytes": mem_rss_bytes,
                        "mem_percent": memory_percent,
                    }
                    post_logs_to_arrow_bci("logs", data)
        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
            # Process terminated or became inaccessible during iteration, skip it
            continue

    time.sleep(10)
