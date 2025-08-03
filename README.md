VHDL UART Transmitter/Receiver

This project contains a straightforward and parameterizable UART (Universal Asynchronous Receiver/Transmitter) implementation in VHDL. It includes separate modules for the transmitter (uart_tx) and receiver (uart_rx), along with a testbench for verification.
The design is intended to be simple, readable, and easily integrated into larger FPGA projects.

What is This?

A UART is a serial communication block that converts parallel data from a system into a serial bitstream that can be sent over a single wire, and vice-versa. This implementation handles standard 8-bit data frames with one start bit and one stop bit (8-N-1 format).
uart_tx: Takes an 8-bit byte and sends it out bit-by-bit.
uart_rx: Listens for incoming bits, validates the frame, and reassembles the 8-bit byte.

Features

Parameterized: Easily configure the system clock frequency and desired baud rate using VHDL generics.
Standard 8-N-1 Framing: Uses 1 start bit, 8 data bits, and 1 stop bit.
Loopback Testbench: Includes a self-contained testbench that connects the transmitter output directly to the receiver input to verify functionality.
Clear I/O: Simple start/busy and valid/data interfaces for easy integration.


How to Run the Simulation

  This project is ready to run on a platform like EDA Playground.
  Copy the UART architectures into the design.vhd window.
  Copy the tb_uart architecture into the testbench.vhd window.

Select a Simulator:

  Choose a simulator like Aldec Riviera Pro.

Run:

  Enable the "Open EPWave after run" option.
  Click "Run". The waveform will open, showing the transmission and reception of the test bytes (0xA5 and 0x3C).

Configuration

  The core of the UART's timing is the g_CLKS_PER_BIT generic. This value tells the state machine how many system clock cycles make up one bit period. You should calculate it as follows:
  g_CLKS_PER_BIT = (System Clock Frequency) / (Baud Rate)

For example, for a 50 MHz clock and a 9600 baud rate:
  50,000,000 / 9600 = 5208

You can change this value in the generic map of the testbench or when you instantiate the modules in your own design.

Possible Improvements

  This is a basic implementation. For more robust applications, consider adding:
  Parity Bit: Add support for even or odd parity for basic error checking.
  FIFO Buffers: Add FIFOs on both the transmitter and receiver to buffer multiple bytes, preventing data loss in a busy system.
  Error Reporting: Add output flags on the receiver to report framing errors (e.g., stop bit not detected) or parity errors.
