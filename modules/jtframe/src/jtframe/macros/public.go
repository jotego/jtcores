package macros

import(
	"strconv"
	"strings"
)

var macros map[string]string

func IsSet( name string ) (set bool) {
	_, set = macros[name]
	return set
}

func Get(name string) (value string) {
	value, _ = macros[name]
	return value
}

func GetInt(name string) (value int) {
	as_string, _ := macros[name]
	value, _ = strconv.Atoi(as_string)
	return value
}

func IsInt(name string) bool {
	val := Get(name)
	if val=="" { return false }
	_, e := strconv.ParseInt( val, 0, 64 )
	return e==nil
}

func Set(name, value string) {
	macros[strings.ToUpper(name)]=value
}

func Remove(all_names ...string) {
	for _, name := range all_names {
		delete(macros,name)
	}
}

func CopyToMap() (copy map[string]string) {
	copy = make(map[string]string)
	for key,val := range macros {
		copy[key]=val
	}
	return copy
}

func AddKeyValPairs( key_val ...string ) {
	for _, def := range key_val {
		split := strings.SplitN(def, "=", 2)
		var name, val string
		if len(split) >= 1 {
			name = split[0]
		}
		if name=="" { continue }
		if len(split) == 2 {
			val = split[1]
		} else {
			val="1"
		}
		Set(name,val)
	}
}

// Mostly meant to be used for unit tests
func MakeFromMap(ref map[string]string) {
	macros = make(map[string]string)
	for key,val := range ref {
		macros[key]=val
	}
}