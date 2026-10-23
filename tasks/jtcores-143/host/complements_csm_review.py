"""Public PCM complements CSM review; no acquisition or new estimator."""
from pathlib import Path
import argparse,csv,hashlib,json,subprocess,sys

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def need(x,m):
 if not x:raise ValueError(m)
def read_pcm(path,column):
 with path.open(newline='')as f:
  reader=csv.reader(f);header=next(reader,None);need(header is not None and len(header)==len(set(header)) and 'sample'in header and column in header,'unique sample/signal header required');s=header.index('sample');v=header.index(column);values=[]
  for i,row in enumerate(reader):
   need(len(row)==len(header),'CSV width');need(row[s]==str(i),'consecutive integer sample');token=row[v];need(token and token.lstrip('-').isdigit(),'integer PCM required');value=int(token);need(-32768<=value<=32767,'signed16 PCM required');values.append(value)
 need(len(values)==16384,'exact16384 native rows required');return values
def historical_manual_guard(fit,z):
 # Original route-controls guard; full held C2 LEFT trace, no new expected phase.
 f=fit['fit'];fg=f['rounded_increment']==65984 and f['phase_rms_radians']<.01 and min(z)<0<max(z);mid=(min(z)+max(z))/2;cross=[];increment=None;cg=False
 for j in range(1,len(z)):
  if z[j-1]<mid<=z[j]:cross.append(j-1+(mid-z[j-1])/(z[j]-z[j-1]))
 if len(cross)>8:increment=(1<<20)*(len(cross)-1)/(cross[-1]-cross[0]);cg=round(increment)==65984
 return{'free_carrier_guard':fg,'independent_crossing_guard':cg,'independent_crossing_increment':increment,'rising_crossings':len(cross),'qualified':fg and cg,'own_expected_increment':65984,'historical_guard_unchanged':True}

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('input',type=Path);parser.add_argument('--profile',choices=['C2','C3','C4'],required=True);parser.add_argument('--latch',type=int,choices=[0,1],required=True);parser.add_argument('--column',default='linear');parser.add_argument('--start-sample',type=int,required=True);parser.add_argument('--energy-exe',type=Path,required=True);parser.add_argument('--phase-exe',type=Path,required=True);parser.add_argument('--output',type=Path,required=True);parser.add_argument('--check-only',action='store_true');a=parser.parse_args();a.input=a.input.resolve();a.output=a.output.resolve();need(not a.output.exists(),'fresh exclusive output required');need(512<=a.start_sample<=16384-256,'explicit native post bound');z=read_pcm(a.input,a.column)
 if a.check_only:print(json.dumps({'state':'structural_only_no_numerical_run','input_sha256':sha(a.input),'samples':len(z)}));return
 need(a.energy_exe.is_file()and a.phase_exe.is_file(),'explicit existing primitive executables required');a.output.mkdir();report={'state':'original_feature_observations_retained_no_modelagreement_gate','profile':a.profile,'latch':a.latch,'input':str(a.input),'input_sha256':sha(a.input),'column':a.column,'start_sample':a.start_sample,'commands':[],'whole_exactzero':all(x==0 for x in z),'prefix512_bipolar':min(z[:512])<0<max(z[:512]),'model_agreement_gate':False};cmd=[str(a.energy_exe.resolve()),'-column',a.column,'-start-sample',str(a.start_sample),str(a.input)];p=subprocess.run(cmd,capture_output=True,text=True,timeout=120);report['commands'].append({'command':cmd,'exitcode':p.returncode,'stdout':p.stdout,'stderr':p.stderr});report['energy_execution_exitcode']=p.returncode
 if p.returncode==0:
  energy=json.loads(p.stdout);need(energy['input_sha256']==sha(a.input),'primitive input hash');report['energy']=energy
 if a.profile=='C2'and a.latch==0:
  cmd=[str(a.phase_exe.resolve()),'-column',a.column,str(a.input)];p=subprocess.run(cmd,capture_output=True,text=True,timeout=60);report['commands'].append({'command':cmd,'exitcode':p.returncode,'stdout':p.stdout,'stderr':p.stderr});report['phase_execution_exitcode']=p.returncode
  if p.returncode==0:
   fit=json.loads(p.stdout);need(fit['sha256']==sha(a.input),'phase input hash');report['manual_phase']=fit;report['manual_guard']=historical_manual_guard(fit,z);report['C2_control_qualified']=report['manual_guard']['qualified']and report['prefix512_bipolar']
  else:report['C2_control_qualified']=False
 elif a.profile=='C2':report['C2_control_qualified']=report['whole_exactzero']
 with(a.output/'report.json').open('x')as f:json.dump(report,f,indent=2,allow_nan=False);f.write('\n')
 print(json.dumps(report,indent=2,allow_nan=False))
if __name__=='__main__':
 try:main()
 except(Exception)as e:print(str(e),file=sys.stderr);sys.exit(1)
