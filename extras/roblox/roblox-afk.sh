#!/usr/bin/env bash

while true; do
    # ЛКМ
    ydotool click 0xC0
    sleep 1

    # Короткий шаг W
    ydotool key 17:1
    sleep 0.1
    ydotool key 17:0

    sleep 0.3

    # Короткий шаг S
    ydotool key 31:1
    sleep 0.1
    ydotool key 31:0

    sleep 0.3

    # ЛКМ
    ydotool click 0xC0

    # Нажимаем 3 каждые 3 секунды
    for i in {1..240}; do
        sleep 7
        ydotool key 4:1
        sleep 0.1
        ydotool key 4:0
    done
done

