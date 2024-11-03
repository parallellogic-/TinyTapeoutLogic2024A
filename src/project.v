/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none
`include "charlie.v"
`include "spi_slave.v"

module tt_um_parallellogic_top (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  parameter MEMORY_COUNT=12;
  reg [7:0] memory [0:(MEMORY_COUNT-1)];
  wire is_frame_done;
  wire [5:0] frame_done_index;
  wire [(8*8-1):0] memory_frame_buffer;//flatten to work with yosys expectations of 1D lists
  
  assign frame_done_index={memory[5][5],memory[4][4],memory[3][3],memory[2][2],memory[1][1],memory[0][0]};
  assign memory_frame_buffer={memory[7], memory[6], memory[5], memory[4], memory[3], memory[2], memory[1], memory[0]};
  
  always @(posedge clk)
  begin
    if(!rst_n) begin
      memory[0]<=8'b0;
      memory[1]<=8'b0;
      memory[2]<=8'b0;
      memory[3]<=8'b0;
      memory[4]<=8'b0;
      memory[5]<=8'b0;
      memory[6]<=8'b0;
      memory[7]<=8'b0;
      memory[8]<=8'b0;
      memory[9]<=8'b0;
      memory[10]<=8'b0;
      memory[11]<=8'b0;
     
    end
  end
  
  charlie cha(
  clk,      // clock
    memory_frame_buffer,
    frame_done_index,
    uio_out,  // IOs: Output path
    uio_oe,
    is_frame_done
  );
  
  
  assign uo_out =8'b0;
  
  wire _unused = &{ena, clk, rst_n, 1'b0,uio_in,is_frame_done,ui_in};

endmodule
