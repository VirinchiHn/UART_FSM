
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

    // ---- State encoding (replaces enum) ----
    parameter IDLE           = 4'd0;
    parameter START_LOW      = 4'd1;
    parameter START_HIGH     = 4'd2;
    parameter WAIT_RESP_LOW  = 4'd3;
    parameter WAIT_RESP_HIGH = 4'd4;
    parameter READ_BIT_LOW   = 4'd5;
    parameter READ_BIT_HIGH  = 4'd6;
    parameter DATA_DONE      = 4'd7;
    parameter VALIDATE       = 4'd8;
    parameter DONE           = 4'd9;

    reg [3:0] state = IDLE;

    reg [31:0] counter = 0;
    reg [5:0] bit_index = 0;
    reg [39:0] data_frame = 0;
    reg sensor_out = 1;
    reg sensor_dir = 1; // 1 = output mode, 0 = input mode

    // Tristate buffer: drives line only when output mode
    assign sensor = (sensor_dir) ? sensor_out : 1'bz;
    wire sensor_in = sensor;

    always @(posedge clk_50M or negedge reset) begin
        if (!reset) begin
            // ACTIVE-LOW RESET
            state <= IDLE;
            counter <= 0;
            bit_index <= 0;
            data_valid <= 0;
            sensor_out <= 1;
            sensor_dir <= 1;
            T_integral <= 0;
            RH_integral <= 0;
            T_decimal <= 0;
            RH_decimal <= 0;
            Checksum <= 0;
        end else begin
            case (state)

                // ---------------- IDLE ----------------
                IDLE: begin
                    data_valid <= 0;
                    sensor_dir <= 1;   // drive line HIGH
                    sensor_out <= 1;
                    counter <= counter + 1;
                    if (counter >= 25_000_000) begin // 0.5 sec delay before starting
                        counter <= 0;
                        state <= START_LOW;
                    end
                end

                // ---------------- START LOW ----------------
                START_LOW: begin
                    sensor_dir <= 1;   // output mode
                    sensor_out <= 0;   // pull LOW
                    counter <= counter + 1;
                    if (counter >= 900_000) begin // 18 ms LOW
                        counter <= 0;
                        sensor_out <= 1;
                        state <= START_HIGH;
                    end
                end

                // ---------------- START HIGH ----------------
                START_HIGH: begin
                    counter <= counter + 1;
                    if (counter >= 2_000) begin // 40 µs HIGH
                        counter <= 0;
                        sensor_dir <= 0; // release line, sensor responds
                        state <= WAIT_RESP_LOW;
                    end
                end

                // ---------------- WAIT RESPONSE LOW ----------------
                WAIT_RESP_LOW: begin
                    if (sensor_in == 0) begin
                        counter <= 0;
                        state <= WAIT_RESP_HIGH;
                    end
                end

                // ---------------- WAIT RESPONSE HIGH ----------------
                WAIT_RESP_HIGH: begin
                    if (sensor_in == 1) begin
                        counter <= 0;
                        bit_index <= 0;
                        data_frame <= 0;
                        state <= READ_BIT_LOW;
                    end
                end

                // ---------------- READ BIT LOW ----------------
                READ_BIT_LOW: begin
                    if (sensor_in == 0)
                        counter <= 0;
                    else begin
                        state <= READ_BIT_HIGH;
                        counter <= 0;
                    end
                end

                // ---------------- READ BIT HIGH ----------------
                READ_BIT_HIGH: begin
                    if (sensor_in == 1)
                        counter <= counter + 1;
                    else begin
                        // Determine bit value by duration of HIGH
                        if (counter > 3_000) // >60 µs = logic 1
                            data_frame <= {data_frame[38:0], 1'b1};
                        else
                            data_frame <= {data_frame[38:0], 1'b0};

                        bit_index <= bit_index + 1;
                        counter <= 0;

                        if (bit_index == 39)
                            state <= DATA_DONE;
                        else
                            state <= READ_BIT_LOW;
                    end
                end

                // ---------------- DATA DONE ----------------
                DATA_DONE: begin
                    RH_integral <= data_frame[39:32];
                    RH_decimal  <= data_frame[31:24];
                    T_integral  <= data_frame[23:16];
                    T_decimal   <= data_frame[15:8];
                    Checksum    <= data_frame[7:0];
                    state <= VALIDATE;
                end

                // ---------------- VALIDATE ----------------
                VALIDATE: begin
                    if ((RH_integral + RH_decimal + T_integral + T_decimal) == Checksum)
                        data_valid <= 1;
                    else
                        data_valid <= 0;
                    state <= DONE;
                end

                // ---------------- DONE ----------------
                DONE: begin
                    data_valid <= 0;
                    counter <= 0;
                    state <= IDLE; // repeat after next interval
                end

                default: state <= IDLE;

            endcase
        end
    end
endmodule