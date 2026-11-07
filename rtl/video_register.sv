`default_nettype none

// One pixel per clock, with the same register delay for data and timing.
// Begin displaying on a frame boundary after reset/clock recovery. No storage
// of previous frames and no clock-domain crossing in the video stream.
module video_register (
    input wire pixel_clk,
    input wire reset,
    input wire [23:0] rgb_in,
    input wire de_in, hsync_in, vsync_in,
    output reg [23:0] rgb_out = 0,
    output reg de_out = 0, hsync_out = 0, vsync_out = 0
);
    reg frame_started = 0;
    reg vsync_previous = 0;
    always @(posedge pixel_clk or posedge reset) begin
        if (reset) begin
            frame_started <= 0;
            vsync_previous <= 0;
            rgb_out <= 0;
            de_out <= 0;
            hsync_out <= 0;
            vsync_out <= 0;
        end else begin
            vsync_previous <= vsync_in;
            if (vsync_in && !vsync_previous) frame_started <= 1;
            rgb_out <= (frame_started && de_in) ? rgb_in : 24'b0;
            de_out <= frame_started && de_in;
            hsync_out <= hsync_in;
            vsync_out <= vsync_in;
        end
    end
endmodule

`default_nettype wire
