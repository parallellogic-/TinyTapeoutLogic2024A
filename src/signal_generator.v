
//behavior undefined for signals of length 0 bits

parameter SIG_GEN_RISING_TIMESTAMP_REGISTER=8;//wrere to store timestamp in memory
parameter SIG_GEN_FALLING_TIMESTAMP_REGISTER=12;
parameter SIG_GEN_LENGTH_REGISTER=17;
parameter SIG_GEN_SLEEP_REGISTER=18;
parameter SIG_GEN_CONFIG_REGISTER=20;
parameter SIG_GEN_TRIGGER_COUNT_REGISTER=21;

module signal_generator #(
    parameter RW_REG_COUNT = 22  // Number of input flags and data sets
) (
	input wire clk,
	input wire trigger,//1/0 coming from the input trigger pin
	input wire clk_div,
	input wire is_div_bypass,//set to 1 to run sig gen at max speed (at speed of sys clock)
	input wire [31:0] counter,//for saving the timestamp of trigger events
	input wire rst_n,
	input wire [1:0] loop_mode,//0 is off, 1 is single, 2 is multi (once per trigger), 3 is loop
	input wire is_trigger_on_rising_edge,
	input wire is_trigger_on_falling_edge,
	input wire is_save_rising_timestamp,
	input wire is_save_falling_timestamp,
	input wire [RW_REG_COUNT*8-1:0] was_config,
	output wire [RW_REG_COUNT*8-1:0] is_config,
	output wire [RW_REG_COUNT-1:0] is_update_flag,
	output reg [3:0] sig_gen_out,
	output wire is_running
);

reg prev_clk_div;
reg prev_trigger;
wire is_clk_div_rising_edge=(clk_div&!prev_clk_div)|is_div_bypass;
wire is_trigger_rising_edge=  ( trigger &!prev_trigger)&is_trigger_on_rising_edge  & !is_running;
wire is_trigger_falling_edge=((!trigger)& prev_trigger)&is_trigger_on_falling_edge & !is_running;
wire is_trigger_on_any_edge=is_trigger_on_rising_edge&is_trigger_on_falling_edge;
//wire is_enabled=|loop_mode;
wire is_loop=loop_mode==2'b11;

reg [7:0] index_reg;//in signal mode, this is the index of the bit being output.  in sleep mode, this is the amount of time remaining until the end of the waveform
reg [1:0] state_machine;//0 is awaiting trigger, 1 is bit mode, 2 is sleep
assign is_running=state_machine!=2'b00;
wire [7:0] next_index=index_reg-1;

wire [7:0] all_single_triggers_cleared=was_config[8*SIG_GEN_CONFIG_REGISTER +: 8]&8'b11110010;//clear the rising/falling edge triggers and single-event
wire [7:0] rising_trigger_cleared=was_config[8*SIG_GEN_CONFIG_REGISTER +: 8]&8'b11111011;//clear only the rising trigger flag
wire [7:0] falling_trigger_cleared=was_config[8*SIG_GEN_CONFIG_REGISTER +: 8]&8'b11110111;//clear only the falling trigger flag
wire [7:0] trigger_register_cleared;
wire is_triggered=(is_trigger_rising_edge|is_trigger_falling_edge);
wire [7:0] get_pattern_length={1'b0,was_config[SIG_GEN_LENGTH_REGISTER*8+:7]};//max 128 bits
wire [7:0] get_pattern_length_decrement=get_pattern_length-1;
wire [7:0] get_pattern_sleep_decrement=was_config[SIG_GEN_SLEEP_REGISTER*8+:8]-1;

assign trigger_register_cleared=(loop_mode==2'b1)?(is_trigger_on_any_edge?
									(is_trigger_rising_edge?rising_trigger_cleared:falling_trigger_cleared)://clear only one flag if single capture and listening for both trigger edges
								all_single_triggers_cleared)://clear rising/falling/single triggers if in single-trigger mode
							was_config[8*SIG_GEN_CONFIG_REGISTER +: 8];//no change if in multi/loop trigger modes

  genvar iter;
	generate//create data and flags for priority write structure
		for (iter = 0; iter < RW_REG_COUNT; iter = iter + 1) begin
			if(iter>=SIG_GEN_RISING_TIMESTAMP_REGISTER & iter<(SIG_GEN_RISING_TIMESTAMP_REGISTER+4)) begin : gen_rising_timestamp//store rising edge timestamp
				assign is_config[8*iter +: 8] = counter[(iter-SIG_GEN_RISING_TIMESTAMP_REGISTER)*8+:8];
				assign is_update_flag[iter]=is_trigger_rising_edge&is_save_rising_timestamp;
			end else if(iter>=SIG_GEN_FALLING_TIMESTAMP_REGISTER & iter<(SIG_GEN_FALLING_TIMESTAMP_REGISTER+4)) begin : gen_falling_timestamp//store falling edge timestamp
				assign is_config[8*iter +: 8] = counter[(iter-SIG_GEN_FALLING_TIMESTAMP_REGISTER)*8+:8];
				assign is_update_flag[iter]=is_trigger_falling_edge&is_save_falling_timestamp;
			end else if(iter==SIG_GEN_CONFIG_REGISTER) begin : gen_clear_single//clear the single_snapshot (and associated rising/falling edge) flags
				assign is_config[8*iter +: 8] = trigger_register_cleared;
				assign is_update_flag[iter]=is_triggered;//clear the single snapshot when machine was idle and a trigger_edge happens
			end else if(iter==SIG_GEN_TRIGGER_COUNT_REGISTER) begin : gen_count_triggers
				assign is_config[8*iter +: 8] = was_config[8*iter +: 8]+1;
				assign is_update_flag[iter]=is_triggered;
			end else begin : gen_leave_other_registers_unchanged
				assign is_config[8*iter +: 8] = was_config[8*iter +: 8];
				assign is_update_flag[iter]=1'b0;//never update the other registers
			end
		end
	endgenerate

    always @(posedge clk) begin
		if(!rst_n) begin
			prev_clk_div<=1'b0;
			prev_trigger<=1'b0;
			state_machine<=2'b0;
			sig_gen_out<=4'b0;
			index_reg<=8'b0;
		end else begin
			prev_clk_div <= clk_div;
			prev_trigger <= trigger;
			if(is_triggered) begin
				state_machine<=1;//go to bit mode (PRECON: LEN>0 of bits to write out)
				index_reg<=get_pattern_length_decrement;//first bit written out is at the highest index
				sig_gen_out[0] <= was_config[get_pattern_length];
				//if(is_save_timestamp) begin
					//save clock to bytes 8-11 (rising), DONE in combinational logic
					//save clock to bytes 12-15 (falling), DONE in combinational logic
				//end
			end
			if(is_clk_div_rising_edge & is_running) begin
				index_reg<=next_index;
				if(state_machine==1) begin//if in bit mode, output the bit
					sig_gen_out[0] <= was_config[index_reg];
				end
				if(index_reg==0) begin
					if(state_machine==1) begin
						state_machine<=2;
						index_reg<=get_pattern_sleep_decrement;
					end else if(state_machine==2) begin
						state_machine<=0;//turn OFF unless otherwise directed to continue
						//if(is_single) begin
							//clear the single_shot bit, DONE in combinational logic
						//end
						//if(is_multi) begin
							//default behavior is to return to idle waiting for trigger
						//end
						if(is_loop) begin
							state_machine<=1;//immediately continue generating pattern
							index_reg<=get_pattern_length_decrement;
							sig_gen_out[0] <= was_config[get_pattern_length];
						end
					end
				end
			end
		end
	end
	
endmodule