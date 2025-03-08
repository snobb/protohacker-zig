#!/usr/bin/env bash

values=(
    '49 00 00 30 39 00 00 00 65'
    '49 00 00 30 3a 00 00 00 66'
    '49 00 00 30 3b 00 00 00 64'
    '49 00 00 a0 00 00 00 00 05'
    '51 00 00 30 00 00 00 40 00'
)

base=0
for idx in ${!values[@]}; do
    hx=$(printf '%x' $((base)))
    echo "000$hx ${values[idx]}"
    base=$((base+9))
done | xxd -r  | nc localhost 8080 | xxd
