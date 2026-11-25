`timescale 1ns/1ps

module tb_ask_link;
    logic clk32d768 = 1'b0;
    logic resetn = 1'b0;
    logic [1:0] sample_div = 2'd0;
    wire clk_sample = sample_div[1];
    wire sample_ce = (sample_div == 2'd1);
    wire pn_tx;
    wire signed [11:0] carrier;
    wire signed [11:0] ask;
    wire [11:0] rectified;
    wire [13:0] envelope;
    wire demod;
    wire symbol_valid;
    wire pn_decision;

    int errors = 0;
    int symbols = 0;
    int csv;
    int pass_file;
    int zero_max = 0;
    int one_min = 16383;
    int input_sample = 0;
    logic started = 1'b0;
    logic first_period [0:30];
    logic previous_bit = 1'b0;
    integer expected_carrier [0:7] = '{0, 1447, 2047, 1447, 0, -1447, -2047, -1447};
    logic sent_bits [$];

    // The FIR Compiler is clocked at 32.768 MHz and accepts one sample every
    // four clocks, exactly matching the hardware configuration.
    always #15.2587890625 clk32d768 = ~clk32d768;
    always @(posedge clk32d768) begin
        if (!resetn)
            sample_div <= 2'd0;
        else
            sample_div <= sample_div + 2'd1;
    end

    ask_mod_demod dut (
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
        .pn_decision  (pn_decision)
    );

    always @(posedge clk32d768) begin
        if (resetn && sample_ce) begin
            if (dut.fir_ready === 1'b1) begin
                started = 1'b1;
                if ($signed(carrier) !== expected_carrier[input_sample % 8])
                    $fatal(1, "Carrier phase/sample mismatch at input sample %0d", input_sample);
                if (input_sample > 0 && pn_tx != previous_bit && input_sample % 8 != 0)
                    $fatal(1, "PN transition interrupted a carrier period");
                previous_bit = pn_tx;
                if (input_sample % 8 == 0)
                    sent_bits.push_back(pn_tx);
                input_sample++;
            end else if (started) begin
                $fatal(1, "FIR stopped accepting samples");
            end
        end
    end

    initial begin
        #1000000;
        $fatal(1, "Simulation timed out before all symbols were checked");
    end

    initial begin
        csv = $fopen("ask_samples.csv", "w");
        $fdisplay(csv, "time_ps,pn_tx,carrier,ask,rectified,envelope,demod,symbol_valid");
        repeat (16) @(posedge clk32d768);
        resetn <= 1'b1;

        while (symbols < 310) begin
            @(posedge clk32d768);
            #1;
            if (sample_ce)
                $fdisplay(csv, "%0t,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                          $time, pn_tx, carrier, ask, rectified, envelope, demod, symbol_valid);

            if (ask !== (pn_tx ? carrier : 12'sd0)) begin
                $error("ASK gating mismatch at %0t", $time);
                errors++;
            end

            if (rectified !== (ask[11] ? (~ask + 12'd1) : ask)) begin
                $error("Full-wave rectifier mismatch at %0t", $time);
                errors++;
            end

            if (symbol_valid) begin
                if (symbols >= sent_bits.size())
                    $fatal(1, "RX produced a decision before TX sent the symbol");
                if (demod !== sent_bits[symbols] || pn_decision !== sent_bits[symbols]) begin
                    $error("Decision mismatch at symbol %0d", symbols);
                    errors++;
                end
                if (sent_bits[symbols] && envelope < one_min)
                    one_min = envelope;
                if (!sent_bits[symbols] && envelope > zero_max)
                    zero_max = envelope;
                if (pn_decision && envelope < 14'd900) begin
                    $error("One-symbol FIR level lacks threshold margin: %0d", envelope);
                    errors++;
                end
                if (!pn_decision && envelope > 14'd300) begin
                    $error("Zero-symbol FIR level lacks threshold margin: %0d", envelope);
                    errors++;
                end

                if (symbols < 31)
                    first_period[symbols] = pn_decision;
                else if (symbols < 62 && pn_decision !== first_period[symbols-31]) begin
                    $error("PN sequence did not repeat after 31 symbols");
                    errors++;
                end
                symbols++;
            end
        end

        $fclose(csv);
        if (errors == 0) begin
            pass_file = $fopen("ask_pass.txt", "w");
            if (!pass_file) $fatal(1, "Could not create simulation pass marker");
            $fdisplay(pass_file, "PASS: 310 symbols, 0 errors");
            $fclose(pass_file);
            $display("PASS: 310 symbols checked, PN period=31, decision errors=0");
            $display("Decision levels: 0 max=%0d, threshold=618, 1 min=%0d", zero_max, one_min);
            $finish;
        end else begin
            $fatal(1, "FAIL: %0d errors", errors);
        end
    end
endmodule
