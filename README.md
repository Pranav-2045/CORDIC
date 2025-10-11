-----

# Pipelined CORDIC Engine in Verilog

This repository contains a synthesizable, **16-bit, 16-stage pipelined CORDIC** (COordinate Rotation DIgital Computer) engine written in Verilog. It's designed to calculate the sine and cosine of a given input angle with high throughput, making it ideal for applications in Digital Signal Processing (DSP), communications, and real-time control systems.

The primary advantage of the CORDIC algorithm is its ability to compute trigonometric functions using only simple hardware components: **adders, subtractors, and bit-shifters**. It completely avoids the need for complex and resource-intensive multipliers.

-----

## 📖 What is CORDIC?

CORDIC is an elegant algorithm that calculates trigonometric and other functions by performing a series of micro-rotations.

Imagine a vector on a 2D plane. To find the sine and cosine of an angle $\theta$, CORDIC starts with a known vector (e.g., `(x=1, y=0)`) and rotates it by the target angle $\theta$. The final coordinates of the vector's tip will be directly proportional to $(\cos(\theta), \sin(\theta))$.

Instead of performing one large, complex rotation, CORDIC performs a sequence of smaller, progressively finer rotations. The "trick" is that the angles of these micro-rotations are chosen to be $\arctan(2^{-i})$, which simplifies the complex rotation math into simple bit-shifts.

The core iterative equations for the rotation mode are:

> $x_{i+1} = x_i - d_i \cdot y_i \cdot 2^{-i}$
>
> $y_{i+1} = y_i + d_i \cdot x_i \cdot 2^{-i}$
>
> $z_{i+1} = z_i - d_i \cdot \arctan(2^{-i})$

Where:

  * $x_i, y_i$ are the vector coordinates at iteration $i$.
  * $z_i$ is the remaining angle to rotate.
  * $d_i$ is the direction of rotation (+1 or -1), chosen at each step to make the remaining angle $z$ approach zero.

-----

## ✨ Features

  * **Pipelined Architecture**: A 16-stage pipeline allows it to accept a new angle on every clock cycle after an initial latency. This results in a very high throughput of **1 result/cycle**.
  * **Multiplier-less Design**: True to the CORDIC algorithm, the datapath contains **no hardware multipliers**, saving significant hardware resources.
  * **Fixed-Point Arithmetic**: Uses a 16-bit signed **Q2.14** fixed-point format for all calculations, providing a good balance between precision and hardware cost.
  * **High Throughput**: Ideal for streaming data applications in DSP and software-defined radio (SDR).
  * **Synthesizable**: The code is written in a synthesizable subset of Verilog, ready for implementation on FPGAs or ASICs.
  * **Comprehensive Testbench**: Includes a self-checking testbench that verifies the output against expected values for several angles.

-----

## 🛠️ Hardware Architecture

The module is composed of three main parts:

1.  **Angle Look-Up Table (LUT)**: A small, hardcoded ROM that stores the pre-calculated $\arctan(2^{-i})$ constants required for each iteration.
2.  **Control Logic**: Manages the flow of data through the pipeline, handling start/done signaling.
3.  **Pipelined Datapath**: This is the core of the engine. It consists of 16 physical stages, where each stage contains:
      * Two barrel shifters (for the $\cdot 2^{-i}$ operation).
      * Three adders/subtractors (to calculate the next $x, y,$ and $z$).
      * Pipeline registers to hold the results between stages.

-----

## 🔢 Fixed-Point Representation & Scaling

#### Q2.14 Format

This implementation uses a **Q2.14** signed fixed-point format. For a 16-bit number, this means:

  * **1 bit** for the sign (S)
  * **1 bit** for the integer part (I)
  * **14 bits** for the fractional part (F)

<!-- end list -->

```
 S .  I  . FFFFFFFFFFFFFF
b15  b14   b13 ... b0
```

This format can represent numbers from -2.0 to +1.999...

#### Angle Scaling

To work with this format, input angles in degrees must be scaled. The range from -90° to +90° is mapped to the range -1.0 to +1.0 in the Q2.14 format. The scaling factor is $(16384 / 90^{\circ})$.

  * **+90°** → `16384` (which is 1.0 in Q2.14)
  * **+45°** → `8192` (which is 0.5 in Q2.14)
  * **-30°** → `-5461`

