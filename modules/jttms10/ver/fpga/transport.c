// SPDX-License-Identifier: GPL-3.0-or-later
// Single-process HPS transport for a stream of autonomous FPGA batches.
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>

#define LW_BASE 0xff210000u
#define SYSID_OFFSET 0x820u
#define RUNNER_OFFSET 0x840u
#define MAP_BYTES 0x1000u
#define MAX_CASES 32u
#define MAX_PROGRAM_WORDS 4096u
#define RESULT_WORDS 72u
#define MAX_EVENTS 4096u
#define MAX_BATCHES 4096u
#define DEFAULT_TIMEOUT_MS 180000u

static volatile uint32_t *regs;
static void wr(uint32_t index, uint32_t value) {
    regs[index] = value;
    __sync_synchronize();
}
static uint32_t rd(uint32_t index) {
    __sync_synchronize();
    return regs[index];
}
static int is_busy(uint32_t status) {
    return (status & 1u) != 0u && (status & 0x80000000u) == 0u;
}
static uint64_t millis(void) {
    struct timespec t;
    if (clock_gettime(CLOCK_MONOTONIC, &t)) return 0;
    return (uint64_t)t.tv_sec * 1000u + (uint64_t)t.tv_nsec / 1000000u;
}
static int read_exact(FILE *f, void *buf, size_t n) {
    return fread(buf, 1, n, f) == n;
}
static void fail(const char *message) { fprintf(stderr, "runner transport: %s\n", message); }

static int run_batch(FILE *in, uint32_t batch_index, uint32_t *previous_status) {
    uint32_t dims[3];
    if (!read_exact(in, dims, sizeof dims)) { fail("truncated batch header"); return 2; }
    uint32_t ncase=dims[0], nprog=dims[1], timeout=dims[2];
    if (!ncase || ncase>MAX_CASES || !nprog || nprog>MAX_PROGRAM_WORDS) {
        fail("batch dimensions out of range"); return 2;
    }
    uint32_t *desc=calloc((size_t)ncase*8,sizeof *desc);
    uint16_t *prog=calloc(nprog,sizeof *prog);
    if (!desc || !prog || !read_exact(in,desc,(size_t)ncase*8*sizeof *desc) ||
        !read_exact(in,prog,(size_t)nprog*sizeof *prog)) {
        fail("truncated batch payload"); free(desc); free(prog); return 2;
    }
    for(uint32_t c=0;c<ncase;c++) {
        uint32_t *d=&desc[c*8];
        if (!d[2] || d[1]>=nprog || d[2]>nprog-d[1] || d[2]>3840u ||
            d[3]<0x1000u || d[3]>=0x10000u || (d[3]&15u) ||
            d[4]<0x1000u || d[4]>=0x10000u || (d[4]&15u) || d[5]>255u) {
            fail("descriptor program bounds or measurement target invalid"); free(desc); free(prog); return 2;
        }
    }
    uint32_t live_status=rd(1);
    if (is_busy(live_status) || is_busy(*previous_status)) {
        fail("runner is still busy; refusing to stage another batch"); free(desc); free(prog); return 4;
    }
    uint64_t stage_start=millis();
    if (*previous_status==2 || (*previous_status & 0x80000000u)) wr(1,0);
    wr(2,ncase); wr(3,0);
    for(uint32_t i=0;i<ncase*8;i++) wr(4,desc[i]);
    wr(5,0);
    for(uint32_t i=0;i<nprog;i++) wr(6,prog[i]);
    if(timeout>=1000) wr(15,timeout);
    wr(1,1);
    uint64_t stage_end=millis();
    uint64_t start=stage_end; uint32_t status=1;
    while(is_busy(status)) {
        usleep(1000); status=rd(1);
        if(millis()-start>DEFAULT_TIMEOUT_MS) {
            fail("host wall-clock timeout while FPGA controller busy");
            free(desc); free(prog); return 4;
        }
    }
    uint64_t run_end=millis();
    *previous_status=status;
    uint32_t event_word=rd(7), nevent=event_word&0x7fffffffu;
    if(nevent>MAX_EVENTS) { fail("event count exceeds output bound"); free(desc); free(prog); return 5; }
    if(batch_index) putchar(',');
    printf("{\"status\":%" PRIu32 ",\"event_count\":%" PRIu32
           ",\"stage_ms\":%" PRIu64 ",\"run_ms\":%" PRIu64
           ",\"results\":[",status,event_word,stage_end-stage_start,run_end-start);
    for(uint32_t c=0;c<ncase;c++) {
        if(c) putchar(',');
        putchar('[');
        for(uint32_t w=0;w<RESULT_WORDS;w++) {
            if(w) putchar(',');
            wr(8,c*RESULT_WORDS+w); printf("%" PRIu32,rd(9));
        }
        putchar(']');
    }
    printf("],\"events\":[");
    for(uint32_t e=0;e<nevent;e++) {
        if(e) putchar(',');
        putchar('['); wr(10,e);
        for(uint32_t w=0;w<4;w++) { if(w)putchar(',');printf("%" PRIu32,rd(11+w)); }
        putchar(']');
    }
    printf("],\"drain_ms\":%" PRIu64 "}",millis()-run_end);
    free(desc); free(prog);
    return status==2 ? 0 : 6;
}

