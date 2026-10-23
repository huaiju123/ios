# 墨读 · 小说 / 漫画 / 短剧

一个纯 SwiftUI 的 iOS 阅读器，四个 Tab：**书架（TXT / EPUB / 在线书源）· 漫画（cbz / zip）· 短剧（本地视频）· 我的**。

- 最低系统：iOS 17.0
- 工具链：**Xcode 16 或更新**（工程用 Xcode 16 的 folder-sync 格式，Xcode 15 打不开）
- 依赖：ZIPFoundation（解压）、SwiftSoup（HTML 解析），走 Swift Package Manager，**首次打开需要联网拉包**

## 跑起来

1. 把 `NovelReader` 文件夹拷到 Mac（或 `git clone`）
2. 双击 `NovelReader.xcodeproj`，等 Xcode 自动拉取两个 SPM 依赖（进度条在右上角）
3. 选一台 iPhone 模拟器，`Cmd + R`

首次启动会自动上架一本示例小说《长夜拾光》，点开就能读。

> 如果依赖没自动拉下来：Xcode 菜单 `File → Add Package Dependencies…`，分别添加
> `https://github.com/weichsel/ZIPFoundation.git`（0.9.19+）和
> `https://github.com/scinfu/SwiftSoup.git`（2.6.0+），勾选到 NovelReader target 即可。

## 用 VS Code 开发

先说清楚一件事：**VS Code 是编辑器，不是 iOS 工具链。**

编译、模拟器、签名、装进手机，全都依赖 macOS 上的 Xcode。`SwiftUI`、`UIKit`、`AVFoundation` 只存在于 iOS SDK 里，Windows / Linux 的编译器根本看不到它们——所以在 Windows 的 VS Code 里打开这个工程会满屏红色波浪线，那是环境问题，不是代码问题。

两条路都配好了：

### A. 有 Mac：VS Code 当主编辑器

1. App Store 装 Xcode，然后 `xcode-select --install` 装命令行工具
2. 装 VS Code 扩展 **Swift**（`swiftlang.swift-vscode`，打开文件夹时会自动推荐）
3. VS Code 打开 `NovelReader` 文件夹
4. `Cmd + Shift + B` → 默认任务「iOS: 编译（模拟器）」
5. 运行：命令面板 → `Tasks: Run Task` → 「iOS: 编译并运行（模拟器）」；等价于终端跑 `bash scripts/run-sim.sh`

VS Code 里能：写代码、跳转补全（SourceKit-LSP 会连 Xcode 的 toolchain）、跑构建任务。不能：图形化改签名 / Capabilities / 资源目录，以及断点调试（VS Code 的 Swift 扩展对 Xcode 工程支持一般，调试还是回 Xcode）。我留了「iOS: 用 Xcode 打开工程」这个任务方便两边切换。

**这个工程用的是 Xcode 16 的 folder-sync 格式，新增 `.swift` 文件不需要动工程文件**：VS Code 里直接新建，Xcode 下次打开自动带上。只有加第三方库、改 Info.plist 键、改 Bundle ID 才需要开 Xcode。

### B. 没 Mac：VS Code 写，GitHub 编译

