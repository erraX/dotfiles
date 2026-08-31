Status: DRAFT
Revision: 5
Execution gate: CLOSED

# Herdr 快捷键重整计划

## 目标

重整 Herdr 的高频快捷键，让 workspace、tab、pane 和 agent 操作形成可预测的规律，并尽量复用 tmux 与当前 Kitty 配置的肌肉记忆。优先覆盖：

- workspace/tab 的创建、关闭、重命名；
- pane 的分屏、关闭、移动焦点、缩放和 resize；
- workspace 与 agent 的导航；
- 消除上述高频操作中的 `prefix+shift+键`。

本计划主要调整 Herdr 键位，并在 Kitty 中仅解除 `Ctrl+Shift+j/k` 两条逐行滚动默认绑定，使该 chord 能传给 Herdr。其余 Kitty 键位不变。低频管理动作（worktree、reload config、swap pane、rename pane 等）暂不为“零 Shift”目标扩大范围。

## 现状与依据

- 当前 Kitty 使用 `Ctrl+A` 作为外层 prefix：`c/x` 创建/关闭 window，`v/s` 分屏，`h/j/k/l` 导航，方向键 resize，数字跳转 tab。
- Kitty 0.45.0 默认将 `Ctrl+Shift+k/j` 绑定为 scroll line up/down；用户确认不使用逐行滚动并授权解除这两条默认绑定。
- 当前 Herdr 使用 `Ctrl+G`，但 workspace 生命周期分散在 `Shift+N/W/D`，tab 重命名/关闭是 `Shift+T/X`，agent 导航是 `Shift+K/J`。
- tmux 的稳定惯例包括：prefix 后 `c` 新建 window、`,` 重命名、`x` 关闭 pane、`h/j/k/l` 或方向键导航、`z` zoom；其核心是“prefix 后单键动作”，而不是持续叠加修饰键。
- Herdr 0.8.2 支持一个 prefix 后的单键、数组别名、直接 modifier chord、数字范围和 Navigate mode；不支持可配置的任意三级命名空间（例如 `prefix+w+c`）。但在 Navigate mode 内，workspace 动作会复用其 prefix 右侧单键，因此可以实现 `prefix+w` 后以普通 `a/m/d` 管理选中 workspace。
- Herdr 0.8.2 的 `close_pane` 已有作用域升级行为：多个 pane 时只关闭 focused pane；tab 只剩一个 pane 时删除该 tab；如果它还是 workspace 的最后一个 tab，则继续进入 workspace 关闭路径。因此无需额外脚本即可让 `Prefix+x` 同时承担 pane/tab 关闭。[实现依据](https://github.com/herdrdev/herdr/blob/v0.8.2/src/workspace.rs#L1209-L1233)
- 参考资料：[tmux Getting Started](https://github.com/tmux/tmux/wiki/Getting-Started)、[Kitty keyboard mapping](https://sw.kovidgoyal.net/kitty/mapping/)、[Herdr Keyboard](https://herdr.dev/docs/keyboard/)、[Herdr Configuration](https://herdr.dev/docs/configuration/)。

## 设计决策

- D1：保留双层 prefix：Kitty `Ctrl+A`，Herdr `Ctrl+G`。不统一两者，避免嵌套 session manager 抢键。
- D2：tab/pane 优先兼容 tmux 和现有 Kitty；workspace 使用独立的 Navigate surface，避免把所有对象硬塞进同一组字母。
- D3：高频动作不得使用 `prefix+shift+键`；允许 prefix 后的普通字母、标点、方向键，或经冲突审计后显式释放的一次性 modifier chord。
- D4：workspace 生命周期采用 `a/m/d`：add、modify name、delete/close。它们既可从 terminal mode 通过 prefix 操作当前 workspace，也可在 `prefix+w` 后直接操作选中的 workspace。
- D5：pane/tab 采用一个上下文关闭键 `Prefix+x`：优先关闭 focused pane，最后一个 pane 自动升级为关闭 tab；不再保留独立的 close-tab 快捷键。workspace 的显式管理键仍为 `d`，且最后一个 tab 触发 workspace 关闭时必须保留 Herdr 的确认保护。
- D6：Herdr 的 `[keys]` 必须同步到当前配置及全部完整主题配置，主题 preset 文件不承载与主题无关的键位。
- D7：Agent 高频导航采用 `Ctrl+Shift+k/j`。在 Kitty 中显式 unmap 同名逐行滚动键后，由 Herdr 直接接收；不再采用 `Ctrl+Alt+k/j`。

## 推荐键位矩阵

### Workspace 与全局导航

| 动作 | 推荐键位 | 说明 |
| --- | --- | --- |
| 打开 workspace navigation surface | `Prefix+w` | 保留 Herdr 默认；进入后用 `j/k` 选择、Enter 聚焦、Esc 退出 |
| 新建 workspace | `Prefix+a`；Navigate mode 内 `a` | add |
| 重命名 workspace | `Prefix+m`；Navigate mode 内 `m` | modify name |
| 关闭 workspace | `Prefix+d`；Navigate mode 内 `d` | delete/close；继续使用 Herdr 的确认流程 |
| 打开全 session navigator | `Prefix+g` | 保留 fuzzy pane/agent 搜索入口 |
| 上一个/下一个 agent | `Ctrl+Shift+k` / `Ctrl+Shift+j` | Kitty 解除同名 scroll-line 默认键后传给 Herdr；不占用 pane 的 `Prefix+h/j/k/l` |
| 按序号聚焦 agent | `Prefix+Alt+1..9` | 可选的确定性跳转 |

### Tab

| 动作 | 推荐键位 | 说明 |
| --- | --- | --- |
| 新建 tab | `Prefix+c` | 保留 Herdr/tmux 惯例 |
| 重命名 tab | `Prefix+,` | 采用 tmux rename-window 惯例 |
| 关闭 tab | `Prefix+x` | 当前 tab 只剩一个 pane 时，由 `close_pane` 自动删除 tab；不配置独立 close-tab 键 |
| 上一个/下一个 tab | `Prefix+p` / `Prefix+n` | 保留 tmux/Herdr 惯例 |
| 跳转 tab 1–9 | `Prefix+1..9` | 保留现状 |

### Pane

| 动作 | 推荐键位 | 说明 |
| --- | --- | --- |
| 左右分屏 | `Prefix+v` | 与当前 Kitty 一致 |
| 上下分屏 | `Prefix+s` | 与当前 Kitty 一致；需把 Herdr Settings 从 `s` 移走 |
| 关闭 pane/tab | `Prefix+x` | 多 pane 时关闭 focused pane；最后一个 pane 自动关闭 tab；最后一个 tab 会进入 workspace 关闭/确认路径 |
| 聚焦 pane | `Prefix+h/j/k/l` | 与 Kitty/Vim/tmux 习惯一致 |
| 直接 resize | `Prefix+方向键` | 与当前 Kitty 一致，适合单次调整 |
| 连续 resize | `Prefix+r` 进入 resize mode | 保留 Herdr modal resize，适合连续调整 |
| zoom/unzoom | `Prefix+z` | 保留 Herdr/tmux 惯例；不复用 Kitty 的 `p`，因为 Herdr 的 `p` 已是 previous tab |

### 必要冲突处理

| 当前动作 | 处理 |
| --- | --- |
| `settings = Prefix+s` | 改为 `Prefix+;`，把 `s` 让给上下分屏 |
| `new_workspace = Prefix+Shift+n` | 替换为 `Prefix+a` |
| `rename_workspace = Prefix+Shift+w` | 替换为 `Prefix+m` |
| `close_workspace = Prefix+Shift+d` | 替换为 `Prefix+d` |
| `rename_tab = Prefix+Shift+t` | 替换为 `Prefix+,` |
| `close_tab = Prefix+Shift+x` | 显式禁用；统一由 `close_pane = Prefix+x` 处理 pane/tab |
| `previous/next_agent = Prefix+Shift+k/j` | 替换为 direct `Ctrl+Shift+k/j` |
| Kitty `Ctrl+Shift+k/j = scroll_line_up/down` | 在 `kitty.conf` 中显式 unmap，让按键传给 Herdr |

## 实施步骤

### P1：应用并同步新的键位矩阵

- 预期结果：优先范围内的键位符合上表，高频路径不再需要 `Prefix+Shift`，且没有重复绑定或被禁用的动作。
- 方法与范围：以显式 `[keys]` 配置覆盖 Herdr 默认值；设置 workspace 生命周期、tab 生命周期、pane split/resize/zoom、agent navigation；让 `close_pane = "prefix+x"` 成为 pane/tab 唯一关闭键并显式禁用 `close_tab`；为 `Prefix+s` 冲突显式迁移 Settings；在 Kitty 中仅添加空 action 的 `Ctrl+Shift+j/k` mappings，解除默认 scroll-line 动作。
- 涉及文件：`config.toml`、`config.quietlight.toml`、`config.tokyonight.toml`、`config.everforest.toml`、`../kitty/kitty.conf`。不把键位写进 `themes/*.toml`，不改其他 Kitty 映射。
- 验证：比较四份 Herdr `[keys]` 完全一致；确认 Kitty 的两条 unmap 生效且其他映射不变；运行格式检查；reload Kitty 与 Herdr 配置，要求 Herdr `status: applied` 且 diagnostics 为空；打开 `Prefix+?` 确认每个动作只显示一次且没有 disabled/conflict。
- 风险/依赖：这些文件已有用户未提交改动，实施时必须做窄范围 patch，不覆盖主题、toast、状态栏或其他现有配置。

<!-- PLAN-REVIEW:P1
status: pending
comment:
response:
-->

### P2：用一次性对象验证实际交互与目标层级

- 预期结果：每个键都作用于预期对象；workspace Navigate mode、active tab、focused pane 和 agent panel 之间不会混淆。
- 方法与范围：会改变 focus、创建对象或执行 close 的自动化验证必须放在独立 named test session 中，不得向共享 session 的外层 Kitty window 注入按键。独立 session 内创建一次性 workspace/tab/pane，依次验证 create → rename → navigate → resize/zoom → close，并覆盖 `Prefix+x` 的三层作用域升级。当前共享 session 仅由用户手动按 `Ctrl+Shift+j/k` 确认 Kitty 透传和 agent 导航。
- 验证：独立 session 中记录每个动作的实际目标和结果，确认 `Prefix+x` 依次只关闭 pane、关闭 tab，并在可能关闭 workspace 时出现确认保护；resize 分别检查四个方向并确认 zoom 可恢复原布局。共享 session 手动确认 `Ctrl+Shift+j/k` 不再滚动 Kitty、能够切换 agent。最后删除 named test session，并再次检查共享 session 未发生拓扑变化。
- 风险/依赖：Kitty 必须成功解除两条默认绑定，否则 `Ctrl+Shift+j/k` 会继续被外层终端消费。named test session 需要单独 client 才能验证真实 UI 输入；在没有隔离 client 时不降级为向共享 focus 注入按键。

<!-- PLAN-REVIEW:P2
status: pending
comment:
response:
-->

## 风险

- R1：Herdr 没有通用的对象命名空间，所以无法同时把 workspace/tab/pane 都设计成完全相同的 `create/rename/close` 三键；本方案通过对象专属键和 Navigate mode 降低记忆成本。
- R2：`Prefix+s` 从 Settings 改为上下分屏会改变一个默认入口；Settings 仍可通过 `Prefix+;` 和鼠标访问。
- R3：`Prefix+x` 是上下文关闭键；在最后一个 pane、最后一个 tab 上会升级到 workspace 关闭路径。必须保留 `confirm_close = true` 的保护，不得在本次改键中顺手关闭确认。
- R4：只改当前 `config.toml` 会在主题切换时回退旧键位，因此四份完整配置必须同步。
- R5：当前工作区有其他未提交修改；实施与验证不得顺手清理、格式化或提交无关内容。
- R6：`Ctrl+Shift+j/k` 不再提供 Kitty 逐行滚动；这是用户明确接受的功能取舍，其他 scrollback 快捷键保持不变。
- R7：共享 Herdr session 的 focused workspace/tab/pane 会被用户或其他 client 并发改变。任何依赖“当前 focus”的自动按键测试都可能命中错误对象；自动化验证必须使用独立 named session 和显式 ID。

## 实施记录

- P1 已执行：四份 Herdr `[keys]` 内容一致，`herdr config check` 全部通过，Herdr reload 返回 `status: applied` 且 diagnostics 为空；Kitty 两条空映射已 reload。
- P2 在共享 session 中止：测试期间 focus 被并发切换，后续 `Prefix+x` 命中了非测试 tab `w2:t6`。测试 workspace `wA` 已删除，且不再向共享 session 注入按键。
- 被关闭 tab 的 Codex session ID `01a055c1-6dff-7a33-bff2-e027cb806469` 已恢复到后台 tab `w2:tA` / pane `w2:pP`，启动参数为 `codex resume 01a055c1-6dff-7a33-bff2-e027cb806469`，Herdr 报告 `interactive_ready: true`、`agent_status: idle`。

## 待确认问题

### Q1：[RESOLVED] Agent 高频导航采用哪一组？

决定采用 direct `Ctrl+Shift+k/j`，并在 Kitty 中解除同名 scroll-line 默认映射。用户确认不需要 Kitty 逐行滚动；该决定替代早先的 `Ctrl+Alt+k/j` 推荐。

<!-- PLAN-REVIEW:Q1
status: accepted
comment:
response: 按用户明确选择采用 Ctrl+Shift+k/j，并解除 Kitty 的同名逐行滚动默认映射。
-->

### Q2：[RESOLVED] 旧的 Shift 键位要立即移除，还是短期保留为别名？

决定立即移除优先范围内的旧绑定，使 `Prefix+?` 保持干净并直接切换到新键位，不保留过渡别名。

<!-- PLAN-REVIEW:Q2
status: accepted
comment:
response: 用户明确要求开始执行，按计划推荐项立即移除旧 Shift 绑定。
-->

### Q3：是否继续进行隔离的 named-session 自动验证？

推荐停止自动 UI 注入，以四份 `config check`、双层 reload 和用户手动按键确认作为本次验收；若确实需要完整自动化交互验证，再单独创建并附加 named test session，不复用当前共享 client。

<!-- PLAN-REVIEW:Q3
status: pending
comment:
response:
-->

<!-- PLAN-REVIEW:OVERALL
status: pending
comment:
response: Revision 5 因共享 focus 竞态重新关闭执行门禁，需用户重新确认验证范围。
-->
