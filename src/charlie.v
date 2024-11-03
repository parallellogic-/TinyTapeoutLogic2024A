//`ifndef CHARLIE_V  // Check if MY_MODULE_V is not defined
//`define CHARLIE_V  // Define MY_MODULE_V to prevent re-inclusion
//seems like simulation double-imports, so just skip second import

module charlie (
  input  wire       clk,      // clock
  input wire[5:0] charlie_index,
  input wire [63:0] memory_frame_buffer,
    //input  wire       rst_n,     // reset_n - low to reset
	//input wire is_enabled,
  output wire [7:0] uio_out,  // IOs: Output path
  output wire [7:0] uio_oe   // IOs: Enable path (active high: 0=input, 1=output)
);
  
//reg[5:0] charlie_index;
wire [2:0] row_index;
  wire [2:0] col_index;
  //wire is_diagonal;
  wire is_on;
  wire [7:0] memory [0:7];
  reg [7:0] uio_out_reg;
  reg [7:0] uio_oe_reg;
  
  assign uio_out=uio_out_reg;//8'h5C;//
  assign uio_oe=uio_oe_reg;
  
  assign memory[0] = memory_frame_buffer[7:0];
  assign memory[1] = memory_frame_buffer[15:8];
  assign memory[2] = memory_frame_buffer[23:16];
  assign memory[3] = memory_frame_buffer[31:24];
  assign memory[4] = memory_frame_buffer[39:32];
  assign memory[5] = memory_frame_buffer[47:40];
  assign memory[6] = memory_frame_buffer[55:48];
  assign memory[7] = memory_frame_buffer[63:56];
  
  assign col_index=charlie_index[2:0];
  assign row_index=charlie_index[5:3];
  
  //assign is_diagonal = row_index == col_index;//if on diagonal, do nothing
  assign is_on=memory[row_index][col_index];//fetch state of this LED
  
  always @(posedge clk)
  begin
    //if(!rst_n) begin
	//	charlie_index <= 6'b0;
	//end else begin
	//	charlie_index <= charlie_index+1;
	//end
    uio_oe_reg<=8'b0;
    uio_out_reg<=8'b0;
    //if(!is_diagonal && is_on) begin
      uio_oe_reg[row_index]<=is_on;
      uio_oe_reg[col_index]<=is_on;
      
      uio_out_reg[row_index]<=1'b1;
      uio_out_reg[col_index]<=1'b0;
   // end
  end
  
endmodule

//`endif