1. 把 `NovelReader` 推到 GitHub
2. push 会自动跑 `.github/workflows/ios-build.yml`（`macos-15` 上编模拟器版），报错看 Actions 日志，`build.log` 也在 artifact 里
3. 想装到手机上：Actions 里手动运行 **Unsigned IPA**，下载 `NovelReader-unsigned-ipa`
4. Windows 上装 [Sideloadly](https://sideloadly.io)，选这个 ipa、填自己的 Apple ID，签进手机
   - 免费 Apple ID：7 天过期、最多 3 个 App；付费开发者账号（$99/年）：一年
   - 装完闪退多半是 Bundle ID 撞了，改 `PRODUCT_BUNDLE_IDENTIFIER` 重新打

Windows 上用 VS Code 的建议：Swift 扩展**别装**（`.vscode/extensions.json` 只推荐、不强制），当文本编辑器用就好。

### 往模拟器里放书

把 epub / cbz 从 Finder 拖到模拟器窗口，文件会进模拟器的「文件」App，然后在 App 里点导入就能选到。

## 功能

### 书架（小说）

- **TXT**：编码自适应 UTF-8 / GB18030 / Big5 / UTF-16；按 `第一章`、`第 12 回`、`第三卷`、`Chapter 3`、`序章`、`楔子`、`番外` 自动分章
- **EPUB**：解压 → 解析 `container.xml` → OPF → spine，按 spine 顺序生成章节；正文按块（段落 / 插图）解析，插图会作为单独的图片页插在正文中；自动提取封面
- **在线书**：书源搜索 → 加入书架 → 打开时拉目录、按章拉正文，读过的章节缓存在本地
- **阅读器**：CoreText 真实分页、左右点击 / 滑动翻页、跨章衔接、目录、整本进度条、5 套配色、字号行距、翻页动画、退出与翻页自动存进度

### 听书（在阅读器底部点「听书」）

- `AVSpeechSynthesizer` 逐句朗读，**读到哪里正文就高亮到哪里**，并自动翻到对应页
- 一章读完自动接下一章
- 后台播放 + 锁屏控制（`UIBackgroundModes: audio`，支持锁屏播放/暂停）
- 可调语速、可选中文音色

### 漫画

- 导入 `cbz` / `zip`（里面是图片），按文件名自然排序成页，自动生成封面缩略图
- 两种阅读模式：**左右翻页**（可双击放大、放大后可拖动）和**上下滚动**（适合条漫）
- 进度按页保存

### 短剧

- 导入本地 `mp4 / mov / m4v`，一次选多个文件就按文件名排成多集
- 全屏播放器：播放/暂停、±15 秒、进度拖动、0.75x–2x 倍速、剧集列表、自动连播下一集
- 记住看到第几集

### 书源

规则引擎，格式见下一节。App 里不带任何书源（见「关于书源」）。

---

## 书源规则格式

一个书源就是一个 JSON。所有字段都是 **CSS 选择器**；以 `@` 开头的部分表示取属性。

```json
{
  "name": "示例源",
  "baseURL": "https://www.example.com",
  "charset": "utf-8",
  "enabled": true,
  "search": {
    "url": "https://www.example.com/search?q={{key}}&page={{page}}",
    "list": "div.result-item",
    "name": "h3 a",
    "author": "span.author",
    "bookURL": "h3 a@href",
    "cover": "img@src",
    "intro": "p.intro"
  },
  "detail": {
    "toc": "#chapter-list dd",
    "chapterName": "a",
    "chapterURL": "a@href"
  },
  "content": {
    "text": "#content",
    "nextPage": "a.next@href",
    "remove": ["div.ad", "script"]
  }
}
```

| 字段 | 说明 |
| --- | --- |
| `search.url` | 搜索地址，`{{key}}` 会被替换成关键词（自动 URL 编码），`{{page}}` 是页码 |
| `search.list` | 搜索结果**每一项**的容器选择器 |
| `search.name` / `author` / `intro` | 在**每一项内部**取文本 |
| `search.bookURL` / `cover` | `选择器@属性`，取链接或图片地址；相对路径会自动补全成绝对地址 |
| `detail.toc` | 目录页每一章的选择器 |
| `detail.chapterName` / `chapterURL` | 在每一章条目内部取章节名和链接 |
| `content.text` | 正文容器，取它的 `innerHTML` 再还原成段落（`<br>`、`</p>` 转换行） |
| `content.nextPage` | 可选，正文分页的「下一页」链接 |
| `content.remove` | 可选，要删掉的节点（广告、脚本等） |

选择器写法就是标准 CSS：`.class`、`#id`、`div > p`、`a[href]`、`:contains(下一页)` 都支持。

### 关于书源

App **不自带任何书源**，需要你自己在「我的 → 书源」里粘贴 JSON。原因有两个：一是各站点结构经常变，规则必须跟着变；二是抓取有版权的正文涉及法律风险，请只对**你有权访问的内容**（自己的站点、授权站点、公版书站点）写规则。示例模板里的 `example.com` 只是占位。

---

## 目录结构

```
NovelReader/
├─ Info.plist                     # 在同步组之外，避免被当成资源重复拷贝
├─ NovelReader.xcodeproj/
├─ NovelReader/
│  ├─ App/NovelReaderApp.swift    # 入口 + 四个 Tab
│  ├─ Core/                       # 路径、编码、文本工具、缩略图
│  ├─ Models/                     # BookMeta / Chapter / Comic / Drama / BookSource
│  ├─ Store/                      # 四个库 + 阅读设置（UserDefaults）
│  ├─ Import/                     # TXT / EPUB / 漫画 / 视频 导入
│  ├─ Reader/                     # CoreText 分页 + 阅读器 UI + 听书面板
│  ├─ Speech/                     # AVSpeechSynthesizer 封装
│  ├─ Network/                    # HTTP、书源规则引擎、发现页
│  ├─ Comic/                      # 漫画书架 / 阅读器 / 可缩放图片
│  ├─ Drama/                      # 短剧书架 / 播放器
│  ├─ Library/                    # 小说书架 / 书封 / 粘贴导入
│  └─ Settings/                   # 我的、书源管理
├─ .vscode/                       # VS Code 任务、推荐扩展、编辑器设置
├─ scripts/                       # build.sh / run-sim.sh / make-ipa.sh
└─ .github/workflows/             # ios-build.yml（推代码就编）/ ios-ipa.yml（手动打未签名 ipa）
```

数据都在沙盒 `Documents/MoDu/`：

```
MoDu/
├─ library.json / comics.json / dramas.json / sources.json
├─ Books/<uuid>/chapters.json + 解压出来的 EPUB 资源 + cover.jpg
├─ Comics/<uuid>/pages/p00001.jpg + pages.json + cover.jpg
└─ Dramas/<uuid>/<视频文件>
```

删 App 就清空，没有云端同步。

## 实现上的几个决定

- **分页用 CoreText**：`CTFramesetter` 量出每页的字符范围，再用同一份 attributed string 画，保证「量出来的页 = 画出来的页」。换字号、转屏重新分页后，用字符锚点还原到同一段话。
- **章节内容是块列表**（`[.text] / [.image]`）：让 TXT、EPUB 插图、漫画式排版能共用一套分页和渲染。
- **TTS 逐句朗读**：把章节按 `。！？；\n` 断句，一句一个 utterance，读完再喂下一句，所以能精确高亮当前句、能中途暂停、能跨章续读。
- **书源用 CSS 选择器**而不是正则：站点改版时改选择器比重写正则容易得多。

## 已知限制（诚实版）

- **没在真机/模拟器上编译过**：这份工程是在没有 Xcode 的环境里写的。结构按 Xcode 16 模板手写，依赖 API 已对照官方 README 核对过，但第一次编译仍可能要修几个小错。报错贴给我就行。
- **书源**：不自带源；不同站点的分页目录（`detail` 多页）还没做，只处理单页目录。
- **听书跨章**：在线书的下一章要先下载，代码里用了「轮询等 2.8 秒」的粗暴做法，弱网时可能断在章首。
- **EPUB**：不解析 CSS，只按结构取正文和图片；脚注、表格、SVG 会被简化成文本或丢弃。加密（DRM）的 EPUB 不支持。
- **漫画**：`cbz` 之外的格式（如 pdf、文件夹导入）不支持；翻页模式下放大后要双击还原才能继续翻页。
- **短剧**：只播本地文件和直接的 mp4/m3u8 地址，没有做站点解析。
- **iOS 17+**：用了 `TabView`/`searchable`/`onChange` 的新写法，没有向下兼容。
- **VS Code**：只配了编辑和构建任务，没有 `launch.json`，断点调试请回 Xcode。

## 如果编译不过

| 现象 | 处理 |
| --- | --- |
| 工程打不开 / target 里没有源文件 | Xcode 版本低于 16，升级 |
| `No such module 'ZIPFoundation'` | SPM 没拉下来，`File → Add Package Dependencies` 手动加 |
| 签名报错 | target 里把 `PRODUCT_BUNDLE_IDENTIFIER` 改成你自己的，Team 选自己的 Apple ID |
| 图标警告 | `AppIcon` 只有 1024 一张，Xcode 15+ 会自动降采样，只是警告 |

命令行编译（本地或 CI）：

```bash
xcodebuild -project NovelReader.xcodeproj -scheme NovelReader \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

## 后面可以加

- 书源：目录分页、多页并发预取、本地书源文件导入/导出
- 阅读：仿真翻页、字体导入、段距字距、书签与批注
- 漫画：pdf / 文件夹导入、双页模式、条漫长图优化
- 短剧：在线剧源、投屏、播放记忆分段
- 通用：iCloud 同步、阅读统计、TTS 后台续读的可靠性
