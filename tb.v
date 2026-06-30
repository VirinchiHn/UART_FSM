/*
`timescale 1ns/1ps

module tb;
reg clk_3125 = 1;
reg [7:0] data = 0;
reg parity_type = 0;    // even parity.
reg parity_bit = 0;

reg tx_start = 0;

wire tx;
reg tx_exp = 1;
wire tx_err;

wire tx_done;
reg tx_done_exp = 0;
wire tx_done_err;

integer r = 0, i = 0,k = 0,j = 0,y = 0,x = 0,err = 0;
integer fd = 0,fw = 0;

reg [10:0] data_packet = 0;
reg [99:0] file_data = 0;
reg [(10*8)-1:0] str = 0;
reg [7:0] rev_msg = 0;
reg [7:0] msg = 0;
reg flag = 0;
reg [7:0] cnt = 0;

assign #(1,1) tx_err = tx ^ tx_exp;
assign #(1,1) tx_done_err = tx_done ^ tx_done_exp;

// module instance.
uart_tx uut(.clk_3125(clk_3125),.parity_type(parity_type),.tx_start(tx_start),.data(data),.tx_done(tx_done),.tx(tx));

// 3.125MHz clock
always begin
    clk_3125 = ~clk_3125; #160;
end

initial begin
    fd = $fopen("data.txt","r");
    while(! $feof(fd)) begin
        if($fgets(str,fd)) begin
            if(str != 0) begin
                file_data[i] = str[15:8] - 48;
            end
            i = i + 1;
            msg = file_data[(10*k+1)+:8];
        end
    end
    $fclose(fd);
end

// parity_bit calculation.
always @(msg,parity_type) begin
    case(parity_type)
            1'b0: parity_bit = (^msg);       // even parity
            1'b1: parity_bit = ~(^msg);      // odd parity
    endcase
end

task reverse(input [7:0]in, output [7:0] out);
  begin
    for(r = 0; r < 8; r = r + 1) begin
      out[r] = in[7-r];
    end
  end
endtask

// sending data.
task send_data(input [7:0] msg,input parity_bit);
    begin
    data_packet = {1'b1,parity_bit,msg,1'b0};   // stop-parity-data-start;
    for(x = 0; x < 11; x = x + 1) begin
        tx_exp = data_packet[x];
        repeat(26) begin
        @(posedge clk_3125);
        end
        flag = 1;
        @(posedge clk_3125);    // 26 + 1 = 27;
        flag = 0;
    end
    end
endtask

initial begin
    tx_done_exp = 0;
    for(y = 0; y < 10; y = y + 1) begin
        tx_start = 1;
        msg = file_data[(10*k+1) +: 8];
        reverse(msg,data);
        @(posedge clk_3125);
        tx_start = 0;
        send_data(msg,parity_bit);
        k = k + 1;
        @(posedge clk_3125);
    end
    $stop(); // worst case simulation stop
end

always @(flag) begin
    cnt = cnt + 1;
    if(cnt == 23) cnt = 1;
end

always @(cnt) begin
    if(cnt == 22) tx_done_exp = 1;
    else tx_done_exp = 0;
end

// check on both edges
always@(clk_3125) begin
    if(tx !== tx_exp) err = err + 1;
    if(tx_done !== tx_done_exp) err = err + 1;
end

always @(posedge clk_3125) begin
    if(k == i/10) begin
        if(err !== 0) begin
            fw = $fopen("results.txt", "w");
            $fdisplay(fw, "%02h", "Errors");
            $display("Error(s) encountered, please check your design!");
            $fclose(fw);
        end else begin
            fw = $fopen("results.txt", "w");
            $fdisplay(fw, "%02h", "No Errors");
            $display("No errors encountered, congratulations!");
            $fclose(fw);
            $stop();
        end
    end
end

endmodule
*/



`timescale 1ns/1ps

module tb;

reg clk_3125 = 0, rx;
wire [7:0] rx_msg;
reg  [7:0] rx_exp = 0;
wire rx_parity;
reg exp_parity = 0;
wire rx_complete;
reg  exp_rx_complete = 0;

integer err = 0;
reg [109:0] data = 0;
reg [7:0] msg = 0;

integer i = 0, j = 0, k = 0,p = 0, fd = 0, fw = 0, s = 0, f = 0;
integer counter = 0;
reg [(10*11)-1:0] str; //10 chars can be stored
reg flag = 0;

uart_rx uut(.clk_3125(clk_3125), .rx(rx), .rx_msg(rx_msg), .rx_parity(rx_parity), .rx_complete(rx_complete));

always begin
	clk_3125 = ~clk_3125; #160;
end

initial begin
	fd = $fopen("data.txt", "r");
	while(! $feof(fd)) begin
		$fgets(str, fd);
		if(str != 0) begin
			data[i] = str[15:8] - 48;
		end
		i = i + 1;
	end
	$fclose(fd);
end

initial begin
	@(negedge clk_3125);
	rx_exp = 0;
	repeat(297) begin @(posedge clk_3125); end
	for(k = 0; k < 11; k = k+1) begin
		msg = data[(11*k+1) + : 9];
		rx_exp = {<<{msg[7:0]}};
		exp_parity = (^rx_exp)?1'b1:1'b0;
		repeat(297) begin @(posedge clk_3125); end
		s = s + 1;
	end
end

initial begin
	fd = $fopen("data.txt", "r");
	while(! $feof(fd)) begin
    if($fgets(str, fd)) begin
        if(str != 0) begin
            rx = str[15:8] - 48;
    end
		repeat(27) begin @(posedge clk_3125); end
        end
        rx = 1'b0;
	end
	$fclose(fd);
end

always @(posedge clk_3125) begin
	exp_rx_complete = 1'b0;
	if(s >= (i-1)/10) begin
		exp_rx_complete = 1'b0;
	end else begin
		if(counter == 297) begin
			exp_rx_complete = 1'b1;
			counter = 0;
		end
		counter = counter + 1;
	end
end

always @(negedge exp_rx_complete) begin
  if(p <= 9) begin
    p <= p + 1;
		if(p > 0) begin
			if((rx_parity !== exp_parity)) begin
				  $display("rx_msg: %c,exp_msg:%c,rx_parity:%b,exp_parity:%b",rx_msg,8'h3F,rx_parity,exp_parity);
	 		 end else begin
				  $display("rx_msg: %c,exp_msg:%c,rx_parity:%b,exp_parity:%b",rx_msg,rx_exp,rx_parity,exp_parity);
	 		 end
  		end
	end else p <= 0;
end

always @(clk_3125) begin
	if(p >= 10) begin
		flag = 1;
	end else begin
		flag = 0;
	end
end

always @(negedge clk_3125) begin
	#1;
	if ((rx_parity === exp_parity) && (rx_msg !== rx_exp)) err = err + 1;
	if ((rx_parity !== exp_parity) && (rx_msg !== 'h3F)) err = err + 1;
	if (rx_complete !== exp_rx_complete) err = err + 1'b1;
end

always @(negedge clk_3125) begin
    if (p == (((i-1)/10)) || (flag == 1)) begin
        if (err !== 0) begin
            fw = $fopen("results.txt","w");
            $fdisplay(fw, "%02h","Errors");
            repeat (300) begin @(posedge clk_3125); end
			$display("Error(s) encountered, please check your design!");
            $fclose(fw);
        end
        else begin
            fw = $fopen("results.txt","w");
            $fdisplay(fw, "%02h","No Errors");
            repeat (300) begin @(posedge clk_3125); end
            $display("No errors encountered, congratulations!");
            $fclose(fw);
        end
    end
end

endmodule
