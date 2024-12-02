interface axi_if #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter ID_WIDTH   = 4
);

    // Global AXI Signals
    logic aclk;
    logic aresetn;

    // Write Address Channel
    logic [ID_WIDTH-1:0] awid;
    logic [ADDR_WIDTH-1:0] awaddr;
    logic [7:0] awlen;         // Burst length
    logic [2:0] awsize;        // Burst size
    logic [1:0] awburst;       // Burst type
    logic [3:0] awqos;         // Quality of Service
    logic [1:0] awlock;        // Lock type
    logic awvalid;
    logic awready;

    // Write Data Channel
    logic [DATA_WIDTH-1:0] wdata;
    logic [(DATA_WIDTH/8)-1:0] wstrb;  // Write strobe
    logic wlast;                       // Last write in burst
    logic wvalid;
    logic wready;

    // Write Response Channel
    logic [ID_WIDTH-1:0] bid;
    logic [1:0] bresp;  // Write response
    logic bvalid;
    logic bready;

    // Read Address Channel
    logic [ID_WIDTH-1:0] arid;
    logic [ADDR_WIDTH-1:0] araddr;
    logic [7:0] arlen;         // Burst length
    logic [2:0] arsize;        // Burst size
    logic [1:0] arburst;       // Burst type
    logic [3:0] arqos;         // Quality of Service
    logic [1:0] arlock;        // Lock type
    logic arvalid;
    logic arready;

    // Read Data Channel
    logic [ID_WIDTH-1:0] rid;
    logic [DATA_WIDTH-1:0] rdata;
    logic [1:0] rresp;  // Read response
    logic rlast;        // Last read in burst
    logic rvalid;
    logic rready;

    // Define modport for master
    modport master (
        input  aclk,
        input  aresetn,

        // Write Address Channel
        output awid,
        output awaddr,
        output awlen,
        output awsize,
        output awburst,
        output awqos,
        output awlock,
        output awvalid,
        input  awready,

        // Write Data Channel
        output wdata,
        output wstrb,
        output wlast,
        output wvalid,
        input  wready,

        // Write Response Channel
        input  bid,
        input  bresp,
        input  bvalid,
        output bready,

        // Read Address Channel
        output arid,
        output araddr,
        output arlen,
        output arsize,
        output arburst,
        output arqos,
        output arlock,
        output arvalid,
        input  arready,

        // Read Data Channel
        input  rid,
        input  rdata,
        input  rresp,
        input  rlast,
        input  rvalid,
        output rready
    );

    // Define modport for slave
    modport slave (
        input  aclk,
        input  aresetn,

        // Write Address Channel
        input  awid,
        input  awaddr,
        input  awlen,
        input  awsize,
        input  awburst,
        input  awqos,
        input  awlock,
        input  awvalid,
        output awready,

        // Write Data Channel
        input  wdata,
        input  wstrb,
        input  wlast,
        input  wvalid,
        output wready,

        // Write Response Channel
        output bid,
        output bresp,
        output bvalid,
        input  bready,

        // Read Address Channel
        input  arid,
        input  araddr,
        input  arlen,
        input  arsize,
        input  arburst,
        input  arqos,
        input  arlock,
        input  arvalid,
        output arready,

        // Read Data Channel
        output rid,
        output rdata,
        output rresp,
        output rlast,
        output rvalid,
        input  rready
    );

endinterface

interface aximm #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter ID_WIDTH   = 4
);

    // Global AXI Signals
    logic aclk;
    logic aresetn;

    // Write Address Channel
    logic [ID_WIDTH-1:0] awid;
    logic [ADDR_WIDTH-1:0] awaddr;
    logic [7:0] awlen;         // Burst length
    logic [2:0] awsize;        // Burst size
    logic [1:0] awburst;       // Burst type
    logic [3:0] awqos;         // Quality of Service
    logic [1:0] awlock;        // Lock type
    logic awvalid;
    logic awready;

    // Write Data Channel
    logic [DATA_WIDTH-1:0] wdata;
    logic [(DATA_WIDTH/8)-1:0] wstrb;  // Write strobe
    logic wlast;                       // Last write in burst
    logic wvalid;
    logic wready;

    // Write Response Channel
    logic [ID_WIDTH-1:0] bid;
    logic [1:0] bresp;  // Write response
    logic bvalid;
    logic bready;

    // Read Address Channel
    logic [ID_WIDTH-1:0] arid;
    logic [ADDR_WIDTH-1:0] araddr;
    logic [7:0] arlen;         // Burst length
    logic [2:0] arsize;        // Burst size
    logic [1:0] arburst;       // Burst type
    logic [3:0] arqos;         // Quality of Service
    logic [1:0] arlock;        // Lock type
    logic arvalid;
    logic arready;

    // Read Data Channel
    logic [ID_WIDTH-1:0] rid;
    logic [DATA_WIDTH-1:0] rdata;
    logic [1:0] rresp;  // Read response
    logic rlast;        // Last read in burst
    logic rvalid;
    logic rready;

    // Define modport for master
    modport master (
        input  aclk,
        input  aresetn,

        // Write Address Channel
        output awid,
        output awaddr,
        output awlen,
        output awsize,
        output awburst,
        output awqos,
        output awlock,
        output awvalid,
        input  awready,

        // Write Data Channel
        output wdata,
        output wstrb,
        output wlast,
        output wvalid,
        input  wready,

        // Write Response Channel
        input  bid,
        input  bresp,
        input  bvalid,
        output bready,

        // Read Address Channel
        output arid,
        output araddr,
        output arlen,
        output arsize,
        output arburst,
        output arqos,
        output arlock,
        output arvalid,
        input  arready,

        // Read Data Channel
        input  rid,
        input  rdata,
        input  rresp,
        input  rlast,
        input  rvalid,
        output rready
    );

    // Define modport for slave
    modport slave (
        input  aclk,
        input  aresetn,

        // Write Address Channel
        input  awid,
        input  awaddr,
        input  awlen,
        input  awsize,
        input  awburst,
        input  awqos,
        input  awlock,
        input  awvalid,
        output awready,

        // Write Data Channel
        input  wdata,
        input  wstrb,
        input  wlast,
        input  wvalid,
        output wready,

        // Write Response Channel
        output bid,
        output bresp,
        output bvalid,
        input  bready,

        // Read Address Channel
        input  arid,
        input  araddr,
        input  arlen,
        input  arsize,
        input  arburst,
        input  arqos,
        input  arlock,
        input  arvalid,
        output arready,

        // Read Data Channel
        output rid,
        output rdata,
        output rresp,
        output rlast,
        output rvalid,
        input  rready
    );

endinterface
