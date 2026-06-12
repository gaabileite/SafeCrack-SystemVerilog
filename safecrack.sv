module safe_cracker ( 
    input  logic	 clk, 		
    input  logic	 rst, 		 
    input  logic	 btn_inc, 	// increment btn
    input  logic	 btn_dec, 	// decrement btn
    input  logic	 key_conf, 	// confirmation key
    output logic	 led_green, 
    output logic	 led_red 
);

	// using one hot enconding logic
	typedef enum logic [6:0] {
		A 				= 7'b0000001,
		B 				= 7'b0000010,
		C 				= 7'b0000100,
		D 				= 7'b0001000,
		E_CHECK 		= 7'b0010000,
		E_CORRECT 		= 7'b0100000,
		E_WRONG 		= 7'b1000000
		F_WAIT			= 7'b1111111
	} state_t;

	state_t state, next_state;
	
	// defining the edge for all of the buttons
	logic	btn_inc_prev, btn_inc_edge, btn_inc_pos;
	logic key_conf_prev, key_conf_edge, key_conf_pos;
	logic btn_dec_prev, btn_dec_edge, btn_dec_pos;

	localparam int ONE_SECOND = 50_000_000; // 1 second delay at 50MHz clock
	logic [$clog2(5*ONE_SECOND)-1:0] delay_cnt, next_delay_cnt;

	// inverting buttons to active when high
	always_comb begin
		btn_inc_pos		= ~btn_inc; 
		btn_dec_pos 	= ~btn_dec;
		key_conf_pos 	= ~key_conf;
		
		// get 0 -> 1 edges
		btn_inc_edge 	= btn_inc_pos & ~btn_inc_prev; 
		btn_dec_edge 	= btn_dec_pos & ~btn_dec_prev;
		key_conf_edge 	= key_conf_pos & ~key_conf_prev;		 
	end

	// creating the parameter logic to decide the password digits
	localparam logic [3:0] pass0 = 4'b0010; // digit 3 = 2
	localparam logic [3:0] pass1 = 4'b0111; // digit 2 = 7
	localparam logic [3:0] pass2 = 4'b0011; // digit 1 = 3
	localparam logic [3:0] pass3 = 4'b1001; // digit 0 = 9
		 
	// creating the registers that'll keep the selected numbers
	logic [3:0] register0;	// keeps digit 3
	logic [3:0] register1; 	// keeps digit 2
	logic [3:0] register2; 	// keeps digit 1
	logic [3:0] register3; 	// keeps digit 0

	// transition logic
	always_comb begin 
		// default assignments
		next_state = state;
		next_delay_cnt = delay_cnt;
		
		unique case (state)
			// if the key_conf has been pressed, advance to the next state
			A: next_state = (key_conf_edge) ? B : A; 
			B: next_state = (key_conf_edge) ? C : B; 
			C: next_state = (key_conf_edge) ? D : C; 
			D: next_state = (key_conf_edge) ? E_CHECK : A;
			
			// however, for the E state, we must check if the password is correct
			E_CHECK: begin
				if (register0 	== pass0 &&
					  register1 == pass1 &&
					  register2 == pass2 &&
					  register3 == pass3)
					  next_state = E_CORRECT;
				else
					  next_state = E_WRONG;
			end
		endcase
	end

	// using sequential logic to increment/decrement the chosen password numbers && calculate the time that each led will light up
	always_ff @(posedge clk or posedge rst) begin
		// reset logic
		if (rst) begin
			state     <= A;
			register0 <= 4'b0;
			register1 <= 4'b0;
			register2 <= 4'b0;
			register3 <= 4'b0;
		end else begin
			state <= next_state;

			// if btn_inc is pressed: if (register < 9) register ++ else register = 0
			// if btn_inc is pressed: if (register > 0) register -- else register = 9
			unique case (state)
					 A: begin
						if      (btn_inc_edge && register3 < 4b'1001) 		register3 <= register3 + 1;
						else if (btn_dec_edge && register3 > 4b'0) 			register3 <= register3 - 1;
						else if (btn_inc_edge && register3 == 4b'1001) 		register3 <= 4b'0;
						else if (btn_dec_edge && register3 == 4b'0) 		register3 <= 4b'1001;
				end B: begin
						if      (btn_inc_edge && register2 < 4b'1001) 		register2 <= register2 + 1;
						else if (btn_dec_edge && register2 > 4b'0) 			register2 <= register2 - 1;
						else if (btn_inc_edge && register2 == 4b'1001) 		register2<= 4b'0;
						else if (btn_dec_edge && register2 == 4b'0) 		register2 <= 4b'1001;
				end C: begin
						if      (btn_inc_edge && register1 < 4b'1001) 		register1 <= register1 + 1;
						else if (btn_dec_edge && register1 > 4b'0) 			register1 <= register1 - 1;
						else if (btn_inc_edge && register1 == 4b'1001) 		register1 <= 4b'0;
						else if (btn_dec_edge && register1 == 4b'0) 		register1 <= 4b'1001;
				end D: begin
						if      (btn_inc_edge && register0< 4b'1001) 		register0 <= register0 + 1;
						else if (btn_dec_edge_edge && register0 > 4b'0) 	register0 <= register0 - 1;
						else if (btn_inc_edge && register0 == 4b'1001) 		register0 <= 4b'0;
						else if (btn_dec_edge && register0 == 4b'0) 		register0 <= 4b'1001;
				end E_CORRECT: begin
					delay_cnt = 5*ONE_SECOND;
					next_state = F_WAIT;
				end E_WRONG: begin
					delay_cnt = 3*ONE_SECOND;
					next_state = F_WAIT;
				end F_WAIT: begin
					if (delay_cnt > 0) begin
                    next_delay_cnt = delay_cnt - 1;
               end else begin
                    next_state     = A;
                    next_delay_cnt = delay_cnt; // resets delay counter
               end
				end
			endcase
		end
	end

	// using combinational logic to light up the LEDs
	always_comb begin
		led_green = (state == E_CORRECT)
		led_red = (state == E_WRONG)
	end
endmodule

