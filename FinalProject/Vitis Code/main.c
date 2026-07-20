#include "platform.h"
#include "xparameters.h"
#include "xaxidma.h"
#include "xtmrctr.h"
#include "xgpio.h"
#include "xil_cache.h"
#include "xil_printf.h"
#include "xuartlite_l.h"
#include "hdmi_text_controller.h"
#include "mnist_benchmark.h"
#include "npu_weights.h"

//Defines memory addresses for our DDR3, NPU, and HDMI text controller
#define HDMI_BASEADDR XPAR_HDMI_TEXT_CONTROLLER_0_AXI_BASEADDR
#define DDR3_BASEADDR 0x80000000
#define NPU_BASEADDR  0x44A10000

//Defines address for UART module if there is one. 
#ifndef UART_BASEADDR
#define UART_BASEADDR XPAR_AXI_UARTLITE_0_BASEADDR
#endif

// Makes sure that we have no issues with our DDR3 overflowing into other parts of memory for DMA operations
#define IMAGE_BUFFER_ADDR (DDR3_BASEADDR + 0x01000000)

hdmi_ctrl_t *hdmi_ctrl = (hdmi_ctrl_t *) HDMI_BASEADDR;
// Protocol initiation
XAxiDma AxiDma;
XTmrCtr Timer;
XGpio   Buttons;

//defines a function to get absolute value of a variable
#define ABS(x) ((x) < 0 ? -(x) : (x))
// Defines the colors that we will use for our palette
struct COLOR colors[]={
    {"black",         0x0, 0x0, 0x0}, {"blue",          0x0, 0x0, 0xa},
    {"green",         0x0, 0xa, 0x0}, {"cyan",          0x0, 0xa, 0xa},
    {"red",           0xa, 0x0, 0x0}, {"magenta",       0xa, 0x0, 0xa},
    {"brown",         0xa, 0x5, 0x0}, {"light gray",    0xa, 0xa, 0xa},
    {"dark gray",     0x5, 0x5, 0x5}, {"light blue",    0x5, 0x5, 0xf},
    {"light green",   0x5, 0xf, 0x5}, {"light cyan",    0x5, 0xf, 0xf},
    {"light red",     0xf, 0x5, 0x5}, {"light magenta", 0xf, 0x5, 0xf},
    {"yellow",        0xf, 0xf, 0x5}, {"white",         0xf, 0xf, 0xf}
};

// Definitions of functions used for HDMI/drawing purposes
//Clears the screen, sets text to spaces and background colors to black
void textHDMIColorClr() {
    for (int i = 0; i < (ROWS * COLUMNS) * 2; i += 2) {
        hdmi_ctrl->VRAM[i] = ' ';
        hdmi_ctrl->VRAM[i + 1] = 0x00;
    }
}
// Determines currently used color with RGB values
void setColorPalette(uint8_t color, uint8_t red, uint8_t green, uint8_t blue) {
    uint32_t colorcalc = ((red & 0x0F) << 8) | ((green & 0x0F) << 4) | (blue & 0x0F);
    hdmi_ctrl->PALETTE[color] = (colorcalc << 16) | colorcalc;
}
// Draws an ascii string with passed-in foreground and background colors in the specified x y coordinates
void textHDMIDrawColorText(char* str, int x, int y, uint8_t background, uint8_t foreground) {
    int i = 0;
    while (str[i] != 0) {
        if (x + i >= 0 && x + i < COLUMNS && y >= 0 && y < ROWS) {
            hdmi_ctrl->VRAM[(y * COLUMNS + x + i) * 2 + 1] = foreground << 4 | background;
            hdmi_ctrl->VRAM[(y * COLUMNS + x + i) * 2] = str[i];
        }
        i++;
    }
}
// Draws a single ascii character with same parameters as above string printing function
void textHDMIDrawChar(int x, int y, char c, uint8_t background, uint8_t foreground) {
    if (x >= 0 && x < COLUMNS && y >= 0 && y < ROWS) {
        hdmi_ctrl->VRAM[(y * COLUMNS + x) * 2 + 1] = foreground << 4 | background;
        hdmi_ctrl->VRAM[(y * COLUMNS + x) * 2] = c;
    }
}
//Draws an integer by turning the value into ascii and drawing
void hdmi_print_int(int val, int x, int y, uint8_t bg, uint8_t fg) {
    if (val == 0) { textHDMIDrawChar(x, y, '0', bg, fg); return; }
    char buf[12]; int i = 11; buf[i--] = '\0';
    while (val > 0) { buf[i--] = (val % 10) + '0'; val /= 10; }
    textHDMIDrawColorText(&buf[i+1], x, y, bg, fg);
}
// Function to draw straight lines
void drawLine(int x0, int y0, int x1, int y1, char c, uint8_t bg, uint8_t fg) {
    int dx = ABS(x1 - x0), sx = x0 < x1 ? 1 : -1;
    int dy = -ABS(y1 - y0), sy = y0 < y1 ? 1 : -1;
    int err = dx + dy, e2;
    while (1) {
        textHDMIDrawChar(x0, y0, c, bg, fg);
        if (x0 == x1 && y0 == y1) break;
        e2 = 2 * err;
        if (e2 >= dy) { err += dy; x0 += sx; }
        if (e2 <= dx) { err += dx; y0 += sy; }
    }
}
//draws the image passed in by the serial communcation that the python sends
void draw_mnist_canvas(const uint8_t* image, int start_x, int start_y) {
    for(int y = 0; y < 28; y++) { //28x28 canvas
        for(int x = 0; x < 28; x++) {
            int idx = (y * 28) + x; // row major indexing
            char c = image[idx] > 0 ? '#' : '.';// Draws a hashmark if 1 is seen, else draws a period, which is our blank character.
            uint8_t fg = image[idx] > 0 ? 15 : 8;
            textHDMIDrawChar(start_x + x, start_y + y, c, 0, fg);
        }
    }
}

