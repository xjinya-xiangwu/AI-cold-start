import json, os, re, subprocess, threading, time, urllib.request, uuid
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
folder=ROOT/'test-output'/('ui-'+uuid.uuid4().hex)
folder.mkdir(parents=True)
import shutil
for item in ('asp.ps1','packs','adapters','registry','scripts'):
    source=ROOT/item
    if source.is_dir():shutil.copytree(source,folder/item)
    else:shutil.copy2(source,folder/item)
home=folder/'home';(home/'.cursor').mkdir(parents=True)
code="$env:PSModulePath=[Environment]::GetEnvironmentVariable('PSModulePath','Machine'); Set-Variable HOME '"+home.as_posix()+"' -Force; $env:USERPROFILE=$HOME; $env:ASP_UI_NOBROWSER='1'; & '"+(folder/'asp.ps1').as_posix()+"' ui"
import base64
encoded=base64.b64encode(code.encode('utf-16le')).decode()
exe=str(Path(os.environ.get('SystemRoot','C:/Windows'))/'System32/WindowsPowerShell/v1.0/powershell.exe')
proc=subprocess.Popen([exe,'-NoProfile','-ExecutionPolicy','Bypass','-EncodedCommand',encoded],stdout=subprocess.PIPE,stderr=subprocess.PIPE)
lines=[]
def drain(stream):
    for line in iter(stream.readline,b''):lines.append(line.decode('utf-8',errors='replace'))
threading.Thread(target=drain,args=(proc.stdout,),daemon=True).start()
threading.Thread(target=drain,args=(proc.stderr,),daemon=True).start()
try:
    limit=time.time()+20;base=None
    while time.time()<limit:
        text=''.join(lines)
        found=re.search(r'http://localhost:(\d+)',text)
        if found:base='http://127.0.0.1:'+found.group(1);break
        if proc.poll() is not None:raise AssertionError('UI process exited: '+text[-2000:])
        time.sleep(.1)
    assert base,'UI did not start'
    def get(path):return json.load(urllib.request.urlopen(base+path,timeout=5))
    def post(path,body):
        req=urllib.request.Request(base+path,data=json.dumps(body).encode(),headers={'Content-Type':'application/json'},method='POST')
        return json.load(urllib.request.urlopen(req,timeout=10))
    page=urllib.request.urlopen(base+'/',timeout=5).read().decode()
    assert 'api/start' in page
    state=get('/api/state')
    (folder/'ui-state.json').write_text(json.dumps(state,ensure_ascii=False,indent=2),'utf-8')
    post('/api/start',{'agents':['cursor'],'skills':{'base':['idea-grilling']},'agents_md':['base'],'prompts':[],'presets':[]})
    limit=time.time()+20
    while time.time()<limit:
        progress=get('/api/progress')
        if progress['done']:break
        time.sleep(.2)
    assert progress['done'],progress
    assert not any('[错误]' in str(line) for line in progress['lines']),progress
    assert (home/'.cursor/skills/idea-grilling/SKILL.md').exists()
    role=(home/'.cursor/rules/asp-ai-pm.mdc').read_text('utf-8')
    assert len(role)>1000
    post('/api/shutdown',{})
    proc.wait(timeout=5)
    print(json.dumps({'page_served':True,'ui_api_install':True,'selected_skill_only':len(list((home/'.cursor/skills').rglob('SKILL.md')))==1,'cursor_role_nonempty':True,'no_errors':True,'sandbox':str(folder)}))
finally:
    if proc.poll() is None:proc.terminate();proc.wait(timeout=5)
