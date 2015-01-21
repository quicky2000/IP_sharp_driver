library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.ALL;

entity driver_sharp is
  port (
    clk : in std_logic;                -- Clock input
    rst : in std_logic;                -- Reset input
    -- Signals to drive the screen
    vsync : out std_logic;
    hsync : out std_logic;
    enable : out std_logic;
    -- Signals to communicate with block giving color
    x_out : out std_logic_vector ( 9 downto 0);
    y_out : out std_logic_vector ( 8 downto 0)
    );
end driver_sharp;

architecture behavorial of driver_sharp is
  -- Constants defined by specification 
  constant THd : positive := 640;     -- Width of display
  constant TVd : positive := 480;     -- Height of display
  constant TH : positive := 799;      -- Horizontal sync signal cycle width in clock cycle
  constant TV : positive := 524;      -- Vertical sync signal period in clock cycle
  constant THp : positive := 95;      -- Horizontal sync signal pulse width in clock cyle
  constant TVp : positive := 1;      -- Vertical sync signal pulse width in hsync cyle
  constant TVs : positive := 34;      -- Vertical start period in clock cycle

  -- Constants for internal use
  -- X axis
  constant x_counter_low : positive :=  1024 - THp ;
  constant x_counter_low_start : positive := x_counter_low+1;
--  constant x_counter_low_start : positive := x_counter_low;
  constant x_counter_valid : positive :=  1024 - THd + 1;
  constant x_counter_fill : positive :=  1024 - (TH - THp - THd) + 1;
  -- Y axis
  constant y_counter_low : positive :=  512 - TVp + 1;
  constant y_counter_low_start : positive :=  y_counter_low;
  constant y_counter_pre_fill : positive :=  512 - (TVs - TVp) + 1;
  constant y_counter_valid : positive :=  512 - TVd + 1;
  constant y_counter_post_fill : positive := 512 - (TV - TVp - TVs - TVd + 1) ;

  -- Internal signals related to X axis
  signal x_counter: std_logic_vector( 10 downto 0) := std_logic_vector(to_unsigned(x_counter_low_start,11));       -- counter for x axis
  signal x_counter_init: std_logic_vector( 10 downto 0) := (others => '0');
  signal hsyncP : std_logic := '0';
  signal enableP : std_logic := '0';
  type x_fsm_state_type is (x_low,x_valid,x_fill);
  signal x_fsm_stateP : x_fsm_state_type := x_low;
  signal x_fsm_stateN : x_fsm_state_type := x_valid;
  signal x : std_logic_vector(9 downto 0) := (others => '0');
  
  -- Internal signals related to Y axis
  signal y_counter: std_logic_vector(9 downto 0) := std_logic_vector(to_unsigned(y_counter_low_start,10));       -- counter for x axis
  signal y_counter_init: std_logic_vector(9 downto 0) := (others => '0');
  signal vsyncP : std_logic := '0';
  type y_fsm_state_type is (y_low,y_pre_fill,y_valid,y_post_fill);
  signal y_fsm_stateP : y_fsm_state_type;
  signal y_fsm_stateN : y_fsm_state_type;
  signal y : std_logic_vector(8 downto 0) := (others => '0');
