#!/usr/bin/env python3
"""Verify pixel processing and TMDS transmission; optionally include RX training."""
import argparse
import os
from pathlib import Path
import re
import shutil
import sys

from simulate import ROOT, run


def source_list(name):
    manifest = (ROOT / "scripts/filter_sources.tcl").read_text()
    match = re.search(r"set " + name + r" \{([^}]+)\}", manifest)
    if not match:
        raise RuntimeError(f"Missing {name} source manifest")
    return [ROOT / path for path in match[1].split()]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--unit", action="store_true", help="Only the fast RGB/timing/EDID tests")
    parser.add_argument("--rtl", action="store_true", help="Use behavioral VHDL cores (much slower than synthesized functional models)")
    parser.add_argument("--full-frame", action="store_true", help="Use all 720 active rows instead of the short 4-row regression raster")
    parser.add_argument("--loopback", action="store_true", help="Also run receiver training and serial input (long acquisition timeouts)")
    args = parser.parse_args()
    cwd = ROOT / "build/filter" / ("sim-rtl" if args.rtl else "sim")
    cwd.mkdir(parents=True, exist_ok=True)
    (cwd / "runner.log").write_text("")
    env = os.environ.copy()
    env.pop("LIBRARY_PATH", None)
    unit_files = [ROOT / "rtl/edid_slave.sv", ROOT / "rtl/video_register.sv",
                  ROOT / "rtl/square_overlay.sv",
                  ROOT / "sim/tb_filter_unit.sv"]
    install = Path(env.get("VIVADO_ROOT", "/opt/Xilinx/2026.1/Vivado")).resolve()
    bindir = install / "bin"
    if shutil.which("iverilog") and shutil.which("vvp"):
        run(["iverilog", "-g2012", "-Wall", "-I", ROOT / "sim", "-s", "tb_filter_unit",
             "-o", "unit.vvp", *unit_files], cwd, env)
        output = run(["vvp", "unit.vvp"], cwd, env)
    else:
        run([bindir / "xvlog", "--sv", "-i", ROOT / "sim", *unit_files], cwd, env)
        run([bindir / "xelab", "work.tb_filter_unit", "-s", "unit", "-mt", "off"], cwd, env)
        output = run([bindir / "xsim", "unit", "-runall"], cwd, env)
    require_pass(output, "FPGA_VIDEO_PASS filter-unit")
    if args.unit:
        return
    if args.rtl:
        run([bindir / "xvhdl", "--2008", *source_list("filter_vhdl_relative")], cwd, env)
        model_files = []
    else:
        run([ROOT / "scripts/vivado.sh", "-mode", "batch", "-source",
             ROOT / "scripts/filter_sim_models.tcl"], cwd, env)
        model_files = [cwd / "models/hdmi_rx.v", cwd / "models/hdmi_tx.v"]
    top = "tb_filter_pipeline" if args.loopback else "tb_filter_tx"
    run([bindir / "xvlog", "--sv", "-i", ROOT / "sim",
         *source_list("filter_sv_relative"), *model_files,
         ROOT / "sim/tmds_monitor.sv", ROOT / "sim" / f"{top}.sv"], cwd, env)
    run([bindir / "xvlog", install / "data/verilog/src/glbl.v"], cwd, env)
    run([bindir / "xelab", f"work.{top}", "work.glbl", "-s", "pipeline",
         "-generic_top", f"ACTIVE_LINES={720 if args.full_frame else 4}",
         "-mt", "off", "-L", "unisims_ver", "-L", "unisim", "-L", "secureip"], cwd, env)
    output = run([bindir / "xsim", "pipeline", "-runall"], cwd, env)
    require_pass(output, "FPGA_VIDEO_PASS filter-pipeline" if args.loopback else "FPGA_VIDEO_PASS filter-transmit")


def require_pass(output, marker):
    if marker not in output or re.search(r"^\s*(ERROR|FATAL):", output, re.IGNORECASE | re.MULTILINE):
        raise RuntimeError(f"Simulation failed ({marker}); see build/filter/sim/runner.log")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        sys.exit(1)
