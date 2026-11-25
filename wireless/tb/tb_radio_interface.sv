`timescale 1ns/1ps
module tb_radio_interface;
 reg adc_clk=0, clk200=0, reset=1;
 always #61.03515625 adc_clk=~adc_clk;
 always #2.5 clk200=~clk200;
 reg [11:0] pin_rx=0, channel_q=0, channel_i=0;
 wire [11:0] pin_tx,rx_i,rx_q;
 wire fbclk,tx_frame,sample_clk,ready;
 wire signed [11:0] tx_i,tx_q; wire pn;
 wire [12:0] env; wire bit_out,valid,lock,sliced;
 reg [2:0] rst_pipe=0;
 always @(posedge sample_clk or posedge reset or negedge ready)
  if(reset || !ready) rst_pipe<=0; else rst_pipe<={rst_pipe[1:0],1'b1};
 AD9361_1RT_FDD dut(.reset(reset),.interface_ready(ready),.clk200M(clk200),
 .AD9361_P0_D(pin_rx),.AD9361_DATACLK(adc_clk),.AD9361_RX_FRAME(adc_clk),
 .AD9361_RX_DAT_I(rx_i),.AD9361_RX_DAT_Q(rx_q),.AD9361_RX_CLK(sample_clk),
 .AD9361_TX_DAT_I(tx_i),.AD9361_TX_DAT_Q(tx_q),.AD9361_TX_CLK(sample_clk),
 .AD9361_P1_D(pin_tx),.AD9361_FBCLK(fbclk),.AD9361_TX_FRAME(tx_frame));
 ask_iq_tx tx(sample_clk,rst_pipe[2],pn,tx_i,tx_q);
 ask_iq_rx rx(sample_clk,rst_pipe[2],rx_i,rx_q,env,bit_out,valid,lock,sliced);
 // Delay TX DDR pair by one whole sample, then launch receive Q/I.
 always @(posedge adc_clk) begin
    #0.2 pin_rx=channel_q;
    #1 channel_q=pin_tx;
 end
 always @(negedge adc_clk) begin
    #0.2 pin_rx=channel_i;
    #1 channel_i=pin_tx;
 end
 reg [11:0] expected_tx_i, expected_tx_q;
 integer tx_checks=0;
 always @(posedge sample_clk) begin
    expected_tx_i=tx_i; expected_tx_q=tx_q;
    #1;
    if(rst_pipe[2]) begin
      if(pin_tx !== expected_tx_q) $fatal(1,"TX DDR Q ordering mismatch");
      tx_checks=tx_checks+1;
    end
 end
 always @(negedge sample_clk) begin
    #1;
    if(rst_pipe[2]) begin
      if(pin_tx !== expected_tx_i) $fatal(1,"TX DDR I ordering mismatch");
      tx_checks=tx_checks+1;
    end
 end
 localparam [30:0] PNREF=31'b0000100101100111110001101110101;
 reg got[0:255]; integer n=0, nmatch, best; reg ok=0; integer f;
 always @(posedge sample_clk) begin
    #1;
    if (rst_pipe[2] && valid && n<256) begin got[n]=bit_out; n=n+1; end
 end
 initial begin
   repeat(20) @(negedge adc_clk); reset=0;
   wait(n==256);
   best=0;
   for(integer phase=0;phase<31;phase=phase+1) begin
     nmatch=0;
     for(integer k=0;k<256;k=k+1) if(got[k]===PNREF[30-((k+phase)%31)]) nmatch++;
     if(nmatch>best) best=nmatch;
   end
   if(best!=256) $fatal(1,"DDR loopback PN mismatch best=%0d/256",best);
   if(tx_checks<4000) $fatal(1,"insufficient DDR checks");
   if(!ready || !lock) $fatal(1,"interface or timing lock missing");
   $display("PASS: AD9361 DDR TX -> channel model -> RX -> demod, PN aligned %0d/256, TX DDR edge checks=%0d",best,tx_checks);
   f=$fopen("radio_interface_pass.txt","w"); $fdisplay(f,"PASS"); $fclose(f); ok=1; $finish;
 end
 initial begin #500000; $fatal(1,"interface timeout"); end
endmodule

