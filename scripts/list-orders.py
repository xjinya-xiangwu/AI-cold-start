# -*- coding: utf-8 -*-
# list-orders.py - 列出全部订单（含撤销标记），输出 JSON 给 gen-order-tokens.ps1 -ResignAll 使用
# 凭据走环境变量 ASP_OSS_AK / ASP_OSS_SK；endpoint 固定，无外部输入。
import oss2, json, os

AK = os.environ['ASP_OSS_AK']
SK = os.environ['ASP_OSS_SK']
auth = oss2.Auth(AK, SK)
bucket = oss2.Bucket(auth, 'oss-cn-hangzhou.aliyuncs.com', 'asp-registry-xjinya')

revoked = set()
for o in oss2.ObjectIterator(bucket, prefix='orders/revoked/'):
    revoked.add(o.key.rsplit('/', 1)[-1].replace('.flag', ''))

orders = []
for o in oss2.ObjectIterator(bucket, prefix='orders/log/'):
    d = json.loads(bucket.get_object(o.key).read())
    d['revoked'] = d['token'] in revoked
    orders.append(d)

print(json.dumps(orders, ensure_ascii=False))
