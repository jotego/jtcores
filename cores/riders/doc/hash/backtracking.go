package main

import (
	"log"
	"math/bits"
)

func feasible(items []Uint72, chosen []int, k int) bool {
	r := k - len(chosen)
	if r < 0 {
		return false
	}

	seen := make(map[string]int, len(items))
	buf := make([]byte, len(chosen))
	for _, it := range items {
		for i, b := range chosen {
			buf[i] = byte(it.BitAt(b))
		}
		seen[string(buf)]++
	}

	for _, cnt := range seen {
		if cnt <= 1 {
			continue
		}
		need := bits.Len(uint(cnt - 1))
		if r < need {
			return false
		}
	}
	return true
}

func search(items []Uint72, k, start int, chosen []int) ([]int, bool) {
	// Pruning
	if !feasible(items, chosen, k) {
		return nil, false
	}

	if len(chosen) == k {
		if uniqueWithBits(items, chosen) {
			cp := make([]int, len(chosen))
			copy(cp, chosen)
			return cp, true
		}
		return nil, false
	}

	for b := start; b < 72; b++ {
		chosen = append(chosen, b)
		if res, ok := search(items, k, b+1, chosen); ok {
			return res, true
		}
		chosen = chosen[:len(chosen)-1]
	}
	return nil, false
}

func backtracking(K int, items []Uint72) {
	if res, ok := search(items, K, 0, nil); ok {
		log.Printf("FOUND unique subset of %d bits: %v\n", K, res)
	} else {
		log.Printf("No subset of %d bits can separate all items.\n", K)
	}
}

func uniqueWithBits(items []Uint72, bits []int) bool {
	seen := make(map[string]struct{}, len(items))
	buf := make([]byte, len(bits))
	for _, item := range items {
		for i, b := range bits {
			buf[i] = byte(item.BitAt(b))
		}
		k := string(buf)
		if _, ok := seen[k]; ok {
			return false
		}
		seen[k] = struct{}{}
	}
	return true
}
