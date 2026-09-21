import pathlib,json,hashlib,csv,statistics,math,sys
sys.stdout.reconfigure(encoding='utf-8')
out=pathlib.Path('work/paper_guide')
items=json.loads(pathlib.Path('work/literature_audit/collection.json').read_text(encoding='utf-8'))
known={}
for i,r in enumerate(items,1):
    for a in r['attachments']:
        p=pathlib.Path(a['file'])
        if p.is_file() and p.suffix.lower()=='.pdf':
            known[hashlib.sha256(p.read_bytes()).hexdigest()]=f'L{i:02d} {r["key"]}'
files=[]
for p in sorted(pathlib.Path('C:/Users/LENOVO/OneDrive/桌面/开题报告相关文献').glob('*.pdf')):
    sha=hashlib.sha256(p.read_bytes()).hexdigest()
    files.append({'file':p.name,'bytes':p.stat().st_size,'sha256':sha,'exact_match':known.get(sha)})
rows=[]
for p in sorted(pathlib.Path('C:/Users/LENOVO/tanker_trucksim_cosim/simulation_data').glob('ts_*.csv')):
    with p.open(encoding='utf-8-sig') as f: data=list(csv.DictReader(f))
    t=[float(r['Time']) for r in data]
    dt=[b-a for a,b in zip(t,t[1:])]
    rows.append({'file':p.name,'rows':len(data),'dt_median':statistics.median(dt),'dt_min':min(dt),'dt_max':max(dt),'end_s':t[-1],'columns':list(data[0])})
result={'desktop_files':files,'csv':rows,'geometry':{'volume_m3':math.pi*1.25**2*12,'mass_70pct_density780_kg':math.pi*1.25**2*12*.7*780,'volume_fill_20000kg_density780':20000/(math.pi*1.25**2*12*780)}}
(out/'supplement_audit.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'desktop_matches':files,'csv_count':len(rows),'dt_values':sorted(set(round(r['dt_median'],6) for r in rows)),'row_counts':sorted(set(r['rows'] for r in rows)),'geometry':result['geometry']},ensure_ascii=False,indent=2))
