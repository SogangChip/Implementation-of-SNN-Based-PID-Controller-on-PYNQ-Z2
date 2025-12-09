module P_cal(clk, rst, loc, P);

parameter bitsize = 8 ;
// parameter frac_bit= 3 ;

input clk, rst;
input [bitsize-1:0] loc ;
output reg signed [bitsize-1:0] P;

always @ (posedge clk or posedge rst) begin
    if (rst) begin
        P <= $signed(0);
    end
    else P <= (36-loc) ; 
end
endmodule
