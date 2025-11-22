/** Simple Core Local INTerrupt Controller
*
*   Author : BRH
*   Project : Holy Core SoC & Software edition
*   Description : A CLINT for the HOLY CORE Project.
*                 Aims at simplicity *over all* (code & use).
*                 Supports AXI LITE. Meant for single
*                 core 32 bits riscv SoCs. Sync reset.
*                 Runs on a SINGLE clock domain.
*                 mtime is READ ONLY.
*
*   Created 07/25
*/

// todo : add AXI error on wong address for write request
// instead of a simple tb display (B channel resp)
// and same for MTIME writes attempts !

import holy_core_pkg::*;

module holy_clint #(
    parameter BASE_ADDR = 0
) (
    input  logic                  clk,
    input  logic                  rst_n,

    // AXI Lite slave interface (simplified)
    axi_lite_if.slave s_axi_lite,

    // Interrupt output to core
    output logic                 timer_irq,
    output logic                 soft_irq
);

    // REGISTERS MAP ADDRESSES
    // WARNING ! FIXED FOX 32BIT CPU USE !
    // WILL NOT WORK FOR A 64 BIT DATA BUS.
    // ALIGNED READ ONLY AS WELL !
    // does that seem like a problem ? idc.
    localparam MSIP = 32'd0;
    localparam MTIME_CMP_LOW = 32'h4000;
    localparam MTIME_CMP_HIGH = 32'h4004;
    localparam MTIME_LOW = 32'hBFF8;
    localparam MTIME_HIGH = 32'hBFFC;

    // Registers
    logic [63:0] timer, timer_next;
    logic [63:0] timercmp, timercmp_next;
    logic [31:0] msip, msip_next;

    always_ff @(posedge clk) begin 
        if(~rst_n)begin
            timer <= 64'd0;
            /*
            We init timer cmp to max possible
            value to avoid a timer itr straight on
            reset release.
            */
            timercmp <= 64'hFFFFFFFFFFFFFFFF;
            msip <= 32'b0;
        end else begin
            timer <= timer_next;
            timercmp <= timercmp_next;
            msip <= msip_next;
        end
    end

    /**
    *   CONTROLLER STATE MACHINE LOGIC
    */

    // Axi lite states
    axi_state_slave_t state, next_state;
    logic [31:0] awaddr, awaddr_next;
    logic [31:0] araddr, araddr_next;

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            state <= SLAVE_IDLE;
            awaddr <= 0;
            araddr <= 0;
        end else begin
            state <= next_state;
            awaddr <= awaddr_next;
            araddr <= araddr_next;
        end
    end

    always_comb begin : axi_lite_fsm
        // stats & registers
        next_state = state;
        awaddr_next = awaddr;
        araddr_next = araddr;

        // DEFAULT REG VALUES ASSIGNS
        timer_next = timer + 64'b1;
        timercmp_next = timercmp;
        msip_next = msip;

        // AXI LITE DEFAULT
        s_axi_lite.awready = 1'b0;
        s_axi_lite.wready = 1'b0;
        s_axi_lite.bresp = 2'b00;
        s_axi_lite.bvalid = 1'b0;
        s_axi_lite.arready = 1'b0;
        s_axi_lite.rdata = 32'd0;
        s_axi_lite.rvalid = 1'b0;
        s_axi_lite.rresp = 2'b00;

        case (state)
            SLAVE_IDLE: begin
                s_axi_lite.awready = 1'b1;
                s_axi_lite.arready = 1'b1;

                if(s_axi_lite.arvalid)begin
                    next_state = LITE_SENDING_READ_DATA;
                    araddr_next = s_axi_lite.araddr - BASE_ADDR;
                end

                if(s_axi_lite.awvalid)begin
                    next_state = LITE_RECEIVING_WRITE_DATA;
                    awaddr_next = s_axi_lite.awaddr - BASE_ADDR;
                end
            end

            LITE_SENDING_READ_DATA: begin
                s_axi_lite.rvalid = 1'b1;

                // Set rdata
                case(araddr)
                    MSIP:begin
                        s_axi_lite.rresp = 2'b00;
                        s_axi_lite.rdata = msip;
                    end

                    MTIME_CMP_LOW: begin
                        s_axi_lite.rresp = 2'b00;
                        s_axi_lite.rdata = timercmp[31:0];
                    end

                    MTIME_CMP_HIGH: begin
                        s_axi_lite.rresp = 2'b00;
                        s_axi_lite.rdata = timercmp[63:32];
                    end

                    MTIME_LOW: begin
                        s_axi_lite.rresp = 2'b00;
                        s_axi_lite.rdata = timer[31:0];
                    end

                    MTIME_HIGH: begin
                        s_axi_lite.rresp = 2'b00;
                        s_axi_lite.rdata = timer[63:32];
                    end

                    default: begin
                        // Return error + dummy / noticable value 
                        s_axi_lite.rresp = 2'b11;
                        s_axi_lite.rdata = 32'hFFFFFFFF;
                    end
                endcase

                if(s_axi_lite.rready)begin
                    next_state = SLAVE_IDLE;
                end
            end

            LITE_RECEIVING_WRITE_DATA: begin
                s_axi_lite.wready = 1'b1;
                // todo : add wstrb masking

                if(s_axi_lite.wvalid)begin
                    // Get wdata
                    case(awaddr)
                        MSIP:begin
                            msip_next = s_axi_lite.wdata;
                        end

                        MTIME_CMP_LOW:begin
                            timercmp_next[31:0] = s_axi_lite.wdata;
                        end

                        MTIME_CMP_HIGH:begin
                            timercmp_next[63:32] = s_axi_lite.wdata;
                        end

                        MTIME_LOW:begin
                            $display("mtime is read only");
                        end

                        MTIME_HIGH:begin
                            $display("mtime is read only");
                        end

                        default: $display("not a valid address pal!");
                    endcase

                    next_state =  LITE_SENDING_WRITE_RES;
                end
            end

            LITE_SENDING_WRITE_RES:begin
                s_axi_lite.bresp = 2'b00;
                s_axi_lite.bvalid = 1'b1;

                if(s_axi_lite.bready)begin
                    next_state = SLAVE_IDLE;
                end
            end

            default : begin
                $display("STATE ERROR");
            end
        endcase
    end

    /*
    * OUT INTRs REQs ASSIGNS
    */

    assign timer_irq = timer >= timercmp;
    assign soft_irq = msip[0];

endmodule
