#!/usr/bin/env python3
"""Private order ZIP fulfillment. Stdlib only; platform adapters are separate.

A verified merchant bridge or explicitly confirmed CSV supplies normalized paid
orders. This module is NOT an unauthenticated native platform webhook parser.
"""
import argparse
import base64
import csv
import hashlib
import hmac
import html
import io
import json
import os
import re
import secrets
import sqlite3
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile
from contextlib import contextmanager, closing
from datetime import datetime, timedelta, timezone
from email.utils import format_datetime
from pathlib import Path

ANY = object()
PLATFORMS = ('xiaohongshu', 'taobao', 'pinduoduo')
SKUS = ('base', 'ai-pm')
STATE_KEY = 'private/fulfillment/state.json'
LOCK_KEY = 'private/fulfillment/write.lock'
LINK_REFRESH_HOURS = 72
# A 24h overlap avoids expiry while a scheduled invocation is delayed.
LINK_VALID_HOURS = 96

def encoded(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2).encode('utf-8')

def sha256(data):
    return hashlib.sha256(data).hexdigest()

def utc(value=None):
    value = value or datetime.now(timezone.utc)
    if value.tzinfo is None:
        raise ValueError('A timezone-aware datetime is required')
    return value.astimezone(timezone.utc)

def stamp(value):
    return utc(value).isoformat()

def parsed(value):
    return datetime.fromisoformat(value).astimezone(timezone.utc)

def order_key(platform, order_id):
    if platform not in PLATFORMS:
        raise ValueError('Unsupported sales platform')
    if not isinstance(order_id, str) or not 1 <= len(order_id) <= 128 or not re.fullmatch(r'[A-Za-z0-9_:-]+', order_id):
        raise ValueError('Invalid order reference')
    return sha256((platform + ':' + order_id).encode())

class Conflict(RuntimeError):
    pass

class LocalStore:
    """Local fixture/development store, not a hosted public download service."""
    def __init__(self, directory):
        self.root = Path(directory).resolve()
        self.root.mkdir(parents=True, exist_ok=True)
        self.db = self.root / 'objects.sqlite3'
        with closing(sqlite3.connect(self.db)) as db:
            db.execute('CREATE TABLE IF NOT EXISTS objects (key TEXT PRIMARY KEY, value BLOB NOT NULL, etag TEXT NOT NULL)')
            db.commit()
    def read(self, key):
        with closing(sqlite3.connect(self.db)) as db:
            row = db.execute('SELECT value,etag FROM objects WHERE key=?', (key,)).fetchone()
            return (bytes(row[0]), row[1]) if row else None
    def put(self, key, data, expected=ANY):
        with closing(sqlite3.connect(self.db)) as db:
            db.execute('BEGIN IMMEDIATE')
            current = db.execute('SELECT etag FROM objects WHERE key=?', (key,)).fetchone()
            current = current[0] if current else None
            if expected is not ANY and expected != current:
                raise Conflict('Conditional local write failed')
            etag = sha256(data)
            db.execute('INSERT OR REPLACE INTO objects VALUES (?,?,?)', (key, data, etag))
            db.commit()
            return etag
    def delete(self, key):
        with closing(sqlite3.connect(self.db)) as db:
            db.execute('DELETE FROM objects WHERE key=?', (key,))
            db.commit()
    def presign(self, key, expires):
        # The local URL is visibly a test fixture, never claimed as a real OSS link.
        return 'https://local-fixture.invalid/' + key + '?expires=' + str(int(expires.timestamp()))
    @contextmanager
    def lock(self):
        token = secrets.token_hex(16).encode()
        self.put(LOCK_KEY, token, expected=None)
        try:
            yield
        finally:
            row = self.read(LOCK_KEY)
            if row and row[0] == token:
                self.delete(LOCK_KEY)

