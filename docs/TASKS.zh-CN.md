# SeekDict 任务拆分

按 [README.md](README.md) 规划拆分的工作任务表。每个任务的粒度控制在一次闲余时间可完成（约 30 分钟 – 2 小时）。用 `[x]` 勾选；建议按从上到下的顺序做，依赖关系写在"完成标准"里。

里程碑：

- **M1——macOS 离线词典可用**：T1.x、T2.x、T4.1–T4.3
- **M2——后台内容上线**：T3.x、T7.1–T7.7
- **M3——macOS 完整应用**：M1 + M2 + T4.4–T4.9、T5.x
- **M4——iOS 应用**：M2 + T6.x

## T1. 工程搭建

| 编号 | 任务 | 完成标准 |
|---|---|---|
| T1.1 | [x] 建共享核心模块（Swift Package 或 framework target），macOS / iOS 两个 App target 都链接它 | 核心编译一次，两个 App 都能 import |
| T1.2 | [x] 选型并接入 SQLite 访问层（先评估 GRDB / SQLite.swift / 系统 C API） | 选定、加入 core、能打开 DB 文件 |
| T1.3 | [x] 给 core 建单元测试 target | 两个平台的 scheme 都能跑通一个 trivial 测试 |
| T1.4 | [x] UI 分层骨架验证：一个 AppKit 视图经 `NSViewRepresentable` 挂进 SwiftUI 窗口，一个 UIKit 视图经 `UIViewRepresentable` 挂进页面 | 两个平台都能编译渲染 |

## T2. 词典数据与引擎（离线核心）

| 编号 | 任务 | 完成标准 |
|---|---|---|
| T2.1 | 引入 qingjian 的两张 TSV（`glossary-zh.tsv`、`glossary-en.tsv`）到 `data/`，附 README 注明来源与 GPL 许可证 | 文件入仓，附许可证说明 |
| T2.2 | SQLite `entries` 表结构（direction、word、pos、sense、sense_order）+ 首次启动导入 TSV 到应用 DB | 全新安装导入无报错 |
| T2.3 | 严格 TSV 解析器：词性枚举校验、每词 ≤2 义项、坏行 fail-fast + 覆盖边界的单元测试 | 解析器 + 测试全绿 |
| T2.4 | 查询层：按方向精确匹配，en→zh 键统一小写归一化 + 单元测试 | `lookup("Abandon")` 能查到 `abandon` |
| T2.5 | 导入校验报告（跳过行数统计）+ 真机查词耗时的粗测 | 有日志报告；查询 < 10 ms |
| T2.6 | `DictionaryService` 门面：所有 UI 统一入口，保证飞行模式下可用 | 断网时 macOS 窗口能显示释义 |

## T3. 后台 API client（共享核心）

| 编号 | 任务 | 完成标准 |
|---|---|---|
| T3.1 | 定义契约模型（`Item`、`HotItem`、`Article`、错误），与 `docs/README.md` 对齐 | Codable 编译通过，字段与契约文档一致 |
| T3.2 | REST client：`/v1/search/news`、`/v1/search/weibo`、`/v1/hot`、`/v1/article` 四个端点 + bearer token 注入 + mock transport 测试 | 四个调用在测试里全部通过 |
| T3.3 | 错误映射：401 → 重新登录信号；402 → 用户提示；429/5xx → 指数退避；其他 4xx → 不重试 + 测试 | 行为在测试中验证 |
| T3.4 | `news_cache` 表（word、payload_json、fetched_at），按板块设 TTL + 测试 | 相同查询在 TTL 内命中缓存 |
| T3.5 | 共享的 Markdown → attributed string 渲染器（阅读视图用） | 两个平台都能渲染标题/链接/列表 |

## T4. macOS 宿主（AppKit）

