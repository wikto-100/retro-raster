`default_nettype none

// Paints a solid green SIZE x SIZE square in the top-left of active video
// while `enable` is high. `enable` is asynchronous (a DIP switch): it is
// synchronized here and only sampled at each VSYNC rising edge, so the square
// appears or disappears on whole frames. One register stage for data and
// timing alike, like video_register.
module square_overlay #(
    parameter integer SIZE = 64
) (
    input wire pixel_clk,
    input wire reset,
    input wire enable,
    input wire [23:0] rgb_in,
    input wire de_in, hsync_in, vsync_in,
    output reg [23:0] rgb_out = 0,
    output reg de_out = 0, hsync_out = 0, vsync_out = 0
);
    (* ASYNC_REG = "TRUE" *) reg [1:0] enable_sync = 0;
    reg show = 0;
    reg vsync_previous = 0, de_previous = 0;
    reg [11:0] x = 0, y = 0;
    wire in_square = show && x < SIZE && y < SIZE;
    always @(posedge pixel_clk or posedge reset) begin
        if (reset) begin
            enable_sync <= 0;
            show <= 0;
            vsync_previous <= 0;
            de_previous <= 0;
            x <= 0;
            y <= 0;
            rgb_out <= 0;
            de_out <= 0;
            hsync_out <= 0;
            vsync_out <= 0;
        end else begin
            enable_sync <= {enable_sync[0], enable};
            vsync_previous <= vsync_in;
            de_previous <= de_in;
            if (vsync_in && !vsync_previous) begin
                show <= enable_sync[1];
                y <= 0;
            end else if (de_previous && !de_in && y != 12'hfff) begin
                y <= y + 1'b1;
            end
            if (de_in) x <= (x == 12'hfff) ? x : x + 1'b1;
            else x <= 0;
            rgb_out <= !de_in ? 24'b0 : in_square ? 24'h00ff00 : rgb_in;
            de_out <= de_in;
            hsync_out <= hsync_in;
            vsync_out <= vsync_in;
        end
    end
endmodule

`default_nettype wire