// Functions to initialize and run the menu
// Polls for the on-board buttons on the fpga
void wait_for_button() {
    textHDMIDrawColorText("[ Press ANY Board Button to Continue ]", 22, 28, 0, 11);
    while(XGpio_DiscreteRead(&Buttons, 1) != 0);
    while(XGpio_DiscreteRead(&Buttons, 1) == 0);
    while(XGpio_DiscreteRead(&Buttons, 1) != 0);
}
// Draws the main menu
void draw_menu() {
    textHDMIColorClr();
    textHDMIDrawColorText("-----------------------------------------", 20, 5, 0, 15);
    textHDMIDrawColorText("       NEURAL PROCESSOR MAIN MENU        ", 20, 6, 0, 10);
    textHDMIDrawColorText("-----------------------------------------", 20, 7, 0, 15);

    textHDMIDrawColorText("[ BTN 1 ] - Architecture Slideshow", 25, 12, 0, 11);
    textHDMIDrawColorText("[ BTN 2 ] - CPU vs. NPU Speed Race", 25, 14, 0, 13);
    textHDMIDrawColorText("[ BTN 3 ] - Interactive Guess-A-Sketch", 25, 16, 0, 14);

    textHDMIDrawColorText("Awaiting Input", 33, 24, 0, 15);
}

// Draws the architecture image for demo
void run_slideshow() {
    textHDMIColorClr();
    //headers and labels
    textHDMIDrawColorText("SLIDE 1: NPU Network Topology", 22, 2, 0, 11);
    textHDMIDrawColorText("784 INPUTS", 4, 4, 0, 15);
    textHDMIDrawColorText("64 HIDDEN NODES", 30, 4, 0, 15);
    textHDMIDrawColorText("10 OUTPUTS", 60, 4, 0, 15);
    // Y-Coordinates for the visible nodes and the also the gap in the middle to show theres a lot of nodes
    int in_y[]  = {7, 10, 20, 23}; 
    int hid_y[] = {6, 9, 21, 24};
    
    // 10 outputs
    int out_y[] = {5, 7, 9, 11, 13, 15, 17, 19, 21, 23};
    char* out_labels[] = {"[ 0 ]", "[ 1 ]", "[ 2 ]", "[ 3 ]", "[ 4 ]", 
                          "[ 5 ]", "[ 6 ]", "[ 7 ]", "[ 8 ]", "[ 9 ]"};

    // Connect Inputs to Hidden
    for(int i=0; i<4; i++) {
        for(int j=0; j<4; j++) {
            drawLine(11, in_y[i], 29, hid_y[j], '.', 0, 8); 
        }
    }
    // Connect Hidden to Outputs
    for(int j=0; j<4; j++) {
        for(int k=0; k<10; k++) {
            drawLine(43, hid_y[j], 58, out_y[k], '.', 0, 8);
        }
    }
    // 2. Draw Layer 1 (Inputs) 
    for(int i=0; i<4; i++) textHDMIDrawColorText("(IN )", 6, in_y[i], 0, 10);
    textHDMIDrawChar(8, 14, '.', 0, 10);
    textHDMIDrawChar(8, 15, '.', 0, 10);
    textHDMIDrawChar(8, 16, '.', 0, 10);
    // 3. Draw Layer 2 (Hidden)
    for(int j=0; j<4; j++) textHDMIDrawColorText("(HIDDEN)", 33, hid_y[j], 0, 13);
    textHDMIDrawChar(36, 14, '.', 0, 13);
    textHDMIDrawChar(36, 15, '.', 0, 13);
    textHDMIDrawChar(36, 16, '.', 0, 13);
    // 4. Draw Layer 3 (Outputs)
    for(int k=0; k<10; k++) {
        textHDMIDrawColorText(out_labels[k], 60, out_y[k], 0, 11);
    }
    wait_for_button();
}

