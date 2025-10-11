/*
================================================================================
-- Module: cordic.v
-- Description: A pipelined CORDIC (COordinate Rotation DIgital Computer)
--              engine to calculate sine and cosine.
================================================================================

-- THEORY OF OPERATION:
-- This module implements the CORDIC algorithm in "Rotation Mode" to find the
-- sine and cosine of an input angle.
--
-- 1. Goal: Rotate a vector (x, y) by a given angle 'z' until 'z' becomes 0.
-- 2. Initialization: We start with a known vector (x=1, y=0). If we rotate
--    this vector by the input angle 'angle_in', its final coordinates will be
--    (x_final = cos(angle_in), y_final = sin(angle_in)).
-- 3. The Trick: Instead of a true rotation (which requires multipliers), CORDIC
--    performs a series of micro-rotations using angles whose tangents are
--    powers of 2 (i.e., arctan(2^-i)). This simplifies the rotation math to
--    bit-shifts, adds, and subtracts, which are very cheap in hardware.
--
-- 4. Fixed-Point Arithmetic:
--    - We use signed 16-bit numbers.
--    - Format is Q2.14 (2 integer bits, 14 fractional bits). This allows us
--      to represent numbers from -2 to +1.999...
--    - Angles are scaled: +90 degrees is represented as 16384 (which is pi/2
--      in radians, scaled by 2^14).
--    - Initial X value is 1/K, where K is the CORDIC gain (~1.647). This
--      pre-scales the vector so the final output has unity gain.
--      1/K ~ 0.60725. In Q2.14, this is 0.60725 * 2^14 = 9950.

*/
module cordic #(
    parameter DATA_WIDTH = 16,  // Width of x, y, z registers
    parameter ITERATIONS = 16   // Number of CORDIC iterations (pipeline stages)
) (
    input                       clk,
    input                       rst_n,
    input                       start,      // Start computation signal
    input      signed [DATA_WIDTH-1:0] angle_in,   // Input angle in scaled format

    output reg signed [DATA_WIDTH-1:0] x_out,      // cos(angle_in)
    output reg signed [DATA_WIDTH-1:0] y_out,      // sin(angle_in)
    output reg                  done        // Computation finished
);

    //--------------------------------------------------------------------------
    // 1. Angle Look-Up Table (LUT) for arctan(2^-i)
    //--------------------------------------------------------------------------
    // These are the pre-calculated, fixed-point values for our micro-rotations.
    reg signed [DATA_WIDTH-1:0] angle_lut [0:ITERATIONS-1];

    initial begin
        // Values are  (arctan(2^-i) in degrees )* (16384/90) to scale correctly
        angle_lut[0]  = 16'd8192; // 45.0 deg
        angle_lut[1]  = 16'd4836; // 26.565 deg
        angle_lut[2]  = 16'd2554; // 14.036 deg
        angle_lut[3]  = 16'd1297; // 7.125 deg
        angle_lut[4]  = 16'd652;  // 3.576 deg
        angle_lut[5]  = 16'd326;  // 1.79 deg
        angle_lut[6]  = 16'd163;  // 0.895 deg
        angle_lut[7]  = 16'd81;   // 0.447 deg
        angle_lut[8]  = 16'd41;   // 0.224 deg
        angle_lut[9]  = 16'd20;   // 0.112 deg
        angle_lut[10] = 16'd10;   // 0.056 deg
        angle_lut[11] = 16'd5;    // 0.028 deg
        angle_lut[12] = 16'd2;    // 0.014 deg
        angle_lut[13] = 16'd1;    // 0.007 deg
        angle_lut[14] = 16'd1;    // 0.003 deg (precision limit)
        angle_lut[15] = 16'd0;    // 0.002 deg (precision limit)
    end

    //--------------------------------------------------------------------------
    // 2. Internal Registers for the Pipeline
    //--------------------------------------------------------------------------
    reg signed [DATA_WIDTH-1:0] x_pipe [0:ITERATIONS];
    reg signed [DATA_WIDTH-1:0] y_pipe [0:ITERATIONS];
    reg signed [DATA_WIDTH-1:0] z_pipe [0:ITERATIONS];

    //--------------------------------------------------------------------------
    // 3. State Machine for control
    //--------------------------------------------------------------------------
    localparam S_IDLE    = 2'b00;
    localparam S_COMPUTE = 2'b01;
    localparam S_DONE    = 2'b10;

    reg [1:0] state, next_state;
    reg [4:0] iteration_counter; // Counter for pipeline stages

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
        end else begin
            state <= next_state;
        end
    end

    // State transition logic
    always @(*) begin
        next_state = state;
        case(state)
            S_IDLE: if (start) next_state = S_COMPUTE;
            S_COMPUTE: if (iteration_counter == ITERATIONS) next_state = S_DONE;
            S_DONE: if (!start) next_state = S_IDLE; // Wait for start to go low before restarting
        endcase
    end
    
    //--------------------------------------------------------------------------
    // 4. Datapath and Pipeline Logic
    //--------------------------------------------------------------------------
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset logic
            for (i=0; i<=ITERATIONS; i=i+1) begin
                x_pipe[i] <= 0;
                y_pipe[i] <= 0;
                z_pipe[i] <= 0;
            end
            x_out <= 0;
            y_out <= 0;
            done <= 0;
            iteration_counter <= 0;
        end else begin
            case(state)
                S_IDLE: begin
                    done <= 0;
                    iteration_counter <= 0;
                    // When 'start' is asserted, load initial values into the first stage
                    if (start) begin
                        x_pipe[0] <= 16'd9950;  // Initial X = 1/K (0.60725) in Q2.14
                        y_pipe[0] <= 16'd0;     // Initial Y = 0
                        z_pipe[0] <= angle_in;  // Load the target angle
                    end
                end

                S_COMPUTE: begin
                    // This loop describes the connections between pipeline stages.
                    // It generates a chain of adders/subtractors and shifters.
                    for (i=0; i<ITERATIONS; i=i+1) begin
                        // Determine rotation direction based on the sign of z
                        // If z is negative, we need to rotate clockwise (+).
                        // If z is positive, we need to rotate counter-clockwise (-).
                        if (z_pipe[i][DATA_WIDTH-1]) begin // z is negative
                            x_pipe[i+1] <= x_pipe[i] + (y_pipe[i] >>> i);
                            y_pipe[i+1] <= y_pipe[i] - (x_pipe[i] >>> i);
                            z_pipe[i+1] <= z_pipe[i] + angle_lut[i];
                        end else begin // z is positive or zero
                            x_pipe[i+1] <= x_pipe[i] - (y_pipe[i] >>> i);
                            y_pipe[i+1] <= y_pipe[i] + (x_pipe[i] >>> i);
                            z_pipe[i+1] <= z_pipe[i] - angle_lut[i];
                        end
                    end
                    iteration_counter <= iteration_counter + 1;
                end
                
                S_DONE: begin
                    // Computation is finished. Hold the final values.
                    x_out <= x_pipe[ITERATIONS]; // Cosine result
                    y_out <= y_pipe[ITERATIONS]; // Sine result
                    done <= 1;
                    iteration_counter <= 0; // Reset for next run
                end
            endcase
        end
    end
endmodule