The testbench (`tb_cordic.v`) handles this conversion automatically.

### An Important Note on Gain

The series of micro-rotations in the CORDIC algorithm scales the magnitude of the initial vector by a constant gain factor, $K$. After $N$ iterations, this gain is:
$$ K = \prod_{i=0}^{N-1} \sqrt{1 + 2^{-2i}} $$
For a large number of iterations ($N=16$ in this case), this gain converges to approximately **1.64676**.

This implementation starts with an initial vector of `(x=1, y=0)`. Therefore, the final outputs are not $(\cos\theta, \sin\theta)$ but rather $(K \cdot \cos\theta, K \cdot \sin\theta)$. To get the true sine and cosine values, you must correct for this gain by either:

1.  **Pre-scaling**: Starting with an initial vector of $(1/K, 0) \approx (0.60725, 0)$.
2.  **Post-scaling**: Dividing the final $x$ and $y$ outputs by the gain $K$.

The testbench output reflects this uncorrected gain. For an input of 0°, the expected cosine is 1.0, but the DUT output is \~0.6073, which is the reciprocal of the gain ($1/K$).

-----

## 📂 File Structure

```
.
├── cordic.v         # The synthesizable CORDIC core module.
└── tb_cordic.v      # The testbench for simulating and verifying the core.
```

-----

## 🚀 How to Run Simulation

You can simulate this project using open-source tools like Icarus Verilog and view the waveforms with GTKWave.

#### Prerequisites

Ensure you have [Icarus Verilog](https://www.google.com/search?q=http://iverilog.icarus.com/) and [GTKWave](https://gtkwave.sourceforge.net/) installed on your system.

#### Steps

1.  **Compile the Verilog files:**
    Open your terminal in the project directory and run the compilation command:

    ```sh
    iverilog -o tb_cordic cordic.v tb_cordic.v
    ```

2.  **Run the simulation:**
    Execute the compiled design:

    ```sh
    vvp tb_cordic
    ```

#### Expected Output

The testbench is self-checking and will print the results of each test to the console. The output shows the DUT's raw integer and scaled fixed-point values alongside the mathematically expected sine/cosine values. Note the gain difference as explained above.

```
================== CORDIC TEST START ==================

-----------------------------------------------------
Testing angle: 0.000000 degrees
Scaled input angle:      0
DUT Output (int): cos= 16385, sin=    -2
DUT Output (real): cos=1.000061, sin=-0.000122
Expected   (real): cos=1.000000, sin=0.000000

-----------------------------------------------------
Testing angle: 30.000000 degrees
Scaled input angle:   5461
DUT Output (int): cos= 14193, sin=  8192
DUT Output (real): cos=0.866272, sin=0.500000
Expected   (real): cos=0.866025, sin=0.500000

-----------------------------------------------------
Testing angle: 45.000000 degrees
Scaled input angle:   8192
DUT Output (int): cos= 11587, sin= 11586
DUT Output (real): cos=0.707214, sin=0.707153
Expected   (real): cos=0.707107, sin=0.707107

-----------------------------------------------------
Testing angle: 60.000000 degrees
Scaled input angle:  10923
DUT Output (int): cos=  8190, sin= 14193
DUT Output (real): cos=0.499878, sin=0.866272
Expected   (real): cos=0.500000, sin=0.866025

-----------------------------------------------------
Testing angle: 90.000000 degrees
Scaled input angle:  16384
DUT Output (int): cos=    -4, sin= 16385
DUT Output (real): cos=-0.000244, sin=1.000061
Expected   (real): cos=0.000000, sin=1.000000

-----------------------------------------------------
Testing angle: -30.000000 degrees
Scaled input angle:  -5461
DUT Output (int): cos= 14193, sin= -8190
DUT Output (real): cos=0.866272, sin=-0.499878
Expected   (real): cos=0.866025, sin=-0.500000

-----------------------------------------------------
Testing angle: -90.000000 degrees
Scaled input angle: -16384
DUT Output (int): cos=    -6, sin=-16385
DUT Output (real): cos=-0.000366, sin=-1.000061
Expected   (real): cos=0.000000, sin=-1.000000

================== CORDIC TEST END ==================
```
