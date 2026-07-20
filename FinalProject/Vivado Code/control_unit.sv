/*
The control unit makes the state machine that the NPU runs on. This handles the AXi-stream handshaking to receive pixels,
determines when the MAC units perform, and manages the BRAM addressing to feed the correct weights. There are two layers in this
neural network, so we had to account for this in our control unit. Layer 1 takes in 784 pixels and outputs 64 hidden nodes by multiplying     
each pixel by weights. In Layer 2, these 64 hidden nodes are used to make 10 probabilites where the most probabilistic output 
is the result. 

*/
`timescale 1ns/ 1ps
module control(
    input  logic clk,
    input  logic reset,

    // dma
    input  logic [7:0]  axi_tdata,
    input  logic        axi_tvalid,
    output logic        axi_tready,

    // microblaze
    input  logic        start_npu,
    output logic        done_npu,
    output logic [3:0]  predict, //prediction

    // bram
    output logic [15:0] bram_raddr,
    
    // mac
    input  logic [63:0] accumulations [0:15],
    output logic        mac_en,
    output logic        mac_clr,
    output logic [31:0] mac_pixel //uses 32 bit calculation for layer 2 calculations
);

    enum logic[3:0] {
        IDLE, //waits for the start_npu trigger
        L1_RUN, // Receives the 784 pixels and multiplies them by the l1 weights to produce 16 hidden nodes at once.
         L1_DRAIN, //Waits an extra clock cycle to let the final MAC calculations clear pipeline
         L1_NEXT,   // zeroes negative numbers, and increments the shift counter to process the next 16 nodes. "ReLU activation"
        L2_RUN, //feeds the 64 hidden nodes back into the MAC and multiplies them by l2 weights to generate 10 final possibilities
         L2_DRAIN, //waits for MAC to clear the pipeline
          L2_MAX,  //applies the ARGmax, finds the index with the highest value from the 10 accumulators.
          DONE
    } curr_state, next_state;

    logic [9:0] pixel_count;  //2^10 for 784 count
    logic [1:0] shift_count; //4 shifts to create 64 nodes
    logic [5:0] node_count; 
    logic [63:0] node_hold [0:63]; //holds the values for hidden nodes.

    //these signals delay pixel and enable by a clock cycle to account for the 1 cycle read latency when reading from the BRAM. 
    //synchronizes the pixel and weight coming into the mac.
    logic [31:0] pixel_delay;  
    logic        en_delay;

    logic [3:0]  max_counter; //argmax counter
    logic signed [63:0] max_val_reg; //index with the highest value

    //calculates bram address; calculates layer 1 based on the shift count and pixel count
    //calculates layer 2 by jumping pasts all the layer 1 weights and increments per hidden node.
    assign bram_raddr = (curr_state == L1_RUN) ? ( (shift_count * 784) + pixel_count ) : (16'd3136 + node_count);

    always_comb begin
        axi_tready = 1'b0;
        mac_clr    = 1'b0;
        done_npu   = 1'b0;

        mac_pixel  = pixel_delay; 
        mac_en     = en_delay;

        unique case(curr_state)
            IDLE:    mac_clr = 1'b1;
            L1_RUN:  axi_tready = 1'b1;  //ready to receive pixel
            L1_NEXT: mac_clr = 1'b1; //clear mac for next shift
            DONE:    done_npu = 1'b1; //inference complete
            default: ;
        endcase
    end


    always_comb begin
        next_state = curr_state;
        unique case(curr_state)
            IDLE:   if (start_npu) next_state = L1_RUN; 
            L1_RUN: if (axi_tvalid && pixel_count == 783) next_state = L1_DRAIN; //stays in l1_run until all pixels have been processed
            L1_DRAIN: next_state = L1_NEXT; // 1 cycle delay
            L1_NEXT: begin //moves to l2 after all shifts are complete
                if (shift_count == 3) next_state = L2_RUN;
                else next_state = L1_RUN;
            end
            L2_RUN: if (node_count == 63) next_state = L2_DRAIN; //stays in l2_run until all pixels have been processed
            L2_DRAIN: next_state = L2_MAX;  // 1 cycle delay
            L2_MAX: begin
            //moves on after all 64 nodes are processed
                if (max_counter == 4'd9) next_state = DONE;
                else next_state = L2_MAX;
            end
            DONE:   if (~start_npu) next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            curr_state  <= IDLE;
            pixel_count <= 10'd0;
            shift_count <= 2'd0;
            node_count  <= 6'd0;
            predict     <= 4'd0;
            pixel_delay <= 32'd0;
            en_delay    <= 1'b0;
            max_counter <= 4'd0;
            max_val_reg <= 64'h8000000000000000;
        end else begin
            curr_state <= next_state;
            en_delay <= 1'b0;

            case (curr_state)
                IDLE: begin
                    pixel_count <= 10'd0;
                    shift_count <= 2'd0;
                    node_count  <= 6'd0;
                end

                L1_RUN: begin
                //sign extend the 8 bit value to 32 bits and delays for 1 cycle
                    if (axi_tvalid) begin
                        pixel_delay <= {24'd0, axi_tdata};
                        en_delay    <= 1'b1;
                        if (pixel_count < 783) pixel_count <= pixel_count + 1;
                    end
                end

                L1_DRAIN: begin
                end

                L1_NEXT: begin
                //apply ReLU activation by removing all negative values and replacing them with 0
                    for (int i = 0; i < 16; i++) begin
                        node_hold[(shift_count * 16) + i] <= (accumulations[i][63]) ? 64'd0 : accumulations[i];
                    end
                    pixel_count <= 10'd0;
                    if (shift_count < 3) shift_count <= shift_count + 1;
                end

                L2_RUN: begin
                    //passes the hidden nodes back into mac
                    //excludes the 8 least valuable bits to scale down the accumulation values
                    pixel_delay <= node_hold[node_count][39:8];
                    en_delay    <= 1'b1;
                    if (node_count < 63) node_count <= node_count + 1;
                end

                L2_DRAIN: begin
                    max_counter <= 4'd0;
                    max_val_reg <= 64'h8000000000000000;
                    predict     <= 4'd0;
                end

                L2_MAX: begin
                //argmax function; loops through the 10 values and picks the highest one.
                    if ($signed(accumulations[max_counter]) > max_val_reg) begin
                        max_val_reg <= accumulations[max_counter];
                        predict     <= max_counter;
                    end
                    if (max_counter < 4'd9) begin
                        max_counter <= max_counter + 4'd1;
                    end
                end
            endcase
            
        end
    end
endmodule