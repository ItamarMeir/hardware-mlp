module mac #(
    // --------------------------------------------------------------------
    //  Public, user-tunable parameters
    // --------------------------------------------------------------------
    parameter int NUM_INPUTS    = 784,
    parameter int FP_TOTAL_BITS = 16,
    parameter int FP_FRAC_BITS  = 8
)(
    input  logic clk,
    input  logic reset,
    input  logic start,

    input  logic signed [FP_TOTAL_BITS-1:0] x       [NUM_INPUTS],
    input  logic signed [FP_TOTAL_BITS-1:0] bias,
    input  logic signed [FP_TOTAL_BITS-1:0] weights [NUM_INPUTS],

    output logic signed [FP_TOTAL_BITS-1:0] mac_output,
    output logic done
);

    // --------------------------------------------------------------------
    //  Derived widths
    // --------------------------------------------------------------------
    localparam int PROD_BITS = 2 * FP_TOTAL_BITS;                 // full product width
    localparam int ACC_BITS  = PROD_BITS + $clog2(NUM_INPUTS);    // headroom for ∑products
    localparam int ROUND_CONST = 1 << (FP_FRAC_BITS-1);           // 0.5 LSB for rounding

    // --------------------------------------------------------------------
    //  Internal signals
    // --------------------------------------------------------------------
    logic signed [PROD_BITS-1:0] mult_out   [NUM_INPUTS]; // Q(m+?),  2·FP_FRAC_BITS frac
    logic signed [ACC_BITS-1 :0] sum_out;                 // same scale as products
    logic signed [ACC_BITS-1 :0] bias_sum_out;            // also 2·FP_FRAC_BITS frac

    logic start_sum_mult, start_sum_bias;
    int   cnt;

    // --------------------------------------------------------------------
    //  Flag mini-FSM (one-shot: mult → sum → bias)
    // --------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (reset) begin
            start_sum_mult <= 1'b0;
            start_sum_bias <= 1'b0;
            cnt            <= 0;
        end else if (start) begin
            start_sum_mult <= 1'b1;   // cycle  1
            start_sum_bias <= 1'b0;
            cnt            <= 1;
        end else begin
            cnt <= cnt + 1;
            if (cnt == 2) begin       // cycle 2
                start_sum_mult <= 1'b0;
                start_sum_bias <= 1'b1;
            end else begin
                start_sum_bias <= 1'b0;
            end
        end
    end

    // --------------------------------------------------------------------
    //    Multiply (full-precision product, no shift yet)
    // --------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (reset) begin
            for (int i = 0; i < NUM_INPUTS; i++)
                mult_out[i] <= '0;
        end else if (start) begin
            for (int i = 0; i < NUM_INPUTS; i++)
                mult_out[i] <= x[i] * weights[i];  // PROD_BITS wide, Q(2m).2n
        end
    end

    // --------------------------------------------------------------------
    //    Adder tree (single-cycle demo)
    // --------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (reset) begin
            sum_out <= '0;
        end else if (start_sum_mult) begin
            logic signed [ACC_BITS-1:0] acc = '0;
            for (int i = 0; i < NUM_INPUTS; i++)
                acc = acc + mult_out[i];          // still 2·FP_FRAC_BITS frac
            sum_out <= acc;
        end
    end

    // --------------------------------------------------------------------
    //    Add bias (bias is Qm.n → shift left by FP_FRAC_BITS)
    // --------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (reset) begin
            bias_sum_out <= '0;
            done         <= 1'b0;
        end else if (start_sum_bias) begin
            bias_sum_out <= sum_out + (bias <<< FP_FRAC_BITS); // align to 2n frac
            done         <= 1'b1;                              // pulse for 1 clk
        end else begin
            done <= 1'b0;
        end
    end

    // --------------------------------------------------------------------
    //    Round-to-nearest & rescale to Qm.n output
    // --------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (reset) begin
            mac_output <= '0;
        end else if (done) begin
            mac_output <= (bias_sum_out + $signed(ROUND_CONST)) >>> FP_FRAC_BITS;
              // ROUND_CONST is added in the same 2·n-fraction scale,
              // then we shift right by FP_FRAC_BITS to return to Qm.n
        end
    end

endmodule
