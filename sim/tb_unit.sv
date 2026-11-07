`timescale 1ns/1ps
`default_nettype none

// Unit test (testbench). Runs in a simulator, not on the board: it drives
// the modules' inputs, checks their outputs, and stops with $fatal on the
// first wrong value. Prints FPGA_VIDEO_PASS unit if everything matches.
// Checks: EDID reads over DDC, video_register, the filter chain.
module tb_unit;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst = 1;
    reg scl = 1, master_sda_low = 0;
    tri1 sda;
    wire sda_low;
    assign sda = (master_sda_low || sda_low) ? 1'b0 : 1'bz;
    edid_slave edid (
        .clk(clk), .rst(rst), .scl(scl), .sda(sda), .sda_low(sda_low)
    );
    `include "ddc_tasks.svh"
    reg edid_done = 0, pixels_done = 0, filter_done = 0;
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
            $fatal(1, "EDID must prefer 720p60 +H/+V");
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

    // Filter chain test: sends small frames, changes switches mid-frame, and
    // compares every output pixel with the expected filter result.
    localparam integer LATENCY = 8;
    reg ch_reset = 1;
    reg [7:0] dip = 0, model_enable = 0, model_enable_previous = 0;
    integer frames_checked = 0;
    reg [23:0] ch_rgb = 0;
    reg ch_de = 0, ch_hs = 0, ch_vs = 0, ch_vs_previous = 0;
    wire [23:0] ch_out_rgb;
    wire ch_out_de, ch_out_hs, ch_out_vs;
    filter_chain chain (
        .pixel_clk(clk), .reset(ch_reset), .enable(dip),
        .rgb_in(ch_rgb), .de_in(ch_de), .hsync_in(ch_hs), .vsync_in(ch_vs),
        .rgb_out(ch_out_rgb), .de_out(ch_out_de), .hsync_out(ch_out_hs), .vsync_out(ch_out_vs)
    );
    function automatic [23:0] gray_of(input [23:0] c);
        reg [15:0] l;
        begin
            l = 77 * c[23:16] + 150 * c[15:8] + 29 * c[7:0];
            gray_of = {3{l[15:8]}};
        end
    endfunction
    function automatic [23:0] phosphor_of(input [23:0] c, input integer row);
        reg [7:0] l;
        reg [15:0] r, g, b;
        begin
            l = gray_of(c) >> 16;
            r = l * (row % 2 ? 29 : 49);
            g = l * (row % 2 ? 146 : 242);
            b = l * (row % 2 ? 58 : 97);
            phosphor_of = {(row % 2 ? 8'd1 : 8'd2) + r[15:8],
                           (row % 2 ? 8'd8 : 8'd13) + g[15:8],
                           (row % 2 ? 8'd3 : 8'd5) + b[15:8]};
        end
    endfunction
    reg [26:0] expected [0:8191];
    integer cycle = 0;
    task automatic ch_tick(input [23:0] color, input active, h, v, input integer row);
        begin
            @(negedge clk);
            {ch_rgb, ch_de, ch_hs, ch_vs} = {color, active, h, v};
            if (v && !ch_vs_previous) begin
                if (!(model_enable & dip)) model_enable = dip & (~dip + 8'd1);
                if (frames_checked > 0 && chain.frame_enable !== model_enable_previous)
                    $fatal(1, "Active filter %b, expected %b", chain.frame_enable, model_enable_previous);
                model_enable_previous = model_enable;
                frames_checked = frames_checked + 1;
            end
            ch_vs_previous = v;
            expected[cycle] = {!active ? 24'b0 : model_enable[0] ? gray_of(color) :
                               model_enable[1] ? phosphor_of(color, row) : color,
                               active, h, v};
            @(posedge clk); #1;
            if (cycle >= LATENCY - 1 &&
                {ch_out_rgb, ch_out_de, ch_out_hs, ch_out_vs} !== expected[cycle - (LATENCY - 1)])
                $fatal(1, "Filter chain mismatch at cycle %0d: got %h expected %h", cycle,
                       {ch_out_rgb, ch_out_de, ch_out_hs, ch_out_vs}, expected[cycle - (LATENCY - 1)]);
            cycle = cycle + 1;
        end
    endtask
    reg [23:0] colors [0:7];
    task automatic ch_frame(input [7:0] switch_mid_frame);
        integer row, col;
        begin
            ch_tick(0, 0, 0, 1, 0);
            ch_tick(0, 0, 0, 0, 0);
            for (row = 0; row < 3; row = row + 1) begin
                if (row == 1) dip = switch_mid_frame;
                for (col = 0; col < 8; col = col + 1)
                    ch_tick(colors[col] ^ (row * 24'h0b1d29), 1, 0, 0, row);
                ch_tick(24'hffffff, 0, 1, 0, row);
                ch_tick(24'hffffff, 0, 0, 0, row);
            end
        end
    endtask
    initial begin
        colors[0] = 24'h000000; colors[1] = 24'hffffff; colors[2] = 24'hff0000;
        colors[3] = 24'h00ff00; colors[4] = 24'h0000ff; colors[5] = 24'h808080;
        colors[6] = 24'h123456; colors[7] = 24'hfedcba;
        if (gray_of(24'hffffff) !== 24'hffffff || gray_of(0) !== 0)
            $fatal(1, "Grayscale must keep black and white");
        repeat (5) @(negedge clk);
        ch_reset = 0;
        ch_frame(8'h00);
        ch_frame(8'h01);    // DP0 on mid-frame: grayscale from the next frame
        ch_frame(8'hff);    // all others on: DP0 keeps the picture (still gray)
        ch_frame(8'h0e);    // DP0 off: lowest still on (DP1) takes over
        ch_frame(8'h0f);    // DP0 back on while DP1 active: no effect
        ch_frame(8'h01);    // DP1-DP3 off: DP0 takes over again (gray)
        ch_frame(8'h01);
        ch_frame(8'h80);    // only DP7: DP7 active
        ch_frame(8'h81);    // DP0 on while DP7 active: no effect, not gray
        ch_frame(8'h00);
        ch_frame(8'h02);    // DP1: green phosphor with scanlines on odd rows
        ch_frame(8'h03);    // DP0 on while DP1 active: no effect
        ch_frame(8'h00);
        ch_frame(8'h00);
        if (phosphor_of(24'hffffff, 0) !== 24'h32fe65 || phosphor_of(0, 0) !== 24'h020d05)
            $fatal(1, "Phosphor endpoints changed");
        if (cycle < 100) $fatal(1, "Filter chain test too short");
        filter_done = 1;
    end
    initial begin
        wait (edid_done && pixels_done && filter_done);
        $display("FPGA_VIDEO_PASS unit");
        $finish;
    end
    initial begin
        #10000000; $fatal(1, "unit timeout");
    end
endmodule
`default_nettype wire
