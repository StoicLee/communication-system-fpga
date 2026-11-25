`timescale 1ns / 1ps
// 教学 AD9361 单收单发接口。重复的延时器、12 位 IDDR/ODDR 用 generate 展开。
// 参数、收发边沿、四级固定延时和接收寄存器均沿用原实现。
module AD9361_1RT_FDD (
    input reset,
    output interface_ready,
    input clk200M,
    input [11:0] AD9361_P0_D,
    input AD9361_DATACLK,
    input AD9361_RX_FRAME,
    output [11:0] AD9361_RX_DAT_I,
    output [11:0] AD9361_RX_DAT_Q,
    output AD9361_RX_CLK,
    input [11:0] AD9361_TX_DAT_I,
    input [11:0] AD9361_TX_DAT_Q,
    input AD9361_TX_CLK,
    output [11:0] AD9361_P1_D,
    output AD9361_FBCLK,
    output AD9361_TX_FRAME
);
    wire AD9361_DATACLKo;
    wire [4:0] delay_clk;
    wire [11:0] rx_i, rx_q;
    IBUFG #(.IBUF_LOW_PWR("FALSE"), .IOSTANDARD("DEFAULT")) IBUFG_instA (
        .I(AD9361_DATACLK), .O(AD9361_DATACLKo)
    );
    assign delay_clk[0] = AD9361_DATACLKo;
    assign AD9361_FBCLK = AD9361_DATACLKo;
    assign AD9361_TX_FRAME = AD9361_RX_FRAME;
    BUFG inst_sample_buf (.I(delay_clk[4]), .O(AD9361_RX_CLK));

    // 200 MHz 稳定后保持校准复位 16 拍（80 ns），RDY 后允许发送。
    reg [4:0] cal_count = 5'd0;
    always @(posedge clk200M or posedge reset) begin
        if (reset) cal_count <= 5'd0;
        else if (!cal_count[4]) cal_count <= cal_count + 5'd1;
    end
    (* IODELAY_GROUP = "idelay" *)
    IDELAYCTRL IDELAYCTRL_inst (
        .RDY(interface_ready), .REFCLK(clk200M), .RST(!cal_count[4])
    );

    genvar stage, bit_index;
    generate
        for (stage = 0; stage < 4; stage = stage + 1) begin : gen_delay
            (* IODELAY_GROUP = "idelay" *)
            IDELAYE2 #(
                .CINVCTRL_SEL("FALSE"), .DELAY_SRC("DATAIN"),
                .HIGH_PERFORMANCE_MODE("FALSE"), .IDELAY_TYPE("FIXED"),
                .IDELAY_VALUE(0), .PIPE_SEL("FALSE"),
                .REFCLK_FREQUENCY(200.0), .SIGNAL_PATTERN("DATA")
            ) inst_delay (
                .DATAIN(delay_clk[stage]), .DATAOUT(delay_clk[stage+1]),
                .C(1'b1), .CE(1'b1), .CINVCTRL(1'b0), .CNTVALUEIN(5'b0),
                .CNTVALUEOUT(), .IDATAIN(1'b0), .INC(1'b1), .LD(1'b1),
                .LDPIPEEN(1'b0), .REGRST(1'b0)
            );
        end
        for (bit_index = 0; bit_index < 12; bit_index = bit_index + 1) begin : gen_data
            IDDR #(
                .DDR_CLK_EDGE("SAME_EDGE_PIPELINED"),
                .INIT_Q1(1'b0), .INIT_Q2(1'b0), .SRTYPE("SYNC")
            ) inst_rx (
                .Q1(rx_q[bit_index]), .Q2(rx_i[bit_index]),
                .C(AD9361_RX_CLK), .CE(1'b1), .D(AD9361_P0_D[bit_index]),
                .R(1'b0), .S(1'b0)
            );
            ODDR #(.DDR_CLK_EDGE("SAME_EDGE"), .INIT(1'b0), .SRTYPE("SYNC")) inst_tx (
                .Q(AD9361_P1_D[bit_index]), .C(AD9361_TX_CLK), .CE(1'b1),
                .D1(AD9361_TX_DAT_Q[bit_index]), .D2(AD9361_TX_DAT_I[bit_index]),
                .R(1'b0), .S(1'b0)
            );
        end
    endgenerate

    reg [11:0] rx_i_buf, rx_q_buf;
    always @(negedge AD9361_RX_CLK) begin
        rx_i_buf <= rx_i;
        rx_q_buf <= rx_q;
    end
    assign AD9361_RX_DAT_I = rx_i_buf;
    assign AD9361_RX_DAT_Q = rx_q_buf;
endmodule
