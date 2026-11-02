`default_nettype none

module moving_pattern (
    input  wire       clk,
    input  wire       rst,
    input  wire       frame_tick,
    input  wire       active,
    input  wire [9:0] x,
    input  wire [9:0] y,
    output reg  [7:0] red,
    output reg  [7:0] green,
    output reg  [7:0] blue
);
    reg [9:0] left = 80;
    reg [9:0] top = 60;
    reg backwards_x = 0;
    reg backwards_y = 0;

    // A small dim square moves once per frame, bouncing at the visible edges.
    always @(posedge clk) begin
        if (rst) begin
            left <= 80;
            top <= 60;
            backwards_x <= 0;
            backwards_y <= 0;
        end else if (frame_tick) begin
            if (left == 576) begin
                backwards_x <= 1;
                left <= left - 10'd1;
            end else if (left == 0) begin
                backwards_x <= 0;
                left <= left + 10'd1;
            end else begin
                left <= backwards_x ? left - 10'd1 : left + 10'd1;
            end
            if (top == 416) begin
                backwards_y <= 1;
                top <= top - 10'd1;
            end else if (top == 0) begin
                backwards_y <= 0;
                top <= top + 10'd1;
            end else begin
                top <= backwards_y ? top - 10'd1 : top + 10'd1;
            end
        end
    end

    always @* begin
        red = 0;
        green = 0;
        blue = 0;
        if (active && x >= left && x < left + 64 && y >= top && y < top + 64) begin
            // Moving red, green, blue, and gray quadrants; maximum code is 32/255.
            if (y < top + 32) begin
                if (x < left + 32) red = 32;
                else green = 32;
            end else begin
                if (x < left + 32) blue = 32;
                else begin
                    red = 24;
                    green = 24;
                    blue = 24;
                end
            end
        end
    end
endmodule

`default_nettype wire
