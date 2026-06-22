#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# Linux → Windows Qt5 交叉编译 + 打包 一键脚本
# 用法: ./build-windows.sh
# 前提: 已完成环境安装（见 cross-compile-qt5-windows.md）
# ═══════════════════════════════════════════════════════════════
set -e

# ── 配置 ─────────────────────────────────────────────────────
PROJECT_DIR="/home/cfy/jisuan"
QT5_WIN="/home/cfy/Qt5-win/5.15.2/mingw81_64"
MINGW="/home/cfy/mingw64/usr"
CXX="${MINGW}/bin/x86_64-w64-mingw32-g++"
RELEASE="${PROJECT_DIR}/release"
BUILD="${PROJECT_DIR}/build-win"

# ── 路径检查 ─────────────────────────────────────────────────
[ -d "$QT5_WIN" ] || { echo "❌ Qt5 Windows 库未安装: $QT5_WIN"; exit 1; }
[ -f "$CXX" ]     || { echo "❌ mingw-w64 未安装"; exit 1; }

cd "$PROJECT_DIR"
rm -rf "$BUILD" "$RELEASE"
mkdir -p "$BUILD" "$RELEASE/platforms"

# ── 1. 生成 MOC / UIC 中间文件 ────────────────────────────────
echo ">>> [1/5] 生成 MOC 和 UIC 文件..."
moc mainwindow.h -o "${BUILD}/moc_mainwindow.cpp"
uic mainwindow.ui -o "${BUILD}/ui_mainwindow.h"

# ── 2. 编译 ──────────────────────────────────────────────────
INCLUDES="-I${QT5_WIN}/include \
          -I${QT5_WIN}/include/QtWidgets \
          -I${QT5_WIN}/include/QtGui \
          -I${QT5_WIN}/include/QtCore \
          -I. -I${BUILD}"

FLAGS="-std=c++17 -O2 \
       -static-libgcc -static-libstdc++ \
       -DUNICODE -D_UNICODE -DWIN32"

echo ">>> [2/5] 编译源文件..."
$CXX -c main.cpp                        -o "${BUILD}/main.o"         $INCLUDES $FLAGS && echo "  main.o ✓"
$CXX -c mainwindow.cpp                  -o "${BUILD}/mainwindow.o"   $INCLUDES $FLAGS && echo "  mainwindow.o ✓"
$CXX -c "${BUILD}/moc_mainwindow.cpp"   -o "${BUILD}/moc_mainwindow.o" $INCLUDES $FLAGS && echo "  moc_mainwindow.o ✓"

# ── 3. 链接 ──────────────────────────────────────────────────
echo ">>> [3/5] 链接..."
$CXX "${BUILD}/main.o" "${BUILD}/mainwindow.o" "${BUILD}/moc_mainwindow.o" \
    -o "${BUILD}/jisuan.exe" \
    -L"${QT5_WIN}/lib" \
    -lQt5Widgets -lQt5Gui -lQt5Core -lqtmain \
    -static-libgcc -static-libstdc++ \
    -Wl,-subsystem,windows

file "${BUILD}/jisuan.exe"

# ── 4. 收集依赖 ──────────────────────────────────────────────
echo ">>> [4/5] 收集 DLL..."
cp "${BUILD}/jisuan.exe"                        "$RELEASE/"
cp "${QT5_WIN}/bin/Qt5Core.dll"                 "$RELEASE/"
cp "${QT5_WIN}/bin/Qt5Gui.dll"                  "$RELEASE/"
cp "${QT5_WIN}/bin/Qt5Widgets.dll"              "$RELEASE/"
cp "${QT5_WIN}/plugins/platforms/qwindows.dll"  "$RELEASE/platforms/"

MINGW_DLL="${MINGW}/lib/gcc/x86_64-w64-mingw32/13-posix"
cp "${MINGW}/x86_64-w64-mingw32/lib/libwinpthread-1.dll" "$RELEASE/"
cp "${MINGW_DLL}/libgcc_s_seh-1.dll"  "$RELEASE/"
cp "${MINGW_DLL}/libstdc++-6.dll"     "$RELEASE/"

# ── 5. 精简 + 打包 ────────────────────────────────────────────
echo ">>> [5/5] Strip + 打包..."
"${MINGW}/bin/x86_64-w64-mingw32-strip" \
    "$RELEASE"/*.dll "$RELEASE"/*.exe "$RELEASE"/platforms/*.dll 2>/dev/null || true

cd "$PROJECT_DIR"
zip -rq jisuan-windows.zip release/

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║  ✅ 编译成功!                                ║"
echo "╠══════════════════════════════════════════════╣"
echo "║  exe : ${BUILD}/jisuan.exe"
echo "║  zip : ${PROJECT_DIR}/jisuan-windows.zip"
echo "║  size: $(du -sh jisuan-windows.zip | cut -f1)"
echo "╠══════════════════════════════════════════════╣"
echo "║  Windows 用法: 解压 → 双击 jisuan.exe       ║"
echo "╚══════════════════════════════════════════════╝"
