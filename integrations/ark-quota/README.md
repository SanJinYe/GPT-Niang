# Ark 额度查询器修复补丁

挂件通过本机 `ark-connection.json` 指向的 `handoff.py usage` 查询 Coding Plan。查询器不属于本仓库，因此这里保存对应源码及测试的差异补丁，不包含账户配置、密钥或额度快照。

`refresh-lock.patch` 修改查询器的 `ark_usage.py` 和 `tests/test_ark_usage.py`：用操作系统文件锁替代文件存在标记；进程被强制终止时自动释放锁。锁文件保留在磁盘上，文件存在不再代表正在查询。补丁附带并发互斥及强制终止后重新获取锁的测试。

在查询器目录应用（先停止使用旧版查询器的进程，避免新旧锁协议同时运行）：

```text
git apply --unidiff-zero --check <本仓库绝对路径>/integrations/ark-quota/refresh-lock.patch
git apply --unidiff-zero <本仓库绝对路径>/integrations/ark-quota/refresh-lock.patch
python -m unittest discover -s tests -p test_ark_usage.py
```

若检查失败，先检查查询器版本或是否已经应用；不要强制覆盖。当前本机已经应用并通过 15 项测试。挂件更新不自动修改外部查询器，其他机器需单独应用此补丁。

挂件自身的防护位于 `runtime/dual-quota.ps1`：连续收到刷新中超过 60 秒后显示失败，而非无限等待；成功返回会清除等待状态。

其他账户查询同步检查结果：

- OpenAI、Anthropic 分页查询增加每账户 30 秒总期限，单个请求最多 15 秒，防止逐页重新计时拖垮整个批次。
- OpenRouter 的余额与 Key 查询独立保留成功结果，失败项不会伪装为零余额。
- 第三方查询的标准输入允许首尾 BOM/空白，兼容 Windows PowerShell 5.1 输出；其后台进程已有 3 分钟整体期限。
- Codex 查询已有超时，Windows 工作进程由命名管道维持互斥，进程结束会释放所有权，无需套用 Ark 文件锁补丁。
