# CORDIC Pipelined Architecture Schematics

This document contains block diagrams illustrating the fully pipelined CORDIC architecture implemented in `cordic.v`.

## 1. Top-Level Module Interface
The top-level module accepts an input angle and a valid signal, and produces the cosine and sine outputs exactly 16 clock cycles later with an accompanying valid output signal.

```mermaid
block-beta
  columns 3
  
  space:1
  doc("Top Level Interface")
  space:1
  
  block:inputs:1
    clk
    rst_n
    valid_in
    angle_in
  end
  
  block:cordic_core:1
    CORDIC_PIPELINE
  end
  
  block:outputs:1
    valid_out
    x_out
    y_out
  end
  
  inputs --> cordic_core
  cordic_core --> outputs
```

## 2. 16-Stage Pipelined Datapath Overview
The engine consists of an initial input capture stage (Stage 0) followed by 16 identical computing stages. Data flows continuously from left to right, advancing one stage per clock cycle.

```mermaid
flowchart LR
    %% Define Inputs
    valid_in[\valid_in/]
    angle_in[\angle_in/]
    
    %% Define Stages
    subgraph Stage0 [Input Stage 0]
        direction TB
        V0[valid_pipe 0]
        X0[x_pipe 0: 0.60725]
        Y0[y_pipe 0: 0]
        Z0[z_pipe 0: angle]
    end

    subgraph Stage1 [Compute Stage 1]
        direction TB
        V1[valid_pipe 1]
        X1[x_pipe 1]
        Y1[y_pipe 1]
        Z1[z_pipe 1]
    end

    mid[...]

    subgraph Stage16 [Compute Stage 16]
        direction TB
        V16[valid_pipe 16]
        X16[x_pipe 16]
        Y16[y_pipe 16]
        Z16[z_pipe 16]
    end

    %% Define Outputs
    valid_out[/valid_out\]
    x_out[/x_out : cos\]
    y_out[/y_out : sin\]
    
    %% Connections
    valid_in --> Stage0
    angle_in --> Stage0
    
    Stage0 -->|"x,y,z,valid"| Stage1
    Stage1 -->|"x,y,z,valid"| mid
    mid -->|"x,y,z,valid"| Stage16
    
    Stage16 --> valid_out
    Stage16 --> x_out
    Stage16 --> y_out
```

## 3. Internal Architecture of a Single Compute Stage (Stage $i$)
Inside every computing stage (from $i=0$ to $i=15$), the vector is rotated. The direction of rotation $d_i$ depends on the sign bit (MSB) of the current angle $z_i$.

```mermaid
flowchart TD
    %% Inputs
    Xi[x_pipe i]
    Yi[y_pipe i]
    Zi[z_pipe i]

    %% Computations
    Zsign{z_pipe i MSB}
    LUT[angle_lut i]
    
    ShiftX[x_pipe i >> i]
    ShiftY[y_pipe i >> i]
    
    AddSubX[x +/- shifted_y]
    AddSubY[y -/+ shifted_x]
    AddSubZ[z -/+ LUT]

    %% Outputs
    Xnext[x_pipe i+1]
    Ynext[y_pipe i+1]
    Znext[z_pipe i+1]
    
    %% X and Y Path
    Xi --> AddSubX
    Yi --> ShiftY
    ShiftY --> AddSubX
    AddSubX --> Xnext
    
    Yi --> AddSubY
    Xi --> ShiftX
    ShiftX --> AddSubY
    AddSubY --> Ynext
    
    %% Z Path
    Zi --> Zsign
    Zi --> AddSubZ
    LUT --> AddSubZ
    AddSubZ --> Znext
    
    %% Control
    Zsign -.-> AddSubX
    Zsign -.-> AddSubY
    Zsign -.-> AddSubZ

    %% Invisible alignment links to keep X, Y, Z grouped
    Xi ~~~ Yi ~~~ Zi
    Xnext ~~~ Ynext ~~~ Znext

    classDef register fill:#dae8fc,stroke:#6c8ebf,stroke-width:2px;
    class Xi,Yi,Zi,Xnext,Ynext,Znext register;
```

## 4. Valid Signal Propagation
To avoid the need for an FSM, a validity bit travels alongside the data in the pipeline to indicate when the output is successfully computed.

```mermaid
flowchart LR
    VI[\valid_in/] --> DFF0[D-FlipFlop 0]
    DFF0 --> DFF1[D-FlipFlop 1]
    DFF1 --> DFF2[...]
    DFF2 --> DFF16[D-FlipFlop 16]
    DFF16 --> VO[/valid_out\]
    
    clk((clk)) --> DFF0
    clk --> DFF1
    clk --> DFF16
```
