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
  wire is_lfsr;
  wire [3:0] tap_index;
  wire [3:0] tap_out;
  wire [RW_REG_COUNT*8-1:0] rw_flat;
  wire [RO_REG_COUNT*8-1:0] ro_flat;
  
  assign is_lfsr=0;//TODO clock mode
  assign tap_index=0;//TODO
  
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
	assign memory_frame_buffer={ro_flat,rw_flat};
  
  
  genvar i;
	generate
		for (i = 0; i < RW_REG_COUNT; i = i + 1) begin
			assign rw_data[i] = rw_flat[8*i + 7 -: 8];
		end
		for (i = 0; i < RO_REG_COUNT; i = i + 1) begin
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
    .rst_n(rst_n),       // Active-low reset
    .is_lfsr(is_lfsr),     // Mode control: 1 for LFSR, 0 for counter
	.tap_index(tap_index),
    .out(counter),   // 16-bit output
	.tap_output(tap_out)
  );
  
  charlie charlie_0(
  .clk(clk),      // clock
  .charlie_index(counter[5:0]),
  .frame_index(rw_data[19][1:0]),//TODO
  .is_mirror(rw_data[19][2]),
    .memory_frame_buffer(memory_frame_buffer),
    .uio_out(uio_out),  // IOs: Output path
    .uio_oe(uio_oe)
  );
  
  spi_slave #(
    RW_REG_COUNT,  // Number of read-write registers
    RO_REG_COUNT   // Number of read-only registers
)spi_slave_0  (
    .clk(clk),                  // System clock
    .rst_n(rst_n),                // Active-low reset
    .spi_cs(ui_in[0]),                   // SPI chip select (active low)
    .spi_clk(ui_in[1]),                  // SPI clock
    .spi_mosi(ui_in[2]),                 // Master-Out Slave-In (data from master)
    .spi_miso(uo_out[7]),                // Master-In Slave-Out (data to master)
	.rw_data(rw_flat),
    .ro_data(ro_flat) // Data for read-only registers
);
	//assign rw_flat=1;
  //assign uo_out[0]=1'b1;//TODO
  assign uo_out[5:1] =0;//TODO
  assign uo_out[6]=ui_in[7];//counter[0];
  assign uo_out[0]=^counter;//TODO //python[0]
  wire _unused = &{ena, clk, rst_n, 1'b0,uio_in,ui_in,tap_out,counter,rw_flat,ro_flat};//TODO

endmodule
