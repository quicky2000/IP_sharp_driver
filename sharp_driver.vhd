---
---    This file is part of sharp_driver
---    Copyright (C) 2011  Julien Thevenon ( julien_thevenon at yahoo.fr )
---
---    This program is free software: you can redistribute it and/or modify
---    it under the terms of the GNU General Public License as published by
---    the Free Software Foundation, either version 3 of the License, or
---    (at your option) any later version.
---
---    This program is distributed in the hope that it will be useful,
---    but WITHOUT ANY WARRANTY; without even the implied warranty of
---    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
---    GNU General Public License for more details.
---
---    You should have received a copy of the GNU General Public License
---    along with this program.  If not, see <http://www.gnu.org/licenses/>
---
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.ALL;

entity sharp_driver is
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
end sharp_driver;

architecture behavorial of sharp_driver is
  -- Constants defined by specification 
  constant THd : positive := 640;     -- Width of display
  constant TVd : positive := 480;     -- Height of display
  constant TH : positive := 799;      -- Horizontal sync signal cycle width in clock cycle
  constant TV : positive := 524;      -- Vertical sync signal period in clock cycle
  constant THp : positive := 95;      -- Horizontal sync signal pulse width in clock cyle
  constant TVp : positive := 1;      -- Vertical sync signal pulse width in hsync cyle
  constant TVs : positive := 34;      -- Vertical start period in clock cycle
  -- Internal signals
  signal x_counter : std_logic_vector( 9 downto 0) := (others => '0');       -- counter for x axis
  signal y_counter : std_logic_vector( 9 downto 0) := (others => '0');       -- counter for x axis

  signal x : std_logic_vector( 9 downto 0) := (others => '0');
  signal y : std_logic_vector( 8 downto 0) := (others => '0');
  -- FSM for hsync
  type hsync_state_type is (low,high);
  signal hsync_state : hsync_state_type := low;
  signal hsync_next_state : hsync_state_type := low ;
  -- FSM for vsync
  type vsync_state_type is (low,high,ready_to_low);
  signal vsync_state : vsync_state_type := low;
  signal vsync_next_state : vsync_state_type := low ;

  signal ycounter_next : std_logic_vector (9 downto 0):= (others => '0');

  -- FSM for enable
  type line_state_type is (virtual,real);                      -- State indicating if we are in non real lines or real lines
  signal line_state : line_state_type := virtual;  -- State of line
  signal line_next_state : line_state_type := virtual;  -- State of line

  type enable_state_type is (active,inactive,done);
  signal enable_state : enable_state_type := inactive;
  signal enable_next_state : enable_state_type := inactive;

  -- FSM for y
  type y_state_type is (active,inactive,done,ready,ready_to_reset);
  signal y_state : y_state_type := inactive;
  signal y_next_state : y_state_type := inactive;
  
