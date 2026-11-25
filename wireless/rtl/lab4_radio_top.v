`timescale 1ns/1ps
module lab4_radio_top(
 input wire PL_CLK_100MHz,
 input wire [11:0] AD9361_P0_D,
 input wire AD9361_DATACLK, AD9361_RX_FRAME,
 output wire [11:0] AD9361_P1_D,
 output wire AD9361_FBCLK, AD9361_TX_FRAME,
 output wire GPIO_TH1, GPIO_TH2, GPIO_TH3, GPIO_TH4
);
 wire clk200, locked_clock, sample_clk, interface_ready;
 clk_radio clocking (.clk_in1(PL_CLK_100MHz), .clk_out1(clk200), .locked(locked_clock));
 wire [11:0] rx_i, rx_q;
 wire signed [11:0] tx_i, tx_q;
 AD9361_1RT_FDD radio (
  .reset(!locked_clock), .interface_ready(interface_ready), .clk200M(clk200),
  .AD9361_P0_D(AD9361_P0_D), .AD9361_DATACLK(AD9361_DATACLK),
  .AD9361_RX_FRAME(AD9361_RX_FRAME), .AD9361_RX_DAT_I(rx_i), .AD9361_RX_DAT_Q(rx_q),
  .AD9361_RX_CLK(sample_clk), .AD9361_TX_DAT_I(tx_i), .AD9361_TX_DAT_Q(tx_q),
  .AD9361_TX_CLK(sample_clk), .AD9361_P1_D(AD9361_P1_D),
  .AD9361_FBCLK(AD9361_FBCLK), .AD9361_TX_FRAME(AD9361_TX_FRAME));
 wire async_reset = !locked_clock || !interface_ready;
 (* ASYNC_REG = "TRUE" *) reg [2:0] reset_pipe = 0;
 always @(posedge sample_clk or posedge async_reset)
  if (async_reset) reset_pipe <= 0;
  else reset_pipe <= {reset_pipe[1:0],1'b1};
 wire resetn=reset_pipe[2];
 wire pn,demod,valid,timing_locked,sliced;
 wire [12:0] envelope;
 ask_iq_tx tx(.clk(sample_clk),.resetn(resetn),.pn(pn),.tx_i(tx_i),.tx_q(tx_q));
 ask_iq_rx rx(.clk(sample_clk),.resetn(resetn),.rx_i(rx_i),.rx_q(rx_q),
  .envelope(envelope),.demod(demod),.symbol_valid(valid),.timing_locked(timing_locked),.sliced(sliced));
 ila_radio capture(.clk(sample_clk),.probe0(pn),.probe1(tx_i),.probe2(tx_q),
  .probe3(rx_i),.probe4(rx_q),.probe5(envelope),.probe6(demod),.probe7(valid),.probe8(timing_locked));
 assign GPIO_TH1=pn; assign GPIO_TH2=demod; assign GPIO_TH3=valid; assign GPIO_TH4=timing_locked;
endmodule
