`timescale 1ns/1ps

module reader (
    input logic [31:0] mem_data,
    input logic [3:0] be_mask,
    input logic [2:0] f3,

    output logic [31:0] wb_data 
);

logic sign_extend;
assign sign_extend = ~f3[2];

logic [31:0] masked_data; // just a mask applied
logic [31:0] raw_data; // Data shifted according to instruction
// and then mem_data is the final output with sign extension

always_comb begin : mask_apply
    for (int i = 0; i < 4; i++) begin
        if (be_mask[i]) begin
            masked_data[(i*8)+:8] = mem_data[(i*8)+:8];
        end else begin
            masked_data[(i*8)+:8] = 8'h00;
        end
    end
end

always_comb begin : shift_data
    case (f3)
        3'b010 : raw_data = masked_data; // masked data is full word in that case

        3'b000, 3'b100: begin // LB, LBU
            case (be_mask)
                4'b0001: raw_data = masked_data;
                4'b0010: raw_data = masked_data >> 8;
                4'b0100: raw_data = masked_data >> 16;
                4'b1000: raw_data = masked_data >> 24;
            endcase
        end

        3'b001, 3'b101: begin // LH, LHU
            case (be_mask)
                4'b0011: raw_data = masked_data;
                4'b1100: raw_data = masked_data >> 16;
            endcase
        end
    endcase
end

always_comb begin : sign_extend_logic
    case (f3)
        // LW
        3'b010 : wb_data = raw_data;

        // LB, LBU
        3'b000, 3'b100: wb_data = sign_extend ? {{24{raw_data[7]}},raw_data[7:0]} : raw_data;

        // LH, LHU
        3'b001, 3'b101: wb_data = sign_extend ? {{16{raw_data[15]}},raw_data[15:0]} : raw_data;
    endcase
end
    
endmodule