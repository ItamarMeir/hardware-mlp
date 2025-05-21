// layer.v – NUM_CLASSES parallel MACs
`timescale 1ns/1ps
module layer #(
    parameter int NUM_FEATURES    = 4,
    parameter int FP_TOTAL_BITS   = 16,
    parameter int FP_FRAC_BITS    = 8,
    parameter int NUM_CLASSES     = 3
)(
    input  logic clk, reset, start,

    input  var logic signed [FP_TOTAL_BITS-1:0] x       [NUM_FEATURES],
    input      logic signed [FP_TOTAL_BITS-1:0] bias    [NUM_CLASSES],
    input  var logic signed [FP_TOTAL_BITS-1:0] weights [NUM_FEATURES][NUM_CLASSES],

    output logic signed [FP_TOTAL_BITS-1:0] layer_out [NUM_CLASSES],
    output logic done
);

    /* ----- wires from each MAC -------------------------------- */
    wire signed [FP_TOTAL_BITS-1:0] mac_out  [NUM_CLASSES];
    wire        [NUM_CLASSES-1:0]   mac_done;

    /* ----- register outputs, done = AND-reduction -------------- */
    // always_ff @(posedge clk)
    //     if (reset) begin
    //         for (int j=0;j<NUM_CLASSES;j++) layer_out[j] <= '0;
    //         done <= 1'b0;
    //     end else begin
    //         layer_out <= mac_out;
    //         done      <= &mac_done;
    //     end
	always_comb begin
		layer_out <= mac_out;
    	done      <= &mac_done;
	end 
	
    /* ----- generate MAC array --------------------------------- */
    genvar j;
    generate
        for (j=0; j<NUM_CLASSES; j++) begin : MACS
            logic signed [FP_TOTAL_BITS-1:0] w_col [NUM_FEATURES];
            always_comb
                for (int k=0;k<NUM_FEATURES;k++)
                    w_col[k] = weights[k][j];

            mac #(
                .NUM_FEATURES (NUM_FEATURES),
                .FP_TOTAL_BITS(FP_TOTAL_BITS),
                .FP_FRAC_BITS (FP_FRAC_BITS)
            ) m (
                .clk        (clk),
                .reset      (reset),
                .start      (start),
                .x          (x),
                .bias       (bias[j]),
                .weights    (w_col),
                .mac_output (mac_out[j]),
                .done       (mac_done[j])
            );
        end
    endgenerate

	// display done vector
	// always_ff @(posedge clk) begin
		
	// 		for (int j=0;j<NUM_CLASSES;j++) begin $display("mac_done[%0d] = %0d", j, mac_done[j]); $display("mac_out[%0d] = %0d", j, mac_out[j]); end
	// 		$display("start = %0d", start);
	// 		$display("done = %0d", done);
	// 		$display("NUM_CLASSES = %0d", NUM_CLASSES);
	// 		$display("NUM_FEATURES = %0d", NUM_FEATURES);
			
	// end

	/* ----- done signal ---------------------------------------- */
	// done is already generated above
	


endmodule
