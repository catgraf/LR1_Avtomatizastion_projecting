#!/usr/bin/env bash
set -e  # остановиться при первой ошибке

# Файлы, участвующие в сборке
FILES="APB_slave.sv APB_master.sv APB_top.sv APB_top_tb.sv"
OUT="tb_top.out"

echo "=== Компиляция ==="
iverilog -g2012 -Wall -o "$OUT" $FILES
echo "OK: $OUT"

echo
echo "=== Симуляция ==="
vvp "$OUT"
