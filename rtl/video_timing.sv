`default_nettype none

module video_timing (
    input  wire       clk,
    input  wire       rst,
    output reg  [9:0] x = 0,
    output reg  [9:0] y = 0,
    output wire       active,
    output wire       hsync,
    output wire       vsync,
    output wire       frame_tick
);
    // 640x480, 800x525 total. 25.2 MHz gives exactly 60 Hz.
    always @(posedge clk) begin
        if (rst) begin
            x <= 0;
            y <= 0;
        end else if (x == 799) begin
            x <= 0;
            y <= (y == 524) ? 10'd0 : y + 10'd1;
        end else begin
            x <= x + 10'd1;
        end
    end

    assign active = (x < 640) && (y < 480);
    assign hsync = !((x >= 656) && (x < 752));
    assign vsync = !((y >= 490) && (y < 492));
    assign frame_tick = (x == 799) && (y == 524);
endmodule

`default_nettype wire
