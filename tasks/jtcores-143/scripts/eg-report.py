"""Format frozen EG descriptors only; no scorer/model/HW calls and no raw PCM reads."""
from pathlib import Path
import argparse,collections,hashlib,json,math,sys
sys.dont_write_bytecode=True
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def need(x,m):
 if not x:raise ValueError(m)
def read(p):return json.loads(Path(p).read_bytes())
def write(p,x):
 with Path(p).open('x')as f:json.dump(x,f,indent=2,allow_nan=False);f.write('\n')
def gates(x):return isinstance(x,dict)and bool(x)and all(v is True for v in x.values())
def explicit_inputs(a):
 paths={k:Path(getattr(a,k)).resolve()for k in ['catalog','geometries','physical_audit','model_audit','model_exceptions','physical_review','model_review']}
 need(len(set(paths.values()))==7,'seven distinct descriptor/catalog/review inputs')
 pins={str(p):sha(p)for p in paths.values()};m={k:str(p)for k,p in paths.items()};m['input_pins']=pins
 cases=read(m['catalog']);need(isinstance(cases,list)and len(cases)==23 and len({c['name']for c in cases})==23,'exact23 unique main profiles')
 normalized=[{k:v for k,v in c.items()if k not in ['init','event']}for c in cases]
 need(hashlib.sha256(json.dumps(normalized,sort_keys=True,separators=(',',':'),allow_nan=False).encode()).hexdigest()=='adbdaf4975b07ed893bb0f7c153ed493567ef9ab10cbf8b72db43a344ae21c76','exact main catalog metadata except caller payload paths')
 need(sha(m['geometries'])=='0c2a75b519f377da97295ee10011961e7f1470d7f6ae38ea3345d6f094a4b42c','exact frozen five-geometry preset')
 physical_review=read(m['physical_review']);model_review=read(m['model_review'])
 need(physical_review.get('state')=='ROOT_REVIEWED_EG_MAIN139_RAW_CONDITIONING_ORIGINAL_REPORTS'and physical_review.get('authorized_by')=='/root'and physical_review.get('audit_sha256')==sha(m['physical_audit'])and physical_review.get('actual_terminal_exitcode')==0,'physical ROOT review must bind this actual audit')
 reviewed_files=model_review.get('files',{})
 need(model_review.get('state')=='ROOT_REVIEWED_EG50_MODELS_RAW_GEOMETRY_FEATURE_EXCEPTIONS_RETAINED'and sha(m['model_audit'])in reviewed_files.values()and sha(m['model_exceptions'])in reviewed_files.values(),'model ROOT review must bind these actual descriptors/exceptions')
 return m,cases
def finite(v):return isinstance(v,(int,float))and not isinstance(v,bool)and math.isfinite(v)
def eligible_duration(env,decay,silent,stable,absolute,conditioned,profile,window_ms):
 reasons=[];feature=None;duration=None
 if not conditioned:reasons.append('conditioning_unqualified')
 if profile=='attack':
  if not silent:reasons.append('initial_support_not_exact_silent')
  if not absolute:reasons.append('absolute_clean_plateau_unqualified')
  if env.get('state')!='measured'or not env.get('attack'):reasons.append('original_attack_unresolved')
  feature=env.get('attack')
 else:
  if not stable:reasons.append('initial_four_full_level_bipolar_unqualified')
  if not decay or decay.get('state')!='measured'or not decay.get('fall'):reasons.append('original_fall_unresolved_or_window_limited')
  feature=(decay or{}).get('fall')
 if feature and finite(feature.get('duration_ms')):
  duration=feature['duration_ms']
  if profile=='attack'and duration<2*window_ms:reasons.append('window_response_only_below_two_windows')
 elif not reasons:reasons.append('duration_absent_or_nonfinite')
 return{'duration_qualified':not reasons,'qualified_duration_ms':duration if not reasons else None,'original_numeric_feature':feature,'original_windowed_feature_duration_ms':duration,'attack_resolution_limited':profile=='attack'and duration is not None and duration<2*window_ms,'duration_interpretation':'window_response_only'if profile=='attack'and duration is not None and duration<2*window_ms else'original_feature_subject_to_eligibility','withheld_reasons':reasons}
