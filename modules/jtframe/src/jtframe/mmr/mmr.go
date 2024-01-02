package mmr

import(
	"bytes"
	"fmt"
	"math"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"text/template"

	"gopkg.in/yaml.v2"
)

type Chunk struct {
	Byte, Msb, Lsb int
}

type Register struct {
	Name, Desc string
	Dw int
	At string
	Wr_event bool
	// Added by jtframe
	Chunks []Chunk
}

type MMRdef struct {
	Name string
	Size int
	Regs []Register
	Read_only bool
	// Added by jtframe
	AMSB int
	Core string
	Seq []int
}

func convert( corename, hdl_path string, cfg MMRdef ) {
	tpath := filepath.Join(os.Getenv("JTFRAME"), "hdl", "inc", "mmr.v")
	t := template.Must(template.New("mmr.v").ParseFiles(tpath))
	var buffer bytes.Buffer
	t.Execute(&buffer, cfg)
	// Dump the file
	fname := fmt.Sprintf("jt%s_%s_mmr.v",corename,cfg.Name)
	outpath := filepath.Join(hdl_path,fname)
	e := os.WriteFile(outpath, buffer.Bytes(), 0644)
	if e!=nil {
		fmt.Println("Error:",e)
	}
}

func Generate( corename string, verbose bool ) {
	fname := filepath.Join(os.Getenv("CORES"),corename,"cfg","mmr.yaml")
	buf, e := os.ReadFile(fname)
	if e != nil {
		if verbose {
			fmt.Println("Cannot open", fname)
		}
		return
	}
	var cfg []MMRdef
	e = yaml.Unmarshal( buf, &cfg )
	if e!=nil {
		fmt.Println(e)
		os.Exit(1)
	}
	sanity_check(cfg)
	hdl_path := filepath.Join(os.Getenv("CORES"), corename, "hdl")
	for k, _ := range cfg {
		cfg[k].Core=corename
		cfg[k].AMSB=int(math.Ceil(math.Log2(float64(cfg[k].Size)))-1)
		cfg[k].Seq=make([]int,cfg[k].Size)
		for i:=0;i<cfg[k].Size;i++ { cfg[k].Seq[i]=i }
		for j, _ := range cfg[k].Regs {
			ss := strings.Split(cfg[k].Regs[j].At,",")
			for j, _ := range ss {
				ss[j] = strings.TrimSpace(ss[j])
			}
			cfg[k].Regs[j].Chunks = make([]Chunk,len(ss))
			for m, _ := range ss {
				aux := &cfg[k].Regs[j].Chunks[m]
				var a int64
				// match a single number
				re := regexp.MustCompile(`^0[xX][0-9a-fA-F]+$|^0[0-7]+$|^\d+$`)
				if re.MatchString(ss[m]) {
					a, _ = strconv.ParseInt( ss[m], 0, 16 )
					aux.Byte = int(a)
					aux.Msb = 7
					aux.Lsb = 0
					// fmt.Printf("%s matched as single digit\n",ss[m])
					continue
				}
				// match number[number]
				re = regexp.MustCompile(`(0[xX][0-9A-Fa-f]+|0[0-7]+|\d+)\[(0[xX][0-9A-Fa-f]+|0[0-7]+|\d+)\]`)
 				matches := re.FindStringSubmatch(ss[m])
				if len(matches)==3 {
					a, _ = strconv.ParseInt( matches[1], 0, 16 )
					aux.Byte = int(a)
					a, _ = strconv.ParseInt( matches[2], 0, 16 )
					aux.Msb = int(a)
					aux.Lsb = aux.Msb
					// fmt.Printf("%s matched as n[m]\n",ss[m])
					continue
				}
				// match number[number:number]
				re = regexp.MustCompile(`(^[0-9A-Fa-f]+|^0[0-7]+|^\d+)\[([0-9A-Fa-f]+|0[0-7]+|\d+):([0-9A-Fa-f]+|0[0-7]+|\d+)\]$`)
 				matches = re.FindStringSubmatch(ss[m])
				if len(matches)==4 {
					a, _ = strconv.ParseInt( matches[1], 0, 16 )
					aux.Byte = int(a)
					a, _ = strconv.ParseInt( matches[2], 0, 16 )
					aux.Msb = int(a)
					a, _ = strconv.ParseInt( matches[3], 0, 16 )
					aux.Lsb = int(a)
					// fmt.Printf("%s matched as n[m:l]\n",ss[m])
					continue
				}
				// Cannot parse it
				fmt.Printf("Error: jtframe mmr cannot parse location %s\n",ss[m])
				os.Exit(1)

			}
		}
		convert(corename,hdl_path,cfg[k])
	}
}

func sanity_check( cfg []MMRdef ) {
	for _, each := range(cfg) {
		if each.Name=="" {
			fmt.Println("Error: MMR without name")
			os.Exit(1)
		}
		if each.Size<4 {
			fmt.Printf("Error: %s's MMR size is less than 4\n", each.Name)
			os.Exit(1)
		}
		if( len(each.Regs)==0 ) {
			fmt.Printf("Error: %s's MMR does not have any output")
			os.Exit(1)
		}
		for _, reg := range each.Regs {
			if reg.Name=="" {
				fmt.Printf("Error: %s's MMR has unnamed registers\n", each.Name )
				os.Exit(1)
			}
			if reg.Dw == 0 {
				fmt.Printf("Error: %s's MMR has register %s with no size\n", each.Name, reg.Name)
				os.Exit(1)
			}
			if reg.At=="" {
				fmt.Printf("Error: %s's MMR has register %s with no location\n", each.Name, reg.Name)
				os.Exit(1)
			}
		}
	}
}
