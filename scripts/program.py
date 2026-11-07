#!/usr/bin/env python3
"""Explicitly load the project's bitstream into volatile FPGA SRAM via OpenOCD."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--bitstream", default="build/artifacts/mimas_hdmi_top.bit",
                    help="Bitstream path, relative to the repository or absolute")
args = parser.parse_args()
bitstream = (root / args.bitstream).resolve()
if not bitstream.is_file():
    sys.exit(f"No bitstream found at {bitstream}. Run make build first.")
programmer = shutil.which("openocd")
if not programmer:
    sys.exit("OpenOCD is not on PATH.")
env = os.environ.copy()
env["FPGA_VIDEO_BITSTREAM"] = str(bitstream)
work = root / "build/program"
work.mkdir(parents=True, exist_ok=True)
print(f"Loading FPGA SRAM from {bitstream}", flush=True)
sys.exit(subprocess.call([
    programmer, "-f", "board/numato_mimas_a7.cfg",
    "-c", "adapter speed 1000", "-c", "init",
    "-c", "pld load 0 $::env(FPGA_VIDEO_BITSTREAM)", "-c", "shutdown",
], cwd=work, env=env))
