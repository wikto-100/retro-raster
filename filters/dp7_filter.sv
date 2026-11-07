`default_nettype none

// DP7: empty slot for a future filter. Passes video through unchanged.
// Same ports as every filter; see dp0_filter.sv.
module dp7_filter (
    input wire pixel_clk, reset, enable,
    input wire [10:0] x, y,
    input wire [23:0] rgb_in,
    input wire de_in, hsync_in, vsync_in,
    output reg [23:0] rgb_out = 0,
    output reg de_out = 0, hsync_out = 0, vsync_out = 0
);
    // On each clock tick, copy the pixel and timing to the outputs.
    always @(posedge pixel_clk or posedge reset) begin
        if (reset) begin
            rgb_out <= 0; de_out <= 0; hsync_out <= 0; vsync_out <= 0;
        end else begin
            // Blanking stays black. To make a filter, replace the rgb_in after
            // `enable ?` with the new color; both choices are rgb_in for now.
            rgb_out <= !de_in ? 24'b0 : enable ? rgb_in : rgb_in;
            de_out <= de_in; hsync_out <= hsync_in; vsync_out <= vsync_in;
        end
    end
endmodule

`default_nettype wire
