`timescale 1ns/1ps
`default_nettype none

module tb_filter_unit;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst = 1;
    reg scl = 1, master_sda_low = 0;
    tri1 sda;
    wire sda_low;
    assign sda = (master_sda_low || sda_low) ? 1'b0 : 1'bz;
    edid_slave #(.ONLY_720P(1)) edid (
        .clk(clk), .rst(rst), .scl(scl), .sda(sda), .sda_low(sda_low)
    );
    `include "ddc_tasks.svh"
    reg edid_done = 0, pixels_done = 0, overlay_done = 0;
    reg [7:0] data [0:127];
    integer n, sum;
    initial begin
        repeat (5) @(negedge clk);
        rst = 0;
        half_period = 1250;
        begin_read(0);
        sum = 0;
        for (n = 0; n < 128; n = n + 1) begin
            i2c_read(data[n], n != 127);
            sum = sum + data[n];
        end
        i2c_stop();
        if ((sum & 255) !== 0) $fatal(1, "720p EDID checksum");
        if ({data[35], data[36], data[37]} !== 24'b0)
            $fatal(1, "Decoded pipeline advertises an established fallback mode");
        for (n = 38; n < 54; n = n + 1)
            if (data[n] !== 1) $fatal(1, "Additional standard mode advertised");
        if ({data[55], data[54]} !== 16'd7425 ||
            {data[58][7:4], data[56]} !== 12'd1280 ||
            {data[61][7:4], data[59]} !== 12'd720 || data[71] !== 8'h1e)
            $fatal(1, "Experimental EDID must prefer 720p60 +H/+V");
        if ({data[72], data[73], data[74], data[75]} !== 32'h00000010 ||
            data[126] !== 0) $fatal(1, "Fallback DTD/extension remains");
        edid_done = 1;
    end

    reg pixel_reset = 1;
    reg [23:0] rgb = 0;
    reg de = 0, hs = 0, vs = 0;
    wire [23:0] out_rgb;
    wire out_de, out_hs, out_vs;
    video_register pixels (
        .pixel_clk(clk), .reset(pixel_reset),
        .rgb_in(rgb), .de_in(de), .hsync_in(hs), .vsync_in(vs),
        .rgb_out(out_rgb), .de_out(out_de), .hsync_out(out_hs), .vsync_out(out_vs)
    );
    task automatic tick(input [23:0] color, input active, h, v, visible);
        begin
            @(negedge clk);
            {rgb, de, hs, vs} = {color, active, h, v};
            @(posedge clk); #1;
            if ({out_rgb, out_de, out_hs, out_vs} !==
                {((visible && active) ? color : 24'b0), (visible && active), h, v})
                $fatal(1, "RGB/timing registration or startup gating failed");
        end
    endtask
    integer k;
    initial begin
        repeat (5) @(negedge clk);
        pixel_reset = 0;
        tick(24'h123456, 1, 0, 0, 0); // acquisition mid-frame is suppressed
        tick(0, 0, 1, 1, 0);
        tick(0, 0, 0, 0, 1);
        tick(24'hff0000, 1, 0, 0, 1);
        tick(24'h00ff00, 1, 0, 0, 1);
        tick(24'h0000ff, 1, 0, 0, 1);
        for (k = 0; k < 2048; k = k + 1)
            tick((24'h010305*k)^24'ha55ac3, k % 17 != 0, k % 23 == 0, k % 997 == 0, 1);
        #2; pixel_reset = 1; #1;
        if ({out_rgb, out_de, out_hs, out_vs} !== 0)
            $fatal(1, "Lost-clock reset must immediately clear video without another clock");
        @(negedge clk); pixel_reset = 0;
        tick(24'habcdef, 1, 0, 0, 0);
        tick(0, 0, 0, 1, 0);
        tick(24'habcdef, 1, 0, 0, 1);
        pixels_done = 1;
    end

    // Square overlay: 8x6 active raster, 4x4 square, switch latched per frame.
    reg ov_reset = 1, ov_enable = 0;
    reg [23:0] ov_rgb = 0;
    reg ov_de = 0, ov_hs = 0, ov_vs = 0;
    wire [23:0] ov_out_rgb;
    wire ov_out_de, ov_out_hs, ov_out_vs;
    square_overlay #(.SIZE(4)) overlay (
        .pixel_clk(clk), .reset(ov_reset), .enable(ov_enable),
        .rgb_in(ov_rgb), .de_in(ov_de), .hsync_in(ov_hs), .vsync_in(ov_vs),
        .rgb_out(ov_out_rgb), .de_out(ov_out_de), .hsync_out(ov_out_hs), .vsync_out(ov_out_vs)
    );
    task automatic ov_tick(input [23:0] color, input active, h, v, input [23:0] expect_rgb);
        begin
            @(negedge clk);
            {ov_rgb, ov_de, ov_hs, ov_vs} = {color, active, h, v};
            @(posedge clk); #1;
            if ({ov_out_rgb, ov_out_de, ov_out_hs, ov_out_vs} !== {expect_rgb, active, h, v})
                $fatal(1, "Square overlay mismatch: got %h expected %h", ov_out_rgb, expect_rgb);
        end
    endtask
    task automatic ov_frame(input show);
        integer row, col;
        reg [23:0] color;
        begin
            ov_tick(0, 0, 0, 1, 0);
            ov_tick(0, 0, 0, 0, 0);
            for (row = 0; row < 6; row = row + 1) begin
                for (col = 0; col < 8; col = col + 1) begin
                    color = 24'h102030 + row * 16 + col;
                    ov_tick(color, 1, 0, 0,
                            (show && row < 4 && col < 4) ? 24'h00ff00 : color);
                end
                ov_tick(24'hffffff, 0, 1, 0, 0);
                ov_tick(24'hffffff, 0, 0, 0, 0);
            end
        end
    endtask
    initial begin
        repeat (5) @(negedge clk);
        ov_reset = 0;
        ov_frame(0);
        ov_enable = 1;          // switched mid-frame: takes effect next frame
        ov_frame(0);
        ov_frame(1);
        ov_frame(1);
        ov_enable = 0;
        ov_frame(1);
        ov_frame(0);
        overlay_done = 1;
    end
    initial begin
        wait (edid_done && pixels_done && overlay_done);
        $display("FPGA_VIDEO_PASS filter-unit");
        $finish;
    end
    initial begin
        #10000000; $fatal(1, "filter-unit timeout");
    end
endmodule
`default_nettype wire
