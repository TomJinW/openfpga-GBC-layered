# openfpga-GBC-layered for Analogue Pocket

This is TomJinW's layered fork of [budude2/openfpga-GBC](https://github.com/budude2/openfpga-GBC), which was ported from the [MiSTer Gameboy core](https://github.com/MiSTer-devel/Gameboy_MiSTer).

The packaged cores install as `budude2-TomJinW.GB-layered`, `budude2-TomJinW.GBC-layered`, `budude2-TomJinW.GB-rumble` and `budude2-TomJinW.GBC-rumble`, so they can coexist with the original `budude2.GB` and `budude2.GBC` cores. They continue to use the shared `gb` and `gbc` platform asset directories.

This fork has two kinds of cores, both of which load the ROM file from the SD
card and use the inserted physical cartridge for something:

- **layered** (`GB-layered`, `GBC-layered`): the cartridge provides the mapper
  control, the save memory, and RTC or other cartridge peripherals. The ROM file
  and the cartridge must be the same game with a compatible mapper and save
  layout, for example a translated or patched ROM with the original cartridge.
  The save always stays on the cartridge.
- **rumble** (`GB-rumble`, `GBC-rumble`): the save is on the SD card and a
  genuine MBC5+RUMBLE cartridge is only used as the rumble motor (see below).

Use the original core for normal ROM-only or cartridge-only play.

## Installation
To install the core, merge the `Assets`, `Cores`, and `Platforms` folders into the root of your SD card. Do not replace the existing `Assets` or `Platforms` folders when installing alongside the original core.

Place the GBC bios in `/Assets/gbc/common` named "gbc_bios.bin", the GB bios in `/Assets/gb/common` named "gb_bios.bin", and the SGB bios in `/Assets/gb/common` named "sgb_boot.bin".


## Usage
Insert the matching physical cartridge before starting the core. Select the
patched ROM in the file browser from `/Assets/gbc/common` or
`/Assets/gb/common`. Save data is read and written on the physical cartridge
and no SD save file should be created (the layered cores report no save to the
Pocket). To use a rumble cartridge only as a motor with an SD save, use the
rumble cores (see below). Back up the cartridge save before using a layered
core with a cartridge whose save matters to you.

### Startup safety check

Before the game starts, the core reads the cartridge header (read-only, no
writes to the cartridge) and shows a confirmation screen with the cartridge's
and the ROM file's title, mapper type, ROM size and RAM size. The game stays in
reset, and the cartridge's write line is not driven, until you continue.

- The screen only offers `>CONTINUE`: press A once to start when the headers
  match. There is no CANCEL on this screen; the Pocket menu button quits the
  core.
- If the cartridge has no valid Nintendo logo or header checksum, the screen
  shows `NO VALID GB/GBC CARTRIDGE` and CONTINUE is disabled.
- The title, cartridge type and RAM size should match between the cartridge and
  the ROM file. If they differ, the screen shows `HEADER FIELDS DIFFER` in
  amber, and pressing A opens an `ARE YOU SURE?` screen with CANCEL (the
  default) and CONTINUE. Choose with the D-pad and press A; B, or A on CANCEL,
  goes back. The wrong ROM can erase the cartridge save.
- ROM size and the header/global checksums are shown or ignored but do not
  trigger the warning, since translated or patched ROMs commonly change them.
  A different ROM size is visible on the screen, but it is up to you to judge
  whether it is expected.
- A button held while picking the ROM file is ignored until released.

## Building

Quartus Lite 18.1, device 5CEBA4F23C8, project `src/ap_core.qpf`. The first
lines of `src/core/core_top.sv` select the core: `` `define isgbc `` (0 = GB,
1 = GBC) and `` `define isrumble `` (0 = layered, 1 = rumble). The packaged
cores use `set_global_assignment -name SEED 2`, which is not stored in this
repository's `ap_core.qsf`: place and route is sensitive to the seed, and with
other seeds some variants had a small negative hold slack. The release bitstream
is `output_files/ap_core.rbf` with the bits of every byte reversed
(`gb.rbf_r` / `gbc.rbf_r` in the core folder from `pkg/`).
`src/core/layered_startup_video.sv` is a generated text display; the generator
is not part of this repository.

