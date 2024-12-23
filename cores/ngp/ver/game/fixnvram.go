package main

// Fixes the NVRAM file so it bypasses the setup menu
// This is mostly code converted from a C file of the HIGAN emulator

import(
	"fmt"
	"os"
)

func main() {
	ram, e := os.ReadFile("nvram.bin")
	if e != nil {
		fmt.Println(e)
		os.Exit(1)
	}
	var data uint16
	data += uint16(ram[0x2f87])
    for address:=0x2c25; address <= 0x2c2b; address++ {
    	data += uint16(ram[address])   //always 0x00dc
    }
    // if(Model::NeoGeoPocketColor()) {
    //   data += ram[0x2f94];  //K1GE color mode: Black & White, Blue, Green, Red, Classic
    // }
    ram[0x2c14] = byte(data&0xff)
    ram[0x2c15] = byte(data>>1)

    //signature check
    ram[0x2e96] = byte('N')   //'N'eo Geo
    ram[0x2e95] = byte('P')   //'P'ocket

    //this byte seems to indicate system state (0x00 = BIOS UI, 0x10 = setup, 0x40 = game playing)
    //for unknown reasons, sometimes d4 gets set, which re-enters the BIOS setup again.
    ram[0x2f83] = ram[0x2f83] & 0xef //.bit(4) = 0;

    //this setting gets erased sometimes for unknown reasons, preventing games from booting.
    ram[0x2f91] = /*Model::NeoGeoPocketColor() ? 0x10 :*/ 0x00
    ram[0x2f95] = ram[0x2f91]
    e = os.WriteFile("nvram.bin", ram, 0666 )
	if e != nil {
		fmt.Println(e)
		os.Exit(1)
	}
}