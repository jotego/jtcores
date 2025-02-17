void sega_outrun_sprite_device::draw(bitmap_ind16 &bitmap, const rectangle &cliprect)
{
    //
    //  Out Run/X-Board-style sprites
    //
    //      Offs  Bits               Usage
    //       +0   e------- --------  Signify end of sprite list
    //       +0   -h-h---- --------  Hide this sprite if either bit is set
    //       +0   ----bbb- --------  Sprite bank
    //       +0   -------t tttttttt  Top scanline of sprite + 256
    //       +1   oooooooo oooooooo  Offset within selected sprite bank
    //       +2   ppppppp- --------  Signed 7-bit pitch value between scanlines
    //       +2   -------x xxxxxxxx  X position of sprite (position $BE is screen position 0)
    //       +3   -s------ --------  Enable shadows
    //       +3   --pp---- --------  Sprite priority, relative to tilemaps
    //       +3   ------vv vvvvvvvv  Vertical zoom factor (0x200 = full size, 0x100 = half size, 0x300 = 2x size)
    //       +4   y------- --------  Render from top-to-bottom (1) or bottom-to-top (0) on screen
    //       +4   -f------ --------  Horizontal flip: read the data backwards if set
    //       +4   --x----- --------  Render from left-to-right (1) or right-to-left (0) on screen
    //       +4   ------hh hhhhhhhh  Horizontal zoom factor (0x200 = full size, 0x100 = half size, 0x300 = 2x size)
    //       +7   dddddddd dddddddd  Scratch space for current address
    //
    //  Out Run only:
    //       +5   hhhhhhhh --------  Height in scanlines - 1
    //       +5   -------- -ccccccc  Sprite color palette
    //
    //  X-Board only:
    //       +A   ----hhhh hhhhhhhh  Height in scanlines - 1
    //       +C   -------- cccccccc  Sprite color palette
    //
    //  Final bitmap format:
    //
    //            -s------ --------  Shadow control
    //            --pp---- --------  Sprite priority
    //            ----cccc cccc----  Sprite color palette
    //            -------- ----llll  4-bit pixel data
    //

    set_origin(m_xoffs, m_yoffs);

    // render the sprites in order
    const uint32_t *spritebase = &m_sprite_region_ptr[0];
    uint8_t numbanks = m_sprite_region_ptr.bytes() / 0x40000;
    uint16_t *ramend = buffer() + spriteram_elements();

    // Save obj buffer
    std::ofstream flog("/home/jtejada/git/jts16/cores/outrun/ver/game/obj.bin",std::ios_base::binary);
    flog.write( (char*)buffer(), (int)(ramend-buffer()) );
    flog.close();

    for (uint16_t *data = buffer(); data < ramend; data += 8)
    {
        // stop when we hit the end of sprite list
        if (data[0] & 0x8000)
            break;

        // extract parameters
        int hide    = (data[0] & 0x5000);
        int bank    = (data[0] >> 9) & 7;
        int top     = (data[0] & 0x1ff) - 0x100;
        uint16_t addr = data[1];
        int pitch   = int16_t((data[2] >> 1) | ((data[4] & 0x1000) << 3)) >> 8;
        int xpos    = data[2] & 0x1ff;
        int vzoom   = data[3] & 0x7ff;
        int ydelta  = (data[4] & 0x8000) ? 1 : -1;
        int flip    = (~data[4] >> 14) & 1;
        int xdelta  = (data[4] & 0x2000) ? 1 : -1;
        int hzoom   = data[4] & 0x7ff;
        int height  = (m_is_xboard ? (data[5] & 0xfff) : (data[5] >> 8)) + 1;
        int colpri  = ((m_is_xboard ? (data[6] & 0xff) : (data[5] & 0x7f)) << 4) | (((data[3] >> 12) & 7) << 12);

        // adjust X coordinate
        // note: the threshhold below is a guess. If it is too high, rachero will draw garbage
        // If it is too low, smgp won't draw the bottom part of the road
        if (xpos < 0x80 && xdelta < 0)
            xpos += 0x200;

        // initialize the end address to the start address
        data[7] = addr;

        // if hidden, punt
        if (hide)
            continue;

        // clamp to within the memory region size
        if (numbanks)
            bank %= numbanks;
        const uint32_t *spritedata = spritebase + 0x10000 * bank;

        // clamp to a maximum of 8x (not 100% confirmed)
        if (vzoom < 0x40) vzoom = 0x40;
        if (hzoom < 0x40) hzoom = 0x40;

        // loop from top to bottom
        int minx = xpos;
        int maxx = xpos;
        int miny = cliprect.max_y + 1;
        int maxy = cliprect.min_y - 1;
        int yacc = 0;
        int ytarget = top + ydelta * height;

        for (int y = top; y != ytarget; y += ydelta)
        {
            // skip drawing if not within the cliprect
            if (y >= cliprect.min_y && y <= cliprect.max_y)
            {
                uint16_t *dest = &bitmap.pix(y);
                int xacc = 0;
                int x;

                data[7] = addr;
                for (x = xpos; (xdelta > 0 && x <= cliprect.max_x) || (xdelta < 0 && x >= cliprect.min_x); )
                {
                    uint32_t pixels = spritedata[data[7]];
                    if( flip ) {
                        data[7]--;
                    } else {
                        data[7]++;
                        pixels =
                            (( pixels << 28) & 0xf0000000) |
                            (( pixels << 20) & 0x0f000000) |
                            (( pixels << 12) & 0x00f00000) |
                            (( pixels <<  4) & 0x000f0000) |
                            (( pixels >>  4) & 0x0000f000) |
                            (( pixels >> 12) & 0x00000f00) |
                            (( pixels >> 20) & 0x000000f0) |
                            (( pixels >> 28) & 0x0000000f);
                    }
                    bool last_data = (pixels & 0x0f00'0000) == 0x0f00'0000;

                    // draw eight pixels
                    for( int k=0; k<8; k++ ) {
                        int pix = pixels & 0xf;
                        while (xacc < 0x200) {
                            if (x >= cliprect.min_x && x <= cliprect.max_x && pix != 0 && pix != 15)
                                dest[x] = colpri | pix;
                            x += xdelta;
                            xacc += hzoom;
                        }
                        xacc -= 0x200;
                        pixels>>=4;
                    }

                    // stop if the second-to-last pixel in the group was 0xf
                    if (last_data)
                        break;
                }

                // update bounds
                if (x > maxx) maxx = x;
                if (x < minx) minx = x;
                if (y < miny) miny = y;
                if (y > maxy) maxy = y;
            }

            // accumulate zoom factors; if we carry into the high bit, skip an extra row
            yacc += vzoom;
            addr += pitch * (yacc >> 9);
            yacc &= 0x1ff;
        }

        // mark dirty
        if (minx <= maxx && miny <= maxy)
            mark_dirty(minx, maxx, miny, maxy);
    }
}