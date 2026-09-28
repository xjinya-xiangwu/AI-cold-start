#!/usr/bin/env bash
cd "$(dirname "$0")"
bash ./asp.sh update
echo
read -r -p "回车关闭..." _
