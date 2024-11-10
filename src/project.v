/*
 * Copyright (c) 2024 ParallelLogic
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none
//`include "charlie.v"
//`include "spi_slave.v"

module tt_um_wokwi_413386991502909441 (//tt_um_parallellogic_top
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  parameter RW_REG_COUNT=23;
  parameter RO_REG_COUNT=1;
  wire [7:0] rw_data [0:(RW_REG_COUNT-1)];
  wire [7:0] ro_data [0:(RO_REG_COUNT-1)];
  wire [(8*24-1):0] memory_frame_buffer;//flatten to work with yosys expectations of 1D lists
  wire [31:0] counter;
  //wire is_lfsr;
  //wire [3:0] tap_index;
  //wire [3:0] tap_out;
  wire [RW_REG_COUNT*8-1:0] rw_flat;
  wire [RO_REG_COUNT*8-1:0] ro_flat;
  
  //IO
  wire mosi=ui_in[2];//^is_input_inverted[2];
  wire sclk=ui_in[1];//^is_input_inverted[1];
  wire cs=ui_in[0];//^is_input_inverted[0];
  wire trigger=ui_in[3]^is_input_inverted[3];
  wire [3:0] asic_in=ui_in[7:4]^is_input_inverted[7:4];
  wire [6:0] asic_out;
  wire miso;
  wire [7:0] bi_out;
  wire [7:0] bi_en;
  assign uo_out[6:0]=asic_out^{7{is_mux_output_inv}};
  assign uo_out[7]=miso;//^is_miso_inverted;
  assign uio_out=bi_out^{8{is_bi_output_inv}};
  assign uio_oe=bi_en^{8{is_bi_en_inv}};
  
  //register map
  wire is_counter_reset=rw_data[16][7];
  wire is_lfsr=rw_data[16][6];
  wire is_clk_div_bypass=rw_data[16][5];
  wire [4:0] clk_tap_index=rw_data[16][4:0];
  wire [1:0] mega_mux_index=rw_data[22][1:0];
  wire [1:0] bi_frame_index=rw_data[19][1:0];
  wire is_bi_mirror=rw_data[19][2];
  wire [1:0] sig_gen_loop_mode=rw_data[20][1:0];
 wire is_trigger_on_rising_edge=rw_data[20][2];
 wire is_trigger_on_falling_edge=rw_data[20][3];
 wire is_save_rising_timestamp=rw_data[20][4];
 wire is_save_falling_timestamp=rw_data[20][5];
 wire [7:0] is_input_inverted=rw_data[22]; 
 wire is_mux_output_inv=rw_data[22][2];
 wire is_bi_output_inv=rw_data[19][4];
 wire is_bi_en_inv=rw_data[19][3];
 
  wire [3:0] sig_gen_out;
  wire [4:0] spi_address;
  wire [7:0] spi_data;
  wire is_spi_write;
  wire [RW_REG_COUNT-1:0] spi_write_flag=1'b1<<spi_address;
  wire [RW_REG_COUNT*8-1:0] sig_gen_data;//updates to the register map configuration in response to trigger events
  wire [RW_REG_COUNT-1:0] sig_gen_flag;//flag to indicate new data is available
  wire is_sig_gen_run;
  
      genvar i;  // Generate variable for the loop
    generate
        for (i = 0; i < RW_REG_COUNT; i = i + 1) begin : gen_priority_write_blocks// : module_instances
            // Instantiate the module here
            priority_write #(2) this_priority_write (
				.clk(clk),
				.rst_n(rst_n),
                .flags({spi_write_flag[i]&is_spi_write,sig_gen_flag[i]}),//flag from each module requesting a write
                .data_bits({spi_data,sig_gen_data[i*8+:8]}),//byte from the module requesting to be written
                .data_in(rw_data[i]),//old value of the register
                .data_out(rw_data[i])//new value of the register
            );
        end
    endgenerate
  
  //assign memory_frame_buffer={rw_data[7], rw_data[6], rw_data[5], rw_data[4], rw_data[3], rw_data[2], rw_data[1], rw_data[0]};
  //flatten 2d list to 1d
    /*  genvar i;
    generate
        for (i = 0; i < RW_REG_COUNT; i = i + 1) begin
            assign memory_frame_buffer[(i*8) +: 8] = rw_data[i];
        end
        for (i = 0; i < RO_REG_COUNT; i = i + 1) begin
            assign memory_frame_buffer[((i+RW_REG_COUNT)*8) +: 8] = ro_data[i];
        end
    endgenerate*/
	assign memory_frame_buffer={ro_flat,rw_flat};//MSbit to LSbit
  
  
  //genvar i;
	generate
		for (i = 0; i < RW_REG_COUNT; i = i + 1) begin : gen_flatten_rw
			//assign rw_data[i] = rw_flat[8*i + 7 -: 8];
			assign rw_flat[8*i + 7 -: 8] = rw_data[i];
		end
		for (i = 0; i < RO_REG_COUNT; i = i + 1) begin : gen_flatten_ro
			assign ro_flat[8*i + 7 -: 8] = ro_data[i];
		end
	endgenerate
  
  
    /*always @(posedge clk) begin
		if(!rst_n) begin
			ro_data[0][7:0]<=0;//TODO
		end else begin
			ro_data[0][7:0]<=8'hE5;//TODO
		end
	end*/
	assign ro_data[0][7:0]=8'hE5;
  
  lfsr_counter lfsr_counter_0(
    .clk(clk),         // Clock input
    .rst_n(rst_n&!is_counter_reset),       // Active-low reset
    .is_lfsr(is_lfsr),     // Mode control: 1 for LFSR, 0 for counter
	//.tap_index(tap_index),
    .out(counter)//,   // 16-bit output
	//.tap_output(tap_out)
  );
  
  charlie charlie_0(
  .clk(clk),      // clock
  .charlie_index(counter[5:0]),
  .frame_index(bi_frame_index),
  .is_mirror(is_bi_mirror),
    .memory_frame_buffer(memory_frame_buffer),
    .uio_out(bi_out),  // IOs: Output path
    .uio_oe(bi_en)
  );
  
  spi_slave #(
    RW_REG_COUNT,  // Number of read-write registers
    RO_REG_COUNT   // Number of read-only registers
)spi_slave_0  (
    .clk(clk),                  // System clock
    .rst_n(rst_n),                // Active-low reset
    .spi_cs(cs),                   // SPI chip select (active low)
    .spi_clk(sclk),                  // SPI clock
    .spi_mosi(mosi),                 // Master-Out Slave-In (data from master)
    .spi_miso(miso),                // Master-In Slave-Out (data to master)
	.rw_data(rw_flat),
    .ro_data(ro_flat), // Data for read-only registers
	.spi_address(spi_address),				//address of where to write data to
	.spi_data(spi_data),					//data byte ready for writing into memory
	.is_spi_write(is_spi_write)
);