def physical_observation(o,raw,case,geometry):
 r=o['result'];env=r['observation']['envelope'];d=r['observation'].get('decay');profile='live'if case['initial_keyon']else'attack';support=geometry['window']+3*geometry['hop']
 need(o['profile']==profile and r['profile']==profile and r['whole_original_trace']is True and r['geometry']['name']==geometry['name']and r['initial_support_samples']==support,'physical descriptor scope/geometry')
 need(env['samples']==geometry['frames']and env['window_samples']==geometry['window']and env['hop_samples']==geometry['hop']and env['phase_increment_20bit']==geometry['recorded_increment'],'physical envelope geometry')
 stable=bool(d and d.get('initial_plateau_quality_evaluated')is True and r['initial_support_bipolar']is True and d.get('initial_amplitude',0)>=32 and abs(d['initial_amplitude']/8169.5-1)<=.01 and d['initial_relative_span']<=.01 and d['initial_relative_carrier_rms']<=.02)
 absolute=r['plateau_quality_evaluated']is True and r['absolute_plateau_within_one_percent']is True
 item={'source':'physical','name':o['name'],'repetition':o['repetition'],'latch':o['latch'],'profile':profile,'geometry':geometry['name'],'window_ms':geometry['window_ms'],'raw':raw,'initial_support_samples':support,'initial_support_exactzero':r['initial_support_exactzero'],'initial_support_bipolar':r['initial_support_bipolar'],'initial_four_stable_full_level':stable,'absolute_plateau_qualified':absolute,'conditioning_qualified':o['conditioning_qualified'],'envelope':env,'decay':d,'input_csv_sha256':o['input_csv_sha256'],'feature_report_sha256':o['report_sha256'],'curve_sha256':o['curve_sha256']}
 item.update(eligible_duration(env,d,r['initial_support_exactzero'],stable,absolute,o['conditioning_qualified'],profile,geometry['window_ms']));return item
def model_observation(record,column,case,geometry):
 d=record['columns'][column];env=d['envelope'];de=d.get('decay');profile='live'if case['initial_keyon']else'attack';support=geometry['window']+3*geometry['hop'];prefix=d['prefix_first_four_support']
 need(record['geometry']==geometry['name']and record['frames']==geometry['frames']and record['stride']==geometry['stride']and prefix['count']==support,'model descriptor geometry/support')
 silent=prefix['exact_zero']is True and d['first_four_silent']is True
 stable=d['first_four_stable_full_level']is True and prefix['bipolar']is True and bool(de and de.get('initial_plateau_quality_evaluated')is True)
 absolute=d['attack_absolute_plateau_qualified']is True and env.get('state')=='measured'
 item={'source':'model','name':record['name'],'model':record['model'],'column':column,'latch':0 if column=='left'else 1,'profile':profile,'geometry':geometry['name'],'window_ms':geometry['window_ms'],'raw':d['raw'],'initial_support_samples':support,'initial_support_exactzero':prefix['exact_zero'],'initial_support_bipolar':prefix['bipolar'],'initial_four_stable_full_level':stable,'absolute_plateau_qualified':absolute,'conditioning_qualified':record['horizon_qualified'],'envelope':env,'decay':de,'input_csv_sha256':record['csv_sha256'],'feature_report_sha256':d['envelope_json_sha256'],'curve_sha256':d['curve_sha256'],'original_audit_attack_duration_qualified':d['attack_duration_qualified'],'original_audit_fall_duration_qualified':d.get('fall_duration_qualified')}
 item.update(eligible_duration(env,de,silent,stable,absolute,record['horizon_qualified'],profile,geometry['window_ms']));return item
def summarize_range(values):
 return[min(values),max(values)]if values else None
