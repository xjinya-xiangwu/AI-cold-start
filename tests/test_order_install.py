import importlib.util, io, json, subprocess, sys, tempfile, zipfile
from pathlib import Path
root=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('fulfillment',root/'delivery/fulfillment.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
folder=root/'test-output/order-install-smoke';folder.mkdir(parents=True,exist_ok=True)
store=m.LocalStore(folder/'state');svc=m.Fulfillment(root,store)
row=svc.fulfill({'platform':'taobao','order_id':'smoke-'+__import__('uuid').uuid4().hex,'sku':'base','payment_status':'paid'})
package=folder/('package-'+row['reference'][:8]);package.mkdir()
with zipfile.ZipFile(io.BytesIO(store.read(row['package_key'])[0])) as z:z.extractall(package)
home=package/'buyer-home';(home/'.claude').mkdir(parents=True)
(home/'.claude/CLAUDE.md').write_text('USER_ORIGINAL_ROLE','utf-8')
code="$env:PSModulePath=[Environment]::GetEnvironmentVariable('PSModulePath','Machine'); Set-Variable HOME '"+home.as_posix()+"' -Force; $env:USERPROFILE=$HOME; & '"+(package/'install.ps1').as_posix()+"' -Cli"
encoded=__import__('base64').b64encode(code.encode('utf-16le')).decode()
for _ in range(3):
    r=subprocess.run([str(Path(__import__('os').environ.get('SystemRoot','C:/Windows'))/'System32/WindowsPowerShell/v1.0/powershell.exe'),'-NoProfile','-ExecutionPolicy','Bypass','-EncodedCommand',encoded],capture_output=True)
    if r.returncode:raise AssertionError(r.stderr.decode(errors='replace')[-3000:])
skills=list((home/'.claude/skills').rglob('SKILL.md'))
assert len(skills)==25,len(skills)
assert (home/'asp-coldstart/app-base/_skill-state').is_dir()
assert (home/'asp-coldstart/app-base/_backup').is_dir()
assert 'USER_ORIGINAL_ROLE' in (home/'.claude/CLAUDE.md').read_text('utf-8')
# Tampered engine is rejected before touching buyer files.
(package/'app/asp.ps1').write_bytes(b'tampered')
r=subprocess.run(['powershell.exe','-NoProfile','-ExecutionPolicy','Bypass','-EncodedCommand',encoded],capture_output=True)
assert r.returncode!=0
print(json.dumps({'three_installs':True,'skill_files':25,'stable_state':True,'original_role':True,'tamper_rejected':True,'package':str(package)}))
