library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_rx is
    generic (
        g_CLKS_PER_BIT : integer := 5208 -- Default for 9600 baud with 50MHz clock
    );
    port (
        i_clk            : in  std_logic;
        i_rst            : in  std_logic;
        i_rx_serial      : in  std_logic;                      -- Serial data input
        o_rx_data_valid  : out std_logic;                      -- Pulse high when new data is ready
        o_rx_data        : out std_logic_vector(7 downto 0)   -- Received data
    );
end entity uart_rx;

architecture rtl of uart_rx is
    -- State machine for the receiver
    type t_rx_state is (ST_IDLE, ST_START_BIT, ST_DATA_BITS, ST_STOP_BIT);
    signal r_rx_state   : t_rx_state := ST_IDLE;

    -- Internal registers
    signal r_clk_counter : integer range 0 to g_CLKS_PER_BIT - 1 := 0;
    signal r_bit_index   : integer range 0 to 7 := 0;
    signal r_rx_data     : std_logic_vector(7 downto 0) := (others => '0');
    signal r_rx_d_valid  : std_logic := '0';

begin

    o_rx_data_valid <= r_rx_d_valid;
    o_rx_data <= r_rx_data;

    process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                -- Reset state
                r_rx_state    <= ST_IDLE;
                r_clk_counter <= 0;
                r_bit_index   <= 0;
                r_rx_d_valid  <= '0';
            else
                -- De-assert data valid signal after one clock cycle to make it a pulse
                r_rx_d_valid <= '0';

                case r_rx_state is

                    when ST_IDLE =>
                        -- Wait for the falling edge of the start bit
                        if i_rx_serial = '0' then
                            r_rx_state    <= ST_START_BIT;
                            r_clk_counter <= 0;
                        end if;

                    when ST_START_BIT =>
                        -- Wait for half a bit-period to sample in the middle
                        if r_clk_counter = (g_CLKS_PER_BIT / 2) - 1 then
                            -- Check if the line is still low (a valid start bit)
                            if i_rx_serial = '0' then
                                r_clk_counter <= 0;
                                r_bit_index   <= 0;
                                r_rx_state    <= ST_DATA_BITS;
                            else -- Glitch, not a real start bit, return to idle
                                r_rx_state <= ST_IDLE;
                            end if;
                        else
                            r_clk_counter <= r_clk_counter + 1;
                        end if;

                    when ST_DATA_BITS =>
                        -- Wait for a full bit-period to get to the middle of the next bit
                        if r_clk_counter < g_CLKS_PER_BIT - 1 then
                            r_clk_counter <= r_clk_counter + 1;
                        else
                            r_clk_counter <= 0;
                            r_rx_data(r_bit_index) <= i_rx_serial; -- Sample the data bit

                            -- Move to the next bit or to the stop bit
                            if r_bit_index < 7 then
                                r_bit_index <= r_bit_index + 1;
                            else
                                r_rx_state <= ST_STOP_BIT;
                            end if;
                        end if;

                    when ST_STOP_BIT =>
                        -- Wait for a bit-period and check for the stop bit
                        if r_clk_counter < g_CLKS_PER_BIT - 1 then
                            r_clk_counter <= r_clk_counter + 1;
                        else
                            -- Frame is complete, data is ready
                            if i_rx_serial = '1' then -- Check for valid stop bit
                                r_rx_d_valid <= '1';
                            end if;
                            r_rx_state <= ST_IDLE;
                        end if;

                end case;
            end if;
        end if;
    end process;

end architecture rtl;

--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_uart is
end entity tb_uart;

architecture sim of tb_uart is
    -- Constants for simulation
    constant c_CLK_PERIOD      : time    := 20 ns; -- 50 MHz clock
    constant c_CLK_FREQUENCY   : integer := 50_000_000;
    constant c_BAUD_RATE       : integer := 9600;
    constant c_CLKS_PER_BIT    : integer := c_CLK_FREQUENCY / c_BAUD_RATE;

    -- Signals to connect the modules
    signal w_clk            : std_logic := '0';
    signal w_rst            : std_logic;
    signal w_tx_start       : std_logic;
    signal w_tx_data        : std_logic_vector(7 downto 0);
    signal w_tx_serial      : std_logic;
    signal w_tx_busy        : std_logic;

    signal w_rx_data_valid  : std_logic;
    signal w_rx_data        : std_logic_vector(7 downto 0);

begin
    -- Instantiate Transmitter
    UUT_TX: entity work.uart_tx
        generic map (
            g_CLKS_PER_BIT => c_CLKS_PER_BIT
        )
        port map (
            i_clk       => w_clk,
            i_rst       => w_rst,
            i_tx_start  => w_tx_start,
            i_tx_data   => w_tx_data,
            o_tx_serial => w_tx_serial,
            o_tx_busy   => w_tx_busy
        );

    -- Instantiate Receiver (in loopback)
    UUT_RX: entity work.uart_rx
        generic map (
            g_CLKS_PER_BIT => c_CLKS_PER_BIT
        )
        port map (
            i_clk           => w_clk,
            i_rst           => w_rst,
            i_rx_serial     => w_tx_serial, -- Loopback from transmitter output
            o_rx_data_valid => w_rx_data_valid,
            o_rx_data       => w_rx_data
        );

    -- Clock generation process
    w_clk <= not w_clk after c_CLK_PERIOD / 2;

    -- Simulation stimulus process
    stim_proc: process
    begin
        -- Start with reset
        w_rst <= '1';
        wait for 100 ns;
        w_rst <= '0';
        wait for c_CLK_PERIOD;

        -- ######### Test 1: Send byte 0xA5 (binary 10100101) #########
        report "TESTBENCH: Sending 0xA5 (10100101)...";
        w_tx_data <= x"A5";
        w_tx_start <= '1';
        wait for c_CLK_PERIOD;
        w_tx_start <= '0';

        -- Wait for transmission to finish
        wait until w_tx_busy = '0';
        wait for 1 us;

        -- ######### Test 2: Send byte 0x3C (binary 00111100) #########
        report "TESTBENCH: Sending 0x3C (00111100)...";
        w_tx_data <= x"3C";
        w_tx_start <= '1';
        wait for c_CLK_PERIOD;
        w_tx_start <= '0';

        wait until w_tx_busy = '0';
        wait for 10 us;

        report "TESTBENCH: Simulation finished." severity failure; -- 'failure' stops the simulation
    end process stim_proc;

end architecture sim;
