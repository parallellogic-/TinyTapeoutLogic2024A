//write verilog code for a spi slave module.  There is a configurable (at compile time) number of read-write-able registers.  There is also accept a number of read-only registers, these are the higher address.    This module allows for multi-byte (streaming) reads and writes.  When passing the data into the module, flatten the list of 2D bytes into a 1D array (ie. no "[7:0]" in the module definition).  when reading from a read-only byte, store the entire byte before outputting one-bit-at-a-time.

module spi_slave #(
    parameter RW_REG_COUNT = 8,                 // Number of read-write registers
    parameter RO_REG_COUNT = 4                  // Number of read-only registers
)(
    input wire clk,                             // System clock
    input wire rst_n,                           // Active-low reset
    input wire spi_clk,                         // SPI clock
    input wire spi_mosi,                        // Master Out Slave In
    output reg spi_miso,                        // Master In Slave Out
    input wire spi_cs,                          // Chip Select (active low)
    output reg [RW_REG_COUNT*8-1:0] rw_data,    // Read-write registers
    input wire [(RO_REG_COUNT * 8)-1:0] ro_data // Flattened read-only data array
);

    always @(posedge clk) begin
		if(!rst_n) begin
			rw_data[8*0+7-:8]<=0;
			rw_data[8*1+7-:8]<=0;
			rw_data[8*2+7-:8]<=0;
			rw_data[8*3+7-:8]<=0;
			rw_data[8*4+7-:8]<=0;
			rw_data[8*5+7-:8]<=0;
			rw_data[8*6+7-:8]<=0;
			rw_data[8*7+7-:8]<=0;
			rw_data[8*8+7-:8]<=0;
			rw_data[8*9+7-:8]<=0;
			rw_data[8*10+7-:8]<=0;
			rw_data[8*11+7-:8]<=0;
		end else begin
			rw_data[8*0+7-:8]<=8'hFF;
			rw_data[8*1+7-:8]<=8'hFF;
			rw_data[8*2+7-:8]<=8'hFF;
			rw_data[8*3+7-:8]<=8'hFF;
			rw_data[8*4+7-:8]<=8'hFF;
			rw_data[8*5+7-:8]<=8'hFF;
			rw_data[8*6+7-:8]<=8'hFF;
			rw_data[8*7+7-:8]<=8'hFF;
			rw_data[8*8+7-:8]<=8'hFF;
			rw_data[8*9+7-:8]<=8'hFF;
			rw_data[8*10+7-:8]<=8'hFF;
			rw_data[8*11+7-:8]<=8'hFF;
		end
	end
	
	assign rw_data=0;
	assign spi_miso=1;
	
	wire _unused = &{clk, rst_n, spi_clk,spi_mosi,spi_cs,ro_data};

endmodule
