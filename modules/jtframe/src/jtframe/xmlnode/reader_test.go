package xmlnode

import (
	"testing"
	"strings"
)

func Test_read_stream(t *testing.T) {
	example := `<root><a1><a1.1 turbo="on" other="off"/><a1.2/></a1><a2>abc</a2></root>`
	n, e := read_stream( strings.NewReader(example) )
	if e!=nil {
		t.Error(e)
		return
	}
	if n.name!="root" { t.Errorf("wrong root") }
	if len(n.children)!=2 { t.Errorf("wrong children"); return }
	if n.children[0].name!="a1" { t.Errorf("wrong a1") }
	if n.children[1].name!="a2" { t.Errorf("wrong a2") }
	if n.children[1].text!="abc" { t.Errorf("wrong a2 text")}
	if len(n.children[0].children)!=2 { t.Errorf("wrong a1 children"); return }
	if n.children[0].children[0].name!="a1.1" { t.Errorf("wrong a1.1") }
	if len(n.children[0].children[0].attr)!=2 { t.Errorf("wrong attributes a1.1"); return}
	if n.children[0].children[0].attr[0].Name!="turbo" { t.Errorf("wrong turbo on a1.1"); return}
	if n.children[0].children[0].attr[0].Value!="on" { t.Errorf("wrong turbo on a1.1"); return}
	if n.children[0].children[0].attr[1].Name!="other" { t.Errorf("wrong other on a1.1"); return}
	if n.children[0].children[0].attr[1].Value!="off" { t.Errorf("wrong other on a1.1"); return}
	if n.children[0].children[1].name!="a1.2" { t.Errorf("wrong a1.2") }
}