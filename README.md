# openfpga-GBC-layered for Analogue Pocket

This is TomJinW's layered fork of [budude2/openfpga-GBC](https://github.com/budude2/openfpga-GBC), which was ported from the [MiSTer Gameboy core](https://github.com/MiSTer-devel/Gameboy_MiSTer).

The packaged cores install as `budude2-TomJinW.GB-layered`, `budude2-TomJinW.GBC-layered`, `budude2-TomJinW.GB-rumble`, `budude2-TomJinW.GBC-rumble`, `budude2-TomJinW.GB-motion` and `budude2-TomJinW.GBC-motion`, so they can coexist with the original `budude2.GB` and `budude2.GBC` cores. They continue to use the shared `gb` and `gbc` platform asset directories.

This fork has three kinds of cores, all of which load the ROM file from the SD
card and use the inserted physical cartridge for something:

- **layered** (`GB-layered`, `GBC-layered`): the cartridge provides the mapper
  control, the save memory, and RTC or other cartridge peripherals. The ROM file
  and the cartridge must be the same game with a compatible mapper and save
  layout, for example a translated or patched ROM with the original cartridge.
  The save always stays on the cartridge.
- **rumble** (`GB-rumble`, `GBC-rumble`): the save is on the SD card and a
  genuine MBC5+RUMBLE cartridge is only used as the rumble motor (see below).
- **motion** (`GB-motion`, `GBC-motion`): the save is on the SD card and a
  genuine MBC7 cartridge is only used as the motion sensor (see below).

Use the original core for normal ROM-only or cartridge-only play.

## Installation
To install the core, merge the `Assets`, `Cores`, and `Platforms` folders into the root of your SD card. Do not replace the existing `Assets` or `Platforms` folders when installing alongside the original core.

Place the GBC bios in `/Assets/gbc/common` named "gbc_bios.bin", the GB bios in `/Assets/gb/common` named "gb_bios.bin", and the SGB bios in `/Assets/gb/common` named "sgb_boot.bin".


## Usage
Insert the matching physical cartridge before starting the core. Select the
patched ROM in the file browser from `/Assets/gbc/common` or
`/Assets/gb/common`. Save data is read and written on the physical cartridge
and no SD save file should be created (the layered cores report no save to the
Pocket). To keep the save on the SD card and use a cartridge only for rumble or
motion, use the rumble or motion cores (see below). Back up the cartridge save
before using a layered core with a cartridge whose save matters to you.

### Startup safety check

Before the game starts, the core reads the cartridge header (read-only, no
writes to the cartridge) and shows a confirmation screen with the cartridge's
and the ROM file's title, mapper type, ROM size and RAM size. The game stays in
reset, and the cartridge's write line is not driven, until you continue.
This describes the layered cores; the rumble and motion cores show the same
kind of screen but only check the cartridge type (see below).

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
1 = GBC), `` `define isrumble `` (1 = rumble) and `` `define ismotion `` (1 =
motion); both 0 is a layered core. Place and route is sensitive to the seed
(`set_global_assignment -name SEED n`, not stored in this repository's
`ap_core.qsf`): the motion cores were built with `SEED 3`, and the layered and
rumble cores were built from the `layered-and-rumble-cores` branch with
`SEED 2`. Building the layered or rumble cores from this branch gives a
different placement and not necessarily the same timing (GBC-rumble with
`SEED 2` had a small negative hold slack here). The release bitstream is
`output_files/ap_core.rbf` with the bits of every byte reversed (`gb.rbf_r` /
`gbc.rbf_r` in the core folder from `pkg/`). `src/core/layered_startup_video.sv`
is a generated text display; the generator is not part of this repository.

## Status

The six cores were compiled with Quartus Lite 18.1 on 2026-10-31 and 2026-11-01
using Apple Container and Rosetta on an Apple silicon Mac. All reported timing
slacks were positive; the smallest are +0.012 ns (GB-layered) and +0.102 ns
(GBC-motion), so a different Quartus version or seed may not give the same
result. The author tested all six on an Analogue Pocket on 2026-11-01 and
reports that they basically work; no detailed per-feature results were
recorded.
Sleep support is disabled. Avoid save states until restoring the cartridge's
mapper and peripheral state is validated.

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

