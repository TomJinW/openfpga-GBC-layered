// Read-only cartridge probe and explicit consent before any game bus access.
// RUMBLE_CORE = 0: the cartridge save is always used.
// RUMBLE_CORE = 1: the save is always on the SD card and the cartridge, which
// must be MBC5+RUMBLE, is only a rumble source.
module layered_startup #(parameter RUMBLE_CORE = 0) (
  input wire clk, reset, rom_download, ioctl_wr,
  input wire [24:0] ioctl_addr,
  input wire [15:0] ioctl_data,
  input wire [31:0] keys,
  input wire [7:0] cart_data,
  output wire [15:0] probe_addr,
  output wire probe_read,
  output wire probe_wr,      // /WR low request for the one rumble-off write
  output wire probe_wdrive,  // drive the data bus (with zero) for that write
  output reg accepted = 0,
  output wire ready,
  output reg valid_cart = 0,
  output reg select_continue = 0,
  output wire fields_match,
  output reg confirm = 0,
  output wire sd_available,
  output wire sd_save,
  output reg [255:0] rom_header = 0,
  output reg [255:0] cart_header = 0
);
  // Header bytes 0130..014F, byte 0130 in the least significant byte.
  localparam [383:0] LOGO = 384'hCEED6666CC0D000B03730083000C000D0008111F8889000EDCCC6EE6DDDDD999BBBB67636E0EECCCDDDC999FBBB9333E;
  reg download_prev = 0, loaded = 0, done = 0;
  reg [31:0] keys_prev = 0;
  reg armed = 0;
  reg [6:0] index = 0;
  reg cleared = 0;
  reg [5:0] wr_phase = 0;
  reg [5:0] phase = 0;
  reg logo_ok = 1;
  reg [7:0] checksum = 0;
  wire [31:0] pressed = keys & ~keys_prev;
  // Title/CGB flag (0134..0143), cartridge type (0147) and RAM size (0149).
  // ROM size and checksums are not compared: a translated ROM may differ in both.
  wire header_match = rom_header[159:32] == cart_header[159:32] &&
                      rom_header[191:184] == cart_header[191:184] &&
                      rom_header[207:200] == cart_header[207:200];
  // Only an MBC5+RUMBLE cartridge (0x1C..0x1E) may be used as a rumble source
  // with the ROM's save kept on the SD card. Then the cartridge's memory is never
  // touched.
  assign sd_available = RUMBLE_CORE && ready && valid_cart && cart_header[191:184] >= 8'h1C && cart_header[191:184] <= 8'h1E;
  assign sd_save = sd_available;
  // With an SD save the cartridge is not the ROM's game, so a mismatch is expected.
  assign fields_match = sd_save || header_match;
  wire probing = loaded && !done && !rom_download && !reset;
  // Some third-party flash cartridges come up with the rumble bit (bit 3 of the
  // MBC5 RAM bank register) set once they are read, which keeps the motor on
  // until the game writes the register. For a cartridge whose header says MBC5
  // RUMBLE (0x1C..0x1E), write 0 to $4000 once after the header was read. That
  // only selects RAM bank 0 and turns the motor off; no save memory is touched.
  wire rumble_cart = valid_cart && cart_header[191:184] >= 8'h1C && cart_header[191:184] <= 8'h1E;
  wire clear_active = ready && !accepted && !cleared && rumble_cart;
  assign probe_addr = clear_active ? 16'h4000 : 16'h0100 + index;
  assign probe_wr = clear_active && wr_phase >= 8 && wr_phase < 40;
  assign probe_wdrive = clear_active && wr_phase >= 4 && wr_phase < 44;
  // At 33.55 MHz: address setup 238 ns, read pulse 954 ns,
  // sample after 924 ns of /RD, then 477 ns between read pulses.
  assign probe_read = probing && phase >= 8 && phase < 40;
  assign ready = loaded && done;

  always @(posedge clk) begin
    download_prev <= rom_download;
    keys_prev <= keys;
    if (rom_download && ioctl_wr && ioctl_addr >= 25'h130 && ioctl_addr < 25'h150) begin
      rom_header[(ioctl_addr-25'h130)*8 +: 16] <= ioctl_data;
    end
    if (rom_download && !download_prev) begin
      rom_header <= 0;
    end
    if (download_prev && !rom_download) loaded <= 1;
    if (rom_download) loaded <= 0;

    if (reset || rom_download || (download_prev && !rom_download)) begin
      accepted <= 0;
      done <= 0;
      valid_cart <= 0;
      select_continue <= 0;
      confirm <= 0;
      armed <= 0;
      index <= 0;
      phase <= 0;
      logo_ok <= 1;
      checksum <= 0;
      cart_header <= 0;
      cleared <= 0;
      wr_phase <= 0;
    end else if (probing) begin
      phase <= phase + 1'b1;
      if (phase == 39) begin
        if (index >= 4 && index < 52)
          logo_ok <= logo_ok && (cart_data == LOGO[(51-index)*8 +: 8]);
        if (index >= 48) cart_header[(index-48)*8 +: 8] <= cart_data;
        if (index >= 52 && index <= 76) checksum <= checksum - cart_data - 8'd1;
        if (index == 77) valid_cart <= logo_ok && (checksum == cart_data);
      end
      if (phase == 55) begin
        phase <= 0;
        if (index == 79) done <= 1;
        else index <= index + 1'b1;
      end
    end else if (ready && !accepted) begin
      if (clear_active) begin
        wr_phase <= wr_phase + 1'b1;
        if (wr_phase == 47) begin
          cleared <= 1;
          wr_phase <= 0;
        end
      end
      // Do not accept a button held through the ROM file browser.
      if (!(|keys[5:0])) armed <= 1;
      if (armed) begin
        // First page: A continues. A header mismatch opens a second page with
        // CANCEL (default) and CONTINUE, which needs its own confirmation.
        if (pressed[4] && valid_cart && (!RUMBLE_CORE || sd_available) && (!confirm || select_continue)) begin
          if (fields_match || confirm) accepted <= 1;
          else begin
            confirm <= 1;
            select_continue <= 0;
          end
        end else if (confirm && (pressed[4] || pressed[5])) begin
          select_continue <= 0;
          confirm <= 0;
        end
        else if (confirm && valid_cart && |pressed[3:0]) select_continue <= ~select_continue;
      end
    end
  end
endmodule
