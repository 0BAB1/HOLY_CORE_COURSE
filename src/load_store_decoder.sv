`timescale 1ns/1ps

module load_store_decoder (
    input logic [31:0] alu_result_address,
    input logic [2:0] f3,
    output logic [3:0] byte_enable
);

logic [1:0] offset;

assign offset = alu_result_address[1:0];

always_comb begin
    case (f3)
        3'b000: begin // SB
            case (offset)
                2'b00: byte_enable = 4'b0001;
                2'b01: byte_enable = 4'b0010;
                2'b10: byte_enable = 4'b0100;
                2'b11: byte_enable = 4'b1000;
                default: byte_enable = 4'b0000;
            endcase
        end
        
        3'b010: begin // SW
            byte_enable = (offset == 2'b00) ? 4'b1111 : 4'b0000;
        end

        default: begin
            byte_enable = 4'b0000; // No operation for unsupported types
        end
    endcase
end

endmodule