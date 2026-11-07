`default_nettype none

// Forward TMDS bits without decoding or buffering frames. Calibrated input
// delays compensate for the unequal routes between the board's RX and TX pins.
module tmds_passthrough #(
    parameter integer BLUE_TAPS = 4,
    parameter integer GREEN_TAPS = 2,
    parameter integer RED_TAPS = 0,
    parameter integer CLOCK_TAPS = 8
) (
    input  wire       clk_100mhz,
    input  wire       rst,
    input  wire [3:0] in_p, // {clock, red, green, blue}
    input  wire [3:0] in_n,
    output wire [3:0] out_p,
    output wire [3:0] out_n,
    output wire       ready
);
    wire feedback, feedback_buf, ref_raw, ref_clk, locked;
    // 100 MHz * 10 / 5 = 200 MHz IDELAYCTRL reference, 1 GHz MMCM VCO.
    MMCME2_BASE #(
        .CLKIN1_PERIOD(10.0), .DIVCLK_DIVIDE(1), .CLKFBOUT_MULT_F(10.0),
        .CLKOUT0_DIVIDE_F(5.0), .STARTUP_WAIT("FALSE")
    ) reference_clock (
        .CLKIN1(clk_100mhz), .RST(rst), .PWRDWN(1'b0),
        .CLKFBIN(feedback_buf), .CLKFBOUT(feedback), .CLKFBOUTB(),
        .CLKOUT0(ref_raw), .CLKOUT0B(), .CLKOUT1(), .CLKOUT1B(),
        .CLKOUT2(), .CLKOUT2B(), .CLKOUT3(), .CLKOUT3B(),
        .CLKOUT4(), .CLKOUT5(), .CLKOUT6(), .LOCKED(locked)
    );
    BUFG feedback_buffer (.I(feedback), .O(feedback_buf));
    BUFG reference_buffer (.I(ref_raw), .O(ref_clk));

    // Hold calibration reset for 160 ns after the reference locks (>59.28 ns).
    (* ASYNC_REG = "TRUE" *) reg [31:0] calibration_reset = 32'hffffffff;
    wire reference_reset = rst || !locked;
    always @(posedge ref_clk or posedge reference_reset) begin
        if (reference_reset) calibration_reset <= 32'hffffffff;
        else calibration_reset <= {calibration_reset[30:0], 1'b0};
    end
    wire calibrated;
    (* IODELAY_GROUP = "hdmi_rx_delay" *) IDELAYCTRL calibration (
        .REFCLK(ref_clk), .RST(calibration_reset[31]), .RDY(calibrated)
    );
    assign ready = calibrated && locked && !rst;

    for (genvar lane = 0; lane < 4; lane = lane + 1) begin : lanes
        localparam integer TAPS = (lane == 0) ? BLUE_TAPS :
            (lane == 1) ? GREEN_TAPS : (lane == 2) ? RED_TAPS : CLOCK_TAPS;
        wire received, delayed;
        IBUFDS #(.IOSTANDARD("TMDS_33"), .DIFF_TERM("FALSE")) receiver (
            .I(in_p[lane]), .IB(in_n[lane]), .O(received)
        );
        // At 200 MHz each calibrated tap is about 78 ps. Include an IDELAY in
        // every lane so their base insertion delays and routing remain alike.
        (* IODELAY_GROUP = "hdmi_rx_delay" *) IDELAYE2 #(
            .DELAY_SRC("IDATAIN"), .IDELAY_TYPE("FIXED"), .IDELAY_VALUE(TAPS),
            .REFCLK_FREQUENCY(200.0), .HIGH_PERFORMANCE_MODE("TRUE"),
            .SIGNAL_PATTERN("DATA")
        ) input_delay (
            .IDATAIN(received), .DATAIN(1'b0), .DATAOUT(delayed),
            .C(1'b0), .CE(1'b0), .INC(1'b0), .LD(1'b0), .LDPIPEEN(1'b0),
            .REGRST(1'b0), .CINVCTRL(1'b0), .CNTVALUEIN(5'd0), .CNTVALUEOUT()
        );
        OBUFDS #(.IOSTANDARD("TMDS_33")) transmitter (
            .I(delayed), .O(out_p[lane]), .OB(out_n[lane])
        );
    end
endmodule

`default_nettype wire
