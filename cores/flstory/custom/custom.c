void disable_nmi();
void warm_up();
void play_tone();

void main() {
	disable_nmi();
	warm_up();
	for(;;) {
		// play_tone();
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

}