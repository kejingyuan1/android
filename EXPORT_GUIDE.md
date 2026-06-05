# Skyline Lite — 导出为 Android APK 指南

## 前置条件

1. **安装 Godot 4.4+**
   - 下载地址: https://godotengine.org/download
   - Windows 版，约 50MB，解压即用，无需安装

2. **安装 Android SDK**（可选，Godot 可自动下载）
   - Godot → Editor → Editor Settings → Export → Android
   - 点击 "Android SDK Setup"，Godot 会自动下载所需组件

## 步骤

### 第一步：打开项目

1. 启动 Godot
2. 点击 "Import"
3. 浏览到 `city-builder/project.godot`，选择并打开
4. 等待项目加载完成

### 第二步：配置 Android 导出

1. **菜单栏** → Project → Export
2. 点击 "Add..." → 选择 "Android"
3. **填写必要信息**：
   - `Package Name` → `com.yourname.skylinelite` (可自定义)
   - `Version` → `1.0.0`
4. **生成 Keystore**（Android 签名需要）：
   - 点击 "Generate" → 填写信息 → 保存到本地
5. 确保底部 "Export Debug" 和 "Export Release" 按钮可用

### 第三步：导出 APK

1. 在 Export 窗口点击 "Export Project"
2. 选择保存位置，命名 `SkylineLite.apk`
3. 等待编译完成（约 1-2 分钟）

### 第四步：安装到手机

1. 将 APK 文件传到手机（USB / 微信 / 网盘）
2. 手机端打开 APK 文件
3. 系统可能提示"未知来源安装"，点"继续安装"
4. 安装完成后即可打开游戏

---

## 常见问题

### Q: Godot 提示 "No Android export templates found"
A: Editor → Manage Export Templates → 点击 "Download" 下载 Android 模板

### Q: APK 安装后闪退
A: 可能原因是 Godot 项目的渲染设置。在 Godot 中：
   - Project → Project Settings → Rendering → Renderer
   - 确保 `Rendering Method` 设置为 `gl_compatibility`
   - 重新导出

### Q: 触摸无反应 / 手势不灵敏
A: 在 Godot 编辑器中：
   - Project → Project Settings → Input Devices → Pointing
   - 确保 `Emulate Touch From Mouse` = ON
   - 重新导出

---

## 后续开发

- 修改游戏参数: `data/balance.gd`
- 修改游戏逻辑: `scripts/` 目录下对应文件
- 修改 UI 布局: `main.tscn` + `scripts/ui/` 目录

## 技术支持

有任何问题直接告诉我，我来帮你排查。
