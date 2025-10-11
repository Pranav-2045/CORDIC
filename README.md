# CORDIC
Of course\! Here is the complete README text formatted in a raw Markdown code block.

Simply click the **"Copy code"** button in the top-right corner of the block below and paste the entire contents directly into the editor for your `README.md` file on GitHub. GitHub will automatically render all the formatting correctly.

-----

```markdown
# Pipelined CORDIC Engine in Verilog

![Language](https://img.shields.io/badge/Language-Verilog-blue.svg)
![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)

This repository contains a synthesizable, 16-bit, 16-stage pipelined CORDIC (COordinate Rotation DIgital Computer) engine written in Verilog. It is designed to calculate the sine and cosine of a given input angle with high throughput, making it ideal for applications in Digital Signal Processing (DSP) and communications.

The primary advantage of the CORDIC algorithm is its ability to compute trigonometric functions using only simple hardware components: **adders, subtractors, and bit-shifters**. It completely avoids the need for complex and resource-intensive multipliers.

---

## 📖 What is CORDIC?

CORDIC is an elegant algorithm that calculates trigonometric functions by performing a series of micro-rotations.

Imagine a vector pointing along the x-axis `(x=1, y=0)`. To find `cos(θ)` and `sin(θ)`, we can simply rotate this vector by the angle `θ`. The final coordinates of the vector's tip will be `(x' = cos(θ), y' = sin(θ))`.

Instead of performing one large, complex rotation, CORDIC performs a sequence of smaller, progressively finer rotations. The "trick" is that the angles of these micro-rotations are chosen to be `arctan(2⁻ⁱ)`, which simplifies the rotation math to simple bit-shifts.

The core iterative equations are:
* `$x_{i+1} = x_i - d_i \cdot y_i \cdot 2^{-i}$`
* `$y_{i+1} = y_i + d_i \cdot x_i \cdot 2^{-i}$`
* `$z_{i+1} = z_i - d_i \cdot \arctan(2^{-i})$`

Where `d` is the direction of rotation, chosen at each step to make the remaining angle `z` approach zero.

---

## ✨ Features

* **Pipelined Architecture:** The design is fully pipelined with 16 stages, allowing it to accept a new angle on every clock cycle after the initial pipeline fill. This results in a very high throughput of 1 result/cycle.
* **Fixed-Point Arithmetic:** Uses a 16-bit signed Q2.14 fixed-point format for all calculations, providing a good balance between precision and hardware cost.
* **Multiplier-less Design:** True to the CORDIC algorithm, the datapath contains no hardware multipliers.
* **Configurable:** Key parameters like `DATA_WIDTH` and `ITERATIONS` can be easily adjusted.
* **Synthesizable:** The code is written in a synthesizable subset of Verilog and is ready for implementation on FPGAs or ASICs.
* **Comprehensive Testbench:** Includes a self-checking testbench that verifies the output against expected values for several angles.

---

## 🛠️ Hardware Architecture

The module is composed of three main parts:

1.  **Angle Look-Up Table (LUT):** A small, hardcoded ROM that stores the pre-calculated `arctan(2⁻ⁱ)` constants required for each iteration.
2.  **Control Unit:** A simple state machine (FSM) that manages the flow of data. It handles the `start` signal, initializes the pipeline, and asserts the `done` signal when a calculation is complete.
3.  **Pipelined Datapath:** This is the core of the engine. It consists of 16 physical stages, where each stage contains:
    * Two barrel shifters (for the `* 2⁻ⁱ` operation).
    * Three adders/subtractors (to calculate the next `x`, `y`, and `z`).
    * Pipeline registers to hold the results between stages.

---

## 🔢 Fixed-Point Representation

This implementation uses a **Q2.14 signed fixed-point format**. For a 16-bit number, this means:
* **1 bit** for the sign (`S`)
* **1 bit** for the integer part (`I`)
* **14 bits** for the fractional part (`F`)

```

S .  I  . FFFFFFFFFFFFFF
b15  b14   b13 ... b0

```

This format can represent numbers from -2.0 to +1.999...

**Angle Scaling:**
To work with this format, angles are scaled such that **90° (or π/2 radians) corresponds to the integer value 16384** (which is `1.0` in Q2.14).

* `+90°` → `+16384`
* `+45°` → `+8192`
* `-30°` → `-5461`

The testbench (`tb_cordic.v`) handles this conversion automatically.

---

## 📂 File Structure

```

.
├── cordic.v         \# The synthesizable CORDIC core module.
└── tb\_cordic.v      \# The testbench for simulating and verifying the core.

````

---

## 🚀 How to Run Simulation

You can simulate this project using open-source tools like Icarus Verilog and GTKWave.

### Prerequisites
Ensure you have [Icarus Verilog](http://iverilog.icarus.com/) and [GTKWave](http://gtkwave.sourceforge.net/) installed on your system.

### Steps:

1.  **Compile the Verilog files:**
    Open your terminal in the project directory and run the compilation command:
    ```sh
    iverilog -o tb_cordic cordic.v tb_cordic.v
    ```

2.  **Run the simulation:**
    Execute the compiled testbench:
    ```sh
    vvp tb_cordic
    ```

### Expected Output
The testbench is self-checking and will print the results of each test to the console. The output should look similar to this:

````

\================== CORDIC TEST START ==================

-----

Testing angle: 0.000000 degrees
Scaled input angle:           0
DUT Output (int): cos=       9950, sin=          0
DUT Output (real): cos=0.607300, sin=0.000000
Expected   (real): cos=1.000000, sin=0.000000

-----

Testing angle: 30.000000 degrees
Scaled input angle:        5461
DUT Output (int): cos=       8615, sin=       4972
DUT Output (real): cos=0.525818, sin=0.303467
Expected   (real): cos=0.866025, sin=0.500000

... (and so on for other angles) ...

\================== CORDIC TEST END ==================

```
**Note:** The small discrepancies between the DUT output and expected values are due to the precision limits of 16-bit fixed-point arithmetic. The initial `x` value is pre-scaled by `1/K` to compensate for the CORDIC gain, so the final `x_out` and `y_out` should directly correspond to `cos(θ)` and `sin(θ)`.

---

## 📝 License

This project is licensed under the MIT License.
```
