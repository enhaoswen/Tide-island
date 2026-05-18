# Tide Island 代码质量与重构建议报告

> 本报告只记录建议，不修改现有实现。审查时间：2026-05-18。

## 审查范围

- QML 入口与 UI 层：`shell.qml`、`DynamicIslandWindow.qml`、`ControlCenterLayer.qml`、`WorkspaceOverviewLayer.qml`、`ConnectivityDetailPanel.qml` 等。
- C++/Qt 后端：`SysBackend.*`、`WifiController.*`、`BluetoothPairingAgent.*`、`WifiNetworkModel.*`。
- 歌词子程序：`lyricsmpris/*` 与 `tests/lyricsmpris_core_tests.cpp`。
- 构建、打包与启动脚本：`CMakeLists.txt`、`PKGBUILD`、`.SRCINFO`、`tide-island-launcher`、`bin/tide-island-setup`、`ConnectivityBackend/*`。

## 验证结果

- 根项目当前可构建：`cmake --build build` 通过。
- 现有测试通过：`ctest --test-dir build --output-on-failure` 中 1 个测试通过。
- `ConnectivityBackend/` 作为独立子项目不可配置：`cmake -S ConnectivityBackend -B /tmp/tide-connectivity-build` 报错找不到 `BluetoothPairingAgent.cpp`。这说明该目录要么是过期实现，要么构建脚本没有同步。

## 总体判断

项目已经具备较完整的功能，但当前代码的主要问题不是某一处小 bug，而是职责边界混乱：QML 同时负责界面、状态机、进程调度、系统命令、配置解析和业务规则；C++ 后端也把电源、音频、键盘、Hyprland、歌词进程混在一个类里。继续叠功能会让维护成本快速上升。

建议优先做三类改造：

1. 收敛架构：删除过期实现，拆分巨型组件，明确 UI 层与系统服务层边界。
2. 降低运行时风险：替换 QML 里的 shell/sudo/轮询命令，改成可测试、异步、可降级的后端服务。
3. 补齐工程卫生：统一版本、修正文档、增加测试、去掉调试输出和明文敏感配置。

## 高优先级问题与建议

### 1. `DynamicIslandWindow.qml` 过大，承担了过多职责

位置：`DynamicIslandWindow.qml`，全文件 2733 行。典型集中点：

- 根窗口、输入区域、Overview 生命周期：`DynamicIslandWindow.qml:10-240`
- 时钟、全局状态、手势、OSD、通知、蓝牙、MPRIS、歌词、Cava、系统统计：`DynamicIslandWindow.qml:456-1881`
- 大量 Loader 与弹层装配：`DynamicIslandWindow.qml:2257-2673`
- 顶部滚轮手势捕获：`DynamicIslandWindow.qml:2676-2733`

问题：

- 一个文件同时是窗口、状态机、服务协调器、手势控制器、播放器控制器和 UI 装配器。
- `islandState`、`restingState`、`overviewPhase` 都是字符串状态，缺少集中转移表，非法状态组合很难发现。
- 多处临时状态靠 Timer 复位，例如 `autoHideTimer`、`sideTransientRestoreTimer`、`sideSwipeSettleReset`，行为分散。
- Loader 大量 `asynchronous: false`，在切换复杂视图时容易造成主线程卡顿。

建议修改：

- 拆出 `IslandStateController.qml`，集中管理 `normal/custom/lyrics/split/expanded/control_center/notification/bluetooth_expanded/long_capsule` 等状态转移。
- 拆出 `IslandGestureController.qml`，专门处理鼠标、触控、滚轮手势、点击动作映射。
- 拆出 `IslandLayerHost.qml`，只负责各层 Loader 的挂载和参数传递。
- 把 MPRIS 选择、歌词桥接、系统统计、蓝牙连接提示从窗口文件中移出，分别成为小型 controller/service。
- 用枚举式常量或只读对象替代裸字符串，至少建立 `State.isTransient()`、`State.blocksOsd()`、`State.restingProgress()` 这类集中工具。

