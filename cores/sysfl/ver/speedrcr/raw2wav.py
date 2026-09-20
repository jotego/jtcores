#!/usr/bin/env python3
# sound.raw ({snd_l,snd_r} 32-bit per sample, see jtframe_board.v) -> wav
import sys, wave, struct
rate = int(sys.argv[2]) if len(sys.argv)>2 else 84000  # ~24.192MHz/288
raw = open(sys.argv[1] if len(sys.argv)>1 else "sound.raw","rb").read()
n = len(raw)//4
w = wave.open("sound.wav","wb")
w.setnchannels(2); w.setsampwidth(2); w.setframerate(rate)
frames = bytearray()
peak = 0
for i in range(n):
    v = struct.unpack_from("<I", raw, i*4)[0]
    l = (v>>16) & 0xffff; r = v & 0xffff
    frames += struct.pack("<hh", l-0x10000 if l>0x7fff else l, r-0x10000 if r>0x7fff else r)
    sl = l-0x10000 if l>0x7fff else l
    if abs(sl)>peak: peak=abs(sl)
w.writeframes(bytes(frames)); w.close()
print(f"sound.wav: {n} samples @{rate}Hz, peak {peak}")
