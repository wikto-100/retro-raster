`default_nettype none

module video_clocks (
    input  wire clk_100mhz,
    input  wire rst,
    output wire pixel_clk,
    output wire serial_clk,
    output wire locked
);
    wire input_clk;
    wire feedback;
    wire feedback_buf;
    wire pixel_raw;
    wire serial_raw;

    IBUF input_buffer (.I(clk_100mhz), .O(input_clk));
    // 100 / 5 * 31.5 = 630 MHz VCO, then /25 and /5.
    // The clocks are related: 25.2 MHz pixels and 126 MHz DDR serialization.
    MMCME2_BASE #(
        .CLKIN1_PERIOD(10.0), .DIVCLK_DIVIDE(5), .CLKFBOUT_MULT_F(31.5),
        .CLKOUT0_DIVIDE_F(25.0), .CLKOUT1_DIVIDE(5), .STARTUP_WAIT("FALSE")
    ) mmcm (
        .CLKIN1(input_clk), .RST(rst), .PWRDWN(1'b0),
        .CLKFBIN(feedback_buf), .CLKFBOUT(feedback), .CLKFBOUTB(),
        .CLKOUT0(pixel_raw), .CLKOUT0B(), .CLKOUT1(serial_raw), .CLKOUT1B(),
        .CLKOUT2(), .CLKOUT2B(), .CLKOUT3(), .CLKOUT3B(),
        .CLKOUT4(), .CLKOUT5(), .CLKOUT6(), .LOCKED(locked)
    );
    BUFG feedback_buffer (.I(feedback), .O(feedback_buf));
    BUFG pixel_buffer (.I(pixel_raw), .O(pixel_clk));
    BUFG serial_buffer (.I(serial_raw), .O(serial_clk));
endmodule

`default_nettype wire
