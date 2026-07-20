//Provided HDMI_Text_controller_v1_0 for HDMI AXI4 IP 
//Fall 2024 Distribution

//Modified 3/10/24 by Zuofu
//Updated 11/18/24 by Zuofu

`timescale 1 ns / 1 ps

module hdmi_text_controller_v1_0 #
(
    // Parameters of Axi Slave Bus Interface S00_AXI
    // Modify parameters as necessary for access of full VRAM range
    parameter integer C_AXI_DATA_WIDTH	= 32,
    parameter integer C_AXI_ADDR_WIDTH	= 14
)
(
    // Users to add ports here
    output logic hdmi_clk_n,
    output logic hdmi_clk_p,
    output logic [2:0] hdmi_tx_n,
    output logic [2:0] hdmi_tx_p,

    // User ports ends
    // Do not modify the ports beyond this line

    
    input logic  axi_aclk,
    input logic  axi_aresetn,
    input logic [C_AXI_ADDR_WIDTH-1 : 0] axi_awaddr,
    input logic [2 : 0] axi_awprot,
    input logic  axi_awvalid,
    output logic  axi_awready,
    input logic [C_AXI_DATA_WIDTH-1 : 0] axi_wdata,
    input logic [(C_AXI_DATA_WIDTH/8)-1 : 0] axi_wstrb,
    input logic  axi_wvalid,
    output logic  axi_wready,
    output logic [1 : 0] axi_bresp,
    output logic  axi_bvalid,
    input logic  axi_bready,
    input logic [C_AXI_ADDR_WIDTH-1 : 0] axi_araddr,
    input logic [2 : 0] axi_arprot,
    input logic  axi_arvalid,
    output logic  axi_arready,
    output logic [C_AXI_DATA_WIDTH-1 : 0] axi_rdata,
    output logic [1 : 0] axi_rresp,
    output logic  axi_rvalid,
    input logic  axi_rready
);


logic clk_25MHz, clk_125MHz, locked;
logic [3:0] red, green, blue;
logic [31:0] color_array [16];
logic [9:0] drawX, drawY;
logic hsync, vsync, vde;
logic [31:0] vsync_count;
logic [9:0] drawX_delay, drawY_delay;
logic vde_delay;

logic [10:0] font_addr;
logic [7:0]  font_data;
logic [11:0] char_index;
logic [9:0]  reg_index;
logic [1:0]  byte_offset_delay;
logic [31:0] current_reg;
logic [7:0]  current_char_data;
logic [7:0]  current_color_data;
logic        draw_pixel;
logic        text_bit;


hdmi_text_controller_v1_0_AXI # ( 
    .C_S_AXI_DATA_WIDTH(C_AXI_DATA_WIDTH),
    .C_S_AXI_ADDR_WIDTH(C_AXI_ADDR_WIDTH)
) hdmi_text_controller_v1_0_AXI_inst (
    .S_AXI_ACLK(axi_aclk),
    .S_AXI_ARESETN(axi_aresetn),
    .S_AXI_AWADDR(axi_awaddr),
    .S_AXI_AWPROT(axi_awprot),
    .S_AXI_AWVALID(axi_awvalid),
    .S_AXI_AWREADY(axi_awready),
    .S_AXI_WDATA(axi_wdata),
    .S_AXI_WSTRB(axi_wstrb),
    .S_AXI_WVALID(axi_wvalid),
    .S_AXI_WREADY(axi_wready),
    .S_AXI_BRESP(axi_bresp),
    .S_AXI_BVALID(axi_bvalid),
    .S_AXI_BREADY(axi_bready),
    .S_AXI_ARADDR(axi_araddr),
    .S_AXI_ARPROT(axi_arprot),
    .S_AXI_ARVALID(axi_arvalid),
    .S_AXI_ARREADY(axi_arready),
    .S_AXI_RDATA(axi_rdata),
    .S_AXI_RRESP(axi_rresp),
    .S_AXI_RVALID(axi_rvalid),
    .S_AXI_RREADY(axi_rready),
    .frames(vsync_count),
    .drawx({2'b00, drawX}),
    .drawy({2'b00, drawY}),
    .portB_clk(clk_25MHz),
    .portB_addr(char_index[11:1]),
    .portB_data(current_reg),
    .colors(color_array)
);

assign char_index = (drawY[9:4] * 80) + drawX[9:3];

assign font_addr = {current_char_data[6:0], drawY_delay[3:0]};

assign draw_pixel = font_data[3'd7 - drawX_delay[2:0]];

assign text_bit = draw_pixel ^ current_char_data[7];

always_comb begin
    if (byte_offset_delay[0] == 1'b0) begin
        current_char_data  = current_reg[7:0];   
        current_color_data = current_reg[15:8]; 
    end else begin
        current_char_data  = current_reg[23:16]; 
        current_color_data = current_reg[31:24]; 
    end
end

logic [3:0] foreground_idx, background_idx;
assign foreground_idx = current_color_data[7:4];
assign background_idx = current_color_data[3:0];

logic [31:0] foreground_color, background_color;
assign foreground_color = color_array[foreground_idx];
assign background_color = color_array[background_idx];

always_comb begin
    if (vde_delay) begin
        if (text_bit == 1'b1) begin
            // Foreground color bits [27:16]
            red   = foreground_color[27:24];   
            green = foreground_color[23:20];  
            blue  = foreground_color[19:16];        
        end else begin
            // Background color bits [11:0]
            red   = background_color[11:8];
            green = background_color[7:4];
            blue  = background_color[3:0];
        end
    end else begin
        // Output black during blanking
        red   = 4'h0;
        green = 4'h0;
        blue  = 4'h0;
    end
end

clk_wiz_0 clk_wiz (
    .clk_out1(clk_25MHz),
    .clk_out2(clk_125MHz),
    .reset(~axi_aresetn),
    .locked(locked),
    .clk_in1(axi_aclk)
);

always_ff @(posedge vsync) begin
    if (~axi_aresetn)
        vsync_count <= 32'h0;
    else
        vsync_count <= vsync_count + 1;
end
//Delays vga variables to sync with BRAM
always_ff @(posedge clk_25MHz) begin
    drawX_delay <= drawX;
    drawY_delay <= drawY;
    vde_delay <= vde;
    byte_offset_delay <= char_index[1:0];
end

vga_controller vga (
    .pixel_clk(clk_25MHz),
    .reset(~axi_aresetn),
    .hs(hsync),
    .vs(vsync),
    .active_nblank(vde),
    .drawX(drawX),
    .drawY(drawY)
);  

hdmi_tx_0 vga_to_hdmi (
    .pix_clk(clk_25MHz),
    .pix_clkx5(clk_125MHz),
    .pix_clk_locked(locked),
    .rst(~axi_aresetn),
    .red(red),
    .green(green),
    .blue(blue),
    .vde(vde_delay),
    .hsync(hsync),
    .vsync(vsync),
     .TMDS_CLK_P(hdmi_clk_p),           
     .TMDS_CLK_N(hdmi_clk_n),           
    .TMDS_DATA_P(hdmi_tx_p),         
    .TMDS_DATA_N(hdmi_tx_n)
);

font_rom font_rom_instance (
    .addr(font_addr),
    .data(font_data)
);

endmodule