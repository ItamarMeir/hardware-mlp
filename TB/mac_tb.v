`timescale 1ns/1ps
module mac_tb;

    /* ===== DUT configuration ================================= */
    localparam int NUM_FEATURES   = 4;
    localparam int FP_TOTAL_BITS  = 16;
    localparam int FP_FRAC_BITS   = 8;
    localparam int ROUND_CONST    = 1 << (FP_FRAC_BITS-1);

    /* ===== clock ============================================= */
    logic clk = 0;  always #5 clk = ~clk;    // 100 MHz

    /* ===== DUT ports ========================================= */
    logic reset, start, done;
    logic signed [FP_TOTAL_BITS-1:0] x_vec [NUM_FEATURES];
    logic signed [FP_TOTAL_BITS-1:0] w_vec [NUM_FEATURES];
    logic signed [FP_TOTAL_BITS-1:0] bias;
    logic signed [FP_TOTAL_BITS-1:0] y_dut;

    mac #(
        .NUM_FEATURES (NUM_FEATURES),
        .FP_TOTAL_BITS(FP_TOTAL_BITS),
        .FP_FRAC_BITS (FP_FRAC_BITS)
    ) dut (
        .clk        (clk),
        .reset      (reset),
        .start      (start),
        .x          (x_vec),
        .bias       (bias),
        .weights    (w_vec),
        .mac_output (y_dut),
        .done       (done)
    );

    /* ===== reference function (pure SV) ====================== */
    function automatic logic signed [FP_TOTAL_BITS-1:0] mac_ref
        (input logic signed [FP_TOTAL_BITS-1:0] xv [NUM_FEATURES],
         input logic signed [FP_TOTAL_BITS-1:0] wv [NUM_FEATURES],
         input logic signed [FP_TOTAL_BITS-1:0] b);
        logic signed [31:0] acc;  acc = 0;
        for (int k=0;k<NUM_FEATURES;k++)
            acc += xv[k] * wv[k];                 // Q(2m).2n
        acc += b <<< FP_FRAC_BITS;                // align bias
        acc += ROUND_CONST;                       // round-to-nearest
        acc  = acc >>> FP_FRAC_BITS;              // back to Qm.n
        return acc[FP_TOTAL_BITS-1:0];
    endfunction

    /* ===== helper task (must be outside initial) ============== */
    task automatic do_test
        (input string tag,
         ref   int    passed);
		logic signed [FP_TOTAL_BITS-1:0] y_ref;
        /* drive start */
        start = 1; @(posedge clk); start = 0;
        @(posedge done);

        /* compute reference and assert */
    
        y_ref = mac_ref(x_vec, w_vec, bias);

        assert (y_dut === y_ref)
            else $fatal("FAIL (%s) got=%0d exp=%0d", tag, y_dut, y_ref);

        $display("PASS (%s)  out=%0d", tag, y_dut);
        passed++;
        @(posedge clk);
    endtask

    /* ===== stimulus ========================================== */
    initial begin
        /* declare locals first */
        int unsigned seed;
        int passed;
        int rand32;

        seed   = 32'hcafe_beef;
        passed = 0;

        /* power-up reset */
        reset = 1; start = 0; repeat (2) @(posedge clk);
        reset = 0;

        /* ------------ hand-crafted vector -------------------- */
        x_vec = '{ 16'sd128, -16'sd256, 16'sd512, 16'sd0 };
        w_vec = '{ 16'sd256,  16'sd128, -16'sd64, -16'sd32 };
        bias  =  16'sd80;
        do_test("hand-crafted", passed);

        /* ------------ 20 random trials ----------------------- */
        for (int t = 1; t <= 20; t++) begin
            for (int k=0;k<NUM_FEATURES;k++) begin
				seed = $urandom(seed);
                rand32   = $urandom(seed);
                x_vec[k] = rand32[15:0];
                rand32   = $urandom(seed);
                w_vec[k] = rand32[15:0];
            end
            rand32 = $urandom(seed);
            bias   = rand32[15:0];

            do_test($sformatf("rand%0d", t), passed);
        end

        $display("All %0d tests passed.", passed);
        $finish;
    end
endmodule
