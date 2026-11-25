`timescale 1ns/1ps
// PN-specific timing recovery: the 31-bit sequence changes at least once
// every five symbols. Three consecutive comparator samples qualify an edge;
// two edges spaced near an integer number of 8-sample symbols acquire timing.
// Once acquired, decisions remain exactly eight samples apart. No transition
// for seven symbols drops lock; this is not valid for arbitrary long runs.
module ask_iq_rx #(parameter [12:0] THRESHOLD=13'd250)(
    input wire clk, input wire resetn,
    input wire signed [11:0] rx_i, rx_q,
    output reg [12:0] envelope,
    output reg demod, output reg symbol_valid,
    output reg timing_locked, output wire sliced);
    wire signed [12:0] ei = {rx_i[11],rx_i};
    wire signed [12:0] eq = {rx_q[11],rx_q};
    wire [12:0] ai = ei[12] ? -ei : ei;
    wire [12:0] aq = eq[12] ? -eq : eq;
    wire [13:0] sum_abs = {1'b0,ai} + {1'b0,aq};
    wire [12:0] magnitude = sum_abs >> 1;
    reg [12:0] previous_mag = 0;
    wire [13:0] smooth_sum = {1'b0,previous_mag} + {1'b0,magnitude};
    wire [12:0] smooth = smooth_sum >> 1;
    assign sliced = (smooth >= THRESHOLD);
    reg stable_slice = 0;
    reg [1:0] different_count = 0;
    wire qualified_edge = (sliced != stable_slice) && (different_count == 2);
    reg [2:0] phase = 0;
    reg have_edge = 0;
    reg [6:0] edge_age = 0;
    // edge_age is zero on an edge and increments on each following sample.
    // Qualified edges belonging to the PN stream are 8,16,...40 samples apart.
    wire acquisition_spacing = (edge_age >= 6 && edge_age <= 40) &&
                               ((edge_age[2:0] == 6) || (edge_age[2:0] == 7) || (edge_age[2:0] == 0));
    always @(posedge clk) begin
        if (!resetn) begin
            previous_mag <= 0; envelope <= 0; stable_slice <= 0;
            different_count <= 0; phase <= 0; have_edge <= 0; edge_age <= 0;
            timing_locked <= 0; demod <= 0; symbol_valid <= 0;
        end else begin
            previous_mag <= magnitude; envelope <= smooth; symbol_valid <= 0;
            if (sliced == stable_slice) different_count <= 0;
            else if (qualified_edge) begin
                stable_slice <= sliced; different_count <= 0;
            end else different_count <= different_count + 1'b1;

            if (qualified_edge) begin
                edge_age <= 0;
                if (!timing_locked) begin
                    if (have_edge && acquisition_spacing) begin
                        timing_locked <= 1; phase <= 0;
                    end
                    have_edge <= 1;
                end
            end else if (have_edge && edge_age < 7'd56) begin
                edge_age <= edge_age + 1'b1;
            end
            if (have_edge && !qualified_edge && edge_age == 7'd55) begin
                timing_locked <= 0; have_edge <= 0; edge_age <= 0;
            end else if (timing_locked) begin
                phase <= phase + 1'b1;
                if (phase == 3'd1) begin demod <= stable_slice; symbol_valid <= 1; end
            end
        end
    end
endmodule
