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
