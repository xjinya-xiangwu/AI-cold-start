#!/usr/bin/env python3
"""Authenticated normalized merchant bridge, not a native marketplace callback.
Deploy behind HTTPS + ingress limits. Only the trusted adapter may know the key;
that adapter MUST verify the platform signature and query paid-order state first.
"""
import json, os
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from fulfillment import Fulfillment, LocalStore, OssStore, Conflict, verify_event

class Handler(BaseHTTPRequestHandler):
    service = None
    def log_message(self, *_):
        pass  # never print buyer capabilities or payment identifiers to server logs
    def respond(self, status, data):
        body=json.dumps(data,ensure_ascii=False).encode()
        self.send_response(status)
        self.send_header('Content-Type','application/json; charset=utf-8')
        self.send_header('Cache-Control','no-store')
        self.send_header('Content-Length',str(len(body)))
        self.end_headers();self.wfile.write(body)
    def do_POST(self):
        if self.path!='/v1/merchant-events':return self.respond(404,{'error':'not_found'})
        try:length=int(self.headers.get('Content-Length','0'))
        except ValueError:return self.respond(400,{'error':'invalid_length'})
        if not 1<=length<=65536:return self.respond(413,{'error':'body_limit'})
        body=self.rfile.read(length)
        if not verify_event(os.environ['ASP_MERCHANT_BRIDGE_SECRET'],self.headers.get('X-ASP-Timestamp',''),self.headers.get('X-ASP-Signature',''),body):
            return self.respond(401,{'error':'unauthorized'})
        try:
            event=json.loads(body)
            if not isinstance(event,dict):raise ValueError('invalid event')
            event_type=event.get('event')
            if event_type=='paid':
                # bridge signature authenticates the source, NOT an arbitrary buyer
                order=self.service.fulfill(event)
                return self.respond(200,{'order':order,'sending':'manual_or_platform_adapter_required'})
            if event_type=='refund':
                self.service.revoke(event.get('platform'),event.get('order_id'))
                return self.respond(200,{'status':'revoked'})
            raise ValueError('unsupported event')
        except (ValueError,KeyError,TypeError,json.JSONDecodeError):return self.respond(400,{'error':'invalid_event'})
        except Conflict:return self.respond(409,{'error':'busy_retry_with_same_order'})
        except Exception:return self.respond(503,{'error':'fulfillment_failed_retry_same_order'})

def main():
    secret=os.environ.get('ASP_MERCHANT_BRIDGE_SECRET','')
    if len(secret)<32:raise SystemExit('Set a merchant bridge secret of at least 32 characters; never expose it to buyers.')
    root=Path(__file__).resolve().parents[1]
    mode=os.environ.get('ASP_STORE','oss')
    if mode=='local':store=LocalStore(os.environ.get('ASP_STATE_DIR',str(root/'ops-private/state')))
    else:store=OssStore(os.environ['ASP_FULFILLMENT_BUCKET'],os.environ['ASP_OSS_ENDPOINT'],os.environ['ASP_OSS_AK'],os.environ['ASP_OSS_SK'])
    Handler.service=Fulfillment(root,store)
    # loopback by default; public ingress MUST be a secured TLS reverse proxy
    host=os.environ.get('ASP_LISTEN_HOST','127.0.0.1');port=int(os.environ.get('ASP_LISTEN_PORT','8787'))
    HTTPServer((host,port),Handler).serve_forever()
if __name__=='__main__':main()
