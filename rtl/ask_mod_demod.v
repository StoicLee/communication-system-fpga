`timescale 1ns/1ps

// 2ASK chain used by simulation and the board top. The low-pass stage is the
// Vivado FIR Compiler instance fir_lpf_ask; matlab/verify_lab4.m writes its COE.
module ask_mod_demod (
    input  wire               clk,
    input  wire               resetn,
    input  wire               sample_ce,
    output wire               pn_tx,
    output reg  signed [11:0] carrier,
    output wire signed [11:0] ask,
    output wire        [11:0] rectified,
    output reg         [13:0] envelope,
    output reg                demod,
    output reg                symbol_valid,
    output reg                pn_decision
);
    localparam [13:0] DECISION_LEVEL = 14'd618;

    reg [4:0]  tx_pn_state = 5'b00001;
    reg [4:0]  rx_pn_state = 5'b00001;
    reg [2:0]  sample_index = 3'd0;
    reg [2:0]  output_index = 3'd0;
    reg [1:0]  decision_warmup = 2'd0;

    wire [11:0] abs_ask;
    wire        fir_ready;
    wire        fir_valid;
    wire signed [31:0] fir_raw_bus;
    // FIR Compiler sign-extends its full-precision result to the AXI word.
    // Remove 15 fractional bits, then clamp negative ringing to zero.
    wire signed [31:0] fir_scaled = fir_raw_bus >>> 15;
    wire [13:0] fir_level = fir_scaled[31] ? 14'd0 : fir_scaled[13:0];

    assign pn_tx = tx_pn_state[4];
    assign ask = pn_tx ? carrier : 12'sd0;
    assign abs_ask = ask[11] ? (~ask + 12'd1) : ask;
    assign rectified = abs_ask;

    // One exact carrier period, rotated so every PN symbol boundary is a zero
    // crossing. OOK then turns on/off at zero instead of at a carrier peak,
    // removing the narrow transition spike seen in the analog ILA display.
    always @* begin
        case (sample_index)
            3'd0: carrier =  12'sd0;
            3'd1: carrier =  12'sd1447;
            3'd2: carrier =  12'sd2047;
            3'd3: carrier =  12'sd1447;
            3'd4: carrier =  12'sd0;
            3'd5: carrier = -12'sd1447;
            3'd6: carrier = -12'sd2047;
            default: carrier = -12'sd1447;
        endcase
    end

    // The 17-tap Q1.15 FIR takes one new sample at 8.192 MHz. Its clock
    // remains 32.768 MHz, giving the core four clock cycles per sample.
    fir_lpf_ask envelope_lpf (
        .aclk                 (clk),
        .aresetn              (resetn),
        .s_axis_data_tvalid   (sample_ce && fir_ready),
        .s_axis_data_tready   (fir_ready),
        .s_axis_data_tdata    ({4'd0, abs_ask}),
        .m_axis_data_tvalid   (fir_valid),
        .m_axis_data_tdata    (fir_raw_bus)
    );

    // The transmitter advances once per eight input samples. The receiver
    // counts only valid FIR outputs, so the IP pipeline latency cannot disturb
    // the symbol boundary or the PN reference used by the self-check.
    always @(posedge clk) begin
        if (!resetn) begin
            tx_pn_state    <= 5'b00001;
            rx_pn_state    <= 5'b00001;
            sample_index   <= 3'd0;
            output_index   <= 3'd0;
            decision_warmup <= 2'd0;
            envelope       <= 14'd0;
            demod          <= 1'b0;
            symbol_valid   <= 1'b0;
            pn_decision    <= 1'b0;
        end else begin
            symbol_valid <= 1'b0;
            if (sample_ce && fir_ready) begin
                if (sample_index == 3'd7) begin
                    sample_index  <= 3'd0;
                    tx_pn_state   <= {tx_pn_state[3:0], tx_pn_state[4] ^ tx_pn_state[2]};
                end else begin
                    sample_index  <= sample_index + 3'd1;
                end
            end

            if (fir_valid) begin
                envelope <= fir_level;
                // Delay 8 samples + symbol midpoint 4 = output index 12.
                // Index 12 is phase 4 of the second group of eight outputs.
                if (output_index == 3'd4) begin
                    if (decision_warmup < 2'd1) begin
                        decision_warmup <= decision_warmup + 2'd1;
                    end else begin
                        demod        <= (fir_level >= DECISION_LEVEL);
                        pn_decision  <= rx_pn_state[4];
                        symbol_valid <= 1'b1;
                        rx_pn_state  <= {rx_pn_state[3:0], rx_pn_state[4] ^ rx_pn_state[2]};
                    end
                end

                output_index <= output_index + 3'd1;
            end
        end
    end
endmodule
