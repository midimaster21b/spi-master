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
use ieee.numeric_std.all;

entity spi_master is
  generic (
    Output_Buffer_Size : Integer   := 256;
    Input_Buffer_Size  : Integer   := 1;
    Clock_Polarity     : STD_LOGIC := '1';
    Clock_Phase        : STD_LOGIC := '0';
    MSB_First          : STD_LOGIC := '1'
    );
  port (
    -- Block necessities
    clk                : in  STD_LOGIC;
    rst                : in  STD_LOGIC;

    -- SPI lines
    spi_clk            : out STD_LOGIC;
    mosi_line          : out STD_LOGIC; -- := '1'
    miso_line          : in  STD_LOGIC;

    -----------------------------------
    -- SPI/Block interfaces
    -----------------------------------
    -- Tx
    s_axis_tdata       : in  STD_LOGIC_VECTOR( 7 downto 0);

    -- Rx
    m_axis_tdata       : out STD_LOGIC_VECTOR( 7 downto 0); -- := x"00";

    -- Control
    start              : in  STD_LOGIC;

    -- Stats
    num_rx_bytes       : in  STD_LOGIC_VECTOR(15 downto 0);
    num_tx_bytes       : in  STD_LOGIC_VECTOR(15 downto 0); -- := x"0001";

    -- Flags
    tx_ready_flag      : out STD_LOGIC; -- := '0';
    rx_ready_flag      : out STD_LOGIC; -- := '0';
    busy               : out STD_LOGIC  -- := '1'
    );
end spi_master;

architecture rtl of spi_master is

  signal byte_counter       : STD_LOGIC_VECTOR (15 downto 0) := x"0000";
  signal byte_rx_count      : STD_LOGIC_VECTOR (15 downto 0);
  signal byte_tx_count      : STD_LOGIC_VECTOR (15 downto 0);
  signal tx_busy            : STD_LOGIC;
  signal tx_clk_delay       : STD_LOGIC := '0';
  signal miso_byte_buffer   : STD_LOGIC_VECTOR (7 downto 0) := x"00";
  signal mosi_byte_buffer   : STD_LOGIC_VECTOR (7 downto 0) := x"00";
  signal start_trigger      : STD_LOGIC := '0';
  signal clear_trigger      : STD_LOGIC := '0';
  signal start_trigger_temp : STD_LOGIC_VECTOR (1 downto 0) := "00";

  -- State Machine
  type STATE_TYPE_T is (RESET_STATE, IDLE_STATE, TX_STATE, RX_STATE, FINISHED);
  signal current_state, next_state : STATE_TYPE_T;

