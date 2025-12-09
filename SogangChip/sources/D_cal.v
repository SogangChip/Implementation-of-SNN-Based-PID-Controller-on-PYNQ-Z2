module D_cal(clk, rst, err, D);

parameter bitsize = 8 ;

input clk, rst; 
input signed [bitsize-1:0] err;
output reg signed [bitsize-1:0] D ;
reg signed [bitsize-1:0] preerr ; // reg for previous error

always @ (posedge clk or posedge rst) begin
    if (rst) begin
         D <= $signed(0) ; 
         preerr <= $signed(0);
    end
    else begin
            if (preerr!=err) begin
                preerr <= err ;
                D <= (err-preerr) ;
            end
            else begin
                D <= D ;
                preerr <= preerr ;
            end
    end
end
endmodule