### 介绍
- BaiNotez APP本地后端源码
- APP下载地址 https://note.bai-keep2025.top:31016/api/download/BaiNotez.apk
- APP官网 https://note.bai-keep2025.top

### 使用
- 确保已安装Anaconda
- 执行run.bat
- 在APP填入
    - 本地后端URL：http://本地IP:8001
    - 本地LLMURL：http://任何支持openai标准接口的api＋端口（如ollama：http://本地IP:11434/v1）
    - 模型名称
    - API key：(ollama)

### 其他说明
- 无窗口模式请确保同意防火墙开放电脑的对应端口，否则需要手动开放
- 支持在仅cpu的环境运行，会自行下载加载small模型
- 在支持cuda的环境会自行下载large-v3，如需修改，请自行替换worker.py