module network(in_valid, clk, rst, x_flat, move, done);

parameter bitsize=8 ; 
parameter in_neuron_num=100 ;
parameter out_neuron_num=4 ;
parameter frac=3 ; // 4일 수도

input in_valid;
input clk, rst;
input [(bitsize)*in_neuron_num-1 :0] x_flat ; //input
output reg [out_neuron_num-1 :0] move ; // motor output
output reg done;

// input array generation
wire [bitsize-1:0] x_array [9:0][9:0] ; 
genvar i,j;
generate 
    for (i=0;i<10;i=i+1) begin
        for (j=0;j<10;j=j+1) begin
            assign x_array[i][j]=x_flat[(10*i+j)*8+:8] ;
        end
    end
endgenerate

// input neuron array formation
wire xy [9:0][9:0];
generate
    genvar i_gen, j_gen;
    for (i_gen = 0; i_gen < 10; i_gen = i_gen + 1) begin 
        for (j_gen = 0; j_gen < 10; j_gen = j_gen + 1) begin 
            lif_neuron lif(.clk(clk),
                .rst(rst),
                .ex(1'b1),
                .in_valid(in_valid| !cycle257),
                .x(x_array[i_gen][j_gen]), // 입력 포트 연결
                .y(xy[i_gen][j_gen])      // 출력 포트 연결
            );
        end
    end
endgenerate


//firing address
//// first of all generate x_idx, y_idx 
assign x_0 = |{xy[0][0], xy[0][1], xy[0][2], xy[0][3], xy[0][4], xy[0][5], xy[0][6], xy[0][7], xy[0][8], xy[0][9]};
assign x_1 = |{xy[1][0], xy[1][1], xy[1][2], xy[1][3], xy[1][4], xy[1][5], xy[1][6], xy[1][7], xy[1][8], xy[1][9]};
assign x_2 = |{xy[2][0], xy[2][1], xy[2][2], xy[2][3], xy[2][4], xy[2][5], xy[2][6], xy[2][7], xy[2][8], xy[2][9]};
assign x_3 = |{xy[3][0], xy[3][1], xy[3][2], xy[3][3], xy[3][4], xy[3][5], xy[3][6], xy[3][7], xy[3][8], xy[3][9]};
assign x_4 = |{xy[4][0], xy[4][1], xy[4][2], xy[4][3], xy[4][4], xy[4][5], xy[4][6], xy[4][7], xy[4][8], xy[4][9]};
assign x_5 = |{xy[5][0], xy[5][1], xy[5][2], xy[5][3], xy[5][4], xy[5][5], xy[5][6], xy[5][7], xy[5][8], xy[5][9]};
assign x_6 = |{xy[6][0], xy[6][1], xy[6][2], xy[6][3], xy[6][4], xy[6][5], xy[6][6], xy[6][7], xy[6][8], xy[6][9]};
assign x_7 = |{xy[7][0], xy[7][1], xy[7][2], xy[7][3], xy[7][4], xy[7][5], xy[7][6], xy[7][7], xy[7][8], xy[7][9]};
assign x_8 = |{xy[8][0], xy[8][1], xy[8][2], xy[8][3], xy[8][4], xy[8][5], xy[8][6], xy[8][7], xy[8][8], xy[8][9]};
assign x_9 = |{xy[9][0], xy[9][1], xy[9][2], xy[9][3], xy[9][4], xy[9][5], xy[9][6], xy[9][7], xy[9][8], xy[9][9]};

assign y_0 = |{xy[0][0], xy[1][0], xy[2][0], xy[3][0], xy[4][0], xy[5][0], xy[6][0], xy[7][0], xy[8][0], xy[9][0]};
assign y_1 = |{xy[0][1], xy[1][1], xy[2][1], xy[3][1], xy[4][1], xy[5][1], xy[6][1], xy[7][1], xy[8][1], xy[9][1]};
assign y_2 = |{xy[0][2], xy[1][2], xy[2][2], xy[3][2], xy[4][2], xy[5][2], xy[6][2], xy[7][2], xy[8][2], xy[9][2]};
assign y_3 = |{xy[0][3], xy[1][3], xy[2][3], xy[3][3], xy[4][3], xy[5][3], xy[6][3], xy[7][3], xy[8][3], xy[9][3]};
assign y_4 = |{xy[0][4], xy[1][4], xy[2][4], xy[3][4], xy[4][4], xy[5][4], xy[6][4], xy[7][4], xy[8][4], xy[9][4]};
assign y_5 = |{xy[0][5], xy[1][5], xy[2][5], xy[3][5], xy[4][5], xy[5][5], xy[6][5], xy[7][5], xy[8][5], xy[9][5]};
assign y_6 = |{xy[0][6], xy[1][6], xy[2][6], xy[3][6], xy[4][6], xy[5][6], xy[6][6], xy[7][6], xy[8][6], xy[9][6]};
assign y_7 = |{xy[0][7], xy[1][7], xy[2][7], xy[3][7], xy[4][7], xy[5][7], xy[6][7], xy[7][7], xy[8][7], xy[9][7]};
assign y_8 = |{xy[0][8], xy[1][8], xy[2][8], xy[3][8], xy[4][8], xy[5][8], xy[6][8], xy[7][8], xy[8][8], xy[9][8]};
assign y_9 = |{xy[0][9], xy[1][9], xy[2][9], xy[3][9], xy[4][9], xy[5][9], xy[6][9], xy[7][9], xy[8][9], xy[9][9]};

wire [15:0] cycle;
// 256T counting for storing fired address

reg [9:0] x_concat ;
reg [9:0] y_concat ;
//reg [2:0] x_ones ; 
//reg [2:0] y_ones ; 
reg hot_x ; 
reg hot_y ; 

// cycle count, various timing regulation signal making
clk_counter total_clkcount(.en(in_valid),.clknum(16'd257), .clk(clk), .rst(rst), .cycle(cycle));
wire cycle0to127 = (cycle>=16'd0) && (cycle<16'd128); // concat true
wire cycle128to256 = (cycle>=16'd128) && (cycle<16'd257);  // spike count true
wire cycle0 = (cycle==16'd0); // concat reset
wire cycle257 = (cycle==16'd257) ;
// x_concat ,y_concat
always @(posedge clk or posedge rst) begin
        if (rst) begin
            x_concat <= 10'b0;
            y_concat <= 10'b0;
        end
        else begin
            if (cycle0 | hot_x | hot_y) begin
                x_concat <= 10'b0;
                y_concat <= 10'b0;
            end 
            else begin
                if (cycle0to127) begin
                    if (x_0) x_concat[0] <= 1'b1;
                    else x_concat[0] <= x_concat[0] ;
                    if (x_1) x_concat[1] <= 1'b1;
                    else x_concat[1] <= x_concat[1];
                    if (x_2) x_concat[2] <= 1'b1;
                    else x_concat[2] <= x_concat[2];
                    if (x_3) x_concat[3] <= 1'b1;
                    else x_concat[3] <= x_concat[3];
                    if (x_4) x_concat[4] <= 1'b1;
                    else x_concat[4] <= x_concat[4];
                    if (x_5) x_concat[5] <= 1'b1;
                    else x_concat[5] <= x_concat[5];
                    if (x_6) x_concat[6] <= 1'b1;
                    else x_concat[6] <= x_concat[6];
                    if (x_7) x_concat[7] <= 1'b1;
                    else x_concat[7] <= x_concat[7];
                    if (x_8) x_concat[8] <= 1'b1;
                    else x_concat[8] <= x_concat[8];
                    if (x_9) x_concat[9] <= 1'b1;
                    else x_concat[9] <= x_concat[9];
                    
                    if (y_0) y_concat[0] <= 1'b1;
                    else y_concat[0] <= y_concat[0];
                    if (y_1) y_concat[1] <= 1'b1;
                    else y_concat[1] <= y_concat[1];
                    if (y_2) y_concat[2] <= 1'b1;
                    else y_concat[2] <= y_concat[2];
                    if (y_3) y_concat[3] <= 1'b1;
                    else y_concat[3] <= y_concat[3];
                    if (y_4) y_concat[4] <= 1'b1;
                    else y_concat[4] <= y_concat[4];
                    if (y_5) y_concat[5] <= 1'b1;
                    else y_concat[5] <= y_concat[5];
                    if (y_6) y_concat[6] <= 1'b1;
                    else y_concat[6] <= y_concat[6];
                    if (y_7) y_concat[7] <= 1'b1;
                    else y_concat[7] <= y_concat[7];
                    if (y_8) y_concat[8] <= 1'b1;
                    else y_concat[8] <= y_concat[8];
                    if (y_9) y_concat[9] <= 1'b1;
                    else y_concat[9] <= y_concat[9];
                end
                else begin
                    x_concat <= x_concat ;
                    y_concat <= y_concat ;
                end
            end
        end
end

wire [7:0] x_and_2;
wire [6:0] x_and_3;
wire [7:0] y_and_2;
wire [6:0] y_and_3;



genvar n;
generate
    for (n = 0; n < 8; n = n + 1) begin : gen_2
        assign x_and_2[n] = x_concat[n] & x_concat[n+2];
        assign y_and_2[n] = y_concat[n] & y_concat[n+2];
    end
endgenerate

genvar u;
generate
    for (u = 0; u < 7; u = u + 1) begin : gen_3
        assign x_and_3[u] = x_concat[u] & x_concat[u+3];
        assign y_and_3[u] = y_concat[u] & y_concat[u+3];
    end
endgenerate


wire [14:0] x_ones = {x_and_2, x_and_3[6:0]};
wire [14:0] y_ones = {y_and_2, y_and_3[6:0]};


always @ (posedge clk or posedge rst) begin
    if (rst) begin
        hot_x <= 1'b0;
        hot_y <= 1'b0;
    end else begin
        // 하나라도 1 있으면 hot_x hot_y = 1
        if (x_ones != 15'b0) hot_x <= 1'b1;
        else hot_x <= 1'b0 ;
        if (y_ones != 15'b0) hot_y <= 1'b1;
        else hot_y <= 1'b0 ;
    end
end



// then, addressing
reg [bitsize-1:0] A_x; // if we reduce the bitsize just for address, probably it would be more efficient
reg [bitsize-1:0] A_y; 
reg [bitsize-1:0] B_x; //same with A_x
reg [bitsize-1:0] B_y; // same with C_y
reg [bitsize-1:0] C_x;
reg [bitsize-1:0] C_y;
reg [bitsize-1:0] D_x; 
reg [bitsize-1:0] D_y; 
always @(posedge clk or posedge rst) begin
    if (rst) begin 
        A_x <= 8'd0;
        A_y <= 8'd0;
        B_x <= 8'd0;
        B_y <= 8'd0;
        C_x <= 8'd0;
        C_y <= 8'd0; 
        D_x <= 8'd0;
        D_y <= 8'd0;       
    end 
    else begin
        // -------------------- X concat case -------------------- 
        case (x_concat) 
            10'b1100000000, 10'b1000000000 : begin
                A_x <= 8'd9;
                B_x <= 8'd9;
                C_x <= 8'd8;
                D_x <= 8'd8;
            end
            10'b0110000000, 10'b0100000000 : begin
                A_x <= 8'd8;
                B_x <= 8'd8;
                C_x <= 8'd7;
                D_x <= 8'd7;
            end
            10'b0011000000, 10'b0010000000 : begin
                A_x <= 8'd7;
                B_x <= 8'd7;
                C_x <= 8'd6;
                D_x <= 8'd6;
            end
            10'b0001100000, 10'b0001000000 : begin
                A_x <= 8'd6;
                B_x <= 8'd6;
                C_x <= 8'd5;
                D_x <= 8'd5;
            end
            10'b0000110000, 10'b0000100000 : begin
                A_x <= 8'd5;
                B_x <= 8'd5;
                C_x <= 8'd4;
                D_x <= 8'd4;
            end
            10'b0000011000, 10'b0000010000 : begin
                A_x <= 8'd4;
                B_x <= 8'd4;
                C_x <= 8'd3;
                D_x <= 8'd3;
            end
            10'b0000001100, 10'b0000001000 : begin
                A_x <= 8'd3;
                B_x <= 8'd3;
                C_x <= 8'd2;
                D_x <= 8'd2;
            end
            10'b0000000110,10'b0000000100 : begin
                A_x <= 8'd2;
                B_x <= 8'd2;
                C_x <= 8'd1;
                D_x <= 8'd1;
            end
            10'b0000000011,10'b0000000010: begin
                A_x <= 8'd1;
                B_x <= 8'd1;
                C_x <= 8'd0;
                D_x <= 8'd0;
            end
            default: begin
                A_x <= A_x;
                B_x <= B_x;
                C_x <= C_x;
                D_x <= D_x;
            end
        endcase

        // -------------------- Y concat case --------------------
        case (y_concat)
            10'b1100000000, 10'b1000000000 : begin
                A_y <= 8'd9;
                B_y <= 8'd8;
                C_y <= 8'd8;
                D_y <= 8'd9;
            end
            10'b0110000000, 10'b0100000000 : begin
                A_y <= 8'd8;
                B_y <= 8'd7;
                C_y <= 8'd7;
                D_y <= 8'd8;
            end
            10'b0011000000, 10'b0010000000 : begin
                A_y <= 8'd7;
                B_y <= 8'd6;
                C_y <= 8'd6;
                D_y <= 8'd7;
            end
            10'b0001100000, 10'b0001000000 : begin
                A_y <= 8'd6;
                B_y <= 8'd5;
                C_y <= 8'd5;
                D_y <= 8'd6;
            end
            10'b0000110000, 10'b0000100000 : begin
                A_y <= 8'd5;
                B_y <= 8'd4;
                C_y <= 8'd4;
                D_y <= 8'd5;
            end
            10'b0000011000, 10'b0000010000 : begin
                A_y <= 8'd4;
                B_y <= 8'd3;
                C_y <= 8'd3;
                D_y <= 8'd4;
            end
            10'b0000001100, 10'b0000001000 : begin
                A_y <= 8'd3;
                B_y <= 8'd2;
                C_y <= 8'd2;
                D_y <= 8'd3;
            end
            10'b0000000110, 10'b0000000100 : begin
                A_y <= 8'd2;
                B_y <= 8'd1;
                C_y <= 8'd1;
                D_y <= 8'd2;
            end
            10'b0000000011, 10'b0000000010 : begin
                A_y <= 8'd1;
                B_y <= 8'd0;
                C_y <= 8'd0;
                D_y <= 8'd1;
            end
            default: begin
                A_y <= A_y;
                B_y <= B_y;
                C_y <= C_y;
                D_y <= D_y;
            end
        endcase
      end
end
// spike counting
//// xy flatten 
wire [0:99] xy_flat;
genvar l, m;
generate
    for (l = 0; l < 10; l = l + 1) begin 
        for (m = 0; m < 10; m = m + 1) begin
            assign xy_flat[l*10 + m] = xy[l][m];
        end
    end
endgenerate
// 2D coord → 1D idx calculation
wire [7:0] A_idx;       
wire [7:0] B_idx;      
wire [7:0] C_idx;       
wire [7:0] D_idx;
assign A_idx = A_x * 10 + A_y;
assign B_idx = B_x * 10 + B_y;
assign C_idx = C_x * 10 + C_y;
assign D_idx = D_x * 10 + D_y;
wire A_spike ;
wire B_spike ;
wire C_spike ;
wire D_spike ;

assign A_spike = xy_flat[A_idx];
assign B_spike = xy_flat[B_idx];
assign C_spike = xy_flat[C_idx];
assign D_spike = xy_flat[D_idx];

wire [bitsize-1:0] spike_count_A ;
wire [bitsize-1:0] spike_count_B ;
wire [bitsize-1:0] spike_count_C ;
wire [bitsize-1:0] spike_count_D ;
spike_counter scA(.clk(clk), .rst(rst), .spike_in(A_spike), .u_counter(spike_count_A), .en(cycle128to256));
spike_counter scB(.clk(clk), .rst(rst), .spike_in(B_spike), .u_counter(spike_count_B), .en(cycle128to256));
spike_counter scC(.clk(clk), .rst(rst), .spike_in(C_spike), .u_counter(spike_count_C), .en(cycle128to256));
spike_counter scD(.clk(clk), .rst(rst), .spike_in(D_spike), .u_counter(spike_count_D), .en(cycle128to256));

wire [bitsize : 0] x_spike_sum1 = spike_count_A + spike_count_B ;
wire [bitsize : 0] x_spike_sum2 = spike_count_C + spike_count_D ;
wire [bitsize : 0] y_spike_sum1 = spike_count_A + spike_count_D ;
wire [bitsize : 0] y_spike_sum2 = spike_count_B + spike_count_C ;

// ball location 
wire [bitsize-1:0] x_loc;
wire [bitsize-1:0] y_loc;
ball_location bl_x(.clk(clk), .rst(rst), .add_A_bef(B_x), .add_B_bef(C_x), .spike_count_A(x_spike_sum1), .spike_count_B(x_spike_sum2), .location(x_loc));
ball_location bl_y(.clk(clk), .rst(rst), .add_A_bef(A_y), .add_B_bef(B_y), .spike_count_A(y_spike_sum1), .spike_count_B(y_spike_sum2), .location(y_loc));

// PID logic
wire signed [bitsize-1:0] Px;
wire signed [bitsize-1:0] Ix;
wire signed [bitsize-1:0] Dx;
wire signed [bitsize-1:0] Py;
wire signed [bitsize-1:0] Iy;
wire signed [bitsize-1:0] Dy;
P_cal P_x(.clk(clk), .rst(rst), .loc(x_loc), .P(Px)); // out signed
P_cal P_y(.clk(clk), .rst(rst), .loc(y_loc), .P(Py));
I_cal I_x(.clk(clk), .rst(rst), .err(Px), .I(Ix)); // in & out signed
I_cal I_y(.clk(clk), .rst(rst), .err(Py), .I(Iy));
D_cal DD_x(.clk(clk), .rst(rst), .err(Px), .D(Dx)); // in & out signed
D_cal DD_y(.clk(clk), .rst(rst), .err(Py), .D(Dy));

// burst coding
wire Px_in, Ix_in, Dx_in, Py_in, Iy_in, Dy_in; // input of PID neuron, output spikes of burst encoder > unsigned
wire ex_Px, ex_Ix, ex_Dx, ex_Py, ex_Iy, ex_Dy ; // 

burst_encoder BEPx(.start(cycle257), .clk(clk), .rst(rst), .data_in_signed(Px), .spike_out(Px_in),  .ex(ex_Px));
burst_encoder BEIx(.start(cycle257), .clk(clk), .rst(rst), .data_in_signed(Ix), .spike_out(Ix_in),  .ex(ex_Ix));
burst_encoder BEDx(.start(cycle257), .clk(clk), .rst(rst), .data_in_signed(Dx), .spike_out(Dx_in),  .ex(ex_Dx));
burst_encoder BEPy(.start(cycle257), .clk(clk), .rst(rst), .data_in_signed(Py), .spike_out(Py_in),  .ex(ex_Py));
burst_encoder BEIy(.start(cycle257), .clk(clk), .rst(rst), .data_in_signed(Iy), .spike_out(Iy_in),  .ex(ex_Iy));
burst_encoder BEDy(.start(cycle257), .clk(clk), .rst(rst), .data_in_signed(Dy), .spike_out(Dy_in),  .ex(ex_Dy));

//PID control neuron
wire Px_out, Ix_out, Dx_out, Py_out, Iy_out, Dy_out; //unsigned , spike

if_neuron_p Px_control(.clk(clk), .rst(rst), .x(Px_in), .y(Px_out), .ex(1'b1)) ;
if_neuron_i Ix_control(.clk(clk), .rst(rst), .x(Ix_in), .y(Ix_out), .ex(1'b1)) ;
if_neuron_d Dx_control(.clk(clk), .rst(rst), .x(Dx_in), .y(Dx_out), .ex(1'b1)) ;
if_neuron_p Py_control(.clk(clk), .rst(rst), .x(Py_in), .y(Py_out), .ex(1'b1)) ;
if_neuron_i Iy_control(.clk(clk), .rst(rst), .x(Iy_in), .y(Iy_out), .ex(1'b1)) ;
if_neuron_d Dy_control(.clk(clk), .rst(rst), .x(Dy_in), .y(Dy_out), .ex(1'b1)) ;

wire [5:0] motorin_x = {ex_Px, Px_out, ex_Ix, Ix_out, ex_Dx, Dx_out} ;
wire [5:0] motorin_y = {ex_Py, Py_out, ex_Iy, Iy_out, ex_Dy, Dy_out} ;

// motor neuron
wire right_out, left_out, up_out, down_out;
motor_ru motor_right(.clk(clk), .rst(rst), .x(motorin_x), .y(right_out)) ;
motor_ld motor_left(.clk(clk), .rst(rst), .x(motorin_x), .y(left_out)) ;
motor_ru motor_up(.clk(clk), .rst(rst), .x(motorin_y), .y(up_out)) ;
motor_ld motor_down(.clk(clk), .rst(rst), .x(motorin_y), .y(down_out)) ;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        move <= 4'b0 ;
        done <= 1'b0;
    end else begin
        move <= {right_out, left_out, up_out, down_out};
        done <= cycle257 ;
    end
end


endmodule