## Status

The four cores were compiled with Quartus Lite 18.1 on 2026-10-31 using Apple
Container and Rosetta on an Apple silicon Mac, with `SEED 2`. All reported
timing slacks were positive; the smallest is +0.012 ns (GB-layered), so a
different Quartus version or seed may not give the same result. The author
tested them on an Analogue Pocket on 2026-11-01 and reports that they basically
work; no detailed per-feature results were recorded.
Sleep support is disabled. Avoid save states until restoring the cartridge's
mapper and peripheral state is validated. MBC7 and other special cartridges
need separate validation.

## Rumble variants (SD save)

Two more cores, `GB-rumble` and `GBC-rumble`, are built from the same sources
for one job: run any game from the SD card, with its save on the SD card, and
use a genuine MBC5+RUMBLE cartridge (header type 0x1C-0x1E) only as the rumble
motor. The layered cores (`GB-layered`, `GBC-layered`) always use the
cartridge save; the rumble cores always use the SD save. There is no switch.

In a rumble core:

- The startup screen only checks that the inserted cartridge is MBC5+RUMBLE.
  Any other cartridge shows `NEED MBC5 RUMBLE CARTRIDGE` and CONTINUE is
  disabled, so a rumble core can never write another cartridge's save.
- The ROM, its save RAM and RTC stay on the SD card
  (`Saves/<platform>/<core>/<rom name>.sav`, sized from the ROM's own header).
- The only thing sent to the cartridge is the game's writes to the MBC5 RAM bank
  register (0x4000-0x5FFF), whose bit 3 drives the motor. Nothing is read from
  the cartridge and its RAM is never enabled or written.
- The title/type/RAM mismatch warning does not apply.

The layered cores report no save to the Pocket, so they should create no `.sav`
file.

---

## 简体中文说明

这是 TomJinW 的“分层（layered）”分支，基于 [budude2/openfpga-GBC](https://github.com/budude2/openfpga-GBC)，后者移植自 [MiSTer Gameboy 核心](https://github.com/MiSTer-devel/Gameboy_MiSTer)。

打包后的核心安装为 `budude2-TomJinW.GB-layered`、`budude2-TomJinW.GBC-layered`、`budude2-TomJinW.GB-rumble`、`budude2-TomJinW.GBC-rumble`，可以和原版的 `budude2.GB`、`budude2.GBC` 核心并存，仍然共用 `gb` 和 `gbc` 平台资源目录。

### 核心种类

所有核心都从 SD 卡加载 ROM 文件，并用插入的实体卡带做一件事：

- **layered**（`GB-layered`、`GBC-layered`）：由卡带提供映射器控制、存档和 RTC 等外设。ROM 文件和卡带必须是同一个游戏，映射器和存档布局要兼容，例如汉化或打过补丁的 ROM 配原版卡带。存档始终留在卡带上。
- **rumble**（`GB-rumble`、`GBC-rumble`）：存档在 SD 卡上，只把真正的 MBC5+RUMBLE 卡带当作震动马达（见下文）。

普通的纯 ROM 或纯卡带游玩，请使用原版核心。

### 安装

把 `Assets`、`Cores`、`Platforms` 三个文件夹合并到 SD 卡根目录。与原版核心并存时，不要替换已有的 `Assets` 或 `Platforms` 文件夹。

把 GBC BIOS 放到 `/Assets/gbc/common`，命名为 `gbc_bios.bin`；GB BIOS 放到 `/Assets/gb/common`，命名为 `gb_bios.bin`；SGB BIOS 放到 `/Assets/gb/common`，命名为 `sgb_boot.bin`。

### 使用

启动核心之前先插入对应的实体卡带，然后在文件浏览器里从 `/Assets/gbc/common` 或 `/Assets/gb/common` 选择修改过的 ROM。存档在实体卡带上读写，不应生成 SD 存档文件（layered 核心向 Pocket 报告没有存档）。如果想把存档放在 SD 卡上、只把卡带当震动马达用，请使用 rumble 核心。在对存档重要的卡带上使用 layered 核心之前，请先备份卡带存档。

### 启动安全检查

游戏开始之前，核心会（只读，不写卡带）读取卡带头，并显示卡带和 ROM 文件的标题、映射器类型、ROM 大小和 RAM 大小。在你继续之前，游戏保持复位，卡带的写信号线也不会被驱动。
- 第一页只有 `>CONTINUE`：卡带头一致时按一次 A 就能开始。这一页没有 CANCEL，按 Pocket 的菜单键退出核心。
- 卡带没有有效的任天堂 Logo 或头校验和时，显示 `NO VALID GB/GBC CARTRIDGE`，不能继续。
- 卡带和 ROM 文件的标题、卡带类型、RAM 大小应当一致。不一致时第一页用黄色显示 `HEADER FIELDS DIFFER`，按 A 进入 `ARE YOU SURE?` 页，有 CANCEL（默认）和 CONTINUE：用方向键选择，按 A 确认；按 B，或在 CANCEL 上按 A，可以返回。用错 ROM 可能会抹掉卡带存档。
- ROM 大小和各种校验和只显示、不触发警告，因为汉化或打过补丁的 ROM 通常会改变它们。ROM 大小不同时在屏幕上能看到，是否正常需要你自己判断。
- 选择 ROM 文件时按住的按键，松开之前会被忽略。

### 构建

Quartus Lite 18.1，器件 5CEBA4F23C8，工程为 `src/ap_core.qpf`。`src/core/core_top.sv` 开头的几行用来选择核心：`` `define isgbc ``（0 = GB，1 = GBC）和 `` `define isrumble ``（0 = layered，1 = rumble）。已打包的核心使用 `set_global_assignment -name SEED 2`，这一项没有保存在本仓库的 `ap_core.qsf` 里：布局布线对种子很敏感，换成别的种子时有些变体出现过小幅的负保持时间余量。发布用的比特流是 `output_files/ap_core.rbf`，把每个字节的位顺序反转后，以 `gb.rbf_r` / `gbc.rbf_r` 放进 `pkg/` 里对应的核心文件夹。`src/core/layered_startup_video.sv` 是生成出来的文字显示模块，生成器不在本仓库中。

### 状态

四个核心于 2026-10-31 在 Apple 芯片的 Mac 上用 Apple Container 加 Rosetta、Quartus Lite 18.1，以 `SEED 2` 编译。所有报告的时序余量都是正的，最小的是 +0.012 ns（GB-layered），所以换一个 Quartus 版本或种子不一定得到同样的结果。作者于 2026-11-01 在 Analogue Pocket 上测试，反馈基本可用，没有记录逐项功能的详细结果。休眠功能已禁用。在验证过卡带映射器和外设状态的恢复之前，请避免使用即时存档。MBC7 等特殊卡带需要另外验证。

### Rumble 核心（SD 存档）

`GB-rumble` 和 `GBC-rumble` 由同一份源码构建，只做一件事：从 SD 卡运行任意游戏，存档放在 SD 卡上，只把真正的 MBC5+RUMBLE 卡带（头类型 0x1C–0x1E）当作震动马达。layered 核心始终使用卡带存档，rumble 核心始终使用 SD 存档，没有切换开关。

在 rumble 核心里：

- 启动页只检查插入的卡带是不是 MBC5+RUMBLE。其他卡带会显示 `NEED MBC5 RUMBLE CARTRIDGE`，并禁止继续，所以 rumble 核心不可能写入别的卡带的存档。
- ROM、存档 RAM 和 RTC 都留在 SD 卡上（`Saves/<平台>/<核心>/<ROM 名>.sav`，大小按 ROM 自己的头计算）。
- 只有游戏对 MBC5 RAM bank 寄存器（0x4000–0x5FFF）的写入会发给卡带，其 bit 3 驱动马达。不会从卡带读取任何内容，卡带的 RAM 也从不被使能或写入。
- 标题、类型、RAM 不一致的警告不适用。

layered 核心向 Pocket 报告没有存档，所以不应生成 `.sav` 文件。
