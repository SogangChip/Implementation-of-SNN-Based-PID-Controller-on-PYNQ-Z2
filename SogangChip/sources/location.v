module ball_location (clk, rst, add_A_bef, add_B_bef, spike_count_A, spike_count_B, location);

parameter bitsize = 8;

input rst;
input clk;
input [bitsize-1:0] add_A_bef ;
input [bitsize-1:0] add_B_bef ;
input [bitsize:0] spike_count_A; // input spike train
input [bitsize:0] spike_count_B; // input spike train

reg [bitsize-1:0] delta_out; // output delta value
wire [2:0] which_case; // 100 : same, 010 : A > B, 001 : B > A

wire [bitsize-1:0] add_A = add_A_bef <<< 3;
wire [bitsize-1:0] add_B = add_B_bef <<< 3;

wire [bitsize:0] large_spike;
wire [bitsize:0] small_spike;
reg [bitsize-1:0] temp_location;
output reg [bitsize-1:0] location ;

assign {large_spike, small_spike} = (spike_count_A == spike_count_B)? {spike_count_A, spike_count_B} : // A = B
                                    (spike_count_A > spike_count_B)? 
                                    {spike_count_A, spike_count_B} : // A > B
                                    {spike_count_B, spike_count_A}; // B > A

assign which_case = (spike_count_A == 0 && spike_count_B == 0)? 3'b000 : // no input or rst
                    (spike_count_A == spike_count_B)? 3'b100 : // A = B
                    (spike_count_A > spike_count_B)? 3'b010 : // A > B
                    3'b001; // B > A

always @(posedge clk or posedge rst) begin
    if (rst) begin
        delta_out <= {bitsize{1'b0}};
        temp_location <= $unsigned(36);
        location <= $unsigned(36);
    end else begin
        // Update last spike times
        delta_out <=  (large_spike == 0 && small_spike == 0)? delta_out : // no input
                        (small_spike == 0)? {bitsize{1'b0}} : // to avoid division by zero
                        (large_spike == small_spike)? {{(bitsize-3){1'b0}}, 3'b100} : // large = small
                        ((large_spike >> 1) < small_spike)? {{(bitsize-2){1'b0}}, 2'b11} : // small < large < 2*small
                        ((large_spike >> 2) < small_spike)? {{(bitsize-2){1'b0}}, 2'b10} : // 2*small <= large < 4*small
                        ((large_spike >> 3) < small_spike)? {{(bitsize-1){1'b0}}, 1'b1} : // 4*small <= large < 8*small
                        {bitsize{1'b0}}; // 8*small <= large
        case (which_case)
            3'b000 : temp_location <= temp_location ; // no input
            3'b100 : temp_location <= add_A ;
            3'b010 : temp_location <= add_A-delta_out ;
            3'b001 : temp_location <= add_B+delta_out ;
            default : temp_location <= $unsigned(36);
       endcase

       location <= temp_location ;

    end
end
endmodule