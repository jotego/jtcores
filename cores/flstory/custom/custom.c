#include "custom.h"

#define CHA 0
#define CHB 1
#define CHC 2
#define YM_ADDR ((char *)0xC800)
#define YM_DATA ((char *)0xC801)

void main() {
	disable_nmi();
	warm_up();
	for(;;) {
		play_tone();
	}
}

void disable_nmi() {
	char *NMIDIS=(char *)0xDC00;
	*NMIDIS=1;
}

void warm_up() {
	int k=0;
	for(k=1;k!=0;k++);
}

void play_tone() {
	set_ch_period(CHA, 0x100);
	set_mixer();
	set_volume();
}

void set_ch_period(int ch, int period) {
	int reg=ch<<1;
	char lobyte = (char)period;
	char hibyte = (char)(period>>8);
	write_reg(reg,   lobyte);
	write_reg(reg+1, hibyte);
}

void write_reg(char reg, char value) {
	*YM_ADDR = reg;
	*YM_DATA = value;
}

void set_mixer() {
	const char mixer_reg = 7;
	const char only_cha = 0xfe;
	write_reg(mixer_reg,only_cha);
}

void set_volume() {
	const char volA_reg = 10;
	const char fixed_loud = 0xf;
	write_reg(volA_reg,fixed_loud);
}