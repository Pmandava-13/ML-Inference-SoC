/*
Initializes 16 mac cores. While only 10 are technically necessary, 16 cores makes math for Layer 1 make more sense and makes overall
slicing of bits easier.
Passes in 16 weights at a time, each 32 bits. Then we split these weights into each core for the math. 

*/
`timescale 1ns/ 1ps
module mac_unit(
    input logic clk,
    input logic reset,
    input logic clr,
    input logic en,
    input logic [511:0] weights,
    input logic [31:0] pixel, 
    
    output logic [63:0] accumulator [0:15]
);

// pixel_pad so that it turns pixel into a signed value
logic signed [31:0] pixel_pad; 
assign pixel_pad = pixel;

//initialize the mac core, the weights are read from left to right from the coe file.
mac_core core_0(.clk(clk), .reset(reset), .clr(clr), .en(en),.weight(weights[511:480]), .pixels(pixel_pad), .accumulation(accumulator[0]));
mac_core core_1(.clk(clk), .reset(reset), .clr(clr), .en(en),.weight(weights[479:448]), .pixels(pixel_pad), .accumulation(accumulator[1]));
mac_core core_2(.clk(clk), .reset(reset), .clr(clr), .en(en),.weight(weights[447:416]), .pixels(pixel_pad), .accumulation(accumulator[2]));
mac_core core_3(.clk(clk), .reset(reset), .clr(clr), .en(en),.weight(weights[415:384]), .pixels(pixel_pad), .accumulation(accumulator[3]));
mac_core core_4(.clk(clk), .reset(reset), .clr(clr), .en(en),.weight(weights[383:352]), .pixels(pixel_pad), .accumulation(accumulator[4]));
mac_core core_5(.clk(clk), .reset(reset), .clr(clr), .en(en),.weight(weights[351:320]), .pixels(pixel_pad), .accumulation(accumulator[5]));
mac_core core_6(.clk(clk), .reset(reset), .clr(clr), .en(en),.weight(weights[319:288]), .pixels(pixel_pad), .accumulation(accumulator[6]));
mac_core core_7(.clk(clk), .reset(reset), .clr(clr), .en(en),.weight(weights[287:256]), .pixels(pixel_pad), .accumulation(accumulator[7]));
mac_core core_8(.clk(clk), .reset(reset), .clr(clr), .en(en),.weight(weights[255:224]), .pixels(pixel_pad), .accumulation(accumulator[8]));
mac_core core_9(.clk(clk), .reset(reset), .clr(clr), .en(en),.weight(weights[223:192]), .pixels(pixel_pad), .accumulation(accumulator[9]));
mac_core core_10(.clk(clk), .reset(reset), .clr(clr), .en(en),.weight(weights[191:160]), .pixels(pixel_pad), .accumulation(accumulator[10]));
mac_core core_11(.clk(clk), .reset(reset), .clr(clr), .en(en),.weight(weights[159:128]), .pixels(pixel_pad), .accumulation(accumulator[11]));
mac_core core_12(.clk(clk), .reset(reset), .clr(clr), .en(en),.weight(weights[127:96]), .pixels(pixel_pad), .accumulation(accumulator[12]));
mac_core core_13(.clk(clk), .reset(reset), .clr(clr), .en(en),.weight(weights[95:64]), .pixels(pixel_pad), .accumulation(accumulator[13]));
mac_core core_14(.clk(clk), .reset(reset), .clr(clr), .en(en),.weight(weights[63:32]), .pixels(pixel_pad), .accumulation(accumulator[14]));
mac_core core_15(.clk(clk), .reset(reset), .clr(clr), .en(en),.weight(weights[31:0]), .pixels(pixel_pad), .accumulation(accumulator[15]));
endmodule