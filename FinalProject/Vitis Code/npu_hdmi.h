#ifndef NPU_HDMI_H
#define NPU_HDMI_H

#include "xil_types.h"
#include "xparameters.h"
#include "xil_io.h"
#include "xtmrctr.h"

// =========================================================
// BASE ADDRESSES & IDs (Verify these match xparameters.h!)
// =========================================================
#define NPU_BASEADDR        XPAR_MNIST_NPU_CORE_0_S00_AXI_BASEADDR
#define HDMI_BASEADDR       XPAR_HDMI_TEXT_CONTROLLER_0_S00_AXI_BASEADDR
#define DMA_DEVICE_ID       XPAR_AXI_DMA_0_DEVICE_ID
#define TIMER_DEVICE_ID     XPAR_TMRCTR_0_DEVICE_ID

// =========================================================
// HDMI MACROS & OFFSETS
// =========================================================
#define HDMI_VRAM_OFFSET    0x0000
#define HDMI_PALETTE_OFFSET 0x2000 

// =========================================================
// SYSTEM CONSTANTS
// =========================================================
#define HARDWARE_TIMEOUT    1000000 // Clock cycles before giving up on NPU

// =========================================================
// FUNCTION PROTOTYPES
// =========================================================

// --- HDMI Display ---
void hdmi_set_palette(u8 color_index, u32 rgb24);
void hdmi_clear_screen();
void hdmi_print_char(int x, int y, char c, u8 fg_color, u8 bg_color);
void hdmi_print_string(int x, int y, const char* str, u8 fg_color, u8 bg_color);
void draw_mnist_ascii(u8* image_data, int start_x, int start_y, u8 fg_color, u8 bg_color);

// --- Software Simulation ---
u8 software_inference(u8* image);

#endif // NPU_HDMI_H
