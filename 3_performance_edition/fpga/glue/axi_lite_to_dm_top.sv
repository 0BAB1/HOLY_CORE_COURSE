import holy_core_pkg::*;

module axi_lite_to_dm_top #(
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_DATA_WIDTH = 32
)(
    input  logic                   clk,
    input  logic                   rst_n,

    // AXI-Lite Slave Interface (input)
    axi_lite_if.slave s_axi_lite,

    // DM Memory Interface (output)
    output logic                   device_req_o,
    output logic                   device_we_o,
    output logic [AXI_ADDR_WIDTH-1:0] device_addr_o,
    output logic [AXI_DATA_WIDTH/8-1:0] device_be_o,
    output logic [AXI_DATA_WIDTH-1:0] device_wdata_o,
    input  logic [AXI_DATA_WIDTH-1:0] device_rdata_i
);
    // AXI LITE's result for reads will be stored here
    logic [31:0]                    axi_lite_read_result;

    // =======================
    // FSM LOGIC
    // =======================
    // dm mem takes a clock cycle to answer due to timing shananigans
    // so we need to make sur we wait 1 cycle whan reading ! thus the delay
    // register below
    logic delay, delay_next;

    // Axi lite states
    axi_state_slave_t state, next_state;
    logic [31:0] awaddr, awaddr_next;
    logic [31:0] araddr, araddr_next;

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            state <= SLAVE_IDLE;
            awaddr <= 0;
            araddr <= 0;
            delay <= 0;
        end else begin
            state <= next_state;
            awaddr <= awaddr_next;
            araddr <= araddr_next;
            delay <= delay_next;
        end
    end

    // =======================
    // READ & MAIN FSM LOGIC
    // =======================
     always_comb begin : axi_lite_fsm
        // stats & registers
        next_state = state;
        awaddr_next = awaddr;
        araddr_next = araddr;

        // AXI LITE DEFAULT
        s_axi_lite.awready = 1'b0;
        s_axi_lite.wready = 1'b0;
        s_axi_lite.bresp = 2'b00;
        s_axi_lite.bvalid = 1'b0;
        s_axi_lite.arready = 1'b0;
        s_axi_lite.rdata = 32'd0;
        s_axi_lite.rvalid = 1'b0;
        s_axi_lite.rresp = 2'b00;

        // OUTGOING MEM BUS DEFAULTS
        device_req_o = 0;
        device_we_o = 0;
        device_addr_o = '0;
        device_be_o = 4'b1111;
        device_wdata_o = '0;

        // misc
        delay_next = 0;

        case (state)
            SLAVE_IDLE: begin
                s_axi_lite.awready = 1'b1;
                s_axi_lite.arready = 1'b1;

                if(s_axi_lite.arvalid)begin
                    next_state = LITE_SENDING_READ_DATA;
                    araddr_next = s_axi_lite.araddr;
                end

                if(s_axi_lite.awvalid)begin
                    next_state = LITE_RECEIVING_WRITE_DATA;
                    awaddr_next = s_axi_lite.awaddr;
                end
            end

            LITE_SENDING_READ_DATA: begin
                device_req_o = 1;
                device_addr_o = araddr;
                delay_next = 1;
                
                s_axi_lite.rresp = 2'b00;
                // simply return 0 extended contents
                s_axi_lite.rdata = device_rdata_i;
                
                if(s_axi_lite.rready && (delay == 1))begin
                    next_state = SLAVE_IDLE;
                    // read is not valid until delay is filled
                    s_axi_lite.rvalid = 1'b1;
                end
            end

            LITE_RECEIVING_WRITE_DATA: begin
                s_axi_lite.wready = 1'b1;
                // todo : add wstrb masking

                if(s_axi_lite.wvalid)begin
                    device_wdata_o = s_axi_lite.wdata;
                    device_addr_o = awaddr;
                    device_be_o = s_axi_lite.wstrb;
                    device_we_o = 1;
                    device_req_o = 1;

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
endmodule
