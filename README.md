# RetroRaster

720p HDMI pass-through on a Numato Mimas A7 V3.0 (`xc7a50tfgg484-1`) that
decodes the video to RGB pixels and re-encodes it. While DIP switch DP0 is on,
the picture is converted to grayscale.

```text
GPU HDMI OUT -> Mimas HDMI IN -> decode -> grayscale -> encode -> Mimas HDMI OUT -> monitor
                1280x720 60 Hz, 8-bit RGB
```

## Build and run

Requires Vivado (default `/opt/Xilinx/2026.1/Vivado`, override with
`VIVADO_ROOT`), Python 3, Make and OpenOCD.

```sh
make sim      # Unit test: EDID/DDC, pixel register, grayscale filter
make build    # Unit test, implement, check timing/DRC -> build/retro_raster.bit
make program  # Load build/retro_raster.bit into SRAM (not flash)
make gui      # Open the Vivado project
```

## Use

Connect the GPU to HDMI IN and the monitor to HDMI OUT. The board presents an
EDID named **RetroRaster** that offers only 1280x720 at 60 Hz; set the GPU to
that mode with 8-bit RGB. The FPGA does not scale other resolutions. On KDE,
enable mirroring if the display appears as a separate desktop.

- **DP0**: on is grayscale (BT.601 luma: 77R + 150G + 29B, /256), off is plain
  pass-through. It switches on whole frames.
- **S3**: resets everything. If the monitor shows no picture after
  programming, press S3. HDMI OUT starts 500 ms after the input locks.

## Design

| File | Role |
| --- | --- |
| `rtl/top.sv` | Clocks, hot-plug/EDID handshake, resets, pipeline |
| `rtl/edid_slave.sv` | Read-only 720p EDID at DDC address 0x50 |
| `rtl/hdmi_rx.vhd`, `rtl/hdmi_tx.vhd` | Wrappers for Digilent dvi2rgb/rgb2dvi (`vendor/`) |
| `rtl/video_register.sv` | Registers RGB/timing; output starts on a frame boundary |
| `filters/grayscale_filter.sv` | The DP0 grayscale filter |
| `constraints/mimas_a7_v3.xdc` | Pins and timing exceptions |

The transmitter uses an inverted TMDS clock pattern (`kClkSwap`), which the
tested monitor requires. Output is DVI-compatible video: no audio, HDR, VRR
or HDCP. See [docs/hardware.md](docs/hardware.md) for pins and power.
