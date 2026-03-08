/*
================================================================================
-- Module: tb_cordic.v
-- Description: Testbench for the fully pipelined CORDIC sine/cosine calculator.
================================================================================
*/
`timescale 1ns / 1ps

module tb_cordic;

    // Parameters
    localparam DATA_WIDTH = 16;
    localparam ITERATIONS = 16;
    localparam CLK_PERIOD = 10; // 10 ns clock period

    // Testbench signals
    reg                         clk;
    reg                         rst_n;
    reg                         valid_in;
    reg  signed [DATA_WIDTH-1:0] angle_in;
    wire signed [DATA_WIDTH-1:0] x_out;
    wire signed [DATA_WIDTH-1:0] y_out;
    wire                        valid_out;

    // Instantiate the Design Under Test (DUT)
    cordic #(
        .DATA_WIDTH(DATA_WIDTH),
        .ITERATIONS(ITERATIONS)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .angle_in(angle_in),
        .x_out(x_out),
        .y_out(y_out),
        .valid_out(valid_out)
    );

    // Clock generator
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Arrays to store test data for pipeline testing
    real test_angles[0:6];
    real expected_cos_arr[0:6];
    real expected_sin_arr[0:6];

    initial begin
        test_angles[0] = 0.0;
        test_angles[1] = 30.0;
        test_angles[2] = 45.0;
        test_angles[3] = 60.0;
        test_angles[4] = 90.0;
        test_angles[5] = -30.0;
        test_angles[6] = -90.0;
        
        expected_cos_arr[0] = $cos(0.0 * 3.1415926535 / 180.0);
        expected_sin_arr[0] = $sin(0.0 * 3.1415926535 / 180.0);
        
        expected_cos_arr[1] = $cos(30.0 * 3.1415926535 / 180.0);
        expected_sin_arr[1] = $sin(30.0 * 3.1415926535 / 180.0);
        
        expected_cos_arr[2] = $cos(45.0 * 3.1415926535 / 180.0);
        expected_sin_arr[2] = $sin(45.0 * 3.1415926535 / 180.0);
        
        expected_cos_arr[3] = $cos(60.0 * 3.1415926535 / 180.0);
        expected_sin_arr[3] = $sin(60.0 * 3.1415926535 / 180.0);
        
        expected_cos_arr[4] = $cos(90.0 * 3.1415926535 / 180.0);
        expected_sin_arr[4] = $sin(90.0 * 3.1415926535 / 180.0);
        
        expected_cos_arr[5] = $cos(-30.0 * 3.1415926535 / 180.0);
        expected_sin_arr[5] = $sin(-30.0 * 3.1415926535 / 180.0);
        
        expected_cos_arr[6] = $cos(-90.0 * 3.1415926535 / 180.0);
        expected_sin_arr[6] = $sin(-90.0 * 3.1415926535 / 180.0);
    end

    // Main test sequence
    integer i;
    integer output_idx;
    real actual_cos, actual_sin;

    initial begin
        // Initialize signals
        rst_n <= 0;
        valid_in <= 0;
        angle_in <= 0;
        output_idx = 0;
        
        // Apply reset
        # (CLK_PERIOD * 2);
        rst_n <= 1;
        # (CLK_PERIOD);
        
        $display("================== PIPELINED CORDIC TEST START ==================");
        
        // Feed inputs continuously cycle by cycle
        for (i = 0; i < 7; i = i + 1) begin
            angle_in <= test_angles[i] * 16384.0 / 90.0;
            valid_in <= 1;
            @(posedge clk);
        end
        valid_in <= 0;
    end

    // Monitor outputs
    always @(posedge clk) begin
        if (valid_out) begin
            actual_cos = x_out / 16384.0;
            actual_sin = y_out / 16384.0;
            
            $display("\n-----------------------------------------------------");
            $display("Received output for angle index: %d", output_idx);
            $display("Angle tested: %f degrees", test_angles[output_idx]);
            $display("DUT Output (int): cos=%d, sin=%d", x_out, y_out);
            $display("DUT Output (real): cos=%f, sin=%f", actual_cos, actual_sin);
            $display("Expected   (real): cos=%f, sin=%f", expected_cos_arr[output_idx], expected_sin_arr[output_idx]);
            
            output_idx = output_idx + 1;
            
            if (output_idx == 7) begin
                $display("\n================== PIPELINED CORDIC TEST END ==================");
                $finish;
            end
        end
    end

    // Timeout safety
    initial begin
        # (CLK_PERIOD * 100);
        $display("TEST TIMEOUT");
        $finish;
    end

endmodule
