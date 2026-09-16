# 🚀 AMBA APB3 Communication IP Core Library

A lightweight, modular, and parameterized hardware communication IP suite developed in Verilog HDL. This library provides standardized peripheral controllers interfaced via the **AMBA 3 APB (Advanced Peripheral Bus)** protocol, designed specifically for seamless integration into embedded SoC and RISC-V architectures.

---

## 📌 Architecture Overview

All peripherals share a standardized **32-bit Memory-Mapped I/O (MMIO)** register structure:
* `0x00` - **CTRL_REG** : Core execution controls and start triggers.
* `0x04` - **STATUS_REG**: Operational flags (`busy`, `done`, `rx_valid`).
* `0x08` - **TX_DATA_REG**: Data payload for transmission.
* `0x0C` - **RX_DATA_REG**: Captured incoming payload.

---

## 📊 FPGA Resource Utilization Summary

All synthesis benchmarks target the **AMD Xilinx Artix-7 (XC7A35T-FTG256-1)** FPGA using **Vivado ML v2024.2**.

| Module | Interface | Slice LUTs | Slice Registers (FF) | CARRY4 | BRAM / DSP | Primary Primitives |
| :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| **I2C Master** (`i2c_master_rw`) | Standalone | **55** *(0.26%)* | **45** *(0.11%)* | 0 | 0 / 0 | 26 LUT6, 17 LUT3, 40 FDCE, 5 FDPE |
| **UART Subsystem** (`apb_uart_slave`) | AMBA APB3 | **58** *(0.28%)* | **53** *(0.13%)* | 4 | 0 / 0 | 29 LUT6, 22 LUT5, 51 FDCE, 2 FDPE |
| **SPI Master** (`apb_spi_slave`) | AMBA APB3 | **34** *(0.16%)* | **46** *(0.11%)* | 0 | 0 / 0 | 14 LUT6, 10 LUT4, 41 FDCE, 5 FDPE |

---

## 🛠 Module Breakdown & Detailed Utilization

### 1. I2C Master Core (`i2c_master_rw`)
* **Features:** Bidirectional single-master controller supporting standard 7-bit addressing, repeated START conditions, and ACK/NACK generation.
* **Interface:** Standalone native signals (`scl`, `sda_in`, `sda_out`, `sda_oe`).

| Resource Type | Used | Total Available | Utilization (%) | Primitive Breakdown |
| :--- | :---: | :---: | :---: | :--- |
| **Slice LUTs** | **55** | 20,800 | 0.26% | 26 LUT6, 17 LUT3, 15 LUT5, 13 LUT4 |
| **Slice Registers** | **45** | 41,600 | 0.11% | 40 FDCE, 5 FDPE |
| **Tristate Buffers** | **1** | - | - | Dedicated `OBUFT` for bidirectional `sda` line |
| **BRAM / DSP** | **0** | - | 0.00% | Pure distributed logic |

---

### 2. UART APB3 Peripheral (`apb_uart_slave`)
* **Features:** Full-duplex asynchronous communication block with configurable baud rate divisor (`CLKS_PER_BIT`), internal status polling, and APB register interface.
* **Verification:** Loopback verified (`tx_pin` connected to `rx_pin`).

| Resource Type | Used | Total Available | Utilization (%) | Primitive Breakdown |
| :--- | :---: | :---: | :---: | :--- |
| **Slice LUTs** | **58** | 20,800 | 0.28% | 29 LUT6, 22 LUT5, 4 LUT4, 4 LUT3, 3 LUT2, 1 LUT1 |
| **Slice Registers** | **53** | 41,600 | 0.13% | 51 FDCE, 2 FDPE |
| **Arithmetic Carry**| **4** | 8,150 | 0.05% | Hardware adders (`CARRY4`) for baud rate generator |
| **BRAM / DSP** | **0** | - | 0.00% | Pure distributed logic |

---

### 3. SPI Master APB3 Peripheral (`apb_spi_slave`)
* **Features:** Synchronous serial master controller supporting configurable SPI clock divider (`CLK_DIV`), active-low chip select (`cs`), and APB3 bus wrapper.
* **Verification:** Full-duplex loopback verified (`mosi` connected to `miso`).

| Resource Type | Used | Total Available | Utilization (%) | Primitive Breakdown |
| :--- | :---: | :---: | :---: | :--- |
| **Slice LUTs** | **34** | 20,800 | 0.16% | 14 LUT6, 10 LUT4, 6 LUT5, 5 LUT2, 3 LUT3, 1 LUT1 |
| **Slice Registers** | **46** | 41,600 | 0.11% | 41 FDCE, 5 FDPE |
| **Arithmetic Carry**| **0** | 8,150 | 0.00% | Handled via slice LUT counters |
| **BRAM / DSP** | **0** | - | 0.00% | Pure distributed logic |

---

## 💻 Simulation & Verification Flow

All testbenches are self-checking and leverage parameterized clock division for rapid RTL execution:
1. **Behavioral Simulation:** Open Vivado and select the desired testbench as top (`*_tb.v`).
2. **Execution:** Run simulation for ~1 µs to verify loopback transfer assertions via Tcl Console.
