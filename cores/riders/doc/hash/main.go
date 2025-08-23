package main

import (
	"flag"
	"log"
	"os"
	"strconv"
)

func main() {
	flag.Parse()

	if flag.NArg() != 3 {
		log.Fatal("Give a command, the key length and the dataset filename as arguments")
	}

	cmd := flag.Arg(0)
	k := flag.Arg(1)
	K, e := strconv.Atoi(k)
	if e != nil {
		log.Fatal("Key length must be an integer")
	}
	filename := flag.Arg(2)

	file, err := os.Open(filename)
	if err != nil {
		log.Fatal(err)
	}
	defer file.Close()

	items := readItems(file)
	if hasDuplicates(items) {
		log.Fatal("There are duplicated values in the dataset")
	}
	log.Printf("Loaded %d items\n", len(items))

	switch cmd {
	case "greedy":
		greedy(K, items)
	case "reverse-greedy":
		reverseGreedy(items)
	case "backtracking":
		backtracking(K, items)
	default:
		log.Fatal("Given command does not exist")
	}
}
