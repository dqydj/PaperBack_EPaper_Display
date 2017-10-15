library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.ALL;

entity FrameGrabber is
	port( 	
			-- Memory
			ADDR: 				out std_logic_vector(18 downto 0);
			IO: 				inout std_logic_vector(7 downto 0);
			MEM_OE: 			out std_logic := '1'; -- Active low 
			MEM_WE:				out std_logic := '1'; -- Active low
			MEM_CE: 			out std_logic := '1';  -- Active low
			
			-- VGA
			HSYNC: 				in std_logic;
			VSYNC: 				in std_logic;
			DCLK: 				in std_logic;
			--RED: 				in std_logic_vector(7 downto 4);
			GREEN: 				in std_logic_vector(7 downto 4);
			--BLUE: 			in std_logic_vector(7 downto 4);
			
			-- Control State
			FRAME_GRAB_DONE: 	out std_logic;
			FRAME_WRITE_DONE: 	in std_logic
	);
end FrameGrabber;

architecture Behavioral of FrameGrabber is
	-- Screen Constants
	constant SCREEN_WIDTH : integer := 800;
	constant SCREEN_HEIGHT : integer := 600;
	constant SCREEN_OVERSCAN : integer := (800*600)+10000;
	constant SCREEN_OVERSCAN_FLAG : integer  := SCREEN_OVERSCAN-100;
	
	-- Left columns to ignore
	constant FRONT_PORCH : integer := 206;
	
	-- Rows to Ignore
	constant ROW_PORCH : integer := 26;
	
	-- State Frame Grab
	signal READY_GRAB: std_logic := '0';
	signal CHECK_WRITE_DONE: std_logic := '0';
	signal pixel_reset_clk: unsigned(0 to 1) := (others => '0');
	signal pixel_count: unsigned(27 downto 0) := (others => '0');
	signal VGA_COL : unsigned(10 downto 0) := (others => '0');
	signal VGA_ROW : unsigned(10 downto 0) := (others => '0');	
	
	-- PIXEL caches
	signal SEEN_VSYNC: std_logic := '0';
	signal PIXEL_00: std_logic_vector(3 downto 0) := (others => '0');
	signal PIXEL_01: std_logic_vector(3 downto 0) := (others => '0');
	signal PIXEL_02: std_logic_vector(3 downto 0) := (others => '0');
	signal PIXEL_03: std_logic_vector(3 downto 0) := (others => '0');
	signal PIXEL_04: std_logic_vector(3 downto 0) := (others => '0');
	signal PIXEL_05: std_logic_vector(3 downto 0) := (others => '0');
	signal PIXEL_06: std_logic_vector(3 downto 0) := (others => '0');
	signal PIXEL_07: std_logic_vector(3 downto 0) := (others => '0');
	
	-- Return decoded EPD Pixels
	function epdPix (
		PIXEL : in std_logic_vector(3 downto 0);
		ADDRESS : in unsigned(1 downto 0)
	) return STD_LOGIC_VECTOR IS
		variable decodedPixel : STD_LOGIC_VECTOR(1 downto 0);
	begin

		if (ADDRESS = "00") then
			if (PIXEL(3) = '1') then
				decodedPixel := "10";
			else
				decodedPixel := "01";
			end if;
		elsif (ADDRESS = "01") then
			if (PIXEL(2) = '1') then
				decodedPixel := "10";
			else
				decodedPixel := "01";
			end if;
		elsif (ADDRESS = "10") then
			if (PIXEL(1) = '1') then
				decodedPixel := "10";
			else
				decodedPixel := "01";
			end if;
		elsif (ADDRESS = "11") then
			if (PIXEL(0) = '1') then
				decodedPixel := "00";
			else
				decodedPixel := "01";
			end if;
		end if;
					
		return decodedPixel;
	end epdPix;
	
	begin
	
	-- Control clocking video into the SRAM
	MEM_WE <= DCLK when 
	(	
		READY_GRAB = '1' and 
		pixel_count < SCREEN_OVERSCAN and 
		HSYNC = '0' and 
		VGA_COL >= to_unsigned(FRONT_PORCH, VGA_COL'length) and 
		VGA_COL < to_unsigned(SCREEN_WIDTH + FRONT_PORCH, VGA_COL'length) and
		VGA_ROW >= ROW_PORCH
	) else '1';
	
	-- Pixel Clock
	process(DCLK, HSYNC)
	begin
		if(rising_edge(HSYNC)) then
			if (VSYNC = '0') then
				VGA_ROW <= to_unsigned(0, VGA_ROW'length);
			else
				VGA_ROW <= VGA_ROW + 1;
			end if;
		end if;
	
		if(rising_edge(DCLK)) then -- Rising pixel clock
			if (pixel_reset_clk /= "11") then
				pixel_reset_clk <= pixel_reset_clk + 1;
			end if;
			
			if (pixel_reset_clk = "01") then
				FRAME_GRAB_DONE <= '0';
				READY_GRAB <= '1';
				CHECK_WRITE_DONE <= '1';
				pixel_count <= (others => '0');
				SEEN_VSYNC <= '0';
				MEM_CE <= '1';
				MEM_OE <= '1';
				ADDR <= (others => 'Z');
				IO <= (others => 'Z');
			end if;
			
			if (READY_GRAB = '0') then -- Check for state with synchronizing flip flop
				READY_GRAB <= CHECK_WRITE_DONE;
				CHECK_WRITE_DONE <= FRAME_WRITE_DONE;
			else -- if READY_GRAB is '1' or it's time to grab a frame
				if (VSYNC = '0') then
					SEEN_VSYNC <= '1';
					VGA_COL <= (others => '0');
					VGA_ROW <= (others => '0');
				else
					SEEN_VSYNC <= SEEN_VSYNC;
				end if;
				
				if (VSYNC = '1' and SEEN_VSYNC = '1') then
					if (pixel_count = to_unsigned(0, pixel_count'length)) then
						FRAME_GRAB_DONE <= '0';
						READY_GRAB <= '1';
						MEM_CE <= '0';
						MEM_OE <= '1';
					end if;
				
					if (pixel_count = to_unsigned(SCREEN_OVERSCAN_FLAG, pixel_count'length)) then 
						FRAME_GRAB_DONE <= '1';
						MEM_CE <= '1';
						MEM_OE <= '1';
					end if;
					
					-- PIXEL LOGIC
					if (pixel_count /= to_unsigned(SCREEN_OVERSCAN, pixel_count'length)) then
						if (
							HSYNC = '0' and 
							VGA_COL >= to_unsigned(FRONT_PORCH, VGA_COL'length) and 
							VGA_COL < to_unsigned(SCREEN_WIDTH + FRONT_PORCH, VGA_COL'length) and
							VGA_ROW >= ROW_PORCH
						) then
							case pixel_count(2 downto 0) is
								when "000" 		=> PIXEL_00 <= GREEN(7 downto 4);
								when "001" 		=> PIXEL_01 <= GREEN(7 downto 4);
								when "010" 		=> PIXEL_02 <= GREEN(7 downto 4);
								when "011" 		=> PIXEL_03 <= GREEN(7 downto 4);
								when "100" 		=> PIXEL_04 <= GREEN(7 downto 4);
								when "101" 		=> PIXEL_05 <= GREEN(7 downto 4);
								when "110" 		=> PIXEL_06 <= GREEN(7 downto 4);
								when others 	=> PIXEL_07 <= GREEN(7 downto 4);
							end case;
						
							if (pixel_count > to_unsigned(3, pixel_count'length)) then
								ADDR <= std_logic_vector(pixel_count(18 downto 0) - 4);
								case pixel_count(2) is
									when '0' 		=> 	IO 		<=  epdPix(PIXEL_04, pixel_count(1 downto 0)) &
																	epdPix(PIXEL_05, pixel_count(1 downto 0)) &
																	epdPix(PIXEL_06, pixel_count(1 downto 0)) &
																	epdPix(PIXEL_07, pixel_count(1 downto 0));
									when others 	=> 	IO 		<=  epdPix(PIXEL_00, pixel_count(1 downto 0)) &
																	epdPix(PIXEL_01, pixel_count(1 downto 0)) &
																	epdPix(PIXEL_02, pixel_count(1 downto 0)) &
																	epdPix(PIXEL_03, pixel_count(1 downto 0));
								end case;
							else
								IO <= "00000000";
								ADDR <= (others => '1');
							end if;
						
							pixel_count <= pixel_count + 1;
							MEM_CE <= '0';
						end if;
					end if;
					
					-- HSYNC Row Rollover / Reset columns, new row
					if (HSYNC = '0') then
						VGA_COL <= VGA_COL + 1;
					else
						VGA_COL <= (others => '0');
					end if;
					
					-- Rollover Logic
					if (pixel_count = to_unsigned(SCREEN_OVERSCAN, pixel_count'length)) then 
						pixel_count <= to_unsigned(0, pixel_count'length);
						READY_GRAB <= '0';
						CHECK_WRITE_DONE <= '0';
						FRAME_GRAB_DONE <= '0';
						ADDR <= (others => 'Z');
						IO <= (others => 'Z');
						MEM_CE <= '1';
						SEEN_VSYNC <= '0';
						VGA_COL <= (others => '0');
						VGA_ROW <= (others => '0');
						-- Just grabbed a frame from VGA - go write it to the EPD
					end if;
				end if;
				
			end if; -- Ready to Grab was 1
		end if; -- end rising clock
	end process; -- End Pixel Clock from AD9883/MST9883
	
end Behavioral;