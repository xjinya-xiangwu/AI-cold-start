import hashlib, json, zipfile
from pathlib import Path
root=Path(__file__).resolve().parents[1]
idx=json.loads((root/'registry/index.json').read_text('utf-8'))
results=[]
for sku in ('base','ai-pm'):
    info=idx['packs'][sku];path=root/'registry'/info['zip']
    assert hashlib.sha256(path.read_bytes()).hexdigest()==info['sha256']
    with zipfile.ZipFile(path) as z:
        names=[n.replace('\\','/') for n in z.namelist()]
        def read(name):return z.read(z.namelist()[names.index(name)])
        assert '使用手册.docx' in names
        assert 'scripts/merge-skills.py' in names and 'scripts/legacy-skill-hashes.json' in names
        assert not any('orders.csv' in n or 'fulfillment/state' in n or 'gen-order-tokens' in n for n in names)
        assert len([n for n in names if n.endswith('/SKILL.md')])==(25 if sku=='base' else 37)
        embedded=json.loads(read('registry/index.json'))
        for included in (('base',) if sku=='base' else ('base','ai-pm')):assert embedded['packs'][included]['version']=='v0.14.2'
        assert read('asp.ps1')[:3]==b'\xef\xbb\xbf'
        assert 'Copy-Item $s.FullName (Join-Path $dst $s.Name) -Recurse -Force' not in read('asp.ps1').decode('utf-8-sig')
        licenses=[n for n in names if '/licenses/' in n]
        assert len(licenses)>=6
        import io
        with zipfile.ZipFile(io.BytesIO(read('使用手册.docx'))) as doc:
            assert len([n for n in doc.namelist() if n.startswith('word/media/')])==4
        results.append({'sku':sku,'version':info['version'],'sha256':info['sha256'],'files':len(names),'license_copies':len(licenses),'manual_images':4})
print(json.dumps(results))
