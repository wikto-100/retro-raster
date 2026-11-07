`default_nettype none

// DP0: grayscale (BT.601 luma, weights sum to 256 so white stays white).
module dp0_filter (
    input wire pixel_clk, reset, enable,
    input wire [10:0] x, y, // position of rgb_in within active video
    input wire [23:0] rgb_in,
    input wire de_in, hsync_in, vsync_in,
    output reg [23:0] rgb_out = 0,
    output reg de_out = 0, hsync_out = 0, vsync_out = 0
);
    wire [15:0] luma = 8'd77 * rgb_in[23:16] + 8'd150 * rgb_in[15:8] + 8'd29 * rgb_in[7:0];
    always @(posedge pixel_clk or posedge reset) begin
        if (reset) begin
            rgb_out <= 0; de_out <= 0; hsync_out <= 0; vsync_out <= 0;
        end else begin
            rgb_out <= !de_in ? 24'b0 : enable ? {3{luma[15:8]}} : rgb_in;
            de_out <= de_in; hsync_out <= hsync_in; vsync_out <= vsync_in;
        end
    end
endmodule

`default_nettype wire
