# MCPHub MCP 参数类型补丁

这个仓库提供两个可选的 MCPHub 补丁，可以单独或一起使用。

## 1. MCP 参数类型补丁（`0001-mcp-argument-coercion.patch`）

解决 Agent 调用 MCP 工具时，把数字或布尔值传成字符串的问题。例如 `{"max_results":"8"}` 会被转换为 `{"max_results":8}`，避免严格类型校验的 MCP 服务报错。

- 根据工具 `inputSchema` 转换数字和布尔参数
- `"8"` → `8`，`"3.5"` → `3.5`
- `"true"` / `"1"` → `true`，`"false"` / `"0"` → `false`
- 非法值保持原样，不强行猜测
- 支持 `type: ["integer", "null"]` 联合类型
- 覆盖 `$smart` 和普通 `/mcp/<group>` 路由
- 覆盖普通 MCP server 和 OpenAPI server

## 2. Smart Routing 工具描述补充补丁（`0002-smart-routing-extra-hint.patch`）

在 Smart Routing 设置中增加一个**补充说明文字**字段。填写后，这段文字会追加在 `search_tools` 和 `call_tool` 的默认描述后面，不会替换默认描述。留空时保持原有行为不变。

- 后台设置项：`systemConfig.smartRouting.extraToolHint`
- 同时影响 `search_tools` 和 `call_tool` 的描述
- 支持 `$smart` 和 `$smart/<group>` 路由
- 通过仪表盘或 `mcp_settings.json` 持久化

## 文件

```text
mcphub-mcp-argument-coercion-patch/
├── README.md
├── 0001-mcp-argument-coercion.patch
├── 0002-smart-routing-extra-hint.patch
├── docker-compose.patch.yml
└── build-and-run.sh
```

## 使用

这是一个独立补丁仓库，不包含 MCPHub 主项目源码。补丁文件描述源码改动，构建脚本通过 `MCPHUB_SOURCE_DIR` 使用 MCPHub 源码构建镜像。

先准备 MCPHub 源码：

```bash
git clone https://github.com/samanhappy/mcphub.git
cd mcphub
```

如果源码还没有这些改动，在 MCPHub 源码目录按需应用补丁（可以只应用一个，也可以两个都应用）：

```bash
# 参数类型补丁
git apply /path/to/mcphub-mcp-argument-coercion-patch/0001-mcp-argument-coercion.patch

# Smart Routing 描述补充补丁
git apply /path/to/mcphub-mcp-argument-coercion-patch/0002-smart-routing-extra-hint.patch
```

脚本默认使用：

- 源码仓库：由 `MCPHUB_SOURCE_DIR` 指定
- 部署目录：`/opt/mcphub`
- 原始 Compose：`/opt/mcphub/docker-compose.yml`
- Docker 平台：`linux/amd64`

构建并启动：

```bash
cd /path/to/mcphub-mcp-argument-coercion-patch
MCPHUB_SOURCE_DIR=/path/to/mcphub \
./build-and-run.sh
```

固定镜像标签：

```bash
MCPHUB_SOURCE_DIR=/path/to/mcphub \
MCPHUB_PATCH_IMAGE=mcphub:patched-20260710 \
./build-and-run.sh
```

只构建镜像、不重启容器：

```bash
MCPHUB_SOURCE_DIR=/path/to/mcphub ./build-and-run.sh --build
```

自定义部署目录或平台：

```bash
MCPHUB_DEPLOY_DIR=/srv/mcphub \
MCPHUB_SOURCE_DIR=/path/to/mcphub \
DOCKER_PLATFORM=linux/arm64 \
./build-and-run.sh
```

自定义部署目录必须包含原始 `docker-compose.yml` 和 `.env`。

## 回滚

回滚不会删除补丁镜像，也不会修改原始文件，只恢复原 Compose 中的官方镜像：

```bash
./build-and-run.sh --rollback
```

## Compose 覆盖层

`docker-compose.patch.yml` 不是完整 Compose 文件，不能单独执行。手动使用时：

```bash
MCPHUB_PATCH_IMAGE=mcphub:patched-20260710 \
docker compose \
  -f /opt/mcphub/docker-compose.yml \
  -f /path/to/mcphub-mcp-argument-coercion-patch/docker-compose.patch.yml \
  up -d mcphub
```

覆盖层只修改 `services.mcphub.image`，不会覆盖 `.env`、环境变量、端口、挂载、网络、restart 策略或 `mcphub-postgres` 服务。

## 验证

```bash
bash -n build-and-run.sh
git diff --check
```

完整测试需要先安装依赖：

```bash
pnpm install --frozen-lockfile
pnpm test
```

## 设计边界

- `0001-mcp-argument-coercion.patch` 只修复 MCPHub 转发层的参数类型，不改变 Agent 工具选择、`$smart` 检索阈值、分组逻辑或 MCP server 配置。它不会把任意字符串猜成数字或布尔值，以避免破坏本来就应该是字符串的参数。
- `0002-smart-routing-extra-hint.patch` 只追加 Meta-tool 描述文本，不修改 Smart Routing 检索逻辑、阈值、分组或工具调用行为。
