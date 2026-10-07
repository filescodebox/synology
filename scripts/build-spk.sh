#!/usr/bin/env bash
# 组装 PigeonBox 群晖 SPK(noarch docker-compose 包装,无需官方 toolchain)。
#
# SPK 结构(全部一手来源核实,见 README「参考」节):
#   外层 = 未压缩 tar(勿 gzip,否则套件中心报 Invalid file format)
#     ├── INFO                  key=value 元数据(模板注入版本 + package.tgz 校验和)
#     ├── package.tgz           gzip tar(compose.yml + env.example)
#     ├── scripts/              生命周期脚本(0755)
#     ├── conf/privilege        DSM7 降权声明 + docker 组
#     ├── WIZARD_UIFILES/       安装向导(端口/数据目录/管理员密码)
#     ├── PACKAGE_ICON.PNG      64x64(DSM7 规范)
#     ├── PACKAGE_ICON_256.PNG  256x256
#     └── LICENSE
#
# 用法: ./scripts/build-spk.sh <版本号> <构建号>
#   例: ./scripts/build-spk.sh 0.1.0 0001   → dist/pigeonbox_0.1.0-0001.spk
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?用法: build-spk.sh <版本号> <构建号>(例: 0.1.0 0001)}"
BUILD="${2:?缺少构建号(例: 0001)}"
case "$BUILD" in
    [0-9][0-9][0-9][0-9]) ;;
    *) echo "构建号须为 4 位数字(例: 0001)" >&2; exit 1 ;;
esac
INFO_VERSION="${VERSION}-${BUILD}"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

# package.tgz:内容解压到 SYNOPKG_PKGDEST(target),升级随包整体替换
PKGDIR="$STAGE/package"
mkdir -p "$PKGDIR"
cp spk/package/compose.yml spk/package/env.example "$PKGDIR/"
(cd "$PKGDIR" && tar -czf "$STAGE/package.tgz" compose.yml env.example)
CHECKSUM="$(md5 -q "$STAGE/package.tgz" 2>/dev/null || md5sum "$STAGE/package.tgz" | cut -d' ' -f1)"

# INFO:注入版本与校验和
sed -e "s/__VERSION__/${INFO_VERSION}/" -e "s/__CHECKSUM__/${CHECKSUM}/" \
    spk/INFO.tmpl > "$STAGE/INFO"

# scripts/conf/WIZARD/图标/LICENSE
cp -R spk/scripts "$STAGE/scripts"
chmod 0755 "$STAGE/scripts/"*
cp -R spk/conf "$STAGE/conf"
cp -R spk/WIZARD_UIFILES "$STAGE/WIZARD_UIFILES"
cp spk/PACKAGE_ICON.PNG spk/PACKAGE_ICON_256.PNG spk/LICENSE "$STAGE/"

# 文本统一 LF(脚本/INFO 混入 CRLF 是套件执行失败的经典坑)
find "$STAGE" -type f -exec perl -pi -e 's/\r$//' {} +

OUT="dist/pigeonbox_${INFO_VERSION}.spk"
mkdir -p dist
tar -cf "$OUT" -C "$STAGE" \
    INFO package.tgz scripts conf WIZARD_UIFILES \
    PACKAGE_ICON.PNG PACKAGE_ICON_256.PNG LICENSE
echo "✓ ${OUT}"
