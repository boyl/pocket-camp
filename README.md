[![Downloads](https://img.shields.io/github/downloads/boyl/pocket-camp/total?label=Downloads&color=blue)](https://github.com/boyl/pocket-camp/releases) [![Stars](https://img.shields.io/github/stars/boyl/pocket-camp?label=Stars)](https://github.com/boyl/pocket-camp/stargazers) [![Latest Release](https://img.shields.io/github/v/release/boyl/pocket-camp?label=Release)](https://github.com/boyl/pocket-camp/releases/latest) [![License](https://img.shields.io/github/license/boyl/pocket-camp?label=License)](https://github.com/boyl/pocket-camp/blob/HEAD/LICENSE)

# Pocket Camp · 随身营地

**版本 1.0.0 ·《怪物猎人：崛起／曙光》Steam PC**

在任务地图中直接打开游戏原生帐篷菜单，切换武器与整套配装、整理道具、用餐及管理随从。退出后回到打开菜单的位置附近，恢复移动与战斗操作。

**每个任务都可直接使用，无需先进一次帐篷。** 支持探索和正式狩猎任务；不需要每次重置脚本。

## 前置

需要 REFramework。本包不包含框架二进制，不需要其他 Lua 库或配装 Mod。

1. 从 [REFramework 官方 Releases](https://github.com/praydog/REFramework/releases) 下载 **MHRISE.zip**。不要下载 MHWILDS.zip，也不要下载 Source code。
2. 从该压缩包取出 `dinput8.dll`，放到 `MonsterHunterRise.exe` 所在目录。已有正常工作的 REFramework 时可跳过。
3. 官方安装与脚本说明：[REFramework 文档](https://cursey.github.io/reframework-book/#loading-a-script)。

本机实测基线：游戏 **16.0.2.0**，REFramework 构建 `654bac566ad2cb645a5ddbf72d0008e8698187b8`（v.1.5.6 后 8 次提交，2024-05-26 构建）。官方页面目前提供的其他构建未逐一回归；请保留已有可正常运行的框架。

## 安装

1. 正常退出游戏。
2. 在 Steam 库右键游戏 → 管理 → 浏览本地文件，找到 `MonsterHunterRise.exe`。
3. 解压本包，将包内的 **`reframework` 文件夹**复制到游戏根目录，允许合并文件夹。不要把整个 `Pocket-Camp-1.0.0` 外层目录复制进去。
4. 启动游戏。无需手动 Run Script 或 Reset scripts；进入任务后直接使用快捷键。

安装后的路径应为：

```text
MonsterHunterRise/                    ← Steam 打开的游戏根目录
├─ MonsterHunterRise.exe              ← 游戏原有文件
├─ dinput8.dll                        ← REFramework 前置
└─ reframework/
   ├─ autorun/
   │  └─ PocketCamp.lua               ← 本 Mod 唯一运行文件
   └─ data/
      └─ PocketCamp/
         └─ status.json              ← 运行后生成，不随包安装
```

`README.md`、`CHANGELOG.md` 和 `SHA256SUMS.txt` 用于阅读及校验，不必复制进游戏目录。

## 使用

- 手柄：**短按并松开左摇杆 L3**，按住时间须少于 0.4 秒。长按 L3、同时按 L3+R3 不触发。
- 键盘：按 **F10**。
- 打开后使用游戏原生菜单操作。选择原生“返回／离开帐篷”退出，等待人物恢复后再打开。
- 使用前关闭 REFramework 覆盖界面和其他菜单。快捷键用于打开，退出使用原生菜单。
- 单人、联机、战斗中换装、用餐和随从管理已有实机验收。实际可选装备与设施选项仍由游戏原生菜单决定。

## 升级

从 1.0.0 及之后版本升级：退出游戏，只覆盖 `reframework/autorun/PocketCamp.lua`。本版本没有需要迁移的玩家设置，`status.json` 是可重新生成的状态记录。

从此前 CampShortcutProbe／Pocket-Camp-006 研究版升级：退出游戏后，移走以下**本 Mod 旧文件**，再安装新脚本，避免两个入口争用同一快捷键：

```text
reframework/autorun/CampShortcutProbe.lua
reframework/autorun/CampShortcutProbe/
lua/CampShortcutProbe/
```

旧 `reframework/data/CampShortcutProbe/` 是诊断记录，可以留作备份或单独删除。不要删除整个 `autorun`、`lua` 或 `reframework` 文件夹。

## 卸载

退出游戏，删除 `reframework/autorun/PocketCamp.lua`。可选删除 `reframework/data/PocketCamp/`；保留 REFramework 和其他 Mod 文件。正常通过原生菜单更换的装备依然按游戏自身规则保存。

## 兼容与已知限制

- 只在已进入且可操作的任务地图启用；标题、据点、加载中、已有设施菜单或帐篷坐姿未结束时不打开。
- 本版按键固定。若其他 Mod 或个人按键映射也使用短按 L3 / F10，可能同时触发；本 Mod 不吞掉游戏原始按键。L3+R3 已排除。
- 请在菜单正常关闭后退出游戏或重置 REFramework 脚本；菜单打开期间 Reset scripts 未纳入支持流程。
- 尚未验证所有特殊任务类型、竞技场及所有游戏／框架版本，不承诺未来更新自动兼容。
- 如入口不可用，先确认路径正确、覆盖界面已关闭，并查看 REFramework 中 **Pocket Camp** 的状态。排障可提供 `reframework/data/PocketCamp/status.json` 及框架错误日志。

## 1.0.0 要点

- 移除每个任务先进入帐篷的要求；任务切换后直接可用。
- 修复换武器后退出仍保留帐篷坐姿的问题。
- 将验证版整理成独立单文件，移除研究钩子、元数据导出、热重载控制文件及模块镜像依赖。

## 开发与构建

源码使用 MIT License，详见 LICENSE。运行依赖仅为 REFramework；Python 仅用于开发。

- `release-src/`：正式版模块；`build_release.py` 生成独立脚本。
- `reframework/`：保留的研究基线，供历史回归断言使用，不进入安装包。
- `tests/`：Python + lupa（Lua 5.4）测试。安装开发依赖：`python -m pip install lupa==2.8`。
- 构建：`python build_release.py`；验证：`python tests/test_release.py`。
- 打包：`python package_release.py`，制品位于 `dist/`。
- `docs/verification.md` 与 `evidence/release-runtime.json` 记录 1.0.0 实机验收。
