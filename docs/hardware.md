# Hardware

Numato Mimas A7 V3.0, Vivado part `xc7a50tfgg484-1`.

Use external 12 V power with P2 jumpered on pins 2-3 (pins 1-2 select USB
power). Check the adapter polarity against the board marking.

## Pins

| Signal | HDMI IN | HDMI OUT | Standard |
| --- | --- | --- | --- |
| TMDS clock P / N | K4 / J4 | L3 / K3 | TMDS_33 |
| Blue P / N | K1 / J1 | B1 / A1 | TMDS_33 |
| Green P / N | M1 / L1 | E1 / D1 | TMDS_33 |
| Red P / N | P2 / N2 | G1 / F1 | TMDS_33 |
| HPD | G2 (to GPU) | B2 (from monitor) | LVCMOS33 |
| CEC / DDC SCL / DDC SDA | K2 / J2 / H2 | E2 / D2 / C2 | LVCMOS33 |

H4 is the 100 MHz clock, M2 the active-high S3 reset and B21 DIP switch DP0
(reads low when ON). All LVCMOS33. Pins follow
[Numato's V3.0 XDC](https://numato.com/download/mimas-a7-v3-0-constraints-file/).

## Handshake and clocks

Upstream HPD is asserted once the monitor's HPD and the local 200 MHz reference
(for IDELAYCTRL) have been stable for 100 ms; it never waits for incoming
video, since the GPU may wait for HPD before transmitting. The EDID is served
at DDC address 0x50; SDA is open drain. Monitor-side DDC and both CEC pins
float.

720p timing: 1650x750 total, 40-pixel HSYNC, 5-line VSYNC, both active high,
74.25 MHz pixel clock, 742.5 Mbit/s per lane. The receiver recovers the pixel
clock; a transmitter PLL derives its serial clock from it. No frame buffer and
no independent video oscillator.
