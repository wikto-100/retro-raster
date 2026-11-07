`default_nettype none

// RetroRaster: decode 720p HDMI, convert to grayscale while DIP switch DP0
// is on, re-encode to HDMI OUT.
module top #(
    parameter integer HPD_DELAY_CYCLES = 10000000,
    // HDMI OUT stays idle until the input has been locked this long (pixel
    // clocks, 500 ms at 720p), so the monitor sees one clean start.
    parameter integer TX_HOLD_CYCLES = 37125000
) (
    input wire CLK1, RESET,
    input wire dip_sw0,
    input wire hdmi_rx_clk_p, hdmi_rx_clk_n,
    input wire [2:0] hdmi_rx_p, hdmi_rx_n,
    output wire hdmi_rx_hpa,
    input wire hdmi_rx_scl,
    inout wire hdmi_rx_sda, hdmi_rx_cec,
    input wire hdmi_tx_hpd,
    output wire hdmi_tx_clk_p, hdmi_tx_clk_n,
    output wire [2:0] hdmi_tx_p, hdmi_tx_n,
    inout wire hdmi_tx_cec, hdmi_tx_rscl, hdmi_tx_rsda
);
    wire feedback, feedback_buf, ref_raw, ref_clk, ref_locked;
    MMCME2_BASE #(
        .CLKIN1_PERIOD(10.0), .DIVCLK_DIVIDE(1), .CLKFBOUT_MULT_F(10.0),
        .CLKOUT0_DIVIDE_F(5.0), .STARTUP_WAIT("FALSE")
    ) reference_clock (
        .CLKIN1(CLK1), .RST(RESET), .PWRDWN(1'b0),
        .CLKFBIN(feedback_buf), .CLKFBOUT(feedback), .CLKFBOUTB(),
        .CLKOUT0(ref_raw), .CLKOUT0B(), .CLKOUT1(), .CLKOUT1B(),
        .CLKOUT2(), .CLKOUT2B(), .CLKOUT3(), .CLKOUT3B(),
        .CLKOUT4(), .CLKOUT5(), .CLKOUT6(), .LOCKED(ref_locked)
    );
    BUFG feedback_buffer (.I(feedback), .O(feedback_buf));
    BUFG reference_buffer (.I(ref_raw), .O(ref_clk));
    // The receiver owns the IDELAYCTRL; do not add a second one for this bank.
    wire reference_reset = RESET || !ref_locked;

    // S3 asserts reset immediately, but every control register leaves reset
    // synchronously with CLK1 rather than sampling the physical button.
    (* ASYNC_REG = "TRUE" *) reg [1:0] control_reset_sync = 2'b11;
    always @(posedge CLK1 or posedge reference_reset) begin
        if (reference_reset) control_reset_sync <= 2'b11;
        else control_reset_sync <= {control_reset_sync[0], 1'b0};
    end
    wire control_reset = control_reset_sync[1];

    (* ASYNC_REG = "TRUE" *) reg [1:0] hpd_sync = 0;
    (* ASYNC_REG = "TRUE" *) reg [1:0] ready_sync = 0;
    localparam integer COUNT_WIDTH = (HPD_DELAY_CYCLES < 2) ? 1 : $clog2(HPD_DELAY_CYCLES);
    reg [COUNT_WIDTH-1:0] hpd_count = 0;
    reg connected = 0;
    always @(posedge CLK1) begin
        if (control_reset) begin
            hpd_sync <= 0;
            ready_sync <= 0;
        end else begin
            hpd_sync <= {hpd_sync[0], hdmi_tx_hpd};
            ready_sync <= {ready_sync[0], ref_locked};
        end
        // HPD depends on the local reference, never on incoming video lock:
        // the GPU may wait for HPD before starting its TMDS clock.
        if (control_reset || !hpd_sync[1] || !ready_sync[1]) begin
            connected <= 0;
            hpd_count <= 0;
        end else if (!connected) begin
            if (hpd_count == HPD_DELAY_CYCLES - 1) connected <= 1;
            else hpd_count <= hpd_count + 1'b1;
        end
    end
    assign hdmi_rx_hpa = connected && !reference_reset;
    wire sda_low;
    edid_slave edid (
        .clk(CLK1), .rst(control_reset || !connected),
        .scl(hdmi_rx_scl), .sda(hdmi_rx_sda), .sda_low(sda_low)
    );
    assign hdmi_rx_sda = sda_low ? 1'b0 : 1'bz;

    wire pixel_clk, serial_clk, pixel_locked;
    wire [23:0] rx_rgb, reg_rgb, tx_rgb;
    wire rx_de, rx_hsync, rx_vsync, reg_de, reg_hsync, reg_vsync;
    wire tx_de, tx_hsync, tx_vsync;
    wire core_reset = reference_reset || !connected;
    hdmi_rx receiver (
        .ref_clk(ref_clk), .reset(core_reset),
        .tmds_clk_p(hdmi_rx_clk_p), .tmds_clk_n(hdmi_rx_clk_n),
        .tmds_p(hdmi_rx_p), .tmds_n(hdmi_rx_n),
        .pixel_clk(pixel_clk), .serial_clk(serial_clk), .locked(pixel_locked),
        .rgb(rx_rgb), .de(rx_de), .hsync(rx_hsync), .vsync(rx_vsync), .debug()
    );
    wire video_reset_async = core_reset || !pixel_locked;
    (* ASYNC_REG = "TRUE" *) reg [1:0] video_reset_sync = 2'b11;
    always @(posedge pixel_clk or posedge video_reset_async) begin
        if (video_reset_async) video_reset_sync <= 2'b11;
        else video_reset_sync <= {video_reset_sync[0], 1'b0};
    end
    video_register pixels (
        .pixel_clk(pixel_clk), .reset(video_reset_sync[1]),
        .rgb_in(rx_rgb), .de_in(rx_de), .hsync_in(rx_hsync), .vsync_in(rx_vsync),
        .rgb_out(reg_rgb), .de_out(reg_de), .hsync_out(reg_hsync), .vsync_out(reg_vsync)
    );
    grayscale_filter filter (
        .pixel_clk(pixel_clk), .reset(video_reset_sync[1]), .enable(!dip_sw0), // DP0 reads low when ON
        .rgb_in(reg_rgb), .de_in(reg_de), .hsync_in(reg_hsync), .vsync_in(reg_vsync),
        .rgb_out(tx_rgb), .de_out(tx_de), .hsync_out(tx_hsync), .vsync_out(tx_vsync)
    );
    // Same domain as the TX input clock; lock loss resets it asynchronously,
    // so any input interruption restarts the hold-off.
    localparam integer HOLD_WIDTH = (TX_HOLD_CYCLES < 2) ? 1 : $clog2(TX_HOLD_CYCLES);
    reg [HOLD_WIDTH-1:0] tx_hold_count = 0;
    reg tx_enable = 0;
    always @(posedge pixel_clk or posedge video_reset_sync[1]) begin
        if (video_reset_sync[1]) begin
            tx_hold_count <= 0;
            tx_enable <= 0;
        end else if (!tx_enable) begin
            if (tx_hold_count == TX_HOLD_CYCLES - 1) tx_enable <= 1;
            else tx_hold_count <= tx_hold_count + 1'b1;
        end
    end
    wire tx_reset = video_reset_async || !tx_enable;
    hdmi_tx transmitter (
        .pixel_clk(pixel_clk), .serial_clk(serial_clk), .reset(tx_reset),
        .rgb(tx_rgb), .de(tx_de), .hsync(tx_hsync), .vsync(tx_vsync),
        .tmds_clk_p(hdmi_tx_clk_p), .tmds_clk_n(hdmi_tx_clk_n),
        .tmds_p(hdmi_tx_p), .tmds_n(hdmi_tx_n)
    );
    assign hdmi_tx_rscl = 1'bz;
    assign hdmi_tx_rsda = 1'bz;
    assign hdmi_rx_cec = 1'bz;
    assign hdmi_tx_cec = 1'bz;
endmodule

`default_nettype wire
