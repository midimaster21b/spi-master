----------------------------------------------------------------------------------
-- Company:
-- Engineer: Joshua Edgcombe
--
-- Create Date: 03/06/2019 01:09:30 PM
-- Design Name:
-- Module Name: SPI_Master_state - Behavioral
-- Project Name:
-- Target Devices:
-- Tool Versions:
-- Description:
--
-- Dependencies:
--
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spi_master is
  generic (
    CLOCK_POLARITY_G     : std_logic := '1';
    CLOCK_PHASE_G        : std_logic := '0';
    MSB_FIRST_G          : std_logic := '1'
    );
  port (
    -- Block necessities
    clk_in               : in  std_logic;
    rst_in               : in  std_logic;

    -- SPI lines
    sclk                 : out std_logic;
    mosi                 : out std_logic; -- := '1'
    miso                 : in  std_logic;
    cs                   : out std_logic;

    -----------------------------------
    -- SPI/Block interfaces
    -----------------------------------
    -- Tx
    s_axis_tdata       : in  std_logic_vector( 7 downto 0);

    -- Rx
    m_axis_tdata       : out std_logic_vector( 7 downto 0);

    -- Control
    start              : in  std_logic;

    -- Stats
    num_rx_bytes       : in  std_logic_vector(15 downto 0);
    num_tx_bytes       : in  std_logic_vector(15 downto 0);

    -- Flags
    tx_ready_flag      : out std_logic; -- := '0';
    rx_ready_flag      : out std_logic; -- := '0';
    busy               : out std_logic  -- := '1'
    );
end spi_master;

architecture rtl of spi_master is

  signal byte_counter_r     : std_logic_vector (15 downto 0) := x"0000";
  signal byte_rx_count_r    : std_logic_vector (15 downto 0);
  signal byte_tx_count_r    : std_logic_vector (15 downto 0);
  signal busy_r             : std_logic;
  signal miso_byte_buffer_r : std_logic_vector (7 downto 0) := x"00";
  signal mosi_byte_buffer_r : std_logic_vector (7 downto 0) := x"00";
  signal start_trigger      : std_logic := '0';
  signal clear_trigger      : std_logic := '0';
  signal start_trigger_temp : std_logic_vector (1 downto 0) := "00";

  -- State Machine
  type STATE_TYPE_T is (RESET_STATE, IDLE_STATE, TX_STATE, RX_STATE, FINISHED);
  signal current_state_r, next_state_s : STATE_TYPE_T;

