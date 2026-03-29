#!/bin/bash

# ========= 环境变量（cron必须） =========
export DISPLAY=:0
export XDG_RUNTIME_DIR=/run/user/$(id -u)
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus

# ========= 基础配置 =========
DEVICE="18:BC:5A:AB:9A:31"
AUDIO_DIR="/data/englishpod"
CALENDAR_FILE="/home/newone/calendar/calendar.txt"
LOG_FILE="/home/newone/play.log"

echo "========== $(date '+%F %T') 启动 ==========" >> "$LOG_FILE"

# ========= 防重复 =========
if pgrep -x mpv > /dev/null; then
    echo "⚠️ mpv 已在运行，退出" >> "$LOG_FILE"
    exit 0
fi

# ========= 获取时间 =========
NOW=$(date "+%F %T")
TODAY=$(date +%F)
WEEKDAY=$(date +%u)
TIME=$(date +%H:%M)

# ========= 读取日历 =========
if [ -f "$CALENDAR_FILE" ]; then
    TYPE=$(grep "^$TODAY " "$CALENDAR_FILE" | awk '{print $2}')
else
    TYPE=""
fi

# ========= 判断最终类型 =========
if [ -z "$TYPE" ]; then
    if [ "$WEEKDAY" -ge 6 ]; then
        FINAL="holiday"
    else
        FINAL="workday"
    fi
else
    FINAL="$TYPE"
fi

echo "$NOW | FINAL=$FINAL | TIME=$TIME" >> "$LOG_FILE"

# ========= 时间匹配 =========
HOLIDAY_TIMES=("07:30" "12:10" "18:00")
WORKDAY_TIMES=("06:40" "18:50")

should_run=false

if [ "$FINAL" = "holiday" ]; then
    for t in "${HOLIDAY_TIMES[@]}"; do
        if [ "$TIME" = "$t" ]; then
            should_run=true
        fi
    done
else
    for t in "${WORKDAY_TIMES[@]}"; do
        if [ "$TIME" = "$t" ]; then
            should_run=true
        fi
    done
fi

if [ "$should_run" = false ]; then
    echo "⛔ 当前时间不在执行范围，退出" >> "$LOG_FILE"
    exit 0
fi

echo "✅ 命中执行时间，继续执行" >> "$LOG_FILE"

# ========= 蓝牙启动 =========
echo "🔵 启动蓝牙..." >> "$LOG_FILE"
bluetoothctl power on >> "$LOG_FILE" 2>&1
sleep 2

# ========= 蓝牙连接 =========
echo "🔁 连接蓝牙..." >> "$LOG_FILE"

CONNECTED=0
for i in {1..5}; do
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
    exit 1
fi

# ========= 等待音频设备 =========
echo "⏳ 等待音频设备..." >> "$LOG_FILE"

READY=0
for i in {1..15}; do
    if pactl list short sinks | grep -i bluez > /dev/null; then
        READY=1
        break
    fi
    sleep 1
done

if [ $READY -eq 0 ]; then
    echo "❌ 音频设备未就绪" >> "$LOG_FILE"
    exit 1
fi

echo "✅ 音频设备就绪" >> "$LOG_FILE"

# ========= 播放函数 =========
play_with_fade() {
    local DURATION=$1
    local TARGET_VOL=$2
    local START_VOL=$3

    MP3_LIST=$(mktemp)
    find "$AUDIO_DIR" -type f -name "*.mp3" | sort > "$MP3_LIST"

    SINK=$(pactl list short sinks | grep -i bluez | awk '{print $2}' | head -n1)

    if [ -z "$SINK" ]; then
        echo "❌ 未找到蓝牙设备" >> "$LOG_FILE"
        return 1
    fi

    pactl set-default-sink "$SINK"
    pactl set-sink-volume "$SINK" ${START_VOL}%

    mpv --no-video --quiet --volume=${START_VOL} --playlist="$MP3_LIST" >> "$LOG_FILE" 2>&1 &
    MPV_PID=$!

    sleep 2

    # 渐进音量
    STEP=5
    for ((v=START_VOL; v<=TARGET_VOL; v+=STEP)); do
        pactl set-sink-volume "$SINK" ${v}%
        sleep 2
    done

    sleep "$DURATION"

    kill -INT $MPV_PID 2>/dev/null
    wait $MPV_PID 2>/dev/null

    bluetoothctl disconnect $DEVICE >> "$LOG_FILE" 2>&1

    echo "🛑 播放结束" >> "$LOG_FILE"
}

# ========= 播放 =========
if [ "$FINAL" = "workday" ]; then
    echo "🎧 工作日播放 30分钟" >> "$LOG_FILE"
    play_with_fade 1800 80 10
else
    echo "🎧 节假日播放 40分钟" >> "$LOG_FILE"
    play_with_fade 2400 85 10
fi
