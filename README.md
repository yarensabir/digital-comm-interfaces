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

---

## 🔬 Simulation & Verification

### UART Loopback Verification
The loopback architecture connects `tx_pin` directly to `rx_pin`. Transmission of byte `0xA5` (binary: `10100101`) verified in AMD Xilinx Vivado ML.

### SPI Master Verification
The SPI Master module is verified via a full-duplex exchange against an emulated SPI slave model:
* **TX (Master -> Slave)**: Transmission of byte `0x3C` (`8'b00111100`) via `mosi`.
* **RX (Slave -> Master)**: Simultaneous reception of byte `0x89` (`8'b10001001`) via `miso`.
* Waveform analysis confirms Mode 0 timing: data driven on falling edges and sampled on rising edges of `sck`.

---

## 📁 Repository Structure

* **`uart/`**: Core Verilog implementation and testbench (`uart_tx.v`, `uart_rx.v`, `uart_loopback_tb.v`).
* **`spi/`**: Core Verilog implementation and testbench (`spi_master.v`, `spi_master_tb.v`).
* **`/rtl/`**: Synthesizable Verilog modules.
* **`/tb/`**: Self-checking testbench environments.
* **`/docs/`**: Simulation waveforms and architecture schematics.