| 编号 | 任务 | 完成标准 |
|---|---|---|
| T4.1 | 查词窗口骨架（输入框 + 结果区），AppKit 实现、SwiftUI 托管 | 窗口显示、可输入 |
| T4.2 | 接通 输入 → `DictionaryService` → 结果展示（离线链路端到端） | 输入单词显示释义 |
| T4.3 | 词典结果渲染细化（词、词性、义项布局），AppKit 视图 | 与词表数据一致 |
| T4.4 | 全局快捷键（event monitor）呼出/隐藏查词窗口 | 任意应用下快捷键可开关窗口 |
| T4.5 | Accessibility 划词取词：读取前台应用选中文本 + 权限申请流程 | 选中文本进入输入框 |
| T4.6 | 取词 → 归一化 → 查词 → 展示 全链路 | 选中 + 快捷键端到端显示释义 |
| T4.7 | 结果窗口内的新闻 / 微博 / 热搜板块，接后台 client | 三个板块都显示真实数据 |
| T4.8 | 应用内 Markdown 阅读视图（article 端点 + 共享渲染器） | 正文在应用内可读 |
| T4.9 | 空 / 离线 / 错误状态与重试 | 断网表现合理 |

## T5. 鉴权（App 侧）

| 编号 | 任务 | 完成标准 |
|---|---|---|
| T5.1 | Sign in with Apple 流程（按钮、凭证处理、与后台换 token） | Apple 登录拿到 bearer token |
| T5.2 | GitHub OAuth 流程（系统 auth session → code → token） | GitHub 登录拿到 bearer token |
| T5.3 | 手机号登录 UI（号码 + 短信验证码输入） | 手机号登录拿到 bearer token |
| T5.4 | Keychain token 存储（macOS & iOS）+ 401 → 回登录页 | 重启后 token 仍在；401 引导重新登录 |
| T5.5 | 登录窗口/页面与设置里的账号状态 | 两个 App 都可登录/登出 |

## T6. iOS 宿主（UIKit）

| 编号 | 任务 | 完成标准 |
|---|---|---|
| T6.1 | 查词页面骨架（UIKit：输入 + 结果），包给 SwiftUI 做页面管理 | 页面显示、可输入 |
| T6.2 | 接通 输入 → `DictionaryService` → 渲染 | 输入单词显示释义 |
| T6.3 | 词典结果渲染（词、词性、义项） | 与词表数据一致 |
| T6.4 | 新闻 / 微博 / 热搜板块，接后台 client | 三个板块都显示真实数据 |
| T6.5 | 应用内 Markdown 阅读视图 | 正文在应用内可读 |
| T6.6 | 空 / 离线 / 错误状态与重试 | 断网表现合理 |

## T7. 后台服务（独立仓库）

| 编号 | 任务 | 完成标准 |
|---|---|---|
| T7.1 | 鉴权服务：Apple / GitHub / 手机号验证，签发 token，用户存储 | 契约里的登录端点返回 token |
| T7.2 | 封装 DeepSeek Search 实现 `/v1/search/news` | 端点返回结构化条目 |
| T7.3 | 原型验证：`site:weibo.com` 过滤的微博内容质量，调整查询策略 | 质量结论记入文档 |
| T7.4 | 原型验证：热搜数据源（直接抓热搜页 vs 降级摘要方案） | 选型结论记入文档 |
| T7.5 | 按 T7.4 结论实现 `/v1/hot` | 榜单返回排名/标题/链接/热度 |
| T7.6 | 按 T7.3 策略实现 `/v1/search/weibo` | 端点上线 |
| T7.7 | 通过 DeepSeek Fetch 实现 `/v1/article`（Markdown） | 端点返回标题 + 正文 |
| T7.8 | 按用户限流 + 结果缓存 | 限额与 TTL 可生效 |
| T7.9 | 把 DeepSeek 错误映射为契约错误码（401/402/429 语义） | App 收到符合契约的错误 |

## T8. 发布与合规

| 编号 | 任务 | 完成标准 |
|---|---|---|
| T8.1 | GPL-3.0-or-later LICENSE 文件 + 应用"关于"页署名 qingjian | 许可证文件在仓，"关于"页有致谢 |
| T8.2 | App Store 审核用的 Accessibility 用途说明（划词取词理由） | 文案写入应用元数据 |
| T8.3 | 隐私清单 + 账号删除入口（Sign in with Apple 强制要求） | 清单 + 删除流程就绪 |
| T8.4 | 应用图标与基础视觉识别 | 两个平台都有图标 |
