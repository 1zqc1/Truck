import sqlite3, json, pathlib, sys
sys.stdout.reconfigure(encoding='utf-8')
root=pathlib.Path('D:/wenxian/zoter')
out=pathlib.Path('work/literature_audit'); out.mkdir(exist_ok=True)
c=sqlite3.connect('file:D:/wenxian/zoter/zotero.sqlite?mode=ro',uri=True)
c.row_factory=sqlite3.Row
def fields(i):
    return dict(c.execute('SELECT f.fieldName,v.value FROM itemData d JOIN fieldsCombined f ON d.fieldID=f.fieldID JOIN itemDataValues v ON v.valueID=d.valueID WHERE d.itemID=?',(i,)).fetchall())
cols=[r[0] for r in c.execute("WITH RECURSIVE q AS (SELECT collectionID FROM collections WHERE key='PUWMQ7MD' UNION ALL SELECT a.collectionID FROM collections a JOIN q ON a.parentCollectionID=q.collectionID) SELECT collectionID FROM q")]
ids=[r[0] for r in c.execute('SELECT DISTINCT itemID FROM collectionItems WHERE collectionID IN ('+','.join('?'*len(cols))+')',cols)]
items=[]
for i in ids:
    if c.execute('SELECT 1 FROM deletedItems WHERE itemID=?',(i,)).fetchone(): continue
    r=dict(c.execute('SELECT i.itemID,i.key,t.typeName FROM items i JOIN itemTypes t ON i.itemTypeID=t.itemTypeID WHERE i.itemID=?',(i,)).fetchone())
    if r['typeName'] in ('attachment','note'): continue
    r.update(fields(i))
    r['creators']=[dict(x) for x in c.execute('SELECT cr.firstName,cr.lastName,ct.creatorType FROM itemCreators ic JOIN creators cr ON cr.creatorID=ic.creatorID JOIN creatorTypes ct ON ct.creatorTypeID=ic.creatorTypeID WHERE ic.itemID=? ORDER BY ic.orderIndex',(i,))]
    r['attachments']=[]
    for a in c.execute('SELECT i.key,a.itemID,a.path,a.contentType FROM itemAttachments a JOIN items i ON i.itemID=a.itemID WHERE a.parentItemID=?',(i,)).fetchall():
        a=dict(a); p=a.get('path') or ''; a['file']=str(root/'storage'/a['key']/p[8:]) if p.startswith('storage:') else p
        cache=root/'storage'/a['key']/'.zotero-ft-cache'
        a['cache_exists']=cache.exists()
        if cache.exists():
            text=cache.read_text(encoding='utf-8',errors='replace')
            target=out/(r['key']+'_'+a['key']+'.txt'); target.write_text(text,encoding='utf-8')
            a['text_file']=str(target); a['text_chars']=len(text)
        r['attachments'].append(a)
    items.append(r)
(out/'collection.json').write_text(json.dumps(items,ensure_ascii=False,indent=2),encoding='utf-8')
for r in items:
    print(json.dumps({k:r.get(k) for k in ['key','title','date','typeName','DOI','url','abstractNote','attachments']},ensure_ascii=False))
print('TOTAL',len(items))
