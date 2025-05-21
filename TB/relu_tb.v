`timescale 1ns/1ps
module relu_tb;

    /* ---- parameters that must match the DUT ---- */
    localparam int NUM_CLASSES    = 4;
    localparam int FP_TOTAL_BITS  = 16;
    localparam int FP_FRAC_BITS   = 8;

    /* ---- DUT ports ---- */
    logic                             clk  = 1;
    logic                             reset;
    logic                             start;
    logic signed [FP_TOTAL_BITS-1:0]  input_vector [NUM_CLASSES];
    logic signed [FP_TOTAL_BITS-1:0]  relu_out      [NUM_CLASSES];
    logic                             done;

    /* ---- clock ---- */
    always #5 clk = ~clk;   // 100 MHz

    /* ---- instantiate the DUT ---- */
    relu #(
        .NUM_CLASSES  (NUM_CLASSES),
        .FP_TOTAL_BITS(FP_TOTAL_BITS),
        .FP_FRAC_BITS (FP_FRAC_BITS)
    ) dut (
        .clk          (clk),
        .reset        (reset),
        .start        (start),
        .input_vector (input_vector),
        .relu_out     (relu_out),
        .done         (done)
    );

    /* -------- helper tasks & functions -------- */
    function automatic bit vec_equal
        (input logic signed [FP_TOTAL_BITS-1:0] a [NUM_CLASSES],
         input logic signed [FP_TOTAL_BITS-1:0] b [NUM_CLASSES]);
        for (int i = 0; i < NUM_CLASSES; i++)
            if (a[i] !== b[i]) return 0;
        return 1;
    endfunction

    function automatic void relu_ref
        (input  logic signed [FP_TOTAL_BITS-1:0] in_vec  [NUM_CLASSES],
         output logic signed [FP_TOTAL_BITS-1:0] out_vec [NUM_CLASSES]);
        for (int i = 0; i < NUM_CLASSES; i++)
            out_vec[i] = (in_vec[i][FP_TOTAL_BITS-1]) ? '0 : in_vec[i];
    endfunction

    /* ---- temporary vectors declared **before** statements ---- */
    logic signed [FP_TOTAL_BITS-1:0] ref1     [NUM_CLASSES];
    logic signed [FP_TOTAL_BITS-1:0] ref_vec  [NUM_CLASSES];

    /* ---------------- main stimulus ---------------- */
initial begin
    /* power-on reset */
    reset = 1'b1;
    start = 1'b0;
    foreach (input_vector[i]) input_vector[i] = '0;
    #20  reset = 1'b0;
    #10;

    /* ---------- test 1: hand-crafted vector ---------- */
    input_vector[0] =  16'sd128;   // +0.500 (Q7.8)
    input_vector[1] = -16'sd256;   // -1.000
    input_vector[2] =  16'sd0;     //  0
    input_vector[3] =  16'sd768;   // +3.000
    start = 1'b1;  #10;  start = 1'b0;

	#10;

    relu_ref(input_vector, ref1);
    assert (vec_equal(relu_out, ref1))
        else $fatal("Hand-crafted vector FAILED.");
    $display("Hand-crafted vector PASS");

    /* reset DUT before next test case */
    reset = 1;
    #10;
    reset = 0;
    #10;

    /* ---------- test 2: 20 random vectors ---------- */
    repeat (20) begin
        // generate test vector
        for (int i = 0; i < NUM_CLASSES; i++)
            input_vector[i] = $urandom_range(-(1<<8)+1, (1<<8)-1);

        start = 1'b1; #10 ; start = 1'b0;
		#10

        relu_ref(input_vector, ref_vec);
        assert (vec_equal(relu_out, ref_vec))
            else $fatal("Random test FAILED at time %t", $time);

        // reset DUT after each test case
        reset = 1;
        #10;
        reset = 0;
        #10;
    end

    $display("Random tests PASS");
    $finish;
end


endmodule
