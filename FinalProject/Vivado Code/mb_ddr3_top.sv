`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Custom top-level wrapper for MicroBlaze DDR3 + HDMI + NPU
//////////////////////////////////////////////////////////////////////////////////

module mb_ddr3_top (
    // 1. Differential System Clock (For the MIG/DDR3 on pins C1/B1)
    input  logic SYS_CLK_clk_n,
    input  logic SYS_CLK_clk_p,

    // 2. Single-Ended System Clock (For MicroBlaze/HDMI on pin N15)
    input  logic sys_clk_i_0,

    // 3. System Reset (Urbana Button J2)
    input  logic sys_rst_0,

    // 4. DDR3 Calibration LED
    output logic init_calib_complete,

    // 5. UART (Matches your main XDC)
    input  logic uart_rtl_0_rxd,
    output logic uart_rtl_0_txd,

    // 6. HDMI (Matches your main XDC)
    output logic HDMI_0_tmds_clk_n,
    output logic HDMI_0_tmds_clk_p,
    output logic [2:0] HDMI_0_tmds_data_n,
    output logic [2:0] HDMI_0_tmds_data_p,

    // 7. DDR3 Memory Interface (Matches urbana_ddr3.xdc)
    output logic [12:0] ddr3_addr,
    output logic [2:0]  ddr3_ba,
    output logic        ddr3_cas_n,
    output logic [0:0]  ddr3_ck_n, 
    output logic [0:0]  ddr3_ck_p,
    output logic [0:0]  ddr3_cke,
    output logic [1:0]  ddr3_dm,
    inout  wire  [15:0] ddr3_dq,     // Bidirectional signals MUST be wire
    inout  wire  [1:0]  ddr3_dqs_n,
    inout  wire  [1:0]  ddr3_dqs_p,
    output logic [0:0]  ddr3_odt,   
    output logic        ddr3_ras_n,
    output logic        ddr3_reset_n,
    output logic        ddr3_we_n
);

    // Instantiate your specific Block Design
    npu_mnist_bd mb_ddr3_i (
        // Clocks & Reset
        .SYS_CLK_clk_n(SYS_CLK_clk_n),
        .SYS_CLK_clk_p(SYS_CLK_clk_p),
        .sys_clk_i_0(sys_clk_i_0),
        .sys_rst_0(sys_rst_0),

        // Calibration LED
        .init_calib_complete(init_calib_complete),

        // UART
        .uart_rtl_0_rxd(uart_rtl_0_rxd),
        .uart_rtl_0_txd(uart_rtl_0_txd),

        // HDMI
        .HDMI_0_tmds_clk_n(HDMI_0_tmds_clk_n),
        .HDMI_0_tmds_clk_p(HDMI_0_tmds_clk_p),
        .HDMI_0_tmds_data_n(HDMI_0_tmds_data_n),
        .HDMI_0_tmds_data_p(HDMI_0_tmds_data_p),

        // DDR3 (Vivado automatically prepends 'DDR3_0_' to interface pins)
        .DDR3_0_addr(ddr3_addr),
        .DDR3_0_ba(ddr3_ba),
        .DDR3_0_cas_n(ddr3_cas_n),
        .DDR3_0_ck_n(ddr3_ck_n),
        .DDR3_0_ck_p(ddr3_ck_p),
        .DDR3_0_cke(ddr3_cke),
        .DDR3_0_dm(ddr3_dm),
        .DDR3_0_dq(ddr3_dq),
        .DDR3_0_dqs_n(ddr3_dqs_n),
        .DDR3_0_dqs_p(ddr3_dqs_p),
        .DDR3_0_odt(ddr3_odt),
        .DDR3_0_ras_n(ddr3_ras_n),
        .DDR3_0_reset_n(ddr3_reset_n),
        .DDR3_0_we_n(ddr3_we_n)
    );

endmodule