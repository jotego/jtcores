/* SPDX-License-Identifier: GPL-3.0-or-later */
/* Close a configfs DT overlay explicitly while the calling task is alive.
 * Linux 5.4 vendor configfs applies the blob at file release. Leaving the
 * descriptor open until process exit can invoke request_firmware after
 * current->fs has been released, faulting in pathname lookup.
 */
#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

int main(int argc, char **argv) {
    struct stat info;
    struct timespec start, end;
    unsigned char *blob;
    size_t done = 0;
    ssize_t count;
    int input, output;
    if (argc != 3) {
        fprintf(stderr, "Usage: %s overlay.dtbo configfs-overlay/dtbo\n", argv[0]);
        return 2;
    }
    input = open(argv[1], O_RDONLY | O_CLOEXEC);
    if (input < 0) { perror("open overlay"); return 1; }
    if (fstat(input, &info) || info.st_size <= 0 || info.st_size > 65536) {
        fprintf(stderr, "Overlay must contain 1..65536 bytes\n");
        close(input);
        return 1;
    }
    blob = malloc((size_t)info.st_size);
    if (!blob) { perror("allocate overlay"); close(input); return 1; }
    while (done < (size_t)info.st_size) {
        count = read(input, blob + done, (size_t)info.st_size - done);
        if (count < 0 && errno == EINTR) continue;
        if (count <= 0) {
            fprintf(stderr, "Incomplete overlay read\n");
            close(input); free(blob); return 1;
        }
        done += (size_t)count;
    }
    if (close(input)) { perror("close input"); free(blob); return 1; }
    output = open(argv[2], O_WRONLY | O_CLOEXEC);
    if (output < 0) { perror("open configfs attribute"); free(blob); return 1; }
    if (clock_gettime(CLOCK_MONOTONIC, &start)) {
        perror("start clock"); close(output); free(blob); return 1;
    }
    done = 0;
    while (done < (size_t)info.st_size) {
        count = write(output, blob + done, (size_t)info.st_size - done);
        if (count < 0 && errno == EINTR) continue;
        if (count <= 0) {
            perror("write overlay"); close(output); free(blob); return 1;
        }
        done += (size_t)count;
    }
    /* Includes synchronous FPGA programming triggered by configfs release. */
    if (close(output)) { perror("apply overlay"); free(blob); return 1; }
    if (clock_gettime(CLOCK_MONOTONIC, &end)) {
        perror("end clock"); free(blob); return 1;
    }
    printf("{\"overlay_bytes\":%zu,\"program_seconds\":%.6f}\n", done,
           (double)(end.tv_sec - start.tv_sec) +
           (double)(end.tv_nsec - start.tv_nsec) * 1e-9);
    free(blob);
    return 0;
}