// Runs CPU inference on passed-in images
int cpu_inference(const uint8_t* image) {
    int32_t hidden[64] = {0}; // Initializes computational layers
    int32_t output[10] = {0};
    //Layer 1 computations
    for (int n = 0; n < 64; n++) {
        int32_t acc = 0;
        for (int p = 0; p < 784; p++) acc += image[p] * cpu_l1_weights[n][p]; //Continuously adds on pixels multiplied by weights
        hidden[n] = (acc > 0) ? (acc >> 8) : 0;
    }
    int best_pred = 0;
    //resets max_val so that a future accumulation can be larger
    int32_t max_val = -670000;
    //layer 2 computations
    for (int n = 0; n < 10; n++) {
        int32_t acc = 0;
        for (int h = 0; h < 64; h++) acc += hidden[h] * cpu_l2_weights[n][h];
        output[n] = acc;
        if (acc > max_val) { max_val = acc; best_pred = n; }
    }
    return best_pred;
}
//Runs the speed test for button 2
void run_race() {
    textHDMIColorClr();
    textHDMIDrawColorText("=== THE MATRIX SWEEP: INFERENCE THROUGHPUT ===", 15, 2, 0, 14);

    //60x20 grid = 1200 total inferences
    int GRID_W = 60;
    int GRID_H = 20;
    int START_X = 10;
    int START_Y = 8;
    int total_inferences = GRID_W * GRID_H;

    // Draw initial expected values
    for(int i = 0; i < total_inferences; i++) {
        int expected = benchmark_labels[i % 1000];
        textHDMIDrawChar(START_X + (i % GRID_W), START_Y + (i / GRID_W), expected + '0', 0, 8);
    }

    //Runs CPU inference on the images
    textHDMIDrawColorText("1. RISC-V CPU Sweep Ready. ", 10, 4, 0, 11);
    wait_for_button();
    textHDMIDrawColorText(">> CPU RUNNING...          ", 10, 4, 0, 12);

    u32 cpu_cycles = 0;
    int cpu_correct = 0;
    
    for(int i = 0; i < total_inferences; i++) {
        //Images are organized
        int img_idx = i % 1000;
        int expected = benchmark_labels[img_idx];

        // Timer is reset and starts running when inference starts
        XTmrCtr_Reset(&Timer, 0);
        XTmrCtr_Start(&Timer, 0);
        int pred = cpu_inference(benchmark_images[img_idx]);
        XTmrCtr_Stop(&Timer, 0); // Timer stops once inference stops
        cpu_cycles += XTmrCtr_GetValue(&Timer, 0); // Adds to running time count

        // Tracks accuracy and prints guessed numbers as either green or red
        if (pred == expected) {
            cpu_correct++;
            textHDMIDrawChar(START_X + (i % GRID_W), START_Y + (i / GRID_W), pred + '0', 0, 10); // Light Green
        } else {
            textHDMIDrawChar(START_X + (i % GRID_W), START_Y + (i / GRID_W), pred + '0', 0, 12); // Light Red
        }

        // Prints accuracy value
        if (i % 10 == 0 || i == total_inferences - 1) { // Runs every 10 inferences to save on performance
            int current_acc = (cpu_correct * 100) / (i + 1);
            textHDMIDrawColorText("Acc: ", 10, 5, 0, 15);
            textHDMIDrawColorText("    ", 15, 5, 0, 0);
            hdmi_print_int(current_acc, 15, 5, 0, 10);

            // Needed to draw percentage symbol in certain places depending on 3 or 2 digit number
            int offset = (current_acc == 100) ? 3 : (current_acc >= 10 ? 2 : 1);
            textHDMIDrawChar(15 + offset, 5, '%', 0, 15);
        }
    }

    u32 cpu_ms = cpu_cycles / 100000;
    textHDMIDrawColorText(">> CPU DONE! Time: ", 10, 4, 0, 11);
    hdmi_print_int(cpu_ms, 29, 4, 0, 15);
    textHDMIDrawColorText(" ms", 35, 4, 0, 11);

    //Preparing for NPU inference
    textHDMIDrawColorText("2. Hardware NPU Sweep Ready. ", 45, 4, 0, 10);
    textHDMIDrawColorText("Preparing DMA Buffers     ", 45, 5, 0, 8);
    
    //Format the 1000 images so that it can properly be stored in DDR3 and mitigate overflow
    u32 (*preformatted_images)[3136] = (u32 (*)[3136])(DDR3_BASEADDR + 0x02000000);
    for(int img = 0; img < 1000; img++) {
        for(int shift = 0; shift < 4; shift++) {
            for(int p = 0; p < 784; p++) {
                preformatted_images[img][(shift * 784) + p] = (u32)benchmark_images[img][p];
            }
        }
    }
    
    // Give images to DDR3
    Xil_DCacheFlushRange((UINTPTR)preformatted_images, 1000 * 3136 * 4);

    //Reprint expected values
    for(int i = 0; i < total_inferences; i++) {
        int expected = benchmark_labels[i % 1000];
        textHDMIDrawChar(START_X + (i % GRID_W), START_Y + (i / GRID_W), expected + '0', 0, 8);
    }

    textHDMIDrawColorText("                             ", 45, 5, 0, 0); // Clear preparation text
    wait_for_button();
    textHDMIDrawColorText(">> NPU RUNNING...            ", 45, 4, 0, 12);

    u32 npu_cycles = 0;
    int npu_correct = 0;
    // NPU inference starts
    for(int i = 0; i < total_inferences; i++) {
        int img_idx = i % 1000;
        int expected = benchmark_labels[img_idx];

        // Starts timer for NPU count
        XTmrCtr_Reset(&Timer, 0);
        XTmrCtr_Start(&Timer, 0);

        XAxiDma_Reset(&AxiDma);
        while(XAxiDma_ResetIsDone(&AxiDma) != 1);// Waits for DMA to reset
        Xil_Out32(NPU_BASEADDR, 0x00);
        for(volatile int d=0; d<50; d++);
        Xil_Out32(NPU_BASEADDR, 0x01);

        XAxiDma_SimpleTransfer(&AxiDma, (UINTPTR)preformatted_images[img_idx], 12544, XAXIDMA_DMA_TO_DEVICE); // Transfers images from DDR3 to NPU
        while((Xil_In32(NPU_BASEADDR + 4) & 0x01) == 0);// Waits for done flag to be asserted in status register of NPU

        XTmrCtr_Stop(&Timer, 0); // Stops timer once inference has been made
        npu_cycles += XTmrCtr_GetValue(&Timer, 0);

        int pred = (Xil_In32(NPU_BASEADDR + 4) >> 4) & 0x0F; // Recieves the guess from direct communication with status register

        // Tracks accuracy, draws correct guesses in yellow, incorrect in red
        if (pred == expected) {
            npu_correct++;
            textHDMIDrawChar(START_X + (i % GRID_W), START_Y + (i / GRID_W), pred + '0', 0, 14); // Yellow
        } else {
            textHDMIDrawChar(START_X + (i % GRID_W), START_Y + (i / GRID_W), pred + '0', 0, 12); // Light Red
        }

        //Updates accuracy live
        if (i % 10 == 0 || i == total_inferences - 1) {
            int current_acc = (npu_correct * 100) / (i + 1);
            textHDMIDrawColorText("Acc: ", 45, 5, 0, 15);
            textHDMIDrawColorText("    ", 50, 5, 0, 0); 
            hdmi_print_int(current_acc, 50, 5, 0, 14);

            int offset = (current_acc == 100) ? 3 : (current_acc >= 10 ? 2 : 1);
            textHDMIDrawChar(50 + offset, 5, '%', 0, 15);
        }
    }

    u32 npu_ms = npu_cycles / 100000;
    if (npu_ms == 0) npu_ms = 1; // prevents undefined from happening

    textHDMIDrawColorText(">> NPU DONE! Time: ", 45, 4, 0, 10);
    hdmi_print_int(npu_ms, 64, 4, 0, 15);
    textHDMIDrawColorText(" ms", 68, 4, 0, 10);

    // Prints results and calculates speed factor
    textHDMIDrawColorText("HARDWARE SPEEDUP MULTIPLIER:", 22, 30, 0, 15);
    int speedup = (cpu_cycles) / npu_cycles;
    hdmi_print_int(speedup, 51, 30, 0, 10);
    textHDMIDrawColorText("x FASTER", 57, 30, 0, 10);

    wait_for_button();
}

