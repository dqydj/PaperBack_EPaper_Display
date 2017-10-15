library IEEE;
use IEEE.std_logic_1164.all;

entity converter_firmware is
    port (
        CLK0: inout std_logic;
		
		-- Power Lines
		NEG_CTRL:	out std_logic; 
		POS_CTRL:	out std_logic;
		SMPS_CTRL:	out std_logic; -- Active low
			
		-- Control Lines
		CKV:		out std_logic;
		SPV: 		out std_logic;
		GMODE:		out std_logic;
		SPH: 		out std_logic;
		OE: 		out std_logic;
			
		-- Clocks/Edges
		CL: 		out std_logic;
		LE: 		out std_logic;
		DATA:		out std_logic_vector(7 downto 0);
		
		-- Memory
		ADDR: 		out std_logic_vector(18 downto 0);
		IO: 		inout std_logic_vector(7 downto 0);
		MEM_OE: 	out std_logic; -- Active low 
		MEM_WE:		inout std_logic; -- Active low
		MEM_CE: 	out std_logic;  -- Active low
		
		-- VGA Capture
		DCK:		in std_logic;
		HSYNC:		in std_logic;
		VSYNC: 		in std_logic;
		RED: 		in std_logic_vector(7 downto 4);
		GREEN: 		in std_logic_vector(7 downto 4);
		BLUE: 		in std_logic_vector(7 downto 4);
		
		-- SWITCH Capture
		SW: 		inout std_logic_vector(3 downto 1);
		
		--VGA Debug
		MEM_WE2: 	inout std_logic;
		DCK_OUT: 	out std_logic;
		HS_OUT: 	out std_logic;
		VS_OUT: 	out std_logic;
		
		-- SWITCH Debug
		SW1: 		out std_logic := '0';
		SW2: 		out std_logic := '0';
		SW3: 		out std_logic := '0'
		
	);
end converter_firmware;

