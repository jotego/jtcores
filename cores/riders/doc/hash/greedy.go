package main

import (
	"log"
	"math/rand"
	"time"
)

func greedy(K int, items []Uint72) {
	const attempts = 100

	var bestSel []int
	for a := 0; a < attempts; a++ {
		sel, success := selectBitsGreedy(items, K, a)
		if success {
			log.Printf("OK (attempt %d, len=%d): %v\n", a+1, len(sel), sel)
			return
		}
		if len(sel) > len(bestSel) {
			bestSel = sel
		}
	}

	log.Printf("FAIL. Best option: %v (len=%d)\n",
		bestSel, len(bestSel))
}

func selectBitsGreedy(items []Uint72, k int, random int) ([]int, bool) {
	N := len(items)
	selected := []int{}
	used := make([]bool, 72)

	keys := make([]Uint72, N)
	nextBit := 0

	groups := make(map[Uint72][]int, N)
	for i, key := range keys {
		groups[key] = append(groups[key], i)
	}

	for nextBit < k {
		r := rand.New(rand.NewSource(time.Now().UnixNano() + int64(random)))
		order := r.Perm(72)

		bestBit := -1
		bestScore := -1

		for _, b := range order {
			if used[b] {
				continue
			}
			score := 0
			for _, g := range groups {
				if len(g) <= 1 {
					continue
				}
				zeros := 0
				for _, idx := range g {
					if items[idx].BitAt(b) == 0 {
						zeros++
					}
				}
				ones := len(g) - zeros
				if zeros == 0 || ones == 0 {
					continue
				}
				if zeros < ones {
					score += zeros
				} else {
					score += ones
				}
			}
			if score > bestScore {
				bestScore = score
				bestBit = b
			} else if score == bestScore && score >= 0 && bestBit != -1 { // Tie-break
				if rand.Intn(2) == 0 {
					bestBit = b
				}
			}
		}

		if bestBit == -1 { // No bit can divide any group
			break
		}

		for i := range items {
			if items[i].BitAt(bestBit) == 1 {
				keys[i].SetBit(nextBit)
			}
		}
		used[bestBit] = true
		selected = append(selected, bestBit)
		nextBit++

		groups = make(map[Uint72][]int, N)
		for i, key := range keys {
			groups[key] = append(groups[key], i)
		}

		done := true
		for _, g := range groups {
			if len(g) > 1 {
				done = false
				break
			}
		}
		if done {
			return selected, true
		}
	}
	return selected, false
}