// Interactive demo portion
void run_guess_a_sketch() {
    textHDMIColorClr();
    textHDMIDrawColorText(" LIVE INFERENCE CANVAS ", 26, 1, 0, 10);
    textHDMIDrawColorText("Awaiting Mouse Input", 14, 32, 0, 15);
    textHDMIDrawColorText("Press BTN 1 or 'Q' in Python to quit.", 20, 34, 0, 8);

    uint8_t canvas[28][28] = {0};
    int use_npu = 1;

    //Draws parts of the UI
    textHDMIDrawColorText("ACTIVE BRAIN:", 56, 10, 0, 15);
    textHDMIDrawColorText("HARDWARE NPU [FAST] ", 56, 11, 0, 10);
    textHDMIDrawColorText("[BTN 2] Toggle Brain", 56, 12, 0, 11);
    // Draws 28x28 canvas
    for(int i=-1; i<29; i++) {
        textHDMIDrawChar(26-1, 3+i, '|', 0, 8);
        textHDMIDrawChar(26+28, 3+i, '|', 0, 8);
        textHDMIDrawChar(26+i, 3-1, '-', 0, 8);
        textHDMIDrawChar(26+i, 3+28, '-', 0, 8);
    }

    while(1) {
        // Continuously polls for buttons
        u32 current_btns = XGpio_DiscreteRead(&Buttons, 1);

        // Button 1: Quit
        if ((current_btns & 0b001) != 0) {
            while(XGpio_DiscreteRead(&Buttons, 1) != 0);
            break;
        }

        // Handles the toggle between processors
        if ((current_btns & 0b010) != 0) {
            while(XGpio_DiscreteRead(&Buttons, 1) != 0); // Debounce
            use_npu = !use_npu;

            if(use_npu) {
                textHDMIDrawColorText("HARDWARE NPU [FAST] ", 56, 11, 0, 10);
            } else {
                textHDMIDrawColorText("MICROBLAZE CPU [LAG]", 56, 11, 0, 12);
            }
        }

        // Polls for an image from python script
        if (!XUartLite_IsReceiveEmpty(UART_BASEADDR)) {
            uint8_t input = (uint8_t)XUartLite_ReadReg(UART_BASEADDR, XUL_RX_FIFO_OFFSET);

            if (input == 'q') break;

            if (input == 0xAA) {
                while(XUartLite_IsReceiveEmpty(UART_BASEADDR));
                if ((uint8_t)XUartLite_ReadReg(UART_BASEADDR, XUL_RX_FIFO_OFFSET) == 0xBB) {

                    // catches bytes that are being sent in 
                    for(int y=0; y<28; y++) {
                        for(int x=0; x<28; x++) {
                            while(XUartLite_IsReceiveEmpty(UART_BASEADDR));
                            canvas[y][x] = (uint8_t)XUartLite_ReadReg(UART_BASEADDR, XUL_RX_FIFO_OFFSET);
                        }
                    }

                    // Translates the image into display
                    for(int y=0; y<28; y++) {
                        for(int x=0; x<28; x++) {
                            char c = canvas[y][x] > 0 ? '#' : '.';
                            uint8_t fg = canvas[y][x] > 0 ? 15 : 8;
                            textHDMIDrawChar(26+x, 3+y, c, 0, fg);
                        }
                    }
                    
                    textHDMIDrawColorText(">> THINKING... <<   ", 56, 14, 0, 14);

                    // Reformats the canvas so stuff is centered correctly
                    long sum_x = 0, sum_y = 0, total_mass = 0;
                    for(int y=0; y<28; y++) {
                        for(int x=0; x<28; x++) {
                            if (canvas[y][x] > 0) {
                                sum_x += x * canvas[y][x];
                                sum_y += y * canvas[y][x];
                                total_mass += canvas[y][x];
                            }
                        }
                    }

                    int offset_x = 0, offset_y = 0; 
                    if (total_mass > 0) { // Calculates shift offset for proper centering
                        offset_x = 13 - (sum_x / total_mass);
                        offset_y = 13 - (sum_y / total_mass);
                    }

                    uint8_t temp[28][28] = {0};
                    for(int y=0; y<28; y++) {
                        for(int x=0; x<28; x++) { // Shifts the canvas by the calculated offset value
                            int orig_x = x - offset_x;
                            int orig_y = y - offset_y;
                            if (orig_x >= 0 && orig_x < 28 && orig_y >= 0 && orig_y < 28) {
                                temp[y][x] = canvas[orig_y][orig_x];
                            }
                        }
                    }
                    for(int y=0; y<28; y++) for(int x=0; x<28; x++) canvas[y][x] = temp[y][x];

                    int pred = 0;

                    if (use_npu) {// Performs inference with the NPU, follows same protocol as described and used above but without timers
                        u32* tx_ptr = (u32*)IMAGE_BUFFER_ADDR;
                        for(int shift = 0; shift < 4; shift++) {
                            for(int y=0; y<28; y++) {
                                for(int x=0; x<28; x++) {
                                    tx_ptr[(shift * 784) + (y*28 + x)] = canvas[y][x];
                                }
                            }
                        }
                        Xil_DCacheFlushRange((UINTPTR)tx_ptr, 12544);
                        XAxiDma_Reset(&AxiDma);
                        while(XAxiDma_ResetIsDone(&AxiDma) != 1);
                        Xil_Out32(NPU_BASEADDR, 0x00);
                        for(volatile int i=0; i<5000; i++);
                        Xil_Out32(NPU_BASEADDR, 0x01);
                        XAxiDma_SimpleTransfer(&AxiDma, (UINTPTR)tx_ptr, 12544, XAXIDMA_DMA_TO_DEVICE);
                        while((Xil_In32(NPU_BASEADDR + 4) & 0x01) == 0);
                        pred = (Xil_In32(NPU_BASEADDR + 4) >> 4) & 0x0F;
                    } else {// Performs inference on CPU
                        uint8_t flat_image[784];
                        for(int y=0; y<28; y++) {
                            for(int x=0; x<28; x++) {
                                flat_image[(y*28) + x] = canvas[y][x];
                            }
                        }
                        pred = cpu_inference(flat_image);
                    }

                    //Output prediction
                    textHDMIDrawColorText("                    ", 56, 14, 0, 0);
                    textHDMIDrawColorText("I SEE A: ", 60, 16, 0, 15);
                    hdmi_print_int(pred, 69, 16, 0, 10);

                    // Makes sure python script knows that the image was recieved
                    Xil_Out32(UART_BASEADDR + 0x04, 0xFF);
                }
            }
        }
    }
}