### 2. `ControlCenterLayer.qml` 混合 UI、系统命令和业务逻辑

位置：`ControlCenterLayer.qml`，全文件 1786 行。典型集中点：

- 大量状态属性：`ControlCenterLayer.qml:30-148`
- TLP 模式检测与 sudo 执行：`ControlCenterLayer.qml:201-343`
- Wi-Fi/蓝牙控制逻辑：`ControlCenterLayer.qml:423-797`
- 亮度/音量 getter/setter：`ControlCenterLayer.qml:583-629`、`ControlCenterLayer.qml:871-930`
- 大量卡片 UI：`ControlCenterLayer.qml:1000-1786`

问题：

- UI 文件直接执行 `sh -lc`、`sudo -S`、`brightnessctl`、`wpctl`，导致错误处理、权限、安全和可测试性都集中在 QML 里。
- TLP、电池抽屉、Wi-Fi、蓝牙、亮度、音量全部塞在一个组件中，任何改动都容易波及整层。
- `ControlCenterLayer.qml:19` 还保留 `// ... rest of properties ...` 这种占位注释，像是生成或迁移遗留。

建议修改：

- 拆出 `BatteryModeController`，把 TLP 状态读取和切换移到 C++/DBus/Polkit 后端。
- 拆出 `BrightnessVolumeController`，统一亮度和音量的读取、设置、防抖、错误提示。
- `ControlCenterLayer.qml` 只保留布局和控件绑定，不直接拼 shell 命令。
- UI 组件拆分为 `BatteryModeCard.qml`、`ConnectivityCards.qml`、`ControlCenterHeader.qml` 等。

### 4. 连接性实现存在两代代码，应该收敛

位置：

- 新路径：`ControlCenterLayer.qml:81-83` 使用 `WifiController` 和 `BluetoothPairingAgent`。
- 旧路径：`ProcessConnectivityProvider.qml` 全文件 858 行，未被其它文件引用。
- 过期模块：`ConnectivityBackend/*`。

问题：

- `ProcessConnectivityProvider.qml` 仍保留一整套基于 `nmcli`/`bluetoothctl` 的实现，但当前界面已经使用 `IslandBackend`。
- `ConnectivityBackend/CMakeLists.txt:14-26` 引用 `BluetoothPairingAgent.cpp`、`WifiController.cpp` 等文件，但这些文件在仓库根目录，不在 `ConnectivityBackend/` 内；独立配置会失败。
- C++ 里的 DBus object path 仍含 `ConnectivityBackend` 命名，例如 `WifiController.cpp:52`、`BluetoothPairingAgent.cpp:19`，和当前 `IslandBackend` 模块命名不一致。

建议修改：

- 删除 `ProcessConnectivityProvider.qml`，或移动到 `legacy/` 并明确标注不参与构建。
- 删除 `ConnectivityBackend/`，或修正为真正可构建的独立模块。二选一，不要保留半残状态。
- 将 DBus object path 从 `ConnectivityBackend` 重命名为当前模块一致的命名，例如 `/com/tideisland/...`。

### 5. QML 中进程和 shell 调用过多，系统交互应该下沉

位置示例：

- 通知监听：`shell.qml:202-215`
- 录屏/pipewire 监听：`shell.qml:396-453`
- Hyprland 数据刷新：`HyprlandData.qml:151-212`
- 壁纸缩略图 shell 脚本：`WallpaperThumbnailCache.qml:105-134`
- Cava 启动脚本：`DynamicIslandWindow.qml:1512-1519`
- 控制中心亮度/音量/TLP 命令：`ControlCenterLayer.qml:201-343`、`ControlCenterLayer.qml:593-629`

问题：

- QML 层直接管理外部进程生命周期，会让 UI 代码变成系统脚本调度器。
- `dbus-monitor`、`pw-mon` 输出解析非常脆弱，格式变化或命令缺失时不容易降级。
- 多个 Process 没有统一错误模型，用户看到的错误提示不一致。

建议修改：

