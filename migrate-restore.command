#!/bin/bash
# 一键还原迁移包到本机（macOS/Linux；不带参数会提示输入路径）
cd "$(dirname "$0")"
if [ -n "$1" ]; then ./asp.sh migrate "$1"; else read -r -p "迁移包路径: " pkg && ./asp.sh migrate "$pkg"; fi
read -r -p "按回车关闭..." _
