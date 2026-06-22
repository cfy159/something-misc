# Linux → Windows Qt5 交叉编译与打包 操作手册

> **环境:** Ubuntu 24.04 LTS  
> **目标:** 将 Qt5/C++ 桌面应用编译为 Windows .exe，并打包成独立可运行目录  
> **成果:** 最终产物为 9.8MB 的 zip 包，解压即可在 Windows 7/8/10/11 x64 上双击运行

---

## 目录

1. [环境概览](#1-环境概览)
2. [第一步：安装 mingw-w64 交叉编译器](#2-第一步安装-mingw-w64-交叉编译器)
3. [第二步：下载 Qt5 Windows 预编译库](#3-第二步下载-qt5-windows-预编译库)
4. [第三步：准备源码与生成元文件](#4-第三步准备源码与生成元文件)
5. [第四步：交叉编译](#5-第四步交叉编译)
6. [第五步：收集依赖与打包](#6-第五步收集依赖与打包)
7. [第六步：精简与压缩](#7-第六步精简与压缩)
8. [附录：完整脚本](#8-附录完整脚本)

---

## 1. 环境概览

### 1.1 原始项目结构

```
jisuan/
├── CMakeLists.txt          # CMake 构建配置
├── main.cpp                # Qt 应用入口
├── mainwindow.h            # 主窗口头文件
├── mainwindow.cpp          # 主窗口实现（含业务逻辑）
├── mainwindow.ui           # Qt Designer UI 文件
└── build/                  # Linux 本地构建产物
    └── jisuan              # Linux 可执行文件
```

### 1.2 核心原理

交叉编译的核心思路：

```
Linux 主机                         目标: Windows
┌─────────────────┐              ┌──────────────────┐
│ /usr/bin/moc ───┼── 生成 ─────→│ moc_mainwindow.cpp│
│ /usr/bin/uic ───┼── 生成 ─────→│ ui_mainwindow.h   │
│                 │              │                   │
│ mingw-w64 g++ ──┼── 编译 ─────→│ *.o (COFF/PE)     │
│                 │              │                   │
│ Qt5 Windows .a ─┼── 链接 ─────→│ jisuan.exe        │
│ Qt5 Windows .dll┼── 打包 ─────→│ release/          │
└─────────────────┘              └──────────────────┘
```

**三要素：**
1. **交叉编译器** — 能在 Linux 上运行，但生成 Windows PE 格式的目标文件
2. **Windows 版 Qt 库** — 头文件（编译时需要）+ 导入库 `.a`（链接时需要）+ DLL（运行时需要）
3. **主机 Qt 工具** — Linux 版的 `moc`（元对象编译器）和 `uic`（UI 编译器）生成平台无关的 C++ 代码

---

## 2. 第一步：安装 mingw-w64 交叉编译器

### 2.1 常规方式（需要 sudo）

```bash
sudo apt-get install -y mingw-w64
```

### 2.2 免 sudo 方式（本地解压 deb 包）

当没有 sudo 权限时，可手动下载 deb 包并解压到用户目录：

```bash
# 创建工作目录
mkdir -p /tmp/mingw-debs ~/mingw64

# 下载编译工具链
cd /tmp/mingw-debs
apt-get download \
    binutils-mingw-w64-x86-64 \
    gcc-mingw-w64-x86-64-posix \
    g++-mingw-w64-x86-64-posix \
    gcc-mingw-w64-base \
    mingw-w64-x86-64-dev \
    mingw-w64-common

# 解压到用户目录
for deb in *.deb; do
    dpkg-deb -x "$deb" ~/mingw64
done

# 创建符号链接（Ubuntu 的 mingw 包后缀 -posix）
cd ~/mingw64/usr/bin
ln -sf x86_64-w64-mingw32-g++-posix   x86_64-w64-mingw32-g++
ln -sf x86_64-w64-mingw32-gcc-posix   x86_64-w64-mingw32-gcc
ln -sf x86_64-w64-mingw32-cpp-posix   x86_64-w64-mingw32-cpp
ln -sf x86_64-w64-mingw32-gcc-ar-posix x86_64-w64-mingw32-gcc-ar
ln -sf x86_64-w64-mingw32-gcc-nm-posix x86_64-w64-mingw32-gcc-nm
ln -sf x86_64-w64-mingw32-gcc-ranlib-posix x86_64-w64-mingw32-gcc-ranlib

# 验证
~/mingw64/usr/bin/x86_64-w64-mingw32-g++ --version
# 输出: x86_64-w64-mingw32-g++ (GCC) 13-posix
```

> **下载量:** 约 66 MB，从阿里云镜像下载约 55 秒

### 2.3 下载 MinGW 运行时 DLL

编译出来的 exe 和 Qt5 的 DLL 在运行时需要 MinGW 的运行时库：

```bash
cd /tmp/mingw-debs
apt-get download gcc-mingw-w64-x86-64-posix-runtime
dpkg-deb -x gcc-mingw-w64-x86-64-posix-runtime*.deb ~/mingw64
```

此步骤提供以下运行时 DLL（位于 `~/mingw64/usr/lib/gcc/x86_64-w64-mingw32/13-posix/`）：
- `libgcc_s_seh-1.dll` → 异常处理支持
- `libstdc++-6.dll` → C++ 标准库
- `libwinpthread-1.dll` → POSIX 线程支持

---

## 3. 第二步：下载 Qt5 Windows 预编译库

### 3.1 安装 aqtinstall 工具

`aqtinstall` 是 Qt 官方库的命令行下载器，支持指定版本/平台/编译器：

```bash
# 创建独立 venv（避免污染系统 Python）
python3 -m venv /tmp/qtvenv
/tmp/qtvenv/bin/pip install aqtinstall
```

### 3.2 配置国内镜像

Qt 官方源 `download.qt.io` 在国内访问缓慢，配置清华镜像：

```bash
mkdir -p ~/.aqt
cat > ~/.aqt/settings.ini << 'EOF'
[mirrors]
trusted_mirrors = https://mirrors.tuna.tsinghua.edu.cn/qt/

[requests]
max_retries_to_retrieve_hash = 10
EOF
```

### 3.3 下载 Qt5 Windows 库

```bash
# 查看可用版本
/tmp/qtvenv/bin/aqt list-qt windows desktop

# 查看指定版本的可用架构
/tmp/qtvenv/bin/aqt list-qt windows desktop --arch 5.15.2
# 输出: win64_mingw81  (我们需要这个)

# 下载到 ~/Qt5-win
/tmp/qtvenv/bin/aqt install-qt windows desktop 5.15.2 win64_mingw81 -O ~/Qt5-win
```

> **下载量:** 约 1.5 GB（含所有模块），耗时约 82 秒（清华镜像）  
> **我们需要的模块:** qtbase（Core/Gui/Widgets）+ qttools（moc 备用）  
> **说明:** aqt 默认下载所有模块，实际只需 `qtbase`，可用 `-m` 参数指定模块以减小下载量

### 3.4 安装后目录结构

```
~/Qt5-win/5.15.2/mingw81_64/
├── bin/                    # DLL 文件（运行时需要）
│   ├── Qt5Core.dll
│   ├── Qt5Gui.dll
│   └── Qt5Widgets.dll
├── include/                # 头文件（编译时需要）
│   ├── QtCore/
│   ├── QtGui/
│   └── QtWidgets/
├── lib/                    # 导入库（链接时需要）
│   ├── libQt5Core.a
│   ├── libQt5Gui.a
│   ├── libQt5Widgets.a
│   └── libqtmain.a         # Windows 入口点
└── plugins/
    └── platforms/
        └── qwindows.dll     # Windows 平台插件
```

---

## 4. 第三步：准备源码与生成元文件

### 4.1 生成 MOC 文件

Qt 的元对象系统需要 `moc`（Meta-Object Compiler）预处理头文件。**使用 Linux 主机的 moc**（因为生成的 C++ 代码是平台无关的）：

```bash
cd /home/cfy/jisuan

# 生成 moc 预处理文件
/usr/bin/moc mainwindow.h -o moc_mainwindow.cpp
```

### 4.2 生成 UI 文件

Qt Designer 的 `.ui` 文件需要 `uic` 编译为 C++ 头文件：

```bash
# 生成 UI 头文件
/usr/bin/uic mainwindow.ui -o ui_mainwindow.h
```

### 4.3 注意事项

- 必须使用与 **链接时 Qt 版本相近** 的 moc/uic（主机 Qt 5.15.13，Windows Qt 5.15.2，大版本一致即可）
- `moc_mainwindow.cpp` 和 `ui_mainwindow.h` 是中间产物，无需提交版本管理
- 生成的代码平台无关，可安全在交叉编译中使用

---

## 5. 第四步：交叉编译

### 5.1 编译参数说明

```bash
CXX=/home/cfy/mingw64/usr/bin/x86_64-w64-mingw32-g++
QT5=/home/cfy/Qt5-win/5.15.2/mingw81_64

# 编译参数
INCLUDES="-I${QT5}/include \
          -I${QT5}/include/QtWidgets \
          -I${QT5}/include/QtGui \
          -I${QT5}/include/QtCore \
          -I."

FLAGS="-std=c++17 -O2 \
       -static-libgcc -static-libstdc++ \
       -DUNICODE -D_UNICODE -DWIN32"
```

| 参数 | 作用 |
|------|------|
| `-I${QT5}/include` | Qt 模块间引用 `<QtWidgets/xxx.h>` 需要顶层 include |
| `-I${QT5}/include/QtWidgets` | `#include <QMainWindow>` 等直接引用 |
| `-static-libgcc -static-libstdc++` | **仅对我们自己的代码**静态链接这两个库，减小对 MinGW DLL 的依赖 |
| `-DUNICODE -D_UNICODE` | Windows Unicode API |

### 5.2 编译每个源文件

```bash
# 编译 main.cpp
$CXX -c main.cpp -o main.o $INCLUDES $FLAGS

# 编译 mainwindow.cpp（含 Qt GUI 代码）
$CXX -c mainwindow.cpp -o mainwindow.o $INCLUDES $FLAGS

# 编译 moc_mainwindow.cpp（Qt 元对象代码）
$CXX -c moc_mainwindow.cpp -o moc_mainwindow.o $INCLUDES $FLAGS
```

### 5.3 链接

```bash
$CXX main.o mainwindow.o moc_mainwindow.o \
    -o jisuan.exe \
    -L${QT5}/lib \
    -lQt5Widgets -lQt5Gui -lQt5Core -lqtmain \
    -static-libgcc -static-libstdc++ \
    -Wl,-subsystem,windows
```

| 链接参数 | 作用 |
|----------|------|
| `-lQt5Widgets` | Qt Widgets 模块 |
| `-lQt5Gui` | Qt GUI 模块 |
| `-lQt5Core` | Qt Core 模块 |
| `-lqtmain` | Windows 入口点封装（`WinMain` → `main`） |
| `-Wl,-subsystem,windows` | 生成 GUI 应用（无控制台窗口） |

### 5.4 验证

```bash
file jisuan.exe
# 输出: PE32+ executable (GUI) x86-64, for MS Windows

x86_64-w64-mingw32-objdump -p jisuan.exe | grep "DLL Name"
# 输出:
#   DLL Name: Qt5Core.dll
#   DLL Name: Qt5Gui.dll
#   DLL Name: Qt5Widgets.dll
#   DLL Name: KERNEL32.dll
#   DLL Name: msvcrt.dll
#   DLL Name: libwinpthread-1.dll
```

---

## 6. 第五步：收集依赖与打包

### 6.1 需要收集的文件

| 文件 | 来源 | 大小 (strip前) | 说明 |
|------|------|----------------|------|
| `jisuan.exe` | 编译产物 | 414K | 主程序 |
| `Qt5Core.dll` | `${QT5}/bin/` | 7.9M | Qt 核心库 |
| `Qt5Gui.dll` | `${QT5}/bin/` | 9.3M | Qt GUI 库 |
| `Qt5Widgets.dll` | `${QT5}/bin/` | 8.3M | Qt Widgets 库 |
| `libstdc++-6.dll` | MinGW runtime | 26M | C++ 标准库 |
| `libgcc_s_seh-1.dll` | MinGW runtime | 757K | GCC 运行时 |
| `libwinpthread-1.dll` | MinGW runtime | 317K | POSIX 线程 |
| `platforms/qwindows.dll` | `${QT5}/plugins/` | 2.8M | Windows 平台插件 |

### 6.2 收集命令

```bash
RELEASE=/home/cfy/jisuan/release
rm -rf $RELEASE
mkdir -p $RELEASE/platforms

# 主程序
cp jisuan.exe $RELEASE/

# Qt5 DLLs
cp ${QT5}/bin/Qt5Core.dll     $RELEASE/
cp ${QT5}/bin/Qt5Gui.dll      $RELEASE/
cp ${QT5}/bin/Qt5Widgets.dll  $RELEASE/

# 平台插件（关键！缺少则程序无法启动）
cp ${QT5}/plugins/platforms/qwindows.dll $RELEASE/platforms/

# MinGW 运行时 DLLs
MINGW_DLL=/home/cfy/mingw64/usr/lib/gcc/x86_64-w64-mingw32/13-posix
cp /home/cfy/mingw64/usr/x86_64-w64-mingw32/lib/libwinpthread-1.dll $RELEASE/
cp ${MINGW_DLL}/libgcc_s_seh-1.dll  $RELEASE/
cp ${MINGW_DLL}/libstdc++-6.dll     $RELEASE/
```

### 6.3 目录结构

```
release/                    ← 这就是最终的 "绿色免安装包"
├── jisuan.exe
├── Qt5Core.dll
├── Qt5Gui.dll
├── Qt5Widgets.dll
├── libstdc++-6.dll
├── libgcc_s_seh-1.dll
├── libwinpthread-1.dll
├── platforms/
│   └── qwindows.dll        ← 必须保持 platforms/ 子目录结构！
└── README.txt
```

> ⚠️ **关键:** `platforms/qwindows.dll` 必须放在 `platforms/` 子目录中，这是 Qt 查找插件的方式。如果缺少此文件或路径不对，程序启动时会弹框报错 "No platform plugin"。

---

## 7. 第六步：精简与压缩

### 7.1 Strip 去除调试符号

MinGW 的 DLL 中包含了大量调试信息和符号表，使用 `strip` 可大幅缩减体积：

```bash
cd release
x86_64-w64-mingw32-strip \
    jisuan.exe \
    Qt5Core.dll \
    Qt5Gui.dll \
    Qt5Widgets.dll \
    platforms/qwindows.dll \
    libstdc++-6.dll \
    libgcc_s_seh-1.dll \
    libwinpthread-1.dll
```

### 7.2 体积对比

| 文件 | strip 前 | strip 后 | 缩减 |
|------|----------|----------|------|
| Qt5Core.dll | 7.9M | 6.2M | -22% |
| Qt5Gui.dll | 9.3M | 6.8M | -27% |
| Qt5Widgets.dll | 8.3M | 5.5M | -34% |
| libstdc++-6.dll | 26M | 2.1M | -92% |
| jisuan.exe | 414K | 143K | -65% |
| **总计** | **~55M** | **~23M** | **-58%** |

### 7.3 压缩分发

```bash
zip -r jisuan-windows.zip release/
# 最终产物: jisuan-windows.zip (~9.8MB)
```

---

## 8. 附录：完整脚本

### 一键交叉编译脚本

将以下脚本保存为 `build-windows.sh` 即可一键完成全部操作：

```bash
#!/bin/bash
set -e

# === 配置 ===
PROJECT_DIR="/home/cfy/jisuan"
QT5_WIN="/home/cfy/Qt5-win/5.15.2/mingw81_64"
MINGW="/home/cfy/mingw64/usr"
CXX="${MINGW}/bin/x86_64-w64-mingw32-g++"
RELEASE="${PROJECT_DIR}/release"
BUILD="${PROJECT_DIR}/build-win"

# === 路径检查 ===
[ -d "$QT5_WIN" ] || { echo "错误: Qt5 Windows 库未安装"; exit 1; }
[ -f "$CXX" ]     || { echo "错误: mingw-w64 未安装"; exit 1; }

cd "$PROJECT_DIR"
rm -rf "$BUILD" "$RELEASE"
mkdir -p "$BUILD" "$RELEASE/platforms"

# === 1. 生成中间文件 ===
echo ">>> 生成 MOC 和 UIC 文件..."
moc mainwindow.h -o "${BUILD}/moc_mainwindow.cpp"
uic mainwindow.ui -o "${BUILD}/ui_mainwindow.h"

# === 2. 编译 ===
INCLUDES="-I${QT5_WIN}/include -I${QT5_WIN}/include/QtWidgets \
          -I${QT5_WIN}/include/QtGui -I${QT5_WIN}/include/QtCore -I. -I${BUILD}"
FLAGS="-std=c++17 -O2 -static-libgcc -static-libstdc++ -DUNICODE -D_UNICODE -DWIN32"

echo ">>> 编译..."
$CXX -c main.cpp         -o "${BUILD}/main.o"         $INCLUDES $FLAGS
$CXX -c mainwindow.cpp   -o "${BUILD}/mainwindow.o"   $INCLUDES $FLAGS
$CXX -c "${BUILD}/moc_mainwindow.cpp" -o "${BUILD}/moc_mainwindow.o" $INCLUDES $FLAGS

# === 3. 链接 ===
echo ">>> 链接..."
$CXX "${BUILD}"/main.o "${BUILD}"/mainwindow.o "${BUILD}"/moc_mainwindow.o \
    -o "${BUILD}/jisuan.exe" \
    -L"${QT5_WIN}/lib" \
    -lQt5Widgets -lQt5Gui -lQt5Core -lqtmain \
    -static-libgcc -static-libstdc++ \
    -Wl,-subsystem,windows

# === 4. 收集依赖 ===
echo ">>> 收集 DLL..."
cp "${BUILD}/jisuan.exe"                     "$RELEASE/"
cp "${QT5_WIN}/bin/Qt5Core.dll"              "$RELEASE/"
cp "${QT5_WIN}/bin/Qt5Gui.dll"               "$RELEASE/"
cp "${QT5_WIN}/bin/Qt5Widgets.dll"           "$RELEASE/"
cp "${QT5_WIN}/plugins/platforms/qwindows.dll" "$RELEASE/platforms/"

MINGW_DLL="${MINGW}/lib/gcc/x86_64-w64-mingw32/13-posix"
cp "${MINGW}/x86_64-w64-mingw32/lib/libwinpthread-1.dll" "$RELEASE/"
cp "${MINGW_DLL}/libgcc_s_seh-1.dll"  "$RELEASE/"
cp "${MINGW_DLL}/libstdc++-6.dll"     "$RELEASE/"

# === 5. 精简 ===
echo ">>> Strip..."
${MINGW}/bin/x86_64-w64-mingw32-strip "$RELEASE"/*.dll "$RELEASE"/*.exe "$RELEASE"/platforms/*.dll

# === 6. 打包 ===
echo ">>> 压缩..."
cd "$PROJECT_DIR"
zip -r jisuan-windows.zip release/

echo ""
echo "✅ 完成!"
echo "   程序: ${BUILD}/jisuan.exe"
echo "   包:   ${PROJECT_DIR}/jisuan-windows.zip"
echo "   大小: $(du -sh jisuan-windows.zip | cut -f1)"
echo ""
echo "   Windows 使用: 解压 jisuan-windows.zip → 双击 jisuan.exe"
```

### 使用方法

```bash
chmod +x build-windows.sh
./build-windows.sh
```

---

## 常见问题

### Q: 为什么不直接用 CMake 交叉编译？

CMake 的 AUTOMOC 功能会尝试调用 Qt Windows 目录下的 `moc.exe`（Windows 可执行文件），在 Linux 上无法运行。虽然可以设置 `QT_MOC_EXECUTABLE` 指向 Linux 版本的 moc，但 CMake 的 Qt 查找模块在这方面支持不完善，手动编译更可靠。

对于小型项目（<10 个源文件），手动编译比配置 CMake 交叉编译更快。

### Q: 为什么不用 windeployqt？

`windeployqt` 是 Windows 平台上的工具，用于自动收集 Qt 依赖 DLL。在 Linux 交叉编译环境中不可用，需要手动分析依赖并复制文件。

### Q: 能生成静态链接的单文件 exe 吗？

理论上可以，但需要自己编译 Qt5 静态库。预编译的 Qt5 Windows 库是动态链接版本。静态链接 Qt 还需要注意 LGPL 授权问题。

### Q: 为什么最终包 9.8MB 而不是更小？

- Qt5Core + Qt5Gui + Qt5Widgets DLL 共约 18MB（strip 后）
- 这是 Qt 框架本身的体积，类似 .NET Framework
- 如果用户的 Windows 电脑已安装有 Qt5 运行时，理论上只需分发 exe（143KB）

### Q: libstdc++-6.dll 从 26MB strip 到 2.1MB，是否正常？

正常。未 strip 的 MinGW 运行时包含完整调试符号和重定位信息。strip 后仅保留代码和数据段。2.1MB 是正常的 C++ 标准库大小。

---

*文档生成时间: 2026-06-22*  
*基于项目: /home/cfy/jisuan (膜成本计算器)*  
*编译链: mingw-w64 GCC 13 + Qt 5.15.2*
