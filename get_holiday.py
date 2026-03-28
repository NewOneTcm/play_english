import cloudscraper
from datetime import datetime

YEAR = 2026
# 记得把这里改成你想要的实际路径，或者直接写 "calendar.txt" 存在当前目录
OUTPUT = "/home/newone/calendar/calendar.txt" 

url = f"https://timor.tech/api/holiday/year/{YEAR}"

# 创建破盾爬虫
scraper = cloudscraper.create_scraper()

try:
    print(f"正在获取 {YEAR} 数据...")
    res = scraper.get(url)
    data = res.json()

    if data.get("code") == 0:
        holiday_data = data["holiday"]
        lines = [f"# ===== {YEAR} 节假日与补班 ====="]

        # 排序处理日期
        for date_short in sorted(holiday_data.keys()):
            info = holiday_data[date_short]
            full_date = f"{YEAR}-{date_short}"
            # 判断逻辑：如果是 holiday 为 True 就是放假，为 False 就是补班
            status = "holiday" if info["holiday"] else "workday"
            lines.append(f"{full_date} {status}")

        with open(OUTPUT, "w", encoding="utf-8") as f:
            f.write("\n".join(lines) + "\n")
        print(f"✅ 成功！文件已生成在: {OUTPUT}")
    else:
        print(f"❌ API 报错: {data.get('msg')}")

except Exception as e:
    print(f"❌ 运行失败: {e}")
