module relu #(
    parameter int NUM_FEATURES    = 4,
    parameter int FP_TOTAL_BITS   = 16,
    parameter int FP_FRAC_BITS    = 8,
    parameter int NUM_CLASSES     = 3
)(
    input  logic clk,
    input  logic reset,
    input  logic start,

    input  logic signed [FP_TOTAL_BITS-1:0] input_vector [NUM_CLASSES],

    output logic done,
    output logic signed [FP_TOTAL_BITS-1:0] relu_out [NUM_CLASSES]
);

    int i;

    /*------------------------------------------------------------*/
    always_ff @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < NUM_CLASSES; i++)
                relu_out[i] <= '0;
            done <= 1'b0;
        end
        else if (start) begin
            for (i = 0; i < NUM_CLASSES; i++) begin
                if (input_vector[i][FP_TOTAL_BITS-1])     // sign bit = 1?
                    relu_out[i] <= '0;                    // negative → 0
                else
                    relu_out[i] <= input_vector[i];       // positive → pass through
            end
            done <= 1'b1;         // pulse for one cycle
        end
        else begin
            done <= 1'b0;         // de-assert
        end
    end

endmodule
