`default_nettype none

module mimas_hdmi_top #(
    parameter integer HPD_DELAY_CYCLES = 10000000 // 100 ms at 100 MHz
) (
    input  wire       CLK1,
    input  wire       RESET,
    input  wire       hdmi_rx_clk_p,
    input  wire       hdmi_rx_clk_n,
    input  wire [2:0] hdmi_rx_p,
    input  wire [2:0] hdmi_rx_n,
    output wire       hdmi_rx_hpa,
    input  wire       hdmi_rx_scl,
    inout  wire       hdmi_rx_sda,
    inout  wire       hdmi_rx_cec,
    input  wire       hdmi_tx_hpd,
    output wire       hdmi_tx_clk_p,
    output wire       hdmi_tx_clk_n,
    output wire [2:0] hdmi_tx_p,
    output wire [2:0] hdmi_tx_n,
    inout  wire       hdmi_tx_cec,
    inout  wire       hdmi_tx_rscl,
    inout  wire       hdmi_tx_rsda
);
    wire [3:0] incoming_p = {hdmi_rx_clk_p, hdmi_rx_p};
    wire [3:0] incoming_n = {hdmi_rx_clk_n, hdmi_rx_n};
    wire [3:0] outgoing_p;
    wire [3:0] outgoing_n;
    assign {hdmi_tx_clk_p, hdmi_tx_p} = outgoing_p;
    assign {hdmi_tx_clk_n, hdmi_tx_n} = outgoing_n;

    wire forwarding_ready;
    tmds_passthrough forwarding (
        .clk_100mhz(CLK1), .rst(RESET), .in_p(incoming_p), .in_n(incoming_n),
        .out_p(outgoing_p), .out_n(outgoing_n), .ready(forwarding_ready)
    );

    // Advertise the fixed low-resolution display only while a monitor is present.
    (* ASYNC_REG = "TRUE" *) reg [1:0] hpd_sync = 0;
    (* ASYNC_REG = "TRUE" *) reg [1:0] ready_sync = 0;
    localparam integer COUNT_WIDTH = (HPD_DELAY_CYCLES < 2) ? 1 : $clog2(HPD_DELAY_CYCLES);
    reg [COUNT_WIDTH-1:0] hpd_count = 0;
    reg connected = 0;
    always @(posedge CLK1) begin
        if (RESET) begin
            hpd_sync <= 0;
            ready_sync <= 0;
        end else begin
            hpd_sync <= {hpd_sync[0], hdmi_tx_hpd};
            ready_sync <= {ready_sync[0], forwarding_ready};
        end
        if (RESET || !hpd_sync[1] || !ready_sync[1]) begin
            hpd_count <= 0;
            connected <= 0;
        end else if (!connected) begin
            if (hpd_count == HPD_DELAY_CYCLES - 1) connected <= 1;
            else hpd_count <= hpd_count + 1'b1;
        end
    end
    assign hdmi_rx_hpa = connected && !RESET;

    wire sda_low;
    edid_slave edid (
        .clk(CLK1), .rst(RESET || !connected),
        .scl(hdmi_rx_scl), .sda(hdmi_rx_sda), .sda_low(sda_low)
    );
    assign hdmi_rx_sda = sda_low ? 1'b0 : 1'bz;

    // The GPU reads our 720p/VGA EDID, not the monitor's native high-res modes.
    assign hdmi_tx_rscl = 1'bz;
    assign hdmi_tx_rsda = 1'bz;
    assign hdmi_rx_cec = 1'bz;
    assign hdmi_tx_cec = 1'bz;
endmodule

`default_nettype wire
