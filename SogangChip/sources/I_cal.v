module I_cal(clk, rst, err, I);

parameter bitsize = 8 ;

input clk, rst;
input signed [bitsize-1:0] err;
output reg signed [bitsize-1:0] I ;
reg signed [bitsize-1:0] prev_err;

always @ (posedge clk or posedge rst) begin
    if (rst) begin
        I <= $signed(0) ;
        prev_err <= $signed(0);
    end
    else begin
        if (err!=0) begin
            if(prev_err!=err) begin
                I <= I+err ;
                prev_err <= err ;
            end
            else begin
                I <= I ;
                prev_err <= prev_err ;
            end
        end
    end
end
endmodule