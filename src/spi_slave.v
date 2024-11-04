//write verilog code for a spi slave module.  There is a configurable (at compile time) number of read-write-able registers.  There is also accept a number of read-only registers, these are the higher address.    This module allows for multi-byte (streaming) reads and writes.  When passing the data into the module, flatten the list of 2D bytes into a 1D array (ie. no "[7:0]" in the module definition).  when reading from a read-only byte, store the entire byte before outputting one-bit-at-a-time.

module spi_slave #(
    parameter RW_REG_COUNT = 12,                 // Number of read-write registers
    parameter RO_REG_COUNT = 1                  // Number of read-only registers
)(
    input wire clk,                             // System clock
    input wire rst_n,                           // Active-low reset
    input wire spi_cs,                          // Chip Select (active low)
    input wire spi_clk,                         // SPI clock
    input wire spi_mosi,                        // Master Out Slave In
    output reg spi_miso,                        // Master In Slave Out
    output reg [RW_REG_COUNT*8-1:0] rw_data,    // Read-write registers
    input wire [(RO_REG_COUNT * 8)-1:0] ro_data // Flattened read-only data array
);

	
	//assign spi_miso=1'b1;//TODO
	/*wire _unused = &{clk, rst_n, spi_clk,spi_mosi,spi_cs,ro_data};//TODO
	
    always @(posedge clk) begin
		if(!rst_n) begin
			 for (int i = 0; i < RW_REG_COUNT; i = i + 1) begin
				rw_data[8*i +: 8] <= 8'b0; // Reset to 0
			end
			spi_miso <= 1'b1;
		end else begin
			for (int i = 0; i < RW_REG_COUNT; i = i + 1) begin
				rw_data[8*i +: 8] <= 8'hFF; // Set to 0xFF
			end
			spi_miso <= 1'b1;
		end
	end*/
	
	
	    // Internal signals
    reg [7:0] shift_reg;                       // 8-bit shift register for SPI data
    reg [2:0] bit_cnt;                         // Bit counter for SPI byte
    reg [7:0] addr_reg;                        // Register to store register address
    reg [7:0] data_reg;                        // Data register for incoming data
    reg rw_mode;                               // Read (0) or Write (1) mode
    //reg addr_valid;                            // Address validity flag for streaming
    reg [7:0] miso_buffer;                     // Buffer to hold byte for SPI MISO
	wire spi_clk_rising_edge;

	reg spi_clk_prev;
	assign spi_clk_rising_edge=spi_clk & !spi_clk_prev;//rising edge (WAS 0, IS 1)

    // SPI FSM states
    typedef enum reg [1:0] {
        IDLE,
        ADDR_PHASE,
        DATA_PHASE
    } state_t;

    state_t state;                             // Current FSM state

    // SPI FSM
    always @(posedge clk) begin
		if (!rst_n) begin
			// Reset all internal signals
			state <= IDLE;
			bit_cnt <= 0;
			//addr_valid <= 0;
			spi_miso <= 1'b0;
			rw_mode <= 1'b0;
			addr_reg <= 8'b0;
			shift_reg <= 8'b0;
			miso_buffer <= 8'b0;
			spi_clk_prev<=1'b0;
			 for (int i = 0; i < RW_REG_COUNT; i = i + 1) begin
				rw_data[8*i +: 8] <= 8'h00;//8'hFF; // Reset to 0 on boot
			end
		end else if(spi_clk_rising_edge) begin
			if (!spi_cs) begin  // SPI active (CS low)
				case (state)
					// IDLE state: waiting for address byte
					IDLE: begin
						if (bit_cnt == 7) begin
							addr_reg <= {shift_reg[6:0], spi_mosi};//MSB first
							rw_mode <= shift_reg[7];  // MSB determines read/write
							state <= ADDR_PHASE;
							bit_cnt <= 0;
						end else begin
							shift_reg <= {shift_reg[6:0], spi_mosi};
							bit_cnt <= bit_cnt + 1;
						end
					end

					// Address phase: determining read or write mode and loading data
					ADDR_PHASE: begin
						if (rw_mode == 1'b0) begin  // Read mode
							if (addr_reg < RW_REG_COUNT) begin
								miso_buffer <= rw_data[addr_reg*8+7-:8];
							end else if (addr_reg < RW_REG_COUNT + RO_REG_COUNT) begin
								miso_buffer <= ro_data[(addr_reg - RW_REG_COUNT) * 8 + 7 -: 8];
							end else begin
								miso_buffer <= 8'hFF; // Invalid address for read
							end
							state <= DATA_PHASE;
						end else begin  // Write mode
							//addr_valid <= 1;
							data_reg <= 8'b0;
							state <= DATA_PHASE;
						end
						bit_cnt <= 0;
					end

					// Data phase for streaming read/write
					DATA_PHASE: begin
						if (rw_mode == 1'b0) begin  // Read operation
							spi_miso <= miso_buffer[7];
							miso_buffer <= {miso_buffer[6:0], 1'b0};
							if (bit_cnt == 7) begin
								addr_reg <= addr_reg + 1;  // Increment for streaming
								if (addr_reg < RW_REG_COUNT) begin
									miso_buffer <= rw_data[addr_reg*8+7-:8];
								end else if (addr_reg < RW_REG_COUNT + RO_REG_COUNT) begin
									miso_buffer <= ro_data[(addr_reg - RW_REG_COUNT) * 8 +7 -: 8];
								end else begin
									miso_buffer <= 8'hFF;
								end
								bit_cnt <= 0;
							end else begin
								bit_cnt <= bit_cnt + 1;
							end
						end else if (rw_mode == 1'b1) begin// && addr_valid) begin
							data_reg <= {data_reg[6:0], spi_mosi};
							if (bit_cnt == 7) begin
								if (addr_reg < RW_REG_COUNT) begin
									rw_data[addr_reg*8+7-:8] <= data_reg;  // Write completed byte
									addr_reg <= addr_reg + 1;  // Increment for streaming
								end
								bit_cnt <= 0;
							end else begin
								bit_cnt <= bit_cnt + 1;
							end
						end
					end

					default: state <= IDLE;
				endcase
			end else begin
				// Reset FSM when CS is high (inactive)
				state <= IDLE;
				bit_cnt <= 0;
				//addr_valid <= 0;
			end
		end
		spi_clk_prev<=spi_clk;
    end
endmodule
