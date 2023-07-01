package vcd

type SimState struct{
	data vcdData
	ram []byte
}

type MAMEState struct{
	data NameValue
	alias mameAlias
	ram []byte
}