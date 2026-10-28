# -*- coding: utf-8 -*-
"""
run_fishhook_batch.py —— 批量生成鱼钩工况 TruckSim 数据
流程: 修改 par 文件的 STEER_SW_TABLE -> 跑 CLI -> 导出 CSV
"""
import json, struct, subprocess, os, sys
from batch_integrity import replace_once, file_signature, validate_solver_output

# 路径
TS_DATA = r'D:\Program Files (x86)\TruckSim\data'
CLI = r'D:\Program Files (x86)\TruckSim\TruckSim2022.1_Prog\Programs\VS_SolverWrapper_CLI_64.exe'
SRC_PAR = os.path.join(TS_DATA, 'Results', 'Run_b2a91e77-4768-44ed-a4e4-8deb2406300c', 'Run_all.par')
OUT_DIR = r'C:\Users\LENOVO\tanker_trucksim_cosim\simulation_data'

# 读取基础 par 文件
with open(SRC_PAR, 'r', encoding='utf-8', errors='replace') as f:
    BASE_PAR = f.read()

# 原始阶跃表（要替换掉）
STEP_TABLE = '''STEER_SW_TABLE LINEAR
0, 0
10, 0
10.1, 120
11, 120
ENDTABLE'''

# 要导出的通道
COLS = ['Time','Vx','Ay','AVz','Roll_E_2','Steer_SW','Fz_L1','Fz_L2','Fz_R1','Fz_R2']

def gen_fishhook_table(amp, rate=720.0, dwell=0.25, t_start=10.0):
    """生成鱼钩转向表（幅值amp度，速率rate deg/s，保持dwell秒）"""
    t1 = t_start + amp / rate          # 打到 +amp
    t2 = t1 + dwell                     # 保持
    t3 = t2 + 2 * amp / rate            # 反向到 -amp
    t4 = t3 + dwell                     # 保持
    t5 = t4 + 1.5                       # 保持回稳
    t6 = t5 + amp / rate                # 回正
    lines = ['STEER_SW_TABLE LINEAR']
    lines.append('0, 0')
    lines.append('%.3f, 0' % t_start)
    lines.append('%.3f, %g' % (t1, amp))
    lines.append('%.3f, %g' % (t2, amp))
    lines.append('%.3f, %g' % (t3, -amp))
    lines.append('%.3f, %g' % (t4, -amp))
    lines.append('%.3f, %g' % (t5, -amp))
    lines.append('%.3f, 0' % t6)
    lines.append('15, 0')
    lines.append('ENDTABLE')
    return '\n'.join(lines)

def run_and_export(speed, amp):
    """跑一次仿真并导出 CSV"""
    table = gen_fishhook_table(amp)
    par = replace_once(BASE_PAR, STEP_TABLE, table)
    par = replace_once(par, 'SPEED_TARGET_CONSTANT 100', 'SPEED_TARGET_CONSTANT %d' % speed)
    par = replace_once(par, 'Steering Step Input', 'Steering Fishhook Input')

    par_path = os.path.join(TS_DATA, 'fishhook_run.par')
    with open(par_path, 'w', encoding='utf-8') as f:
        f.write(par)

    # 跑 CLI
    vsb_path = os.path.join(TS_DATA, 'fishhook.vsb')
    vs_path = os.path.join(TS_DATA, 'fishhook.vs')
    old_vsb, old_vs = file_signature(vsb_path), file_signature(vs_path)
    r = subprocess.run([CLI, '-par', par_path, '-datadir', TS_DATA],
                       capture_output=True, text=True, timeout=120)
    # 检查是否有输出
    validate_solver_output(r.returncode, vsb_path, old_vsb)
    validate_solver_output(r.returncode, vs_path, old_vs)

    # 读通道定义
    with open(vs_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    ch = data['VsChannelGroup']['Channels']
    XStep = data['VsChannelGroup'].get('XStep', 0.025)
    ch_map = {}
    for i, c in enumerate(ch):
        if c.get('Name Aliases'):
            ch_map[c['Name Aliases'][0]] = i
    nChan = len(ch)

    with open(vsb_path, 'rb') as f:
        vsb = f.read()
    hdr = 24
    nFrames = (len(vsb) - hdr) // (nChan * 4)
    if nFrames <= 0:
        return None

    col_idx = {c: ch_map.get(c) for c in COLS if c != 'Time'}
    if any(v is None for v in col_idx.values()):
        return None

    # 导出 CSV
    name = 'ts_fishhook_%d_%ddeg' % (speed, amp)
    out = os.path.join(OUT_DIR, name + '.csv')
    lines = [','.join(COLS)]
    maxAy = 0; maxRoll = 0; sumVx = 0.0
    for f in range(nFrames):
        base = hdr + f * nChan * 4
        t = f * XStep
        vals = ['%.3f' % t]
        for c in COLS[1:]:
            v = struct.unpack_from('<f', vsb, base + col_idx[c]*4)[0]
            vals.append('%.6f' % v)
        lines.append(','.join(vals))
        sumVx += struct.unpack_from('<f', vsb, base + col_idx['Vx']*4)[0]
        ay = abs(struct.unpack_from('<f', vsb, base + col_idx['Ay']*4)[0])
        roll = abs(struct.unpack_from('<f', vsb, base + col_idx['Roll_E_2']*4)[0])
        if ay > maxAy: maxAy = ay
        if roll > maxRoll: maxRoll = roll

    with open(out, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines) + '\n')

    return {'name': name, 'Vx': sumVx/nFrames, 'maxAy': maxAy, 'maxRoll': maxRoll, 'frames': nFrames, 'dur': nFrames*XStep}

if __name__ == '__main__':
    # 工况: 4车速 x 4幅值 = 16组
    speeds = [60, 70, 80, 90]
    amps = [90, 150, 200, 270]

    results = []
    for sp in speeds:
        for amp in amps:
            r = run_and_export(sp, amp)
            if r:
                results.append(r)
                status = '侧翻' if r['maxRoll'] > 40 else ('警告' if r['maxRoll'] > 5 else '安全')
                print('%-28s Vx=%5.1f |Ay|max=%5.3fg Roll2max=%5.1fdeg [%s] (%d帧, %.1fs)' % (
                    r['name'], r['Vx'], r['maxAy'], r['maxRoll'], status, r['frames'], r['dur']))
            else:
                print('%-28s 失败' % ('ts_fishhook_%d_%ddeg' % (sp, amp)))

    print('\n共成功 %d/%d 组' % (len(results), len(speeds)*len(amps)))
