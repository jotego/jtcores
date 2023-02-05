package main

import "os"

type Obj struct {
	code, x, y, attr byte
}

func make_ca(id int) (code, attr byte) {
	var aux int
	aux = id & 0x3f
	aux = aux | ((id & 0x40) << 1)
	aux = aux | ((id & 0x100) >> 2)
	code = byte(aux)
	attr = byte((id & 0x80) >> 1)
	return code, attr
}

func save(buff []byte, fname string) {
	f, _ := os.Create(fname)
	f.Write(buff)
	f.Close()
}

func main() {
	var x, y byte
	y = 32
	var all_obj [32]Obj
	id0 := 144
	for k := 0; k < 16; k++ {
		if id0+k == 151 {
			code, attr := make_ca(id0 + k)
			all_obj[k] = Obj{code, x, y, attr}
		}
		x += 16
		if x == 0 {
			y += 16
		}
	}
	var buff_low [1024]byte
	var buff_hi [1024]byte
	for k, o := range all_obj {
		buff_low[(k << 1)] = o.attr
		buff_low[(k<<1)+1] = o.y
		buff_hi[(k << 1)] = o.x
		buff_hi[(k<<1)+1] = o.code
	}

	save(buff_low[:], "obj1.bin")
	save(buff_hi[:], "obj2.bin")
}
