`default_nettype none

module tmds_encoder (
    input  wire       clk,
    input  wire       rst,
    input  wire       active,
    input  wire [1:0] control,
    input  wire [7:0] data,
    output reg  [9:0] symbol = 10'b1101010100
);
    reg [8:0] transition_word;
    reg use_xnor;
    integer ones_in;
    integer ones_word;
    integer i;
    reg signed [5:0] balance;
    reg signed [5:0] disparity = 0;

    always @* begin
        ones_in = 0;
        for (i = 0; i < 8; i = i + 1) ones_in = ones_in + data[i];
        use_xnor = (ones_in > 4) || ((ones_in == 4) && !data[0]);
        transition_word[0] = data[0];
        for (i = 1; i < 8; i = i + 1)
            transition_word[i] = transition_word[i-1] ^ data[i] ^ use_xnor;
        transition_word[8] = !use_xnor;
        ones_word = 0;
        for (i = 0; i < 8; i = i + 1) ones_word = ones_word + transition_word[i];
        balance = 2 * ones_word - 8;
    end

    always @(posedge clk) begin
        if (rst || !active) begin
            disparity <= 0;
            if (rst) symbol <= 10'b1101010100;
            else case (control)
                2'b00: symbol <= 10'b1101010100;
                2'b01: symbol <= 10'b0010101011;
                2'b10: symbol <= 10'b0101010100;
                2'b11: symbol <= 10'b1010101011;
            endcase
        end else if (disparity == 0 || balance == 0) begin
            symbol <= {~transition_word[8], transition_word[8],
                       (transition_word[8] ? transition_word[7:0] : ~transition_word[7:0])};
            disparity <= disparity + (transition_word[8] ? balance : -balance);
        end else if ((disparity > 0 && balance > 0) || (disparity < 0 && balance < 0)) begin
            symbol <= {1'b1, transition_word[8], ~transition_word[7:0]};
            disparity <= disparity - balance + (transition_word[8] ? 6'sd2 : 6'sd0);
        end else begin
            symbol <= {1'b0, transition_word[8], transition_word[7:0]};
            disparity <= disparity + balance - (transition_word[8] ? 6'sd0 : 6'sd2);
        end
    end
endmodule

`default_nettype wire
