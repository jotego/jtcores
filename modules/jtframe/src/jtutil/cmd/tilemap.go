/*  This file is part of JTCORES.
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

package cmd

import (
	"fmt"
	"crypto/sha1"
	"encoding/hex"
	"image"
	"image/color"
	"image/png"
	"math"
	"os"

	"github.com/spf13/cobra"
)

var tilemap_args struct{
	name   string
	array  bool
	wround bool
}

// tilemapCmd represents the tilemap command
var tilemapCmd = &cobra.Command{
	Use:   "tilemap",
	Short: "Converts a PNG image to a tile map",
	Long: `Creates two output files: tilemap.hex and tiledata.hex`,
	Args: cobra.MinimumNArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		png2tilemap(args[0], tilemap_args.name )
	},
}

func init() {
	rootCmd.AddCommand(tilemapCmd)

	// Here you will define your flags and configuration settings.

	// Cobra supports Persistent Flags which will work for this command
	// and all subcommands, e.g.:
	// tilemapCmd.PersistentFlags().String("foo", "", "A help for foo")

	// Cobra supports local flags which will only run when this command
	// is called directly, e.g.:
	// tilemapCmd.Flags().BoolP("toggle", "t", false, "Help message for toggle")
	tilemapCmd.Flags().StringVarP( &tilemap_args.name, "name", "n", "tile", "Prefix for output file names")
	tilemapCmd.Flags().BoolVarP( &tilemap_args.array,  "array", "a", false, "Output System Verilog arrays instead of a .hex file")
	tilemapCmd.Flags().BoolVarP( &tilemap_args.wround, "width", "w", true, "Round up map width to nearest power of 2")
}

func png2tilemap( fname, ofname string ) {
	f, e := os.Open(fname)
	if e != nil {
		fmt.Println(e)
		os.Exit(1)
	}
	defer f.Close()
	img, e := png.Decode(f)
	if e != nil {
		fmt.Println(e)
		os.Exit(1)
	}
	if img.Bounds().Dx() % 8 != 0 || img.Bounds().Dy()%8!=0 {
		fmt.Println("The image width and height must be a multiple of 8")
		os.Exit(1)
	}

	uniqueBlocks := make(map[string]image.Image)
	blockIds := make(map[string]int)
	tiles := make([]image.Image,0)
	tilemap := make([]int,0)
	id := 0
	w := 0
	map_width  := img.Bounds().Dx()>>3
	map_wround := int( math.Ceil(math.Log2(float64(map_width))) )

    for y := 0; y < img.Bounds().Dy(); y += 8 {
        for x := 0; x < img.Bounds().Dx(); x += 8 {
            // Create a sub-image (block)
            block := img.(interface {
                SubImage(r image.Rectangle) image.Image
            }).SubImage(image.Rect(x, y, x+8, y+8))

            // Create a hash for the block
            hash := hashImage(block)
            // fmt.Println(x,y,hash)

            // If the block is unique, store it
            if _, exists := uniqueBlocks[hash]; !exists {
                uniqueBlocks[hash] = block
		    	blockIds[hash] = id
		    	tiles = append( tiles, block )
		    	id++
            }
            tilemap=append(tilemap,blockIds[hash])
            w++
            // round up the map width to the nearest power of 2
            if w==map_width && tilemap_args.wround {
            	for w < (1<<map_wround) {
            		tilemap=append(tilemap,0)
            		w++
            	}
            	w=0
            }
        }
    }

    pal := makePal(uniqueBlocks)
    bpp := int(math.Ceil(math.Log2(float64(len(pal)))))
    tileData := packTiles( dumpTiles( tiles, pal ), bpp )
    if tilemap_args.array {
    	arraydump( ofname+"map.sv", tilemap, 1 )
	    arraydump( ofname+"data.sv", tileData, bpp )
    } else {
	    hexdump( ofname+"map.hex", tilemap, 1)
	    hexdump( ofname+"data.hex", tileData, bpp )
    }
    if verbose {
    	fmt.Printf("Total unique 8x8 tiles: %d\n", len(uniqueBlocks))
    	fmt.Println("Total",len(pal),"colors")
    }
}

func packTiles( tiles []int, bpp int ) []byte {
	if bpp==0 || bpp!=2 || 8%bpp!=0 {
		fmt.Println("Unsupported bpp encoding")
		os.Exit(1)
	}

	pack := 8/bpp
	data := make([]byte,len(tiles)/pack)
	for k, _ := range data {
		data[k]=0
	}
	sh := bpp-1
	for i,each := range tiles {
		ish := (i>>3) << sh
		imod := (^i)&7
		for j:=0; j<bpp; j++ {
			data[ ish+j ] |= byte(((each>>j)&1) << imod)
		}
	}
	return data
}

func dumpTiles( tiles []image.Image, pal map[int]int ) []int {
	intdump := make([]int,len(tiles)<<6)
	k:=0
	for _,each := range tiles {
		r := each.Bounds()
	    for y := r.Min.Y; y < r.Max.Y; y ++ {
	        for x := r.Min.X; x < r.Max.X; x ++ {
	        	rgb := rgbPack(each.At(x,y))
	        	intdump[k] = pal[rgb]
	        	k++
	        }
        }
	}
	return intdump
}

func rgbPack( c color.Color ) int {
	r,g,b,_ := c.RGBA()
	return ((int(r)&0xff)<<16) | ((int(g)&0xff)<<8) | (int(b)&0xff)
}

func makePal( tiles map[string]image.Image ) map[int]int {
	pal := make(map[int]int)
	k := 0
	for _, each := range tiles {
		r := each.Bounds()
	    for y := r.Min.Y; y < r.Max.Y; y ++ {
	        for x := r.Min.X; x < r.Max.X; x ++ {
	        	rgb := rgbPack(each.At(x,y))
	        	if _, found := pal[rgb]; !found {
	        		pal[rgb] = k
	        		k++
	        	}
	        }
	    }
	}
	return pal
}

// input data is truncated to 8 bits
func hexdump[E int|byte]( fname string, data []E, bpp int ) {
	f, e := os.Create(fname)
	if e!=nil {
		fmt.Println(e)
		os.Exit(1)
	}
	defer f.Close()
	format := fmt.Sprintf("%%0%dX\n",bpp<<1)
	for k:=0; k<len(data); k+=bpp {
		var v8 int
		for j:=0; j<bpp; j++ {
			v:=int(data[k+j])
			if v>255 {
				fmt.Println("Error: only 1-byte numbers allowed")
				os.Exit(1)
			}
			v8 |= v<<(j<<3)
		}
		fmt.Fprintf(f,format,v8)
	}
	// the dump length is always extended to match a power of 2
	// in order to prevent Quartus warnings when loading the data into a BRAM
	rounded := 1<<int(math.Ceil(math.Log2(float64(len(data)))))
	for k:=len(data); k <rounded; k+=bpp {
		fmt.Fprintf(f,format,0)
	}
}

func arraydump[E int|byte]( fname string, data []E, bpp int ) {
	f, e := os.Create(fname)
	if e!=nil {
		fmt.Println(e)
		os.Exit(1)
	}
	defer f.Close()
	fmt.Fprintf(f,"'{\n")
	dw := bpp<<3
	format := fmt.Sprintf("%%d'h%%0%dX",bpp<<1)
	for k:=0; k<len(data); k+=bpp {
		if k!=0 {
			fmt.Fprintf(f,", ")
			if (k&0xf) == 0 { fmt.Fprintln(f)}
		}
		var v8 int
		for j:=0; j<bpp; j++ {
			v:=int(data[k+j])
			if v>255 {
				fmt.Println("Error: only 1-byte numbers allowed")
				os.Exit(1)
			}
			v8 |= v<<(j<<3)
		}
		fmt.Fprintf(f,format,dw,v8)
	}
	fmt.Fprintf(f,"  };\n")
}


func hashImage(img image.Image) string {
    // Convert image to RGBA
    bounds := img.Bounds()
    rgba := image.NewRGBA(image.Rect(0, 0, bounds.Dx(), bounds.Dy()))
    y0:=0
    for y := bounds.Min.Y; y < bounds.Max.Y; y++ {
    	x0:=0
        for x := bounds.Min.X; x < bounds.Max.X; x++ {
            rgba.Set(x0, y0, img.At(x, y))
            x0++
        }
        y0++
    }

    // Hash the RGBA values
    hash := sha1.New()
    hash.Write(rgba.Pix)
    return hex.EncodeToString(hash.Sum(nil))
}