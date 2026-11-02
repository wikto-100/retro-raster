`timescale 1ns/1ps
`default_nettype none

module tb_core;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst = 1;
    wire [9:0] x, y;
    wire active, hsync, vsync;
    wire [7:0] red, green, blue;
    wire [9:0] tx_blue, tx_green, tx_red;
    reg core_done = 0;
    reg encoder_done = 0;
    reg motion_done = 0;
    video_source dut (
        .clk(clk), .rst(rst), .x(x), .y(y), .active(active),
        .hsync(hsync), .vsync(vsync), .red(red), .green(green), .blue(blue),
        .tmds_blue(tx_blue), .tmds_green(tx_green), .tmds_red(tx_red)
    );

    function automatic [7:0] decode(input [9:0] word);
        reg [7:0] transitions;
        integer n;
        begin
            transitions = word[9] ? ~word[7:0] : word[7:0];
            decode[0] = transitions[0];
            for (n = 1; n < 8; n = n + 1)
                decode[n] = transitions[n] ^ transitions[n-1] ^ !word[8];
        end
    endfunction

    function automatic [9:0] control_word(input [1:0] bits_in);
        case (bits_in)
            0: control_word = 10'b1101010100;
            1: control_word = 10'b0010101011;
            2: control_word = 10'b0101010100;
            3: control_word = 10'b1010101011;
        endcase
    endfunction

    integer pixel, frame, expected_x, expected_y;
    integer visible_count, lit_count, hsync_count, vsync_count;
    reg was_active;
    reg [1:0] was_control;
    reg [7:0] was_red, was_green, was_blue;
    initial begin
        visible_count = 0;
        lit_count = 0;
        hsync_count = 0;
        vsync_count = 0;
        repeat (3) @(negedge clk);
        rst = 0;
        #1;
        for (pixel = 0; pixel < 2 * 800 * 525; pixel = pixel + 1) begin
            frame = pixel / (800 * 525);
            expected_x = pixel % 800;
            expected_y = (pixel / 800) % 525;
            if (x !== expected_x[9:0] || y !== expected_y[9:0])
                $fatal(1, "raster count mismatch at pixel %0d", pixel);
            if (active !== (expected_x < 640 && expected_y < 480))
                $fatal(1, "active area mismatch");
            if (hsync !== !(expected_x >= 656 && expected_x < 752))
                $fatal(1, "horizontal sync mismatch");
            if (vsync !== !(expected_y >= 490 && expected_y < 492))
                $fatal(1, "vertical sync mismatch");
            if ((^{red, green, blue}) === 1'bx || red > 32 || green > 32 || blue > 32)
                $fatal(1, "unknown or over-bright pattern pixel");
            if (active) visible_count = visible_count + 1;
            if (!hsync) hsync_count = hsync_count + 1;
            if (!vsync) vsync_count = vsync_count + 1;
            if ((red | green | blue) != 0) begin
                lit_count = lit_count + 1;
                if (!active || expected_x < 80 + frame || expected_x >= 144 + frame ||
                    expected_y < 60 + frame || expected_y >= 124 + frame)
                    $fatal(1, "moving shape escaped its expected rectangle");
            end
            if (expected_x == 799 && expected_y == 524) begin
                if (visible_count != 640 * 480 || lit_count != 64 * 64 ||
                    hsync_count != 96 * 525 || vsync_count != 2 * 800)
                    $fatal(1, "incorrect frame totals or missing pattern motion");
                visible_count = 0;
                lit_count = 0;
                hsync_count = 0;
                vsync_count = 0;
            end
            was_active = active;
            was_control = {vsync, hsync};
            was_red = red;
            was_green = green;
            was_blue = blue;
            @(posedge clk);
            #1;
            if (was_active) begin
                if (decode(tx_blue) !== was_blue || decode(tx_green) !== was_green ||
                    decode(tx_red) !== was_red)
                    $fatal(1, "encoded pixel or RGB lane mapping mismatch");
            end else if (tx_blue !== control_word(was_control) ||
                         tx_green !== control_word(0) || tx_red !== control_word(0)) begin
                $fatal(1, "blanking control or sync alignment mismatch");
            end
        end
        @(negedge clk);
        rst = 1;
        @(posedge clk);
        #1;
        if (x !== 0 || y !== 0) $fatal(1, "raster reset failed");
        core_done = 1;
    end

    reg enc_rst = 1;
    reg enc_active = 0;
    reg [1:0] enc_control = 0;
    reg [7:0] enc_data = 0;
    wire [9:0] enc_symbol;
    integer running_balance = 0;
    tmds_encoder encoder (
        .clk(clk), .rst(enc_rst), .active(enc_active), .control(enc_control),
        .data(enc_data), .symbol(enc_symbol)
    );
    task automatic blank(input [1:0] control_in);
        begin
            @(negedge clk);
            enc_active = 0;
            enc_control = control_in;
            @(posedge clk);
            #1;
            if (enc_symbol !== control_word(control_in)) $fatal(1, "TMDS control mismatch");
            running_balance = 0;
        end
    endtask
    task automatic emit(input [7:0] data_in);
        integer n, ones, transitions;
        begin
            @(negedge clk);
            enc_active = 1;
            enc_data = data_in;
            @(posedge clk);
            #1;
            if (decode(enc_symbol) !== data_in) $fatal(1, "TMDS decode mismatch for %h", data_in);
            ones = 0;
            transitions = 0;
            for (n = 0; n < 10; n = n + 1) ones = ones + enc_symbol[n];
            for (n = 1; n < 8; n = n + 1)
                if (enc_symbol[n] != enc_symbol[n-1]) transitions = transitions + 1;
            running_balance = running_balance + 2 * ones - 10;
            if (running_balance < -8 || running_balance > 8)
                $fatal(1, "unbounded TMDS running disparity: %0d", running_balance);
            if (transitions > 3) $fatal(1, "TMDS transition minimization failed");
        end
    endtask
    integer value;
    reg [7:0] random_data = 8'h57;
    initial begin
        repeat (3) @(negedge clk);
        enc_rst = 0;
        for (value = 0; value < 4; value = value + 1) blank(value[1:0]);
        blank(0); emit(8'h00);
        if (enc_symbol !== 10'h100) $fatal(1, "known black symbol mismatch");
        blank(0); emit(8'hff);
        if (enc_symbol !== 10'h200) $fatal(1, "known white symbol mismatch");
        blank(0); emit(8'h01);
        if (enc_symbol !== 10'h1ff) $fatal(1, "known 01 symbol mismatch");
        blank(0); emit(8'hfe);
        if (enc_symbol !== 10'h2ff) $fatal(1, "known fe symbol mismatch");
        for (value = 0; value < 256; value = value + 1) emit(value[7:0]);
        for (value = 0; value < 4096; value = value + 1) begin
            random_data = {random_data[6:0], random_data[7] ^ random_data[5] ^ random_data[4] ^ random_data[3]};
            emit(random_data);
        end
        blank(0);
        repeat (256) emit(8'h00);
        repeat (256) emit(8'hff);
        blank(3);
        encoder_done = 1;
    end

    // Accelerated frame ticks exercise every bounce without simulating minutes of video.
    reg motion_rst = 1;
    reg motion_tick = 0;
    reg [9:0] probe_x = 0, probe_y = 0;
    wire [7:0] probe_red, probe_green, probe_blue;
    moving_pattern motion (
        .clk(clk), .rst(motion_rst), .frame_tick(motion_tick), .active(1'b1),
        .x(probe_x), .y(probe_y), .red(probe_red), .green(probe_green), .blue(probe_blue)
    );
    integer step, ref_x = 80, ref_y = 60, dx = 1, dy = 1;
    initial begin
        repeat (3) @(negedge clk);
        motion_rst = 0;
        motion_tick = 1;
        for (step = 0; step < 2000; step = step + 1) begin
            @(posedge clk);
            if (ref_x == 576) dx = -1;
            if (ref_x == 0) dx = 1;
            if (ref_y == 416) dy = -1;
            if (ref_y == 0) dy = 1;
            ref_x = ref_x + dx;
            ref_y = ref_y + dy;
            probe_x = ref_x;
            probe_y = ref_y;
            #1;
            if (probe_red !== 32 || probe_green !== 0 || probe_blue !== 0)
                $fatal(1, "motion or edge bounce failed at step %0d", step);
            probe_x = ref_x + 63;
            probe_y = ref_y + 63;
            #1;
            if (probe_red !== 24 || probe_green !== 24 || probe_blue !== 24)
                $fatal(1, "moving shape extent failed");
            probe_x = ref_x + 64;
            #1;
            if ({probe_red, probe_green, probe_blue} !== 24'd0)
                $fatal(1, "moving shape too wide");
        end
        motion_done = 1;
    end

    initial begin
        wait(core_done && encoder_done && motion_done);
        $display("FPGA_VIDEO_PASS core");
        $finish;
    end
    initial begin
        #10000000;
        $fatal(1, "core test timeout");
    end
endmodule

`default_nettype wire