int main() {
    init_platform();
    Xil_DCacheDisable(); //Disables cache in memory 
    for (int i = 0; i < 16; i++) setColorPalette(i, colors[i].red, colors[i].green, colors[i].blue);
    // Initializes DMA and GPIO settings
    XAxiDma_Config *dma_cfg = XAxiDma_LookupConfig(XPAR_AXI_DMA_0_DEVICE_ID);
    XAxiDma_CfgInitialize(&AxiDma, dma_cfg);
    XGpio_Initialize(&Buttons, XPAR_AXI_GPIO_0_DEVICE_ID);
    XGpio_SetDataDirection(&Buttons, 1, 0xFFFFFFFF);
    XTmrCtr_Initialize(&Timer, XPAR_TMRCTR_0_DEVICE_ID);

    while(1) { // Active program loop 
        draw_menu();//Draw menu handles the GUI loop
        u32 btn_state = 0;

        //Polls for buttons and decides what to do when buttons are hit
        while(btn_state == 0) btn_state = XGpio_DiscreteRead(&Buttons, 1);
        while(XGpio_DiscreteRead(&Buttons, 1) != 0);

        if ((btn_state & 0b001) != 0) run_slideshow();
        else if ((btn_state & 0b010) != 0) run_race();
        else if ((btn_state & 0b100) != 0) run_guess_a_sketch();

        while(XGpio_DiscreteRead(&Buttons, 1) != 0);
    }
    cleanup_platform();
    return 0;
}
