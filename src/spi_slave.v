//write verilog code for a spi slave MODE 0 module.  The lower registers are read-write-able (RW_REG_COUNT) while the higher are read-only (RO_REG_COUNT).   The module input/output includes: input wire clk, input wire spi_clk, output reg [RW_REG_COUNT*8-1:0] rw_data, input wire [(RO_REG_COUNT * 8)-1:0] ro_data.  Use always @(posedge clk).  Buffer the byte being read or written.

module spi_slave #(
    parameter RW_REG_COUNT = 23,                 // Number of read-write registers
    parameter RO_REG_COUNT = 1                  // Number of read-only registers
)(
    input wire clk,                             // System clock
    input wire rst_n,                           // Active-low reset
    input wire spi_cs,                          // Chip Select (active low)
    input wire spi_clk,                         // SPI clock
    input wire spi_mosi,                        // Master Out Slave In
    output reg spi_miso,                        // Master In Slave Out
    input wire [RW_REG_COUNT*8-1:0] rw_data,    // Read-write registers
    input wire [(RO_REG_COUNT * 8)-1:0] ro_data,// Flattened read-only data array
	output wire [4:0] spi_address,				//address of where to write data to
	output wire [7:0] spi_data,					//data byte ready for writing into memory
	output wire is_spi_write					//flag to indicate data is on the output wire to be written
);
	
    reg [2:0] bit_cnt;                         // Bit counter for SPI byte
    reg is_mosi;                               // Read mosi (0) or Write miso(1) mode
	wire spi_clk_rising_edge,spi_clk_falling_edge; //SPI Mode 0 state machine
	reg [4:0] reg_address;//address being read/written to
	reg [7:0] reg_data;//data being written to that address or being read out

	reg spi_clk_prev;//for spi_clk_rising_edge,spi_clk_falling_edg state machine
	assign spi_clk_rising_edge=spi_clk & !spi_clk_prev;//rising edge (WAS 0, IS 1), read
	assign spi_clk_falling_edge=!spi_clk & spi_clk_prev;//falling edge (WAS 1, IS 0), change data (write)

	reg is_data_phase;//if receiving address (0), or interacting with data byte (1)
	
	wire [7:0] next_shift_reg={reg_data[6:0], spi_mosi};//shifting master data into slave\
	
	assign is_spi_write=(!spi_cs)&spi_clk_rising_edge&is_data_phase&is_mosi&(bit_cnt==7);
	assign spi_data=next_shift_reg;
	assign spi_address=reg_address[4:0];//TODO, use $bits(param)
	
    // SPI FSM
    always @(posedge clk) begin
		if (!rst_n) begin
			// Reset all internal signals
			is_data_phase <= 1'b0;
			bit_cnt <= 0;
			spi_miso <= 1'b0;
			is_mosi <= 1'b0;
			spi_clk_prev<=1'b0;
			reg_address<=5'b0;
			reg_data<=8'b0;
			//for (int i = 0; i < RW_REG_COUNT; i = i + 1) begin
			//	rw_data[8*i +: 8] <= 8'h00; // Reset to const on boot
			//end
		end else begin
			spi_clk_prev<=spi_clk;
			if(!spi_cs) begin
				if(spi_clk_rising_edge) begin
					if(!is_data_phase) begin
						if (bit_cnt == 7) begin//done receiving one byte
							is_mosi <= next_shift_reg[7];  // MSB determines read/write
							is_data_phase <= 1'b1;
							if (next_shift_reg[7]) begin  //mosi write mode
								reg_address <= next_shift_reg[4:0];//{1'b0,next_shift_reg[6:0]};//save the address for later so it's clear where to save the data byte to in the register map
							end else begin //miso read mode
								if (next_shift_reg[6:0] < RW_REG_COUNT) begin;
									reg_data <= rw_data[next_shift_reg[6:0]*8+7-:8];
								end else if (next_shift_reg[6:0] < RW_REG_COUNT + RO_REG_COUNT) begin
									reg_data <= ro_data[(next_shift_reg[6:0] - RW_REG_COUNT) * 8 + 7-: 8];
								end else begin
									reg_data <= 8'hFF; // Invalid address for read
								end
							end
						end else begin
							//in the middle of receiving a byte, store the bit
							reg_data <= next_shift_reg;//MSB first
						end
						bit_cnt <= bit_cnt + 1;
					end else begin//have the address in-hand, now do the data byte handling
						if (is_mosi) begin  // MOSI write operation (device reads master-to-slave on clk rising)
							if(bit_cnt==7) begin
								//rw_data[reg_address*8+7-:8] <= next_shift_reg; //moved to priority write module
							end
							reg_data <= next_shift_reg;
							bit_cnt <= bit_cnt + 1;
						end 
					end
				end else if(spi_clk_falling_edge) begin
					if(is_data_phase && !is_mosi) begin//MISO slave send data out to master, change on falling edge
						spi_miso <= reg_data[7];
						reg_data <= next_shift_reg;
					end
				end
			end else begin
				is_data_phase<=1'b0;
				bit_cnt <= 0;
			end
		end
	end
endmodule
