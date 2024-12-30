package main

import (
	"bufio"
	"fmt"
	"log"
	"os"
	"strconv"
	"strings"
)

type field struct {
	main, sub  bool
	write bool
	addr  uint64
	data  uint64
	line int
}

func create_reader(fname string) *bufio.Scanner {
	f, e := os.Open(fname)
	if e != nil {
		log.Fatal(e)
		return nil
	}
	rd := bufio.NewReader(f)
	if rd == nil {
		log.Fatal("Cannot read file ", fname)
	}
	return bufio.NewScanner(rd)
}

func tokenize(s string, line int, f *field) {
	tokens := strings.Split(s, " ")
	if len(tokens)<4 {
		f.main = false
		f.sub = false
	}
	f.main = tokens[0]=="main"
	f.sub = tokens[0]=="sub"
	f.write = tokens[1] == "WR"
	f.addr, _ = strconv.ParseUint(tokens[2], 16, 32)
	f.data, _ = strconv.ParseUint(strings.Trim(tokens[3], "()"), 16, 16)
	f.line = line
}

func ( f *field ) Print( s string ) {
	fmt.Printf("%4s (%d) ", s, f.line)
	if f.main {
		fmt.Printf("main ")
	}
	if f.sub {
		fmt.Printf("sub ")
	}
	if f.write {
		fmt.Printf("WR")
	} else {
		fmt.Printf("RD")
	}
	fmt.Printf(" %X (%04X)\n", f.addr, f.data )
}

func match( a, b field ) bool {
	a.Print("MAME")
	b.Print("SIM")
	fmt.Println("")
	return  a.addr  == b.addr  &&
			a.data  == b.data  &&
			a.write == b.write &&
			a.main  == b.main  &&
			a.sub   == b.sub
}

func report( mame_token, sim_token field ) {
	fmt.Printf("discrepancy at lines %d (mame)/%d (sim)\n",
		mame_token.line, sim_token.line )
		mame_token.Print("MAME")
		sim_token.Print("SIM")
}

func get_next( sim *bufio.Scanner, sim_ln *int, sim_token *field ) bool {
	for sim.Scan() {
		*sim_ln++
		tokenize(sim.Text(), *sim_ln, sim_token)

		if sim_token.sub {
			return true
		}
	}
	return false
}

func main() {
	sim := create_reader("sim.log")
	mame := create_reader("outrun.log")
	var mame_ln, sim_ln int
	var mame_token, sim_token, saved field
	var good int
	use_saved := false
top:
	for get_next( mame, &mame_ln, &mame_token ) {
		for get_next( sim, &sim_ln, &sim_token ) {
			if !match( mame_token, sim_token ) {
				if use_saved {
					if !match( mame_token, saved ) {
						report( mame_token, saved )
						break top
					}
					saved = sim_token
				} else {
					saved = sim_token
					use_saved = true
				}
			} else {
				good++
				break
			}
		}
	}
	fmt.Printf("Parsed %d lines\n", good)
}
