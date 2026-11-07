`timescale 1ns/1ps
`default_nettype none
module tb_filter_tx #(parameter integer ACTIVE_LINES = 4);
    reg pixel_clk = 0;
    always #6.734 pixel_clk = ~pixel_clk;
    reg rst = 1;
    integer x = 0, y = 0, frame_number = 0;
    reg [23:0] rgb = 0;
    reg de = 0, hs = 0, vs = 0;
    function automatic [23:0] test_pixel(input integer x, y, frame_number);
        reg [7:0] r,g,b;
        begin
            r = x ^ frame_number;
            g = y;
            b = (x >> 3) ^ (y >> 2) ^ 8'ha5;
            test_pixel = {r,g,b};
        end
    endfunction

    always @(negedge pixel_clk) begin
        rgb <= test_pixel(x,y,frame_number);
        de <= x < 1280 && y < ACTIVE_LINES;
        hs <= x >= 1390 && x < 1430;
        vs <= y >= ACTIVE_LINES+5 && y < ACTIVE_LINES+10;
        x = x + 1;
        if (x == 1650) begin
            x = 0; y = y + 1;
            if (y == ACTIVE_LINES+30) begin y = 0; frame_number = frame_number+1; end
        end
    end
    wire [23:0] tx_rgb;
    wire tx_de, tx_hs, tx_vs;
    video_register pixels (
        .pixel_clk(pixel_clk), .reset(rst),
        .rgb_in(rgb), .de_in(de), .hsync_in(hs), .vsync_in(vs),
        .rgb_out(tx_rgb), .de_out(tx_de), .hsync_out(tx_hs), .vsync_out(tx_vs)
    );
    wire tx_clk_p, tx_clk_n;
    wire [2:0] tx_p, tx_n;
    hdmi_tx transmitter (
        .pixel_clk(pixel_clk), .serial_clk(1'b0), .reset(rst),
        .rgb(tx_rgb), .de(tx_de), .hsync(tx_hs), .vsync(tx_vs),
        .tmds_clk_p(tx_clk_p), .tmds_clk_n(tx_clk_n), .tmds_p(tx_p), .tmds_n(tx_n)
    );
    wire [31:0] full_frames;
    tmds_monitor #(.ACTIVE_LINES(ACTIVE_LINES)) monitor (
        .rst(rst), .enabled(!rst), .tx_clk_p(tx_clk_p),
        .tx_p(tx_p), .tx_n(tx_n), .full_frames(full_frames)
    );
    initial begin
        #300; @(negedge pixel_clk); rst = 0;
        wait (full_frames == 2);
        @(negedge pixel_clk); rst = 1;
        #320; @(negedge pixel_clk); rst = 0;
        wait (full_frames == 3);
        $display("FPGA_VIDEO_PASS filter-transmit");
        $finish;
    end
    initial begin #1000000000; $fatal(1,"transmitter test timeout"); end
endmodule
`default_nettype wire
