// by brh
//
// ...
//
// bruh

module prim_clock_inv #(
    parameter logic HasScanMode = 1'b0,
    parameter logic NoFpgaBufG  = 1'b0
)(
    input  logic clk_i,
    output logic clk_no,
    input  logic scanmode_i = 1'b0
);

    logic clk_int;

    // Optionally bypass inversion in scan mode
    generate
        if (HasScanMode) begin
            always_comb begin
                if (scanmode_i)
                    clk_int = clk_i;      // pass through during scan
                else
                    clk_int = ~clk_i;     // invert normally
            end
        end else begin
            always_comb clk_int = ~clk_i;  // always invert
        end
    endgenerate

    // Optionally remove FPGA buffer (just pass through)
    assign clk_no = (NoFpgaBufG) ? clk_int : clk_int; // placeholder for FPGA-specific buffer

endmodule
