import importlib.util,json,os,subprocess,time,urllib.request,urllib.error,uuid
from pathlib import Path
root=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('fulfillment',root/'delivery/fulfillment.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
state=root/'test-output'/('webhook-'+uuid.uuid4().hex)
import socket
s=socket.socket();s.bind(('127.0.0.1',0));port=s.getsockname()[1];s.close()
env=os.environ.copy();env.update(ASP_STORE='local',ASP_STATE_DIR=str(state),ASP_LISTEN_PORT=str(port),ASP_MERCHANT_BRIDGE_SECRET='controlled-fixture-secret-0123456789')
proc=subprocess.Popen([__import__('sys').executable,str(root/'delivery/server.py')],env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
try:
    for _ in range(100):
        try:
            urllib.request.urlopen('http://127.0.0.1:'+str(port),timeout=.3)
        except urllib.error.HTTPError:break
        except OSError:time.sleep(.1)
    def post(event,signed=True):
        body=json.dumps(event).encode();ts=str(int(time.time()))
        headers={'Content-Type':'application/json','X-ASP-Timestamp':ts}
        if signed:headers['X-ASP-Signature']=m.sign_event(env['ASP_MERCHANT_BRIDGE_SECRET'],ts,body)
        req=urllib.request.Request('http://127.0.0.1:'+str(port)+'/v1/merchant-events',data=body,headers=headers,method='POST')
        try:
            with urllib.request.urlopen(req,timeout=10) as r:return r.status,json.load(r)
        except urllib.error.HTTPError as e:return e.code,json.load(e)
    event={'event':'paid','platform':'pinduoduo','order_id':'fixture-100','sku':'base','payment_status':'paid'}
    assert post(event,False)[0]==401
    a=post(event);b=post(event);assert a[0]==200 and b[0]==200
    assert a[1]['order']['package_key']==b[1]['order']['package_key']
    assert post(dict(event,payment_status='unpaid',order_id='fixture-unpaid'))[0]==400
    assert post(dict(event,event='refund'))[0]==200
    assert post(event)[0]==400
    print(json.dumps({'unsigned_rejected':True,'signed_paid_package':True,'duplicate_idempotent':True,'unpaid_rejected':True,'refund_no_resurrection':True,'mode':'controlled-local-not-platform-payment'}))
finally:
    proc.terminate();proc.wait(timeout=5)
