library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.ALL;

-- License: MIT

entity FrameWriter is
	port(
			-- Input from above
			CLK0: in std_logic;

			-- Power Lines
			NEG_CTRL:	out std_logic := '0';
			POS_CTRL:	out std_logic := '0';
			SMPS_CTRL:	out std_logic := '1'; -- Active low

			-- Control Lines
			CKV:		out std_logic := '1';
			SPV: 		out std_logic := '0';
			GMODE:		out std_logic := '0';
			SPH: 		out std_logic := '0';
			OE: 		out std_logic := '0';

			-- Clocks/Edges
			CL: 		out std_logic := '0';
			LE: 		out std_logic := '0';

			-- Data
			DATA:		out std_logic_vector(7 downto 0);

			-- Memory
			ADDR: 		out std_logic_vector(18 downto 0);
			IO: 		in std_logic_vector(7 downto 0);
			MEM_OE: 	out std_logic := '1'; -- Active low
			MEM_WE:		out std_logic := '1'; -- Active low
			MEM_CE: 	out std_logic := '1'; -- Active low

			-- Control State
			FRAME_GRAB_DONE: 	in std_logic;
			FRAME_WRITE_DONE: 	out std_logic;
			READY_WRITE: 		inout std_logic

	);
end FrameWriter;

architecture Behavioral of FrameWriter is
	-- Screen Constants
	constant SCREEN_WIDTH : integer := 800;
	constant SCREEN_HEIGHT : integer := 600;
	constant SCREEN_OVERSCAN : integer := (800*600)+50000;
	constant SCREEN_OVERSCAN_FLAG : integer  := SCREEN_OVERSCAN-100;

	-- CONTRAST CONSTANTS
	constant CONTRAST_CYCLES : unsigned(0 to 5) := to_unsigned(24, 6);
	constant CONTRAST_START_DARK: integer := 5;
	constant CONTRAST_END_DARK: integer := 11;
	constant CONTRAST_BP_HI: integer:=20;
	constant CONTRAST_BP_MD: integer:=22;
	constant CONTRAST_BP_LO: integer:=23;

	-- Return a full address based on our contrast cycle
	function getAddress (
		ADDR_MSB : in UNSIGNED(16 downto 0);
		CURR_COUNT : in UNSIGNED(5 downto 0)
	) return STD_LOGIC_VECTOR IS
		variable tempAddress : STD_LOGIC_VECTOR(18 downto 0);
	begin

		if (CURR_COUNT <= to_unsigned(CONTRAST_BP_HI, CURR_COUNT'length)) then
			tempAddress := std_logic_vector(ADDR_MSB) & "00";
		elsif  (CURR_COUNT > to_unsigned(CONTRAST_BP_HI, CURR_COUNT'length) and CURR_COUNT <= to_unsigned(CONTRAST_BP_MD, CURR_COUNT'length)) then
			tempAddress := std_logic_vector(ADDR_MSB) & "01";
		elsif  (CURR_COUNT > to_unsigned(CONTRAST_BP_MD, CURR_COUNT'length) and CURR_COUNT <= to_unsigned(CONTRAST_BP_LO, CURR_COUNT'length)) then
			tempAddress := std_logic_vector(ADDR_MSB) & "10";
		else
			tempAddress := std_logic_vector(ADDR_MSB) & "11";
		end if;

		return tempAddress;
	end getAddress;

	-- HARD TIMING CONSTANTS
	constant ROLLOVER_SCREEN: integer:= 96000000; -- Controls refresh rate
	constant SAFE_REFRESH:	integer:= 35000;

	-- CYCLE TIMING
	constant POWERON_SMPS_LO: integer:=1;
	constant POWERON_NEG_HI: integer:=1201;
	constant POWERON_POS_HI: integer:=13201;
	constant POWERON_SPV_SPH_LO: integer:=13441;
	constant OUTER_GMODE_HI: integer:=13451;
	constant OUTER_SPV_HI: integer:=25451;
	constant OUTER_CKV_LO: integer:=25499;
	constant OUTER_CKV_HI: integer:=25547;
	constant OUTER_SPV_LO: integer:=25595;
	constant OUTER_CKV_LO_2: integer:=25643;
	constant OUTER_CKV_HI_2: integer:=25691;
	constant OUTER_SPV_HI_2: integer:=25739;
	constant OUTER_CKV_LO_3: integer:=25787;
	constant OUTER_CKV_HI_3: integer:=25835;
	constant INNER_OE_HI_SPH_LO_MEM_ON: integer:=25859;
	constant PIXEL_GET_MEMORY: integer:=25860;
	constant PIXEL_CL_HI: integer:=25861;
	constant PIXEL_CL_LO: integer:=25862;
	constant INNER_SPH_HI_MEM_OFF: integer:=25910;
	constant INNER_CL_HI: integer:=25958;
	constant INNER_CL_LO: integer:=26006;
	constant INNER_CL_HI_2: integer:=26054;
	constant INNER_CL_LO_2: integer:=26102;
	constant INNER_OE_HI_CKV_HI: integer:=26150;
	constant INNER_CKV_LO: integer:=26198;
	constant INNER_OE_LO: integer:=26246;
	constant INNER_CL_HI_3: integer:=26294;
	constant INNER_CL_LO_3: integer:=26342;
	constant INNER_CL_HI_4: integer:=26390;
	constant INNER_CL_LO_4: integer:=26438;
	constant INNER_CKV_HI: integer:=26486;
	constant INNER_LE_HI: integer:=26534;
	constant INNER_CL_HI_5: integer:=26582;
	constant INNER_CL_LO_5: integer:=26630;
	constant INNER_CL_HI_6: integer:=26678;
	constant INNER_CL_LO_6: integer:=26726;
	constant INNER_LE_LO: integer:=26774;
	constant INNER_CL_HI_7: integer:=26822;
	constant INNER_CL_LO_7: integer:=26870;
	constant INNER_CL_HI_8: integer:=26918;
	constant INNER_CL_LO_8: integer:=26966;
	constant OUTER_OE_HI_SPH_LO: integer:=27014;
	constant PIXEL2_CL_HI: integer:=27016;
	constant PIXEL2_CL_LO: integer:=27018;
	constant OUTER_SPH_HI: integer:=27066;
	constant OUTER_CL_HI: integer:=27114;
	constant OUTER_CL_LO: integer:=27162;
	constant OUTER_CL_HI_2: integer:=27210;
	constant OUTER_CL_LO_2: integer:=27258;
	constant OUTER_OE_HI_CKV_HI: integer:=27306;
	constant OUTER_CKV_LO_4: integer:=27354;
	constant OUTER_OE_LO: integer:=27402;
	constant OUTER_CL_HI_3: integer:=27450;
	constant OUTER_CL_LO_3: integer:=27498;
	constant OUTER_CL_HI_4: integer:=27546;
	constant OUTER_CL_LO_4: integer:=27594;
	constant OUTER_OE_LO_CKV_LO: integer:=27642;
	constant OUTER_CKV_HI_5: integer:=28842;
	constant OUTER_CKV_LO_5: integer:=30042;
	constant OUTER_GMODE_LO: integer:=30090;
	constant POWEROFF_POS_LO: integer:=30138;
	constant POWEROFF_NEG_LO: integer:=30378;
	constant POWEROFF_SMPS_HI: integer:=32778;

	-- LOOP CONSTANTS
	constant START_INNER_LOOP: integer:= OUTER_CKV_HI_3  +1;
	constant END_INNER_LOOP: integer:= INNER_CL_LO_8 +1;

	constant START_PIXEL_LOOP: integer:= INNER_OE_HI_SPH_LO_MEM_ON +1;
	constant END_PIXEL_LOOP: integer:= PIXEL_CL_LO +1;

	constant START_PIXEL2_LOOP: integer:= OUTER_OE_HI_SPH_LO +1;
	constant END_PIXEL2_LOOP: integer:= PIXEL2_CL_LO +1;

	constant START_OUTER_LOOP: integer:= POWERON_SPV_SPH_LO +1;
	constant END_OUTER_LOOP: integer:= OUTER_GMODE_LO +1;

	-- Other Signals
	signal reset_clk: unsigned(0 to 2) := (others => '0');
	signal timer: unsigned(0 to 27) := (others => '0');
	signal cycle: std_logic := '0';

	-- Loop Counters
	signal COLUMN: unsigned(0 to 9) := (others => '0');
	signal ROW: unsigned(0 to 9) := (others => '0');
	signal CONTRAST: unsigned(0 to 5) := (others => '0');
	signal MEM_ADDR: unsigned(16 downto 0) := (others => '0');
	signal FULL_ADDR: unsigned(18 downto 0) := (others => '0');

	-- State Frame Write
	signal CHECK_GRAB_DONE: std_logic := '0';

	begin

	-- Internal FPGA Clock Logic
	process(CLK0)
	begin

		if(rising_edge(CLK0)) then -- Do stuff on clock
		-----------------------------------------------------------------------

			if (reset_clk /= "111") then
				reset_clk <= reset_clk + 1;
			end if;

			if (reset_clk = "001") then
					-- Reset everything to safe
					SMPS_CTRL <= '1';
					NEG_CTRL <= '0';
					POS_CTRL <= '0';
					CKV <= '1';
					SPV <= '0';
					GMODE <= '0';
					SPH <= '0';
					OE <= '0';
					CL <= '0';
					LE <= '0';

					-- Flags
					CHECK_GRAB_DONE <= '0';
					READY_WRITE <= '0';
					FRAME_WRITE_DONE <= '1';

					MEM_ADDR <= to_unsigned(0, MEM_ADDR'length);

			end if;



			if (READY_WRITE = '0') then -- Start screen write
				READY_WRITE <= CHECK_GRAB_DONE;
				CHECK_GRAB_DONE <= FRAME_GRAB_DONE;
			else

				if (timer = to_unsigned(0, timer'length)) then

					-- Reset everything to safe
					SMPS_CTRL <= '1';
					NEG_CTRL <= '0';
					POS_CTRL <= '0';
					CKV <= '1';
					SPV <= '0';
					GMODE <= '0';
					SPH <= '0';
					OE <= '0';
					CL <= '0';
					LE <= '0';

					--DATA <= "00000000";
					MEM_ADDR <= to_unsigned(0, MEM_ADDR'length);
					FRAME_WRITE_DONE <= '0';

					CHECK_GRAB_DONE <= '0';

					MEM_CE <= '1';
					MEM_WE <= '1';
					MEM_OE <= '1';
					ADDR <= (others => 'Z');
				end if;

				-- Start cycle, SMPS On
				if (timer = to_unsigned(POWERON_SMPS_LO, timer'length)) then
					SMPS_CTRL <= '0';
				end if;

				-- NEG Voltage On
				if (timer = to_unsigned(POWERON_NEG_HI, timer'length)) then
					NEG_CTRL <= '1';
				end if;

				-- POS Voltage On
				if (timer = to_unsigned(POWERON_POS_HI, timer'length)) then
					POS_CTRL <= '1';
				end if;


				-- SPV/SPH On
				if (timer = to_unsigned(POWERON_SPV_SPH_LO, timer'length)) then
					SPV <= '1';
					SPH <= '1';
				end if;

				-------------------------------------------------------------------
				-- Outer Loop Start 13442
				-------------------------------------------------------------------

				------------------------------------------------------- VSCAN Start
				if (timer = to_unsigned(OUTER_GMODE_HI, timer'length)) then
					GMODE <= '1';
				end if;

				-- SPV High
				if (timer = to_unsigned(OUTER_SPV_HI, timer'length)) then
					SPV <= '1';
				end if;

				-- CKV Low
				if (timer = to_unsigned(OUTER_CKV_LO, timer'length)) then
					CKV <= '0';
				end if;

				-- CKV Hi
				if (timer = to_unsigned(OUTER_CKV_HI, timer'length)) then
					CKV <= '1';
				end if;

				-- SPV Low
				if (timer = to_unsigned(OUTER_SPV_LO, timer'length)) then
					SPV <= '0';
				end if;

				-- CKV Low
				if (timer = to_unsigned(OUTER_CKV_LO_2, timer'length)) then
					CKV <= '0';
				end if;

				-- CKV Hi
				if (timer = to_unsigned(OUTER_CKV_HI_2, timer'length)) then
					CKV <= '1';
				end if;

				-- SPV High
				if (timer = to_unsigned(OUTER_SPV_HI_2, timer'length)) then
					SPV <= '1';
				end if;

				-- CKV Low
				if (timer = to_unsigned(OUTER_CKV_LO_3, timer'length)) then
					CKV <= '0';
				end if;

				-- CKV Hi
				if (timer = to_unsigned(OUTER_CKV_HI_3, timer'length)) then
					CKV <= '1';
				end if;

				--------------------------------------------------- END VSCAN Start

					---------------------------------------------------------------
					-- Start Inner Loop 25836
					---------------------------------------------------------------

					--------------------------------------------------- HSCAN Start
					-- OE Hi, SPH low, MEM On & Output & not write
					if (timer = to_unsigned(INNER_OE_HI_SPH_LO_MEM_ON, timer'length)) then
						OE <= '1';
						SPH <= '0';
						MEM_OE <= '0';
						MEM_WE <= '1';
						MEM_CE <= '0';
						--DATA <= "01010101";
						DATA <= "ZZZZZZZZ";
					end if;
					----------------------------------------------- END HSCAN Start

						-----------------------------------------------------------
						-- Start Pixel Loop 25860
						-----------------------------------------------------------

						-- PIXEL_GET_MEMORY
						if (timer = to_unsigned(PIXEL_GET_MEMORY, timer'length)) then
							ADDR <= getAddress(MEM_ADDR, CONTRAST);
							if (CONTRAST >= CONTRAST_BP_HI) then -- >
								DATA <= IO;
							else
								if (CONTRAST >= CONTRAST_START_DARK and CONTRAST <= CONTRAST_END_DARK) then
									DATA <= "01010101";
								else
									DATA <= "10101010";
								end if;
							end if;
						end if;

						-- CL Hi
						if (timer = to_unsigned(PIXEL_CL_HI, timer'length)) then
							CL <= '1';
						end if;

						-- CL Lo
						if (timer = to_unsigned(PIXEL_CL_LO, timer'length)) then
							CL <= '0';
						end if;

						-- Do all the columns
						if (timer = to_unsigned(END_PIXEL_LOOP, timer'length)) then
							if (COLUMN < SCREEN_WIDTH) then
								timer <= to_unsigned(START_PIXEL_LOOP, timer'length);
								COLUMN <= COLUMN + to_unsigned(4, COLUMN'length);
								MEM_ADDR <= MEM_ADDR + 1;
							else
								timer <= timer + 1;
							end if;
						end if;


						-----------------------------------------------------------
						-- End Pixel Loop
						-----------------------------------------------------------

					--------------------------------------------------- HSCAN End
					-- SPH Hi
					if (timer = to_unsigned(INNER_SPH_HI_MEM_OFF, timer'length)) then
						SPH <= '1';
						MEM_OE <= '1';
						MEM_WE <= '1';
					end if;

					-- CL Hi
					if (timer = to_unsigned(INNER_CL_HI, timer'length)) then
						CL <= '1';
					end if;

					-- CL Lo
					if (timer = to_unsigned(INNER_CL_LO, timer'length)) then
						CL <= '0';
					end if;

					-- CL Hi
					if (timer = to_unsigned(INNER_CL_HI_2, timer'length)) then
						CL <= '1';
					end if;

					-- CL Lo
					if (timer = to_unsigned(INNER_CL_LO_2, timer'length)) then
						CL <= '0';
					end if;
					----------------------------------------------- END HSCAN End

					-------------------------------------------- Output Row Start
					----- Output the row first
					-- OE Hi, CKV Hi
					if (timer = to_unsigned(INNER_OE_HI_CKV_HI, timer'length)) then
						OE <= '1';
						CKV <= '1';
					end if;

					-- CKV Lo
					if (timer = to_unsigned(INNER_CKV_LO, timer'length)) then
						CKV <= '0';
					end if;

					-- OE Lo
					if (timer = to_unsigned(INNER_OE_LO, timer'length)) then
						OE <= '0';
					end if;

					----- Now start the next row
					-- CL Hi
					if (timer = to_unsigned(INNER_CL_HI_3, timer'length)) then
						CL <= '1';
					end if;

					-- CL Lo
					if (timer = to_unsigned(INNER_CL_LO_3, timer'length)) then
						CL <= '0';
					end if;

					-- CL Hi
					if (timer = to_unsigned(INNER_CL_HI_4, timer'length)) then
						CL <= '1';
					end if;

					-- CL Lo
					if (timer = to_unsigned(INNER_CL_LO_4, timer'length)) then
						CL <= '0';
					end if;

					-- CKV Hi
					if (timer = to_unsigned(INNER_CKV_HI, timer'length)) then
						CKV <= '1';
					end if;
					---------------------------------------------- Output Row End

					---------------------------------------------- Latch Row Start
					-- LE Hi
					if (timer = to_unsigned(INNER_LE_HI, timer'length)) then
						LE <= '1';
					end if;

					-- CL Hi
					if (timer = to_unsigned(INNER_CL_HI_5, timer'length)) then
						CL <= '1';
					end if;

					-- CL Lo
					if (timer = to_unsigned(INNER_CL_LO_5, timer'length)) then
						CL <= '0';
					end if;

					-- CL Hi
					if (timer = to_unsigned(INNER_CL_HI_6, timer'length)) then
						CL <= '1';
					end if;

					-- CL Lo
					if (timer = to_unsigned(INNER_CL_LO_6, timer'length)) then
						CL <= '0';
					end if;

					-- LE Lo
					if (timer = to_unsigned(INNER_LE_LO, timer'length)) then
						LE <= '0';
					end if;

					-- CL Hi
					if (timer = to_unsigned(INNER_CL_HI_7, timer'length)) then
						CL <= '1';
					end if;

					-- CL Lo
					if (timer = to_unsigned(INNER_CL_LO_7, timer'length)) then
						CL <= '0';
					end if;

					-- CL Hi
					if (timer = to_unsigned(INNER_CL_HI_8, timer'length)) then
						CL <= '1';
					end if;

					-- CL Lo
					if (timer = to_unsigned(INNER_CL_LO_8, timer'length)) then
						CL <= '0';
					end if;

					------------------------------------------------ Latch Row End

					-- Do all the rows
					if (timer = to_unsigned(END_INNER_LOOP, timer'length)) then
						if (ROW < SCREEN_HEIGHT) then
							timer <= to_unsigned(START_INNER_LOOP, timer'length);
							ROW <= ROW + to_unsigned(1, ROW'length);

							-- RESET Column Counter
							COLUMN <= (others => '0');

						else
							timer <= timer + 1;
						end if;
					end if;

					---------------------------------------------------------------
					-- End Inner Loop
					---------------------------------------------------------------

				--------------------------------------------------- VSCAN END Start
				-- VSCAN END Start
				----------------------------------------------------- HSCAN Start 2
				-- OE Hi, SPH low
				if (timer = to_unsigned(OUTER_OE_HI_SPH_LO, timer'length)) then
					OE <= '1';
					SPH <= '0';

					-- RESET Column Counter
					COLUMN <= (others => '0');
				end if;
				------------------------------------------------- END HSCAN Start 2

					---------------------------------------------------------------
					-- Start Pixel Loop2
					-- This is for the row off the end of the screen.
					---------------------------------------------------------------
					-- CL Hi
					if (timer = to_unsigned(PIXEL2_CL_HI, timer'length)) then
						CL <= '1';
					end if;

					-- CL Lo
					if (timer = to_unsigned(PIXEL2_CL_LO, timer'length)) then
						CL <= '0';
					end if;

					-- Do all the columns
					if (timer = to_unsigned(END_PIXEL2_LOOP, timer'length)) then
						if (COLUMN < SCREEN_WIDTH) then
							timer <= to_unsigned(START_PIXEL2_LOOP, timer'length);
							COLUMN <= COLUMN + 4; --to_unsigned(4, COLUMN'length);
						else
							timer <= timer + 1;
						end if;
					end if;
					---------------------------------------------------------------
					-- End Pixel Loop2
					---------------------------------------------------------------

				-------------------------------------------------------- HSCAN End2
				-- SPH Hi
				if (timer = to_unsigned(OUTER_SPH_HI, timer'length)) then
					SPH <= '1';
				end if;

				-- CL Hi
				if (timer = to_unsigned(OUTER_CL_HI, timer'length)) then
					CL <= '1';
				end if;

				-- CL Lo
				if (timer = to_unsigned(OUTER_CL_LO, timer'length)) then
					CL <= '0';
				end if;

				-- CL Hi
				if (timer = to_unsigned(OUTER_CL_HI_2, timer'length)) then
					CL <= '1';
				end if;

				-- CL Lo
				if (timer = to_unsigned(OUTER_CL_LO_2, timer'length)) then
					CL <= '0';
				end if;
				---------------------------------------------------- END HSCAN End2

				-- This point in the C++ we'd turn interrupts and finish off this
				-- particular cycle. OE, CKV, GMODE all get flipped.

				-- OE, CKV Hi
				if (timer = to_unsigned(OUTER_OE_HI_CKV_HI, timer'length)) then
					OE <= '1';
					CKV <= '1';
				end if;

				-- CKV Lo
				if (timer = to_unsigned(OUTER_CKV_LO_4, timer'length)) then
					CKV <= '0';
				end if;

				-- OE Lo
				if (timer = to_unsigned(OUTER_OE_LO, timer'length)) then
					OE <= '0';
				end if;

				-- Then we would reenable interrupts here and run the clock.

				-- CL Hi
				if (timer = to_unsigned(OUTER_CL_HI_3, timer'length)) then
					CL <= '1';
				end if;

				-- CL Lo
				if (timer = to_unsigned(OUTER_CL_LO_3, timer'length)) then
					CL <= '0';
				end if;

				-- CL Hi
				if (timer = to_unsigned(OUTER_CL_HI_4, timer'length)) then
					CL <= '1';
				end if;

				-- CL Lo
				if (timer = to_unsigned(OUTER_CL_LO_4, timer'length)) then
					CL <= '0';
				end if;

				-- OE, CKV Double Sure of Low (!)
				if (timer = to_unsigned(OUTER_OE_LO_CKV_LO, timer'length)) then
					OE <= '0';
					CKV <= '0';
				end if;

				-- CKV Hi
				if (timer = to_unsigned(OUTER_CKV_HI_5, timer'length)) then
					CKV <= '1';
				end if;

				-- CKV Lo
				if (timer = to_unsigned(OUTER_CKV_LO_5, timer'length)) then
					CKV <= '0';
				end if;

				-- GMODE Lo
				if (timer = to_unsigned(OUTER_GMODE_LO, timer'length)) then
					GMODE <= '0';
				end if;
				----------------------------------------------------- VSCAN END end

				-------------------------------------------------------------------
				-- End Outer Loop
				-------------------------------------------------------------------

				if (timer = to_unsigned(END_OUTER_LOOP, timer'length)) then
					if (CONTRAST < CONTRAST_CYCLES) then
						COLUMN <= to_unsigned(0, COLUMN'length);
						ROW <= to_unsigned(0, ROW'length);
						timer <= to_unsigned(START_OUTER_LOOP, timer'length);
						CONTRAST <= CONTRAST + 1;
						MEM_ADDR <= to_unsigned(0, MEM_ADDR'length);
					else
						timer <= timer + 1;
					end if;
				end if;

				-- Power Off.

				-- End cycle, POS Voltage Off
				if (timer = to_unsigned(POWEROFF_POS_LO, timer'length)) then
					POS_CTRL <= '0';
				end if;

				-- NEG Voltage Off
				if (timer = to_unsigned(POWEROFF_NEG_LO, timer'length)) then
					NEG_CTRL <= '0';
				end if;

				-- SMPS Off, End of Cycle
				if (timer = to_unsigned(POWEROFF_SMPS_HI, timer'length)) then
					SMPS_CTRL <= '1';
				end if;


				if (timer = to_unsigned(SAFE_REFRESH, timer'length)) then

					-- Reset everything to safe in case we missed one
					SMPS_CTRL <= '1';
					NEG_CTRL <= '0';
					POS_CTRL <= '0';


					CKV <= '1';
					SPV <= '0';
					GMODE <= '0';
					SPH <= '0';
					OE <= '0';
					CL <= '0';
					LE <= '0';

					-- Data Cycles
					cycle <= not cycle;
					COLUMN <= to_unsigned(0, COLUMN'length);
					ROW <= to_unsigned(0, ROW'length);
					CONTRAST <= to_unsigned(0, CONTRAST'length);
					DATA <= "00000000";
					MEM_ADDR <= to_unsigned(0, MEM_ADDR'length);
					MEM_CE <= '1';

					-- Flags
					CHECK_GRAB_DONE <= '0';
					FRAME_WRITE_DONE <= '0';
				end if;

				-- Dirty hack!
				if (
					timer /= to_unsigned(END_INNER_LOOP, timer'length) and
					timer /= to_unsigned(END_PIXEL_LOOP, timer'length) and
					timer /= to_unsigned(END_PIXEL2_LOOP, timer'length) and
					timer /= to_unsigned(END_OUTER_LOOP, timer'length) and
					timer /= to_unsigned(ROLLOVER_SCREEN, timer'length)
				) then
					timer <= timer + 1; -- Increase timer.
				end if;

				if (timer = to_unsigned(ROLLOVER_SCREEN-100, timer'length)) then
					FRAME_WRITE_DONE <= '1';
				end if;

				-- Roll over when we tell you to (Assuming 18-24 MHz.)
				if (timer = to_unsigned(ROLLOVER_SCREEN, timer'length)) then
					timer <= to_unsigned(0, timer'length);
					COLUMN <= to_unsigned(0, COLUMN'length);
					ROW <= to_unsigned(0, ROW'length);
					MEM_ADDR <= to_unsigned(0, MEM_ADDR'length);
					CHECK_GRAB_DONE <= '0';
					READY_WRITE <= '0';
					-- Done with our thing, see you after the next frame grab!
				end if;
			end if; -- End Global State '1'
		end if; -- End Rising Edge CLK0
	end process;
end Behavioral;