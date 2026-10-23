"""Independent descriptor eligibility regressions; no capture/model files or endpoint."""
import importlib.util,math,tempfile,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('eg_report',Path(__file__).with_name('eg-report.py'));eg=importlib.util.module_from_spec(spec);spec.loader.exec_module(eg)
class Eligibility(unittest.TestCase):
 def test_attack_resolution(self):
  for d,qualified in [(19.999,False),(20,True),(20.001,True)]:
   r=eg.eligible_duration({'state':'measured','attack':{'duration_ms':d}},None,True,False,True,True,'attack',10)
   self.assertEqual(r['duration_qualified'],qualified);self.assertEqual(r['original_windowed_feature_duration_ms'],d)
   self.assertEqual(r['attack_resolution_limited'],not qualified)
 def test_attack_quality_dimensions(self):
  for silent,absolute,conditioned in [(False,True,True),(True,False,True),(True,True,False)]:
   r=eg.eligible_duration({'state':'measured','attack':{'duration_ms':30}},None,silent,False,absolute,conditioned,'attack',10)
   self.assertFalse(r['duration_qualified']);self.assertIsNone(r['qualified_duration_ms'])
 def test_fall_states(self):
  for state in ['held_in_window','window_limited','incomplete','no_initial_signal']:
   r=eg.eligible_duration({}, {'state':state},False,True,False,True,'live',10);self.assertFalse(r['duration_qualified'])
  r=eg.eligible_duration({}, {'state':'measured','fall':{'duration_ms':40}},False,True,False,True,'live',10);self.assertTrue(r['duration_qualified'])
 def test_nonfinite_and_boolean_duration(self):
  for value in [None,True,float('nan'),float('inf')]:
   r=eg.eligible_duration({'state':'measured','attack':{'duration_ms':value}},None,True,False,True,True,'attack',10);self.assertFalse(r['duration_qualified'])
 def test_output_ownership(self):
  with tempfile.TemporaryDirectory()as d:
   p=Path(d)/'already.json';p.write_bytes(b'preserve')
   with self.assertRaises(FileExistsError):eg.write(p,{'new':True})
   self.assertEqual(p.read_bytes(),b'preserve')
 def test_gate_values(self):
  self.assertTrue(eg.gates({'raw':True}));self.assertFalse(eg.gates({}));self.assertFalse(eg.gates({'raw':1}));self.assertFalse(eg.gates({'feature':False}))
 def test_ranges(self):
  self.assertEqual(eg.summarize_range([3,1,2]),[1,3]);self.assertIsNone(eg.summarize_range([]))
class DescriptorCells(unittest.TestCase):
 def dataset(self,root,duration=52):
  import json
  g={'name':'independent-descriptor-geometry','window':8,'hop':2,'window_ms':10,'frames':128,'stride':1,'recorded_increment':100000}
  cases=[{'name':'independent-'+str(i),'initial_keyon':True,'group':'C-independent','d1r':12,'d2r':0,'ar':31,'geometry':{'name':g['name']}}for i in range(23)]
  env={'state':'no_pretrigger','samples':128,'window_samples':8,'hop_samples':2,'phase_increment_20bit':100000,'plateau_amplitude':8169.5}
  def decay(t):return{'state':'measured','fall':{'duration_ms':t},'initial_plateau_quality_evaluated':True,'initial_amplitude':8169.5,'initial_relative_span':0,'initial_relative_carrier_rms':0,'final_amplitude':0}
  phys={'stage':'main','records':139,'raw_gates':{'raw':True},'conditioning_gates':{'conditioning':True},'feature_gates':{'report_present':True},'issues':[],'conditioning_issues':[],'feature_observations':[],'raw_records':[]}
  model={'summary':{'records':50,'output_columns':100,'all_raw_integrity':True,'all_actual_write_horizons':True,'attack_duration_qualified':0},'records':[]}
  for c in cases:
   for rep in range(3):
    phys['raw_records'].append({'kind':'target','name':c['name'],'repetition':rep,'channels':[{'latch':l,'whole':{'min':-8170,'max':8170}}for l in range(2)]})
    for latch in range(2):
     r={'profile':'live','whole_original_trace':True,'geometry':g,'initial_support_samples':14,'observation':{'envelope':env,'decay':decay(30+rep)},'initial_support_bipolar':True,'initial_support_exactzero':False,'plateau_quality_evaluated':True,'absolute_plateau_within_one_percent':True}
     phys['feature_observations'].append({'name':c['name'],'repetition':rep,'latch':latch,'profile':'live','result':r,'conditioning_qualified':True,'exitcode':0,'input_csv_sha256':'input','report_sha256':'report','curve_sha256':'curve'})
   for mo in ['jt51','opm']:
    col={'envelope':env,'decay':decay(duration),'prefix_first_four_support':{'count':14,'exact_zero':False,'bipolar':True},'first_four_silent':False,'first_four_stable_full_level':True,'attack_absolute_plateau_qualified':False,'raw':{'min':-8170,'max':8170},'envelope_json_sha256':'env','curve_sha256':'curve','attack_duration_qualified':False,'fall_duration_qualified':True}
    model['records'].append({'name':c['name'],'model':mo,'geometry':g['name'],'frames':128,'stride':1,'horizon_qualified':True,'csv_sha256':'csv','columns':{'left':col,'right':col}})
  values={'geometries':[g],'physical_audit':phys,'model_audit':model,'model_exceptions':{'exception_output_observations':24,'records':[{'unresolved':True}for _ in range(24)]}}
  m={'input_pins':{},'physical_review':'unused','model_review':'unused'}
  for name,value in values.items():
   p=root/(name+'.json');p.write_text(json.dumps(value));m[name]=str(p)
  # aggregate() writes review provenance, so prepare descriptors explicitly as fixture labels, not real ROOT approval.
  for k in ['physical_review','model_review']:
   p=root/(k+'.json');p.write_text('{"synthetic_test_fixture_not_ROOT_approval":true}');m[k]=str(p)
  return m,cases,phys
 def test_exact_interval_edges_and_retained_exceptions(self):
  import contextlib,io,json
  for duration,inside in [(10,True),(52,True),(52.0001,False)]:
   with tempfile.TemporaryDirectory()as d:
    root=Path(d);m,cases,_=self.dataset(root,duration)
    with contextlib.redirect_stdout(io.StringIO()):eg.aggregate(root/'out',m,cases)
    rows=json.loads((root/'out/model-comparisons.json').read_text());self.assertEqual(len(rows),92);self.assertTrue(all(r['within_declared_two_window_bound']is inside for r in rows));self.assertEqual(len(json.loads((root/'out/model-exceptions-verbatim.json').read_text())['records']),24)
 def test_missing_duplicate_cells_rejected(self):
  import json
  for duplicate in [False,True]:
   with tempfile.TemporaryDirectory()as d:
    root=Path(d);m,cases,physical=self.dataset(root)
    if duplicate:physical['feature_observations'][-1]=physical['feature_observations'][0]
    else:physical['feature_observations'].pop()
    Path(m['physical_audit']).write_text(json.dumps(physical))
    with self.assertRaises(ValueError):eg.aggregate(root/'out',m,cases)
    self.assertFalse((root/'out').exists())
if __name__=='__main__':unittest.main()