architecture Behavioral of converter_firmware is

	COMPONENT FrameWriter
	port( 	
			-- Input from above
			CLK0: in std_logic;
			
			-- User switches
			SW: 		in std_logic_vector(3 downto 1);
			
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
			DATA:		out std_logic_vector(7 downto 0) := "00000000";
			
			-- Memory
			ADDR: 		out std_logic_vector(18 downto 0);
			IO: 		inout std_logic_vector(7 downto 0);
			MEM_OE: 	out std_logic := '1'; -- Active low 
			MEM_WE:		out std_logic := '1'; -- Active low
			MEM_CE: 	out std_logic := '1'; -- Active low
			
			-- Control State
			FRAME_GRAB_DONE: 	in std_logic;
			FRAME_WRITE_DONE: 	out std_logic;
			READY_WRITE: 		inout std_logic
	);
	END COMPONENT;
	
	COMPONENT FrameGrabber 
	port( 	
			-- Memory
			ADDR: 				out std_logic_vector(18 downto 0);
			IO: 				inout std_logic_vector(7 downto 0);
			MEM_OE: 			out std_logic := '1'; -- Active low 
			MEM_WE:				out std_logic := '1'; -- Active low
			MEM_CE: 			out std_logic := '1'; -- Active low
			
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
	END COMPONENT;
	
	COMPONENT OSCC 
	PORT (
		OSC:OUT std_logic
	);
	END COMPONENT;
	
	-- Mux Memory Signals for Grabber
	signal MEM_WE_GRAB, MEM_CE_GRAB, MEM_OE_GRAB : std_logic;
	signal ADDR_GRAB :  std_logic_vector(18 downto 0);
	signal IO_GRAB : std_logic_vector(7 downto 0);
	
	-- Mux Memory Signals for ePD
	signal MEM_WE_WRITE, MEM_CE_WRITE, MEM_OE_WRITE : std_logic;
	signal ADDR_WRITE :  std_logic_vector(18 downto 0);
	signal IO_WRITE : std_logic_vector(7 downto 0);
	
	-- State
	signal FRAME_GRAB_DONE, FRAME_WRITE_DONE, READY_WRITE : std_logic;

begin

	-- Internal FPGA Clock
	OSCInst0: OSCC PORT MAP ( 
		OSC => CLK0	
	);
		
	-- User switch. Doesn't really need to be in a process...
	Switcher: process(
		SW
	)
	begin
		SW1 <= SW(1);
		SW2 <= SW(2);
		SW3 <= SW(3);
	end process;
	
	-- Control which process has the memory...
	MemoryController: process(
		READY_WRITE,
		ADDR_WRITE,
		MEM_OE_WRITE,
		MEM_WE_WRITE,
		MEM_CE_WRITE,
		IO_GRAB,
		ADDR_GRAB,
		MEM_OE_GRAB,
		MEM_WE_GRAB,
		MEM_CE_GRAB,
		IO
	)
	begin
		if (READY_WRITE = '1') then
			IO <= "ZZZZZZZZ";
			IO_WRITE <= IO;
			ADDR <= ADDR_WRITE;
			MEM_OE <= MEM_OE_WRITE;
			MEM_WE <= '1'; -- We should never change this in here.
			--MEM_WE <= MEM_WE_WRITE;
			MEM_CE <= MEM_CE_WRITE;
		else			
			IO <= IO_GRAB;
			ADDR <= ADDR_GRAB;
			MEM_OE <= '1'; -- We should never change this in here.
			--MEM_OE <= MEM_OE_GRAB;
			MEM_WE <= MEM_WE_GRAB;
			MEM_CE <= MEM_CE_GRAB;
		end if;
	end process; -- End MemoryController
	
	-- The Frame writing logic...
	Inst_FrameWriter: FrameWriter PORT MAP(
		-- Internal Clock
		CLK0 => CLK0,
		
		-- User Switches
		SW => SW,
		
		-- EPD Lines
		NEG_CTRL => NEG_CTRL,
		POS_CTRL => POS_CTRL,
		SMPS_CTRL => SMPS_CTRL,
		CKV => CKV,
		SPV => SPV,
		GMODE => GMODE,
		SPH => SPH,
		OE => OE,
		CL => CL,
		LE => LE,
		DATA => DATA,
		
		-- Muxed
		ADDR => ADDR_WRITE,
		IO => IO_WRITE,
		MEM_OE => MEM_OE_WRITE,
		MEM_WE => MEM_WE_WRITE,
		MEM_CE => MEM_CE_WRITE,
		
		-- State
		FRAME_GRAB_DONE => FRAME_GRAB_DONE,
		FRAME_WRITE_DONE => FRAME_WRITE_DONE,
		READY_WRITE => READY_WRITE
	);
	
	-- The Frame grabbing logic from VGA...
	-- Compatible with Analog Devices 9883 or MST 9883
	-- or others in this family.
	Inst_FrameGrabber: FrameGrabber PORT MAP(
		-- Muxed
		ADDR => ADDR_GRAB,
		IO => IO_GRAB,
		MEM_OE => MEM_OE_GRAB,
		MEM_WE => MEM_WE_GRAB,
		MEM_CE => MEM_CE_GRAB,
	
		-- Direct
		HSYNC => HSYNC,
		VSYNC => VSYNC,
		DCLK => DCK,
		--RED => RED,
		GREEN => GREEN,
		--BLUE => BLUE,
			
		-- State
		FRAME_GRAB_DONE => FRAME_GRAB_DONE,
		FRAME_WRITE_DONE => FRAME_WRITE_DONE
	);
	
	-- Debugging signals (will probably hide these behind a switch)
	DCK_OUT <= DCK;
	HS_OUT <= HSYNC;
	VS_OUT <= VSYNC;
	MEM_WE2 <= MEM_WE;
	
end Behavioral;