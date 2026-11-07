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

## How it works

The GPU sends a picture 60 times a second. Each picture (frame) is 720 lines
of 1280 pixels, sent one pixel at a time, left to right, top to bottom.
Between lines and between frames there are short pauses (blanking).

The FPGA handles one pixel per tick of the pixel clock (74.25 MHz):

1. `rtl/hdmi_rx.vhd` decodes HDMI IN into pixels.
2. `rtl/video_register.sv` holds output back until a frame starts.
3. `filters/filter_chain.sv` runs the filter chosen by the DIP switches.
4. `rtl/hdmi_tx.vhd` encodes the pixels back to HDMI OUT.

`rtl/top.sv` connects these, and also handles the handshake with the GPU
(`rtl/edid_slave.sv`).

Terms used in the code:

| Term | Meaning |
| --- | --- |
| Pixel | 24-bit color: 8 bits each of red, green, blue (0-255) |
| DE | Data enable: 1 for visible pixels, 0 during blanking |
| HSYNC / VSYNC | Pulses marking a new line / a new frame |
| TMDS | How HDMI sends each color: a fast serial bit stream |
| HPD | Hot-plug detect: a wire saying "a display is connected" |
| EDID | 128 bytes describing a display; the GPU reads it to choose a mode |
| DDC | The two-wire bus (I2C) the GPU uses to read the EDID |
| Register / flip-flop | Stores a value; updates once per clock tick |
| Synchronizer | Two flip-flops that make an outside signal safe to use |
| Bitstream | The file loaded into the FPGA to configure it |

## Filters

Each filter is a module in `filters/` and delays the pixel by one clock
tick. Its inputs are `enable` (1 while its switch is selected), `x`/`y`
(pixel position) and the pixel. To add a filter, edit one of the empty
slots `dp2_filter.sv` to `dp7_filter.sv`.

## Notes

- Power: 12 V, P2 on pins 2-3.
- Output is DVI only.
- `vendor/digilent/`: Digilent dvi2rgb and rgb2dvi, BSD-3-Clause.

## License

MIT, see `LICENSE`. Files in `vendor/digilent/` are BSD-3-Clause, see
`vendor/digilent/LICENSE`.