- 建立 `SystemServices` C++ 模块，统一提供通知、录屏状态、音量、亮度、Hyprland 快照、缩略图生成等能力。
- 对外暴露 Q_PROPERTY/Q_SIGNAL，QML 只订阅状态。
- 所有外部命令统一做 executable 检测、超时、错误码映射和日志。
- 能走 DBus/API 的地方避免 `dbus-monitor` 文本解析。

### 6. C++ 后端存在阻塞调用，可能卡住 UI 线程

位置：

- `SysBackend.cpp:381-397` 用 `QProcess::waitForFinished(500)` 取音量。
- `SysBackend.cpp:469-502` 每 200ms 执行 `hyprctl devices -j` 并等待最多 500ms。
- `SysBackend.cpp:504-518` 通过 `pactl get-default-sink` 同步判断蓝牙音频。
- `WifiController.cpp:1579-1582` 所有 DBus method 都使用同步 `systemBus().call()`。
- `LyricsMprisApp.cpp:206-244`、`LyricsMprisApp.cpp:787-808` 同步 DBus 读取 MPRIS 属性和 Position。

问题：

- 同步等待发生在 QObject 所在线程，容易造成动画卡顿和输入延迟。
- `updateCapsLock()` 每 200ms 调一次 `hyprctl`，最坏情况下会持续占用进程资源。
- Wi-Fi 扫描会触发大量 DBus 属性读取，当前实现是串行同步调用。

建议修改：

- `SysBackend` 改为持久化异步 QProcess 或原生 DBus/udev/libinput 状态订阅。
- `WifiController` 改用 `QDBusPendingCallWatcher` 或小型 worker 线程，避免 UI 主线程同步 DBus。
- MPRIS 位置更新尽量使用 `Seeked`、`PropertiesChanged` 与本地时间推算，减少 350ms 同步轮询。

### 7. `SysBackend` 职责过宽且有遗留成员

位置：

- 构造函数一次性启动 Hyprland、电池、音频、亮度、键盘、歌词：`SysBackend.cpp:41-46`
- 头文件里有未使用/疑似遗留声明：`SysBackend.h:76`、`SysBackend.h:94`、`SysBackend.h:113`
- 调试输出：`SysBackend.cpp:254`、`SysBackend.cpp:373`、`SysBackend.cpp:387`、`SysBackend.cpp:394`、`SysBackend.cpp:515`

问题：

- 一个 singleton 覆盖太多系统域，后续测试和错误隔离都困难。
- `queryBluetoothAudioConnected()` 只声明不实现，`m_audioDebounceTimer`、`m_isBluetoothAudioConnected` 未实际使用。
- 正常运行时会产生大量 debug 日志，尤其音量事件。

建议修改：

- 拆成 `PowerBackend`、`AudioBackend`、`BrightnessBackend`、`KeyboardBackend`、`HyprlandEventBackend`、`LyricsProcessSupervisor`。
- 删除未使用成员和未实现声明。
- 调试日志加 `QLoggingCategory`，默认关闭。
- 析构时显式停止进程/定时器，udev 资源用 RAII 包装。

### 8. 配置读取重复解析 JSON

位置：`UserConfig.qml:46-83`

问题：

- `userConfigString()`、`userConfigReal()`、`userConfigArray()`、`userConfigObject()` 每次都调用 `userConfigData()`，而 `userConfigData()` 每次都读取 `FileView.text()` 并 `JSON.parse()`。
- 多个组件各自实例化 `UserConfig`，会重复解析同一个配置文件。

建议修改：

- 将配置改成一个 singleton，例如 `ConfigStore.qml` 或 C++ `UserConfigBackend`。
- 文件变化时解析一次，保存为 `property var data`。
- 所有读取函数只访问缓存对象，并对配置错误暴露 `configError`。

### 9. `lyricsmpris` 功能完整，但 provider 流程重复

位置：

- provider 启动：`lyricsmpris/LyricsMprisApp.cpp:428-547`
- 网络结果分发：`lyricsmpris/LyricsMprisApp.cpp:589-711`
- 解析函数集中在 `lyricsmpris/LyricsCore.cpp:637-838`

