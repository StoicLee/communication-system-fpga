`timescale 1ns/1ps

module lab4_top (
    input  wire        PL_CLK_100MHz,
    output wire [13:0] LS_DAC1_DB,
    output wire [13:0] LS_DAC2_DB,
    output wire        LS_DAC1_CLK,
    output wire        LS_DAC2_CLK,
    output wire        LS_DAC1_WRT,
    output wire        LS_DAC2_WRT,
    output wire        LS_DAC_MODE,
    output wire        GPIO_TH1,
    output wire        GPIO_TH2,
    output wire        GPIO_TH3,
    output wire        GPIO_TH4
);
    wire clk128;
    wire clk32d768;
    wire locked128;
    wire locked32;

    clk_128M Inst_clock_128M (
        .clk_in1 (PL_CLK_100MHz),
        .clk_out1(clk128),
        .locked  (locked128)
    );

    clk_32d768M Inst_clock_32d768M (
        .clk_in1 (clk128),
        .clk_out1(clk32d768),
        .locked  (locked32)
    );

    wire clocks_locked = locked128 & locked32;
    (* ASYNC_REG = "TRUE" *) reg [4:0] reset_pipe = 5'd0;
    always @(posedge clk32d768 or negedge clocks_locked) begin
        if (!clocks_locked)
            reset_pipe <= 5'd0;
        else
            reset_pipe <= {reset_pipe[3:0], 1'b1};
    end
    wire resetn = reset_pipe[4];

    // Divide 32.768 MHz by four. The core uses the rising-edge strobe while
    // clk_sample remains available as a clean 8.192 MHz waveform for ILA.
    reg [1:0] sample_div = 2'd0;
    always @(posedge clk32d768) begin
        if (!resetn)
            sample_div <= 2'd0;
        else
            sample_div <= sample_div + 2'd1;
    end
    wire sample_ce  = (sample_div == 2'd1);
    wire clk_sample = sample_div[1];

    wire               pn_tx;
    wire signed [11:0] carrier;
    wire signed [11:0] ask;
    wire        [11:0] rectified;
    wire        [13:0] envelope;
    wire               demod;
    wire               symbol_valid;

    ask_mod_demod ask_chain (
        .clk          (clk32d768),
        .resetn       (resetn),
        .sample_ce    (sample_ce),
        .pn_tx        (pn_tx),
        .carrier      (carrier),
        .ask          (ask),
        .rectified    (rectified),
        .envelope     (envelope),
        .demod        (demod),
        .symbol_valid (symbol_valid),
        .pn_decision  ()
    );

    // Oscilloscope CH1: 2ASK waveform. CH2: recovered binary data.
    reg [13:0] dac1 = 14'h2000;
    reg [13:0] dac2 = 14'h1000;
    always @(posedge clk32d768) begin
        if (!resetn)
            dac1 <= 14'h2000;
        else if (sample_ce)
            dac1 <= {{2{ask[11]}}, ask} ^ 14'h2000;
    end

    // CH2 captures on the rising WRT edge. Launch data half a period earlier.
    always @(negedge clk32d768) begin
        if (!resetn)
            dac2 <= 14'h1000;
        else
            dac2 <= demod ? 14'h3000 : 14'h1000;
    end

    assign LS_DAC1_DB   = dac1;
    assign LS_DAC2_DB   = dac2;
    assign LS_DAC1_CLK  = clk32d768;
    assign LS_DAC2_CLK  = clk32d768;
    assign LS_DAC1_WRT  = ~clk32d768;
    assign LS_DAC2_WRT  = clk32d768;
    assign LS_DAC_MODE  = 1'b1;

    assign GPIO_TH1 = clk_sample;
    assign GPIO_TH2 = pn_tx;
    assign GPIO_TH3 = demod;
    assign GPIO_TH4 = symbol_valid;

    // Sample in the data path's clock domain to capture whole bus values.
    ila_ask ila_ask_7signals (
        .clk   (clk32d768),
        .probe0(clk_sample),
        .probe1(pn_tx),
        .probe2(carrier),
        .probe3(ask),
        .probe4(rectified),
        .probe5(envelope),
        .probe6(demod)
    );
endmodule
