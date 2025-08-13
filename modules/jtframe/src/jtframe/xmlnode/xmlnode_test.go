package xmlnode

import(
	"fmt"
	"testing"
)

func TestFindAll(t *testing.T) {
	top := XMLNode{
		name: "top",
		children: []*XMLNode{
			&XMLNode{ name: "a" },
			&XMLNode{ name: "b" },
			&XMLNode{
				name: "c",
				children: []*XMLNode{
					&XMLNode{ name: "xx", text: "1" },
					&XMLNode{ name: "xx", text: "2" },
					&XMLNode{ name: "xx", text: "3" },
					&XMLNode{ name: "xx", text: "4" },
				},
			},
			&XMLNode{
				name: "d",
				children: []*XMLNode{
					&XMLNode{ name: "d2" },
					&XMLNode{
						name: "d3",
						children: []*XMLNode{
							&XMLNode{ name: "xx", text: "5" },
							&XMLNode{ name: "xx", text: "6" },
						},
					},
				},
			},
		},
	}
	all := top.FindAll("xx")
	if len(all)!=6 {
		show(all, t)
		t.Error("Expecting 6 elements")
	}
	for k:=1;k<7;k++ {
		id := fmt.Sprintf("%d",k)
		found := false
		for _,node := range all {
			if node.text==id {
				found = true
				break
			}
		}
		if !found {
			t.Errorf("Missing node %s",id)
		}
	}
}

func show(all []*XMLNode, t *testing.T) {
	for _, node := range all {
		t.Logf("%s - %s\n",node.name,node.text)
	}
}