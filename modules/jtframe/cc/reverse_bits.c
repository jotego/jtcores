// reverse_bits
// 2022 Developer
//
// LICENSE: This code is public domain.
//

#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <stdlib.h>

int main(int argc, char* argv[])
{
  uint8_t *buf;
  FILE *fp;
  if (argc != 3){
    printf("\nWrong parameters given\nUsage: reverse_bits [file_in] [file_out]\n");
    return -1;
  }
  fp = fopen(argv[1], "rb");
  if (fp == NULL) {
    printf("Couldn't open the file %s for input\n", argv[1]);
    return -1;
  }
  fseek(fp, 0L, SEEK_END);
  int size = ftell(fp);
  fseek(fp, 0L, SEEK_SET);
  
  buf = (uint8_t*)malloc(size);
  if (buf == NULL){
    printf("Couldn't malloc file\n");
    return -1;
  }
  
  uint8_t in;
  for (int i = 0; i < size; i++){
    fread(&in, 1, 1, fp);
    in = ((in & 1) << 7) | ((in & 2) << 5) | ((in & 4) << 3) | ((in & 8) << 1) |
      ((in & 16) >> 1) | ((in & 32) >> 3) | ((in & 64) >> 5) | ((in & 128) >> 7);
  
    buf[i] = in;
  }
  fclose(fp);
  
  printf("Reversed %d bytes\n", size);
  fp = fopen(argv[2], "wb");
  if (fp == NULL) {
    printf("Couldn't open the file %s for output\n", argv[2]);
    return -1;
  }
  fwrite(buf, 1, size, fp);
  fclose(fp);
  
  free(buf);
  printf("Done\n");
  
  return 0;
}