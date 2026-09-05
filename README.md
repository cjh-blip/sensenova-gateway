# sensenova-gateway

把多个 API key 打包成一个稳定出口的本地网关：`429 限流在网关内消化，工具侧永不因节流失败`。

基于 [LiteLLM](https://github.com/BerriAI/litellm) 构建，OpenAI 兼容。仓库以商汤 SenseNova Token Plan（`token.sensenova.cn`）为例，多 key 负载均衡是高可用通用工程实践，任何 OpenAI 兼容端点都适用。

## 为什么

单个免费/低频 key 在并发请求下容易触发分钟级 TPM 限流（429）。本网关把 N 个 key 注册为同一模型名的 N 个 deployment：

- 负载均衡轮询，各 key 分摊 TPM 配额
- 某 key 429 → 冷却 60s → 自动切下一个 → 单请求最多重试 8 次
- 并发摊平：同时最多 3 个请求在飞，其余排队（宁慢勿挂，防瞬时打爆所有 key）
- 单请求最长等 300s（5 分钟）：宁慢勿挂
- 响应原样透传（含 reasoning 字段）

工具侧只需把 `base_url` 指到网关，模型名不变，**永远拿到 200**。

## 快速开始

### 1. 准备 key

在供应商控制台创建 N 个 API key，设为用户环境变量：

```powershell
[Environment]::SetEnvironmentVariable("SENSENOVA_KEY1", "sk-xxx", "User")
# ... SENSENOVA_KEY2 .. N
```

### 2. 配置

编辑 `config.yaml`：每个 key 一段 deployment，模型名统一（如 `deepseek-v4-flash`）：

```yaml
model_list:
  - model_name: deepseek-v4-flash
    litellm_params:
      model: openai/deepseek-v4-flash
      api_base: https://token.sensenova.cn/v1
      api_key: os.environ/SENSENOVA_KEY1
  # 复制以上段，改 KEY 编号，即可加 key
```

重试参数在 `router_settings`（`num_retries` / `timeout` / `cooldown_time` / `retry_after` / `max_parallel_requests`）。

### 3. 启动

```powershell
# Windows
.\start-gateway.ps1        # 或双击 start-gateway.bat
```

启动约 20~30s 就绪，探活：`http://localhost:4000/health/liveliness`。

### 4. 接入工具

| 参数 | 值 |
|---|---|
| base_url | `http://localhost:4000/v1` |
| model | `deepseek-v4-flash`（与 config 的 model_name 一致） |
| api_key | 任意非空值（网关不校验） |

自写脚本示例：

```python
import requests
resp = requests.post(
    "http://localhost:4000/v1/chat/completions",
    headers={"Authorization": "Bearer anything"},
    json={"model": "deepseek-v4-flash",
          "messages": [{"role": "user", "content": "你好"}]},
    timeout=300,
)
print(resp.json()["choices"][0]["message"]["content"])
```

## 自愈（Windows 可选）

`start-gateway.ps1` 幂等：进程活着且端口监听则跳过；进程在但端口死则自动重启。配合计划任务可做到开机自启 + 崩溃自愈：

```powershell
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File D:\path\to\start-gateway.ps1"
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration (New-TimeSpan -Days 999)
Register-ScheduledTask -TaskName "Sensenova_Gateway" -Action $action -Trigger $trigger -Force
```

## 排障

| 现象 | 处理 |
|---|---|
| 连接拒绝 | 网关没起来或还在启动，等 20~30s 看日志 |
| content 为空 | 推理模型会先消耗 token，`max_tokens` 放大（如 32768） |
| 全部 429 | 免费额度窗口耗尽（如 1500 次/5h），等窗口重置；或加 key |
| 新 key 首次 429 | 部分供应商新账号有激活延迟，过一会自动恢复，无需改配置 |

## 合规

多 key 负载均衡是高可用架构的标准实践。请确保你的多 key 使用方式符合供应商服务条款（尤其免费额度）。

## License

MIT
