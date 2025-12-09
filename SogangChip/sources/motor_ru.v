module motor_ru(clk, rst, x, y); 
parameter bitsize = 8 ; 
// parameter frac = 4 ; // for fixed point Qm.n expression, fixed point used for leakrate &  PID constants?
parameter leakrate = 4 ; //leakrate=12.5%

input clk, rst;
input [5:0] x ; 
output reg y;
reg [bitsize-1:0] th = $unsigned(16); //integer
reg [bitsize-1:0] acc ; //integer

// ex=1 → +, ex=0 → -  (x[4],x[2],x[0]은 1비트 크기: 0 또는 1)
wire [bitsize-1:0] minus_value = {{(bitsize-1){1'b0}},x[5]&x[4]}+{{(bitsize-1){1'b0}},x[3]&x[2]}+{{(bitsize-1){1'b0}},x[1]&x[0]} ;     
wire [bitsize-1:0] plus_value = {{(bitsize-1){1'b0}},(~x[5])&x[4]}+{{(bitsize-1){1'b0}},(~x[3])&x[2]}+{{(bitsize-1){1'b0}},(~x[1])&x[0]} ;     

always @ (posedge clk or posedge rst) begin
    if (rst) begin
          y <= 1'b0 ;
          acc <= {bitsize{1'b0}} ;  
    end       
    else begin // rst=0 
        if (acc<th) begin
            y <= 1'b0 ;
            if (plus_value>=minus_value) acc <= (acc - (acc >>> leakrate)) + plus_value-minus_value ;
            else begin
                 if ((acc - (acc >>> leakrate)) < minus_value-plus_value) acc <= 0;
                 else acc <= (acc - (acc >>> leakrate)) + plus_value-minus_value ;
            end
        end
        else begin 
            y <= 1'b1 ;
            acc <= {bitsize{1'b0}} ;
        end
    end
end
endmodule