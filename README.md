# ML-Inference-SoC
# Spartan-7 FPGA Neural Processing Unit (NPU)

## Overview
A custom-designed Edge AI Accelerator SoC built on an Artix-7 FPGA for real-time MNIST digit recognition. This project offloads machine learning inference from software to dedicated hardware, utilizing a custom 16-core parallel MAC datapath to execute a 2-layer ReLU neural network. 

By leveraging hardware-level parallelism and direct memory access (DMA), this NPU achieves a **700x inference speedup** compared to a baseline MicroBlaze CPU implementation.

## Architecture & Hardware Design
* **Compute Core:** 16-core parallel MAC (Multiply-Accumulate) datapath controlled by a custom Finite State Machine (FSM).
* **Network Topology:** 2-layer neural network with ReLU activation.
* **Model Quantization:** PyTorch-based quantization pipeline to convert floating-point weights into hardware-optimized formats.
* **Memory Subsystem:** 
  * Weights are stored and accessed via 512-bit wide BRAM rows for high-bandwidth parallel reads.
  * Input images are streamed directly from DDR3 memory.
* **Interconnects:** 
  * **AXI4-Lite:** Handles control plane registers and CPU-to-Accelerator configuration.
  * **AXI-Stream & AXI-DMA:** Manages the high-speed data plane, streaming pixel data directly to the MAC array without CPU intervention.
* **Clocking:** Safely crosses and integrates three distinct clock domains, utilizing robust cache flushing protocols to maintain DMA read coherence.

## Performance Metrics
* **Throughput:** 700x acceleration in inference time vs. bare-metal MicroBlaze execution.
* **Bottleneck Mitigation:** Bypasses standard CPU memory bottlenecks via burst-transfers over AXI-DMA.

## Tech Stack
* **Hardware Description:** Verilog / SystemVerilog
* **Synthesis & Simulation:** Xilinx Vivado, Vitis
* **Machine Learning:** PyTorch (Quantization & Training)
* **Protocols:** AXI4-Lite, AXI-Stream, AXI-DMA

## Future Improvements
* [ ] Expand datapath to support deeper network architectures.
* [ ] Implement further power-optimization strategies across clock domains.
