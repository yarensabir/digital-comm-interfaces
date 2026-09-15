# Digital Communication Interfaces (RTL)

Synthesizable, modular, and parameterizable serial communication IP cores implemented in Verilog (IEEE 1364-2001) for FPGA and ASIC architectures.

## 📌 Features

### UART Core (`uart_tx.v` & `uart_rx.v`)
* **Frame Format**: 8-N-1 (1 Start bit, 8 Data bits, No parity, 1 Stop bit).
* **Timing**: Configurable clock-per-bit counter (default: 100 MHz clock, 9600 baud -> 10,400 clocks/bit).
* **Transmitter (TX)**: FSM-driven serializer with deterministic transmission intervals.
* **Receiver (RX)**: Mid-bit oversampling strategy with false-start glitch rejection.
* **Verification**: Self-checking loopback testbench verifying full TX-to-RX transmission.

### SPI Master Core (`spi_master.v`)
* **Protocol Mode**: SPI Mode 0 (CPOL = 0, CPHA = 0).
* **Frame Format**: 8-bit full-duplex data exchange, MSB-first.
* **Timing**: Parameterized clock divider (`CLK_DIV`) generating SCK from system clock.
* **Control**: Single-cycle start trigger, active-low Chip Select (`cs`), and `done_tick` completion flag.
* **Verification**: Self-checking testbench simulating a virtual SPI slave device.

### I2C Master Core (`i2c_master_full.v`)
* **Physical Layer**: Tristate/open-drain bus control (`1'bz` release / `1'b0` drive) with external/internal pull-up architecture.
* **Timing Generator**: 4-phase micro-state machine per SCL cycle ensuring data setup and hold compliance.
* **Transactions Supported**:
  * Single-byte Write (Device Addressing, ACK checking, Data Write, ACK checking, STOP).
  * Single-byte Read (Device Addressing, ACK checking, Data Sampling, Master NACK, STOP).
* **Robust Error Handling**: Dynamic `ack_error` flag asserted upon missing slave acknowledgment.
* **Verification**: Self-checking testbench interacting with an emulated responsive I2C slave peripheral.

---

## 🔬 Simulation & Verification

### UART Loopback Verification
The loopback architecture connects `tx_pin` directly to `rx_pin`. Transmission of byte `0xA5` (binary: `10100101`) verified in AMD Xilinx Vivado ML.

### SPI Master Verification
The SPI Master module is verified via a full-duplex exchange against an emulated SPI slave model:
* **TX (Master -> Slave)**: Transmission of byte `0x3C` (`8'b00111100`) via `mosi`.
* **RX (Slave -> Master)**: Simultaneous reception of byte `0x89` (`8'b10001001`) via `miso`.
* Waveform analysis confirms Mode 0 timing: data driven on falling edges and sampled on rising edges of `sck`.

### I2C Master Read Verification
Verified behavioral simulation targeting an emulated slave at address `7'h50` responding with sensor payload `0xA5`:

| Step / Condition | SCL Cycles | Duration (`CLK_DIV = 10`, 100 MHz Clk) |
| :--- | :---: | :--- |
| **START Condition** | 1 | $400\text{ ns}$ |
| **Slave Address + R/W Bit (`7'h50` + `1'b1`)** | 8 | $3.200\text{ ns}$ |
| **Slave ACK Evaluation** | 1 | $400\text{ ns}$ |
| **Data Reception Phase** | 8 | $3.200\text{ ns}$ |
| **Master NACK Generation** | 1 | $400\text{ ns}$ |
| **STOP Condition** | 1 | $400\text{ ns}$ |
| **Total Packet Duration** | **20 Cycles** | **$8.000\text{ ns}\ (8\ \mu\text{s})$** |

* Waveform analysis confirms complete reception of `0xA5` into `rx_data[7:0]` without asserting `ack_error`.

---

## 📊 FPGA Resource Utilization (AMD Xilinx Artix-7)

Synthesized with AMD Xilinx Vivado ML (v2024.2) targeting the **XC7A35T-FTG256-1** FPGA:

| Resource Type | Used | Total Available | Utilization (%) | Primary Primitive Breakdown |
| :--- | :---: | :---: | :---: | :--- |
| **Slice LUTs** | **55** | 20,800 | 0.26% | 26 LUT6, 17 LUT3, 15 LUT5, 13 LUT4 |
| **Slice Registers (FF)** | **45** | 41,600 | 0.11% | 40 FDCE (Async Reset), 5 FDPE (Async Set) |
| **Block RAM (BRAM)** | **0** | 50 | 0.00% | Pure distributed logic |
| **DSP Blocks** | **0** | 90 | 0.00% | No hardware multipliers instantiated |
| **Tristate Buffers (OBUFT)** | **1** | - | - | Dedicated I/O tristate buffer for bidirectional `sda` |

---

## 📁 Repository Structure

* **`UART/`**: Core Verilog implementation and testbench (`uart_tx.v`, `uart_rx.v`, `tb_uart_tx.v`, `uart_loopback_tb.v`).
* **`SPI/`**: Core Verilog implementation and testbench (`spi_master.v`, `spi_master_tb.v`).
* **`I2C/`**: Core Verilog implementation and testbench (`i2c_master.v`,`i2c_master_rw.v`, `i2c_master_tb.v`,`i2c_master_rw_tb.v`).
