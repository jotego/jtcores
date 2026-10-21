package main
import("encoding/json";"math";"os";"path/filepath";"testing")
func TestEGCSVStrictness(t *testing.T){
 for _,raw:=range []string{"sample,linear\n1,0\n","sample,linear\n0,NaN\n","sample,linear\n0,1.5\n","sample,raw16_hex,linear\n0,XYZ,0\n","wrong,linear\n0,0\n"}{if _,e:=physical_read_csv([]byte(raw));e==nil{t.Fatalf("invalid CSV accepted %q",raw)}}
 for _,raw:=range []string{"sample,linear\n0,0\n1,-1\n","sample,raw16_hex,linear\n0,0000,0\n1,ffff,-1\n"}{v,e:=physical_read_csv([]byte(raw));if e!=nil||len(v)!=2||v[1]!=-1{t.Fatalf("valid CSV %v %v",v,e)}}
}
func TestEGHeldAndSilent(t *testing.T){
 var gs []geometry;if e:=json.Unmarshal([]byte(eg_geometry_json),&gs);e!=nil{t.Fatal(e)}
 for _,g:=range gs{t.Run(g.Name,func(t *testing.T){v:=make([]float64,g.Frames);for n:=range v{native:=n*g.Stride;v[n]=math.Round(8169.5*math.Sin(2*math.Pi*float64(native)*g.Native/(1<<20)))-8};r,e:=measure_envelope(v,g.Recorded,g.Fs,g.Window,g.Hop);if e!=nil||r.State!="no_pretrigger"||math.Abs(r.Plateau/8169.5-1)>.01{t.Fatalf("held %v %v",r,e)};z:=make([]float64,g.Frames);r,e=measure_envelope(z,g.Recorded,g.Fs,g.Window,g.Hop);if e!=nil||r.State!="no_signal"{t.Fatal("silent accepted as signal")}})}
}
func TestEGRejectNonfiniteAndTruncation(t *testing.T){v:=make([]float64,32);v[0]=math.NaN();if _,e:=measure_envelope(v,41568,55937.5,64,8);e==nil{t.Fatal("short/nonfinite accepted")}}
func TestEGCurveExclusive(t *testing.T){p:=filepath.Join(t.TempDir(),"curve.csv");if e:=os.WriteFile(p,[]byte("preserve"),0600);e!=nil{t.Fatal(e)};if e:=write_envelope(p,[]envelope_point{{}});e==nil{t.Fatal("curve overwritten")};v,_:=os.ReadFile(p);if string(v)!="preserve"{t.Fatal("existing curve changed")}}
// Test-only native-forward sources have analytic truth; runtime has no waveform generator.
func TestEGAnalyticAttackFall(t *testing.T){
 g:=geometry{Name:"native-kc3e-mul8",Native:39232,Recorded:39232,Stride:1,Frames:16384,Window:64,Hop:8,Fs:55937.5};h:=float64(g.Frames-2*g.Window);onset:=float64(2*g.Window)
 for _,fall:=range []bool{false,true}{v:=make([]float64,g.Frames);for n:=range v{q:=float64(n)-onset;a:=8169.5;if fall{if q>=0{a*=math.Exp(-q/(h/4))}}else{a*=math.Max(0,math.Min(1,q/(h/8)))};v[n]=16*math.Floor(a*math.Sin(2*math.Pi*float64(n)*g.Native/(1<<20))/16)};r,e:=measure_envelope(v,g.Recorded,g.Fs,g.Window,g.Hop);if e!=nil{t.Fatal(e)};if fall{d,e:=measure_decay(decay_points(r),g.Fs,g.Window,8169.5,false);if e!=nil||d.State!="measured"||d.Feature==nil{t.Fatalf("fall unresolved %+v %v",d,e)};if math.Abs(d.Feature.Duration*g.Fs/1000-h/4*math.Ln2)>float64(g.Window){t.Fatal("fall exceeds original one-window bound")}}else{if r.State!="measured"||r.Attack==nil{t.Fatalf("attack unresolved %+v",r)};if math.Abs(r.Attack.Duration*g.Fs/1000-.8*h/8)>float64(g.Window){t.Fatal("attack exceeds original one-window bound")}}}
}