问题：

- 每个 provider 都手写 search、sort、download、copy metadata 流程，新增 provider 成本高。
- `handleNetworkFinished()` 变成大型 stage switch。
- 当前测试主要覆盖 core 解析/匹配，缺少 provider pipeline、网络失败、MPRIS 属性变化的测试。

建议修改：

- 定义 `LyricsProvider` 接口：`start(query)`、`handleReply(stage, body)`、`candidateMetadata()`。
- 每个 provider 单独一个文件，`LyricsMprisApp` 只负责调度、接受候选、输出状态。
- 用 fake `QNetworkAccessManager` 或可注入 transport 增加 provider pipeline 测试。

### 10. MPRIS 逻辑在 QML 和 C++ 中重复

位置：

- QML 侧 active player 选择：`DynamicIslandWindow.qml:1742-1819`
- C++ 歌词进程也选择 active player：`lyricsmpris/LyricsMprisApp.cpp:140-304`

问题：

- 播放器选择规则在两处维护，容易出现 UI 显示的播放器和歌词进程查询的播放器不一致。
- QML 自己处理 inline lyrics，C++ 也处理 inline/local/remote lyrics。

建议修改：

- 明确单一事实来源：要么 QML 选择 active player 并把 track query 传给歌词后端，要么 C++ 后端输出完整歌词状态给 QML。
- 保留一套 active player selection policy，并加测试。

### 11. Hyprland 数据刷新策略偏重

位置：`HyprlandData.qml:46-85`、`HyprlandData.qml:151-212`

问题：

- 一个事件可能触发 `clients`、`monitors`、`workspaces`、`activeworkspace` 四个 `hyprctl -j` 命令。
- 虽然有 90ms debounce，但 overview 打开时窗口拖动/切换工作区仍可能频繁启进程。
- 解析错误只 `console.log`，没有状态降级或用户可见错误。

建议修改：

- 优先使用 Quickshell/Hyprland 原生对象和事件，减少 `hyprctl` 快照。
- 若必须快照，集中到 C++ 后端并做增量更新、失败退避。
- 对 `hyprctl` 不存在、JSON 解析失败、超时分别暴露状态。

### 12. 主题值和魔法数字过多

位置示例：

- `ControlCenterLayer.qml:86-108`
- `WorkspaceOverviewLayer.qml:60-65`
- `ConnectivityDetailPanel.qml:83-249`
- `DynamicIslandWindow.qml:531-534`、`DynamicIslandWindow.qml:1449-1458`

问题：

- 颜色、圆角、字体大小、动画时长散落在各文件中，导致视觉一致性依赖人工记忆。
- 同一语义颜色多处硬编码，例如背景、次级文字、强调蓝、错误红。

建议修改：

- 新增 `Theme.qml` 或 `StyleTokens.qml`，集中定义 color、radius、duration、spacing、font size。
- UI 文件只引用语义 token，例如 `Theme.color.accent`、`Theme.radius.card`。
- 对动态岛宽度、阈值、动画时长建立命名常量，避免 `0.56`、`140`、`220` 等裸值散落。

### 13. 构建和打包元数据不一致

位置：

- CMake 项目版本：`CMakeLists.txt:2` 为 `1.0.1`
- PKGBUILD：`PKGBUILD:3-4` 为 `1.0.7`
- `.SRCINFO:3` 为 `1.0.4`
- `PKGBUILD:9` license 为 `unknown`
- `PKGBUILD:36` sha256 为 `SKIP`
- systemd 安装路径硬编码：`CMakeLists.txt:114`

问题：

- 版本来源不一致，会影响发布、AUR、问题排查。
- `.SRCINFO` 没有跟 `PKGBUILD` 同步。
- `sha256sums=('SKIP')` 不适合正式包。
- systemd user service 路径应使用合适的安装目录变量或可配置路径。

建议修改：

- 设定单一版本来源，并由 release 脚本同步 CMake、PKGBUILD、.SRCINFO。
- 明确 license，补充 LICENSE 文件。
- 正式发布包固定 sha256。
- systemd 安装路径改用 `${CMAKE_INSTALL_LIBDIR}/systemd/user` 或发行版可覆盖变量。