begin  -- behavorial

  x_counter_process: process(clk,rst)
  begin
    if rising_edge(clk) then 
      if rst = '1' or unsigned(x_counter) = TH then
        x_counter <= (others => '0');
      else
        x_counter <= std_logic_vector(unsigned(x_counter) + 1);
      end if;
    end if;
  end process;

  
  -- ycounter state register process
  ycounter_state_register_process : process(clk,rst)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        y_counter <= (others => '0');
      elsif unsigned(x_counter) = TH then
        y_counter <= ycounter_next;
      else
        y_counter <= y_counter;
      end if;
    end if;
  end process;

  --ycounter state transition
  y_counter_state_transition_process : process(y_counter)
  begin
    if unsigned(y_counter) = TV then 
      ycounter_next <= (others => '0');
    else
      ycounter_next <= std_logic_vector(unsigned(y_counter) + 1);
    end if;
  end process;

  --hsync state register
  hsync_state_register_process : process(clk,rst)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        hsync_state <= low;
      else
        hsync_state <= hsync_next_state;
      end if;
    end if;
  end process;
  
  --hsync state transition
  hsync_state_transition_process : process(hsync_state,x_counter)
  begin
    case hsync_state is
      when low => if unsigned(x_counter) = THp then
                    hsync_next_state <= high;
                  else
                    hsync_next_state <= low ;
                  end if;
      when high => if unsigned(x_counter) = TH then
                     hsync_next_state <= low;
                   else
                     hsync_next_state <= high;
                   end if;
      when others => hsync_next_state <= low ;
    end case;
  end process;
  
  --hsync output function
  hsync <= '1' when hsync_state = high else '0';
  
  --vsync state register
  vsync_state_register_process : process(clk,rst)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        vsync_state <= low;
      else
        vsync_state <= vsync_next_state;
      end if;
    end if;
  end process;
  
  --vsync state transition
  vsync_state_transition_process : process(vsync_state,y_counter,x_counter)
  begin
    case vsync_state is
      when low => if unsigned(y_counter) = TVp then
                    vsync_next_state <= high;
                  else
                    vsync_next_state <= low ;
                  end if;
      when high => if unsigned(y_counter) = TV then
                     vsync_next_state <= ready_to_low;
                   else
                     vsync_next_state <= high;
                   end if;
      when ready_to_low => if unsigned(x_counter) = TH then
                             vsync_next_state <= low;
                           else
                             vsync_next_state <= ready_to_low;
                           end if;
      when others => vsync_next_state <= low ;
    end case;
  end process;
  
  --vsync output function
  vsync <= '0' when vsync_state = low else '1';

  -- Process managing line state 
  line_state_register_process: process(clk,rst)
  begin
    if rising_edge(clk) then 
      if rst = '1' then
        line_state <= virtual;
      else
        line_state <= line_next_state;
      end if;
    end if;
  end process;

  --line_state transition
  line_state_transition_process : process(line_state,y_counter)
  begin
    case line_state is
      when virtual => if unsigned(y_counter) = TVs then
                        line_next_state <= real;
                      else
                        line_next_state <= virtual ;
                      end if;
      when real => if unsigned(y_counter) = (TVd + TVs) then
                     line_next_state <= virtual;
                   else
                     line_next_state <= real;
                   end if;
      when others => line_next_state <= virtual;
    end case;
  end process;
  
  -- enable process management
  enable_state_register_process: process(clk,rst)
  begin
    if rising_edge(clk) then 
      if rst = '1' then
        enable_state <= inactive;
      else
        enable_state <= enable_next_state;
      end if;
    end if;
  end process;

  --enable_state transition
  enable_state_transition_process : process(enable_state,hsync_next_state,x,line_state)
  begin
    case enable_state is
      when inactive => if hsync_next_state = high and line_state = real then
                         enable_next_state <= active;
                       else
                         enable_next_state <= inactive ;
                       end if;
      when active => if unsigned(x) = (THd -1) then
                       enable_next_state <= done;
                     else
                       enable_next_state <= active;
                     end if;
      when done => if hsync_next_state = low then
                     enable_next_state <= inactive;
                   else
                     enable_next_state <= done;
                   end if;
      when others => enable_next_state <= inactive;
    end case;
  end process;

  enable <= '1' when enable_state = active else '0';

  x_out_process : process(clk,rst)
  begin
    if rising_edge(clk) then
      if rst = '1' or unsigned(x) = (THd -1) then
        x <= (others => '0');
      elsif enable_state = active then
        x <= std_logic_vector(unsigned(x) + 1);
      else
        x <= x;
      end if;
    end if;
  end process;

  y_out_process : process(clk,rst)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        y_state <= inactive;
      else
        y_state <= y_next_state;
      end if;
    end if;
  end process;

  --y state transition
  process(y_state,y_counter,hsync_state,hsync_next_state,vsync_state)
  begin
    case y_state is
      when inactive => if unsigned(y_counter) = TVs then
                         y_next_state <= ready;
                       else
                         y_next_state <= inactive ;
                       end if;
      when active => if hsync_state = low then
                       y_next_state <= done;
                       y <= std_logic_vector(unsigned(y) + 1);
                     else
                       y <= y;
                       y_next_state <= active;
                     end if;
      when done => if unsigned(y) = (TVd - 1) then
                     y_next_state <= ready_to_reset;
                   else
                     y_next_state <= ready;
                     y <= y;
                   end if;
      when ready_to_reset => if vsync_state = low then
                               y_next_state <= inactive;
                               y <= (others => '0');
                             else
                               y_next_state <= ready_to_reset;
                               y <= y;
                             end if;
      when ready => if  hsync_next_state = high then
                      y_next_state <= active;
                    else
                      y_next_state <= ready;
                    end if;
      when others => y_next_state <= inactive ;
    end case;
  end process;
  
  x_out <= x;
  y_out <= y;
end behavorial;

