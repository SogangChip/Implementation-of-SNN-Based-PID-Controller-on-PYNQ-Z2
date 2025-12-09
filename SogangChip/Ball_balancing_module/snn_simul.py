from pynq import Overlay
from pynq import MMIO
import socket
import struct
import numpy as np
import os

BITSTREAM_NAME = "snn_big_I.bit"
IP_BLOCK_NAME = "my_snn_axi_0"

# --- 설정 로드 ---
if not os.path.exists(BITSTREAM_NAME):
    print(f"❌ 파일 없음: {BITSTREAM_NAME}")
    exit()

overlay = Overlay(BITSTREAM_NAME)
if IP_BLOCK_NAME in overlay.ip_dict:
    ip_dict = overlay.ip_dict[IP_BLOCK_NAME]
    phys_addr = ip_dict['phys_addr']
    addr_range = ip_dict['addr_range']
    mmio = MMIO(phys_addr, addr_range)
    print(f"✅ FPGA 준비 완료 (IP: {IP_BLOCK_NAME})")
else:
    print("❌ IP 이름 오류")
    exit()

# ==========================================
# [주소 설정] 사용자 설계에 맞춰 수정 필요
# ==========================================
# ★ 주의: 입력(Input) 주소와 출력(Output) 주소가 겹치지 않게 FPGA가 설계되어 있어야 합니다.
INPUT_START_REG = 0x10  # (예시) 입력을 0x10으로 옮겼다고 가정
REG_CONTROL     = 0x00  # (예시) 컨트롤 레지스터
REG_OUTPUT_PACKED = 0x04 # ★ 결과를 읽을 주소 (여기에 4개 값이 다 들어있음)

# 서버 시작
HOST = ''
PORT = 5000
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind((HOST, PORT))
s.listen(1)

print(f"⏳ PC 연결 대기 중...")
conn, addr = s.accept()
print(f"🚀 PC 접속됨: {addr}")

try:
    count = 0
    while True:
        # 1. 받기 (100바이트)
        data = conn.recv(100)
        if not data: 
            print("PC 연결 끊김")
            break
        
        # 2. 입력 데이터 변환
        input_array = np.frombuffer(data, dtype=np.uint8)

        # 3. 하드웨어 쓰기 (100개)
        if len(input_array) == 100:
            for i in range(100):
                mmio.write(INPUT_START_REG + (i * 4), int(input_array[i]))
        
        # 4. Start 신호 (설계에 맞게 주소/값 수정 필요)
        mmio.write(REG_CONTROL, 0x01) 
        mmio.write(REG_CONTROL, 0x00)

        # ==========================================
        # ★ 5. 결과 읽기 (수정된 부분)
        # ==========================================
        # 0x04 주소에서 32비트 값을 한 번에 읽어옴
        packed_val = mmio.read(REG_OUTPUT_PACKED)
        
        # [비트 쪼개기] FPGA 설계 순서에 맞춰서 수정하세요!
        # 예: LSB(0~7)가 Left인 경우
        s_down  = (packed_val >> 0)  & 0xFF
        s_up = (packed_val >> 8)  & 0xFF
        s_left    = (packed_val >> 16) & 0xFF
        s_right  = (packed_val >> 24) & 0xFF
        
        count += 1
        if count % 10 == 0:
             print(f"[{count}] Packed: {hex(packed_val)} -> R:{s_right}  L:{s_left}  U:{s_up} D:{s_down}")

        # 6. PC로 보내기 (기존 형식 유지 <4I)
        # PC 코드를 안 고쳐도 되게, 쪼갠 값을 각각 정수로 포장해서 보냅니다.
        res = struct.pack('<4I', s_right, s_left, s_up, s_down)
        conn.sendall(res)
            
except Exception as e:
    print(f"에러: {e}")
finally:
    conn.close()
    s.close()