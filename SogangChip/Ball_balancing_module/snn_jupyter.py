import pybullet as p
import pybullet_data
import time
import socket
import struct
import numpy as np

# ==========================================
# [설정] 사용자 환경
# ==========================================
FPGA_IP = '192.168.2.99'  # ★ IP 확인 필수
PORT = 5000              
PANEL_SIZE_CM = 30.0

# 튜닝 파라미터 (상황에 맞춰 조절)
TILT_GAIN = 0.00008   # ★ 기존보다 값을 줄여서 안정성 확보
ALPHA = 0.1          # ★ 부드러움 계수 (0.05 ~ 0.2 추천, 클수록 빠르지만 거칠어짐)

# ==========================================
# [초기화] 뉴런 위치 매핑 (10x + y 방식)
# ==========================================
neuron_pos = []
grid = np.linspace(-PANEL_SIZE_CM/2 + 1.5, PANEL_SIZE_CM/2 - 1.5, 10)

for x in grid:       
    for y in grid:   
        neuron_pos.append((x, y))

neuron_pos = np.array(neuron_pos)

def generate_pressure_bytes(ball_x_cm, ball_y_cm, weight_kg):
    """ 공 위치에 따라 뉴런 압력값 생성 """
    dists = np.sqrt((neuron_pos[:,0] - ball_x_cm)**2 + (neuron_pos[:,1] - ball_y_cm)**2)
    pressures = np.zeros(100, dtype=np.uint8)
    
    mask = dists <= 2.73  # 감지 반경
    
    if np.any(mask):
        gain = weight_kg * 2000.0 
        raw_val = gain / (dists[mask] + 0.1)
        raw_val[raw_val < 16] = 0 # Threshold
        pressures[mask] = np.clip(raw_val, 0, 255).astype(np.uint8)
        
    return pressures.tobytes()

def clear_socket_buffer(sock):
    """ 소켓에 쌓인 묵은 데이터 제거 (Latency 해결) """
    sock.setblocking(0)
    try:
        while True:
            data = sock.recv(1024)
            if not data: break
    except BlockingIOError:
        pass
    sock.setblocking(1)

def calibrate_bias(sock):
    """ 시작 전 센서 노이즈/편향 측정 (Down 값 폭주 해결) """
    print("\n⚖️  [보정 중] 센서 0점을 잡고 있습니다... (공을 건드리지 마세요)")
    offsets = np.zeros(4)
    sample_count = 20
    
    for _ in range(sample_count):
        # 자극 없는 상태(0,0,0) 전송
        sock.sendall(generate_pressure_bytes(0, 0, 0.0))
        try:
            res = sock.recv(16)
            if res and len(res) == 16:
                vals = struct.unpack('<4I', res)
                offsets += np.array(vals)
        except:
            pass
        time.sleep(0.05)
    
    offsets /= float(sample_count)
    print(f"✅ [보정 완료] Bias detected: R={offsets[0]:.1f} L={offsets[1]:.1f} U={offsets[2]:.1f} D={offsets[3]:.1f}")
    print("   -> 이제부터 이 값을 뺀 '순수 변화량'만 제어에 사용됩니다.\n")
    return offsets

