`timescale 1ns / 1ps

module npu_tb();

    // -----------------------------------------
    // 1. Clock and Reset Generation
    // -----------------------------------------
    logic clk;
    logic rst_n;

    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz Clock
    end

    initial begin
        rst_n = 0;
        #50 rst_n = 1;         // Release reset after 50ns
    end

    // -----------------------------------------
    // 2. AXI-Lite Signals (MicroBlaze Mock)
    // -----------------------------------------
    logic [3:0]  s00_axi_awaddr;
    logic        s00_axi_awvalid, s00_axi_awready;
    logic [31:0] s00_axi_wdata;
    logic [3:0]  s00_axi_wstrb;
    logic        s00_axi_wvalid, s00_axi_wready;
    logic [1:0]  s00_axi_bresp;
    logic        s00_axi_bvalid, s00_axi_bready;
    logic [3:0]  s00_axi_araddr;
    logic        s00_axi_arvalid, s00_axi_arready;
    logic [31:0] s00_axi_rdata;
    logic [1:0]  s00_axi_rresp;
    logic        s00_axi_rvalid, s00_axi_rready;

    // -----------------------------------------
    // 3. AXI-Stream Signals (DMA Mock)
    // -----------------------------------------
    logic        s00_axis_tvalid, s00_axis_tready, s00_axis_tlast;
    logic [31:0] s00_axis_tdata;
    logic [3:0]  s00_axis_tstrb;

    // -----------------------------------------
    // 4. BRAM Signals
    // -----------------------------------------
    logic [511:0] bram_rddata;
    logic [15:0]  bram_raddr;

    // Mocking BRAM: Just feed it dummy weights based on address
    assign bram_rddata = {16{32'h00000001}}; // Every MAC gets a weight of '1'

    // -----------------------------------------
    // 5. Instantiate the NPU Core
    // -----------------------------------------
    mnist_npu_core_v1_0 dut (
        .bram_rddata_wire(bram_rddata),
        .bram_raddr_wire(bram_raddr),

        // AXI-Lite
        .s00_axi_aclk(clk),
        .s00_axi_aresetn(rst_n),
        .s00_axi_awaddr(s00_axi_awaddr),
        .s00_axi_awvalid(s00_axi_awvalid),
        .s00_axi_awready(s00_axi_awready),
        .s00_axi_wdata(s00_axi_wdata),
        .s00_axi_wstrb(s00_axi_wstrb),
        .s00_axi_wvalid(s00_axi_wvalid),
        .s00_axi_wready(s00_axi_wready),
        .s00_axi_bresp(s00_axi_bresp),
        .s00_axi_bvalid(s00_axi_bvalid),
        .s00_axi_bready(s00_axi_bready),
        .s00_axi_araddr(s00_axi_araddr),
        .s00_axi_arvalid(s00_axi_arvalid),
        .s00_axi_arready(s00_axi_arready),
        .s00_axi_rdata(s00_axi_rdata),
        .s00_axi_rresp(s00_axi_rresp),
        .s00_axi_rvalid(s00_axi_rvalid),
        .s00_axi_rready(s00_axi_rready),

        // AXI-Stream
        .s00_axis_aclk(clk),
        .s00_axis_aresetn(rst_n),
        .s00_axis_tready(s00_axis_tready),
        .s00_axis_tdata(s00_axis_tdata),
        .s00_axis_tstrb(s00_axis_tstrb),
        .s00_axis_tlast(s00_axis_tlast),
        .s00_axis_tvalid(s00_axis_tvalid)
    );

    // -----------------------------------------
    // 6. Test Sequence
    // -----------------------------------------
    initial begin
        // Initialize Inputs
        s00_axi_awaddr = 0; s00_axi_awvalid = 0; s00_axi_wdata = 0;
        s00_axi_wstrb = 4'hF; s00_axi_wvalid = 0; s00_axi_bready = 1;
        s00_axi_araddr = 0; s00_axi_arvalid = 0; s00_axi_rready = 1;
        
        s00_axis_tdata = 0; s00_axis_tvalid = 0; 
        s00_axis_tlast = 0; s00_axis_tstrb = 4'hF;

        // Wait for Reset
        wait(rst_n == 1);
        #100;

        // Step 1: Write to slv_reg0 (Start NPU)
        $display("Starting NPU...");
        @(posedge clk);
        s00_axi_awaddr = 4'h0; // reg 0
        s00_axi_wdata  = 32'h1; // assert start
        s00_axi_awvalid = 1;
        s00_axi_wvalid = 1;
        wait(s00_axi_awready && s00_axi_wready);
        @(posedge clk);
        s00_axi_awvalid = 0;
        s00_axi_wvalid = 0;
        #50;

        // Step 2: Feed Pixels via AXI-Stream (Mock DMA)
        $display("Sending DMA Stream...");
        for (int i = 0; i < 784; i++) begin
            @(posedge clk);
            s00_axis_tvalid = 1;
            s00_axis_tdata = i % 255; // Dummy pixel value
            s00_axis_tlast = (i == 783) ? 1 : 0;
            
            // Wait for NPU to accept data
            wait(s00_axis_tready);
        end
        @(posedge clk);
        s00_axis_tvalid = 0;
        s00_axis_tlast = 0;

        // Step 3: Poll slv_reg1 for Done signal
        $display("Waiting for NPU to finish calculation...");
        s00_axi_araddr = 4'h4; // reg 1 (status)
        forever begin
            @(posedge clk);
            s00_axi_arvalid = 1;
            wait(s00_axi_arready);
            @(posedge clk);
            s00_axi_arvalid = 0;
            wait(s00_axi_rvalid);
            
            if (s00_axi_rdata & 32'h00000001) begin
                $display("NPU DONE! Prediction Output: %d", (s00_axi_rdata >> 4) & 32'h0F);
                break;
            end
        end

        $display("Simulation Complete.");
        $finish;
    end

endmodule