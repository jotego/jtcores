/* SPDX-License-Identifier: GPL-3.0-or-later */
#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>

enum { INFO, CAPACITY, COUNT, STATUS, SEED, LIMIT, ARM, STOP, READ, PERIOD,
       CAPTURE_ID, GET_SEED, GET_LIMIT, GET_PERIOD, MODE, GET_MODE,
       INVERT, GET_INVERT, FORMAT, GET_FORMAT, PINS, ERRORS, FRAME_CLOCKS };
static volatile uint32_t *regs;
static uint32_t toggle;
static uint32_t protocol;

static void die(const char *s) { fprintf(stderr,"%s\n",s); exit(1); }
static double now(void) {
    struct timespec t;
    if (clock_gettime(CLOCK_MONOTONIC,&t)) die("clock_gettime failed");
    return t.tv_sec+t.tv_nsec*1e-9;
}
static void pause_ms(unsigned ms) {
    struct timespec t={ms/1000,(long)(ms%1000)*1000000};
    while (nanosleep(&t,&t) && errno==EINTR) {}
}
static uint32_t number(const char *s, uint32_t max) {
    char *end;
    errno=0;
    unsigned long v=strtoul(s,&end,0);
    if (errno || !*s || *s=='-' || *end || v>max) die("Invalid numeric argument");
    return (uint32_t)v;
}
static uint32_t command(unsigned op, uint32_t arg) {
    double deadline=now()+1.0;
    unsigned polls=0;
    uint32_t v;
    toggle^=0x80000000u;
    __sync_synchronize();
    regs[4]=toggle|((uint32_t)op<<24)|arg;
    __sync_synchronize();
    for (;;) {
        v=regs[5];
        if ((v&0x80000000u)==toggle) {
            __sync_synchronize();
            if (regs[5]==v) break;
        }
        if ((++polls&255)==0 && now()>deadline) die("FPGA command timeout");
    }
    if (((v>>24)&63)!=op) die("FPGA reply opcode mismatch");
    if (v&0x40000000u) {
        fprintf(stderr,"FPGA rejected command %u: error %u\n",op,v&0xffffff);
        exit(1);
    }
    return v&0xffffff;
}
static void connect_fpga(void) {
    char model[64]={0}, state[32]={0};
    FILE *f=fopen("/proc/device-tree/model","rb");
    if (!f || !fgets(model,sizeof(model),f)) die("Cannot identify board");
    fclose(f);
    if (strcmp(model,"NovTech CV96")) die("This tool requires the NovTech CV96");
    f=fopen("/sys/class/fpga_manager/fpga0/state","r");
    if (!f || !fgets(state,sizeof(state),f)) die("Cannot read FPGA state");
    fclose(f);
    if (strcmp(state,"operating\n")) die("FPGA is not operating");
    int lock=open("/var/lock/c96-capture.lock",O_CREAT|O_RDWR,0600);
    if (lock<0 || flock(lock,LOCK_EX|LOCK_NB)) die("Another capture command is running");
    int fd=open("/dev/mem",O_RDWR|O_SYNC);
    if (fd<0) die("Cannot open /dev/mem (root required)");
    regs=mmap(NULL,4096,PROT_READ|PROT_WRITE,MAP_SHARED,fd,0xff706000);
    if (regs==MAP_FAILED) die("Cannot map FPGA manager registers");
    close(fd);
    // Start from the last completed toggle, including after a prior process exits.
    toggle=regs[5]&0x80000000u;
    protocol=command(INFO,0);
    if (protocol<0x960101 || protocol>0x960104) die("Unexpected FPGA protocol identity");
}
static void arm_capture(char **args) {
    uint32_t seed=number(args[0],65535), count=number(args[1],32768);
    uint32_t period=number(args[2],0xffffff), id=number(args[3],0xffffff);
    if (!seed || !count || !period) die("Seed, count and period must be nonzero");
    if (command(STATUS,0)&1) die("Capture is already running");
    command(SEED,seed); command(LIMIT,count); command(PERIOD,period);
    command(ARM,id);
    if (command(GET_SEED,0)!=seed || command(GET_LIMIT,0)!=count ||
        command(GET_PERIOD,0)!=period || command(CAPTURE_ID,0)!=id)
        die("FPGA did not retain the requested capture configuration");
}
static void put32(unsigned char *p,uint32_t v) {
    for (int i=0;i<4;i++) p[i]=(unsigned char)(v>>(8*i));
}
static void export_capture(const char *path) {
    uint32_t status=command(STATUS,0), count=command(COUNT,0);
    uint32_t seed=command(GET_SEED,0), limit=command(GET_LIMIT,0);
    uint32_t period=command(GET_PERIOD,0), id=command(CAPTURE_ID,0);
    if ((status&1) || !(status&2) || count>32768 || count>limit)
        die("Capture must be complete or stopped before export");
    unsigned char header[80]={0};
    uint32_t mode=protocol!=0x960101 ? command(GET_MODE,0) : 0;
    uint32_t invert=protocol!=0x960101 ? command(GET_INVERT,0) : 0;
    uint32_t format=protocol!=0x960101 ? command(GET_FORMAT,0) : 0;
    uint32_t errors=protocol!=0x960101 ? command(ERRORS,0) : 0;
    uint32_t frame_clocks=mode==3 ? command(FRAME_CLOCKS,0) : 0;
    uint32_t header_size=protocol!=0x960101 ? 80 : 64;
    uint32_t version=mode==3 ? (protocol==0x960104 ? 4 : 3) : protocol!=0x960101 ? 2 : 1;
    uint32_t fields[]={header_size,version,seed,count,limit,
        period,100000000,id,status,16,count*2,mode,invert,format,errors,frame_clocks,0,0};
    memcpy(header,version==4 ? "C96CAP04" : version==3 ? "C96CAP03" : version==2 ? "C96CAP02" : "C96CAP01",8);
    for (unsigned i=0;i<(header_size-8)/4;i++) put32(header+8+4*i,fields[i]);
    // Exclusive creation prevents overwriting an earlier capture.
    int fd=open(path,O_WRONLY|O_CREAT|O_EXCL,0600);
    if (fd<0) die("Cannot create capture file (must not exist)");
    FILE *f=fdopen(fd,"wb");
    if (!f || fwrite(header,1,header_size,f)!=header_size) die("Cannot write capture header");
    double start=now();
    for (uint32_t i=0;i<count;i++) {
        uint32_t v=command(READ,i);
        if (v>65535) die("Invalid sample width");
        unsigned char pair[2]={(unsigned char)v,(unsigned char)(v>>8)};
        if (fwrite(pair,1,2,f)!=2) die("Cannot write sample");
    }
    if (fflush(f) || fsync(fd) || fclose(f)) die("Cannot finish capture file");
    printf("{\"id\":%u,\"seed\":%u,\"samples\":%u,\"requested\":%u,"
           "\"period_ticks\":%u,\"status\":%u,\"mode\":%u,\"invert\":%u,"
           "\"format\":%u,\"framing_errors\":%u,\"read_seconds\":%.6f}\n",
           id,seed,count,limit,period,status,mode,invert,format,errors,now()-start);
}
static void usage(void) {
    die("Usage: c96-capture probe | status | stop | arm SEED COUNT PERIOD ID\n"
        "       c96-capture configure MODE INVERT FORMAT\n"
        "       c96-capture export FILE\n"
        "       c96-capture capture FILE SEED COUNT PERIOD ID [STOP_AFTER_MS]");
}
int main(int argc,char **argv) {
    if (argc<2) usage();
    int probe=!strcmp(argv[1],"probe") && argc==2;
    int status=!strcmp(argv[1],"status") && argc==2;
    int stop=!strcmp(argv[1],"stop") && argc==2;
    int arm=!strcmp(argv[1],"arm") && argc==6;
    int export=!strcmp(argv[1],"export") && argc==3;
    int capture=!strcmp(argv[1],"capture") && (argc==7 || argc==8);
    int configure=!strcmp(argv[1],"configure") && argc==5;
    if (!(probe || status || stop || arm || export || capture || configure)) usage();
    connect_fpga();
    if (probe) printf("protocol=0x%06x capacity=%u samples\n",command(INFO,0),command(CAPACITY,0));
    if (stop) command(STOP,0);
    if (status || stop) printf("status=0x%x samples=%u id=%u\n",command(STATUS,0),command(COUNT,0),command(CAPTURE_ID,0));
    if (configure) {
        if (protocol==0x960101) die("External input mode requires protocol 0x960102 or later");
        if (command(STATUS,0)&1) die("Cannot configure an active capture");
        uint32_t mode=number(argv[2],protocol>=0x960103 ? 3 : 2), invert=number(argv[3],15), format=number(argv[4],3);
        command(MODE,mode); command(INVERT,invert); command(FORMAT,format);
        if (command(GET_MODE,0)!=mode || command(GET_INVERT,0)!=invert ||
            command(GET_FORMAT,0)!=format) die("Input configuration readback failed");
        printf("mode=%u invert=%u format=%u pins_raw=%u\n",mode,invert,format,command(PINS,0));
    }
    if (arm) arm_capture(argv+2);
    if (capture) {
        unsigned stop_ms=argc==8 ? number(argv[7],60000) : 0;
        arm_capture(argv+3);
        double start=now();
        double ticks=number(argv[4],32768)*(double)number(argv[5],0xffffff);
        if (protocol>=0x960103 && command(GET_MODE,0)==3) {
            // Conservative upper bound for the qualified native frame interval.
            // Older Yamaha protocols ignore PERIOD; v104 uses a stereo stride.
            double stride=protocol==0x960104 ? number(argv[5],1024) : 1;
            ticks=((number(argv[4],32768)+1)/2)*stride*4096;
        }
        double deadline=start+ticks/1e8+5;
        while (command(STATUS,0)&1) {
            if (stop_ms && now()-start>=stop_ms/1000.0) command(STOP,0);
            if (now()>deadline) { command(STOP,0); die("Capture completion timeout; stopped"); }
            pause_ms(1);
        }
    }
    if (export || capture) export_capture(argv[2]);
    return 0;
}
