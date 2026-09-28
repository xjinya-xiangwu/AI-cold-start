# 托管开通指南（OSS 主源 + GitHub Pages 备源）

> registry 托管地 = 「每周一键更新」承诺的物理载体。开通后把 `registry/index.json` 的 mirrors 替换为真实地址，asp update 才会真正走网络更新。当前 mirrors 仍是占位符（REPLACE）。

## 一、OSS 主源（先做这个）

1. **开通**：阿里云控制台 → 对象存储 OSS → 开通服务（个人实名即可，按量付费，百级用户规模月成本 5–20 元）。
2. **建 Bucket**：
   - 名称如 `asp-registry`（后续 mirrors 要用），地域选华东-上海（oss-cn-shanghai）
   - 读写权限：**公共读**（静态更新源，任何人可拉；防盗链 v2 再上 Referer 白名单）
   - 版本控制：不开（省成本，回滚靠 git）
3. **上传**：每次发版后把 build-release 产物上传：
   - `registry/index.json` → `asp/registry/index.json`
   - `dist/packs/ai-pm-vX.Y.Z.zip` → `asp/registry/packs/ai-pm-vX.Y.Z.zip`
   - （用 ossutil 批量：`ossutil cp -rf dist/ oss://asp-registry/asp/registry/`）
4. **替换 mirrors**：`registry/index.json` 第一条改为
   `https://asp-registry.oss-cn-shanghai.aliyuncs.com/asp/registry`
5. **验证**：浏览器开上面地址 + `/index.json` 能下载即通；然后本机双击 update.bat 走一遍真实更新。

## 二、GitHub Pages 备源

1. 仓库 Settings → Pages → Source 选 `Deploy from a branch` → 分支 `main`、目录 `/(root)` → Save。
2. 等构建完成（~1 分钟），registry 可达地址为：
   `https://<你的GitHub用户名>.github.io/AI-cold-start/registry`
3. 替换 `registry/index.json` 第二条 mirrors 为上地址，commit + push。
4. 验证：curl 该地址 `/index.json` 返回 200。

> 注意：Pages serve 的是整个 main 分支，路径含仓库名 `/AI-cold-start/`，别写成根路径。
> asp update 已内置双源 failover（主源 3 秒超时自动切备源），无需额外配置。

## 三、发版周流程（托管开通后）

1. 周四：跑 `collector/collect.ps1` → 产出 `collector/reports/<date>-candidates.md`
2. 周五：人工周审 → 收录的进 `packs/` 补 manifest → `scripts/build-release.ps1 -Pack ai-pm`
3. 上传产物到 OSS（步骤一.3）→ commit + push（Pages 备源自动同步）
4. 更新群通知：「vX.Y.Z 已发布：新增 A/B/C，淘汰 D（原因）」

## 四、验收清单

- [ ] OSS index.json 可公网访问
- [ ] Pages index.json 可公网访问
- [ ] mirrors 两条均为真实地址且已 commit
- [ ] 本机 update.bat 真实走通：主源拉取 → 哈希校验 → 增量部署
- [ ] 断网主源（改 hosts 试）能 3 秒切备源