signal_generator #(
    RW_REG_COUNT  // Number of input flags and data sets
) signal_generator_0 (
	.clk(clk),
	.trigger(trigger),
	.clk_div(counter[clk_tap_index]),
	.is_div_bypass(is_clk_div_bypass),//set to 1 to run sig gen at max speed (at speed of sys clock)
	.counter(counter),//for saving the timestamp of trigger events
	.rst_n(rst_n),
	.loop_mode(sig_gen_loop_mode),//0 is off, 1 is single, 2 is multi (once per trigger), 3 is loop
	.is_trigger_on_rising_edge(is_trigger_on_rising_edge),
	.is_trigger_on_falling_edge(is_trigger_on_falling_edge),
	.is_save_rising_timestamp(is_save_rising_timestamp),
	.is_save_falling_timestamp(is_save_falling_timestamp),
	.was_config(rw_flat),
	.is_config(sig_gen_data),//data reqeusted to be written to registers
	.is_update_flag(sig_gen_flag),//flag to indicate data is ready to be written
	.sig_gen_out(sig_gen_out),
	.is_running(is_sig_gen_run)
);

	wire [4*7-1:0] mega_mux={
							rw_data[{1'b0,asic_in}][6:0]&{7{sig_gen_out[0]}},//dimmable display
							is_clk_div_bypass?clk:counter[clk_tap_index],counter[clk_tap_index+8],sig_gen_out[3:0],is_sig_gen_run,//2 siggen
							rw_data[{1'b0,asic_in}][6:0],//1 decode
							asic_in,trigger,mosi,sclk//0 echo
							};
	assign asic_out=mega_mux[(mega_mux_index*7)+:7];//8th bit is reserved for miso
	//wire [2:0] _unused2=is_input_inverted[2:0];
 //wire _is_miso_inverted=rw_data[17][7];
  wire _unused = &{ena,uio_in,is_input_inverted[2:0]};//TODO

endmodule