begin

  -- Assign busy_r signal to busy flag
  busy <= busy_r;


  -- Move to the next state
  advance_state: process(clk_in)
  begin
    -- Synchronous reset
    if(rst_in = '1') then
      -- Set current and next state to reset
      current_state_r <= RESET_STATE;

    elsif clk_in'event and clk_in='1' then
      -- Advance to next state
      current_state_r <= next_state_s;

    end if;
  end process;


  -- Allow trigger that is shorter than a SPI clock cycle
  trigger: process(start, clear_trigger)
  begin
    if clear_trigger = '1' then
      start_trigger <= '0';

    elsif start = '1' then
      start_trigger <= '1';

    end if;

  end process;


  -- Process for clearing the trigger
  trigger_clear: process(current_state_r)
  begin
    case current_state_r is
      when RESET_STATE =>
        -- Clear any triggers
        clear_trigger <= '1';

      when IDLE_STATE =>
        -- Allow trigger to be armed
        clear_trigger <= '0';

      when RX_STATE =>
        clear_trigger <= '0';

      when TX_STATE =>
        clear_trigger <= '0';

      when FINISHED_STATE =>
        -- Clear trigger when finished
        clear_trigger <= '1';

    end case;
  end process;


  -- Process for storing max bytes
  store_bytes_num: process(clk_in, current_state_r)
  begin
    if current_state_r = idle and start_trigger = '1' then
      -- Store expected rx byte count
      byte_rx_count_r <= num_rx_bytes;

      -- Store expected tx byte count
      byte_tx_count_r <= num_tx_bytes;

    end if;
  end process;


  -- Determine the next state
  determine_state: process(current_state_r, start_trigger, byte_counter_r, byte_rx_count_r, byte_tx_count_r)
  begin
    case current_state_r is
      when RESET_STATE =>
        -- Move to the idle state
        next_state_s <= IDLE_STATE;

      when IDLE_STATE =>
        -- If triggered
        if start_trigger = '1' then
          -- Move to tx state
          next_state_s <= TX_STATE;

        else
          -- Stay in the current state
          next_state_s <= IDLE_STATE;

        end if;

      when TX_STATE =>
        -- If byte counter hit max
        if byte_counter_r(2 downto 0) = "111" and byte_counter_r(15 downto 3) >= byte_tx_count_r - 1 then
          -- Move to rx state
          next_state_s <= RX_STATE;

        else
          -- Stay in the current state
          next_state_s <= TX_STATE;

        end if;

      when RX_STATE =>
        -- If byte counter hit max
        -- Multiply by 8 for 8 bits per byte
        -- +8 for command byte
        -- -1 for zero indexed
        -- if byte_counter_r >= x"0028" then
        -- if byte_counter_r >= (byte_rx_count_r(12 downto 0) & "000") + 8 - 1 then
        -- if byte_counter_r >= (byte_rx_count_r(12 downto 0) & "111") then
        if byte_counter_r >= ((byte_rx_count_r(12 downto 0) + byte_tx_count_r - 1) & "111") then
          -- Move to finished state
          next_state_s <= FINISHED_STATE;

        else
          -- Stay in the current state
          next_state_s <= RX_STATE;

        end if;

      when FINISHED_STATE =>
        next_state_s <= IDLE_STATE;

    end case;
  end process;


  -- Handle busy device flag
  dev_busy: process(current_state_r)
  begin
    if current_state_r = RESET_STATE or current_state_r = IDLE_STATE then
      busy_r <= '1';
    else
      busy_r <= '0';
    end if;
  end process;


  -- Read Rx bits
  read_bits : process(clk_in)
  begin
    -- Trigger check on rising edge of clk
    if clk_in'event and rising_edge(clk_in) then
      -- If in receiving state
      if current_state_r = RX_STATE then
        -- Assign next input bit to miso_byte_buffer_r
        miso_byte_buffer_r <= miso_byte_buffer_r (6 downto 0) & miso;

      end if;

    end if;
  end process;


  -- Rx Ready Flag
  rx_flag : process(clk_in)
  begin
    -- Trigger check on rising edge of clk
    if clk_in'event and falling_edge(clk_in) then

      -- If currently receiving
      if current_state_r = RX_STATE and current_state_r = next_state_s then

        -- If modulo 8 = 0 (full byte read)
        -- if byte_counter_r (2 downto 0) = "000" and byte_counter_r > 8 then
        -- If modulo 8 = 0 and after last tx byte (assumes all tx bytes occur
        -- before all rx bytes)
        if byte_counter_r (2 downto 0) = "000" and byte_counter_r(15 downto 3) > byte_tx_count_r then
          -- Set the rx ready flag
          rx_ready_Flag <= '1';

          -- Set miso output byte
          m_axis_tdata <= miso_byte_buffer_r;

        else
          -- Set the rx ready flag
          rx_ready_Flag <= '0';

        end if;

      -- If finished receiving
      elsif current_state_r = FINISHED_STATE then
        -- Set the rx ready flag
        rx_ready_Flag <= '1';

        -- Set miso output byte
        m_axis_tdata <= miso_byte_buffer_r;

      -- All other states
      else
        -- Clear the rx ready flag
        rx_ready_Flag <= '0';

      end if;
    end if;
  end process;


  -- Tx Ready Flag
  -- combinational logic only
  tx_flag : process(current_state_r, byte_counter_r, start_trigger, next_state_s)
  begin
    -- If starting a transmission
    if current_state_r = IDLE_STATE and start_trigger = '1' then

      -- Store currently supplied byte
      mosi_byte_buffer_r <= s_axis_tdata;

      -- Set the rx ready flag
      tx_ready_flag <= '0';

    -- If currently transmitting
    elsif current_state_r = TX_STATE and current_state_r = next_state_s then

      -- Signal on 6th bit
      -- if byte_counter_r (2 downto 0) = "110" then
      if byte_counter_r (2 downto 0) = "111" then
        -- Set the rx ready flag
        tx_ready_flag <= '1';

      -- Store on 7th bit
      -- if byte_counter_r (2 downto 0) = "111" then
      -- elsif byte_counter_r (2 downto 0) = "111" then
      elsif byte_counter_r (2 downto 0) = "000" then
        -- Store currently supplied byte
        mosi_byte_buffer_r <= s_axis_tdata;
        -- tx_ready_flag <= '0';
        -- tx_ready_flag <= '1';

      else
        -- Set the rx ready flag
        tx_ready_flag <= '0';

      end if;

    -- All other states
    else
      -- Clear the rx ready flag
      tx_ready_flag <= '0';

    end if;
  -- end if;
  end process;


  -- Byte counter
  counter : process(clk_in)
  begin
    -- If positive edge of the clk
    if clk_in'event and rising_edge(clk_in) then
      -- If not active state
      if current_state_r = RESET_STATE or current_state_r = IDLE_STATE or current_state_r = FINISHED_STATE then
        -- Reset the counter
        byte_counter_r <= x"0000";

      -- else active state
      else
        -- Increment the counter
        byte_counter_r <= byte_counter_r + 1;

      end if;
    end if;
  end process;


  -- SPI clock output
  spi_clk_gen : process(clk_in)
  begin
    -- If transmitting or receiving
    if current_state_r = TX_STATE or current_state_r = RX_STATE then
      -- Set SPI clock to output
      sclk <= clk_in;

    -- While transmitting or receiving
    else
      -- Set idle clock to polarity
      sclk <= CLOCK_POLARITY_G;

    end if;
  end process;


  -- Output block (Tx)
  spi_out : process(clk_in)
  begin
    if current_state_r = TX_STATE or (current_state_r = RX_STATE and byte_counter_r (15 downto 3) <= num_tx_bytes - 1) then
      if CLOCK_POLARITY_G = '0' and CLOCK_PHASE_G = '0' then
        if falling_edge(clk_in) then
          if MSB_First /= '1' then
            -- Set bit to output line
            mosi <= mosi_byte_buffer_r(to_integer(unsigned(byte_counter_r(2 downto 0))));

          else
            -- Set bit to output line
            mosi <= mosi_byte_buffer_r(7 - to_integer(unsigned(byte_counter_r(2 downto 0))));

          end if;
        end if;

      elsif CLOCK_POLARITY_G = '0' and CLOCK_PHASE_G = '1' then
        if rising_edge(clk_in) then
          if MSB_First /= '1' then
            -- Set bit to output line
            mosi <= mosi_byte_buffer_r(to_integer(unsigned(byte_counter_r(2 downto 0))));

          else
            -- Set bit to output line
            mosi <= mosi_byte_buffer_r(7 - to_integer(unsigned(byte_counter_r(2 downto 0))));

          end if;
        end if;

      elsif CLOCK_POLARITY_G = '1' and CLOCK_PHASE_G = '0' then
        if rising_edge(clk_in) then
          if MSB_First /= '1' then
            -- Set bit to output line
            mosi <= mosi_byte_buffer_r(to_integer(unsigned(byte_counter_r(2 downto 0))));

          else
            -- Set bit to output line
            mosi <= mosi_byte_buffer_r(7 - to_integer(unsigned(byte_counter_r(2 downto 0))));

          end if;
        end if;

      elsif CLOCK_POLARITY_G = '1' and CLOCK_PHASE_G = '1' then
        if falling_edge(clk_in) then
          if MSB_First /= '1' then
            -- Set bit to output line
            mosi <= mosi_byte_buffer_r(to_integer(unsigned(byte_counter_r(2 downto 0))));

          else
            -- Set bit to output line
            mosi <= mosi_byte_buffer_r(7 - to_integer(unsigned(byte_counter_r(2 downto 0))));

          end if;
        end if;
      end if;

    else
      -- Set to normally high
      mosi <= '1';

    end if; -- current_state_r = tx
  end process;
end rtl;