class OssStore:
    """OSS V1 HTTPS signer; every object written by this service is private.

OSS PutObject does not support If-Match CAS. A forbid-overwrite global lock
serializes ALL metadata writers. Stale locks fail closed: do not auto-steal.
"""
    def __init__(self, bucket, endpoint, access_key, secret_key):
        if not re.fullmatch(r'[a-z0-9][a-z0-9-]{2,62}', bucket):
            raise ValueError('Invalid bucket')
        if not re.fullmatch(r'oss-[a-z0-9-]+\.aliyuncs\.com', endpoint):
            raise ValueError('Invalid OSS endpoint')
        if not access_key or not secret_key:
            raise ValueError('OSS runtime credentials are required')
        self.bucket, self.endpoint, self.ak, self.sk = bucket, endpoint, access_key, secret_key
        self._locked = False
    def _signature(self, text):
        return base64.b64encode(hmac.new(self.sk.encode(), text.encode(), hashlib.sha1).digest()).decode()
    def _request(self, method, key, data=None, create=False):
        if not key.startswith('private/fulfillment/') or '..' in key.split('/'):
            raise ValueError('Object outside fulfillment private prefix')
        date = format_datetime(datetime.now(timezone.utc), usegmt=True)
        ctype = 'application/zip' if key.endswith('.zip') else 'application/json; charset=utf-8'
        headers = {'Date':date, 'Cache-Control':'private, no-store'}
        canon = ''
        if method == 'PUT':
            headers['x-oss-object-acl'] = 'private'
            if create:
                headers['x-oss-forbid-overwrite'] = 'true'
            canon = ''.join(k + ':' + headers[k] + '\n' for k in sorted(headers) if k.startswith('x-oss-'))
            headers['Content-Type'] = ctype
        else:
            ctype = ''
        resource = '/' + self.bucket + '/' + key
        text = method + '\n\n' + ctype + '\n' + date + '\n' + canon + resource
        headers['Authorization'] = 'OSS ' + self.ak + ':' + self._signature(text)
        url = 'https://' + self.bucket + '.' + self.endpoint + '/' + urllib.parse.quote(key, safe='/')
        request = urllib.request.Request(url, data=data, headers=headers, method=method)
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                return response.read(), response.headers.get('ETag','').strip('"')
        except urllib.error.HTTPError as exc:
            if exc.code == 404 and method in ('GET','DELETE'):
                return None
            if exc.code in (409,412):
                raise Conflict('OSS object is locked or immutable') from None
            # Avoid leaking request URLs, order capabilities, or cloud credentials.
            raise RuntimeError('OSS request failed with HTTP ' + str(exc.code)) from None
    def read(self, key):
        return self._request('GET',key)
    def put(self, key, data, expected=ANY):
        if expected is not None and expected is not ANY:
            if not self._locked:
                raise Conflict('Metadata updates require the global writer lock')
            current = self.read(key)
            if not current or current[1] != expected:
                raise Conflict('Metadata changed under writer lock')
        if expected is ANY and key != LOCK_KEY and not self._locked:
            raise Conflict('Uncoordinated OSS write rejected')
        row = self._request('PUT',key,data,create=(expected is None))
        return row[1]
    def delete(self, key):
        if not self._locked:
            raise Conflict('Delete requires the global writer lock')
        self._request('DELETE',key)
    def presign(self, key, expires):
        expiry = str(int(utc(expires).timestamp()))
        resource = '/' + self.bucket + '/' + key
        sig = self._signature('GET\n\n\n' + expiry + '\n' + resource)
        query = urllib.parse.urlencode({'OSSAccessKeyId':self.ak,'Expires':expiry,'Signature':sig})
        return 'https://' + self.bucket + '.' + self.endpoint + '/' + urllib.parse.quote(key,safe='/') + '?' + query
    @contextmanager
    def lock(self):
        token = encoded({'owner':secrets.token_hex(24),'created_at':stamp(utc())})
        self.put(LOCK_KEY,token,expected=None)
        self._locked = True
        try:
            yield
        finally:
            row = self.read(LOCK_KEY)
            if row and row[0] == token:
                self.delete(LOCK_KEY)
            self._locked = False


