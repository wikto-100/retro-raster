# RetroRaster

HDMI video effects on a Numato Mimas A7 (V3.0, `xc7a50tfgg484-1`).

Currently outputs a dim moving test pattern at 640x480, 60 Hz. HDMI input and
live filters are next: one button will cycle through passthrough, decade-inspired
TV looks, grayscale, and other effects. See the [filter plan](docs/filter-box.md).

## Build and run

Requires Vivado, Python 3, Make, and OpenOCD for programming.

```sh
make gui      # Open the project in Vivado
make sim      # Run the video core tests
make build    # Test and build the bitstream
make program  # Load the existing bitstream into SRAM
```

Edit the files in `rtl/` and `constraints/` using your preferred editor. Vivado
references them directly. Project settings live in `scripts/project.tcl`.
VS Code tasks are included; Ctrl+Shift+B builds the bitstream.

Vivado defaults to `/opt/Xilinx/2026.1/Vivado`; set `VIVADO_ROOT` to use another
installation. `make help` lists the other targets. Use `JOBS=8` to change build
parallelism or `SIM=iverilog` to run the core tests with Icarus Verilog.

Generated files go under `build/`. The bitstream is
`build/artifacts/mimas_hdmi_top.bit`; timing and DRC reports are in
`build/reports/`. Programming does not rebuild or write SPI flash.

## Hardware

Connect the board's HDMI OUT to the monitor and select that input. S3 resets the
design. Keep OLED brightness low during testing.

[Hardware notes](docs/hardware.md) cover the pinout, video timing, and power setup.
