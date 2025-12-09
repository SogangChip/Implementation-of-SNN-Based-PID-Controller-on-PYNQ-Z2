module lif_neuron(in_valid, clk, rst, ex, x, y); 
parameter bitsize = 8 ; 
// parameter frac = 4 ; // for fixed point Qm.n expression, fixed point used for leakrate &  PID constants?
parameter leakrate = 3 ; //leakrate=12.5%

input in_valid;
input clk, rst;
input ex; // excitatory, inhibitatory
input [bitsize-1:0] x ; 
output reg y;
reg [bitsize-1:0] th = $unsigned(16) ; //integer
reg [bitsize-1:0] acc = $unsigned(0); //integer


always @ (posedge clk or posedge rst) begin
    if (rst) begin
        y <= 1'b0 ;
        acc <= {bitsize{1'b0}} ;  
    end        
    else begin // rst=0
        if (in_valid) begin
             if (x!=0) begin // input exist
                if (acc<th) begin // compare with threshold
                    y <= 1'b0 ; // output 0, $signed used for parameter bitsize
                    if (ex) acc <= acc - (acc >>> leakrate)+x ; //acc integration, nonblocking assign for instant firing
                    else acc <= acc- (acc >>> leakrate)-x ;
                end
                else begin // firing
                    y <= 1'b1 ;
                    acc <= {bitsize{1'b0}} ;
                end
             end
             else begin
                acc <= acc - (acc >>> leakrate) ; //leak
                y <= 1'b0 ;
             end 
       end
       else begin
            acc <= {bitsize{1'b0}};
            y <= 1'b0;
       end    
    end
end
endmodule