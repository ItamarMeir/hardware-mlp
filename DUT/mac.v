// mac.v  –  single MAC with bias and Q7.8 rounding
`timescale 1ns/1ps
module mac #(
    parameter int NUM_FEATURES  = 4,
    parameter int FP_TOTAL_BITS = 16,
    parameter int FP_FRAC_BITS  = 8
)(
    input  logic                          clk,
    input  logic                          reset,
    input  logic                          start,

    // use   “var”  to silence ModelSim’s -13314 port-kind warning
    input  var  logic signed [FP_TOTAL_BITS-1:0] x       [NUM_FEATURES],
    input       logic signed [FP_TOTAL_BITS-1:0] bias,
    input  var  logic signed [FP_TOTAL_BITS-1:0] weights [NUM_FEATURES],

    output logic signed [FP_TOTAL_BITS-1:0] mac_output,
    output logic                          done
);
    /* -------- derived widths ----------------------------------- */
    localparam int PROD_BITS   = 2*FP_TOTAL_BITS;                 // product width
    localparam int ACC_BITS    = PROD_BITS + $clog2(NUM_FEATURES);// no overflow
    localparam int ROUND_CONST = 1 << (FP_FRAC_BITS-1);           // ½-LSB

    /* -------- pipeline regs ------------------------------------ */
    logic signed [PROD_BITS-1:0] mult_r [NUM_FEATURES]; // stage-1
    logic signed [ACC_BITS-1:0]  sum_r;                 // stage-2

    typedef enum logic [1:0] {IDLE, MULT, SUM, BIAS} state_t;
    state_t state, next;

    /* --- FSM register ------------------------------------------ */
    always_ff @(posedge clk or posedge reset)
        if (reset) state <= IDLE;
        else       state <= next;

    /* --- FSM transition ---------------------------------------- */
    always_comb begin
        next = state;
        unique case (state)
            IDLE : if (start) next = MULT;
            MULT :           next = SUM;
            SUM  :           next = BIAS;
            BIAS :           next = IDLE;
        endcase
    end

    /* --- stage-1 : products ------------------------------------ */
    always_ff @(posedge clk)
        if (state == MULT)
            for (int k = 0; k < NUM_FEATURES; k++)
                mult_r[k] <= x[k] * weights[k];   // no scaling yet

    /* --- stage-2 : adder tree ---------------------------------- */
    always_ff @(posedge clk) begin
        if (state == SUM) begin
            automatic logic signed [ACC_BITS-1:0] acc = '0;
            for (int k = 0; k < NUM_FEATURES; k++)
                acc += mult_r[k];
            sum_r <= acc;
        end
    end

    /* --- stage-3 : bias + rounding ----------------------------- */
    always_ff @(posedge clk) begin
        if (state == BIAS) begin
            logic signed [ACC_BITS-1:0] tmp;
            tmp        = sum_r + (bias <<< FP_FRAC_BITS);
            mac_output <= (tmp + ROUND_CONST) >>> FP_FRAC_BITS;
        end
        if (reset || state == IDLE)
            mac_output <= '0;
    end

    /* --- done pulse ------------------------------------------- */
    always_ff @(posedge clk) begin
        if (reset) done <= 1'b0;
        else if (state == BIAS)      done <= 1'b1;   // 1-cycle pulse
		else done <= 1'b0;
	end
endmodule
