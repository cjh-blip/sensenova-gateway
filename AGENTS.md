# AGENTS.md — sensenova-gateway

## 定位
本地 LiteLLM 网关：把 N 个 API key 打包成 OpenAI 兼容出口，429 TPM 限流在网关内消化（冷却切换 + 重试）。工具指向 `localhost:4000` 即得"宁慢勿挂"的访问。

## 怎么跑
- 启动：`start-gateway.bat`（或 `start-gateway.ps1`），幂等 + 半死自愈（进程 + 端口 4000 双检查）
- 自愈（可选）：计划任务每 5 分钟 keep-alive（示例见 README）
- 停止：先禁计划任务再 `Stop-Process -Name litellm`
- 就绪：启动约 20~30s；探活 `http://localhost:4000/health/liveliness`

## 技术栈
LiteLLM（独立 venv `.venv\`，勿污染系统 Python）；OpenAI 兼容转发供应商端点；key 走用户级环境变量 `SENSENOVA_KEY1-N`，config.yaml 只引用不落明文。

## 目录与约定
- `config.yaml`：N 个 deployment 同 `model_name`，负载均衡；加 key 复制段 + 改环境变量名
- `start-gateway.ps1` / `.bat`：启动入口（bat 必须 CRLF，ps1 纯 ASCII）
- `gateway.log` / `gateway.err.log`：运行时日志（重启覆盖，已 gitignore）
- `README.md`：权威文档（快速开始/接入/排障/合规）

## 当前状态
- 多 key 均衡 + 429 自动切换 + reasoning 透传（本机 9 key 实测）
- 唯一注册模型：`deepseek-v4-flash`（其他模型名会 404；按需在 config 加）
- 本机运维细节（计划任务名、key 登记表路径）记录在本地 gitignore 排除的文件中，不入仓库
