#!/bin/bash
# Firefly 开发服务器启动脚本
# 用法：在终端运行 ./start-dev.sh

cd "$(dirname "$0")"

echo "========================================="
echo "  Firefly 开发服务器"
echo "  地址: http://localhost:4321/"
echo "  按 Ctrl+C 停止服务器"
echo "========================================="
echo ""

pnpm dev
