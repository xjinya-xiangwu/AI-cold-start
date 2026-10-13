import importlib.util, json, tempfile, unittest, zipfile
from datetime import datetime, timedelta, timezone
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
SPEC=importlib.util.spec_from_file_location('fulfillment', ROOT/'delivery'/'fulfillment.py')
M=importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(M)
class DeliveryTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory()
        self.store=M.LocalStore(Path(self.tmp.name)/'store')
        self.svc=M.Fulfillment(ROOT,self.store)
        self.now=datetime(2026,10,13,tzinfo=timezone.utc)
    def tearDown(self): self.tmp.cleanup()
    def paid(self, **kwargs):
        event=dict(platform='xiaohongshu', order_id='test-order-100',sku='base',payment_status='paid')
        event.update(kwargs)
        return self.svc.fulfill(event,self.now)
    def test_paid_order_zip_has_manual_and_three_install_modes(self):
        result=self.paid()
        obj=self.store.read(result['package_key'])[0]
        import io
        with zipfile.ZipFile(io.BytesIO(obj)) as z:
            names=z.namelist()
            for name in ('用户手册.html','使用手册.docx','安装命令.txt','AGENT-INSTALL.md','install-windows.bat','install-macos.command','install-linux.sh','install.ps1','delivery-manifest.json'):
                self.assertIn(name,names)
            self.assertEqual(len([x for x in names if x.endswith('/SKILL.md')]),25)
            self.assertNotIn('app/packs/ai-pm/AGENTS.md',names)
            self.assertFalse(any('orders.csv' in x or 'gen-order' in x for x in names))
            self.assertIn('每月',z.read('用户手册.html').decode())
    def test_pm_includes_both_layers(self):
        result=self.paid(order_id='pm-order',sku='ai-pm')
        import io
        with zipfile.ZipFile(io.BytesIO(self.store.read(result['package_key'])[0])) as z:
            self.assertEqual(len([x for x in z.namelist() if x.endswith('/SKILL.md')]),37)
    def test_order_idempotency_and_payment_guard(self):
        a=self.paid(); b=self.paid()
        self.assertEqual(a['package_key'],b['package_key'])
        self.assertEqual(a['revision'],b['revision'])
        with self.assertRaises(ValueError): self.paid(payment_status='unpaid',order_id='unpaid')
        with self.assertRaises(ValueError): self.paid(platform='unknown')
        with self.assertRaises(ValueError): self.paid(sku='../../private')
        with self.assertRaises(ValueError): self.paid(sku='ai-pm')
    def test_links_rotate_only_after_72_hours(self):
        a=self.paid()
        self.assertEqual(self.svc.refresh(self.now+timedelta(days=2)),[])
        updated=self.svc.refresh(self.now+timedelta(days=3))
        self.assertEqual(len(updated),1)
        self.assertNotEqual(a['download_url'],updated[0]['download_url'])
        self.assertEqual(updated[0]['content_version'],a['content_version'])
    def test_refund_never_resurrects(self):
        a=self.paid()
        self.svc.revoke('xiaohongshu','test-order-100',self.now)
        self.assertEqual(self.svc.refresh(self.now+timedelta(days=4)),[])
        with self.assertRaises(ValueError): self.paid()
        self.assertIsNone(self.store.read(a['package_key']))
    def test_expired_update_entitlement_does_not_receive_new_content(self):
        a=self.paid()
        self.svc.publish('0.99.0',self.now+timedelta(days=120))
        rows=self.svc.refresh(self.now+timedelta(days=120))
        self.assertEqual(rows[0]['content_version'],a['content_version'])
    def test_native_platform_names_all_supported_but_no_fake_api_adapter(self):
        for platform in ('xiaohongshu','taobao','pinduoduo'):
            row=self.paid(platform=platform)
            self.assertEqual(row['platform'],platform)
    def test_cas_blocks_lost_updates(self):
        self.store.put('cas.json',b'one',expected=None)
        with self.assertRaises(M.Conflict): self.store.put('cas.json',b'two',expected=None)
    def test_signature_replay_and_body_validation(self):
        body=b'{"ok":true}'
        stamp=str(int(self.now.timestamp()))
        signature=M.sign_event('secret',stamp,body)
        self.assertTrue(M.verify_event('secret',stamp,signature,body,self.now))
        self.assertFalse(M.verify_event('secret',stamp,signature,body+b'x',self.now))
        self.assertFalse(M.verify_event('secret',stamp,signature,body,self.now+timedelta(minutes=6)))
    def test_sent_receipt_cannot_acknowledge_stale_link(self):
        a=self.paid()
        self.assertEqual(a['order_id'],'test-order-100')
        self.svc.mark_sent(a['reference'],'message-1',a['revision'],self.now)
        self.assertEqual(self.svc.pending(),[])
        self.svc.refresh(self.now+timedelta(days=3))
        with self.assertRaises(M.Conflict): self.svc.mark_sent(a['reference'],'old-message',a['revision'],self.now)
        self.assertEqual(len(self.svc.pending()),1)
    def test_publish_is_immutable_and_valid_entitlement_upgrades(self):
        a=self.paid()
        self.svc.publish('v0.15.0',self.now+timedelta(days=10))
        with self.assertRaises(M.Conflict): self.svc.publish('v0.15.0',self.now+timedelta(days=11))
        changed=self.svc.refresh(self.now+timedelta(days=10))
        self.assertEqual(changed[0]['content_version'],'v0.15.0')
        self.assertNotEqual(changed[0]['package_key'],a['package_key'])
    def test_private_oss_signature_and_lock_headers(self):
        store=M.OssStore('test-private-bucket','oss-cn-hangzhou.aliyuncs.com','fixture-ak','fixture-sk')
        from unittest.mock import patch
        class Response:
            headers={'ETag':'"etag"'}
            def __enter__(self): return self
            def __exit__(self,*_): pass
            def read(self): return b'ok'
        requests=[]
        def capture(req,timeout): requests.append(req); return Response()
        with patch.object(M.urllib.request,'urlopen',capture):
            store.put(M.LOCK_KEY,b'lock',expected=None)
        headers={k.lower():v for k,v in requests[0].header_items()}
        self.assertEqual(headers['x-oss-object-acl'],'private')
        self.assertEqual(headers['x-oss-forbid-overwrite'],'true')
        self.assertNotIn('fixture-sk',str(headers))
        with self.assertRaises(M.Conflict): store.put(M.STATE_KEY,b'{}')
if __name__=='__main__': unittest.main()
