----
----    This file is part of sharp_driver
----    Copyright (C) 2011  Julien Thevenon ( julien_thevenon at yahoo.fr )
----
----    This program is free software: you can redistribute it and/or modify
----    it under the terms of the GNU General Public License as published by
----    the Free Software Foundation, either version 3 of the License, or
----    (at your option) any later version.
----
----    This program is distributed in the hope that it will be useful,
----    but WITHOUT ANY WARRANTY; without even the implied warranty of
----    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
----    GNU General Public License for more details.
----
----    You should have received a copy of the GNU General Public License
----    along with this program.  If not, see <http://www.gnu.org/licenses/>
----
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
  constant x_counter_low : positive :=  1024 - THp ;
  constant x_counter_low_start : positive := x_counter_low + 1;
  constant x_counter_high : positive :=  1024 - (TH - THp) + 1;
  constant y_counter_low : positive :=  1024 - TVp;
  constant y_counter_high : positive :=  1024 - (TV - TVp) + 1;
  -- Internal signals 
  signal x_counter: std_logic_vector( 10 downto 0) := std_logic_vector(to_unsigned(x_counter_low_start,11));       -- counter for x axis
  signal x_counter_init: std_logic_vector( 10 downto 0) := std_logic_vector(to_unsigned(x_counter_high,11));       -- counter for x axis
  signal hsyncP : std_logic := '0';
  signal hsyncN : std_logic := '1';
  
  signal y_counterP: std_logic_vector( 10 downto 0) := std_logic_vector(to_unsigned(y_counter_low,11));       -- counter for x axis
  signal y_counter_init: std_logic_vector( 10 downto 0) := std_logic_vector(to_unsigned(y_counter_high,11));       -- counter for x axis

  -- FSM for vsync
  type vsync_state_type is (low,after_low,high,ready_to_low,before_low);
  signal vsyncP : vsync_state_type := low;
  signal vsyncN : vsync_state_type := low ;

  -- counter to determine if line is active or not
  constant line_counter_low_start : positive :=  512 - TVs;
  constant line_counter_low : positive :=  512 - (TV - TVd);
  constant line_counter_high : positive :=  512 - TVd + 1;
  signal line_counter : std_logic_vector(9 downto 0) := std_logic_vector(to_unsigned(line_counter_low_start,10));
  signal line_counter_init : std_logic_vector(9 downto 0) := std_logic_vector(to_unsigned(line_counter_low_start,10));
  type line_state_type is(virtual,first_real,real,after_real);
  signal line_stateP : line_state_type := virtual;
  signal line_stateN : line_state_type := virtual;
begin  -- behavorial

  -- Process managing outputs
  output_management : process(clk,rst)
  begin
    if rst = '1' then
--			vsync <= '0';
      hsync <= '0';
      enable <= '0';
      x_out <= (others => '0');
      y_out <= (others => '0');
    elsif rising_edge(clk) then
--			vsync <= vsyncP;
      hsync <= hsyncP;
