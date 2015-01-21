--
--    This file is part of sharp_driver
--    Copyright (C) 2011  Julien Thevenon ( julien_thevenon at yahoo.fr )
--
--    This program is free software: you can redistribute it and/or modify
--    it under the terms of the GNU General Public License as published by
--    the Free Software Foundation, either version 3 of the License, or
--    (at your option) any later version.
--
--    This program is distributed in the hope that it will be useful,
--    but WITHOUT ANY WARRANTY; without even the implied warranty of
--    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--    GNU General Public License for more details.
--
--    You should have received a copy of the GNU General Public License
--    along with this program.  If not, see <http://www.gnu.org/licenses/>
--
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
  constant THd : positive := 640;     -- Width of display
  constant TVd : positive := 480;     -- Height of display
  constant TH : positive := 800;      -- Horizontal sync signal cycle width in clock cycle
  constant THp : positive := 96;      -- Horizontal sync signal pulse width in clock cyle
  constant TVs : positive := 34;      -- Vertical start period in clock cycle
  constant TV : positive := 525;      -- Vertical sync signal period in clock cycle
begin  -- behavorial

  process(clk,rst)
    variable x_counter : positive range 1 to TH := 1;       -- counter for x axis
    variable y_counter : positive range 1 to TV := 1;       -- counter for y axis
    variable x : natural range 0 to THd := 0;         -- x coordinate of active pixel
    variable y : natural range 0 to TVd := 0;         -- x coordinate of active pixel
  begin
    if rst = '1' then
      x_counter := 1;
      y_counter := 1;
      vsync <= '0';
      hsync <= '0';
      enable <= '0';
      x_out <= (others => '0');
      y_out <= (others => '0');
      x := 0;
      y := 0;
    elsif rising_edge(clk) then 
      if y_counter < 2 then
        vsync <= '0';
      else
        vsync <= '1';
      end if;
      if x_counter < TH then        
        x_counter := x_counter + 1;
      else
        x_counter := 1;
        if y_counter <  TV then
          y_counter := y_counter + 1;
        else
          y_counter := 1;
          y := 0;
          y_out <= (others => '0');
        end if;
        if y_counter > TVs and y < TVd then 
          y_out <= std_logic_vector(to_unsigned(y,9));
          y := y +1;
        end if;
      end if;

      if x_counter <= THp then
        hsync <= '0';
        x := 0;
        x_out <= (others => '0');
      else
        hsync <= '1';
        if x < THd and y_counter > TVs and y_counter <= TVd + TVs then
          x_out <= std_logic_vector(to_unsigned(x,10));
          x := x + 1;
          enable <= '1';
        else
          enable <= '0';
          x_out <= (others => '0');
        end if;
      end if;
    end if;
  end process;

end behavorial;

