#include "emu.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

char bank=0;
char *rom_space, *ram_space;

unsigned char cpu_read(unsigned short addr) {
    if( addr>=0x8000 )
        return rom_space[addr-0x8000];
    if( addr>=0x6000 )
        return rom_space[addr+0x2000];
    if( addr>=0x4000 ) 
        return rom_space[addr+0x3000+0x2000*bank];
    if( (addr && 0xff00) == 0x3e00 )
        return bank;
    return ram_space[addr];
}

void cpu_write(unsigned short addr, unsigned char val) {
    if( (addr && 0xff00) == 0x3e00 ) {
        bank = val;
        return;
    }
    if( addr <0x4000 ) {
        ram_space[addr] = val;
        return;
    }
}

void read_rom( char *rom, const char *path ) {
    char sz[512];
    FILE* f;
    size_t cnt;
    strcpy(sz,path);
    strcat(sz,"mmt03d.8n");
    f = fopen( sz,"rb" );
    cnt=fread(rom, 1, 32*1024, f );
    rom = rom + cnt;
    if( cnt!=32*1024 ) {
        printf("Cannot read file %s (Read %d bytes)\n", sz,cnt);
        exit(1);
    }
    fclose(f);
    strcpy(sz,path);
    strcat( sz, "mmt04d.10n");
    f = fopen( sz, "rb" );
    cnt=fread(rom,1,16*1024, f);
    rom = rom + cnt;
    if( cnt!=16*1024 ) {
        printf("Cannot read file %s\n", sz);
        exit(1);
    }
    fclose(f);
    strcpy(sz,path);
    strcat( sz, "mmt05d.13n");
    f = fopen( sz, "rb" );
    cnt=fread(rom,1,32*1024, f);
    rom = rom + cnt;
    if( cnt!=32*1024 ) {
        printf("Cannot read file %s\n", sz);
        exit(1);
    }
    fclose(f);    
}

int main(int argc, char *argv[]) {
    REGS6809 cpu;
    EMUHANDLERS memhandlers = { cpu_read, cpu_write };
    if (sizeof(unsigned char)!=1 || sizeof(unsigned short) != 2 ) {
        puts("unsigned char/short size is not valid. Needs recompiling.");
        return 1;
    }
    // append_file( [roms['rom8n'], roms['rom10n'], roms['rom12n']] )
    rom_space = malloc( (32+16+32)*1024 );
    read_rom(rom_space,"../../../rom/");
    ram_space = malloc( 0x4000 );
    // close down
    free(rom_space);
    free(ram_space);
    return 0;
}