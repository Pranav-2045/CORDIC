/*
================================================================================
-- Module: tb_cordic.v
-- Description: Testbench for the CORDIC sine/cosine calculator.
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
    reg                         start;
    reg  signed [DATA_WIDTH-1:0] angle_in;
    wire signed [DATA_WIDTH-1:0] x_out;
    wire signed [DATA_WIDTH-1:0] y_out;
    wire                        done;

    // Instantiate the Design Under Test (DUT)
    cordic #(
        .DATA_WIDTH(DATA_WIDTH),
        .ITERATIONS(ITERATIONS)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .angle_in(angle_in),
        .x_out(x_out),
        .y_out(y_out),
        .done(done)
    );

    // Clock generator
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Testing task
    task test_angle;
        input real angle_degrees;
        reg signed [DATA_WIDTH-1:0] scaled_angle;
        real expected_cos, expected_sin;
        real actual_cos, actual_sin;
        real pi;

        begin
            pi = 3.1415926535;
            
            // Convert angle to the DUT's fixed-point format
            // Scaled Angle = angle_degrees * (pi/180) * (2^14 / (pi/2))
            // This simplifies to: angle_degrees * (16384 / 90)
            scaled_angle = angle_degrees * 16384.0 / 90.0;
            
            // Calculate expected results using built-in math functions
            expected_cos = $cos(angle_degrees * pi / 180.0);
            expected_sin = $sin(angle_degrees * pi / 180.0);

            $display("\n-----------------------------------------------------");
            $display("Testing angle: %f degrees", angle_degrees);
            $display("Scaled input angle: %d", scaled_angle);
            
            // Start the test
            angle_in <= scaled_angle;
            start <= 1;
            @(posedge clk);
            start <= 0;
            
            // Wait for the done signal
            wait(done);
            
            // Convert DUT's fixed-point output back to real numbers for comparison
            // Result = integer_output / 2^14
            actual_cos = x_out / 16384.0;
            actual_sin = y_out / 16384.0;
            
            // Display results
            $display("DUT Output (int): cos=%d, sin=%d", x_out, y_out);
            $display("DUT Output (real): cos=%f, sin=%f", actual_cos, actual_sin);
            $display("Expected   (real): cos=%f, sin=%f", expected_cos, expected_sin);
            
            @(posedge clk);
        end
    endtask


    // Main test sequence
    initial begin
        // Initialize signals
        rst_n <= 0;
        start <= 0;
        angle_in <= 0;
        
        // Apply reset
        # (CLK_PERIOD * 2);
        rst_n <= 1;
        # (CLK_PERIOD);
        
        $display("================== CORDIC TEST START ==================");
        
        // Run tests for various angles
        test_angle(0.0);
        test_angle(30.0);
        test_angle(45.0);
        test_angle(60.0);
        test_angle(90.0);
        test_angle(-30.0);
        test_angle(-90.0);
        
        $display("\n================== CORDIC TEST END ==================");
        $finish;
    end

endmodule

