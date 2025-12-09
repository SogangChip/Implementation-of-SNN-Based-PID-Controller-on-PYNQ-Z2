module if_neuron_p(clk, rst, x, y, ex); 
parameter bitsize = 8 ; 
// parameter frac = 4 ; // for fixed point Qm.n expression, fixed point used for leakrate &  PID constants?
parameter leakrate = 3 ; //leakrate=12.5%

input clk, rst;
input ex; //excitatory, inhibitatory
input x ; 
output reg y;
reg  [bitsize-1:0] th = $unsigned(1); //integer
reg  [bitsize-1:0] acc; //integer


always @ (posedge clk or posedge rst) begin
    if (rst) begin
        y <= 1'b0 ;
        acc <= {bitsize{1'b0}} ;   
    end       
    else begin // rst=0 
        if (acc<th) begin
            y <= 1'b0 ;
            if (ex) acc <= acc+x ;
            else acc <= acc-x ;
        end
        else begin
           y <= 1'b1 ;
           acc <= {bitsize{1'b0}} ;
        end
    end
end
endmodule