module spike_counter(clk, rst, en, spike_in, u_counter);

parameter bitsize = 8;

input clk;
input rst;
input spike_in; // spikes during 128T
input en; // enable counting

output reg [bitsize-1:0] u_counter;

reg [bitsize-1:0] temp_counter;

reg [bitsize-2:0] clk_count; // for making 128T period
always @(posedge clk or posedge rst) begin
    if (rst) begin
        temp_counter <= {bitsize{1'b0}};
        clk_count <= {1'b0, {(bitsize-1){1'b1}}};
        u_counter <= {bitsize{1'b0}};
    end else begin
        if (en) begin
            if (clk_count < {(bitsize-1){1'b1}}) begin // count for 128Tclk
                clk_count <= clk_count + 8'd1;
                if(spike_in) begin
                    temp_counter <= temp_counter + 8'd1;
                end
            end else begin // end of 128T
                clk_count <= {(bitsize-1){1'b0}};
                u_counter <= temp_counter;
                temp_counter <= {bitsize{1'b0}};
            end
        end else begin
            temp_counter <= {bitsize{1'b0}};
            clk_count <= {1'b0, {(bitsize-1){1'b1}}};
            u_counter <= {bitsize{1'b0}};
        end
    end
end

endmodule