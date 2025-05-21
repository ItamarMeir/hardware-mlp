`timescale 1ns/1ps
module mlp_tb;
	localparam int CYCLE = 10; // 100 MHz
    /* ----- DUT parameters ------------------------------------- */
    localparam int NUM_FEATURES   = 4;
    localparam int NUM_CLASSES    = 3;
    localparam int FP_TOTAL_BITS  = 16;
    localparam int FP_FRAC_BITS   = 8;

    /* ----- 100-MHz clock -------------------------------------- */
    logic clk = 0; always #5 clk = ~clk;

    /* ----- DUT signals ---------------------------------------- */
    logic reset, start, done;
    logic signed [FP_TOTAL_BITS-1:0] x           [NUM_FEATURES];
    logic signed [FP_TOTAL_BITS-1:0] hid_bias    [NUM_FEATURES];
    logic signed [FP_TOTAL_BITS-1:0] hid_w       [NUM_FEATURES][NUM_FEATURES];
    logic signed [FP_TOTAL_BITS-1:0] out_bias    [NUM_CLASSES];
    logic signed [FP_TOTAL_BITS-1:0] out_w       [NUM_FEATURES][NUM_CLASSES];
    logic signed [FP_TOTAL_BITS-1:0] y           [NUM_CLASSES];

    /* ---------------- MLP instance ---------------- */
MLP #(
    .NUM_FEATURES (NUM_FEATURES),
    .NUM_CLASSES  (NUM_CLASSES),
    .FP_TOTAL_BITS(FP_TOTAL_BITS),
    .FP_FRAC_BITS (FP_FRAC_BITS)
) dut (
    .clk            (clk),
    .reset          (reset),
    .start          (start),
    .x              (x),

    .hidden_bias    (hid_bias),        // explicit mapping
    .hidden_weights (hid_w),

    .out_bias       (out_bias),
    .out_weights    (out_w),

    .mlp_out        (y),               // explicit mapping
    .done           (done)
);


    /* ----- file buffers --------------------------------------- */
    bit [8*NUM_FEATURES*NUM_FEATURES*2-1:0] raw_whid = '0;
    bit [8*NUM_FEATURES*2-1:0]             raw_bhid = '0;
    bit [8*NUM_FEATURES*NUM_CLASSES*2-1:0] raw_wout = '0;
    bit [8*NUM_CLASSES*2-1:0]              raw_bout = '0;
    bit [8*NUM_FEATURES*60-1:0]            raw_x    = '0;
    byte unsigned                          raw_y [0:59];

    logic signed [15:0] w_in_flat  [NUM_FEATURES*NUM_FEATURES-1:0];
    logic signed [15:0] w_out_flat [NUM_FEATURES*NUM_CLASSES-1:0];
    logic signed [15:0] b_hid_flat [NUM_FEATURES-1:0];
    logic signed [15:0] b_out_flat [NUM_CLASSES-1:0];
    logic signed [15:0] x_flat     [NUM_FEATURES-1:0];

    /* ----- stimulus ------------------------------------------- */
    initial begin
		integer fd, nbytes, num_samples, file_size;
		int correct, idx, pred, r, c, i, s, f;
		bit [7:0] lo, hi;
		bit       sample_complete;
		// Declare test vector array at the beginning
		logic signed [15:0] x_test [0:59][0:NUM_FEATURES-1]; // Pre-allocate max size
		
		// Initialize variables
		correct = 0;

		/* === load hidden layer weights === */
		fd = $fopen("../Weights/w_in_hid.bin","rb");  if(!fd) $fatal;
		for (int i=0; i<NUM_FEATURES*NUM_FEATURES; i++) begin
			bit [7:0] lo, hi;
			void'($fread(lo, fd));  // Read one byte (least significant)
			void'($fread(hi, fd));  // Read one byte (most significant)
			w_in_flat[i] = {hi,lo};
		end
		$fclose(fd);

		/* === load hidden biases === */
		fd = $fopen("../Weights/b_hid.bin","rb"); if(!fd) $fatal;
		for (int i=0; i<NUM_FEATURES; i++) begin
			bit [7:0] lo, hi;
			void'($fread(lo, fd));  // Read one byte (least significant)
			void'($fread(hi, fd));  // Read one byte (most significant)
			b_hid_flat[i] = {hi,lo};
		end
		$fclose(fd);

		/* === load output weights === */
		fd = $fopen("../Weights/w_hid_out.bin","rb"); if(!fd) $fatal;
		for (int i=0; i<NUM_FEATURES*NUM_CLASSES; i++) begin
			bit [7:0] lo, hi;
			void'($fread(lo, fd));  // Read one byte (least significant)
			void'($fread(hi, fd));  // Read one byte (most significant)
			w_out_flat[i] = {hi,lo};  // FIXED: Was incorrectly using w_in_flat
		end
		$fclose(fd);

		/* === load output biases === */
		fd = $fopen("../Weights/b_out.bin","rb"); if(!fd) $fatal;
		for (int i=0; i<NUM_CLASSES; i++) begin  // FIXED: Was incorrectly using NUM_FEATURES
			bit [7:0] lo, hi;
			void'($fread(lo, fd));  // Read one byte (least significant)
			void'($fread(hi, fd));  // Read one byte (most significant)
			b_out_flat[i] = {hi,lo};  // FIXED: Was incorrectly using b_hid_flat
		end
		$fclose(fd);

        /* map to DUT arrays */
        for (int r=0;r<NUM_FEATURES;r++)
            for (int c=0;c<NUM_FEATURES;c++)
                hid_w[r][c] = w_in_flat[r*NUM_FEATURES+c];
        for (int i=0;i<NUM_FEATURES;i++)
                hid_bias[i] = b_hid_flat[i];
        for (int r=0;r<NUM_FEATURES;r++)
            for (int c=0;c<NUM_CLASSES;c++)
                out_w[r][c] = w_out_flat[r*NUM_CLASSES+c];
        for (int i=0;i<NUM_CLASSES;i++)
                out_bias[i] = b_out_flat[i];

		/* === load test vectors === */
		fd = $fopen("../Weights/x_test.bin","rb"); if(!fd) $fatal;
        num_samples = 0;

        for (s = 0; s < 30; s++) begin  // Max 30 samples
            sample_complete = 1;         // <-- initialize here
            for (f = 0; f < NUM_FEATURES; f++) begin
                if ($fread(lo, fd) != 1 || $fread(hi, fd) != 1) begin
                    sample_complete = 0;
                    break;
                end
                x_test[s][f] = {hi, lo};
                raw_x[(s*NUM_FEATURES+f)*16 +: 8]   = lo;
                raw_x[(s*NUM_FEATURES+f)*16+8 +: 8] = hi;
                if (s == 0)
                    $display("Test sample 0, feature %0d: %h", f, {hi, lo});
            end
            if (!sample_complete) break;
            num_samples++;
        end
        $fclose(fd);
        $display("Loaded %0d test samples", num_samples);



		// Load ground truth labels
		fd = $fopen("../Weights/y_test.bin","rb"); if(!fd) $fatal;
		void'($fread(raw_y, fd, 0, num_samples));
		$fclose(fd);

		// Debug - verify sample count
		$display("Loaded %0d test samples", num_samples);

        /* one-time reset */
        reset = 1; start = 0; repeat(2) @(posedge clk);
        reset = 0;

	/* -------------- iterate samples ---------------- */
	for (int s = 0; s < num_samples; s++) begin : SAMPLE
		/* ---- declare all locals FIRST ------------- */
		int             idx;
		bit [7:0]       lo, hi;
		int             pred;

		/* ---- reset between samples ---------------- */
		reset = 1; #CYCLE; reset = 0;

		/* ---- load one sample into x[] ------------- */
		for (int f = 0; f < NUM_FEATURES; f++) begin
			x[f] = x_test[s][f];
		end

		/* ---- start pulse -------------------------- */
		start = 1; #CYCLE; start = 0; #CYCLE;
		@(posedge done); // wait for done
	
		/* ---- arg-max prediction ------------------- */
		pred = 0;
		for (int c = 1; c < NUM_CLASSES; c++)
			if (y[c] > y[pred]) pred = c;

		$display("sample %0d : pred=%0d  true=%0d", s, pred, raw_y[s]);
		if (pred == raw_y[s]) correct++;

		#(CYCLE);
	end


        $display("Accuracy = %0d / %0d = %0.2f%%",
                 correct, num_samples,
                 100.0*real'(correct)/num_samples);
		// Add to mlp_tb.v
		// After loading weights
// Add after loading weights

        $finish;
    end
endmodule