## Motion variants (SD save, sensor from a cartridge)

`GB-motion` and `GBC-motion` run a game from the SD card with its save on the SD
card (the MBC7 EEPROM is emulated in the FPGA) and use a genuine MBC7 cartridge
(an MBC7 motion cartridge, header type 0x22) only as the motion sensor.

- The startup screen requires an MBC7 cartridge (`NEED MBC7 SENSOR CARTRIDGE`
  otherwise, and CONTINUE is disabled). A ROM that is not MBC7 is flagged with
  `ROM TYPE IS NOT MBC7`.
- Only these accesses reach the cartridge: the two RAM enable writes
  ($0000-$1FFF, $4000-$5FFF), the erase/latch writes to $A000 and $A010, and
  reads of the sensor registers $A020-$A05F. The EEPROM at $A080 and everything
  else stay in the FPGA, so the cartridge's own save is never read or written.
- The save is the raw 256-byte 93LC56 EEPROM (`<rom name>.sav`, 128 16-bit
  words, high byte first), with no RTC block, the same size emulators use.
  The byte order against emulator saves has not been compared yet.
- Basic hardware test by the author: works. The save format and the sensor
  response have not been checked in detail.

### Reading the sensor from a game

The sequence below is what an MBC7 game does (and what the cores expect):

1. Once at start-up: write `$0A` to `$0000` and `$40` to `$4000`, write `$55` to
   `$A000` (erase) and `$AA` to `$A010` (latch), then wait a few milliseconds.
2. Each time you want a sample: write `$0A` / `$40` again, read X from
   `$A020` (low) and `$A030` (high) and Y from `$A040` / `$A050`, and only
   then erase and latch the next sample with the same two writes. Reading
   straight after latching returns `$8000` ("nothing latched yet"). A level
   console reads about `$81D0` on both axes; only the low 12 bits count.
3. The EEPROM (93LC56, 16-bit words) is bit-banged through `$A080` (bit 7 chip
   select, bit 6 clock, bit 1 data in, bit 0 data out): a start bit, a 2-bit
   opcode and an 8-bit address, then 16 data bits, most significant first.
   Write enable (`00 11xxxxxx`) has to be sent in its own chip-select cycle
   before a write, and the clock must be brought low before the first data bit
   is read.

---

## 简体中文说明

