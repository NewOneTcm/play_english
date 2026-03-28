import requests

YEAR = 2026
# 修改为你希望保存的路径，如果在当前目录直接写 "calendar.txt"
OUTPUT = "calendar.txt"

# GitHub 原始数据地址
url = f"https://raw.githubusercontent.com/NateScarlet/holiday-cn/master/{YEAR}.json"

# 1️⃣ 必须加上 Headers，否则 GitHub 可能会拒绝连接
headers = {
    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
}

try:
    print(f"正在从 GitHub 获取 {YEAR} 数据...")
    res = requests.get(url, headers=headers, timeout=10)
    res.raise_for_status()  # 如果状态码不是 200，会直接报错
    
    data = res.json()
    lines = [f"# ===== {YEAR} 节假日与补班 (GitHub源) ====="]

    # 2️⃣ 解析 days 列表
    for day in data.get("days", []):
        date_str = day["date"]
        name = day["name"]
        
        # 这里的逻辑：
        # isOffDay 为 True  -> 放假 (holiday)
        # isOffDay 为 False -> 调休补班 (workday)
        if day["isOffDay"]:
            lines.append(f"{date_str} holiday  # {name}")
        else:
            lines.append(f"{date_str} workday  # {name}补班")

    # 3️⃣ 写入文件
    with open(OUTPUT, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    
    print(f"✅ 成功！文件已保存至: {OUTPUT}")
    print("预览前 5 行：")
    print("\n".join(lines[:6]))

except Exception as e:
    print(f"❌ 运行失败: {e}")
