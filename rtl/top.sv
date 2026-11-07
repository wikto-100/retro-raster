`default_nettype none

// Top level: everything the FPGA does
//
// The GPU sends HDMI video to HDMI IN. 
// The receiver turns it back into pixels.
// The filter chain changes the pixels.
// The transmitter turns them into HDMI again and sends them to the monitor on HDMI OUT.
module top #(
    // 100 ms at 100 MHz: how long the monitor must be connected before we
    // tell the GPU that a display is present.
    parameter integer HPD_DELAY_CYCLES = 10000000,
    // 500 ms at 74.25 MHz: how long the input must be stable before HDMI OUT
    // is switched on, so the monitor sees one clean start.
    parameter integer TX_HOLD_CYCLES = 37125000
) (
    input wire CLK1,               // 100 MHz oscillator on the board
    input wire RESET,              // button S3, high while pressed
    input wire [7:0] dip_sw,       // DIP switches DP0-DP7, low = ON
    // HDMI IN. Each signal is a differential pair (_p/_n): one clock lane
    // and three data lanes (blue, green, red).
    input wire hdmi_rx_clk_p, hdmi_rx_clk_n,
    input wire [2:0] hdmi_rx_p, hdmi_rx_n,
    output wire hdmi_rx_hpa,       // hot-plug (HPD) to the GPU: "a display is here"
    input wire hdmi_rx_scl,        // DDC clock: the GPU reads our EDID over it
    inout wire hdmi_rx_sda,        // DDC data
    inout wire hdmi_rx_cec,        // unused
    // HDMI OUT.
    input wire hdmi_tx_hpd,        // hot-plug from the monitor
    output wire hdmi_tx_clk_p, hdmi_tx_clk_n,
    output wire [2:0] hdmi_tx_p, hdmi_tx_n,
    inout wire hdmi_tx_cec, hdmi_tx_rscl, hdmi_tx_rsda // unused
);
    // Reference clock: make 200 MHz from the board's 100 MHz.
    //
    // Why: HDMI bits arrive very fast (742.5 million per second per lane).
    // To read each bit correctly, the receiver delays each input pin by a
    // small adjustable amount so it reads in the middle of the bit, not at
    // its edge. Those delay blocks need a 200 MHz clock to keep their delay
    // steps accurate. Nothing else uses this clock.
    //
    // How: an MMCM is a clock generator built into the FPGA. It multiplies
    // the input clock and then divides it: 100 MHz x 10 = 1000 MHz, / 5 =
    // 200 MHz (CLKFBOUT_MULT_F and CLKOUT0_DIVIDE_F below). The "feedback"
    // wires loop its output back to its input so it can keep the output in
    // step. ref_locked turns 1 once the output is stable.
    //
    // BUFG: a clock buffer. It sends a clock over the dedicated clock wiring
    // that reaches the whole chip with almost no delay.
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
    // Everything is held in reset while S3 is pressed or the 200 MHz clock
    // is not stable yet.
    wire reference_reset = RESET || !ref_locked;

    // control_reset: the same reset, but released in step with CLK1.
    // Starts at 2'b11 (in reset) and shifts in 0s, so reset ends two clock
    // ticks after reference_reset ends. Logic released in step with its
    // clock starts reliably.
    (* ASYNC_REG = "TRUE" *) reg [1:0] control_reset_sync = 2'b11;
    always @(posedge CLK1 or posedge reference_reset) begin
        if (reference_reset) control_reset_sync <= 2'b11;
        else control_reset_sync <= {control_reset_sync[0], 1'b0};
    end
    wire control_reset = control_reset_sync[1];

    // Hot-plug handshake. When the monitor is connected (its HPD is high) and
    // the 200 MHz clock is stable, count to 100 ms, then set `connected`.
    // `connected` drives HPD to the GPU, which then reads our EDID and starts
    // sending video. We do not wait for video before raising HPD: the GPU
    // only sends video after it sees HPD.
    //
    // hpd_sync and ready_sync are synchronizers: signals that change at any
    // time (not in step with CLK1) pass through two flip-flops before use,
    // so the logic never sees a half-changed value.
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
        if (control_reset || !hpd_sync[1] || !ready_sync[1]) begin
            connected <= 0;
            hpd_count <= 0;
        end else if (!connected) begin
            if (hpd_count == HPD_DELAY_CYCLES - 1) connected <= 1;
            else hpd_count <= hpd_count + 1'b1;
        end
    end
    assign hdmi_rx_hpa = connected && !reference_reset;

    // EDID: a 128-byte description of the display (name, supported modes).
    // The GPU reads it over DDC (an I2C bus) to decide what to send. Ours
    // offers only 1280x720 at 60 Hz. DDC data is "open drain": a device
    // either pulls the line low or lets go of it (1'bz), never drives it high.
    wire sda_low;
    edid_slave edid (
        .clk(CLK1), .rst(control_reset || !connected),
        .scl(hdmi_rx_scl), .sda(hdmi_rx_sda), .sda_low(sda_low)
    );
    assign hdmi_rx_sda = sda_low ? 1'b0 : 1'bz;

    // Video signals, all in step with pixel_clk (74.25 MHz, one pixel per
    // tick):
    //   rgb   24-bit color, 8 bits each of red, green, blue
    //   de    "data enable": high for visible pixels, low in blanking
    //   hsync high once per line, vsync high once per frame
    // rx_* come from the receiver, reg_* from video_register, tx_* go to
    // the transmitter.
    wire pixel_clk, serial_clk, pixel_locked;
    wire [23:0] rx_rgb, reg_rgb, tx_rgb;
    wire rx_de, rx_hsync, rx_vsync, reg_de, reg_hsync, reg_vsync;
    wire tx_de, tx_hsync, tx_vsync;

    // Receiver: decodes HDMI IN into pixels, and recovers the pixel clock
    // from the HDMI clock lane. pixel_locked is high while it is decoding.
    // It is held in reset until the GPU has been told a display is present.
    wire core_reset = reference_reset || !connected;
    hdmi_rx receiver (
        .ref_clk(ref_clk), .reset(core_reset),
        .tmds_clk_p(hdmi_rx_clk_p), .tmds_clk_n(hdmi_rx_clk_n),
        .tmds_p(hdmi_rx_p), .tmds_n(hdmi_rx_n),
        .pixel_clk(pixel_clk), .serial_clk(serial_clk), .locked(pixel_locked),
        .rgb(rx_rgb), .de(rx_de), .hsync(rx_hsync), .vsync(rx_vsync), .debug()
    );

    // Video reset: on while the receiver is not decoding. Released two
    // pixel_clk ticks after it starts, like control_reset above.
    wire video_reset_async = core_reset || !pixel_locked;
    (* ASYNC_REG = "TRUE" *) reg [1:0] video_reset_sync = 2'b11;
    always @(posedge pixel_clk or posedge video_reset_async) begin
        if (video_reset_async) video_reset_sync <= 2'b11;
        else video_reset_sync <= {video_reset_sync[0], 1'b0};
    end

    // Pass pixels through a register and blank them until the first full
    // frame begins, so the output never starts mid-picture.
    video_register pixels (
        .pixel_clk(pixel_clk), .reset(video_reset_sync[1]),
        .rgb_in(rx_rgb), .de_in(rx_de), .hsync_in(rx_hsync), .vsync_in(rx_vsync),
        .rgb_out(reg_rgb), .de_out(reg_de), .hsync_out(reg_hsync), .vsync_out(reg_vsync)
    );

    // The filters. ~dip_sw flips the switches so 1 = ON.
    filter_chain filters (
        .pixel_clk(pixel_clk), .reset(video_reset_sync[1]), .enable(~dip_sw),
        .rgb_in(reg_rgb), .de_in(reg_de), .hsync_in(reg_hsync), .vsync_in(reg_vsync),
        .rgb_out(tx_rgb), .de_out(tx_de), .hsync_out(tx_hsync), .vsync_out(tx_vsync)
    );

    // Keep HDMI OUT off until video has been coming in for 500 ms. If the
    // input drops, the video reset clears the count and the wait restarts.
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

    // Transmitter: encodes the pixels back into HDMI on HDMI OUT.
    hdmi_tx transmitter (
        .pixel_clk(pixel_clk), .serial_clk(serial_clk), .reset(tx_reset),
        .rgb(tx_rgb), .de(tx_de), .hsync(tx_hsync), .vsync(tx_vsync),
        .tmds_clk_p(hdmi_tx_clk_p), .tmds_clk_n(hdmi_tx_clk_n),
        .tmds_p(hdmi_tx_p), .tmds_n(hdmi_tx_n)
    );

    // Pins we do not use are left floating (1'bz = not driven).
    assign hdmi_tx_rscl = 1'bz;
    assign hdmi_tx_rsda = 1'bz;
    assign hdmi_rx_cec = 1'bz;
    assign hdmi_tx_cec = 1'bz;
endmodule

`default_nettype wire
