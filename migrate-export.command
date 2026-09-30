#!/bin/bash
# 一键导出本机 agent 环境 -> 迁移包（macOS/Linux，双击或 bash 运行）
cd "$(dirname "$0")" && ./asp.sh export
read -r -p "按回车关闭..." _