begin

  -- Assign tx_busy signal to busy flag
  busy <= tx_busy;

  -- Move to the next state
  advance_state: process(clk)
  begin
    -- Synchronous reset
    if(rst = '1') then
      -- Set current and next state to reset
      current_state <= RESET_STATE;

    elsif clk'event and clk='1' then
      -- Advance to next state
      current_state <= next_state;

    end if;
  end process;


  -- Allow trigger that is shorter than a SPI clock cycle
  -- start_trigger <= (start_trigger or start) and not clear_trigger;
  trigger: process(start, clear_trigger)
  begin
    if clear_trigger = '1' then
      start_trigger <= '0';

    elsif start = '1' then
      start_trigger <= '1';

    end if;

  end process;


  -- Process for clearing the trigger
  trigger_clear: process(current_state)
  begin
    case current_state is
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
  store_bytes_num: process(clk, current_state)
  begin
    if current_state = idle and start_trigger = '1' then
      -- Store expected rx byte count
      byte_rx_count <= num_rx_bytes;

      -- Store expected tx byte count
      byte_tx_count <= num_tx_bytes;

    end if;
  end process;


  -- Determine the next state
  -- determine_state: process(clk, current_state)
  determine_state: process(current_state, start_trigger, byte_counter, byte_rx_count, byte_tx_count)
  begin
    case current_state is
      when RESET_STATE =>
        -- Move to the idle state
        next_state <= IDLE_STATE;

      when IDLE_STATE =>
        -- If triggered
        if start_trigger = '1' then
          -- Move to tx state
          next_state <= TX_STATE;

        else
          -- Stay in the current state
          next_state <= IDLE_STATE;

        end if;

      when TX_STATE =>
        -- If byte counter hit max
        if byte_counter(2 downto 0) = "111" and byte_counter(15 downto 3) >= byte_tx_count - 1 then
          -- Move to rx state
          next_state <= RX_STATE;

        else
          -- Stay in the current state
          next_state <= TX_STATE;

        end if;

      when RX_STATE =>
        -- If byte counter hit max
        -- Multiply by 8 for 8 bits per byte
        -- +8 for command byte
        -- -1 for zero indexed
        -- if byte_counter >= x"0028" then
        -- if byte_counter >= (byte_rx_count(12 downto 0) & "000") + 8 - 1 then
        -- if byte_counter >= (byte_rx_count(12 downto 0) & "111") then
        if byte_counter >= ((byte_rx_count(12 downto 0) + byte_tx_count - 1) & "111") then
          -- Move to finished state
          next_state <= FINISHED_STATE;

        else
          -- Stay in the current state
          next_state <= RX_STATE;

        end if;

      when FINISHED_STATE =>
        next_state <= IDLE_STATE;

    end case;
  end process;


  -- Handle busy device flag
  dev_busy: process(current_state)
  begin
    -- if current_state = tx or current_state = rx or current_state = finished then
    if current_state = RESET_STATE or current_state = IDLE_STATE then
      tx_busy <= '1';
    else
      tx_busy <= '0';
    end if;
  end process;


  -- Read Rx bits
  read_bits : process(clk)
  begin
    -- Trigger check on rising edge of clk
    if clk'event and rising_edge(clk) then
      -- If in receiving state
      if current_state = RX_STATE then
        -- Assign next input bit to miso_byte_buffer
        miso_byte_buffer <= miso_byte_buffer (6 downto 0) & miso_line;

      end if;

    end if;
  end process;


  -- Rx Ready Flag
  rx_flag : process(clk)
  begin
    -- Trigger check on rising edge of clk
    if clk'event and falling_edge(clk) then

      -- If currently receiving
      if current_state = RX_STATE and current_state = next_state then

        -- If modulo 8 = 0 (full byte read)
        -- if byte_counter (2 downto 0) = "000" and byte_counter > 8 then
        -- If modulo 8 = 0 and after last tx byte (assumes all tx bytes occur
        -- before all rx bytes)
        if byte_counter (2 downto 0) = "000" and byte_counter(15 downto 3) > byte_tx_count then
          -- Set the rx ready flag
          rx_ready_Flag <= '1';

          -- Set miso output byte
          m_axis_tdata <= miso_byte_buffer;

        else
          -- Set the rx ready flag
          rx_ready_Flag <= '0';

        end if;

      -- If finished receiving
      elsif current_state = FINISHED_STATE then
        -- Set the rx ready flag
        rx_ready_Flag <= '1';

        -- Set miso output byte
        m_axis_tdata <= miso_byte_buffer;

      -- All other states
      else
        -- Clear the rx ready flag
        rx_ready_Flag <= '0';

      end if;
    end if;
  end process;


  -- Tx Ready Flag
  -- tx_flag : process(clk)
  -- combinational logic only
  tx_flag : process(current_state, byte_counter, start_trigger, next_state)
  begin
    -- -- Trigger check on rising edge of clk
    -- if clk'event and falling_edge(clk) then

    -- If starting a transmission
    if current_state = IDLE_STATE and start_trigger = '1' then

      -- Store currently supplied byte
      mosi_byte_buffer <= s_axis_tdata;

      -- Set the rx ready flag
      tx_ready_flag <= '0';

    -- If currently transmitting
    elsif current_state = TX_STATE and current_state = next_state then

      -- Signal on 6th bit
      -- if byte_counter (2 downto 0) = "110" then
      if byte_counter (2 downto 0) = "111" then
        -- Set the rx ready flag
        tx_ready_flag <= '1';

      -- Store on 7th bit
      -- if byte_counter (2 downto 0) = "111" then
      -- elsif byte_counter (2 downto 0) = "111" then
      elsif byte_counter (2 downto 0) = "000" then
        -- Store currently supplied byte
        mosi_byte_buffer <= s_axis_tdata;
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
  counter : process(clk)
  begin
    -- If positive edge of the clk
    if clk'event and rising_edge(clk) then
      -- If not active state
      if current_state = RESET_STATE or current_state = IDLE_STATE or current_state = FINISHED_STATE then
        -- Reset the counter
        byte_counter <= x"0000";

      -- else active state
      else
        -- Increment the counter
        byte_counter <= byte_counter + 1;

      end if;
    end if;
  end process;


  -- SPI clock output
  spi_clk_gen : process(clk)
  begin
    -- If transmitting or receiving
    if current_state = TX_STATE or current_state = RX_STATE then
      -- Set SPI clock to output
      spi_clk <= clk;

    -- While transmitting or receiving
    else
      -- Set idle clock to polarity
      spi_clk <= Clock_Polarity;

    end if;
  end process;


  -- Output block (Tx)
  spi_out : process(clk)
  begin

    -- if current_state = tx then
    -- if current_state = tx or (current_state = rx and byte_counter (15 downto 3) <= num_tx_bytes) then
    if current_state = TX_STATE or (current_state = RX_STATE and byte_counter (15 downto 3) <= num_tx_bytes - 1) then
      if Clock_Polarity = '0' and Clock_Phase = '0' then
        if falling_edge(clk) then
          if MSB_First /= '1' then
            -- Set bit to output line
            mosi_line <= mosi_byte_buffer(to_integer(unsigned(byte_counter(2 downto 0))));

          else
            -- Set bit to output line
            mosi_line <= mosi_byte_buffer(7 - to_integer(unsigned(byte_counter(2 downto 0))));

          end if;
        end if;

      elsif Clock_Polarity = '0' and Clock_Phase = '1' then
        if rising_edge(clk) then
          if MSB_First /= '1' then
            -- Set bit to output line
            mosi_line <= mosi_byte_buffer(to_integer(unsigned(byte_counter(2 downto 0))));

          else
            -- Set bit to output line
            mosi_line <= mosi_byte_buffer(7 - to_integer(unsigned(byte_counter(2 downto 0))));

          end if;
        end if;

      elsif Clock_Polarity = '1' and Clock_Phase = '0' then
        if rising_edge(clk) then
          if MSB_First /= '1' then
            -- Set bit to output line
            mosi_line <= mosi_byte_buffer(to_integer(unsigned(byte_counter(2 downto 0))));

          else
            -- Set bit to output line
            mosi_line <= mosi_byte_buffer(7 - to_integer(unsigned(byte_counter(2 downto 0))));

          end if;
        end if;

      elsif Clock_Polarity = '1' and Clock_Phase = '1' then
        if falling_edge(clk) then
          if MSB_First /= '1' then
            -- Set bit to output line
            mosi_line <= mosi_byte_buffer(to_integer(unsigned(byte_counter(2 downto 0))));

          else
            -- Set bit to output line
            mosi_line <= mosi_byte_buffer(7 - to_integer(unsigned(byte_counter(2 downto 0))));

          end if;
        end if;
      end if;

    else
      -- Set to normally high
      mosi_line <= '1';

    end if; -- current_state = tx
  end process;
end rtl;
