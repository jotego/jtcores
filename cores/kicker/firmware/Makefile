kicker.zip: kicker/477l05.d11
	rm -f kicker.zip
	zip -j kicker.zip kicker/*
	cp kicker/477l05.d11 /nobackup/477l05.d11
	cat kicker/477l05.d11 >> /nobackup/477l05.d11
	sshpass -p 1 scp -o "ConnectTimeout 1" kicker.zip root@MiSTer.home:/media/fat/games/mame

kicker/477l05.d11: kicker.s
	vasm6809 kicker.s -o kicker/477l05.d11 -L kicker.lst -Fbin
	cp kicker/477l05.d11 kicker/477-l05.d11

clean:
	rm -f kicker.zip kicker/477l05.d11
	sshpass -p 1 scp -o "ConnectTimeout 1" /opt/mame/kicker.zip root@MiSTer.home:/media/fat/games/mame
