# SeekDict

SeekDict 是一款 macOS / iOS 词典应用，目标是比 Apple 自带词典提供更好的翻译体验：即时的英⇄简中查词，并附上与查询词相关的新闻、微博内容和热搜榜。

英文版见 [README.md](README.md)，两份内容一一对应。

## 产品概述

- **词典优先**：英文 ⇄ 简体中文的单词、短语释义，完全离线可用。
- **不止释义**：对正在查询的词，SeekDict 同时展示相关新闻、微博内容和热搜榜——全部经由我们自己的后台接入联网搜索。
- **macOS**：全局划词取词（基于 Accessibility API，类似 Bob/Easydict），也支持打开查词窗口手动输入。
- **iOS**：仅支持手动输入。
- **应用内阅读**：新闻正文在应用内置的 Markdown 阅读视图里打开，不跳转浏览器。

## 范围

### v1 范围内

- 英文 ⇄ 简体中文词典查词，离线可用。
- macOS：全局划词取词 + 输入查词窗口。
- iOS：手动输入查词。
- 相关新闻列表、相关微博列表、热搜榜。
- 应用内阅读正文（后台抓取 Markdown，在应用内渲染）。
- 用户账号：Sign in with Apple、GitHub、手机号（短信验证码）登录。

### 范围外

- 英文和简体中文以外的任何语言对。
- 生词本 / 背单词功能——SeekDict 是词典，不是英语学习软件。
- 查询历史（v1 不做）。
- App 直接调用 DeepSeek API——所有搜索都走我们自己的后台。

## 架构

```
SeekDict App (macOS / iOS)  ↔  SeekDict 后台  ↔  DeepSeek Search / Fetch
```

### App（本仓库）

- **SwiftUI 仅用于窗口/页面管理**。窗口、视图层级、控件、事件响应都实现在 AppKit（macOS）和 UIKit（iOS）里；SwiftUI 通过 `NSViewRepresentable` / `UIViewRepresentable` 做包装。
- **共享核心**（Swift，跨平台）：基于 SQLite 的词典引擎、后台 REST client 与数据模型、鉴权与 token 管理。
- **macOS 宿主**：通过 Accessibility API 进行全局划词取词（需要用户在系统设置里授权），查词面板/窗口。
- **iOS 宿主**：查词页面，手动输入。

### 后台（独立服务，不在本仓库）

- 持有 DeepSeek API key，封装 DeepSeek Search/Fetch 接口。
- 通过 bearer token 校验用户身份，并按用户限流。
- 缓存搜索结果，降低 DeepSeek 调用量。
- 负责用户账号体系（Apple / GitHub / 手机号）和登录流程。

### 后台 API 契约（v1）

Base URL 待定。除登录相关接口外，所有接口都需要 `Authorization: Bearer <token>`。

登录：

| 接口 | 请求 | 响应 |
|---|---|---|
| `POST /auth/apple` | `{id_token}` | `{token, user}` |
| `POST /auth/github` | `{code}` | `{token, user}` |
| `POST /auth/phone` | `{number, sms_code}` | `{token, user}` |

内容：

| 接口 | 响应 |
|---|---|
| `GET /v1/search/news?word=&limit=` | `{results: [Item]}`——与词相关的新闻 |
| `GET /v1/search/weibo?word=&limit=` | `{results: [Item]}`——与词相关的微博内容 |
| `GET /v1/hot` | `{items: [HotItem]}`——热搜榜（排名、标题、链接、热度） |
| `GET /v1/article?url=` | `{title, content_markdown}`——后台抓取正文，供应用内阅读 |

`Item` 字段（对齐 DeepSeek Search 的返回结构，后台可以保持为带缓存的薄封装）：

```
{title, url, snippet, date, source_name, source_icon, score}
```

错误处理：`401` → 引导重新登录；`402`（后台 DeepSeek 余额不足）→ 提示用户稍后重试；`429`/5xx → 指数退避重试；其他 4xx → 不重试。

## 词典数据

词典内容以数据文件形式随本仓库发布，首次启动时导入 SQLite。

- **来源**：[qingjian](https://github.com/qingjian-team/qingjian) 项目的释义表（`assets/glossary/`）：
  - `glossary-zh.tsv`——英→简中，约 4.5 万词，键为小写。
  - `glossary-en.tsv`——中→英，约 23.9 万词。
- **格式**：TSV，一行一词——`词 \t [词性. ]译词 \t [词性. ]译词`；UTF-8 无 BOM、LF 换行、按码点排序；每词最多 2 个义项。词性使用固定枚举（`n. v. adj. adv. pron. prep. conj. num. m. part. int. phr.`）。
- **为什么直接复用而不是重新生成**：qingjian 已经付过一次 LLM 生成的成本并公开发布了结果，重新生成同样的表只会白烧 API 预算。因此 SeekDict 采用与数据源相同的许可证（见下文）。

## 本地存储（SQLite）

- `entries`：词典内容——`direction`（en→zh / zh→en）、`word`、`pos`、`sense`、`sense_order`；建索引支持精确匹配查询。
- `news_cache`（可选）：`word`、`payload_json`、`fetched_at`，按板块设置 TTL——纯优化项，后台自己也有缓存。

词典查词完全离线可用；新闻板块需要联网，断网时降级为显示缓存/空状态并提供重试。

## 鉴权与 token

- 支持 Sign in with Apple、GitHub OAuth、手机号 + 短信验证码登录；后台为每个用户签发 bearer token，用于鉴权和限流。
- 因为接入了第三方登录，Sign in with Apple 是必须的（App Store 政策要求）。
- token 存储在 Keychain 中；收到 `401` 响应时引导用户重新登录。

## 许可证

GPL-3.0-or-later，与词典数据的许可证保持一致。释义词表 © qingjian-team，按 GPL-3.0-or-later 使用，在仓库和应用"关于"页面中署名致谢。

## 原型里程碑 / 待验证项

以下是后台侧要尽早用原型定案的问题；无论结论如何，App 都按上面固定的契约开发。

- 用 DeepSeek Search 加 `site:weibo.com` 过滤，验证微博相关内容的返回质量。
- 验证热搜榜数据源（直接抓取微博热搜页可能被拦截；降级方案是搜索聚合热门 query 的摘要）。
- 确认 App Store 审核接受基于 Accessibility 的划词取词（权限声明 + 用途说明）。
