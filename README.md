# openfpga-GBC-layered for Analogue Pocket

This is TomJinW's layered fork of [budude2/openfpga-GBC](https://github.com/budude2/openfpga-GBC), which was ported from the [MiSTer Gameboy core](https://github.com/MiSTer-devel/Gameboy_MiSTer).

The packaged cores install as `budude2-TomJinW.GB-layered`, `budude2-TomJinW.GBC-layered`, `budude2-TomJinW.GB-rumble` and `budude2-TomJinW.GBC-rumble`, so they can coexist with the original `budude2.GB` and `budude2.GBC` cores. They continue to use the shared `gb` and `gbc` platform asset directories.

This fork is intended only for a layered setup: load a ROM file from SD while
using the inserted physical cartridge for its mapper control, save memory, and
RTC or other cartridge peripherals. The ROM file and cartridge must be the same
game with a compatible mapper and save layout. Use the original core for normal
ROM-only or cartridge-only play.

## Installation
To install the core, merge the `Assets`, `Cores`, and `Platforms` folders into the root of your SD card. Do not replace the existing `Assets` or `Platforms` folders when installing alongside the original core.

Place the GBC bios in `/Assets/gbc/common` named "gbc_bios.bin", the GB bios in `/Assets/gb/common` named "gb_bios.bin", and the SGB bios in `/Assets/gb/common` named "sgb_boot.bin".


## Usage
Insert the matching physical cartridge before starting the core. Select the
patched ROM in the file browser from `/Assets/gbc/common` or
`/Assets/gb/common`. Save data is read and written on the physical cartridge
and no SD save file is created. To use a rumble cartridge only as a motor with
an SD save, use the rumble cores (see below). Back up the cartridge save before
testing on hardware.

### Startup safety check

Before the game starts, the core reads the cartridge header (read-only, no
writes to the cartridge) and shows a confirmation screen with the cartridge's
and the ROM file's title, mapper type, ROM size and RAM size. The game stays in
reset, and the cartridge's write line is not driven, until you confirm.

- The screen defaults to CANCEL. Select CONTINUE with the D-pad and press A.
  B cancels, and the Pocket menu button quits the core.
- If the cartridge has no valid Nintendo logo or header checksum, CONTINUE is
  disabled.
- The title, cartridge type and RAM size must match between the cartridge and
  the ROM file. If they differ, the screen shows `HEADER FIELDS DIFFER` and
  asks "ARE YOU SURE?" with a second confirmation, because the wrong ROM can
  erase the cartridge save.
- ROM size and the header/global checksums are shown or ignored but do not
  trigger the warning, since translated or patched ROMs commonly change them.
  A different ROM size is visible on the screen, but it is up to you to judge
  whether it is expected.
- A button held while picking the ROM file is ignored until released.

## Status

The GB and GBC variants were successfully compiled with Quartus Lite 18.1 on 2026-10-31
using Apple Container and Rosetta on an Apple silicon Mac. All reported timing
summary slacks were positive. Neither variant has been validated on an Analogue Pocket.
Sleep support is disabled. Avoid save states
until restoring the cartridge's mapper and peripheral state is validated.
MBC7 and other special cartridges need separate hardware validation.

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

The layered cores report no save to the Pocket, so they create no `.sav` file.
(Not yet confirmed on hardware.)
