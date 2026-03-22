library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_tx is
    generic (
        -- The number of clock cycles required for one bit period.
        -- Example: 50,000,000 Hz Clock / 9600 Baud = 5208
        g_CLKS_PER_BIT : integer := 5208
    );
    port (
        i_clk       : in  std_logic;
        i_rst       : in  std_logic;
        i_tx_start  : in  std_logic;                      -- Pulse to start transmission
        i_tx_data   : in  std_logic_vector(7 downto 0);   -- Data to send
        o_tx_serial : out std_logic;                      -- Serial data output
        o_tx_busy   : out std_logic                       -- High while transmitting
    );
end entity uart_tx;

architecture rtl of uart_tx is
    -- State machine for the transmitter
    type t_tx_state is (ST_IDLE, ST_START_BIT, ST_DATA_BITS, ST_STOP_BIT);
    signal r_tx_state    : t_tx_state := ST_IDLE;

    -- Internal registers
    signal r_clk_counter : integer range 0 to g_CLKS_PER_BIT - 1 := 0;
    signal r_bit_index   : integer range 0 to 7 := 0;
    signal r_tx_data     : std_logic_vector(7 downto 0) := (others => '0');
    signal r_tx_busy     : std_logic := '0';

begin

    o_tx_busy <= r_tx_busy;

    process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                -- Reset state
                r_tx_state    <= ST_IDLE;
                r_clk_counter <= 0;
                r_bit_index   <= 0;
                o_tx_serial   <= '1'; -- Idle line is high
                r_tx_busy     <= '0';
            else
                case r_tx_state is

                    when ST_IDLE =>
                        o_tx_serial <= '1'; -- Line is high when idle
                        r_tx_busy   <= '0';
                        r_clk_counter <= 0;
                        r_bit_index   <= 0;

                        -- On start pulse, latch data and begin transmission
                        if i_tx_start = '1' then
                            r_tx_busy   <= '1';
                            r_tx_data   <= i_tx_data;
                            r_tx_state  <= ST_START_BIT;
                        end if;

                    when ST_START_BIT =>
                        o_tx_serial <= '0'; -- Drive line low for the start bit
                        -- Wait for one full bit period
                        if r_clk_counter < g_CLKS_PER_BIT - 1 then
                            r_clk_counter <= r_clk_counter + 1;
                        else
                            r_clk_counter <= 0;
                            r_tx_state <= ST_DATA_BITS;
                        end if;

                    when ST_DATA_BITS =>
                        o_tx_serial <= r_tx_data(r_bit_index); -- Send data bit (LSB first)
                        -- Wait for one full bit period
                        if r_clk_counter < g_CLKS_PER_BIT - 1 then
                            r_clk_counter <= r_clk_counter + 1;
                        else
                            r_clk_counter <= 0;
                            -- Move to the next bit or to the stop bit
                            if r_bit_index < 7 then
                                r_bit_index <= r_bit_index + 1;
                            else
                                r_tx_state <= ST_STOP_BIT;
                            end if;
                        end if;

                    when ST_STOP_BIT =>
                        o_tx_serial <= '1'; -- Drive line high for the stop bit
                        -- Wait for one full bit period
                        if r_clk_counter < g_CLKS_PER_BIT - 1 then
                            r_clk_counter <= r_clk_counter + 1;
                        else
                            r_clk_counter <= 0;
                            r_tx_state <= ST_IDLE; -- Return to idle
                        end if;

                end case;
            end if;
        end if;
    end process;
end architecture rtl;
