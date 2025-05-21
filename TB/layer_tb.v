`timescale 1ns/1ps
module layer_tb;

    /* ===== parameters that match the DUT ========================= */
    localparam int NUM_FEATURES   = 4;
    localparam int NUM_CLASSES    = 4;
    localparam int FP_TOTAL_BITS  = 16;
    localparam int FP_FRAC_BITS   = 8;
    localparam int ROUND_CONST    = 1 << (FP_FRAC_BITS-1);

    /* ===== 100-MHz clock ======================================== */
    logic clk = 0;
    always #5 clk = ~clk;

    /* ===== DUT signals ========================================== */
    logic reset, start, done;
    logic signed [FP_TOTAL_BITS-1:0] x             [NUM_FEATURES];
    logic signed [FP_TOTAL_BITS-1:0] hidden_bias    [NUM_CLASSES];
    logic signed [FP_TOTAL_BITS-1:0] hidden_weights [NUM_FEATURES][NUM_CLASSES];
    logic signed [FP_TOTAL_BITS-1:0] layer_out      [NUM_CLASSES];

    layer #(
        .NUM_FEATURES (NUM_FEATURES),
        .NUM_CLASSES  (NUM_CLASSES),
        .FP_TOTAL_BITS(FP_TOTAL_BITS),
        .FP_FRAC_BITS (FP_FRAC_BITS)
    ) dut (
        .clk       (clk),
        .reset     (reset),
        .start     (start),
        .x         (x),
        .bias      (hidden_bias),
        .weights   (hidden_weights),
        .layer_out (layer_out),
        .done      (done)
    );

    /* ===== raw byte vectors for $fread ========================== */
    bit [8*NUM_FEATURES*NUM_CLASSES*2-1:0] raw_w = '0;
    bit [8*NUM_CLASSES*2-1:0]              raw_b = '0;
    bit [8*NUM_FEATURES*2-1:0]             raw_x = '0;

    /* unpacked 16-bit helpers */
    logic signed [15:0] w_flat [NUM_FEATURES*NUM_CLASSES-1:0];
    logic signed [15:0] b_flat [NUM_CLASSES-1:0];
    logic signed [15:0] x_flat [NUM_FEATURES-1:0];

    /* ===== stimulus ============================================ */
    initial begin
        integer fd, nbytes;

        /* ---------- load weights -------------------------------- */
        fd = $fopen("../Weights/w_in_hid.bin","rb");
        if (!fd) $fatal(0,"Cannot open w_in_hid.bin");
        nbytes = $fread(raw_w, fd); $fclose(fd);
        if (nbytes==0) $fatal(0,"w_in_hid.bin empty");
        for (int i=0;i<NUM_FEATURES*NUM_CLASSES;i++) begin
            bit [7:0] lo; bit [7:0] hi;
            lo = raw_w[i*16 +: 8];
            hi = raw_w[i*16+8 +: 8];
            w_flat[i] = {hi,lo};
        end

        /* ---------- load biases --------------------------------- */
        fd = $fopen("../Weights/b_hid.bin","rb");
        if (!fd) $fatal(0,"Cannot open b_hid.bin");
        nbytes = $fread(raw_b, fd); $fclose(fd);
        if (nbytes==0) $fatal(0,"b_hid.bin empty");
        for (int i=0;i<NUM_CLASSES;i++) begin
            bit [7:0] lo; bit [7:0] hi;
            lo = raw_b[i*16 +: 8];
            hi = raw_b[i*16+8 +: 8];
            b_flat[i] = {hi,lo};
        end

        /* map into DUT arrays */
        for (int r=0;r<NUM_FEATURES;r++)
            for (int c=0;c<NUM_CLASSES;c++)
                hidden_weights[r][c] = w_flat[r*NUM_CLASSES+c];
        for (int c=0;c<NUM_CLASSES;c++)
                hidden_bias[c] = b_flat[c];

        /* ---------- global reset -------------------------------- */
        reset = 1; start = 0; #10; reset = 0;

        /* =============== TEST-1  hand-crafted =================== */
        x = '{ 16'sd128, -16'sd256, 16'sd0, 16'sd768 };
        start = 1; #10; start = 0;
        while (!done) #10;

        $display("Case-1 outputs: %0d %0d %0d %0d",
                 layer_out[0],layer_out[1],layer_out[2],layer_out[3]);

        /* correct per-class assertion */
        for (int j=0;j<NUM_CLASSES;j++) begin
            automatic logic signed [31:0] acc;  acc = 0;
            for (int k=0;k<NUM_FEATURES;k++)
                acc += x[k] * hidden_weights[k][j];
            acc += hidden_bias[j] <<< FP_FRAC_BITS;
            acc += ROUND_CONST;
            acc  = acc >>> FP_FRAC_BITS;
            assert (layer_out[j] === acc[15:0])
              else $fatal(0,"Mismatch class %0d exp=%0d got=%0d",
                          j, acc[15:0], layer_out[j]);
        end
        $display("Case-1 assertion PASS");

        /* one-cycle reset */
        reset = 1; #10; reset = 0;

        /* =============== TEST-2  first x_test sample ============ */
        fd = $fopen("../Weights/x_test.bin","rb");
        if (!fd) $fatal(0,"Cannot open x_test.bin");
        nbytes = $fread(raw_x, fd); $fclose(fd);
        if (nbytes==0) $fatal(0,"x_test.bin empty");
		
        for (int i=0;i<NUM_FEATURES;i++) begin
            bit [7:0] lo; bit [7:0] hi;
            lo = raw_x[i*16 +: 8];
            hi = raw_x[i*16+8 +: 8];
            x_flat[i] = {hi,lo};
            x[i]      = x_flat[i];
        end

        start = 1; #10; start = 0;
        while (!done) #10;

        $display("Case-2 outputs: %0d %0d %0d %0d",
                 layer_out[0],layer_out[1],layer_out[2],layer_out[3]);

        $finish;
    end
endmodule
