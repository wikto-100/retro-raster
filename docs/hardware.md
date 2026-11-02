# Hardware

Numato Mimas A7 V3.0, Vivado part `xc7a50tfgg484-1`
(Numato ordering code `XC7A50T-1FGG484C`).

Use external 12 V power with P2 jumpered on pins 2-3. Check the adapter polarity
against the board marking. P2 pins 1-2 select USB power.

## HDMI OUT pins

| Signal | Pin(s) | Standard |
| --- | --- | --- |
| 100 MHz clock | H4 | LVCMOS33 |
| S3 reset, active high | M2 | LVCMOS33 |
| TMDS clock P / N | L3 / K3 | TMDS_33 |
| Blue P / N | B1 / A1 | TMDS_33 |
| Green P / N | E1 / D1 | TMDS_33 |
| Red P / N | G1 / F1 | TMDS_33 |
| HPD | B2 | LVCMOS33 |
| CEC / DDC SCL / DDC SDA | E2 / D2 / C2 | LVCMOS33 |

These match [Numato's V3.0 XDC](https://numato.com/download/mimas-a7-v3-0-constraints-file/).
The [board manual](https://docs.numato.com/docs/mimas-artix-7-fpga-development-board-with-ddr-sdram-and-gigabit-ethernet/)
links to a [schematic labeled V3.1](https://docs.numato.com/wp-content/uploads/2018/06/MimasA7_V3.1_Sch.pdf).
Use the V3.0 XDC for this project's pin assignments.

## Video timing

| Axis | Active | Front porch | Sync | Back porch | Total |
| --- | --- | --- | --- | --- | --- |
| Horizontal | 640 | 16 | 96 | 48 | 800 |
| Vertical | 480 | 10 | 2 | 33 | 525 |

Both syncs are active low. The 25.2 MHz pixel clock gives exactly 60 Hz.
The MMCM runs at 630 MHz with output divides of 25 and 5, producing 25.2 MHz
pixels and a related 126 MHz serializer clock. OSERDESE2 pairs send 10-bit TMDS
symbols LSB first at 252 Mbit/s per lane. The clock lane sends five low bits
followed by five high bits.

The AORUS FO32U2P [manual](https://download.gigabyte.com/FileList/Manual/AORUS_FO32U2P_FO32U2_FO27Q3_FO32U_FO27Q2_UM_English_20240417.pdf)
lists 640x480 at 60 Hz for both HDMI inputs.

The output is DVI-compatible video. HPD is synchronized; CEC and DDC float.
Pixel and serializer clocks remain related. The constraints cover internal
FPGA timing, not the HDMI cable or receiver.

## Test pattern

A 64x64 square moves and bounces around a black background. Its red, green,
blue, and gray quadrants use RGB codes no higher than 32/255. Keep OLED
brightness low while testing.
