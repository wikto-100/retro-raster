`default_nettype none
// Read-only USER1 JTAG status. Capture is intentionally asynchronous: software
// reads multiple times; this register has no path back into the live design.
module hdmi_debug #(
    parameter integer WIDTH = 32,
    parameter integer CHAIN = 1
) (input wire [WIDTH-1:0] status);
    wire capture, shift, drck, tdi;
    reg [WIDTH-1:0] snapshot = 0;
    BSCANE2 #(.JTAG_CHAIN(CHAIN)) scan (
        .CAPTURE(capture), .SHIFT(shift), .DRCK(drck), .TDI(tdi), .TDO(snapshot[0]),
        .RESET(), .RUNTEST(), .SEL(), .TCK(), .TMS(), .UPDATE()
    );
    always @(posedge drck) begin
        if (capture) snapshot <= status;
        else if (shift) snapshot <= {tdi, snapshot[WIDTH-1:1]};
    end
endmodule
`default_nettype wire
