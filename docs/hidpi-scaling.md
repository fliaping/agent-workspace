# HiDPI 动态缩放 / HiDPI Dynamic Scaling

Selkies WebRTC 会根据浏览器的缩放比例自动调整远程桌面的 DPI。本项目在此基础上增加了完整的桌面环境联动，确保面板、图标、窗口装饰等 UI 元素跟随 DPI 同步缩放。

## 使用方式 / Usage

- **自动适配（默认）**：不设置 `SELKIES_SCALING_DPI`，DPI 随浏览器缩放实时变化
- **固定 DPI**：设置 `SELKIES_SCALING_DPI=192`（2x 缩放），适用于始终 HiDPI 的场景

## 工作原理 / How It Works

```
浏览器缩放 → Selkies 写入新 DPI → watch-dpi.sh 检测变化 → 更新桌面环境配置
Browser zoom → Selkies writes new DPI → watch-dpi.sh detects change → Updates DE config
```

### 两阶段适配 / Two-phase Adaptation

| 阶段 Phase | 脚本 Script | 时机 Timing | 作用 Purpose |
|------------|-------------|-------------|-------------|
| 初始化 Init | `scripts/set-dpi.sh` | 容器启动、DE 启动前 (before DE launch) | 根据 `SELKIES_SCALING_DPI` 预配置 DPI，避免首次启动时 96 DPI 闪烁 |
| 运行时 Runtime | `scripts/watch-dpi.sh` | DE 启动后持续运行 (s6 service) | 监听 DPI 变化，动态更新面板大小、图标、窗口主题等 |

### 各桌面环境适配内容 / Per-DE Adaptation

| 适配项 Component | LXQt | XFCE | KDE |
|-----------------|------|------|-----|
| 字体 DPI (Font DPI) | .Xresources + .xsettingsd | xfconf xsettings | .Xresources + .xsettingsd |
| GTK 缩放 (GTK Scaling) | Gdk/WindowScalingFactor | Gdk/WindowScalingFactor | — |
| 面板/图标 (Panel/Icons) | panel.conf 尺寸 + 重启面板 | xfconf-query 实时更新 | Selkies 原生处理 |
| 窗口装饰 (Window Decorations) | Openbox 主题缩放 | xfwm4 HiDPI 主题切换 | Selkies 原生处理 |
| 光标大小 (Cursor Size) | .xsettingsd | xfconf CursorThemeSize | .xsettingsd |

## 实现细节 / Implementation Details

### set-dpi.sh（初始化阶段）

运行于 `/custom-cont-init.d/`，在桌面环境启动前执行。根据 `SELKIES_SCALING_DPI` 环境变量计算缩放参数：

- **缩放因子**：`SCALE_FACTOR = DPI / 96`（如 192 DPI → 2.0x）
- **整数缩放**：`SCALE_INT`（DPI/96 ≥ 1.75 时为 2，否则为 1），用于 GTK3 的 `Gdk/WindowScalingFactor`
- **光标大小**：`CURSOR_SIZE = DPI / 96 * 32`

按 DE 检测顺序（KDE → XFCE → LXQt）写入对应配置文件：

| DE | 配置文件 |
|----|---------|
| LXQt | `.Xresources`, `.xsettingsd`, `lxqt/session.conf`, `lxqt/panel.conf`, Openbox theme |
| XFCE | `.Xresources`, `xfconf/xsettings.xml`, `xfconf/xfce4-panel.xml` |
| KDE | `.Xresources`, `.xsettingsd`, `kdeglobals`, `kcmfonts` |

### watch-dpi.sh（运行时阶段）

作为 s6 service 持续运行，监听 Selkies 写入的 DPI 变化：

- **XFCE**：每 2 秒轮询 `xfconf-query`（因为 xfconfd 不会立即刷盘到 XML）
- **LXQt/KDE**：通过 `inotifywait` 监听 `.xsettingsd` 文件修改

DPI 变化时执行的操作：

| DE | 操作 |
|----|------|
| LXQt | 更新 GTK 缩放 → 更新面板尺寸并重启 `lxqt-panel` → 更新 session.conf → 缩放 Openbox 主题 |
| XFCE | 通过 xfconf-query 实时更新面板大小、图标、GTK 缩放、xfwm4 主题（自动选择 Default / Default-hdpi / Default-xhdpi） |
| KDE | 重置 `ScaleFactor=1.0` 和 `forceFontDPI=0` 防止与 Selkies DPI 双重缩放 |

### XFCE 特殊处理

XFCE 有独立的 DBUS 隔离问题，详见 [xfce-dpi-scaling.md](xfce-dpi-scaling.md)。关键点：

- Selkies 容器中 xfconf-query 需要注入正确的 `DBUS_SESSION_BUS_ADDRESS`
- 面板尺寸使用 `uint` 类型（非 `int`）
- 面板值需除以 `SCALE_INT` 来补偿 `WindowScalingFactor` 的倍增效果
