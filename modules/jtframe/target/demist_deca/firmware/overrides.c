#include "config.h"
#include "interrupts.h"
#include "menu.h"
#include "user_io.h"
#include "spi.h"
#include "arcfile.h"
#include "configstring.h"

#define ARCADEKEYS_RINGBUFFER_SIZE 16

static char arckeys[]={0x16,0x1e,0x26,0x25,0x2e,0x36,0x3d,0x3e}; /* PS/2 codes for keys 1 through 8 */

extern int menu_buttons;

void sendarcadekeys()
{
	static unsigned int prev=0x000;
	unsigned int d=menu_buttons ^ prev;
	unsigned int s=prev;
	unsigned int i;
	DisableInterrupts();
	for(i=0;i<8;++i)
	{
		if(d&0x10)
		{
			EnableIO();
			SPI(UIO_KEYBOARD);
			if(s&0x10)
				SPI(0xf0); /* Key up event */
			SPI(arckeys[i]); /* Key code */
			DisableIO();
		}
		d>>=1;
		s>>=1;
	}
	EnableInterrupts();
	prev=menu_buttons;
}

char romname[12];
extern unsigned char romtype;
int LoadROM(const char *fn);

char *autoboot()
{
    char *result=0;
    DIRENTRY *de;
    romtype=CONFIGSTRING_INDEX_ARC;
    //LoadROM(ROM_FILENAME)

/* Fetch first 8 characters of core name */    
configstring_getcorename(romname,8);
/* Clear file extension */
strcpy(&romname[8],"   ");

//if(de=GetDirEntry(romname))
//    ChangeDirectory(de);

if(de=GetDirEntry("JOTEGO     "))
    ChangeDirectory(de);

/* Set file extension to .VHD */
//strcpy(&romname[8],"VHD");
//diskimg_mount(romname,0);

/* Set file extension to .ARC */
strcpy(&romname[8],"ARC");
if(!LoadROM(romname))
    result="ARC not found. Load ARC";

/* return to the root directory */
ChangeDirectoryByCluster(0);

    return(result);
}


void mainloop()
{
	while(1)
	{
		Menu_Run();
		sendarcadekeys();
		/* Read arcade buttons and send key events. */
	}
}


