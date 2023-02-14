package main

import(
	"bufio"
	"fmt"
	"os"
	"regexp"
	"strconv"
)

type Access struct {
	data, addr int
	write bool
	line int
}

func (a *Access)Eq( b Access) bool {
	return a.data==b.data && a.addr==b.addr && a.write==b.write
}

func (a *Access)Dump() string {
	dir := "rd"
	if a.write {
		dir = "wr"
	}
	return fmt.Sprintf("%04X %02X %s @ %d", a.addr, a.data, dir, a.line )
}

func read_sim( fname string ) []Access {
	fin, _ := os.Open(fname)
	defer fin.Close()
	sc := bufio.NewScanner(fin)
	y := make([]Access,0)
	// for k:=0; k<8; k++ {
	// 	sc.Scan() // skip the first 8 lines
	// }
	line := 1
	for sc.Scan() {
		if( sc.Text()=="RESET" ) {
			line = 1
			y = make([]Access,0) // ditchess previously read stuff
			continue
		}
		var acc Access
		var dir string
		fmt.Sscanf( sc.Text(), "%x %s %x", &acc.addr, &dir, &acc.data )
		if dir == "<-" {
			acc.write = true
		} else if dir != "->" {
			fmt.Println("Wrong sim file: ", sc.Text())
		}
		acc.line = line
		y = append( y, acc )
		line++
	}
	return y
}

func read_mame( fname string ) []Access {
	fin, _ := os.Open(fname)
	defer fin.Close()
	sc := bufio.NewScanner(fin)
	y := make([]Access,0)
	re := regexp.MustCompile("/[^/]*/")
	line := 1
	for sc.Scan() {
		for _, each := range(re.FindAllString( sc.Text(), -1 )) {
			var acc Access
			var dir string
			fmt.Sscanf( each, "/%x %s %x/", &acc.addr, &dir, &acc.data )
			if dir == "<-" {
				acc.write = true
			}
			acc.line = line
			y = append( y, acc )
		}
		line++
	}
	return y
}

func main() {
	cpu := "main"
	if len(os.Args)>1 {
		cpu = os.Args[1]
		fmt.Printf("Reading from the %s files\n",cpu)
	}
	sim := read_sim( cpu + ".log")
	mame:=read_mame( cpu + ".tr")
	k:=0
	last_swap := false
	line_check:
	for k=0; k <len(sim); {
		if !sim[k].Eq(mame[k]) && k+1 < len(sim) && sim[k+1].Eq(mame[k]) && !last_swap {
			// swap them
			aux := sim[k]
			sim[k] = sim[k+1]
			sim[k+1] = aux
			last_swap = true
		} else {
			last_swap = false
		}
		if !sim[k].Eq(mame[k]) {
			for j := 2; j<len(os.Args); j++ {
				n, err :=strconv.Atoi(os.Args[j])
				if err == nil && n==sim[k].line {
					fmt.Printf("Ignoring mismatched line %d\n", sim[k].line )
					k++
					continue line_check
				}
			}
			fmt.Printf("Split ways\n")
			fmt.Printf("\tSIM:  %04X %02X %t @ %d\n", sim[k].addr, sim[k].data, sim[k].write, sim[k].line )
			fmt.Printf("\tMAME: %04X %02X %t @ %d\n", mame[k].addr, mame[k].data, mame[k].write, mame[k].line )
			fmt.Printf("\nContext\n")
			for i:=k-4;i<len(sim) && i<k+4 && i>0;i++ {
				fmt.Printf("\tSIM:  %s", sim[i].Dump() )
				if(i==k) {
					fmt.Print("  *")
				}
				fmt.Print("\n")
			}
			fmt.Println("=============")
			for i:=k-4;i<len(mame) && i<k+4 && i>0;i++ {
				fmt.Printf("\tMAME:  %s", mame[i].Dump() )
				if(i==k) {
					fmt.Print("  *")
				}
				fmt.Print("\n")
			}
			break
		}
		k++
	}
	fmt.Printf("%d matches of %d lines\n",k, len(sim))
}