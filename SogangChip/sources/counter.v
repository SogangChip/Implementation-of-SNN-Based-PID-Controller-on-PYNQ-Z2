module clk_counter(en, clknum, clk, rst, cycle);

parameter bitsize=16;
input en ; 
input [bitsize-1:0] clknum ;
input clk, rst;
//output reg done;
output reg [bitsize-1:0] cycle ;


always @ (posedge clk or posedge rst) begin
    if (rst) begin
        cycle <= 0;
    end
    else begin
        if (en) begin
	        if (cycle == clknum) begin // before 128T
	            cycle <= $unsigned(0);
//            done <= 1'b1 ; 
	        end
		    else begin
                cycle <= cycle + $unsigned(1) ;
            end
        end
		else cycle <= $unsigned(0) ;
    end
end
endmodule