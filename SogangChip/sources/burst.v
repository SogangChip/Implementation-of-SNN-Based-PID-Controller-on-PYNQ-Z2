module burst_encoder(clk, rst, start, data_in_signed, spike_out, ex);

    parameter bitsize = 8;
    // parameter [bitsize-1:0] max_ISI = 8'd255; // 스파이크 최대 간격

    input clk;
    input rst;
    input start;
    input signed [bitsize-1:0] data_in_signed; // 8-bit error input
    output reg spike_out;
    output reg ex; // ~data_in MSB (sign bit)
    
    // logic parameters
    wire [bitsize-1:0] data_in ; // absolute value of input data
    // wire [bitsize-1:0] ISI_c ; // 스파이크 간격 ;
    // reg [bitsize-1:0] data_in_buf ; // buffer for input data
    
    reg [bitsize-1:0] ISI_LUT_load [0:255];
    wire [bitsize-1:0] ISI_c ; 

    initial begin
        $readmemh("ISI_LUT.mem", ISI_LUT_load);
    end

    // data_in logic
    assign data_in = ( data_in_signed[bitsize-1] ) ? -data_in_signed : data_in_signed ;  //-data_in_signed = 2's complement
    assign ISI_c = ISI_LUT_load[data_in];

    // 내부 counter
    reg [bitsize-1:0] counter; // 8-bit counter to count up to 255
    reg start_trigger;
    reg encoding_active;
    reg [bitsize-1:0] ISI_cnt; // ISI 다운카운터
    // reg [bitsize-1:0] ISI_fixed; // ISI 고정값 저장용
    reg [1:0] start_delay; // 2clk buffer

    reg [bitsize-1:0] target_count;
    reg [bitsize-1:0] spike_gen_cnt;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            spike_out <= 1'b0;
            ex <= 1'b0;
            counter <= {bitsize{1'b0}};
            // data_in_buf <= {bitsize{1'b0}};
            start_trigger <= 1'b0;
            encoding_active <= 1'b0;
            ISI_cnt <= {bitsize{1'b0}};
            // ISI_fixed <= {bitsize{1'b0}};
            start_delay <= 2'b00;

            target_count <= {bitsize{1'b0}};
            spike_gen_cnt <= {bitsize{1'b0}};

        end else begin
            spike_out <= 1'b0; // 기본값 0 유지
            target_count <= data_in; // 스파이크 발생 횟수 설정
            // 1) 257clk
            // start 신호 래치, 2clk 버퍼링
            // start가 들어오면 start_trigger를 1로 래치
            if (start && (start_delay == 2'd0)) begin
                start_trigger <= 1'b1;
                start_delay <= 2'd2; // 2clk delay 시작           
            end

            if (start_trigger && (start_delay != 2'd0)) begin
                start_delay <= start_delay - 2'b1;
                
                // 2) 258clk 시점
                if (start_delay == 2'd1) begin
                    // data_in 래치, ISI 고정
                    // data_in_buf <= data_in;
                    // ex <= data_in_signed[bitsize-1]; // 부호 비트 설정
                    ISI_cnt <= {bitsize{1'b0}}; // ISI 카운터 초기화

                    spike_gen_cnt <= {bitsize{1'b0}}; // 스파이크 발생 카운터 초기화

                    // 259clk부터 인코딩 시작
                    encoding_active <= 1'b1;

                    // 래치 정리
                    start_trigger <= 1'b0;

                    // counter 초기화 : 259clk에서 1로 증가 시작
                    counter <= {bitsize{1'b0}};
                end
            end

            // 3) 259clk - 514clk : burst encoding 수행
            if (encoding_active) begin
                ex <= data_in_signed[bitsize-1];
                
                // ISI 기반 스파이크 발생 : ISI_cnt가 ISI_fixed에 도달하면 1clk 펄스
                if (ISI_cnt == (ISI_c-1)) begin
                    if ((data_in != {bitsize{1'b0}}) && (spike_gen_cnt < target_count)) begin
                        spike_out <= 1'b1;
                        spike_gen_cnt <= spike_gen_cnt + 1'b1;
                    end else begin
                        spike_out <= 1'b0;
                    end
                    ISI_cnt <= {bitsize{1'b0}}; // ISI 카운터 초기화
                end else begin
                    ISI_cnt <= ISI_cnt + 1'b1; // ISI 카운터 증가
                end

                // 256clk 클럭 윈도우
                if (counter == 8'd255) begin
                    // 514clk 종료 : 인코딩 종료 및 상태 초기화
                    encoding_active <= 1'b0;
                    counter <= {bitsize{1'b0}};
                    // ISI_fixed <= ISI_c;                         
                    // 다음 사이클부터 새로운 start 신호 대기
                end else begin
                    counter <= counter + 1'b1; // 카운터 증가
                end
            end
        end
    end
                

endmodule