# Parameterized Hardware Accelerator for 2D Convolution

## Overview
A high-performance, parameterized hardware accelerator for 2D image convolution designed in **SystemVerilog**. This IP core features a fully pipelined Multiply-Accumulate (MAC) architecture and **AXI4-Stream** interfaces, optimized for high-throughput image processing tasks in FPGAs or ASICs.

## Key Features
* **High Frequency:** Synthesized to **855 MHz** on Nangate 45nm Open Cell Library (ASIC).
* **Fully Parameterized:** Supports configurable Input Bit-Width, Kernel Size (3x3, 5x5, etc.), and Image Dimensions.
* **Pipelined Architecture:** 3-stage pipelined MAC unit with hazard-free execution.
* **Standard Interface:** AXI4-Stream compliant input/output with back-pressure handling.

## Architecture
![Block Diagram](docs/block_diagram.png)

## Verification (DPI-C)
The design was verified using a **Constrained-Random** testbench in Questasim.
* **DPI-C Co-Simulation:** A C++ Reference model is connected via SystemVerilog DPI to validate RTL output against software-computed expected values.
* **Coverage:** Functional coverage focuses on FIFO full/empty states and AXI handshake randomization.

## Usage
```systemverilog
// Example Instantiation
Conv #(
    .INW(18),
    .R(9),
    .C(8),
    .MAXK(5),
) u_conv_accelerator (
    .clk(clk),
    .reset(reset),
    .INPUT_TDATA(),
    .INPUT_TVALID(),
    .INPUT_TUSER(),
    .INPUT_TREADY(),
    
    .OUTPUT_TDATA(),
    .OUTPUT_TVALID(),
    .OUTPUT_TREADY()
);
```

---
**Copyright (c) 2025 Huabin Wu & Ryan Lin. All Rights Reserved.**
For demonstration purposes only. It is not licensed for use, modification, or distribution.