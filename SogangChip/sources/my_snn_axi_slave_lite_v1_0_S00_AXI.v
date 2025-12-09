`timescale 1 ns / 1 ps

module my_snn_axi_slave_lite_v1_0_S00_AXI #
(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 9 
)
(
    // [AXI 버스 신호 - 수정 불필요]
    input wire  S_AXI_ACLK,
    input wire  S_AXI_ARESETN,
    input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
    input wire [2 : 0] S_AXI_AWPROT,
    input wire  S_AXI_AWVALID,
    output wire  S_AXI_AWREADY,
    input wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
    input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
    input wire  S_AXI_WVALID,
    output wire  S_AXI_WREADY,
    output wire [1 : 0] S_AXI_BRESP,
    output wire  S_AXI_BVALID,
    input wire  S_AXI_BREADY,
    input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
    input wire [2 : 0] S_AXI_ARPROT,
    input wire  S_AXI_ARVALID,
    output wire  S_AXI_ARREADY,
    output wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
    output wire [1 : 0] S_AXI_RRESP,
    output wire  S_AXI_RVALID,
    input wire  S_AXI_RREADY
);

    // [AXI 내부 레지스터]
    reg [C_S_AXI_ADDR_WIDTH-1 : 0] axi_awaddr;
    reg  axi_awready;
    reg  axi_wready;
    reg [1 : 0] axi_bresp;
    reg  axi_bvalid;
    reg [C_S_AXI_ADDR_WIDTH-1 : 0] axi_araddr;
    reg  axi_arready;
    reg [C_S_AXI_DATA_WIDTH-1 : 0] axi_rdata;
    reg [1 : 0] axi_rresp;
    reg  axi_rvalid;

    // [USER SIGNALS]
    localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH/32) + 1;
    
    reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg_control; 
    reg [7:0] input_data [0:99];
    
    wire [6:0] awaddr_index;
    wire [6:0] araddr_index;
    
    reg [8*100-1:0] x_flat_bus;
    reg in_valid_reg;          // SNN Enable 신호 (한번 켜지면 유지)
    wire [3:0] move_net;
    reg [31:0] move_accum_reg; // 결과 누적 레지스터
    
    // 타이머 관련
    reg [9:0] timer_cnt;       
    reg start_pulse;           // 파이썬이 명령을 내린 "그 순간"을 감지하는 신호
    
    // 상수 정의
    localparam [9:0] WAIT_CYCLES  = 10'd517;
    localparam [9:0] COUNT_CYCLES = 10'd257;
    localparam [9:0] TOTAL_CYCLES = WAIT_CYCLES + COUNT_CYCLES; // 774

    integer k;

    // I/O Connections
    assign S_AXI_AWREADY = axi_awready;
    assign S_AXI_WREADY  = axi_wready;
    assign S_AXI_BRESP   = axi_bresp;
    assign S_AXI_BVALID  = axi_bvalid;
    assign S_AXI_ARREADY = axi_arready;
    assign S_AXI_RDATA   = axi_rdata;
    assign S_AXI_RRESP   = axi_rresp;
    assign S_AXI_RVALID  = axi_rvalid;

    assign awaddr_index = axi_awaddr[8:2]; 
    assign araddr_index = axi_araddr[8:2];

    //---------------------------------------------------------
    // [LOGIC 1] Write Channel & in_valid Latch Logic
    //---------------------------------------------------------
    reg aw_en;

    always @(posedge S_AXI_ACLK) begin
        if (S_AXI_ARESETN == 1'b0) begin
            axi_awready <= 1'b0;
            axi_wready  <= 1'b0;
            axi_bvalid  <= 1'b0;
            axi_bresp   <= 2'b0;
            aw_en       <= 1'b1;
            axi_awaddr  <= 0;
            
            slv_reg_control <= 0;
            in_valid_reg <= 0;      // 리셋 시에만 0으로 꺼짐
            start_pulse <= 0;       // 펄스 초기화
        end 
        else begin
            // 펄스는 기본적으로 0 (한 클럭만 1이 되도록)
            start_pulse <= 0;

            // 1. Handshake
            if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en) begin
                axi_awready <= 1'b1;
                axi_wready  <= 1'b1;
                axi_awaddr  <= S_AXI_AWADDR;
            end
            else begin
                axi_awready <= 1'b0;
                axi_wready  <= 1'b0;
            end

            // 2. Response
            if (axi_awready && S_AXI_AWVALID && axi_wready && S_AXI_WVALID && ~axi_bvalid) begin
                axi_bvalid <= 1'b1;
                axi_bresp  <= 2'b0; 
            end
            else if (S_AXI_BREADY && axi_bvalid) begin
                axi_bvalid <= 1'b0; 
            end

            // 3. User Register Write (Data & Control)
            if (axi_awready && S_AXI_WVALID && axi_wready && S_AXI_WVALID) begin
                
                // (1) Control Register (0x00) 접근 시
                if (awaddr_index == 7'd0) begin
                      slv_reg_control <= S_AXI_WDATA;
                      
                      // **[핵심 수정 1] in_valid는 켜기만 하고 끄지는 않음 (Latch)**
                      if (S_AXI_WDATA[0]) begin
                          in_valid_reg <= 1'b1; 
                          
                          // **[핵심 수정 2] 1을 쓰는 순간 "Start Pulse" 발생**
                          // 이 신호가 아래 타이머 로직에서 리셋 신호로 쓰임
                          start_pulse <= 1'b1; 
                      end
                end
                
                // (2) Input Data 저장 (0x10 ~)
                else if (awaddr_index >= 7'd4 && awaddr_index < 7'd104) begin
                    if (S_AXI_WSTRB[0]) input_data[awaddr_index - 4] <= S_AXI_WDATA[7:0];
                end
            end
        end
    end

    //---------------------------------------------------------
    // [LOGIC 2] Timer & Accumulator Logic (명확한 Reset 구현)
    //---------------------------------------------------------
    always @(posedge S_AXI_ACLK) begin
            if (S_AXI_ARESETN == 1'b0) begin
                move_accum_reg <= 32'd0;
                timer_cnt      <= 10'd0;
            end
            else begin
                // 1. 리셋/재시작 (Python Start Pulse)
                if (start_pulse == 1'b1) begin
                    move_accum_reg <= 32'd0; 
                    timer_cnt      <= 10'd0; // 0부터 시작 (초기 517 대기 진입)
                end
                
                // 2. 카운팅 및 루프 로직
                else if (in_valid_reg == 1'b1) begin
                    
                    // [핵심 수정] 루프 구현
                    // 0 ~ 516 (517clk): 초기 대기
                    // 517 ~ 773 (257clk): 동작 구간
                    // 773 도달 시 -> 517로 되돌아감 (Wait 구간 스킵하고 바로 동작 반복)
                    
                    if (timer_cnt >= TOTAL_CYCLES - 1) begin // 773에 도달하면
                        timer_cnt <= WAIT_CYCLES;            // 517로 점프 (무한 루프)
                        
                        // (선택사항) 루프 돌 때마다 누적값을 0으로 초기화하려면 주석 해제
                        // move_accum_reg <= 32'd0; 
                    end
                    else begin
                        timer_cnt <= timer_cnt + 1;
                    end
    
                    // 3. 누적 로직 (517 ~ 773 구간에서만 동작)
                    // timer_cnt가 517~773 사이를 계속 반복하므로, 초기 대기 이후에는 계속 누적됨
                    if (timer_cnt >= WAIT_CYCLES && timer_cnt < TOTAL_CYCLES) begin
                        if (move_net[0]) move_accum_reg[7:0]   <= move_accum_reg[7:0]   + 1; // down
                        if (move_net[1]) move_accum_reg[15:8]  <= move_accum_reg[15:8]  + 1; // up
                        if (move_net[2]) move_accum_reg[23:16] <= move_accum_reg[23:16] + 1; // left
                        if (move_net[3]) move_accum_reg[31:24] <= move_accum_reg[31:24] + 1; // right
                    end
                end
            end
        end

    //---------------------------------------------------------
    // [LOGIC 3] Read Channel
    //---------------------------------------------------------
    always @(posedge S_AXI_ACLK) begin
        if (S_AXI_ARESETN == 1'b0) begin
            axi_arready <= 1'b0;
            axi_rvalid  <= 1'b0;
            axi_rresp   <= 2'b0;
            axi_rdata   <= 0;
            axi_araddr  <= 0;
        end 
        else begin
            if (~axi_arready && S_AXI_ARVALID) begin
                axi_arready <= 1'b1;
                axi_araddr  <= S_AXI_ARADDR;
            end
            else begin
                axi_arready <= 1'b0;
            end

            if (axi_arready && S_AXI_ARVALID && ~axi_rvalid) begin
                axi_rvalid <= 1'b1;
                axi_rresp  <= 2'b0; 
                
                case (axi_araddr[8:2]) 
                    // 0x00: busy 상태 확인 (타이머가 다 돌았는지 Python에서 체크 가능)
                    // bit 0: Start Signal 상태
                    // bit 1: Busy Flag (1이면 동작 중, 0이면 완료)
                    7'd0: axi_rdata <= {30'd0, (timer_cnt < TOTAL_CYCLES), slv_reg_control[0]}; 
                    
                    // 0x04: 누적 결과
                    7'd1: axi_rdata <= move_accum_reg;  
                    
                    default: begin
                        if (axi_araddr[8:2] >= 7'd4 && axi_araddr[8:2] < 7'd104) 
                            axi_rdata <= {24'd0, input_data[axi_araddr[8:2] - 4]};
                        else 
                            axi_rdata <= 32'd0;
                    end
                endcase
            end
            else if (axi_rvalid && S_AXI_RREADY) begin
                axi_rvalid <= 1'b0;
            end
        end
    end

    // Data Packing
    always @(*) begin
        for (k = 0; k < 100; k = k + 1) begin
            x_flat_bus[k*8 +: 8] = input_data[k];
        end
    end

    // SNN Core
    network #(
        .bitsize(8),
        .in_neuron_num(100),
        .out_neuron_num(4),
        .frac(3)
    ) u_network (
        .in_valid (in_valid_reg), // 계속 1로 유지됨
        .clk      (S_AXI_ACLK),
        .rst      (~S_AXI_ARESETN), 
        .x_flat   (x_flat_bus),
        .move     (move_net)
    );

endmodule