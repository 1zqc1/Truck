# -*- coding: utf-8 -*-
"""
run_superelevation_batch.py —— 批量生成横坡（超高）工况 TruckSim 数据
基础工况: 阶跃转向 120度, 80 km/h
横坡: -6%, -4%, -2%, 0%, 2%, 4%, 6% (正值=右侧高)
流程: 生成 dZ Map -> 插入 par -> 跑 CLI -> 导出 CSV
"""
import json, struct, subprocess, os, sys
from batch_integrity import replace_once, file_signature, validate_solver_output

TS_DATA = r'D:\Program Files (x86)\TruckSim\data'
CLI = r'D:\Program Files (x86)\TruckSim\TruckSim2022.1_Prog\Programs\VS_SolverWrapper_CLI_64.exe'
SRC_PAR = os.path.join(TS_DATA, 'Results', 'Run_b2a91e77-4768-44ed-a4e4-8deb2406300c', 'Run_all.par')
OUT_DIR = r'C:\Users\LENOVO\tanker_trucksim_cosim\simulation_data'

with open(SRC_PAR, 'r', encoding='utf-8', errors='replace') as f:
    BASE_PAR = f.read()

# 阶跃转向表（原始，保留）
ANCHOR = 'set_description road_path_id PATH_ID for: Straight Path East'

# 要导出的通道
COLS = ['Time','Vx','Ay','AVz','Roll_E_2','Steer_SW','Fz_L1','Fz_L2','Fz_R1','Fz_R2']

def make_dzmap_block(pct):
    """生成横坡 dZ Map 展开块（pct 为百分数，如 6 表示 6%）"""
    dz = pct / 100.0 * 5  # L=±5m 处的 dZ
    return '''ENTER_PARSFILE Roads\\\\dZ_Map\\\\RdMapZ_crossslope.par
#FullDataName Road: Off-Center Elevation Map, S-L Grid\`Cross Slope {pct}pct\`Cross Slope
SET_IROAD_DZ_FOR_ID 0
ROAD_N_DZ = ROAD_N_DZ + 1
IDZ_ROAD = ROAD_N_DZ
RD_DZ_ID = ROAD_DZ_ID
set_description RD_DZ_ID ROAD_DZ_ID for: Cross Slope {pct}pct
set_description ROAD_DZ_ID Cross Slope {pct}pct
ROAD_DZ_COMBINE MULTIPLY
ROAD_DZ_TABLE SPLINE_FLAT
0, 1
1000, 1
ENDTABLE
ROAD_DZ_L_TABLE LINEAR_FLAT
-5, {neg}
0, 0
5, {pos}
ENDTABLE
LOG_ENTRY Used Dataset: Road: Off-Center Elevation Map, S-L Grid; {{ Cross Slope }} Cross Slope {pct}pct
EXIT_PARSFILE Roads\\\\dZ_Map\\\\RdMapZ_crossslope.par

'''.format(pct=pct, neg=(-dz), pos=dz)

def run_and_export(pct, steer_angle=90):
    """跑一次横坡仿真并导出"""
    block = make_dzmap_block(pct)
    par = replace_once(BASE_PAR, ANCHOR, ANCHOR + '\n' + block)
    par = replace_once(par, 'SPEED_TARGET_CONSTANT 100', 'SPEED_TARGET_CONSTANT 80')
    # 阶跃转向改为指定角度（默认90度临界工况）
    step_table = '''STEER_SW_TABLE LINEAR
0, 0
10, 0
10.1, %d
11, %d
ENDTABLE''' % (steer_angle, steer_angle)
    original_step = 'STEER_SW_TABLE LINEAR\n0, 0\n10, 0\n10.1, 120\n11, 120\nENDTABLE'
    par = replace_once(par, original_step, step_table)

    par_path = os.path.join(TS_DATA, 'super_run.par')
    with open(par_path, 'w', encoding='utf-8') as f:
        f.write(par)

    vsb_path = os.path.join(TS_DATA, 'super.vsb')
    vs_path = os.path.join(TS_DATA, 'super.vs')
    old_vsb, old_vs = file_signature(vsb_path), file_signature(vs_path)
    r = subprocess.run([CLI, '-par', par_path, '-datadir', TS_DATA],
                       capture_output=True, text=True, timeout=120)

    validate_solver_output(r.returncode, vsb_path, old_vsb)
    validate_solver_output(r.returncode, vs_path, old_vs)

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

    sign = 'p' if pct >= 0 else 'n'
    name = 'ts_super90_%s%d' % (sign, abs(pct))
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

    return {'name': name, 'pct': pct, 'Vx': sumVx/nFrames, 'maxAy': maxAy, 'maxRoll': maxRoll,
            'frames': nFrames, 'dur': nFrames*XStep}

if __name__ == '__main__':
    pcts = [-6, -4, -2, 0, 2, 4, 6]
    results = []
    for pct in pcts:
        r = run_and_export(pct)
        if r:
            results.append(r)
            status = '侧翻' if r['maxRoll'] > 40 else ('警告' if r['maxRoll'] > 5 else '安全')
            print('%-18s 横坡%+3d%%  Vx=%5.1f |Ay|max=%5.3fg Roll2max=%5.1fdeg [%s] (%.1fs)' % (
                r['name'], r['pct'], r['Vx'], r['maxAy'], r['maxRoll'], status, r['dur']))
        else:
            print('横坡 %+3d%% 失败' % pct)

    print('\n共成功 %d/%d 组' % (len(results), len(pcts)))
