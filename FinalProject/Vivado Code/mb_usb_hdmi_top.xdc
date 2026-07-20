## -------------------------------------------------------------------------------
## URBANA BOARD CONSTRAINTS - FIXED FOR NPU & HDMI
## -------------------------------------------------------------------------------

## 1. System Clock
set_property -dict { PACKAGE_PIN N15   IOSTANDARD LVCMOS33 } [get_ports {clk_100mhz}]

## 2. DDR3 Calibration LED
set_property -dict { PACKAGE_PIN C13   IOSTANDARD LVCMOS33 } [get_ports {init_calib_complete}]

## 3. System Reset
set_property -dict { PACKAGE_PIN J2    IOSTANDARD LVCMOS33 } [get_ports {sys_rst_0}]

## 4. USB-UART
set_property -dict { PACKAGE_PIN B16   IOSTANDARD LVCMOS33 } [get_ports {uart_rtl_0_rxd}]
set_property -dict { PACKAGE_PIN A16   IOSTANDARD LVCMOS33 } [get_ports {uart_rtl_0_txd}]

## 5. HDMI Out 
set_property -dict { PACKAGE_PIN V17   IOSTANDARD TMDS_33 } [get_ports {HDMI_0_tmds_clk_n}]
set_property -dict { PACKAGE_PIN U16   IOSTANDARD TMDS_33 } [get_ports {HDMI_0_tmds_clk_p}]

set_property -dict { PACKAGE_PIN U18   IOSTANDARD TMDS_33 } [get_ports {HDMI_0_tmds_data_n[0]}]
set_property -dict { PACKAGE_PIN U17   IOSTANDARD TMDS_33 } [get_ports {HDMI_0_tmds_data_p[0]}]
set_property -dict { PACKAGE_PIN R17   IOSTANDARD TMDS_33 } [get_ports {HDMI_0_tmds_data_n[1]}]
set_property -dict { PACKAGE_PIN R16   IOSTANDARD TMDS_33 } [get_ports {HDMI_0_tmds_data_p[1]}]
set_property -dict { PACKAGE_PIN T14   IOSTANDARD TMDS_33 } [get_ports {HDMI_0_tmds_data_n[2]}]
set_property -dict { PACKAGE_PIN R14   IOSTANDARD TMDS_33 } [get_ports {HDMI_0_tmds_data_p[2]}]

#button menu
set_property -dict { PACKAGE_PIN J1    IOSTANDARD LVCMOS33 } [get_ports {gpio_rtl_0_tri_i[0]}] 
set_property -dict { PACKAGE_PIN G2    IOSTANDARD LVCMOS33 } [get_ports {gpio_rtl_0_tri_i[1]}] 
set_property -dict { PACKAGE_PIN H2    IOSTANDARD LVCMOS33 } [get_ports {gpio_rtl_0_tri_i[2]}]

## -------------------------------------------------------------------------------
## CAUTION: MANUAL ROUTING & CDC BYPASSES REMOVED
## Vivado will automatically infer the correct clock domains and backbone routing 
## through the Clocking Wizard.
## -------------------------------------------------------------------------------
# set_property CLOCK_DEDICATED_ROUTE BACKBONE [get_nets clk_100mhz_IBUF]
# set_clock_groups -asynchronous -group [get_clocks clk_out1_npu_mnist_bd_clk_wiz_1_0] -group [get_clocks clk_out1_clk_wiz_0]