module MLP #(
    parameter int NUM_FEATURES    = 4,
    parameter int FP_TOTAL_BITS   = 16,
    parameter int FP_FRAC_BITS    = 8,
    parameter int NUM_CLASSES     = 3
)(
    input  logic clk,
    input  logic reset,
    input  logic start,

    input  var logic signed [FP_TOTAL_BITS-1:0] x             [NUM_FEATURES],
    input  var logic signed [FP_TOTAL_BITS-1:0] hidden_bias    [NUM_FEATURES],
    input  var logic signed [FP_TOTAL_BITS-1:0] hidden_weights [NUM_FEATURES][NUM_FEATURES],

    input  var logic signed [FP_TOTAL_BITS-1:0] out_bias    [NUM_CLASSES],
    input  var logic signed [FP_TOTAL_BITS-1:0] out_weights [NUM_FEATURES][NUM_CLASSES],

    output logic signed [FP_TOTAL_BITS-1:0] mlp_out [NUM_CLASSES],   // <-- var!
    output logic done
);

    /* ---------------- internal signals ---------------- */
    logic signed [FP_TOTAL_BITS-1:0] hidden_out       [NUM_FEATURES];
    logic signed [FP_TOTAL_BITS-1:0] relu_out         [NUM_FEATURES];
    logic signed [FP_TOTAL_BITS-1:0] out_layer_output [NUM_CLASSES];

    logic hidden_done, relu_done;

    /* ---------------- hidden MAC layer ---------------- */
    layer #(
        .NUM_FEATURES   (NUM_FEATURES),
        .NUM_CLASSES    (NUM_FEATURES),       // 4->4
        .FP_TOTAL_BITS  (FP_TOTAL_BITS),
        .FP_FRAC_BITS   (FP_FRAC_BITS)
    ) hidden_layer (
        .clk        (clk),
        .reset      (reset),
        .start      (start),
        .x          (x),
        .bias       (hidden_bias),
        .weights    (hidden_weights),
        .layer_out  (hidden_out),
        .done       (hidden_done)
    );

    /* ---------------- ReLU ---------------- */
    relu #(
        .NUM_CLASSES   (NUM_FEATURES),        // same vector width
        .FP_TOTAL_BITS (FP_TOTAL_BITS),
        .FP_FRAC_BITS  (FP_FRAC_BITS)
    ) relu_after_hidden (
        .clk          (clk),
        .reset        (reset),
        .start        (hidden_done),
        .input_vector (hidden_out),
        .relu_out     (relu_out),
        .done         (relu_done)
    );

    /* ---------------- output layer (4->3) -------------- */
    layer #(
        .NUM_FEATURES   (NUM_FEATURES),
        .NUM_CLASSES    (NUM_CLASSES),
        .FP_TOTAL_BITS  (FP_TOTAL_BITS),
        .FP_FRAC_BITS   (FP_FRAC_BITS)
    ) out_layer (
        .clk        (clk),
        .reset      (reset),
        .start      (relu_done),
        .x          (relu_out),
        .bias       (out_bias),
        .weights    (out_weights),
        .layer_out  (mlp_out),
        .done       (done)
    );


	// display start and internal done signals
	// always_ff @(posedge clk) begin
	// 	if (reset) begin
	// 		$display("Resetting MLP");
	// 	end
	// 	else if (start) begin
	// 		$display("MLP started");
	// 	end
	// 	else if (hidden_done) begin
	// 		$display("Hidden layer done");
	// 		$display("Hidden layer output: ");
	// 		for (int i = 0; i < NUM_FEATURES; i++) begin
	// 			$display("%d: %d", i, hidden_out[i]);
	// 		end
	// 	end
	// 	else if (relu_done) begin
	// 		$display("ReLU done");
	// 		$display("ReLU output: ");
	// 		for (int i = 0; i < NUM_FEATURES; i++) begin
	// 			$display("%d: %d", i, relu_out[i]);
	// 		end
	// 	end
	// 	else if (done) begin
	// 		$display("Output layer done");
	// 		$display("Output layer output: ");
	// 		for (int i = 0; i < NUM_CLASSES; i++) begin
	// 			$display("%d: %d", i, out_layer_output[i]);
	// 		end
	// 	end
	// end



endmodule
