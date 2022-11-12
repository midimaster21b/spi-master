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
    CLOCK_POLARITY_G     : std_logic := '0';
    CLOCK_PHASE_G        : std_logic := '0';
    MSB_FIRST_G          : std_logic := '1';
    RST_LEVEL_G          : std_logic := '1'
    );
  port (
    -- Block necessities
    clk_in               : in  std_logic;
    rst_in               : in  std_logic;

    -----------------------------------
    -- SPI lines
    -----------------------------------
    sclk                 : out std_logic;
    mosi                 : out std_logic;
    miso                 : in  std_logic;
    cs                   : out std_logic;

    -----------------------------------
    -- AXIS interface
    -----------------------------------
    -- Tx
    s_axis_tdata         : in  std_logic_vector( 7 downto 0);
    s_axis_tvalid        : in  std_logic;
    s_axis_tready        : out std_logic;
    s_axis_tlast         : in  std_logic;

    -- Rx
    m_axis_tdata         : out std_logic_vector( 7 downto 0);
    m_axis_tvalid        : out std_logic;
    m_axis_tready        : in  std_logic;
    m_axis_tlast         : out std_logic;

    -----------------------------------
    -- Control & Stats
    -----------------------------------
    -- Control
    trigger              : in  std_logic;

    -- Stats
    num_bytes            : out std_logic_vector(31 downto 0);
    busy                 : out std_logic
    );
end spi_master;

architecture rtl of spi_master is

  -----------------------------------------------------------------------------
  -- Types and constants
  -----------------------------------------------------------------------------
  -- State Machine
  type STATE_T is (RESET_STATE, IDLE_STATE, TRIG_STATE, TX_STATE,
                   FINISHED_STATE);

  -----------------------------------------------------------------------------
  -- Signals
  -----------------------------------------------------------------------------
  signal curr_state_r       : STATE_T := IDLE_STATE;
  signal next_state_s       : STATE_T;

  signal total_byte_count_r : unsigned(31 downto 0)         := (others => '0');
  signal curr_byte_count_r  : unsigned(31 downto 0)         := (others => '0');
  signal bit_count_r        : unsigned( 2 downto 0)         := (others => '0');
  signal last_byte_r        : std_logic                     := '0';
  signal busy_r             : std_logic                     := '0';
  signal miso_byte_r        : std_logic_vector (7 downto 0) := (others => '0');
  signal mosi_byte_r        : std_logic_vector (17 downto 0) := (others => '0');
  signal mosi_byte_r_1      : std_logic_vector (17 downto 0) := (others => '0');
  signal first_bit_r        : std_logic                     := '1';
  signal cs_r               : std_logic                     := '1';

  signal s_axis_tvalid_r    : std_logic                     := '0';

  signal test_mosi_s        : std_logic;
  signal sclk_en_s          : std_logic;

  signal rst_s              : std_logic;

  signal clk_s              : std_logic;
  -- signal d1_s               : std_logic_vector(8 downto 0);
  -- signal d2_s               : std_logic_vector(8 downto 0);
  signal d1_s               : std_logic;
  signal d2_s               : std_logic;


