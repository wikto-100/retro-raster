`default_nettype none

// Checkpoint 1: decode, register unchanged RGB/timing, re-encode. No filter yet.
module mimas_filter_top #(
    parameter integer HPD_DELAY_CYCLES = 10000000
) (
    input wire CLK1, RESET,
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
    edid_slave #(.ONLY_720P(1)) edid (
        .clk(CLK1), .rst(control_reset || !connected),
        .scl(hdmi_rx_scl), .sda(hdmi_rx_sda), .sda_low(sda_low)
    );
    assign hdmi_rx_sda = sda_low ? 1'b0 : 1'bz;

    wire pixel_clk, serial_clk, pixel_locked;
    wire [15:0] rx_debug;
    wire [23:0] rx_rgb, tx_rgb;
    wire rx_de, rx_hsync, rx_vsync, tx_de, tx_hsync, tx_vsync;
    wire core_reset = reference_reset || !connected;
    hdmi_rx receiver (
        .ref_clk(ref_clk), .reset(core_reset),
        .tmds_clk_p(hdmi_rx_clk_p), .tmds_clk_n(hdmi_rx_clk_n),
        .tmds_p(hdmi_rx_p), .tmds_n(hdmi_rx_n),
        .pixel_clk(pixel_clk), .serial_clk(serial_clk), .locked(pixel_locked),
        .rgb(rx_rgb), .de(rx_de), .hsync(rx_hsync), .vsync(rx_vsync), .debug(rx_debug)
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
        .rgb_out(tx_rgb), .de_out(tx_de), .hsync_out(tx_hsync), .vsync_out(tx_vsync)
    );
    hdmi_tx transmitter (
        .pixel_clk(pixel_clk), .serial_clk(serial_clk), .reset(video_reset_async),
        .rgb(tx_rgb), .de(tx_de), .hsync(tx_hsync), .vsync(tx_vsync),
        .tmds_clk_p(hdmi_tx_clk_p), .tmds_clk_n(hdmi_tx_clk_n),
        .tmds_p(hdmi_tx_p), .tmds_n(hdmi_tx_n)
    );
    assign hdmi_tx_rscl = 1'bz;
    assign hdmi_tx_rsda = 1'bz;
    assign hdmi_rx_cec = 1'bz;
    assign hdmi_tx_cec = 1'bz;

    reg seen_de = 0, seen_hs = 0, seen_vs = 0, seen_tx_de = 0;
    always @(posedge pixel_clk or posedge video_reset_sync[1]) begin
        if (video_reset_sync[1]) begin
            seen_de <= 0; seen_hs <= 0; seen_vs <= 0; seen_tx_de <= 0;
        end else begin
            seen_de <= seen_de || rx_de;
            seen_hs <= seen_hs || rx_hsync;
            seen_vs <= seen_vs || rx_vsync;
            seen_tx_de <= seen_tx_de || tx_de;
        end
    end
    // USER1 scan register is read-only and never controls the video pipeline.
    wire [31:0] debug_status = {8'ha7, rx_debug, seen_tx_de, seen_vs, seen_hs, seen_de,
                               video_reset_sync[1], pixel_locked, connected, ref_locked};
    hdmi_debug diagnostics (.status(debug_status));
    wire [127:0] video_status;
    video_probe probe (
        .clk(pixel_clk), .reset(video_reset_sync[1]), .de(rx_de),
        .hsync(rx_hsync), .vsync(rx_vsync), .status(video_status)
    );
    hdmi_debug #(.WIDTH(128), .CHAIN(2)) diagnostics_video (.status(video_status));
endmodule

`default_nettype wire
