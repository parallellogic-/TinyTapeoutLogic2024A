//give me verilog code for a priority_write module.  The module will accept a parameterized INPUT_COUNT.  There will be INPUT_COUNT flags, and INPUT_COUNT*8 data_bits.  THe module checks if the first flag is 1, and if so outputs the 8 data bits associated with that flag.  If the first flag is 0, then it checks the next flag and outputs those 8 bits if that flag is 1, and so on.  IF no flag is raised, the prior value of the data register is output.  DO not clk or register

module priority_write #(
    parameter INPUT_COUNT = 4  // Number of input flags and data sets
) (
	input wire clk,
	input wire rst_n,
    input wire [INPUT_COUNT-1:0] flags,             // Array of flags
    input wire [(INPUT_COUNT*8)-1:0] data_bits,     // Concatenated 8-bit data inputs
    input wire [7:0] data_in,                       // Input to hold previous data_out value
    output reg [7:0] data_out                      // 8-bit output (wire type)
);

    // Function to get the highest-priority active data
    /*function [7:0] get_priority_data;
        input [INPUT_COUNT-1:0] flags;
        input [(INPUT_COUNT*8)-1:0] data_bits;
        integer i;
        begin
            get_priority_data = data_in;  // Default to data_in if no flags are active
            for (i = 0; i < INPUT_COUNT; i = i + 1) begin
                if (flags[i]) begin
                    get_priority_data = data_bits[(i*8) +: 8]; // Select data associated with the first active flag
                    disable for;  // Stop checking further flags once an active flag is found
                end
            end
        end
    endfunction*/
	
	integer i;
    always @(posedge clk) begin
		if(!rst_n) begin
			data_out <= 8'b0;
		end else begin
			data_out <= data_in; // Default output if no flag is set
			for (i = 0; i < INPUT_COUNT; i = i + 1) begin
				if (flags[i]) begin
					data_out <= data_bits[(i*8) +: 8]; // Extract and output 8 bits for the first active flag
				end
			end
		end
    end

    // Assign the result of the function to data_out
    //assign data_out = get_priority_data(flags, data_bits);

endmodule