/*
the mac_core is used as an mulitplication- accumulation core to multiply a 32 bit weight value against a 64 signed pixel value. 
Products are continuously summed and stored into the accumulation register. Accumulation is only running if enable is high.
*/


`timescale 1ns/ 1ps
module mac_core(
    input logic clk,
    input logic reset,
    input logic clr, //clear
    input logic en,  //enable bit
    input logic signed [31:0] weight,
    input logic signed [63:0] pixels,

    output logic signed [63:0] accumulation
);

    always_ff @(posedge clk) begin
        if (reset || clr) begin //0's accumulation if reset or clear are on
            accumulation <= 64'sd0;
        end
        else if (en) begin
            accumulation <= accumulation + (weight * pixels);
        end
    end
endmodule