### 14. README 已过期且有误导信息

位置：

- `README.md:6` 拼写问题：`Pursuting`
- `README.md:8` 拼写问题：`dependcies`
- `README.md:48` `data` 应为 `date`
- `README.md:169` 仍说 backlight hardcoded 到 `intel_backlight`，但当前代码已经在 `SysBackend.cpp:421-444` 自动检测 backlight。
- `README.md:175` 要求写入 sudo 密码。

建议修改：

- 同步 README 与当前实现，删除过期 hardcoded backlight 说明。
- 移除明文密码建议，改成安全授权说明。
- 增加“哪些功能是可选依赖”的表格，例如 `cava`、`imagemagick`、`NetworkManager/iwd`、`TLP`。
- 补充故障排查：Quickshell 模块路径、IslandBackend 未加载、Hyprland IPC、歌词 helper 未找到等。

### 15. 测试覆盖面过窄

现状：

- 只有 `tests/lyricsmpris_core_tests.cpp` 一个测试目标。
- 根构建测试通过，但主要 UI 行为、系统后端、Wi-Fi/Bluetooth、配置读取、打包没有测试。

建议新增：

- `UserConfig` 解析测试：空文件、非法 JSON、类型错误、watch change。
- `WifiController` 单元测试：用 mock DBus 或拆出纯解析/排序逻辑先测。
- `SysBackend` 纯函数测试：电池状态映射、Hyprland 事件解析、音量输出解析、亮度路径选择。
- `HyprlandData` 的事件分类测试，至少把 `queueRefreshForEvent()` 的规则迁到可测函数。
- `lyricsmpris` provider pipeline 测试：网络失败、低分候选、高置信同步歌词、纯文本歌词回退。

## 中优先级问题与建议

### 16. 通知监听使用 `dbus-monitor` 文本解析

位置：`shell.qml:111-190`、`shell.qml:202-215`

问题：

- 通过 `dbus-monitor` 输出行数和顺序推断 appName/summary/body，依赖外部命令文本格式。
- 不处理通知图标、actions、urgency、replacesId 等信息。

建议修改：

- 实现轻量 `org.freedesktop.Notifications` 代理/转发，或使用 Quickshell 提供的通知服务能力。
- 把通知对象建模为结构化数据，而不是从文本行提取。

### 17. 录屏检测逻辑脆弱

位置：`shell.qml:221-384`、`shell.qml:396-453`

问题：

- 同时解析 Portal DBus、`pw-mon` 文本和 `pw-cli ls Node` 快照，逻辑复杂且难测试。
- PipeWire 节点文本匹配关键词，误报/漏报都难排查。

建议修改：

- 封装为 C++ `ScreenCaptureMonitor`，用可测试的 parser 和明确状态机。
- 对 `pw-cli`/`pw-mon` 缺失时给出禁用状态，而不是静默重启。

### 18. 壁纸缩略图生成应从 shell 脚本改为后端任务

位置：`WallpaperThumbnailCache.qml:94-134`

问题：

- QML 内拼 `sh -lc` 脚本，可读性低。
- `quality=$7` 等位置参数容易误改。
- 文件系统错误、ImageMagick 缺失、图片格式失败没有可见错误模型。

建议修改：

- 使用 C++ `QImageReader/QImageWriter` 生成缩略图，或把 ImageMagick 调用放入 C++ 后端。
- 缓存 key 应包含源文件 mtime/size 或内容 hash，避免同路径内容变化但时间戳异常时缓存错误。

### 19. Header include 有重复和整理空间

位置：

- `WifiController.h:3-22`
- `BluetoothPairingAgent.h:3-12`

问题：

- 头文件中重复 include `QObject`、`QVariant`、`QDBusMessage` 等。
- include 顺序不统一。

建议修改：

- 移除重复 include，尽量前置声明。
- 建立简单 include 规范，降低编译依赖。

### 20. 日志系统需要规范化

