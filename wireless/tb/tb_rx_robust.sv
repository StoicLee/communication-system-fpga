`timescale 1ns/1ps
module tb_rx_robust;
 reg clk=0, resetn=0, cut=0;
 always #5 clk=~clk;
 wire pn; wire signed [11:0] ti,tq;
 wire signed [11:0] ri=cut ? 12'sd0 : ti, rq=cut ? 12'sd0 : tq;
 wire [12:0] env; wire bitout,valid,locked,sliced;
 ask_iq_tx tx(clk,resetn,pn,ti,tq);
 ask_iq_rx rx(clk,resetn,ri,rq,env,bitout,valid,locked,sliced);
 integer cycle=0,last=-1,good=0; reg [7:0] refbits=0;
 reg check_decisions=0, previously_locked=0; integer f;
 always @(posedge clk) begin
  if(resetn) refbits <= {refbits[6:0],pn};
  cycle=cycle+1;
  #1;
  if(check_decisions && locked && valid) begin
   if(last>=0 && cycle-last != 8) $fatal(1,"missed/extra decision: interval %0d",cycle-last);
   if(bitout !== refbits[4]) $fatal(1,"wrong bit at cycle %0d got %0d expected %0d",cycle,bitout,refbits[4]);
   last=cycle; good=good+1;
  end
  if(!locked) last=-1;
 end
 initial begin
  repeat(5) @(negedge clk); resetn=1;
  // A short isolated pulse is rejected and cannot acquire lock.
  cut=1; force ri=12'sd1000; repeat(2) @(negedge clk); release ri;
  repeat(20) @(negedge clk);
  if(locked || valid) $fatal(1,"short pulse acquired timing");
  cut=0; wait(locked); repeat(16) @(negedge clk); check_decisions=1;
  repeat(160) @(negedge clk);
  // Inject a two-sample fade inside a single one symbol.
  wait(pn && tx.phase==2); @(negedge clk); cut=1;
  repeat(2) @(negedge clk); cut=0;
  repeat(160) @(negedge clk);
  if(!locked || good<35) $fatal(1,"glitch disturbed lock");
  // Loss longer than maximum PN run must unlock and stop valid output.
  check_decisions=0; cut=1; repeat(80) @(negedge clk);
  if(locked || valid) $fatal(1,"receiver did not lose lock");
  repeat(24) begin
    @(negedge clk);
    if(locked || valid) $fatal(1,"receiver produced output while unlocked");
  end
  cut=0; wait(locked); repeat(8) @(negedge clk);
  last=-1; good=0; check_decisions=1;
  repeat(256) @(negedge clk);
  if(!locked || good<28) $fatal(1,"receiver did not reacquire");
  $display("PASS: short pulse rejection, 2-sample fade, 8-sample cadence, loss and reacquisition (%0d decisions)",good);
  f=$fopen("rx_robust_pass.txt","w"); $fdisplay(f,"PASS"); $fclose(f); $finish;
 end
 initial begin #30000; $fatal(1,"robustness timeout"); end
endmodule