int main(int argc,char **argv) {
    if(argc!=4){fail("usage: transport BATCHES.bin EXPECTED_SYSID EXPECTED_TIMESTAMP");return 2;}
    char *end=NULL;
    errno=0; unsigned long expected_id=strtoul(argv[2],&end,0);
    if(errno || !end || *end || expected_id>UINT32_MAX){fail("invalid expected SYSID");return 2;}
    errno=0; unsigned long expected_timestamp=strtoul(argv[3],&end,0);
    if(errno || !end || *end || expected_timestamp>UINT32_MAX){fail("invalid expected SYSID timestamp");return 2;}
    FILE *in=fopen(argv[1],"rb");
    if(!in){perror("fopen batch");return 2;}
    uint8_t magic[4]; uint32_t nbatch;
    if(!read_exact(in,magic,4)||memcmp(magic,"JTR2",4)||!read_exact(in,&nbatch,sizeof nbatch)||!nbatch||nbatch>MAX_BATCHES){
        fail("bad stream header");fclose(in);return 2;
    }
    int fd=open("/dev/mem",O_RDWR|O_SYNC);
    if(fd<0){perror("open /dev/mem");fclose(in);return 2;}
    void *map=mmap(NULL,MAP_BYTES,PROT_READ|PROT_WRITE,MAP_SHARED,fd,LW_BASE);
    if(map==MAP_FAILED){perror("mmap lightweight bridge");close(fd);fclose(in);return 2;}
    volatile uint32_t *sysid=(volatile uint32_t *)((volatile char *)map+SYSID_OFFSET);
    uint32_t live_id=sysid[0], live_timestamp=sysid[1];
    if(live_id!=(uint32_t)expected_id || live_timestamp!=(uint32_t)expected_timestamp) {
        fprintf(stderr,"runner transport: safe SYSID preflight mismatch at 0xff210820: got %" PRIu32 "/%" PRIu32 ", expected %" PRIu32 "/%" PRIu32 "\n",
                live_id,live_timestamp,(uint32_t)expected_id,(uint32_t)expected_timestamp);
        munmap(map,MAP_BYTES);close(fd);fclose(in);return 3;
    }
    regs=(volatile uint32_t *)((volatile char *)map+RUNNER_OFFSET);
    if(rd(0)!=0x4a545231u){fail("runner magic mismatch at 0xff210840");munmap(map,MAP_BYTES);close(fd);fclose(in);return 3;}
    uint32_t previous_status=rd(1); int overall=0;
    printf("{\"batches\":[");
    for(uint32_t b=0;b<nbatch;b++) {
        int rc=run_batch(in,b,&previous_status);
        if(rc && !overall)overall=rc;
        if(rc==2||rc==4||rc==5)break;
    }
    printf("]}\n");fflush(stdout);
    munmap(map,MAP_BYTES);close(fd);fclose(in);
    return overall;
}