def aggregate(output,m,cases):
 physical=read(m['physical_audit'])
 need(physical['stage']=='main'and physical['records']==139 and gates(physical['raw_gates'])and gates(physical['conditioning_gates'])and gates(physical['feature_gates'])and physical['issues']==physical['conditioning_issues']==[],'actual Main139 raw/conditioning/report integrity reviewed')
 need(len(physical['feature_observations'])==138,'physical138 reports');model=read(m['model_audit']);exceptions=read(m['model_exceptions'])
 need(model['summary']['records']==50 and model['summary']['output_columns']==100 and model['summary']['all_raw_integrity']is True and model['summary']['all_actual_write_horizons']is True,'actual50 model raw/geometry descriptor audit')
 need(exceptions['exception_output_observations']==24 and len(exceptions['records'])==24,'all24 model exceptions retained')
 names=[c['name']for c in cases];byname={c['name']:c for c in cases};gs={g['name']:g for g in read(m['geometries'])};prows=[];mrows=[];raw={}
 for r in physical['raw_records']:
  if r['kind']=='target':
   for channel in r['channels']:raw[(r['name'],r['repetition'],channel['latch'])]=channel['whole']
 for o in physical['feature_observations']:
  need(o['name']in byname and o['exitcode']==0,'original physical feature report present');c=byname[o['name']];prows.append(physical_observation(o,raw[(o['name'],o['repetition'],o['latch'])],c,gs[c['geometry']['name']]))
 expected={(n,r,l)for n in names for r in range(3)for l in range(2)};need(len(prows)==138 and{(r['name'],r['repetition'],r['latch'])for r in prows}==expected,'exact138 unique public physical cells')
 for record in model['records']:
  if record['name']in byname:
   c=byname[record['name']]
   for column in ['left','right']:mrows.append(model_observation(record,column,c,gs[c['geometry']['name']]))
 need(len(mrows)==92 and{(r['name'],r['model'],r['latch'])for r in mrows}=={(n,mo,l)for n in names for mo in ['jt51','opm']for l in range(2)},'exact92 public model cells')
 ranges=[];comparisons=[]
 for name in names:
  for latch in [0,1]:
   reps=sorted((r for r in prows if r['name']==name and r['latch']==latch),key=lambda r:r['repetition']);eligible=[r['qualified_duration_ms']for r in reps if r['duration_qualified']];allthree=len(eligible)==3
   amps=[r['envelope']['plateau_amplitude']for r in reps];initial=[r['decay']['initial_amplitude']for r in reps if r['decay']];tail=[r['decay']['final_amplitude']for r in reps if r['decay']]
   rg={'name':name,'latch':latch,'repetitions':[r['repetition']for r in reps],'all_three_durations_qualified':allthree,'qualified_duration_count':len(eligible),'qualified_subset_duration_range_ms':summarize_range(eligible),'all_three_duration_range_ms':summarize_range(eligible)if allthree else None,'plateau_amplitude_range':summarize_range(amps),'initial_amplitude_range':summarize_range(initial),'final_amplitude_range':summarize_range(tail),'envelope_states':[r['envelope']['state']for r in reps],'decay_states':[(r['decay']or{}).get('state')for r in reps],'window_ms':reps[0]['window_ms']};ranges.append(rg)
   for mo in ['jt51','opm']:
    mr=next(r for r in mrows if r['name']==name and r['model']==mo and r['latch']==latch);reason=[]
    if not allthree:reason.append('not_all_three_physical_durations_qualified')
    if not mr['duration_qualified']:reason.append('model_duration_unqualified')
    row={'name':name,'latch':latch,'model':mo,'physical_triplicate_range_ms':rg['all_three_duration_range_ms'],'model_qualified_duration_ms':mr['qualified_duration_ms'],'model_original_numeric_feature':mr['original_numeric_feature'],'physical_window_ms':rg['window_ms'],'model_window_ms':mr['window_ms'],'comparison_withheld_reasons':reason,'within_declared_two_window_bound':None,'model_report_sha256':mr['feature_report_sha256']}
    if not reason:
     guard=rg['window_ms']+mr['window_ms'];lo,hi=rg['all_three_duration_range_ms'];row.update(declared_sum_of_window_bounds_ms=guard,expanded_triplicate_interval_ms=[lo-guard,hi+guard],within_declared_two_window_bound=lo-guard<=mr['qualified_duration_ms']<=hi+guard)
    comparisons.append(row)
 literal=[]
 for r in prows+mrows:
  c=byname[r['name']];is_ar=c['group']=='B-attack-zero-positive';is_zero_live=c['initial_keyon']and(c['d1r']==0 if c['group'].startswith('C-')else c['d2r']==0)
  if is_ar or is_zero_live:literal.append({'name':r['name'],'source':r['source'],'repetition':r.get('repetition'),'model':r.get('model'),'latch':r['latch'],'kind':'AR0'if is_ar and c['ar']==0 else'AR1'if is_ar else'zero_rate_live','raw':r['raw'],'envelope_state':r['envelope']['state'],'decay_state':(r['decay']or{}).get('state'),'initial_four_stable_full_level':r['initial_four_stable_full_level'],'duration_qualified':r['duration_qualified'],'original_numeric_feature':r['original_numeric_feature']})
 need(len(ranges)==46 and len(comparisons)==92,'finite output counts');output=Path(output).resolve();need(not output.exists(),'fresh exclusive aggregation directory');output.mkdir()
 write(output/'method-before-aggregation.json',{'source_sha256':sha(__file__),'explicit_input_sha256':m['input_pins'],'ROOT_reviews':{k:{'path':m[k],'sha256':sha(m[k])}for k in ['physical_review','model_review']},'no_new_fitting_or_extraction':True})
 write(output/'observations.json',{'physical':prows,'models':mrows});write(output/'physical-triplicate-ranges.json',ranges);write(output/'model-comparisons.json',comparisons);write(output/'literal-state-observations.json',literal);write(output/'model-exceptions-verbatim.json',exceptions)
 summary={'state':'finite_existing_descriptor_aggregation_complete_all_states_retained','physical_observations':len(prows),'model_observations':len(mrows),'triplicate_cells':len(ranges),'comparison_rows':len(comparisons),'comparisons_eligible':sum(r['within_declared_two_window_bound']is not None for r in comparisons),'comparisons_within_bound':sum(r['within_declared_two_window_bound']is True for r in comparisons),'comparisons_outside_bound':sum(r['within_declared_two_window_bound']is False for r in comparisons),'comparisons_withheld':sum(r['within_declared_two_window_bound']is None for r in comparisons),'original_model_exceptions_retained':24,'original_model_audit_attack_duration_qualified':model['summary']['attack_duration_qualified'],'physical_attack_window_response_only':sum(r['attack_resolution_limited']for r in prows),'model_attack_window_response_only':sum(r['attack_resolution_limited']for r in mrows),'physical_envelope_states':dict(collections.Counter(r['envelope']['state']for r in prows)),'physical_decay_states':dict(collections.Counter(r['decay']['state']for r in prows if r['decay'])),'model_envelope_states':dict(collections.Counter(r['envelope']['state']for r in mrows)),'model_decay_states':dict(collections.Counter(r['decay']['state']for r in mrows if r['decay'])),'no_chip_conformance_or_exact_phase_gain_DC_correction_claim':True};write(output/'summary.json',summary)
 inputs=dict(m['input_pins']);inputs[str(Path(__file__).resolve())]=sha(__file__)
 write(output/'provenance.json',{'inputs':inputs,'outputs':{str(q):sha(q)for q in output.iterdir()if q.is_file()}});print(json.dumps(summary,indent=2))
def main():
 p=argparse.ArgumentParser(description=__doc__)
 for k in ['catalog','geometries','physical-audit','model-audit','model-exceptions','physical-review','model-review','output']:p.add_argument('--'+k,type=Path,required=True)
 a=p.parse_args();need(not a.output.resolve().exists(),'fresh output required');m,cases=explicit_inputs(a);aggregate(a.output.resolve(),m,cases)
if __name__=='__main__':main()
