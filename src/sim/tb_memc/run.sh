#!/bin/bash
# tb_memc: the tree decode of memc_translator against the original chain (iverilog, seconds)
set -e
cd "$(dirname "$0")"
mkdir -p ../build/tb_memc
B=../build/tb_memc
git show 81feb14:src/rtl/sv2v/memc_translator.v | sed 's/^module memc_translator/module memc_translator_old/' > $B/memc_translator_old.v
iverilog -g2005 -o $B/tb tb_memc.v ../../rtl/sv2v/memc_translator.v $B/memc_translator_old.v
vvp -n $B/tb | grep -v '^writing to table'
