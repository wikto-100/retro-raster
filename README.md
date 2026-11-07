# RetroRaster

HDMI video filters on a Numato Mimas A7 V3.0 (`xc7a50tfgg484-1`).
Input and output are 1280x720 at 60 Hz.

## Build

Requires Vivado 2026.1 (set `VIVADO_ROOT` if not in `/opt/Xilinx`), Python 3,
Make and OpenOCD.

```sh
make sim      # unit test
make build    # bitstream: build/retro_raster.bit
make program  # load into SRAM
make gui      # Vivado project
```

## Use

Set the GPU to 1280x720 60 Hz.

| Switch | Filter |
| --- | --- |
| DP0 | Grayscale |
| DP1 | Green phosphor with scanlines |
| DP2-DP7 | None yet |

The first switch turned on stays active until it is turned off.

S3 resets the board. If there is no picture after programming, press S3.

## Filters

Each filter is a module in `filters/` with one clock of latency. Inputs are
`enable` (its switch), `x`/`y` (pixel position) and the pixel.

## Notes

- Power: 12 V, P2 on pins 2-3.
- Output is DVI only.
- `vendor/digilent/`: Digilent dvi2rgb and rgb2dvi, BSD-3-Clause.