def user_manual(sku, version):
    name = '基础包：25 技能 / 11 指令' if sku == 'base' else 'PM 完整版：37 技能 / 42 指令（含基础层）'
    return '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>冷启动包 用户手册</title>
<style>body{max-width:900px;margin:32px auto;padding:0 24px;font:17px/1.8 system-ui;color:#172234}code,pre{background:#eef2f7;padding:5px;border-radius:5px}h1,h2{color:#162b4d}.note{background:#fff4db;padding:14px}</style>
<h1>智能体冷启动包 用户手册</h1><p>已购内容：''' + html.escape(name) + '''；内容版本：''' + html.escape(version) + '''。</p>
<p class="note">请先解压整个 ZIP。需要电脑上已有可正常使用的 AI 工具；本包不含 AI 账号、会员或模型额度，不替你安装客户端。</p>
<h2>Windows 双击安装</h2><p>双击 install-windows.bat → 本地选择页选择工具与技能 → 开始安装 → 查看报告 → 重启 AI 工具并首用验证。</p>
<h2>macOS 和 Linux 安装</h2><p>macOS 双击 install-macos.command；Linux 在终端运行 bash install-linux.sh。需要 bash 和 python3；系统策略拦截时按终端方式操作，不绕过公司策略。原生 macOS/Linux 真机兼容仍需发布验收。</p>
<h2>命令行安装</h2><pre>Windows: powershell -NoProfile -ExecutionPolicy Bypass -File ".\\install.ps1" -Cli
macOS/Linux: bash ./install.sh</pre><p>CLI 会按探测结果安装；希望逐项选择请使用 Windows 选择页。无人交互模式仅在你明确授权时使用。</p>
<h2>交给 Agent 安装</h2><p>复制 AGENT-INSTALL.md 中的 prompt，填入已解压包的绝对目录。Agent 必须有本地文件和终端权限；没有权限时只能给你命令，不能声称已安装。</p>
<h2>更新</h2><p><b>每 3 天刷新下载链接，每月更新一次技能内容。</b>链接轮换本身不改变内容。卖家会在群或私信发送新版链接；下载后解压并运行相同安装入口。链接默认有效 4 天，轮换后有 1 天重叠以防发布延误。过期请向卖家索取最新链接。</p>
<p>默认没有本机自动计划任务。Windows 固定安装目录为 %USERPROFILE%\\asp-coldstart\\app-已购SKU；Mac/Linux 为 ~/asp-coldstart/app-已购SKU。历史备份和技能状态跨包保留，修改过的同名技能会保留并报告冲突。</p>
<h2>适配与验收</h2><p>Trae/Qoder 当前仅迁移；ZCode/OpenCode 的项目角色需部署项目 AGENTS.md。安装成功是文件落位证据，不保证真实客户端已加载；重启后试“用 idea-grilling 拷问我一个想法”。Cursor 规则需确认正文非空。</p>
<h2>售后与权益</h2><p>微信 xjinya；报错截图请遮挡订单信息、密钥和私人路径。已有版本可继续本地使用，月更新权益期限以订单规则为准。退款、支持范围和原创使用规则须在购买前由卖家明确展示；本包不能技术撤回已经下载的副本。</p></html>'''


def core_archive(root, sku, version):
    root = Path(root).resolve()
    include = ('base',) if sku == 'base' else ('base','ai-pm')
    entries = {}
    for name in ('asp.ps1','asp.sh','scripts/merge-skills.py','scripts/legacy-skill-hashes.json'):
        entries[name] = (root/name).read_bytes()
    for directory in ('adapters',) + tuple('packs/' + pk for pk in include):
        for file in (root/directory).rglob('*'):
            if file.is_symlink():
                raise ValueError('Release symlinks are not permitted')
            if file.is_file():
                entries[file.relative_to(root).as_posix()] = file.read_bytes()
    index = json.loads((root/'registry/index.json').read_text('utf-8-sig'))
    index['packs'] = {pk:index['packs'][pk] for pk in include}
    for pack in index['packs'].values():
        pack['version'] = version
        pack['sha256'] = ''
    entries['registry/index.json'] = encoded(index)
    entries['README.md'] = ('# 冷启动包安装器\n\n'+('基础包 25 技能' if sku=='base' else 'PM 包 37 技能，含基础层')+'。完整使用说明见订单 ZIP 根的用户手册.html。每三天换链接，每月更新内容。\n').encode()
    out = io.BytesIO()
    with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED) as z:
        for name,data in sorted(entries.items()):
            z.writestr(name,data)
    return out.getvalue()


def order_archive(root, sku, version, reference, core):
    manifest={'schema':'asp-order/1','order_reference_sha256':reference,'sku':sku,'content_version':version,
              'link_refresh_hours':LINK_REFRESH_HOURS,'content_cadence':'monthly','core_sha256':sha256(core)}
    out=io.BytesIO()
    with zipfile.ZipFile(io.BytesIO(core)) as src, zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED) as z:
        for item in src.infolist():
            z.writestr('app/'+item.filename,src.read(item))
        for name in ('install.ps1','install.sh','install-windows.bat','install-cli.bat','install-macos.command','install-linux.sh','AGENT-INSTALL.md'):
            info=zipfile.ZipInfo(name)
            info.compress_type=zipfile.ZIP_DEFLATED
            info.create_system=3
            info.external_attr=(0o100755 if name.endswith(('.sh','.command')) else 0o100644)<<16
            z.writestr(info,(Path(root)/'delivery'/name).read_bytes())
        z.writestr('delivery-manifest.json',encoded(manifest))
        z.writestr('用户手册.html',user_manual(sku,version).encode())
        manual_path=Path(root)/'docs/manual/使用手册.docx'
        if manual_path.exists():z.writestr('使用手册.docx',manual_path.read_bytes())
        z.writestr('安装命令.txt',('先解压完整包。\nWindows 双击 install-windows.bat，或运行：\npowershell -NoProfile -ExecutionPolicy Bypass -File ".\\install.ps1" -Cli\nMac/Linux：bash ./install.sh\nAgent 安装：复制 AGENT-INSTALL.md，填绝对路径。\n每三天更新下载链接，每月更新内容。\n').encode('utf-8-sig'))
        # Exact app file digests make integrity independently checkable after unzip.
        integrity={item.filename:sha256(src.read(item)) for item in src.infolist()}
        z.writestr('app-integrity.json',encoded(integrity))
    return out.getvalue()

class Fulfillment:
    def __init__(self, root, store):
        self.root,self.store=Path(root).resolve(),store
    def _load(self):
        result=self.store.read(STATE_KEY)
        if result:
            return json.loads(result[0]),result[1]
        index=json.loads((self.root/'registry/index.json').read_text('utf-8-sig'))
        return {'schema':1,'orders':{},'latest_version':index['packs']['base']['version'],'releases':{}},None
    def _save(self,state,etag):
        return self.store.put(STATE_KEY,encoded(state),expected=etag)
    def _core(self,state,sku,version):
        release_id=version+':'+sku
        if release_id not in state['releases']:
            core=core_archive(self.root,sku,version)
            key='private/fulfillment/releases/'+version+'/'+sku+'-'+sha256(core)+'.zip'
            if not self.store.read(key):
                self.store.put(key,core,expected=None)
            state['releases'][release_id]={'key':key,'sha256':sha256(core)}
        info=state['releases'][release_id]
        row=self.store.read(info['key'])
        if not row or sha256(row[0]) != info['sha256']:
            raise RuntimeError('Immutable content snapshot missing or corrupt')
        return row[0]
    def _package(self,state,order,now):
        core=self._core(state,order['sku'],order['content_version'])
        blob=order_archive(self.root,order['sku'],order['content_version'],order['reference'],core)
        key='private/fulfillment/packages/'+order['reference']+'/'+order['content_version']+'/'+sha256(blob)+'.zip'
        if not self.store.read(key): self.store.put(key,blob,expected=None)
        order['package_key']=key
        order['package_sha256']=sha256(blob)
        order.setdefault('package_history',[])
        if key not in order['package_history']:order['package_history'].append(key)
    def _link(self,order,now):
        order['revision']=order.get('revision',0)+1
        order['download_url']=self.store.presign(order['package_key'],now+timedelta(hours=LINK_VALID_HOURS))
        order['link_created_at']=stamp(now)
        order['link_expires_at']=stamp(now+timedelta(hours=LINK_VALID_HOURS))
        order['next_link_refresh_at']=stamp(now+timedelta(hours=LINK_REFRESH_HOURS))
        order['delivery_status']='pending_manual_send'
    def fulfill(self,event,now=None):
        now=utc(now)
        ref=order_key(event.get('platform'),event.get('order_id'))
        if event.get('payment_status') != 'paid' or event.get('sku') not in SKUS:
            raise ValueError('Verified paid event and valid SKU required')
        with self.store.lock():
            state,etag=self._load()
            previous=state['orders'].get(ref)
            if previous:
                if previous['status']!='active' or previous['sku']!=event['sku']:
                    raise ValueError('Order already revoked or SKU mismatched')
                return dict(previous)
            # Freeze both SKU layers before the first order of a version is issued.
            for release_sku in SKUS:self._core(state,release_sku,state['latest_version'])
            order={'reference':ref,'order_id':event['order_id'],'platform':event['platform'],'sku':event['sku'],'status':'active',
                   'paid_at':stamp(now),'updates_until':stamp(now+timedelta(days=90)),
                   'content_version':state['latest_version']}
            self._package(state,order,now)
            self._link(order,now)
            state['orders'][ref]=order
            self._save(state,etag)
            return dict(order)
    def refresh(self,now=None,force=False):
        now=utc(now)
        with self.store.lock():
            state,etag=self._load()
            changed=[]
            for order in state['orders'].values():
                if order['status']!='active':continue
                upgrade=now <= parsed(order['updates_until']) and order['content_version']!=state['latest_version']
                if not force and not upgrade and now < parsed(order['next_link_refresh_at']):continue
                if upgrade:
                    order['content_version']=state['latest_version']
                    self._package(state,order,now)
                self._link(order,now)
                changed.append(dict(order))
            if changed:self._save(state,etag)
            return changed
    def publish(self,version,now=None):
        now=utc(now)
        if not re.fullmatch(r'v?\d+\.\d+\.\d+',version):raise ValueError('Invalid version')
        with self.store.lock():
            state,etag=self._load()
            for sku in SKUS:
                identifier=version+':'+sku
                if identifier in state['releases']:
                    raise Conflict('Published content version is immutable; use a new version')
                self._core(state,sku,version)
            state['latest_version']=version
            state['published_at']=stamp(now)
            self._save(state,etag)
    def revoke(self,platform,order_id,now=None):
        now=utc(now);ref=order_key(platform,order_id)
        with self.store.lock():
            state,etag=self._load()
            order=state['orders'].get(ref)
            if not order:raise ValueError('Order not found')
            order['status']='revoked';order['revoked_at']=stamp(now)
            order['download_url']='';order['delivery_status']='cancelled'
            # Persist revocation before deleting objects so a crash cannot resurrect entitlement.
            self._save(state,etag)
            for key in order.get('package_history',[]):self.store.delete(key)
    def pending(self):
        state,_=self._load()
        return [dict(o) for o in state['orders'].values() if o['status']=='active' and o['delivery_status']=='pending_manual_send']
    def mark_sent(self,reference,receipt,revision,now=None):
        if not isinstance(receipt,str) or not 1<=len(receipt)<=256:raise ValueError('Send receipt required')
        with self.store.lock():
            state,etag=self._load();order=state['orders'].get(reference)
            if not order or order['status']!='active':raise ValueError('Active order required')
            if order['revision']!=revision:raise Conflict('Link refreshed; send and acknowledge the latest revision')
            order['delivery_status']='sent';order['sent_at']=stamp(utc(now));order['send_receipt']=receipt
            self._save(state,etag)


def sign_event(secret,timestamp,body):
    return hmac.new(secret.encode(),timestamp.encode()+b'.'+body,hashlib.sha256).hexdigest()

def verify_event(secret,timestamp,signature,body,now=None):
    try:
        if not secret or abs(int(utc(now).timestamp())-int(timestamp))>300:return False
        return hmac.compare_digest(sign_event(secret,timestamp,body),signature)
    except (TypeError,ValueError):return False


def configured_store(args):
    if args.store=='local':return LocalStore(args.state_dir)
    return OssStore(os.environ['ASP_FULFILLMENT_BUCKET'],os.environ['ASP_OSS_ENDPOINT'],
                    os.environ['ASP_OSS_AK'],os.environ['ASP_OSS_SK'])

def write_private_result(path,rows):
    path=Path(path).resolve();path.parent.mkdir(parents=True,exist_ok=True)
    path.write_bytes(encoded(rows))
    try:path.chmod(0o600)
    except OSError:pass

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--store',choices=('local','oss'),default='local')
    parser.add_argument('--state-dir',default='ops-private/state')
    parser.add_argument('--root',default=str(Path(__file__).resolve().parents[1]))
    parser.add_argument('--output',default='ops-private/delivery-results.json')
    sub=parser.add_subparsers(dest='command',required=True)
    issue=sub.add_parser('issue');issue.add_argument('--platform',choices=PLATFORMS,required=True)
    issue.add_argument('--order',required=True);issue.add_argument('--sku',choices=SKUS,required=True)
    issue.add_argument('--confirmed-paid',action='store_true',required=True)
    imp=sub.add_parser('import-csv');imp.add_argument('path');imp.add_argument('--confirmed-paid',action='store_true',required=True)
    refresh=sub.add_parser('refresh');refresh.add_argument('--force',action='store_true')
    pub=sub.add_parser('publish');pub.add_argument('--version',required=True)
    revoke=sub.add_parser('revoke');revoke.add_argument('--platform',choices=PLATFORMS,required=True);revoke.add_argument('--order',required=True)
    sent=sub.add_parser('mark-sent');sent.add_argument('--reference',required=True);sent.add_argument('--receipt',required=True);sent.add_argument('--revision',type=int,required=True)
    sub.add_parser('pending')
    args=parser.parse_args();svc=Fulfillment(args.root,configured_store(args));rows=[]
    if args.command=='issue':rows=[svc.fulfill({'platform':args.platform,'order_id':args.order,'sku':args.sku,'payment_status':'paid'})]
    elif args.command=='import-csv':
        with open(args.path,encoding='utf-8-sig',newline='') as f:
            for event in csv.DictReader(f):rows.append(svc.fulfill(event))
    elif args.command=='refresh':svc.refresh(force=args.force);rows=svc.pending()
    elif args.command=='publish':svc.publish(args.version);svc.refresh(force=True);rows=svc.pending()
    elif args.command=='revoke':svc.revoke(args.platform,args.order)
    elif args.command=='mark-sent':svc.mark_sent(args.reference,args.receipt,args.revision)
    elif args.command=='pending':rows=svc.pending()
    write_private_result(args.output,rows)
    print(json.dumps({'count':len(rows),'result_file':str(Path(args.output).resolve()),'store':args.store}))
    # Neither payment nor platform message sending is faked by this CLI.

if __name__=='__main__':main()
