#!/usr/bin/env python3
"""Read the experimental design's USER1 JTAG status without changing video."""
from pathlib import Path
import re
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
work = root / "build/program"
work.mkdir(parents=True, exist_ok=True)
result = subprocess.run([
    "openocd", "-f", "board/numato_mimas_a7.cfg", "-c", "adapter speed 1000",
    "-c", "init", "-c", "irscan xc7.tap 0x02",
    "-c", "echo FPGA_STATUS:[drscan xc7.tap 32 0]",
    "-c", "irscan xc7.tap 0x03", "-c", "echo VIDEO_STATUS:[drscan xc7.tap 128 0]",
    "-c", "shutdown",
], cwd=work, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
match = re.search(r"FPGA_STATUS:([0-9a-fA-F]+)", result.stdout)
if result.returncode or not match:
    sys.exit(result.stdout)
value = int(match[1], 16)
if value >> 24 != 0xa7:
    sys.exit(f"No experimental status signature: 0x{value:08x}")
print(f"FPGA status 0x{value:08x}")
for bit, name in enumerate(("reference_locked", "monitor_connected", "pixel_locked", "video_reset",
                            "received_pixels", "received_hsync", "received_vsync", "transmitted_pixels")):
    print(f"{name}: {(value >> bit) & 1}")
debug = (value >> 8) & 65535
print(f"lane_ready: {(debug >> 13) & 7:03b}")
print(f"lane_aligned: {(debug >> 10) & 7:03b}")
print(f"receiver_mmcm_locked: {(debug >> 9) & 1}")
print(f"idelay_ready: {(debug >> 8) & 1}")
print(f"idelay_reset: {(debug >> 7) & 1}")
print(f"receiver_mmcm_reset: {(debug >> 6) & 1}")
video_match = re.search(r"VIDEO_STATUS:([0-9a-fA-F]+)", result.stdout)
if video_match:
    video = int(video_match[1], 16)
    if video >> 104 == 0x720a7d:
        print(f"tx_enabled: {(video >> 103) & 1}")
        print(f"video_starts_since_config: {(video >> 96) & 0x7f}")
        print(f"frame_pixel_clocks: {(video >> 64) & 0xffffffff}")
        print(f"active_pixels: {(video >> 42) & 0x3fffff}")
        print(f"active_rows: {(video >> 32) & 0x3ff}")
        print(f"hsync_width: {(video >> 24) & 0xff}")
        print(f"active_width: {(video >> 13) & 0x7ff}")
        print(f"line_pixel_clocks: {video & 0x1fff}")
