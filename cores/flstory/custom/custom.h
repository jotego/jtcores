// only declarations so they are out of the way when
// visually inspecting custom.c
void disable_nmi();
void warm_up();

void play_tone();
void set_ch_period(int ch, int period);
void write_reg(char reg, char value);
void set_mixer();
void set_volume();