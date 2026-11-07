# RetroRaster

Low-resolution HDMI passthrough on a Numato Mimas A7
(V3.0, `xc7a50tfgg484-1`).

```text
RTX 5070 Ti HDMI OUT -> Mimas HDMI IN -> Mimas HDMI OUT -> monitor
                         1280x720, 60 Hz
```

The board presents a small EDID (the display's supported-mode information) to the
GPU, advertising 1280x720 at 60 Hz as preferred, with 640x480 as a fallback.
The GPU sends that signal; the FPGA forwards its three video lanes and clock
through calibrated delays that compensate for unequal FPGA routes.
The monitor can scale the picture to its panel.

There is no test pattern, filter selection, frame buffer, or FPGA downscaler.
The GPU handles rendering and must send a low-resolution HDMI signal. Forcing a
higher input resolution will not convert it to 720p. This build uses
DVI-compatible RGB video over HDMI, without audio, HDR, VRR, or HDCP support.

## Build and run

Requires Vivado, Python 3, Make, and OpenOCD for programming.

```sh
make gui      # Open the project in Vivado
make sim      # Test EDID and DDC reads
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

The previously working VGA bitstream is saved locally at
`build/recovery/vga-working/mimas_hdmi_top.bit`. To restore that version:

```sh
make program BITSTREAM=build/recovery/vga-working/mimas_hdmi_top.bit
```

## Hardware

Connect the GPU to HDMI IN and the monitor to HDMI OUT, then select that monitor
input. After programming, the GPU should detect a display named **RetroRaster**.
Set the actual output signal to **1280x720 at 60 Hz**, with 8-bit RGB. VGA at
59.94/59.95 Hz remains available as a fallback. S3 resets the display handshake;
unplugging/reconnecting the monitor also triggers detection.

If HDMI shows a still desktop background, check the desktop's display layout.
KDE may configure RetroRaster as a separate desktop to the right of the main
display. Move an application onto that desktop, or select mirroring in KDE's
Display Configuration to show the main desktop through the FPGA.

For clear desktop text while mirroring, set the source display (DP-4 on this
setup) to 1280x720 and 100% scale too. Mirroring a 4K desktop into 720p still
shrinks its text. Set both outputs to 60.00 Hz to avoid a 59.94/60 Hz cadence
mismatch. Reprogramming changes the EDID; the desktop may require you
to select the HDMI mode and mirroring again.

`make build` checks EDID transactions, differential forwarding with AMD I/O
models at 742.5 Mbit/s, calibration/reset/hot-plug, FPGA timing, and DRC. It also
checks that the four forwarded lanes' relative delays stay within 0.330 ns,
including both edges and output polarities at both process corners. Cable
signal quality and GPU/monitor
compatibility still require a physical test; building does not program the board.

[Hardware notes](docs/hardware.md) cover the pinout, passthrough, and power setup.

The separate [decoded 720p checkpoint](docs/pixel-checkpoint.md) receives and
re-encodes unchanged live pixels as the foundation for filtering. Build it with
`make filter-build`; it has its own project/artifact and does not replace the
default serial-passthrough build. The tested 720p recovery image is saved at
`build/recovery/720p-working/mimas_hdmi_top.bit`.
