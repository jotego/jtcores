package main

import "log"

func reverseGreedy(items []Uint72) {
	key, count := removeBits(items)

	log.Printf("Key: %b\n", key)
	log.Println("Key length: ", count)

}

func removeBits(items []Uint72) (Uint72, int) {
	var key Uint72
	key.Set()
	count := 72

	for i := 0; i < 72; i++ {
		tempKey := key
		tempKey.ResetBit(i)
		if allUniques(items, tempKey) {
			key.ResetBit(i)
			count--
		}
	}
	return key, count
}

func allUniques(items []Uint72, key Uint72) bool {
	uniques := make(map[Uint72]struct{})

	for _, item := range items {
		value := item.And(key)
		if _, found := uniques[value]; found {
			return false
		}
		uniques[value] = struct{}{}
	}
	return true
}
