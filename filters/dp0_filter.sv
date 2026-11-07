`default_nettype none

// DP0: grayscale. Replaces each pixel with its brightness (luma).
//
// Every filter has the same ports:
//   enable   1 while this filter is selected
//   x, y     position of the pixel on screen
//   rgb_in   the pixel; de/hsync/vsync_in its timing signals
// and outputs the pixel and timing one clock tick later.
module dp0_filter (
    input wire pixel_clk, reset, enable,
    input wire [10:0] x, y,
    input wire [23:0] rgb_in,
    input wire de_in, hsync_in, vsync_in,
    output reg [23:0] rgb_out = 0,
    output reg de_out = 0, hsync_out = 0, vsync_out = 0
);
    // Brightness = 0.30 red + 0.59 green + 0.11 blue (the TV standard BT.601;
    // eyes are most sensitive to green). In integers: (77R + 150G + 29B) / 256.
    // The top 8 bits of the 16-bit sum are the division by 256.
    wire [15:0] luma = 8'd77 * rgb_in[23:16] + 8'd150 * rgb_in[15:8] + 8'd29 * rgb_in[7:0];
    always @(posedge pixel_clk or posedge reset) begin
        if (reset) begin
            rgb_out <= 0; de_out <= 0; hsync_out <= 0; vsync_out <= 0;
        end else begin
            // Blanking stays black. If selected, output brightness as R, G and B
            // (a gray), otherwise the pixel unchanged.
            rgb_out <= !de_in ? 24'b0 : enable ? {3{luma[15:8]}} : rgb_in;
            de_out <= de_in; hsync_out <= hsync_in; vsync_out <= vsync_in;
        end
    end
endmodule

`default_nettype wire