begin

  num_bytes <= std_logic_vector(total_byte_count_r);
  busy      <= busy_r;
  cs        <= cs_r;
  rst_s     <= '1' when rst_in = RST_LEVEL_G else '0'; -- active high reset
  sclk_en_s <= not CLOCK_POLARITY_G when curr_state_r = TX_STATE else CLOCK_POLARITY_G;

  clk_s <= clk_in          when CLOCK_PHASE_G = '0' else not clk_in;
  d1_s  <= mosi_byte_r(16) when CLOCK_PHASE_G = '0' else mosi_byte_r(17);
  d2_s  <= mosi_byte_r(15) when CLOCK_PHASE_G = '0' else mosi_byte_r(16);


  -----------------------------------------------------------------------------
  -- Two process state machine
  -----------------------------------------------------------------------------
  -- Move to the next state
  advance_state: process(clk_in, rst_in)
  begin
    -- Asynchronous reset
    if(rst_in = RST_LEVEL_G) then
      -- Set current and next state to reset
      curr_state_r <= RESET_STATE;

    elsif rising_edge(clk_in) then
      -- Advance to next state
      curr_state_r <= next_state_s;

    end if;
  end process;


  -- Determine the next state
  determine_state: process(curr_state_r, trigger, bit_count_r, last_byte_r, s_axis_tvalid_r)
  begin
    case curr_state_r is
      when RESET_STATE =>
        -- Move to the idle state
        next_state_s <= IDLE_STATE;


      when IDLE_STATE =>
        -- If triggered
        if trigger = '1' then
          -- Move to tx state
          next_state_s <= TRIG_STATE;

        else
          -- Stay in the current state
          next_state_s <= IDLE_STATE;

        end if;


      when TRIG_STATE =>
        if s_axis_tvalid_r = '1' then
          -- Stay here for a single cycle
          next_state_s <= TX_STATE;

        else
          -- Stay here for a single cycle
          next_state_s <= TRIG_STATE;

        end if;


      when TX_STATE =>
        -- If byte counter hit max
        if(bit_count_r = x"7" and last_byte_r = '1') then
          -- Move to rx state
          next_state_s <= FINISHED_STATE;

        else
          -- Stay in the current state
          next_state_s <= TX_STATE;

        end if;


      when FINISHED_STATE =>
        next_state_s <= IDLE_STATE;

    end case;
  end process;


  -- Handle busy device flag
  dev_busy: process(curr_state_r)
  begin
    if curr_state_r = RESET_STATE or curr_state_r = IDLE_STATE then
      busy_r <= '1';
    else
      busy_r <= '0';
    end if;
  end process;


  -----------------------------------------------------------------------------
  -- Counter process
  --
  -- This process is responsible for managing all the counters in this
  -- component.
  --
  -- Current message bytes - Counting the number of bytes associated with the
  -- current message being transmitted/received on the SPI bus.
  --
  -- Bits - Counting the number of bits transmitted during the current message.
  -----------------------------------------------------------------------------
  counters: process(clk_in, rst_in)
  begin
    -- Async reset
    if rst_in = RST_LEVEL_G then
      total_byte_count_r <= (others => '0');
      curr_byte_count_r  <= (others => '0');
      bit_count_r        <= (others => '0');

    -- If positive edge of the clk
    elsif rising_edge(clk_in) then
      -- Byte counters
      if curr_state_r = RESET_STATE or curr_state_r = IDLE_STATE or curr_state_r = TRIG_STATE then
        -- Reset the counter
        curr_byte_count_r <= (others => '0');


      elsif curr_state_r = TX_STATE and bit_count_r = 7 then
        -- Increment the counter
        curr_byte_count_r  <= curr_byte_count_r + 1;
        total_byte_count_r <= total_byte_count_r + 1;

      end if;


      -- Bit counter
      if curr_state_r = TX_STATE  then
        -- Only 3 bits so it automatically rolls over at 8 bits to zero
        bit_count_r <= bit_count_r + 1;

      else
        bit_count_r <= (others => '0');

      end if;
    end if;
  end process;


  -----------------------------------------------------------------------------
  -- SPI data input process
  --
  -- This process is responsible for reading the MISO port and storing the data
  -- in the MISO byte buffer.
  -----------------------------------------------------------------------------
  read_bits : process(clk_in)
  begin
    -- Trigger check on rising edge of clk
    if rising_edge(clk_in) then
      -- If in receiving state
      if curr_state_r = TX_STATE then
        -- Assign next input bit to miso_byte_r
        miso_byte_r <= miso_byte_r (6 downto 0) & miso;

      end if;
    end if;
  end process;


  -----------------------------------------------------------------------------
  -- SPI chip select process
  --
  -- This process is responsible for controlling the register value used to
  -- output the chip select port value.
  -----------------------------------------------------------------------------
  cs_proc: process(clk_in)
  begin
    if rising_edge(clk_in) then
      case curr_state_r is
        when TRIG_STATE =>
          cs_r <= '0';

        when TX_STATE =>
          cs_r <= '0';

        when FINISHED_STATE =>
          cs_r <= '0';

        when others =>
          cs_r <= '1';
      end case;
    end if;
  end process;


  -----------------------------------------------------------------------------
  -- AXIS slave process
  --
  -- This process is responsible for handling the AXIS slave interface signals.
  -----------------------------------------------------------------------------
  s_axis: process(clk_in, rst_in)
  begin
    if rst_in = RST_LEVEL_G then
      s_axis_tready   <= '0';
      s_axis_tvalid_r <= '0';

    elsif rising_edge(clk_in) then
      s_axis_tvalid_r <= s_axis_tvalid;

      case curr_state_r is
        when RESET_STATE =>
          s_axis_tready <= '0';
          last_byte_r   <= '0';
          mosi_byte_r   <= (others => '0');

        when IDLE_STATE =>
          s_axis_tready <= '0';
          last_byte_r   <= '0';
          mosi_byte_r   <= (others => '0');

        when TRIG_STATE =>
          if s_axis_tvalid_r = '1' then
            s_axis_tready <= '1';

          else
            s_axis_tready <= '0';

          end if;

          last_byte_r   <= s_axis_tlast;
          -- mosi_byte_r(7 downto 0)   <= s_axis_tdata;
          mosi_byte_r(16 downto 9)   <= s_axis_tdata;

        when TX_STATE =>
          -- If not the last byte, get the next byte
          if(bit_count_r = to_unsigned(7, bit_count_r'length)
             and last_byte_r = '0') then
            s_axis_tready <= '1';
            last_byte_r   <= s_axis_tlast;
            -- mosi_byte_r(7 downto 0)   <= s_axis_tdata;

            mosi_byte_r(16 downto 9)   <= s_axis_tdata;
            -- mosi_byte_r(15 downto 8)   <= s_axis_tdata;
            -- mosi_byte_r(14 downto 7)   <= s_axis_tdata;

          elsif(bit_count_r = to_unsigned(0, bit_count_r'length)
             and last_byte_r = '0') then
            -- s_axis_tready <= '1';
            s_axis_tready <= '0';
            last_byte_r   <= s_axis_tlast;
            mosi_byte_r(17 downto 0) <= mosi_byte_r(16 downto 0) & "0";

          else
            s_axis_tready <= '0';
            last_byte_r   <= last_byte_r;
            mosi_byte_r(17 downto 0) <= mosi_byte_r(16 downto 0) & "0";

          end if;

        when FINISHED_STATE =>
          s_axis_tready <= '0';
          last_byte_r   <= '0';
          mosi_byte_r   <= (others => '0');

        when others =>
          s_axis_tready <= '0';
          last_byte_r   <= '0';
          mosi_byte_r   <= (others => '0');

      end case;
    end if;
  end process;


  -----------------------------------------------------------------------------
  -- AXIS master process
  --
  -- This process is responsible for handling the AXIS master interface
  -- signals.
  -----------------------------------------------------------------------------
  m_axis: process(clk_in, rst_in)
  begin
    if rst_in = RST_LEVEL_G then
      first_bit_r   <= '1';
      m_axis_tvalid <= '0';
      m_axis_tdata  <= (others => '0');
      m_axis_tlast  <= '0';

    elsif rising_edge(clk_in) then
      case curr_state_r is
        when TX_STATE =>
          if(bit_count_r = to_unsigned(0, bit_count_r'length) and first_bit_r = '0') then
            m_axis_tvalid <= '1';
            m_axis_tdata  <= miso_byte_r;
            m_axis_tlast  <= '0';

          else
            first_bit_r   <= '0';
            m_axis_tvalid <= '0';
            m_axis_tdata  <= (others => '0');
            m_axis_tlast  <= '0';

          end if;

        when FINISHED_STATE =>
            m_axis_tvalid <= '1';
            m_axis_tdata  <= miso_byte_r;
            m_axis_tlast  <= '1';


        when others =>
          first_bit_r   <= '1';
          m_axis_tvalid <= '0';
          m_axis_tdata  <= (others => '0');
          m_axis_tlast  <= '0';

      end case;
    end if;
  end process;


  u_mosi: entity work.oddr
    port map(
      clk => clk_s,
      rst => rst_s,
      d1  => d1_s,
      d2  => d2_s,
      q   => mosi
      );


  u_sclk: entity work.oddr
    port map(
      clk => clk_in,
      rst => rst_s,
      d1  => sclk_en_s,
      d2  => CLOCK_POLARITY_G,
      q   => sclk
      );


end rtl;