这是 TomJinW 的“分层（layered）”分支，基于 [budude2/openfpga-GBC](https://github.com/budude2/openfpga-GBC)，后者移植自 [MiSTer Gameboy 核心](https://github.com/MiSTer-devel/Gameboy_MiSTer)。

打包后的核心安装为 `budude2-TomJinW.GB-layered`、`budude2-TomJinW.GBC-layered`、`budude2-TomJinW.GB-rumble`、`budude2-TomJinW.GBC-rumble`、`budude2-TomJinW.GB-motion`、`budude2-TomJinW.GBC-motion`，可以和原版的 `budude2.GB`、`budude2.GBC` 核心并存，仍然共用 `gb` 和 `gbc` 平台资源目录。

### 核心种类

所有核心都从 SD 卡加载 ROM 文件，并用插入的实体卡带做一件事：

- **layered**（`GB-layered`、`GBC-layered`）：由卡带提供映射器控制、存档和 RTC 等外设。ROM 文件和卡带必须是同一个游戏，映射器和存档布局要兼容，例如汉化或打过补丁的 ROM 配原版卡带。存档始终留在卡带上。
- **rumble**（`GB-rumble`、`GBC-rumble`）：存档在 SD 卡上，只把真正的 MBC5+RUMBLE 卡带当作震动马达（见下文）。
- **motion**（`GB-motion`、`GBC-motion`）：存档在 SD 卡上，只把真正的 MBC7 卡带当作体感传感器（见下文）。

普通的纯 ROM 或纯卡带游玩，请使用原版核心。

### 安装

把 `Assets`、`Cores`、`Platforms` 三个文件夹合并到 SD 卡根目录。与原版核心并存时，不要替换已有的 `Assets` 或 `Platforms` 文件夹。

把 GBC BIOS 放到 `/Assets/gbc/common`，命名为 `gbc_bios.bin`；GB BIOS 放到 `/Assets/gb/common`，命名为 `gb_bios.bin`；SGB BIOS 放到 `/Assets/gb/common`，命名为 `sgb_boot.bin`。

### 使用

启动核心之前先插入对应的实体卡带，然后在文件浏览器里从 `/Assets/gbc/common` 或 `/Assets/gb/common` 选择修改过的 ROM。存档在实体卡带上读写，不应生成 SD 存档文件（layered 核心向 Pocket 报告没有存档）。如果想把存档放在 SD 卡上、只把卡带当震动马达或体感传感器用，请使用 rumble 或 motion 核心。在对存档重要的卡带上使用 layered 核心之前，请先备份卡带存档。

### 启动安全检查

游戏开始之前，核心会（只读，不写卡带）读取卡带头，并显示卡带和 ROM 文件的标题、映射器类型、ROM 大小和 RAM 大小。在你继续之前，游戏保持复位，卡带的写信号线也不会被驱动。以下描述的是 layered 核心；rumble 和 motion 核心的界面类似，但只检查卡带类型（见下文）。

- 第一页只有 `>CONTINUE`：卡带头一致时按一次 A 就能开始。这一页没有 CANCEL，按 Pocket 的菜单键退出核心。
- 卡带没有有效的任天堂 Logo 或头校验和时，显示 `NO VALID GB/GBC CARTRIDGE`，不能继续。
- 卡带和 ROM 文件的标题、卡带类型、RAM 大小应当一致。不一致时第一页用黄色显示 `HEADER FIELDS DIFFER`，按 A 进入 `ARE YOU SURE?` 页，有 CANCEL（默认）和 CONTINUE：用方向键选择，按 A 确认；按 B，或在 CANCEL 上按 A，可以返回。用错 ROM 可能会抹掉卡带存档。
- ROM 大小和各种校验和只显示、不触发警告，因为汉化或打过补丁的 ROM 通常会改变它们。ROM 大小不同时在屏幕上能看到，是否正常需要你自己判断。
- 选择 ROM 文件时按住的按键，松开之前会被忽略。

### 构建

Quartus Lite 18.1，器件 5CEBA4F23C8，工程为 `src/ap_core.qpf`。`src/core/core_top.sv` 开头的几行用来选择核心：`` `define isgbc ``（0 = GB，1 = GBC）、`` `define isrumble ``（1 = rumble）和 `` `define ismotion ``（1 = motion），两者都为 0 就是 layered 核心。布局布线对种子很敏感（`set_global_assignment -name SEED n`，没有保存在本仓库的 `ap_core.qsf` 里）：motion 核心用 `SEED 3` 编译，layered 和 rumble 核心是在 `layered-and-rumble-cores` 分支上用 `SEED 2` 编译的。在本分支上编译 layered 或 rumble 核心，布局不同，时序不一定一样（这里用 `SEED 2` 编译 GBC-rumble 时出现过小幅的负保持时间余量）。发布用的比特流是 `output_files/ap_core.rbf`，把每个字节的位顺序反转后，以 `gb.rbf_r` / `gbc.rbf_r` 放进 `pkg/` 里对应的核心文件夹。`src/core/layered_startup_video.sv` 是生成出来的文字显示模块，生成器不在本仓库中。

### 状态

六个核心于 2026-10-31 和 2026-11-01 在 Apple 芯片的 Mac 上用 Apple Container 加 Rosetta、Quartus Lite 18.1 编译。所有报告的时序余量都是正的，最小的是 +0.012 ns（GB-layered）和 +0.102 ns（GBC-motion），所以换一个 Quartus 版本或种子不一定得到同样的结果。作者于 2026-11-01 在 Analogue Pocket 上测试了全部六个核心，反馈基本可用，没有记录逐项功能的详细结果。休眠功能已禁用。在验证过卡带映射器和外设状态的恢复之前，请避免使用即时存档。

### Rumble 核心（SD 存档）

`GB-rumble` 和 `GBC-rumble` 由同一份源码构建，只做一件事：从 SD 卡运行任意游戏，存档放在 SD 卡上，只把真正的 MBC5+RUMBLE 卡带（头类型 0x1C–0x1E）当作震动马达。layered 核心始终使用卡带存档，rumble 核心始终使用 SD 存档，没有切换开关。

在 rumble 核心里：

- 启动页只检查插入的卡带是不是 MBC5+RUMBLE。其他卡带会显示 `NEED MBC5 RUMBLE CARTRIDGE`，并禁止继续，所以 rumble 核心不可能写入别的卡带的存档。
- ROM、存档 RAM 和 RTC 都留在 SD 卡上（`Saves/<平台>/<核心>/<ROM 名>.sav`，大小按 ROM 自己的头计算）。
- 只有游戏对 MBC5 RAM bank 寄存器（0x4000–0x5FFF）的写入会发给卡带，其 bit 3 驱动马达。不会从卡带读取任何内容，卡带的 RAM 也从不被使能或写入。
- 标题、类型、RAM 不一致的警告不适用。

layered 核心向 Pocket 报告没有存档，所以不应生成 `.sav` 文件。

### Motion 核心（SD 存档，传感器来自卡带）

`GB-motion` 和 `GBC-motion` 从 SD 卡运行游戏，存档也在 SD 卡上（MBC7 的 EEPROM 由 FPGA 模拟），只把真正的 MBC7 卡带（头类型 0x22）当作体感传感器。

- 启动页要求插入的是 MBC7 卡带，否则显示 `NEED MBC7 SENSOR CARTRIDGE` 并禁止继续。ROM 不是 MBC7 时会提示 `ROM TYPE IS NOT MBC7`。
- 只有以下访问会到达卡带：两个 RAM 使能写入（$0000–$1FFF、$4000–$5FFF）、对 $A000 和 $A010 的擦除与锁存写入，以及对传感器寄存器 $A020–$A05F 的读取。$A080 处的 EEPROM 和其余一切都留在 FPGA 内，所以卡带自己的存档从不被读写。
- 存档是原始的 256 字节 93LC56 EEPROM（`<ROM 名>.sav`，128 个 16 位字，高字节在前），没有 RTC 块，大小和模拟器一致。字节顺序与模拟器存档是否一致还没有比较过。
- 作者做过基本的真机测试，可用。存档格式和传感器响应还没有详细检查。

#### 在游戏里读取传感器

下面是 MBC7 游戏的读取顺序，也是这些核心所期望的：

1. 启动时执行一次：往 `$0000` 写 `$0A`，往 `$4000` 写 `$40`，往 `$A000` 写 `$55`（擦除），往 `$A010` 写 `$AA`（锁存），然后等待几毫秒。
2. 每次需要采样时：再次写 `$0A` / `$40`，从 `$A020`（低字节）和 `$A030`（高字节）读 X，从 `$A040` / `$A050` 读 Y，**然后**才用同样的两次写入擦除并锁存下一次采样。锁存后立刻读取会得到 `$8000`（表示“还没有锁存”）。水平放置时两个轴都大约读到 `$81D0`，只有低 12 位有意义。
3. EEPROM（93LC56，16 位字）通过 `$A080` 逐位操作（bit 7 片选，bit 6 时钟，bit 1 数据输入，bit 0 数据输出）：一个起始位、2 位操作码、8 位地址，然后是 16 个数据位，高位在前。写之前要先在单独的一次片选周期里发送写使能命令（`00 11xxxxxx`），读数据之前必须先把时钟拉低。