begin  -- behavorial

  -- Process managing outputs
  output_management : process(clk,rst)
  begin
    if rst = '1' then
      hsync <= '0';
      vsync <= '0';
      enable <= '0';
      x_out <= (others => '0');
      y_out <= (others => '0');
    elsif rising_edge(clk) then
      vsync <= vsyncP;
      hsync <= hsyncP;
      enable <= enableP;
      x_out <= x;
      y_out <= y;
    end if;
  end process;

  -- process managing x_counter increment
  x_counter_increment : process(clk,rst)
  begin
    if rst = '1' then
      x_counter <= std_logic_vector(to_unsigned(x_counter_low_start,11));
    elsif rising_edge(clk) then
      if x_counter(10) = '1' then
        x_counter <= x_counter_init;
      else
        x_counter <= std_logic_vector(unsigned(x_counter)+1);
      end if;
    end if;
  end process;

  -- process computing x_counter_init
  prepare_x_counter_init : process (x_fsm_stateP)
  begin
    case x_fsm_stateP is
      when x_low => x_counter_init <= std_logic_vector(to_unsigned(x_counter_valid,11));
      when x_valid => x_counter_init <= std_logic_vector(to_unsigned(x_counter_fill,11));
      when x_fill => x_counter_init <= std_logic_vector(to_unsigned(x_counter_low,11));
      when others => x_counter_init <= (others => '0');
    end case;
  end process;	

  -- process computing next x_fsm_state
  prepare_next_x_fsm_state : process (x_fsm_stateP)
  begin
    case x_fsm_stateP is
      when x_low => x_fsm_stateN <= x_valid;
      when x_valid => x_fsm_stateN <= x_fill;
      when x_fill => x_fsm_stateN <= x_low;
      when others => x_fsm_stateN <= x_low;
    end case;
  end process;	

  -- process managing x_fsm_state register
  x_fsm_state_register : process(clk,rst)
  begin
    if rst = '1' then
      x_fsm_stateP <= x_low;
    elsif rising_edge(clk) then
      if x_counter(10) = '1' then
        x_fsm_stateP <= x_fsm_stateN;
      else
        x_fsm_stateP <= x_fsm_stateP;
      end if;
    end if;
  end process;

  apply_hsync : hsyncP <= '0' when x_fsm_stateP = x_low else '1';
  
  -- process managing ycounter increment
  ycounter_increment : process(clk,rst)
  begin
    if rst = '1' then
      y_counter <= std_logic_vector(to_unsigned(y_counter_low_start,10));
    elsif rising_edge(clk) then
      if x_counter(10) = '1' and x_fsm_stateP = x_fill then
        if y_counter(9) = '1' then 
          y_counter <= y_counter_init;
        else
          y_counter <= std_logic_vector(unsigned(y_counter) + 1);
        end if;
      else
        y_counter <= y_counter;
      end if;

    end if;
  end process;

  -- prepare the init value for ycounter
  prepare_ycounter_init : process(y_fsm_stateP)
  begin
    case y_fsm_stateP is
      when y_low => y_counter_init <= std_logic_vector(to_unsigned(y_counter_pre_fill,10));
      when y_pre_fill => y_counter_init <= std_logic_vector(to_unsigned(y_counter_valid,10));
      when y_valid => y_counter_init <= std_logic_vector(to_unsigned(y_counter_post_fill,10));
      when y_post_fill => y_counter_init <= std_logic_vector(to_unsigned(y_counter_low,10));
      when others => y_counter_init <= std_logic_vector(to_unsigned(y_counter_low,10));
    end case;
  end process;

  -- process computing next y_fsm_state
  vsync_state_transition_process : process(y_fsm_stateP)
  begin
    case y_fsm_stateP is
      when y_low => y_fsm_stateN <= y_pre_fill;
      when y_pre_fill => y_fsm_stateN <= y_valid;
      when y_valid => y_fsm_stateN <= y_post_fill;
      when y_post_fill => y_fsm_stateN <= y_low;
      when others => y_fsm_stateN <= y_low;
    end case;
  end process;
  
  -- process managing y_fsm_state_register
  y_fsm_state_register : process(clk,rst)
  begin
    if rst = '1' then
      y_fsm_stateP <= y_low;
    elsif rising_edge(clk) then
      if y_counter(9) = '1' and x_counter(10) = '1' and x_fsm_stateP = x_fill then 
        y_fsm_stateP <= y_fsm_stateN;
      else
        y_fsm_stateP <= y_fsm_stateP;
      end if;
    end if;
  end process;
  
--vsync output function
  apply_vsync : vsyncP <= '0' when y_fsm_stateP = y_low else '1';

-- enable output function
  apply_enable : enableP <= '1' when y_fsm_stateP = y_valid and x_fsm_stateP = x_valid else '0';

  --process managing x increment
  x_increment : process(clk,rst)
  begin
    if rst = '1' then
      x <= (others => '0');
    elsif rising_edge(clk) then
      if x_fsm_stateP = x_valid and y_fsm_statep = y_valid then
        if x_counter(10) = '0' then
          x <= std_logic_vector(unsigned(x) + 1);
        else
          x <= (others => '0');
        end if;
      else
        x <= x;
      end if;
    end if;
  end process;
  
  -- process managing y increment
  y_increment : process(clk,rst)
  begin
    if rst = '1' then
      y <= (others => '0');
    elsif rising_edge(clk) then
      if y_fsm_stateP = y_valid  and x_fsm_stateP = x_fill then
        if x_counter(10) = '1'then
          if y_counter(9) = '0' then
            y <= std_logic_vector(unsigned(y) + 1);
          else
            y <= (others => '0');
          end if;
        end if;
      else
        y <= y;
      end if;
    end if;
  end process;
end behavorial;

