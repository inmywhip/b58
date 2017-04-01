// Part 2 skeleton

// implement not erasing paddle when collecting
// implement time limit

module final
	(
		CLOCK_50,						//	On Board 50 MHz
		// Your inputs and outputs here
        KEY,
        SW,
		  LEDR,
		  LEDG,
		  HEX0,
		  HEX1,
		  HEX2,
		  HEX3,
		  HEX4,
		  HEX5,
		  HEX6,
		  HEX7,
		// The ports below are for the VGA output.  Do not change.
		VGA_CLK,   						//	VGA Clock
		VGA_HS,							//	VGA H_SYNC
		VGA_VS,							//	VGA V_SYNC
		VGA_BLANK_N,						//	VGA BLANK
		VGA_SYNC_N,						//	VGA SYNC
		VGA_R,   						//	VGA Red[9:0]
		VGA_G,	 						//	VGA Green[9:0]
		VGA_B   						//	VGA Blue[9:0]
	);

	input	CLOCK_50;				//	50 MHz
	input   [17:0]   SW;
	input   [3:0]   KEY;

	// Declare your inputs and outputs here
	output [17:0] LEDR;
	output [8:0] LEDG;
	output [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, HEX6, HEX7;
	// Do not change the following outputs
	output			VGA_CLK;   				//	VGA Clock
	output			VGA_HS;					//	VGA H_SYNC
	output			VGA_VS;					//	VGA V_SYNC
	output			VGA_BLANK_N;				//	VGA BLANK
	output			VGA_SYNC_N;				//	VGA SYNC
	output	[9:0]	VGA_R;   				//	VGA Red[9:0]
	output	[9:0]	VGA_G;	 				//	VGA Green[9:0]
	output	[9:0]	VGA_B;   				//	VGA Blue[9:0]
	
	// Create the colour, x, y and writeEn wires that are inputs to the controller.
	wire resetn, go, doneDrop, ld_val, startDrop, Ychange, draw, drawing, writeOK, write;
	wire [7:0] coin_x;
	wire [7:0] user_x;
	wire [6:0] outY;
	wire [7:0] outX;
	wire [2:0] colour;
	wire [7:0] x;
	wire [6:0] y;
	wire writeEn = write && startDrop; // Set this to on only when plotting //

	wire ld_x;
	wire colour_in;
	assign colour_in = 3'b111; // white

	// Stuff from player side
	wire [7:0] xCoorOut;
	wire out_clk;
	wire leftIn, rightIn;
	assign leftIn = ~KEY[3];
	assign rightIn = ~KEY[2];

	// Create an Instance of a VGA controller - there can be only one!
	// Define the number of colours as well as the initial background
	// image file (.MIF) for the controller.module final
	vga_adapter VGA(
			.resetn(1'b1),	// Disallow resets
			.clock(clk),
			.colour(colour),
			.x(x),
			.y(y),
			.plot(writeEn),
			/* Signals for the DAC to drive the monitor. */
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK(VGA_BLANK_N),
			.VGA_SYNC(VGA_SYNC_N),
			.VGA_CLK(VGA_CLK));
		defparam VGA.RESOLUTION = "160x120";
		defparam VGA.MONOCHROME = "FALSE";
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
		defparam VGA.BACKGROUND_IMAGE = "black.mif";
			
	// Put your code here. Your code should produce signals x,y,colour and writeEn/plot
	// for the VGA controller, in addition to any other functionality your design may require.
	
	// FOR MODEL SIM
		assign resetn = 1'b1; // disable resets
		assign clk = CLOCK_50;
		assign LEDR[16] = startDrop;
		assign LEDR[14] = doneDrop;
		assign LEDR[13] = draw;
		assign LEDR[12] = ld_x;
		hex_decoder({1'b0, outY[6:4]}, HEX3);
		hex_decoder(outY[3:0], HEX2);
		hex_decoder(xCoorOut[7:4], HEX5);
		hex_decoder(xCoorOut[3:0], HEX4);
		
	// For board
//		assign resetn = KEY[0];
//		assign clk = CLOCK_50;

   // Instansiate FSM control and datapath
	iterateY c3(clk, startDrop,  outY, Ychange, doneDrop);
	fsmi c1(clk, resetn, go, doneDrop,  ld_val, startDrop, LEDG[1:0]); // Get go from randomizer (should be on each time randomizer changes values)
	fsmii c2(clk, resetn, Ychange, startDrop,  draw, drawing, LEDR[4:0]);
	randomizer r1(clk, xCoorOut,  go, outX); // get userX from the user's x location
	scoreKeeper out0(resetn, Ychange, xCoorOut, coin_x, y, HEX0, HEX1);
	
	// Player side
	control c0(clk, resetn, leftIn, rightIn, drawing, ld_x, writeOK, LEDR[7:5]); // outputs ld_x, writeEn;
	RateDivider divide_rate(.clk(CLOCK_50), .switch(2'b01), .out(out_clk));
	player player0(leftIn, rightIn, xCoorOut, out_clk); 
	
	datapath d0(clk, resetn, draw, drawing, ld_val, outX, outY, xCoorOut, ld_x, leftIn, rightIn, writeOK, colour, x, y, write, coin_x); // Get outX from randomizer
	assign LEDG[7] = ~KEY[3];
	assign LEDG[6] = ~KEY[2];

endmodule

// go should be on when a value is ready to be loaded	output [6:0] HEX0, HEX1, HEX4, HEX5;
module fsmi(clk, resetn, go, doneDrop, ld_val, startDrop, LEDG); // Fix state change
	input clk;
	input resetn;
	input go;
	input doneDrop;
	
	output reg ld_val, startDrop;
	output [1:0] LEDG;
	
	reg [5:0] current_state, next_state;

	localparam  S_LOAD_Val        = 2'b01,
	            S_PLOT          = 2'b10;
			   
	// state table
	always@(*)
	begin: state_table
			case (current_state)
			// For variable 'go', change using random number generator
				S_LOAD_Val: next_state = go ? S_PLOT : S_LOAD_Val; // Loop in current state until value is input
				S_PLOT: next_state = doneDrop ? S_LOAD_Val : S_PLOT; // load x after finished dropping
			default: next_state = S_LOAD_Val;//
		endcase
	end	
	
	// datapath control signals
	always@(*)
	begin: enable_signals
        // By default make all our signals 0
        ld_val = 1'b0;
        startDrop = 1'b0;
		
		case (current_state)
            S_LOAD_Val: begin
                ld_val = 1'b1;
            end
            S_PLOT: begin
                startDrop = 1'b1;
            end
		endcase
	end
	
    //current_state registers
    always@(posedge clk)
    begin: state_FFs
        if(!resetn)
            current_state <= S_LOAD_Val;
        else
            current_state <= next_state;
    end // state_FFS
	 
	assign LEDG = current_state;
endmodule

// Attach Ychange to drawNext
// Attach startDrop to drop
// draw determines whether to plot or unplot
module fsmii(clk, resetn, drawNext, drop, draw, drawing, LEDR);
	input clk;
	input drawNext; // Draw the block 1 block lower
	input resetn;
	input drop; // turn this on to initiate the falling process
	
	output reg draw, drawing;
	output [4:0] LEDR;
	
	reg [5:0] current_state, next_state;
	
	localparam  S_PLOT          = 5'b00001,
	            S_PLOT_WAIT     = 5'b00010,
					S_UNPLOT	       = 5'b00100,
					S_UNPLOT_WAIT   = 5'b01000,
					S_STANDBY	    = 5'b10000;
			   
	// state table_V
	always@(*)
	begin: state_table
		if (drop) begin // Leave standby
			case (current_state)
				S_STANDBY: next_state = S_UNPLOT; 
				S_UNPLOT: next_state = S_PLOT;
				S_PLOT: next_state = drawNext ? S_PLOT_WAIT : S_PLOT; // Waiting for a new Y value
				S_PLOT_WAIT: next_state = drawNext ? S_PLOT_WAIT : S_UNPLOT; // Loop in current state until go signal goes low
				default: next_state = S_STANDBY;
			endcase
		end
		else begin // Return to standby
			case (current_state)
				S_STANDBY: next_state = S_STANDBY; 
				S_PLOT: next_state = drawNext ? S_PLOT_WAIT : S_PLOT; // Loop in current state until value is input
				S_PLOT_WAIT: next_state = drawNext ? S_PLOT_WAIT : S_UNPLOT; // Loop in current state until go signal goes low; plotting
				S_UNPLOT: next_state = S_STANDBY;
				default: next_state = S_STANDBY;
			endcase
		end
	end
	
	// datapath control signals
	always@(*)
	begin: enable_signals
        // By default make all our signals 0
			draw = 1'b0;
			drawing = 1'b0;
		
		case (current_state)
            S_PLOT_WAIT: begin
                draw = 1'b1;
					 drawing = 1'b1;
            end
            S_UNPLOT: begin
                draw = 1'b0;
					 drawing = 1'b1;
            end
		endcase
	end
	
    // current_state registers
    always@(posedge clk)
    begin: state_FFs
        if(!resetn)
            current_state <= S_STANDBY;
        else
            current_state <= next_state;
    end // state_FFS
	 
	 assign LEDR = current_state; 
endmodule
	
module datapath(clk, reset, drawCoin, drawing, ld_val, X, Y, value_in, draw, LInput, RInput, plot, colour, x_out, y_out, write, coinX);
	input clk;
	input reset;
	input drawCoin;
	input drawing;
	input ld_val;
	input plot;
	input [6:0] Y;
	input [7:0] X;
	
	input [7:0] value_in; // x-value coming in
	input draw;
	input LInput, RInput;

	reg [7:0] x;	
	wire [3:0] counter_wire;

	output reg [2:0] colour;	
	output reg [6:0] y_out;
	output reg [7:0] x_out;
	output reg write;
	
	output reg [7:0] coinX;
	reg [7:0] userX;
	reg counter = 2'b00;
	
	initial begin
		coinX = 8'd27;
		colour <= 3'b111; // white player
		x_out = 8'd80;
		repeat(4) begin
			x_out = value_in + counter;
			counter = counter + 1;
		end
	end
	
	always@(posedge clk) 
	begin
		write = 1'b0;
		colour = 3'b000; // Stop drawing 'stars'
	
		if (drawing) begin // Give drawing the coin the priority
			if (!reset) begin // Unplot the previous location.
				y_out = Y - 1; // Unplot the previous location
				colour = 3'b000; // Black
			end
			else if (drawCoin) // Plot the coin
			begin
				y_out = Y;
				colour = 3'b111; // White. Same colour as the player to deal with overlaps
			end
		
			else // Unplot the coin
			begin
				// Don't unplot if collecting the coin.
				if ((Y == 8'd120) && ((value_in == coinX) || (value_in + 1 == coinX) || (value_in + 2 == coinX) || (value_in + 3 == coinX))) begin
					y_out = 9'd200;
					end
				else
					y_out = Y - 1; // Unplot the previous location
				colour = 3'b000; // Black
			end
			if (ld_val) begin
				coinX = X; // Load the value
			end
			
			x_out <= coinX;
			write = 1'b1;
		end
		else begin
			y_out = 8'd119;
//			if (!plot && !draw) begin // if left/right both 0 -> draw only if coordinate is starting position
//					x_out = value_in + 1'b0;
//					colour <= 3'b111; // player is white
//			end
			// Erase first
			if (!draw) // if (L = 1 or R = 1) writeEn == 1 and ld_x == 0 -> unplot
			begin
				if (RInput && LInput) // Do nothing if both inputs are on
					userX = 8'd255; // draw offscreen
				else if (RInput) 
					userX = value_in - 3'd1; // Where to erase
				else if (LInput)
					userX = value_in + 3'd4; // Where to erase
				colour <= 3'b000; // Erase with black
			end
			// Draw new location
			else if (draw) // if writeEn == 1 and ld_x == 1 -> draw new box
			begin
				if (RInput && LInput) // Do nothing if both inputs are on
					userX = 8'd255; // draw offscreen
				else if (RInput) 
					userX = value_in + 3'd3; // Where to draw
				else if (LInput)
					userX = value_in; // Where to draw
				colour <= 3'b111; // Player is white
			end
			
			x_out <= userX;
			write = 1'b1;
		end
	end
endmodule

module iterateY(clk, startDrop, outY, change, done); // Attach start signal
	input clk;
	input startDrop;
	output reg [6:0] outY;
	output change;
	output reg done; // Tell the FSMs when the coin has reached the bottom

	wire [6:0] counterY;
	
	always@(*)
	begin
		// Off the screen or do not start yet, set reset to OFF.
		if (outY >= 8'd121 | startDrop == 1'b0) begin  // do outY >= 8'd119
			outY <= 0;
			done <= 1'b1;
		end
		else begin
			outY <= counterY;
			done <= 1'b0;
		end
	end
	
	// Set Dcounter's 'resetn' to 'start' to disable counting
	dropCounter Dcounter(clk, startDrop, counterY, change);
endmodule

module dropCounter(clk, resetn, out, change);
		input clk;
		input resetn;
		output reg [6:0]out; // Need to reach 120; OK
		output reg change; // Tell the FSMs when out has 'dropped'
		reg [28:0]count;
		wire [28:0] interval;
		reg enable;
		
//		assign interval = 27'd100000000 - 1'd1;
		assign interval = 27'd4500000 - 1'd1;

		// interval = 26'd500000000 - 1'd1;
		
		always@(posedge clk)
		begin
			if (!resetn) begin
				enable = 1'b0;
				count <= interval; // reset the display counter
				change <= 1'b0;
				out <= 0;
			end
		
			else if (enable == 1'b1) begin
				enable = 1'b0;
				count <= interval; // reset the display counter
				out <= out + 1;
			end
			else if (count == 1'b0) begin
				enable = 1'b1;	// count <= 0;000;set enable on
				change <= 1'b1;
			end
			else begin
				count <= count - 1'b1;	// countdown
				change <= 1'b0;
			end
		end
endmodule

module randomizer(clk, user_x, signal, out);
	input clk;							// The clock
	input [7:0] user_x;           // x coordinate of the player
	output reg signal;            // signal when out changes
	output reg [7:0] out;         // the random number generated

	wire [8:0] count;            // output from rawCounter
	reg [8:0] out9;				// out with an extra bit
	wire [8:0] revCount = {count[0], count[1], count[2], count[3], count[4], count[5], count[6], count[7], count[8]}; // reverse the bits of count
	wire [7:0] revUser = {user_x[0], user_x[1], user_x[2], user_x[3], user_x[4], user_x[5], user_x[6], user_x[7]};
	
	always@(posedge clk)
	begin
			out9 <= revUser^revCount; // Maybe let the user's x position affect out9
			
			if (out9 < 8'd160) begin
				signal = 1'b1;		// Let the FSM know a valid X has been chosen
				out <= out9 [7:0];
			end
			else
				signal = 1'b0;		// Number not chosen yet
	end
	
	rawCounter Rcounter(clk, count);
endmodule

module rawCounter(
	input clk,
	output reg [8:0] out // Also make sure this is enough
	);
	
	initial
		out <= 9'd27;
	
	always@(posedge clk)
		out <= out + 1'b1;
endmodule

module scoreKeeper(reset, check, userX, X, Y, HEXOutOnes, HEXOutTens);
	input check;
	input reset;
	input [7:0] userX;
	input [7:0] X;
	input [6:0] Y; // Now would be a good idea to find out what is the max Y
//	input LEDG;
	output [6:0] HEXOutOnes, HEXOutTens;
	
	reg [7:0] count_score;
	reg [7:0] score;

	always@(negedge check) begin
		if (Y == 8'd119)
			if ((userX == X) || (userX + 1 == X) || (userX + 2 == X) || (userX + 3 == X)) // If the user overlaps the coin location
				score = score + 1;	// Get 1 point
	end

	hex_decoder(score [3:0], HEXOutOnes);
	hex_decoder(score [7:4], HEXOutTens);
//	assign LEDG = ((userX == X) || (userX + 1 == X) || (userX + 2 == X) || (userX + 3 == X));

endmodule

// Player side:

module control(clk, resetn, L, R, drawing, ld_x, writeEn, LEDR);//, LOut, ROut); // no longer handles colour since it should only draw 1 colour determined by SW[9:0]
	input clk;
	input resetn;
	input L;
	input R;
	input drawing;
	
	output LEDR;
	assign LEDR = current_state;
	output reg ld_x, writeEn;
	
	reg [1:0] current_state, next_state; // only 2 flip flops -> each flip flop holds 2-bit binary
	
	localparam S_HOLD		= 2'd1,
	           S_UNPLOT		= 2'd2,
	           S_PLOT		= 2'd4;
			   
	always@(*)
	begin: state_table
			case (current_state)
				S_HOLD:		begin // Loop in hold state until only one of the L, R inputs = 1
								if ((L == 1'b1 || R == 1'b1))
									next_state <= S_UNPLOT;
								else
									next_state <= S_HOLD; 
							end
				S_UNPLOT: 	next_state <= S_PLOT;
				S_PLOT: 	next_state <= S_HOLD;
			default: next_state = S_HOLD;
		endcase
	end

	always@(*) // logic at each state
	begin: enable_signals
        // By default make all our signals 0
        ld_x = 1'b0;
        writeEn = 1'b0;
		
		case (current_state)
            S_UNPLOT: 	begin
							writeEn = 1'b1;
						end
            S_PLOT: 	begin
							ld_x = 1'b1; // load new value
							writeEn = 1'b1;
						end
				S_HOLD: begin
							
						end
		endcase
	end
	
	always@(posedge clk)
    begin: state_FFs
//        if(!resetn) // Reset disabled
//            current_state <= S_HOLD;
		  if(!drawing) // Lock the state if coin is drawing
            current_state <= next_state;
				
    end 
endmodule

module counter(
	input enable,
	input clk,
	input resetn,
	output reg [3:0] out,
	input init
	);
	
	always@(posedge clk)
	begin
		if(resetn == 1'b0)
			out <= 0;
		else if (enable == 1'b1 || init == 1'b1) // if reset is pressed or L/R switch is flicked -> plot
			out <= out + 1'b1;
	end
endmodule

module RateDivider(clk, switch, out);
	input clk;
	input [1:0] switch;
	output reg out;

	// ???????????????
	reg [27:0] counter0; // a lot hz;
	reg [27:0] counter50mil; // 1hz;
	reg [27:0] counter100mil; // 0.5hz;
	reg [27:0] counter200mil; // 0.25hz;
	
	wire hertzalot, hertz1, hertz05, hertz025;
	
	assign hertzalot = (counter0 == 28'h0000000) ? 1 : 0;
	assign hertz1 = (counter50mil == 28'h0000000) ? 1 : 0;
	assign hertz05 = (counter100mil == 28'h0000000) ? 1 : 0;
	assign hertz025 = (counter200mil == 28'h0000000) ? 1 : 0;

	always @(posedge clk)
	begin
		if(counter0 == 28'h0000001)
		    begin
		        counter0 <= 0;
		    end
		else
		    begin
	          counter0 <= counter0 + 1'b1;
		    end

		if(counter50mil == 28'h4C4B40) // 50m changed to 10m
		    begin
		        counter50mil <= 0;
		    end
		else
		    begin
	          counter50mil <= counter50mil + 1'b1;
		    end
			
		if(counter100mil == 28'h5F5E100)
		    begin
		        counter100mil <= 0;
		    end
		else
		    begin
				  counter100mil <= counter100mil + 1'b1;
		    end
			 
		if(counter200mil == 28'hBEBC200)
		    begin
		        counter200mil <= 0;
		    end
		else
		    begin
		        counter200mil <= counter200mil + 1'b1;
		    end
			 
		case(switch)
			2'b00: out <= hertzalot;
			2'b01: out <= hertz1;
			2'b10: out <= hertz05;
			2'b11: out <= hertz025;
			default: out <= clk;
		endcase
	end
endmodule

module player(left, right, playerX, clock);
	input left, right, clock;
	output reg [7:0] playerX;
	
	initial
		playerX <= 8'd80;
	
	always @(posedge clock) // outputs prev coordinate and new coordinate
	begin
		if (left == 1'b1 && playerX > 8'd0) 
			playerX = playerX - 1;
		if (right == 1'b1 && playerX < 8'd156) // -4 for width of player; two if statements means if they're both on, player does not move
			playerX = playerX + 1;
	end
endmodule

module hex_decoder(hex_digit, segments);
    input [3:0] hex_digit;
    output reg [6:0] segments;
   
    always @(*)
        case (hex_digit)
            4'h0: segments = 7'b100_0000;
            4'h1: segments = 7'b111_1001;
            4'h2: segments = 7'b010_0100;
            4'h3: segments = 7'b011_0000;
            4'h4: segments = 7'b001_1001;
            4'h5: segments = 7'b001_0010;
            4'h6: segments = 7'b000_0010;
            4'h7: segments = 7'b111_1000;
            4'h8: segments = 7'b000_0000;
            4'h9: segments = 7'b001_0000;
            4'hA: segments = 7'b000_1000;
            4'hB: segments = 7'b000_0011;
            4'hC: segments = 7'b100_0110;
            4'hD: segments = 7'b010_0001;
            4'hE: segments = 7'b000_0110;
            4'hF: segments = 7'b000_1110;   
            default: segments = 7'h7f;
        endcase
endmodule