
module t2a_dht(
    input clk_50M,
    input reset,
    inout sensor,
    output reg [7:0] T_integral,
    output reg [7:0] RH_integral,
    output reg [7:0] T_decimal,
    output reg [7:0] RH_decimal,
    output reg [7:0] Checksum,
    output reg data_valid
);

    initial begin
        T_integral = 0;
        RH_integral = 0;
        T_decimal = 0;
        RH_decimal = 0;
        Checksum = 0;
        data_valid = 0;
    end
//////////////////DO NOT MAKE ANY CHANGES ABOVE THIS LINE //////////////////

/*
Add your logic here
*/

/*
Add your logic here
*/

/*
Add your logic here
*/

localparam CLK_FREQ = 50000000;
localparam START_LOW_CYCLES = (18 * CLK_FREQ) / 1000;
localparam START_HIGH_CYCLES = (40 * CLK_FREQ) / 1000000;
localparam ACK_CYCLES = (80 * CLK_FREQ) / 1000000;
localparam READ_LOW_CYCLES = (50 * CLK_FREQ) / 1000000;
localparam READ_HIGH_CYCLES = (26 * CLK_FREQ) / 1000000;

localparam IDLE = 4'b0000;
localparam START_LOW = 4'b0001;
localparam START_HIGH = 4'b0010;
localparam ACK_LOW = 4'b0011;
localparam ACK_HIGH = 4'b0100;
localparam READ_LOW = 4'b0101;
localparam READ_HIGH = 4'b0110;
localparam S_VALIDATION = 4'b0111;
localparam WAIT1 = 4'b1000;
localparam WAIT2 = 4'b1001;
localparam WAIT3 = 4'b1010;
// Add more states here later

reg [3:0] state; // No next_state needed in this style
reg [19:0] timer;
reg [5:0] bit_counter;
reg [39:0] data_buffer;
reg en;
reg write;


assign sensor = en ? write : 1'bz;

wire read;
wire [7:0] calc_checksum;
assign calc_checksum = data_buffer[39:32] + data_buffer[31:24] + data_buffer[23:16] + data_buffer[15:8];
assign read = sensor;


	

always @(posedge clk_50M or negedge reset) begin
    if(!reset) begin
        state <= IDLE;
        timer <= 0;
		  bit_counter <= 0;
        en <= 0;
        write <= 1'b1;
		  
    end
    else begin
        case(state)
				IDLE: begin
                en <= 0; // Release bus
                if (timer >= 4 - 1) begin
                     state <= START_LOW;
                     timer <= 0;
							data_valid = 0;
							
							bit_counter <= 0;
                end else begin
                     timer <= timer + 1;
                end
            end
            START_LOW: begin
                en <= 1; write <= 0; // Output LOW
                
                // Your requested structure: Timer inside the case
                if(timer >= START_LOW_CYCLES - 1) begin
                    state <= START_HIGH;
						  
                    timer <= 0; // MUST reset timer when changing state
                end
                else begin
                    timer <= timer + 1;
                end
            end

            START_HIGH: begin
                en <= 1; write <= 1; // Output HIGH
                
                if(timer >= START_HIGH_CYCLES - 1) begin
                    // Next state will be waiting for response...
                    // state <= WAIT_RESPONSE; 
                    state <= ACK_LOW; // Placeholder loop for now
                    timer <= 0;
						  en <= 0;// MUST reset timer when changing state
						  
                end
                else begin
                    timer <= timer + 1;
                end
            end
//				ACK_LOW: begin
//					if(!read) begin
//					
//						if(timer >= ACK_CYCLES - 1) begin
//							state <= ACK_HIGH;
//							timer <= 0;
//
//						end
//						else begin
//							timer <= timer + 1;
//
//						end
//					end
//				end
//				ACK_HIGH: begin
//					if(read) begin
//						if(timer >= ACK_CYCLES - 1) begin
//							state <= READ_LOW;
//							timer <= 0;
//						end
//						else begin
//							timer <= timer + 1;
//						end
//					end
//				end
//				READ_LOW: begin
//					if(!read) begin
//						if(timer >= READ_LOW_CYCLES - 1) begin
//							state <= READ_HIGH;
//							timer <= 0;
//						end
//						else begin						
//							timer <= timer + 1;						
//						end
//					end
//				end
//				READ_HIGH: begin
//					if(read) begin
//						timer <= timer + 1;
//					end
//					else begin
//						// ... data shifting ...
//						data_buffer <= {data_buffer[38:0], (timer > READ_HIGH_CYCLES)}; // NOTE: USE A BETTER THRESHOLD HERE! 26us IS RISKY.
//						timer <= 1;
//
//						// FIX: Check for 39, not 40, because we are currently processing bit #40 (index 39)
//						if(bit_counter >= 39) begin
//							state <= S_VALIDATION;
//							bit_counter <= 0; // Reset for next time
//						end
//						else begin
//							bit_counter <= bit_counter + 1;
//							state <= READ_LOW;
//						end
//					end
//				end
				WAIT1: begin
					state <= WAIT2;

				end
				WAIT2: begin
					state <= S_VALIDATION;
				end
				WAIT3: begin
					state <= IDLE;
					data_valid <= 0;
				end
				S_VALIDATION: begin
					      // Check if the sum of the first 4 bytes equals the checksum byte
					state <= WAIT3;
					RH_integral <= data_buffer[39:32];
					RH_decimal  <= data_buffer[31:24];
					T_integral  <= data_buffer[23:16];
					T_decimal   <= data_buffer[15:8];
					Checksum    <= data_buffer[7:0];
					if (calc_checksum == data_buffer[7:0]) begin
						data_valid <= 1; // Set valid flag only on success
					end
					

                    // If checksum fails, outputs are not updated and data_valid remains 0
				end
				ACK_LOW: begin
					
               // Wait for Sensor to release the line (go HIGH) after its 80us LOW presence pulse
					
					if(read == 1 && timer != 0) begin
						state <= ACK_HIGH;
						timer <= 0;
					end
					
               // Handle timeout if sensor is missing

               
               else begin
						timer <= timer + 1;
						if(timer > ACK_CYCLES + 5) begin
							state <= WAIT3;
							timer <= 0;
						end
					end
               
            end
            ACK_HIGH: begin
               // Wait for Sensor to pull line LOW to start the first data bit
               if(read == 0) begin
                   state <= READ_LOW;
                   timer <= 1;
               end
               else begin
                   timer <= timer + 1;
               end
            end
            READ_LOW: begin
               // Wait for rising edge (start of HIGH data pulse)
               if(read == 1) begin
                   state <= READ_HIGH;
                   timer <= 1;
               end
               else begin
                   timer <= timer + 1;
               end
            end
            READ_HIGH: begin
               if(read == 1) begin
                   
                   timer <= timer + 1;
               end
               else begin
                   data_buffer <= {data_buffer[38:0], (timer > 1350)};
                   timer <= 1;

                   if(bit_counter >= 39) begin
							  timer <= 0;
                       state <= WAIT1;
                       bit_counter <= 0;
                   end
                   else begin
                       bit_counter <= bit_counter + 1;
                       state <= READ_LOW;
                   end
               end
            end
				
				
            
            default: state <= IDLE;
        endcase
    end
end



//////////////////DO NOT MAKE ANY CHANGES BELOW THIS LINE //////////////////
  
endmodule
