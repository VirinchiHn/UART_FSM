
module uart_rx(
    input clk_3125,
    input rx,
    output reg [7:0] rx_msg,
    output reg rx_parity,
    output reg rx_complete
);

//////////////////DO NOT MAKE ANY CHANGES ABOVE THIS LINE//////////////////

// Initialize outputs
initial begin
    rx_msg      = 8'b0;
    rx_parity   = 1'b0;
    rx_complete = 1'b0;
end

// UART timing
localparam BAUD_COUNT = 5'd26;        // 27 clock cycles per bit
localparam HALF_BAUD  = 5'd13;        // 13 cycles (mid-bit sampling)

// FSM states
localparam s_IDLE      = 3'd0;
localparam s_START     = 3'd1;
localparam s_DATA      = 3'd2;
localparam s_PARITY    = 3'd3;
localparam s_STOP      = 3'd4;
localparam s_DONE      = 3'd5;

reg [2:0] state = s_IDLE;
reg [4:0] clk_count = 0;
reg [2:0] bit_idx = 0;
reg [7:0] shift_reg = 0;
reg parity_calc = 0;   // even parity accumulator
reg parity_error;
reg rx_parity_stored;


always @(posedge clk_3125) begin
    rx_complete <= 1'b0;

    case(state)

        s_IDLE: begin
            clk_count <= 0;
            bit_idx   <= 0;
            parity_calc <= 0;      // reset parity tracking

            if(rx == 1'b0) begin   // start bit detected
                state <= s_START;
					 clk_count <= 0;
            end
        end

        s_START: begin
            if(clk_count < BAUD_COUNT-1)
                clk_count <= clk_count + 1;
            else begin
                clk_count <= 0;
                state <= s_DATA;
            end
        end

        s_DATA: begin
            if(clk_count < BAUD_COUNT)
                clk_count <= clk_count + 1;

            else begin
                clk_count <= 0;

                shift_reg[7-bit_idx] <= rx;     // LSB-first
                parity_calc <= parity_calc ^ rx; // accumulate even parity

                if(bit_idx < 7)
                    bit_idx <= bit_idx + 1;
                else begin
                    bit_idx <= 0;
                    state <= s_PARITY;
                end
            end
        end

       /* // ------------------- PARITY BIT -------------------
        s_PARITY: begin
            if(clk_count < BAUD_COUNT)
                clk_count <= clk_count + 1;
            else begin
                clk_count <= 0;

                // Compare expected parity with received parity bit
                rx_parity <= (parity_calc == rx);

                state <= s_STOP;
            end
        end
		  */
        s_PARITY: begin
            if(clk_count < BAUD_COUNT)
                clk_count <= clk_count + 1;
            else begin
                clk_count <= 0;

                rx_parity_stored <= rx;                 // store actual parity bit
                parity_error <= (parity_calc != rx);   // internal check

                state <= s_STOP;
            end
        end

        s_STOP: begin
            if(clk_count < BAUD_COUNT-1)
                clk_count <= clk_count + 1;
            else begin
                clk_count <= 0;

                state <= s_DONE;
            end
        end

        s_DONE: begin
             rx_complete <= 1'b1;
             rx_msg <= shift_reg;
				 rx_parity <= parity_calc;
             state <= s_IDLE;   
		  end	
		  default:
        begin

                state <= s_IDLE;
            
		  end

    endcase
end

//////////////////DO NOT MAKE ANY CHANGES BELOW THIS LINE//////////////////

endmodule

