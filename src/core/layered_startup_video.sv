// Fixed 160x144 startup display, independent of the held-in-reset GB CPU.
module layered_startup_video #(parameter RUMBLE_CORE = 0, parameter MOTION_CORE = 0) (
  input wire clk, reset,
  input wire ready, valid_cart, select_continue, fields_match, confirm, sd_available, sd_save,
  input wire [255:0] rom_header, cart_header,
  output reg [23:0] rgb,
  output wire de, hs, vs
);
  localparam SD_CORE = RUMBLE_CORE || MOTION_CORE;
  // The headers are only read while ready is set, when they cannot change
  // (they are written during ROM download and the cartridge probe, both of
  // which clear ready), so they are used directly across the asynchronous clock
  // groups instead of being copied into this domain.
  reg [6:0] status_meta = 0, status = 0;
  wire [255:0] rh = status[2] ? rom_header : 256'd0;
  wire [255:0] ch = status[2] ? cart_header : 256'd0;
  always @(posedge clk) begin
    status_meta <= {sd_save,sd_available,confirm,fields_match,ready,valid_cart,select_continue}; status <= status_meta;
  end
  reg [8:0] x = 0, y = 0;
  always @(posedge clk) begin
    if (reset) begin x <= 0; y <= 0; end
    else if (x == 424) begin
      x <= 0;
      if (y == 263) y <= 0; else y <= y + 1'b1;
    end else x <= x + 1'b1;
  end
  assign de = x >= 57 && x < 217 && y >= 105 && y < 249;
  assign hs = x == 0 && y != 0;
  assign vs = x == 0 && y == 0;
  wire [7:0] px = x - 57, py = y - 105;
  wire [4:0] row = py[7:3];
  // Character column and pixel within a 5+1 pixel glyph cell, counted instead of
  // dividing: text starts two pixels into the line, at x == 59.
  reg [4:0] column = 0;
  reg [2:0] glyph_x = 0;
  always @(posedge clk) begin
    if (x == 58) begin column <= 0; glyph_x <= 0; end
    else if (x >= 59 && x < 217) begin
      if (glyph_x == 5) begin glyph_x <= 0; column <= column + 1'b1; end
      else glyph_x <= glyph_x + 1'b1;
    end
  end
  wire rom_ok = MOTION_CORE ? rh[191:184] == 8'h22 : (rh[191:184] >= 8'h1C && rh[191:184] <= 8'h1E);
  wire match = status[3], confirming = status[4], sd_avail = status[5], sd_on = status[6];
  function automatic [7:0] hexchar(input [3:0] n);
    hexchar = n < 10 ? 8'd48+n : 8'd65+n-10;
  endfunction
  function automatic [47:0] mapper(input [7:0] n);
    case(n)
      0,8,9: mapper="ROM   ";
      1,2,3: mapper="MBC1  ";
      5,6: mapper="MBC2  ";
      15,16: mapper="MBC3+T";
      17,18,19: mapper="MBC3  ";
      25,26,27,28,29,30: mapper="MBC5  ";
      32: mapper="MBC6  ";
      34: mapper="MBC7  ";
      11,12,13: mapper="MMM01 ";
      252: mapper="CAMERA";
      253: mapper="TAMA5 ";
      254: mapper="HUC3  ";
      255: mapper="HUC1  ";
      default: mapper={"TYPE",hexchar(n[7:4]),hexchar(n[3:0])};
    endcase
  endfunction
  function automatic [31:0] romsize(input [7:0] n);
    case(n)
      0: romsize="32K "; 1: romsize="64K "; 2: romsize="128K";
      3: romsize="256K"; 4: romsize="512K"; 5: romsize="1M  ";
      6: romsize="2M  "; 7: romsize="4M  "; 8: romsize="8M  ";
      default: romsize="????";
    endcase
  endfunction
  function automatic [31:0] ramsize(input [7:0] n, input [7:0] kind);
    if (kind == 5 || kind == 6) ramsize="512B";
    else if (kind == 34) ramsize="256B";
    else case(n)
      0: ramsize="0   "; 1: ramsize="2K  "; 2: ramsize="8K  ";
      3: ramsize="32K "; 4: ramsize="128K"; 5: ramsize="64K ";
      default: ramsize="????";
    endcase
  endfunction
  function automatic [34:0] glyph(input [7:0] c);
    reg [7:0] upper;
    begin
      upper = (c >= "a" && c <= "z") ? c-8'd32 : c;
      case(upper)
        8'd32: glyph=35'h000000000;
        8'd65: glyph=35'h3a31fc631;
        8'd66: glyph=35'h7a31f463e;
        8'd67: glyph=35'h3e108420f;
        8'd68: glyph=35'h7a318c63e;
        8'd69: glyph=35'h7e10f421f;
        8'd70: glyph=35'h7e10f4210;
        8'd71: glyph=35'h3e10bc62f;
        8'd72: glyph=35'h4631fc631;
        8'd73: glyph=35'h38842108e;
        8'd74: glyph=35'h1c4210a4c;
        8'd75: glyph=35'h4654c5251;
        8'd76: glyph=35'h42108421f;
        8'd77: glyph=35'h4775ac631;
        8'd78: glyph=35'h4739ace71;
        8'd79: glyph=35'h3a318c62e;
        8'd80: glyph=35'h7a31f4210;
        8'd81: glyph=35'h3a318d64d;
        8'd82: glyph=35'h7a31f5251;
        8'd83: glyph=35'h3e107043e;
        8'd84: glyph=35'h7c8421084;
        8'd85: glyph=35'h46318c62e;
        8'd86: glyph=35'h46318c544;
        8'd87: glyph=35'h4631ad6aa;
        8'd88: glyph=35'h462a22a31;
        8'd89: glyph=35'h462a21084;
        8'd90: glyph=35'h7c222221f;
        8'd48: glyph=35'h3a33ae62e;
        8'd49: glyph=35'h11842108e;
        8'd50: glyph=35'h3a211111f;
        8'd51: glyph=35'h78217043e;
        8'd52: glyph=35'h08ca97c42;
        8'd53: glyph=35'h7e10f043e;
        8'd54: glyph=35'h3a10f462e;
        8'd55: glyph=35'h7c2222108;
        8'd56: glyph=35'h3a317462e;
        8'd57: glyph=35'h3a317842e;
        8'd58: glyph=35'h008401080;
        8'd46: glyph=35'h000000084;
        8'd47: glyph=35'h042222210;
        8'd45: glyph=35'h0000f8000;
        8'd43: glyph=35'h0084f9080;
        8'd62: glyph=35'h410411110;
        8'd63: glyph=35'h3a2111004;
        default: glyph=0;
      endcase
    end
  endfunction
  reg [207:0] text_line;
  reg [255:0] header;
  reg [7:0] character;
  reg [34:0] pixels;
  always @* begin
    text_line = "                          ";
    header = row < 7 ? ch : rh;
    case(row)
      3: text_line="CARTRIDGE                 ";
      7: text_line="ROM FILE                  ";
      0: text_line = RUMBLE_CORE ? "LAYERED - RUMBLE + SD SAVE" : MOTION_CORE ? "LAYERED - MOTION + SD SAVE" : "LAYERED - SAVE WARNING    ";
      1: text_line = !status[2] ? "READING CARTRIDGE...      " :
                     !status[1] ? "NO VALID GB/GBC CARTRIDGE " :
                     SD_CORE && !sd_avail ? (MOTION_CORE ? "NEED MBC7 SENSOR CARTRIDGE" : "NEED MBC5 RUMBLE CARTRIDGE") :
                     confirming ? "ARE YOU SURE?             " :
                     sd_on ? (MOTION_CORE ? "SD SAVE  CART SENSOR ONLY " : "SD SAVE  CART RUMBLE ONLY ") : match ? "TITLE / TYPE / RAM MATCH  " : "HEADER FIELDS DIFFER      ";
      5,9: text_line = {mapper(header[191:184])," ROM:",romsize(header[199:192])," RAM:",ramsize(header[207:200],header[191:184]),"  "};
      15: text_line = confirming ? " CANCEL       CONTINUE    " : status[1] && (!SD_CORE || sd_avail) ? "              CONTINUE    " : "                          ";
      16: text_line = confirming ? "ARROWS: SELECT  A: CONFIRM" : "A: CONTINUE               ";
      17: text_line = confirming ? "B: CANCEL  MENU: QUIT     " : "MENU: QUIT                ";
      11: text_line = SD_CORE && sd_avail ? "SAVE:  SD CARD ONLY       " : "                          ";
      12: text_line = sd_on ? "CARTRIDGE SAVE IS SAFE.   " : SD_CORE ? "                          " : confirming ? "WRONG ROM MAY ERASE SAVE. " : "GAME MAY OVERWRITE SAVE.  ";
      13: text_line = sd_on ? "SAVE FILE ON SD CARD.     " : SD_CORE ? "                          " : confirming ? "FILES DO NOT MATCH.       " : "BACK UP YOUR SAVE FIRST.  ";
      14: text_line = confirming ? "CONTINUE ANYWAY?          " :
                      sd_on && !rom_ok ? (MOTION_CORE ? "ROM TYPE IS NOT MBC7      " : "ROM TYPE HAS NO RUMBLE    ") :
                      sd_on && !MOTION_CORE && rh[207:200] == 0 ? "ROM HAS NO SAVE RAM       " : "                          ";
      default: ;
    endcase
    character = text_line[207-column*8 -: 8];
    if ((row == 4 || row == 8) && column < 16) begin
      character = header[(column+4)*8 +: 8];
      if (character < 32 || character > 126) character = " ";
    end
    if (row == 15 && status[1] && column == (confirming && !status[0] ? 0 : 13)) character = ">";
    pixels = glyph(character);
    rgb = 24'h101820;
    if (de && px >= 2 && px < 158 && glyph_x < 5 && py[2:0] < 7 && pixels[34-py[2:0]*5-glyph_x]) begin
      rgb = 24'he8edf2;
      if ((row == 0 || row == 12) && !sd_on && !SD_CORE || (row == 1 && status[1] && (SD_CORE ? !sd_avail : !match)) || (row == 14 && sd_on && !rom_ok) || (confirming && (row == 13 || row == 14))) rgb = 24'hffbc55;
      if (row == 15 || row == 11) rgb = 24'h65dbb0;
    end
    if (!de) rgb = 0;
  end
endmodule
