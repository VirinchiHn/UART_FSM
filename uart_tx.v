
// MazeSolver Bot: Task 2B - UART Transmitter
/*
Instructions
-------------------
Students are not allowed to make any changes in the Module declaration.

This file is used to generate UART Tx data packet to transmit the messages based on the input data.

Recommended Quartus Version : 20.1
The submitted project file must be 20.1 compatible as the evaluation will be done on Quartus Prime Lite 20.1.

Warning: The error due to compatibility will not be entertained.
-------------------
*/

/*
Module UART Transmitter

Input:  clk_3125 - 3125 KHz clock
        parity_type - even(0)/odd(1) parity type
        tx_start - signal to start the communication.
        data    - 8-bit data line to transmit

Output: tx      - UART Transmission Line
        tx_done - message transmitted flag


        Baudrate : 115200 bps
*/

// module declaration
module uart_tx(
    input clk_3125,
    input parity_type,tx_start,
    input [7:0] data,
    output reg tx, tx_done
);

initial begin
    tx = 1'b1;
    tx_done = 1'b0;
end
//////////////////DO NOT MAKE ANY CHANGES ABOVE THIS LINE//////////////////
 
 /*  Add your logic here */
 
     // --- State Machine Definitions ---
    // We need 6 states for the transmission process
    localparam s_IDLE 		= 3'd0; // Waiting for tx_start
    localparam s_START_BIT 	= 3'd1; // Sending the start bit (0)
    localparam s_DATA_BITS 	= 3'd2; // Sending the 8 data bits
    localparam s_PARITY_BIT 	= 3'd3; // Sending the parity bit
    localparam s_STOP_BIT 	= 3'd4; // Sending the stop bit (1)
    localparam s_TX_DONE 	= 3'd5; // Pulsing tx_done high for one cycle

    // --- Baud Rate Timer ---
    // Clock Freq = 3.125 MHz, Baud Rate = 115200
    // Cycles per bit = 3,125,000 / 115,200 = 27.126
    // We will use 27 clock cycles, which gives a bit duration of 27 * 320ns = 8640ns
    // This matches the "ideal value" from the task description.
    // We need a counter that counts from 0 to 26 (27 cycles).
    localparam BAUD_COUNT = 5'd26;

    // --- Internal Registers ---
    reg [2:0] state = s_IDLE; // State register for the FSM, initialized to IDLE
    
    // Counter for the 27-cycle bit duration
    reg [4:0] bit_clk_counter = 5'd0; // Needs 5 bits to count to 26
    
    // Counter for the 8 data bits (0 to 7)
    reg [2:0] bit_counter = 3'd0; // Needs 3 bits to count to 7

    // Internal registers to latch the input data when transmission starts
    reg [7:0] data_reg;
    reg parity_bit_reg; // Stores the calculated parity bit
    
    // Main logic block, sensitive to the positive edge of the clock
    always @(posedge clk_3125)
    begin
        // Default tx_done to 0. It will only be high for one cycle in the s_TX_DONE state.
        tx_done <= 1'b0;

        case (state)
            
            // --- IDLE State ---
            // Wait for the tx_start signal. Keep the tx line high (idle).
            s_IDLE:
            begin
                tx <= 1'b1; // UART line is high when idle
                bit_clk_counter <= 5'd0; // Reset counters
                bit_counter <= 3'd0;

                if (tx_start == 1'b1)
                begin
                    // Latch the input data and parity type
                    data_reg <= data;
                    
                    // Calculate and latch the parity bit
                    // For even (0), parity bit is 1 if data has odd 1s (^data = 1)
                    // For odd (1), parity bit is 1 if data has even 1s (~^data = 1)
                    if (parity_type == 1'b0) // Even parity
                        parity_bit_reg <= ^data; // XOR reduction
                    else // Odd parity
                        parity_bit_reg <= ~^data; // XNOR reduction
                        
                    state <= s_START_BIT; 
						  tx <= 1'b0;// Move to next state
                end
                else
                begin
                    state <= s_IDLE;
						  
                end
            end
            
            // --- START_BIT State ---
            // Send the '0' start bit for one full bit duration (27 cycles).
            s_START_BIT:
            begin
                 // Start bit is active low

                // Wait for one bit-period
                if (bit_clk_counter < BAUD_COUNT - 1)
                begin
                    bit_clk_counter <= bit_clk_counter + 1;
                end
                else // 27 cycles have passed
                begin
                    bit_clk_counter <= 5'd0; // Reset counter for the next bit
                    state <= s_DATA_BITS; // Move to data transmission
                end
            end

            // --- DATA_BITS State ---
            // Send all 8 data bits, MSB first.
            s_DATA_BITS:
            begin
                // ** MSB-First Logic **
                // When bit_counter = 0, send data_reg[7]
                // When bit_counter = 7, send data_reg[0]
                tx <= data_reg[7 - bit_counter];

                // Wait for one bit-period
                if (bit_clk_counter < BAUD_COUNT)
                begin
                    bit_clk_counter <= bit_clk_counter + 1;
                end
                else // 27 cycles have passed
                begin
                    bit_clk_counter <= 5'd0; // Reset baud counter
                    
                    if (bit_counter < 3'd7) // Check if we've sent all 8 bits
                    begin
                        bit_counter <= bit_counter + 1; // Move to the next bit
                        state <= s_DATA_BITS; 
                    end
						  
                    else 
                    begin
                        bit_counter <= 3'd0; 
                        state <= s_PARITY_BIT; 
                    end
                end
            end


            s_PARITY_BIT:
            begin
                tx <= parity_bit_reg;


                if (bit_clk_counter < BAUD_COUNT)
                begin
                    bit_clk_counter <= bit_clk_counter + 1;
                end
                else 
                begin
                    bit_clk_counter <= 5'd0;
                    state <= s_STOP_BIT; 
                end
            end
            

            s_STOP_BIT:
            begin
                tx <= 1'b1; 


                if (bit_clk_counter < BAUD_COUNT - 1)
                begin
                    bit_clk_counter <= bit_clk_counter + 1;
                end
                else // 27 cycles have passed
                begin
                    bit_clk_counter <= 5'd0;
                    state <= s_TX_DONE; // Move to done state
                end
            end
            

            s_TX_DONE:
            begin
                tx_done <= 1'b1;
                state <= s_IDLE; // Go back to IDLE
            end


            default:
            begin
                tx <= 1'b1;
                tx_done <= 1'b0;
                state <= s_IDLE;
            end
            
        endcase
    end

//////////////////DO NOT MAKE ANY CHANGES BELOW THIS LINE//////////////////

endmodule