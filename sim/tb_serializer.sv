`timescale 1ns/1ps
`default_nettype none

module tb_serializer;
    reg pixel_clk = 0;
    reg serial_clk = 0;
    reg rst = 1;
    reg [9:0] symbol = 0;
    wire data_p, data_n, clock_p, clock_n;
    always #20 pixel_clk = ~pixel_clk;
    always #4 serial_clk = ~serial_clk;
    tmds_serializer data_lane (
        .pixel_clk(pixel_clk), .serial_clk(serial_clk), .rst(rst),
        .symbol(symbol), .out_p(data_p), .out_n(data_n)
    );
    tmds_serializer clock_lane (
        .pixel_clk(pixel_clk), .serial_clk(serial_clk), .rst(rst),
        .symbol(10'b1111100000), .out_p(clock_p), .out_n(clock_n)
    );

    task automatic check_word(input [9:0] word);
        reg previous_clock;
        reg found_boundary;
        reg [9:0] received;
        integer bit_index;
        begin
            @(negedge pixel_clk);
            symbol = word;
            repeat (8) @(posedge pixel_clk);
            found_boundary = 0;
            while (!found_boundary) begin
                previous_clock = clock_p;
                @(serial_clk);
                #1;
                // The forwarded clock's falling edge accompanies symbol bit zero.
                found_boundary = (previous_clock === 1'b1 && clock_p === 1'b0);
            end
            received[0] = data_p;
            for (bit_index = 1; bit_index < 10; bit_index = bit_index + 1) begin
                @(serial_clk);
                #1;
                received[bit_index] = data_p;
                if (data_n !== !data_p || clock_n !== !clock_p)
                    $fatal(1, "differential output polarity mismatch");
                if (clock_p !== (bit_index >= 5))
                    $fatal(1, "forwarded clock ratio/duty mismatch");
            end
            if (received !== word)
                $fatal(1, "serializer bit order mismatch: sent %h received %h", word, received);
        end
    endtask
    initial begin
        // glbl holds GSR for 100 ns; maintain the explicit reset beyond that interval.
        repeat (6) @(negedge pixel_clk);
        rst = 0;
        check_word(10'h12d);
        check_word(10'h2d3);
        check_word(10'h003);
        check_word(10'h3fc);
        check_word(10'h000);
        check_word(10'h3ff);
        $display("FPGA_VIDEO_PASS serializer");
        $finish;
    end
    initial begin
        #20000;
        $fatal(1, "serializer test timeout");
    end
endmodule

`default_nettype wire
