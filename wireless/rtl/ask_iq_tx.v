`timescale 1ns/1ps
// 1.024 MHz complex OOK at 8.192 MSPS, eight samples per PN symbol.
module ask_iq_tx(input wire clk, input wire resetn,
    output wire pn, output wire signed [11:0] tx_i, tx_q);
    reg [4:0] state = 5'b00001;
    reg [2:0] phase = 0;
    reg signed [11:0] sine, cosine;
    always @(posedge clk) begin
        if (!resetn) begin state <= 5'b00001; phase <= 0; end
        else if (phase == 7) begin
            phase <= 0; state <= {state[3:0], state[4] ^ state[2]};
        end else phase <= phase + 1'b1;
    end
    always @* begin
        case (phase)
            0: begin sine=0; cosine=1200; end
            1: begin sine=849; cosine=849; end
            2: begin sine=1200; cosine=0; end
            3: begin sine=849; cosine=-849; end
            4: begin sine=0; cosine=-1200; end
            5: begin sine=-849; cosine=-849; end
            6: begin sine=-1200; cosine=0; end
            default: begin sine=-849; cosine=849; end
        endcase
    end
    assign pn = state[4];
    assign tx_i = resetn && pn ? sine : 12'sd0;
    assign tx_q = resetn && pn ? cosine : 12'sd0;
endmodule
