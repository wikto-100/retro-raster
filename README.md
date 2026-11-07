# RetroRaster

Retro display filters for a 720p HDMI signal, on a Numato Mimas A7 V3.0
(`xc7a50tfgg484-1`). The FPGA decodes the HDMI input to RGB pixels, applies
the filter selected by the DIP switches, and re-encodes it.

```text
GPU -> HDMI IN -> decode -> filter -> encode -> HDMI OUT -> monitor
       1280x720 60 Hz, 8-bit RGB
```

## Build and run

Requires Vivado (default `/opt/Xilinx/2026.1/Vivado`, or set `VIVADO_ROOT`),
Python 3, Make and OpenOCD.

```sh
make sim      # Unit test: EDID/DDC, pixel register, filter chain
make build    # Unit test, implement, check timing/DRC -> build/retro_raster.bit
make program  # Load the bitstream into SRAM (not flash)
make gui      # Open the Vivado project
```

## Use

The board presents an EDID named **RetroRaster** offering only 1280x720 at
60 Hz; set the GPU to that mode. On KDE, enable mirroring if it appears as a
separate desktop.

| Switch | Filter |
| --- | --- |
| DP0 | Grayscale (BT.601 luma) |
| DP1 | Green phosphor terminal with scanlines |
| DP2-DP7 | Placeholders (no change) |

One filter runs at a time: the first switch turned on keeps the picture until
it is turned off, then the lowest switch still on takes over. Changes apply at
the next frame.

**S3** resets everything. After programming, the monitor may show no picture
until S3 is pressed or until it retries on its own, which can take a minute.

## Adding a filter

Edit the `rgb_out` expression in `filters/dpN_filter.sv`. Each filter gets
`enable` (its switch, frame-aligned), `x`/`y` (pixel position in the active
area) and the pixel, and must delay RGB and timing by exactly one clock.

## Notes

- Power: external 12 V with P2 on pins 2-3.
- Output is DVI-compatible video: no audio, HDR, VRR or HDCP.
- The transmitter inverts the TMDS clock pattern (`kClkSwap`), which the
  tested monitor requires.
- The Digilent dvi2rgb/rgb2dvi cores in `vendor/` are BSD-3-Clause; see
  `vendor/digilent/README.md` for the pinned revision and local patches.