def run_simulation():
    print("------------------------------------------")
    print("   SNN Ball Balancer (Timer Added)")
    print("------------------------------------------")
    
    try:
        start_x = float(input("공 초기 X 위치 (cm, 예: 5): "))
        start_y = float(input("공 초기 Y 위치 (cm, 예: -5): "))
        weight = float(input("공 무게 (kg, 예: 0.1): "))
    except ValueError:
        print("❌ 숫자를 입력해주세요.")
        return

    # 1. 통신 연결 (TCP_NODELAY 적용)
    print(f"📡 FPGA({FPGA_IP}:{PORT}) 연결 시도...")
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1) # ★ 딜레이 최소화 옵션
    sock.settimeout(2) # 타임아웃 단축
    
    try:
        sock.connect((FPGA_IP, PORT))
        print("✅ 연결 성공!")
    except Exception as e:
        print(f"❌ 연결 실패: {e}")
        return

    # 2. 0점 조절 (Calibration) 수행
    bias_offsets = calibrate_bias(sock)
    bias_r, bias_l, bias_u, bias_d = bias_offsets

    # 3. PyBullet 설정
    p.connect(p.GUI)
    p.setAdditionalSearchPath(pybullet_data.getDataPath())
    p.setGravity(0, 0, -9.8)
    p.setTimeStep(1/500) # 물리 엔진 스텝
    
    p.loadURDF("plane.urdf")
    
    # 판 생성
    half_ex = [PANEL_SIZE_CM/200.0, PANEL_SIZE_CM/200.0, 0.005] 
    plate_id = p.createMultiBody(0, 
                                 p.createCollisionShape(p.GEOM_BOX, halfExtents=half_ex),
                                 p.createVisualShape(p.GEOM_BOX, halfExtents=half_ex, rgbaColor=[0.8,0.8,0.8,1]),
                                 [0, 0, 0.005])
    
    # 공 생성
    ball_radius = 0.02
    ball_id = p.createMultiBody(weight, 
                                p.createCollisionShape(p.GEOM_SPHERE, radius=ball_radius),
                                p.createVisualShape(p.GEOM_SPHERE, radius=ball_radius, rgbaColor=[1,0.2,0.2,1]),
                                [start_x/100.0, start_y/100.0, ball_radius + 0.01])

    print("🚀 시뮬레이션 시작! (Ctrl+C로 종료)")
    
    # 제어 변수 초기화
    current_roll = 0.0
    current_pitch = 0.0
    stable_start_time = None
    step = 0
    
    # ★ [추가] 시뮬레이션 시작 시간 기록
    sim_start_time = time.time()

    try:
        while p.isConnected():
            # (1) 공 상태 확인
            pos, _ = p.getBasePositionAndOrientation(ball_id)
            if pos[2] < 0:
                print("\n💥 공이 떨어졌습니다.")
                break

            bx_cm, by_cm = pos[0]*100.0, pos[1]*100.0
            dist_center = np.sqrt(bx_cm**2 + by_cm**2)

            # 성공 조건 체크 (중심 유지)
            if dist_center <= 1.0:
                if stable_start_time is None: stable_start_time = time.time()
                elif time.time() - stable_start_time >= 10.0:
                    # ★ [추가] 총 소요 시간 계산 및 출력
                    total_duration = time.time() - sim_start_time
                    print(f"\n🎉 성공! 중심 유지 완료.")
                    print(f"⏱️ 총 소요 시간: {total_duration:.2f}초")
                    time.sleep(1)
                    break
            else:
                stable_start_time = None

            # (2) 통신 및 데이터 송수신
            # ★ 루프 시작 전 묵은 데이터 비우기
            clear_socket_buffer(sock)

            # 데이터 전송
            data_bytes = generate_pressure_bytes(bx_cm, by_cm, weight)
            sock.sendall(data_bytes)
            
            # 데이터 수신
            try:
                res = sock.recv(16)
                if not res: break
                raw_vals = struct.unpack('<4I', res)
                
                # ★ [보정 적용] 측정된 Bias를 뺌 (음수는 0으로 처리)
                s_right = max(0, raw_vals[0] - bias_r)
                s_left  = max(0, raw_vals[1] - bias_l)
                s_up    = max(0, raw_vals[2] - bias_u)
                s_down  = max(0, raw_vals[3] - bias_d)
                
            except socket.timeout:
                continue

            # (3) 목표 각도 계산 (Gain 적용)
            MAX_ANGLE = 0.25 # 최대 기울기 제한 (라디안)
            
            target_roll = (float(s_right) - float(s_left)) * TILT_GAIN
            target_pitch = -(float(s_up) - float(s_down)) * TILT_GAIN
            
            target_roll = np.clip(target_roll, -MAX_ANGLE, MAX_ANGLE)
            target_pitch = np.clip(target_pitch, -MAX_ANGLE, MAX_ANGLE)
            
            # (4) ★ LPF 적용 (부드러운 움직임)
            # 현재 각도를 유지하려는 성질(1-ALPHA) + 목표로 가려는 성질(ALPHA)
            current_roll = current_roll * (1 - ALPHA) + target_roll * ALPHA
            current_pitch = current_pitch * (1 - ALPHA) + target_pitch * ALPHA

            # (5) 물리 엔진 적용
            quat = p.getQuaternionFromEuler([current_pitch, current_roll, 0])
            p.resetBasePositionAndOrientation(plate_id, [0, 0, 0.005], quat)
            
            p.stepSimulation()
            
            # ★ time.sleep 제거됨 (최대 속도)

            if step % 50 == 0:
                print(f"\r Pos:({bx_cm:4.1f}, {by_cm:4.1f}) | Raw-Bias: R{int(s_right)} L{int(s_left)} U{int(s_up)} D{int(s_down)} ", end='')
            step += 1

    except KeyboardInterrupt:
        print("\n⏹ 중단됨.")
    except Exception as e:
        print(f"\n⚠️ 에러: {e}")
    finally:
        sock.close()
        if p.isConnected():
            p.disconnect()
        print("\n종료.")

if __name__ == "__main__":
    run_simulation()