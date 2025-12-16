/*
* HOLY CORE MULTIPLY/DIVIDE UNIT
*
* BRH 12/24
*
* Separate unit for M extension operations.
* - Multiplication: Single-cycle (DSP inference)
* - Division: Multi-cycle iterative (32 cycles) using restoring algorithm
*
* Handshake protocol:
*   - req_valid: Requester asserts when operands are ready
*   - res_valid: MDU asserts when result is ready
*   - res_ack:   Requester acknowledges result, MDU returns to IDLE
*/

`timescale 1ns/1ps
import holy_core_pkg::*;

module mul_div_unit (
    input  logic        clk,
    input  logic        rst_n,

    // Operands
    input  logic [31:0] src1,
    input  logic [31:0] src2,
    input  alu_control_t     mdu_control,

    // Handshake
    input  logic        req_valid,
    input  logic        res_ack,
    output logic        res_valid,

    // Result
    output logic [31:0] mdu_result
);

    // =========================================================================
    // State Machine
    // =========================================================================

    alu_state_t state, next_state;

    always_ff @(posedge clk) begin
        if (!rst_n)
            state <= ALU_IDLE;
        else
            state <= next_state;
    end

    // =========================================================================
    // Operation Type Detection
    // =========================================================================

    wire is_mul_op = (mdu_control == ALU_MUL)    ||
                     (mdu_control == ALU_MULH)   ||
                     (mdu_control == ALU_MULHSU) ||
                     (mdu_control == ALU_MULHU);

    wire is_div_op = (mdu_control == ALU_DIV)  ||
                     (mdu_control == ALU_DIVU) ||
                     (mdu_control == ALU_REM)  ||
                     (mdu_control == ALU_REMU);

    wire is_signed_op = (mdu_control == ALU_DIV) || (mdu_control == ALU_REM);
    wire is_rem_op    = (mdu_control == ALU_REM) || (mdu_control == ALU_REMU);

    // =========================================================================
    // Multiplication (Single-Cycle, DSP Inference)
    // =========================================================================

    // Sign-extended operands for signed multiplication
    wire signed [32:0] mul_src1_signed   = {src1[31], src1};
    wire signed [32:0] mul_src2_signed   = {src2[31], src2};
    wire        [32:0] mul_src2_unsigned = {1'b0, src2};

    // 64-bit multiplication results
    wire signed [65:0] mul_ss = mul_src1_signed * mul_src2_signed;
    wire signed [65:0] mul_su = mul_src1_signed * $signed(mul_src2_unsigned);
    wire        [63:0] mul_uu = src1 * src2;

    // Multiplication result mux
    logic [31:0] mul_result;
    always_comb begin
        case (mdu_control)
            ALU_MUL:    mul_result = mul_uu[31:0];
            ALU_MULH:   mul_result = mul_ss[63:32];
            ALU_MULHSU: mul_result = mul_su[63:32];
            ALU_MULHU:  mul_result = mul_uu[63:32];
            default:    mul_result = 32'd0;
        endcase
    end

    // =========================================================================
    // Division Logic (Restoring Algorithm)
    // =========================================================================

    // Division registers
    // quotient holds dividend initially, then shifts left with result bits entering LSB
    // remainder accumulates the partial remainder
    logic [31:0] divisor_reg;       // Latched divisor (absolute value)
    logic [31:0] quotient;          // Shifts left; quotient bits enter from right
    logic [31:0] remainder;         // Working remainder
    logic [5:0]  div_counter;       // Iteration counter (0-31)

    // Sign tracking for result correction
    logic dividend_neg;             // Original dividend was negative
    logic divisor_neg;              // Original divisor was negative
    logic div_by_zero;              // Division by zero flag
    logic overflow;                 // Signed overflow: -2^31 / -1

    // Latched operation type (capture at start)
    logic is_signed_op_reg;
    logic is_rem_op_reg;

    // Latched original dividend for div-by-zero case
    logic [31:0] dividend_orig;

    // Absolute value computation
    wire [31:0] src1_abs = (is_signed_op && src1[31]) ? (~src1 + 1'b1) : src1;
    wire [31:0] src2_abs = (is_signed_op && src2[31]) ? (~src2 + 1'b1) : src2;

    // Division iteration logic (restoring division)
    // Each cycle: shift {remainder, quotient} left by 1, then try subtract divisor
    wire [32:0] remainder_shifted = {remainder[31:0], quotient[31]};
    wire [32:0] trial_sub = remainder_shifted - {1'b0, divisor_reg};

    // If subtraction doesn't borrow (MSB=0), it succeeded
    wire sub_ok = ~trial_sub[32];

    // Final quotient and remainder with sign correction
    logic [31:0] quotient_corrected;
    logic [31:0] remainder_corrected;

    always_comb begin
        // Sign correction for quotient: negate if operand signs differ
        if (dividend_neg ^ divisor_neg)
            quotient_corrected = ~quotient + 1'b1;
        else
            quotient_corrected = quotient;

        // Sign correction for remainder: same sign as dividend
        if (dividend_neg)
            remainder_corrected = ~remainder + 1'b1;
        else
            remainder_corrected = remainder;
    end

    // Division result considering special cases
    logic [31:0] div_result;
    logic [31:0] rem_result;

    always_comb begin
        if (div_by_zero) begin
            // RISC-V spec: div by zero returns all 1s, rem returns dividend
            div_result = 32'hFFFF_FFFF;
            rem_result = dividend_orig;
        end else if (overflow) begin
            // RISC-V spec: signed overflow returns -2^31 for div, 0 for rem
            div_result = 32'h8000_0000;
            rem_result = 32'd0;
        end else begin
            div_result = quotient_corrected;
            rem_result = remainder_corrected;
        end
    end

    // =========================================================================
    // Division Datapath Sequential Logic (NOTA : state transition is not here)
    // =========================================================================

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            divisor_reg      <= 32'd0;
            quotient         <= 32'd0;
            remainder        <= 32'd0;
            div_counter      <= 6'd0;
            dividend_neg     <= 1'b0;
            divisor_neg      <= 1'b0;
            div_by_zero      <= 1'b0;
            overflow         <= 1'b0;
            is_signed_op_reg <= 1'b0;
            is_rem_op_reg    <= 1'b0;
            dividend_orig    <= 32'd0;
        end else begin
            case (state)
                ALU_IDLE: begin
                    if (req_valid && is_div_op) begin
                        // Initialize div: latch sources
                        divisor_reg      <= src2_abs;
                        quotient         <= src1_abs;
                        // reset counters
                        remainder        <= 32'd0;
                        div_counter      <= 6'd0;
                        // detect edge cases according to RV32M specs
                        div_by_zero      <= (src2 == 32'd0);
                        overflow         <= is_signed_op && 
                                           (src1 == 32'h8000_0000) && 
                                           (src2 == 32'hFFFF_FFFF);
                        // latch onto metadata
                        dividend_neg     <= is_signed_op && src1[31];
                        divisor_neg      <= is_signed_op && src2[31];
                        is_signed_op_reg <= is_signed_op;
                        is_rem_op_reg    <= is_rem_op;
                        dividend_orig    <= src1;
                    end
                end

                ALU_BUSY: begin
                    if (!div_by_zero && !overflow) begin
                        // Restoring division iteration:
                        // 1. Shift {remainder, quotient} left by 1
                        // 2. Subtract divisor from new remainder
                        // 3. If result >= 0: keep subtraction, quotient bit = 1
                        //    If result < 0:  restore (use shifted), quotient bit = 0
                        if (sub_ok) begin
                            remainder <= trial_sub[31:0];
                            quotient  <= {quotient[30:0], 1'b1};
                        end else begin
                            remainder <= remainder_shifted[31:0];
                            quotient  <= {quotient[30:0], 1'b0};
                        end
                        div_counter <= div_counter + 1'b1;
                    end
                end

                default: ;
            endcase
        end
    end

    // =========================================================================
    // State Machine Logic
    // =========================================================================

    always_comb begin
        next_state = state;

        case (state)
            ALU_IDLE: begin
                if (req_valid) begin
                    if (is_mul_op)
                        next_state = ALU_DONE;  // MUL is single-cycle
                    else if (is_div_op)
                        next_state = ALU_BUSY;  // DIV needs iterations
                end
            end

            ALU_BUSY: begin
                // Division complete after 32 iterations, or immediate for special cases
                if (div_by_zero || overflow || div_counter == 6'd31)
                    next_state = ALU_DONE;
            end

            ALU_DONE: begin
                if (res_ack)
                    next_state = ALU_IDLE;
            end

            default: next_state = ALU_IDLE;
        endcase
    end

    // =========================================================================
    // Output Logic
    // =========================================================================

    assign res_valid = (state == ALU_DONE);

    always_comb begin
        case (state)
            ALU_DONE: begin
                if (is_mul_op)
                    mdu_result = mul_result;
                else if (is_rem_op_reg)
                    mdu_result = rem_result;
                else
                    mdu_result = div_result;
            end
            default: mdu_result = 32'd0;
        endcase
    end

endmodule