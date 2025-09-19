package wav

import(
	"os"
)

type WavFile struct{
	buf []byte
}

func MakeWav() *WavFile {
	wav := WavFile{
		buf: make([]byte,44,2*1024*1024),
	}
	wav.make_header()
	return &wav
}

func (w *WavFile)make_header() {
	copy(w.buf,[]byte("RIFF"))
	copy(w.buf[8:],[]byte("WAVEfmt "))
	copy(w.buf[36:],[]byte("data"))
	w.buf[16]=16	// 16-bit sound
	w.buf[20]=1
	w.buf[22]=2
	sample_rate := uint32(48000)
	w.write32(24,sample_rate)
	w.write32(28,sample_rate*4)
	w.buf[32]=4
	w.buf[34] = 16
}

func (w *WavFile)write32(offset int, value uint32) {
	w.buf[offset+0] = byte((value>> 0)&0xff)
	w.buf[offset+1] = byte((value>> 8)&0xff)
	w.buf[offset+2] = byte((value>>16)&0xff)
	w.buf[offset+3] = byte((value>>24)&0xff)
}

func (w *WavFile)append( value int16 ) {
	asbytes := []byte{byte(value),byte(value>>8)}
	w.buf=append(w.buf,asbytes...) // left
	w.buf=append(w.buf,asbytes...) // right
}

func (w *WavFile)Dump(fname string) error {
	w.write32(4,  uint32(len(w.buf)))
	w.write32(40, uint32(len(w.buf)-44))
	return os.WriteFile(fname,w.buf,0664)
}