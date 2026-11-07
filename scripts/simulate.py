#!/usr/bin/env python3
"""Run real HDL simulations and require a testbench pass marker, not just exit 0."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
RTL = ROOT / "rtl"
CORE = [RTL / "edid_slave.sv"]


def run(command, cwd, env):
    print("+ " + " ".join(map(str, command)), flush=True)
    result = subprocess.run(list(map(str, command)), cwd=cwd, env=env,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    output = result.stdout
    print(output, end="", flush=True)
    with (cwd / "runner.log").open("a") as log:
        log.write("+ " + " ".join(map(str, command)) + "\n" + output)
    if result.returncode:
        raise RuntimeError(f"{command[0]} exited {result.returncode}; see {cwd / 'runner.log'}")
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--simulator", choices=("auto", "xsim", "iverilog"), default="auto")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--vendor", action="store_true")
    mode.add_argument("--elaborate", action="store_true")
    args = parser.parse_args()
    vendor = args.vendor or args.elaborate
    simulator = args.simulator
    if simulator == "auto":
        simulator = "iverilog" if not vendor and shutil.which("iverilog") and shutil.which("vvp") else "xsim"
    if vendor and simulator == "iverilog":
        raise RuntimeError("AMD primitive checks require XSim")
    kind = "design" if args.elaborate else "passthrough" if args.vendor else "core"
    cwd = ROOT / "build" / "sim" / f"{kind}-{simulator}"
    cwd.mkdir(parents=True, exist_ok=True)
    (cwd / "runner.log").write_text("")
    env = os.environ.copy()
    if simulator == "iverilog":
        if not shutil.which("iverilog") or not shutil.which("vvp"):
            raise RuntimeError("iverilog and vvp must both be on PATH")
        run(["iverilog", "-g2012", "-Wall", "-I", ROOT / "sim", "-s", "tb_core", "-o", "core.vvp",
             *CORE, ROOT / "sim/tb_core.sv"], cwd, env)
        output = run(["vvp", "core.vvp"], cwd, env)
    else:
        install = Path(env.get("VIVADO_ROOT", "/opt/Xilinx/2026.1/Vivado")).resolve()
        bindir = install / "bin"
        if not (bindir / "xvlog").is_file():
            raise RuntimeError(f"XSim not found at {bindir}; set VIVADO_ROOT")
        # The vendor executable launchers load their own installation environment.
        # Retain caller licensing settings, but drop an unrelated compiler search path.
        env.pop("LIBRARY_PATH", None)
        if args.elaborate:
            files = [*CORE, RTL / "tmds_passthrough.sv", RTL / "mimas_hdmi_top.sv"]
            top = "mimas_hdmi_top"
        elif args.vendor:
            files = [*CORE, RTL / "tmds_passthrough.sv", RTL / "mimas_hdmi_top.sv",
                     ROOT / "sim/tb_passthrough.sv"]
            top = "tb_passthrough"
        else:
            files = CORE + [ROOT / "sim/tb_core.sv"]
            top = "tb_core"
        run([bindir / "xvlog", "--sv", "-i", ROOT / "sim", *files], cwd, env)
        elaborate = [bindir / "xelab", f"work.{top}", "-s", "snapshot", "-mt", "off"]
        if vendor:
            run([bindir / "xvlog", install / "data/verilog/src/glbl.v"], cwd, env)
            elaborate += ["work.glbl", "-L", "unisims_ver", "-L", "secureip"]
        run(elaborate, cwd, env)
        if args.elaborate:
            print("FPGA_VIDEO_ELABORATION_PASS")
            return
        output = run([bindir / "xsim", "snapshot", "-runall"], cwd, env)
    marker = f"FPGA_VIDEO_PASS {kind}"
    if marker not in output or "ERROR:" in output or "FATAL:" in output:
        raise RuntimeError(f"Simulation did not pass ({marker} missing or an error occurred). "
                           f"See {cwd / 'runner.log'}. XSim can exit 0 after a runtime failure.")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        sys.exit(1)
