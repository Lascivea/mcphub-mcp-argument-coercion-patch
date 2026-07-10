# MCPHub MCP 参数类型补丁

这个补丁解决 Agent 调用 MCP 工具时，把数字或布尔值传成字符串的问题。例如 `{"max_results":"8"}` 会被转换为 `{"max_results":8}`，避免严格类型校验的 MCP 服务报错。

## 功能

- 根据工具 `inputSchema` 转换数字和布尔参数
- `"8"` → `8`，`"3.5"` → `3.5`
- `"true"` / `"1"` → `true`，`"false"` / `"0"` → `false`
- 非法值保持原样，不强行猜测
- 支持 `type: ["integer", "null"]` 联合类型
- 覆盖 `$smart` 和普通 `/mcp/<group>` 路由
- 覆盖普通 MCP server 和 OpenAPI server

## 文件

```text
mcp-argument-coercion/
├── README.md
├── 0001-mcp-argument-coercion.patch
├── docker-compose.patch.yml
└── build-and-run.sh
```

## 使用

本目录位于 MCPHub 源码仓库的 `patches/` 下。补丁文件描述源码改动，构建脚本直接使用当前仓库源码构建镜像。

如果源码还没有这些改动：

```bash
git apply patches/mcp-argument-coercion/0001-mcp-argument-coercion.patch
```

脚本默认使用：

- 源码仓库：当前 MCPHub 仓库
- 部署目录：`/opt/mcphub`
- 原始 Compose：`/opt/mcphub/docker-compose.yml`
- Docker 平台：`linux/amd64`

构建并启动：

```bash
cd patches/mcp-argument-coercion
./build-and-run.sh
```

固定镜像标签：

```bash
MCPHUB_PATCH_IMAGE=mcphub:patched-20260710 ./build-and-run.sh
```

只构建镜像、不重启容器：

```bash
./build-and-run.sh --build
```

自定义部署目录或平台：

```bash
MCPHUB_DEPLOY_DIR=/srv/mcphub \
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
  -f patches/mcp-argument-coercion/docker-compose.patch.yml \
  up -d mcphub
```

覆盖层只修改 `services.mcphub.image`，不会覆盖 `.env`、环境变量、端口、挂载、网络、restart 策略或 `mcphub-postgres` 服务。

## 验证

```bash
bash -n patches/mcp-argument-coercion/build-and-run.sh
git diff --check
```

完整测试需要先安装依赖：

```bash
pnpm install --frozen-lockfile
pnpm test
```

## 设计边界

补丁只修复 MCPHub 转发层的参数类型，不改变 Agent 工具选择、`$smart` 检索阈值、分组逻辑或 MCP server 配置。它不会把任意字符串猜成数字或布尔值，以避免破坏本来就应该是字符串的参数。
