# play_english
auto play english in the morning.


## 实现效果

### 自动生成节假日 

#### get_holiday.py

- 从网站下载加班和补班的日期，自动生成calendar.txt

#### get_holiday_git.py
- 如果前一个不可用，可以使用这个，自动生成calendar.txt


### 播放功能 play_english.sh
- 每天自动开始播放Englishpod节目。
- 打开蓝牙连接音箱，播放结束后关闭蓝牙连接
- 播放时使用渐进式增加音量
- 播放指定时间时间，暂停，下次进入时，按上一次的进度继续播放。
- 根据节假日来定时开始播放，考虑了调休的日期。


## 配置环境

需要使用linux环境
有一个带蓝牙的音箱

### 连接蓝牙

本文件是使用我的蓝牙mac地址，你需要修改为你蓝牙设置的mac地址。

###  下载英语

你需要下载englishpod到你指定的文件夹。

你可以在网上找搜索 

### 添加定时任务

在craontab 中添加定时任务，这样就可以自动执行了。
