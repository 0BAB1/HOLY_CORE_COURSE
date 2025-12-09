interface axi_lite_if #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
);
/* verilator lint_off UNOPTFLAT */

    // Write Address Channel
    logic [ADDR_WIDTH-1:0] awaddr;
    logic awvalid;
    logic awready;

    // Write Data Channel
    logic [DATA_WIDTH-1:0] wdata;
    logic [(DATA_WIDTH/8)-1:0] wstrb;
    logic wvalid;
    logic wready;

    // Write Response Channel
    logic [1:0] bresp;
    logic bvalid;
    logic bready;

    // Read Address Channel
    logic [ADDR_WIDTH-1:0] araddr;
    logic arvalid;
    logic arready;

    // Read Data Channel
    logic [DATA_WIDTH-1:0] rdata;
    logic [1:0] rresp;
    logic rvalid;
    logic rready;

    // Master modport
    modport master (
        output awaddr,
        output awvalid,
        input  awready,

        output wdata,
        output wstrb,
        output wvalid,
        input  wready,

        input  bresp,
        input  bvalid,
        output bready,

        output araddr,
        output arvalid,
        input  arready,

        input  rdata,
        input  rresp,
        input  rvalid,
        output rready
    );

    // Slave modport
    modport slave (
        input  awaddr,
        input  awvalid,
        output awready,

        input  wdata,
        input  wstrb,
        input  wvalid,
        output wready,

        output bresp,
        output bvalid,
        input  bready,

        input  araddr,
        input  arvalid,
        output arready,

        output rdata,
        output rresp,
        output rvalid,
        input  rready
    );

/* verilator lint_on UNOPTFLAT */
endinterface
