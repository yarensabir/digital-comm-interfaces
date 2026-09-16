# 📡 Serial Communication IP Core Library (I2C, UART, SPI)

A modular, parameterized digital hardware IP library written in Verilog HDL. This repository provides foundational serial communication protocols designed for FPGA implementations, featuring standalone protocol controllers alongside optional **AMBA APB3** slave wrappers for SoC/processor integration.

---

## 📌 Architecture & Integration Layers

Each communication protocol is built in a two-layer modular architecture:
1. **Core Controller (Standalone):** Pure protocol engine handling serial timing, state transitions, framing, and bit-level transactions.
2. **Bus Wrapper (AMBA APB3):** Memory-mapped slave interface allowing CPU/SoC access via standard 32-bit control/data registers (`CTRL_REG`, `STATUS_REG`, `TX_DATA_REG`, `RX_DATA_REG`).

---

## 📊 FPGA Resource Utilization Summary

Benchmarks synthesized with **AMD Vivado ML v2024.2** targeting the **AMD Xilinx Artix-7 (XC7A35T-FTG256-1)**:

| Protocol | Module | Layer | Slice LUTs | Slice Registers (FF) | Carry4 | BRAM / DSP |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: |
| **I2C** | `i2c_master_rw` | Core (Native) | **55** *(0.26%)* | **45** *(0.11%)* | 0 | 0 / 0 |
| **UART** | `apb_uart_slave` | Core + APB3 Wrapper | **58** *(0.28%)* | **53** *(0.13%)* | 4 | 0 / 0 |
| **SPI** | `apb_spi_slave` | Core + APB3 Wrapper | **34** *(0.16%)* | **46** *(0.11%)* | 0 | 0 / 0 |

---

## 🔌 Protocol Details & Implementations

### 1. I2C (Inter-Integrated Circuit) Master
* **Protocol Specs:** Synchronous, multi-device, bidirectional two-wire bus using open-drain `SCL` and `SDA` lines with pull-up resistors.
* **Core Architecture (`i2c_master_rw`):**
  * Dedicated FSM managing `START`, `STOP`, and `REPEATED START` sequences.
  * Standard 7-bit slave addressing with read/write control.
  * Bidirectional `SDA` line handling with dedicated tri-state buffer driving (`sda_oe`, `sda_in`, `sda_out`) for ACK/NACK verification.
* **Target Interface:** Standalone native signals.

| Resource Type | Used | Total Available | Utilization (%) | Primitive Breakdown |
| :--- | :---: | :---: | :---: | :--- |
| **Slice LUTs** | **55** | 20,800 | 0.26% | 26 LUT6, 17 LUT3, 15 LUT5, 13 LUT4 |
| **Slice Registers** | **45** | 41,600 | 0.11% | 40 FDCE, 5 FDPE |
| **Tristate Buffers** | **1** | - | - | Dedicated `OBUFT` for physical `sda` pin |

---

### 2. UART (Universal Asynchronous Receiver-Transmitter)
* **Protocol Specs:** Asynchronous, full-duplex point-to-point communication. Frame: 1 Start bit, 8 Data bits (LSB-first), 1 Stop bit.
* **Implementation (`apb_uart_slave`):**
  * Independent TX and RX engines. Receiver utilizes midpoint bit-sampling to prevent clock drift errors.
  * Fully parameterized baud rate generator (`CLKS_PER_BIT = F_clk / Baud_rate`) allowing rapid simulation scaling.
  * Interfaced with an AMBA APB3 slave wrapper for register access.

| Resource Type | Used | Total Available | Utilization (%) | Primitive Breakdown |
| :--- | :---: | :---: | :---: | :--- |
| **Slice LUTs** | **58** | 20,800 | 0.28% | 29 LUT6, 22 LUT5, 4 LUT4, 4 LUT3, 3 LUT2, 1 LUT1 |
| **Slice Registers** | **53** | 41,600 | 0.13% | 51 FDCE, 2 FDPE |
| **Arithmetic Carry**| **4** | 8,150 | 0.05% | `CARRY4` blocks allocated for baud counter arithmetic |

---

### 3. SPI (Serial Peripheral Interface) Master
* **Protocol Specs:** Synchronous, four-wire, full-duplex communication bus using `SCK`, `MOSI`, `MISO`, and active-low `CS`.
* **Implementation (`apb_spi_slave`):**
  * Operates in SPI Mode 0 (CPOL = 0, CPHA = 0): Data shifted out on falling edge, sampled on rising edge.
  * Parameterized clock divider (`CLK_DIV`) to derive SPI serial clock from system clock.
  * Simultaneous 8-bit send/receive shift register architecture.
  * Wrapped with an AMBA APB3 interface with status polling (`busy`, `done_tick`).

| Resource Type | Used | Total Available | Utilization (%) | Primitive Breakdown |
| :--- | :---: | :---: | :---: | :--- |
| **Slice LUTs** | **34** | 20,800 | 0.16% | 14 LUT6, 10 LUT4, 6 LUT5, 5 LUT2, 3 LUT3, 1 LUT1 |
| **Slice Registers** | **46** | 41,600 | 0.11% | 41 FDCE, 5 FDPE |
| **Arithmetic Carry**| **0** | 8,150 | 0.00% | Synthesized entirely into Slice LUTs |

---

## 🧪 Simulation & Verification

All cores include self-checking behavioral testbenches:
* **Loopback Tests:** UART (`tx_pin` $\rightarrow$ `rx_pin`) and SPI (`mosi` $\rightarrow$ `miso`) validated under full transmission cycles.
* **Fast Verification:** Clock division parameters scale dynamically during simulation, allowing sub-microsecond execution without altering hardware logic.
