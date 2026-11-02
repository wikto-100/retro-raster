`default_nettype none

module mimas_hdmi_top (
    input  wire       CLK1,
    input  wire       RESET,
    input  wire       hdmi_tx_hpd,
    output wire       hdmi_tx_clk_p,
    output wire       hdmi_tx_clk_n,
    output wire [2:0] hdmi_tx_p,
    output wire [2:0] hdmi_tx_n,
    inout  wire       hdmi_tx_cec,
    inout  wire       hdmi_tx_rscl,
    inout  wire       hdmi_tx_rsda
);
    wire pixel_clk;
    wire serial_clk;
    wire locked;
    wire pixel_rst;
    (* ASYNC_REG = "TRUE" *) reg [1:0] reset_sync = 2'b11;
    (* ASYNC_REG = "TRUE" *) reg hpd_meta = 0;
    (* ASYNC_REG = "TRUE" *) reg hpd_sync = 0;
    wire [9:0] blue_symbol;
    wire [9:0] green_symbol;
    wire [9:0] red_symbol;

    video_clocks clocks (
        .clk_100mhz(CLK1), .rst(RESET), .pixel_clk(pixel_clk),
        .serial_clk(serial_clk), .locked(locked)
    );
    // Asynchronous assertion on loss of lock, synchronous release in CLKDIV domain.
    always @(posedge pixel_clk or negedge locked) begin
        if (!locked) reset_sync <= 2'b11;
        else reset_sync <= {reset_sync[0], 1'b0};
    end
    assign pixel_rst = reset_sync[1];
    always @(posedge pixel_clk) begin
        if (pixel_rst) begin
            hpd_meta <= 0;
            hpd_sync <= 0;
        end else begin
            hpd_meta <= hdmi_tx_hpd;
            hpd_sync <= hpd_meta;
        end
    end

    video_source source (
        .clk(pixel_clk), .rst(pixel_rst || !hpd_sync),
        .x(), .y(), .active(), .hsync(), .vsync(), .red(), .green(), .blue(),
        .tmds_blue(blue_symbol), .tmds_green(green_symbol), .tmds_red(red_symbol)
    );
    tmds_serializer blue_lane (
        .pixel_clk(pixel_clk), .serial_clk(serial_clk), .rst(pixel_rst),
        .symbol(blue_symbol), .out_p(hdmi_tx_p[0]), .out_n(hdmi_tx_n[0])
    );
    tmds_serializer green_lane (
        .pixel_clk(pixel_clk), .serial_clk(serial_clk), .rst(pixel_rst),
        .symbol(green_symbol), .out_p(hdmi_tx_p[1]), .out_n(hdmi_tx_n[1])
    );
    tmds_serializer red_lane (
        .pixel_clk(pixel_clk), .serial_clk(serial_clk), .rst(pixel_rst),
        .symbol(red_symbol), .out_p(hdmi_tx_p[2]), .out_n(hdmi_tx_n[2])
    );
    tmds_serializer clock_lane (
        .pixel_clk(pixel_clk), .serial_clk(serial_clk), .rst(pixel_rst),
        .symbol(10'b1111100000), .out_p(hdmi_tx_clk_p), .out_n(hdmi_tx_clk_n)
    );

    // Fixed known video mode: no DDC transaction or CEC traffic in milestone 1.
    assign hdmi_tx_rscl = 1'bz;
    assign hdmi_tx_rsda = 1'bz;
    assign hdmi_tx_cec = 1'bz;
endmodule

`default_nettype wire
