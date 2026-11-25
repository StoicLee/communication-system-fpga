`timescale 1ns/1ps
module tb_iq_width;
 reg clk=0, resetn=0; reg signed [11:0] i=0,q=0;
 wire [12:0] envelope; wire demod,valid,locked,sliced; integer f;
 always #5 clk=~clk;
 ask_iq_rx dut(clk,resetn,i,q,envelope,demod,valid,locked,sliced);
 task check_level(input signed [11:0] a, input signed [11:0] b, input integer expected);
  begin
   @(negedge clk); i=a; q=b;
   repeat(3) @(negedge clk);
   if(envelope !== expected) $fatal(1,"I=%0d Q=%0d expected=%0d envelope=%0d",a,b,expected,envelope);
  end
 endtask
 initial begin
  repeat(4) @(negedge clk); resetn=1;
  check_level(-12'sd2048,-12'sd2048,2048);
  check_level(12'sd2047,12'sd2047,2047);
  check_level(-12'sd2048,12'sd2047,2047);
  check_level(12'sd0,12'sd0,0);
  $display("PASS: 12-bit signed I/Q extremes and 13-bit envelope, no overflow");
  f=$fopen("iq_width_pass.txt","w"); $fdisplay(f,"PASS"); $fclose(f); $finish;
 end
 initial begin #3000; $fatal(1,"width test timeout"); end
endmodule