--			enable <= enableP;
--			x_out <= x_outP;
--			y_out <= x_outP;
    end if;
  end process;

  -- process managing xcounter increment
  xcounter_increment : process(clk,rst)
  begin
    if rst = '1' then
      x_counter <= std_logic_vector(to_unsigned(x_counter_low_start,11));
      hsyncP <= '0';
    elsif rising_edge(clk) then
      if x_counter(10) = '1' then
        x_counter <= x_counter_init;
        hsyncP <= hsyncN;
      else
        x_counter <= std_logic_vector(unsigned(x_counter)+1);
      end if;
    end if;
  end process;

  -- process preparing next hsync_value
  prepare_next_hsync : process(hsyncP)
  begin
    case hsyncP is
      when '0' => hsyncN <= '1';
      when '1' => hsyncN <= '0';
      when others => hsyncN <= '0';
    end case;
  end process;

  -- process computing next x_counter_init
  prepare_next_counter_init : process (hsyncP)
  begin
    case hsyncP is
      when '0' => x_counter_init <= std_logic_vector(to_unsigned(x_counter_high,11));
      when '1' => x_counter_init <= std_logic_vector(to_unsigned(x_counter_low,11));
      when others => x_counter_init <= std_logic_vector(to_unsigned(x_counter_high,11));
    end case;
  end process;	

  -- process managing ycounter increment
  ycounter_increment : process(clk,rst)
  begin
    if rst = '1' then
      y_counterP <= std_logic_vector(to_unsigned(y_counter_low,11));
    elsif rising_edge(clk) then
      if x_counter(10) = '1' and hsyncP = '1' then
        if y_counterP(10) = '1' then 
          y_counterP <= y_counter_init;
        else
          y_counterP <= std_logic_vector(unsigned(y_counterP) + 1);
        end if;
      else
        y_counterP <= y_counterP;
      end if;
    end if;
  end process;

  -- prepare the init value for ycounter
  prepare_ycounter_init : process(vsyncP)
  begin
    case vsyncP is
      when low => y_counter_init <= std_logic_vector(to_unsigned(y_counter_high,11));
      when after_low => y_counter_init <= std_logic_vector(to_unsigned(y_counter_high,11));
      when high => y_counter_init <= std_logic_vector(to_unsigned(y_counter_low,11));
      when ready_to_low => y_counter_init <= std_logic_vector(to_unsigned(y_counter_low,11));
      when others => y_counter_init <= std_logic_vector(to_unsigned(y_counter_high,11));
    end case;
  end process;

  --vsync state register
  vsync_state_register_process : process(clk,rst)
  begin
    if rst = '1' then
      vsyncP <= low;
    elsif rising_edge(clk) then
      vsyncP <= vsyncN;
    end if;
  end process;
  
  --vsync state transition
  vsync_state_transition_process : process(vsyncP,hsyncP,y_counterP,x_counter)
  begin
    case vsyncP is
      when low => if y_counterP(10) = '1' then
                    vsyncN <= after_low;
                  else
                    vsyncN <= low ;
                  end if;
      when after_low => if y_counterP(10) = '1' then
                          vsyncN <= after_low;
                        else
                          vsyncN <= high ;
                        end if;
      when high => if y_counterP(10) = '1' and vsyncP = high then
                     vsyncN <= ready_to_low;
                   else
                     vsyncN <= high;
                   end if;
      when ready_to_low => if x_counter(10) = '1' and hsyncP = '1' then
                             vsyncN <= before_low;
                           else
                             vsyncN <= ready_to_low;
                           end if;
      when before_low => vsyncN <= low;
      when others => vsyncN <= low ;
    end case;
  end process;
  
  --vsync output function
  apply_vsync : vsync <= '0' when vsyncP = low else '1';

  -- Process managing line state 
  line_state_register: process(clk,rst)
  begin
    if rst = '1' then
      line_stateP <= virtual;
    elsif rising_edge(clk) then
      line_stateP <= line_stateN;
    end if;
  end process;

  --line_state transition
  line_state_transition : process(line_stateP,line_counter(9))
  begin
    case line_stateP is
      when virtual => if line_counter(9) = '1' then
                        line_stateN <= first_real ;
                      else
                        line_stateN <= virtual;
                      end if;
      when first_real => if line_counter(9) = '0' then
                           line_stateN <= real;
                         else
                           line_stateN <= first_real;
                         end if;
      when real => if line_counter(9) = '1' then
                     line_stateN <= after_real;
                   else
                     line_stateN <= real;
                   end if;
      when after_real => if line_counter(9) = '0' then
                           line_stateN <= virtual;
                         else
                           line_stateN <= after_real;
                         end if;
      when others => line_stateN <= virtual;
    end case;
  end process;
  
  -- line counter increment
  line_couter_increment : process(clk,rst)
  begin
    if rst = '1' then
      line_counter <= std_logic_vector(to_unsigned(line_counter_low_start,10));
    elsif rising_edge(clk) then
      if x_counter(10) = '1' and hsyncP = '1' then
        if line_counter(9) = '1' then 
          line_counter <= line_counter_init;
        else
          line_counter <= std_logic_vector(unsigned(line_counter) + 1);
        end if;
      end if;
    end if;
  end process;

  prepare_line_counter_init : process(line_stateP)
  begin
    case line_stateP is
      when virtual => line_counter_init <= std_logic_vector(to_unsigned(line_counter_high,10));
      when first_real => line_counter_init <= std_logic_vector(to_unsigned(line_counter_high,10));
      when real => line_counter_init <= std_logic_vector(to_unsigned(line_counter_low,10));
      when after_real => line_counter_init <= std_logic_vector(to_unsigned(line_counter_low,10));
      when others => line_counter_init <= std_logic_vector(to_unsigned(line_counter_high,10));
    end case;
  end process;
end behavorial;

