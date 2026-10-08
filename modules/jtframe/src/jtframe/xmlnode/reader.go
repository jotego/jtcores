package xmlnode

import (
	"errors"
	"fmt"
	"io"
	"os"
	"encoding/xml"
)

func ReadFile(filename string) (*XMLNode,error) {
	f, e := os.Open(filename); if e!=nil { return nil, e }
	defer f.Close()
	return read_stream(f)
}

func read_stream(f io.Reader) (*XMLNode,error) {
	dec := xml.NewDecoder(f)
	var root, cur *XMLNode
	for {
		token, e := dec.Token()
		if errors.Is(e,io.EOF) {
			if root==nil { return nil, fmt.Errorf("The file was empty")}
			return root,nil
		}
		if e!=nil { return nil, e }
		switch t := token.(type) {
			case xml.StartElement:
				name := t.Name.Local
				if root==nil {
					n := MakeNode(name)
					root = &n
					cur = root
				} else {
					cur = cur.AddNode(name)
				}
				for _, attr := range t.Attr {
					cur.AddAttr(attr.Name.Local,attr.Value)
				}
			case xml.EndElement:
				cur = cur.Parent()
			case xml.CharData:
				if cur!=nil {
					cur.text=string(t)
				}
		}
	}
	if root==nil {
		return nil, fmt.Errorf("Empty set")
	}
	return root,nil
}