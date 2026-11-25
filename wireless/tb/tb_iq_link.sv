`timescale 1ns/1ps
module tb_iq_link;
    reg clk=0, resetn=0;
    always #61.03515625 clk=~clk;
    wire pn; wire signed [11:0] tx_i,tx_q;
    ask_iq_tx tx(.clk(clk),.resetn(resetn),.pn(pn),.tx_i(tx_i),.tx_q(tx_q));
    reg signed [11:0] di[0:15],dq[0:15];
    reg [15:0] refs=0;
    integer k;
    always @(posedge clk) begin
        if (!resetn) begin
            refs <= 0;
            for(k=0;k<16;k=k+1) begin di[k]<=0; dq[k]<=0; end
        end else begin
            di[0]<=tx_i; dq[0]<=tx_q; refs<={refs[14:0],pn};
            for(k=1;k<16;k=k+1) begin di[k]<=di[k-1]; dq[k]<=dq[k-1]; end
        end
    end
    wire [12:0] env[0:4]; wire [4:0] bits,valid,locked,sliced;
    wire signed [13:0] rot_i = $signed(di[5]) - $signed(dq[5]);
    wire signed [13:0] rot_q = $signed(di[5]) + $signed(dq[5]);
    wire signed [25:0] prod_i = rot_i * 181;
    wire signed [25:0] prod_q = rot_q * 181;
    wire signed [11:0] chan_i = (prod_i >>> 8) + (refs[0] ? 12'sd35 : -12'sd35);
    wire signed [11:0] chan_q = (prod_q >>> 8) + (refs[1] ? -12'sd30 : 12'sd30);
    // independent delay, gain and phase; receiver has no TX timing input
    ask_iq_rx r0(clk,resetn,di[0],dq[0],env[0],bits[0],valid[0],locked[0],sliced[0]);
    ask_iq_rx r1(clk,resetn,di[3]>>>1,dq[3]>>>1,env[1],bits[1],valid[1],locked[1],sliced[1]);
    ask_iq_rx r2(clk,resetn,-dq[7],di[7],env[2],bits[2],valid[2],locked[2],sliced[2]);
    ask_iq_rx r3(clk,resetn,-di[11]>>>1,-dq[11]>>>1,env[3],bits[3],valid[3],locked[3],sliced[3]);
    ask_iq_rx r4(clk,resetn,chan_i,chan_q,env[4],bits[4],valid[4],locked[4],sliced[4]);
    integer checked[0:4]; integer last_valid[0:4]; integer errors=0; integer epoch=0; integer cycles=0;
    reg [4:0] expected;
    integer f;
    initial begin
      for(integer j=0;j<5;j=j+1) begin checked[j]=0; last_valid[j]=-1; end
      f=$fopen("wireless_samples.csv","w");
      $fdisplay(f,"cycle,pn,tx_i,tx_q,rx_i,rx_q,envelope,sliced,demod,valid");
      repeat(20) @(negedge clk); resetn=1;
      repeat(5000) @(negedge clk);
      resetn=0; repeat(20) @(negedge clk); resetn=1; epoch=1;
      repeat(5000) @(negedge clk);
      for(integer j=0;j<5;j=j+1) if(checked[j]<1100) $fatal(1,"insufficient checks %0d: %0d",j,checked[j]);
      if(errors) $fatal(1,"wireless link errors=%0d",errors);
      $fclose(f);
      $display("PASS: 5 channels, 2 resets, varying delay, gain, phase and bounded noise");
      $display("Decisions checked %0d %0d %0d %0d %0d, errors=0",checked[0],checked[1],checked[2],checked[3],checked[4]);
      f=$fopen("wireless_pass.txt","w"); $fdisplay(f,"PASS"); $fclose(f); $finish;
    end
    always @(posedge clk) if(!resetn) begin
        for(integer j=0;j<5;j=j+1) last_valid[j]=-1;
    end else begin
        expected={refs[5],refs[11],refs[7],refs[3],refs[0]};
        #1;
        for(integer j=0;j<5;j=j+1) if(valid[j]) begin
            checked[j]++;
            if(last_valid[j]>=0 && cycles-last_valid[j] != 8)
                $fatal(1,"case %0d invalid decision spacing: %0d samples",j,cycles-last_valid[j]);
            last_valid[j]=cycles;
            if(bits[j] !== expected[j]) begin
                $error("case %0d cycle %0d demod=%0d expected=%0d",j,cycles,bits[j],expected[j]); errors++;
            end
        end
        if(epoch==0 && cycles<600) $fdisplay(f,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",cycles,pn,$signed(tx_i),$signed(tx_q),$signed(di[3]>>>1),$signed(dq[3]>>>1),env[1],sliced[1],bits[1],valid[1]);
        cycles++;
    end
    initial begin #2000000; $fatal(1,"timeout"); end
endmodule
