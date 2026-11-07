`default_nettype none

// DP7: placeholder, passes video through unchanged. Replace the
// `enable ? rgb_in : rgb_in` expression with the filter.
module dp7_filter (
    input wire pixel_clk, reset, enable,
    input wire [10:0] x, y, // position of rgb_in within active video
    input wire [23:0] rgb_in,
    input wire de_in, hsync_in, vsync_in,
    output reg [23:0] rgb_out = 0,
    output reg de_out = 0, hsync_out = 0, vsync_out = 0
);
    always @(posedge pixel_clk or posedge reset) begin
        if (reset) begin
            rgb_out <= 0; de_out <= 0; hsync_out <= 0; vsync_out <= 0;
        end else begin
            rgb_out <= !de_in ? 24'b0 : enable ? rgb_in : rgb_in;
            de_out <= de_in; hsync_out <= hsync_in; vsync_out <= vsync_in;
        end
    end
endmodule

`default_nettype wire
