//`ifndef CHARLIE_V  // Check if MY_MODULE_V is not defined
//`define CHARLIE_V  // Define MY_MODULE_V to prevent re-inclusion
//seems like simulation double-imports, so just skip second import

parameter FRAME_BUFFER_COUNT= 3;
parameter CHARLIE_ROWS= 8*FRAME_BUFFER_COUNT;

module charlie (
  input  wire       clk,      // clock
  input wire[5:0] charlie_index,
  input wire[1:0] frame_index,
  input wire [CHARLIE_ROWS*8-1:0] memory_frame_buffer,
  input wire is_mirror,//mirror left/right
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
  wire [7:0] memory [0:CHARLIE_ROWS-1];
  reg [7:0] uio_out_reg;
  reg [7:0] uio_oe_reg;
  
  assign uio_out=uio_out_reg;
  assign uio_oe=uio_oe_reg;
  
  genvar i;
	generate
		for (i = 0; i < CHARLIE_ROWS; i = i + 1) begin
			assign memory[i][7:0] = memory_frame_buffer[8*i + 7 -: 8];
		end
	endgenerate
  
  assign col_index=charlie_index[2:0];
  assign row_index=charlie_index[5:3];
  
  //assign is_diagonal = row_index == col_index;//if on diagonal, do nothing
  assign is_on=memory[row_index+8*frame_index][col_index^{is_mirror,is_mirror,is_mirror}]&(frame_index!=2'b11);//fetch state of this LED
  
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