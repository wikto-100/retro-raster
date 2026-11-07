#!/usr/bin/env python3
"""Run the unit test (EDID/DDC, pixel register, square overlay)."""
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
FILES = [ROOT / f for f in ("rtl/edid_slave.sv", "rtl/video_register.sv",
                            "rtl/square_overlay.sv", "sim/tb_unit.sv")]
work = ROOT / "build/sim"
work.mkdir(parents=True, exist_ok=True)


def run(*command):
    result = subprocess.run([str(c) for c in command], cwd=work,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    print(result.stdout, end="")
    if result.returncode:
        sys.exit(f"{command[0]} failed")
    return result.stdout


if shutil.which("iverilog") and shutil.which("vvp"):
    run("iverilog", "-g2012", "-Wall", "-I", ROOT / "sim", "-s", "tb_unit", "-o", "unit.vvp", *FILES)
    output = run("vvp", "unit.vvp")
else:
    bindir = Path(os.environ.get("VIVADO_ROOT", "/opt/Xilinx/2026.1/Vivado")) / "bin"
    run(bindir / "xvlog", "--sv", "-i", ROOT / "sim", *FILES)
    run(bindir / "xelab", "work.tb_unit", "-s", "unit")
    output = run(bindir / "xsim", "unit", "-runall")
# XSim can exit 0 after $fatal, so require the pass marker.
if "FPGA_VIDEO_PASS unit" not in output:
    sys.exit("Unit test did not pass")
