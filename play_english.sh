#!/bin/bash

# ========= 基础配置 =========
DEVICE="18:BC:5A:AB:9A:31"
AUDIO_DIR="/data/englishpod"
CALENDAR_FILE="/home/newone/calendar/calendar.txt"
LOG_FILE="/home/newone/play.log"

echo "========== $(date '+%F %T') 启动 ==========" >> "$LOG_FILE"


set_volume_gradually() {
    local TARGET=$1
    local STEP=$2
    local INTERVAL=$3
    local START=${4:-20}   # 新增：起始音量（默认20）

    echo "🔊 渐进音量启动 (目标=${TARGET}%)" >> "$LOG_FILE"

    SINK=$(pactl list short sinks | grep -i bluez | awk '{print $2}' | head -n1)

    if [ -z "$SINK" ]; then
        echo "❌ 未找到蓝牙音频设备" >> "$LOG_FILE"
        return 1
    fi

    pactl set-default-sink "$SINK"

    # ⭐ 关键：强制设置初始音量
    pactl set-sink-volume "$SINK" ${START}%
    CURRENT=$START

    echo "🔈 初始音量 ${CURRENT}%" >> "$LOG_FILE"

    while [ "$CURRENT" -lt "$TARGET" ]
    do
        CURRENT=$((CURRENT + STEP))

        if [ "$CURRENT" -gt "$TARGET" ]; then
            CURRENT=$TARGET
        fi

        pactl set-sink-volume "$SINK" ${CURRENT}%
        echo "🔊 音量 -> ${CURRENT}%" >> "$LOG_FILE"

        sleep "$INTERVAL"
    done

    echo "✅ 渐进音量完成" >> "$LOG_FILE"
}





# ========= 防重复 =========
pgrep -x mpv > /dev/null && echo "mpv 已在运行，退出" >> "$LOG_FILE" && exit

# ========= 启动蓝牙 =========
echo "🔵 启动蓝牙..." >> "$LOG_FILE"
bluetoothctl power on
sleep 3

# ========= 蓝牙连接（带重试） =========
echo "🔁 尝试连接蓝牙..." >> "$LOG_FILE"

CONNECTED=0

for i in {1..5}
do
    bluetoothctl connect $DEVICE >> "$LOG_FILE" 2>&1
    sleep 3

    if bluetoothctl info $DEVICE | grep "Connected: yes" > /dev/null; then
        echo "✅ 蓝牙连接成功" >> "$LOG_FILE"
        CONNECTED=1
        break
    else
        echo "⚠️ 第 $i 次连接失败" >> "$LOG_FILE"
    fi
done

if [ $CONNECTED -eq 0 ]; then
    echo "❌ 蓝牙连接失败，退出" >> "$LOG_FILE"
    exit
fi

# ========= 等待音频设备 =========
echo "⏳ 等待音频设备准备..." >> "$LOG_FILE"

READY=0

for i in {1..15}
do
    if pactl list short sinks | grep -i bluez > /dev/null; then
        echo "✅ 音频设备就绪" >> "$LOG_FILE"

        READY=1
        break
    fi
    sleep 1
done

if [ $READY -eq 0 ]; then
    echo "❌ 音频设备未就绪，退出" >> "$LOG_FILE"
    exit
fi

sleep 2

# ========= 获取时间 =========
NOW=$(date "+%Y-%m-%d %H:%M:%S")
TODAY=$(date +%F)
WEEKDAY=$(date +%u)

# ========= 读取日历 =========
TYPE=$(grep "^$TODAY " "$CALENDAR_FILE" | awk '{print $2}')

# ========= 判断类型 =========
if [ -z "$TYPE" ]; then
    if [ "$WEEKDAY" -ge 6 ]; then
        FINAL="holiday"
    else
        FINAL="workday"
    fi
else
    FINAL="$TYPE"
fi

echo "$NOW | TODAY=$TODAY | FINAL=$FINAL" >> "$LOG_FILE"

# ========= 播放 =========
echo "🎧 开始播放..." >> "$LOG_FILE"

if [ "$FINAL" = "workday" ]; then
    echo "$NOW | 工作日播放（30分钟）" >> "$LOG_FILE"

    MP3_LIST=$(mktemp)

    find "$AUDIO_DIR" -type f -name "*.mp3" | sort > "$MP3_LIST"

    mpv --no-video --save-position-on-quit --playlist="$MP3_LIST" &

    MPV_PID=$!



    # ========= 渐进音量（关键在这里） =========
    echo "🔊 渐进音量启动..." >> "$LOG_FILE"

    set_volume_gradually 80 5 5 20

    sleep 1800
    kill -INT $MPV_PID 2>/dev/null

    wait $MPV_PID 2>/dev/null

    echo "🔌 断开蓝牙..." >> "$LOG_FILE"
    bluetoothctl disconnect $DEVICE >> "$LOG_FILE" 2>&1

    echo "$NOW | 播放结束（工作日）" >> "$LOG_FILE"

else
    echo "$NOW | 节假日播放（40分钟）" >> "$LOG_FILE"

    MP3_LIST=$(mktemp)

    find "$AUDIO_DIR" -type f -name "*.mp3" | sort > "$MP3_LIST"

    mpv --no-video --save-position-on-quit --playlist="$MP3_LIST" &

    MPV_PID=$!
    # ========= 渐进音量（关键在这里） =========
    echo "🔊 渐进音量启动..." >> "$LOG_FILE"

    set_volume_gradually 85 5 5 20

    sleep 2400
    kill -INT $MPV_PID 2>/dev/null

    wait $MPV_PID 2>/dev/null

    echo "🔌 断开蓝牙..." >> "$LOG_FILE"
    bluetoothctl disconnect $DEVICE >> "$LOG_FILE" 2>&1

    echo "$NOW | 播放结束（节假日）" >> "$LOG_FILE"
fi

echo "========== 结束 ==========" >> "$LOG_FILE"