位置：

- `SysBackend.cpp:254`、`SysBackend.cpp:373`、`SysBackend.cpp:387`、`SysBackend.cpp:394`、`SysBackend.cpp:515`
- `WifiController.cpp:302`、`WifiController.cpp:801-826`
- `HyprlandData.qml:34`

问题：

- 正常状态变化使用 debug 输出，长期运行会刷日志。
- QML/C++ 日志风格不统一。

建议修改：

- C++ 使用 `QLoggingCategory`，例如 `tide.audio`、`tide.power`、`tide.wifi`。
- QML 只保留用户可见错误或受配置开关控制的 debug。

## 低优先级与清理项

### 21. 本地工作区存在未跟踪的 Python 缓存

位置：`bin/__pycache__/tide-island-setupcpython-314.pyc`

说明：

- `.gitignore` 已忽略 `*.pyc` 和 `__pycache__/`，该文件未被 git 跟踪。
- 建议清理本地缓存，避免误打包或人工查看时混淆。

### 22. `file(GLOB "*.qml")` 安装方式可维护性一般

位置：`CMakeLists.txt:78-80`

问题：

- 所有根目录 QML 会被自动安装，未来临时 QML/实验 QML 容易被带入包。

建议修改：

- 改成显式 QML 文件列表，或建立 `qml/` 目录并只安装该目录。

### 23. UI 文案未国际化

位置：多处 QML 和 C++ 字符串。

建议修改：

- 若项目面向多语言用户，把用户可见文本集中为 `Strings.qml` 或 Qt 翻译资源。
- 至少先集中错误文案，避免同类错误在不同位置说法不一致。

## 建议的重构顺序

### 第一阶段：低风险卫生清理

1. 删除或归档 `ProcessConnectivityProvider.qml`。
2. 删除或修复 `ConnectivityBackend/`。
3. 同步 `CMakeLists.txt`、`PKGBUILD`、`.SRCINFO` 版本。
4. 移除 `SysBackend`、`WifiController` 中默认开启的 debug 输出。
5. 修正 README 过期内容和拼写错误。
6. 删除未使用声明和成员：`queryBluetoothAudioConnected()`、`m_audioDebounceTimer`、`m_isBluetoothAudioConnected`。

### 第二阶段：安全与系统服务下沉

1. 移除 `tlpSudoPassword` 和 setup wizard 的密码采集。
2. 把亮度、音量、TLP、电源、通知、录屏监控迁入 C++ 后端。
3. 给所有外部命令建立统一错误模型。
4. 把 `SysBackend` 拆成多个小 singleton 或一个聚合模块下的多个 QObject。

### 第三阶段：QML 组件拆分

1. 拆 `DynamicIslandWindow.qml`：状态机、手势、层宿主、MPRIS、系统统计分离。
2. 拆 `ControlCenterLayer.qml`：UI 卡片与 controller 分离。
3. 引入 `Theme.qml`，替换散落的颜色、圆角、动画时长。
4. 把 `UserConfig.qml` 改成缓存型 singleton。

### 第四阶段：异步化与测试

1. `WifiController` 改异步 DBus 或 worker 线程。
2. `SysBackend` 去掉阻塞 `waitForFinished()`。
3. `lyricsmpris` provider 改策略类，并补 provider pipeline 测试。
4. 增加后端纯函数测试和配置解析测试。

## 可作为验收标准的目标

- `DynamicIslandWindow.qml` 降到 800 行以内。
- `ControlCenterLayer.qml` 降到 600 行以内。
- QML 中不再出现 `sudo -S`、`sh -lc`、`dbus-monitor` 这类系统实现细节。
- `ProcessConnectivityProvider.qml` 与 `ConnectivityBackend/` 不再处于“看似可用但实际不用/不可构建”的状态。
- `ctest` 至少覆盖歌词 core、配置解析、Wi-Fi 网络排序/过滤、系统输出解析。
- 正常运行日志中不再刷音量、电池、Wi-Fi debug。
- README 中不存在明文密码建议，版本与打包文件一致。

