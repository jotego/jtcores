package mra

// Minimum support for now
type MRA struct {
	Name    string `xml:"name"`
	Setname string `xml:"setname"`
	Rbf     string `xml:"rbf"`
}

type MRAfile struct {
	data MRA `xml:"misterromdescription"`
}
