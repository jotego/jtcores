/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Date: 4-1-2025 */

package mra

import (
	"fmt"
	"math"
	"strconv"
	"strings"
)

type XMLAttr struct {
	Name, Value string
}

type XMLNode struct {
	name, text string
	comment    bool
	attr       []XMLAttr
	children   []*XMLNode
	depth      int
	indent_txt bool
}

// first XML node of a ROM region
type StartNode struct {
	node *XMLNode
	pos  int
}

func (this *StartNode) add_length(pos int) {
	if this.node != nil {
		lenreg := pos - this.pos
		if lenreg > 0 {
			this.node.name = fmt.Sprintf("%s - length 0x%X (%d bits)", this.node.name, lenreg,
				int(math.Ceil(math.Log2(float64(lenreg)))))
		}
	}
}

func (n *XMLNode) GetNode(name string) *XMLNode {
	for _, c := range n.children {
		if c.name == name {
			return c
		}
	}
	return nil
}

func (n *XMLNode) AddNode(names ...string) *XMLNode {
	var child XMLNode
	child.name = names[0]
	n.children = append(n.children, &child)
	child.depth = n.depth + 1
	if len(names) > 1 {
		child.text = names[1]
		for k := 2; k < len(names); k++ {
			child.text = child.text + names[k]
		}
	}
	return &child
}

func (n *XMLNode) RmNode( rm *XMLNode ) {
	rest := make( []*XMLNode, 0, len(n.children)-1 )
	for _, each := range n.children {
		if each != rm {
			rest = append( rest, each )
		}
	}
	n.children = rest
}

// Inserts a copy of a node
func (n *XMLNode) InsertNode( child XMLNode ) *XMLNode {
	n.children = append(n.children, &child)
	child.depth = n.depth + 1
	return &child
}

func (n *XMLNode) AddAttr(name, value string) *XMLNode {
	n.attr = append(n.attr, XMLAttr{name, value})
	return n
}

func (n *XMLNode) ChangeAttr(name, value string) *XMLNode {
    for k,_ := range n.attr {
        if n.attr[k].Name == name {
            n.attr[k].Value = value
            return n
        }
    }
    return n.AddAttr(name,value) // Adds it if it doesn't exist
}

func (n *XMLNode) AddIntAttr(name string, value int) *XMLNode {
	n.attr = append(n.attr, XMLAttr{name, strconv.Itoa(value)})
	return n
}

func (n *XMLNode) SetText(value string) *XMLNode {
	n.text = value
	return n
}

func (n *XMLNode) GetAttr(name string) string {
	for _, a := range n.attr {
		if a.Name == name {
			return a.Value
		}
	}
	return ""
}

func (n *XMLNode) FindNode(name string) (found *XMLNode) {
	if n.name == name {
		return n
	} else {
		for _, each := range n.children {
			found = each.FindNode(name)
			if found != nil {
				return found
			}
		}
	}
	found = nil
	return found
}

func (n *XMLNode) FindMatch(f func(n *XMLNode) bool) *XMLNode {
	if f(n) {
		return n
	} else {
		for _, each := range n.children {
			if f(each) {
				return each
			}
		}
	}
	return nil
}

func xml_str(in string) string {
	out := strings.ReplaceAll(in, "&", "&amp;")
	out = strings.ReplaceAll(out, "'", "&apos;")
	out = strings.ReplaceAll(out, "<", "&lt;")
	out = strings.ReplaceAll(out, ">", "&gt;")
	out = strings.ReplaceAll(out, `\`, "&quot;")
	return out
}

func (n *XMLNode) Dump() string {
	var s, indent string
	for k := 0; k < n.depth; k++ {
		indent += "    "
	}
	if n.comment {
		return indent + "<!-- " + n.name + " -->"
	}
	s = fmt.Sprintf("%s<%s", indent, n.name)
	if len(n.attr) > 0 {
		for _, a := range n.attr {
			s += fmt.Sprintf(" %s=\"%v\"", a.Name, xml_str(a.Value))
		}
	}
	if len(n.text) > 0 {
		// dump text
		s = s + ">"
		if n.indent_txt {
			lines := strings.Split(xml_str(n.text), "\n")
			for _, l := range lines {
				s += "\n" + indent
				if len(l) > 0 {
					s += "    " + l
				}
			}
		} else {
			s += xml_str(n.text)
		}
		s = s + fmt.Sprintf("</%s>", n.name)
	} else {
		if len(n.children) > 0 {
			s = s + ">" + n.text
			for _, c := range n.children {
				s = s + "\n" + c.Dump()
			}
			s = s + fmt.Sprintf("\n%s</%s>", indent, n.name)
		} else {
			s = s + "/>"
		}
	}
	return s
}
