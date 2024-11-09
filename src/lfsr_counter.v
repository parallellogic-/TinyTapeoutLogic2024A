//give me verilog code for a combined 32-bit clock and lfsr.  if is_lfsr is 1, then the 32-bit register behaves like a lfsr.  if 0, then the counter counts up.  on !rst_n, resets to all 1's.

module lfsr_counter (
    input wire clk,           // Clock input
    input wire rst_n,         // Active-low reset
    input wire is_lfsr,       // Mode control: 1 for LFSR, 0 for counter
    //input wire [3:0] tap_index,       // Mode control: 1 for LFSR, 0 for counter
    output reg [31:0] out//,     // 32-bit output
    //output wire [3:0] tap_output     // 32-bit output
);

    // Polynomial: x^32 + x^22 + x^2 + x + 1 (0x80200003)
    wire feedback = out[31] ^ out[21] ^ out[1] ^ out[0];
	//assign tap_output = out[tap_index+3-:4];

    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset to all 1's on active-low reset
            out <= is_lfsr?32'hFFFFFFFF:32'h0;
        end else begin
            if (is_lfsr) begin
                // LFSR mode: shift and apply feedback
                out <= {out[30:0], feedback};
            end else begin
                // Counter mode: increment by 1
                out <= out + 1;
            end
        end
    end

endmodule
