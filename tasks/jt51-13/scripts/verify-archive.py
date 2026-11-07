#!/usr/bin/env python3
"""Stream-decompress and verify every archived member against the original SHA256 inventory."""
from pathlib import Path
import argparse,json,hashlib,subprocess,tarfile,time
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('archive',nargs='?',type=Path,default=Path(__file__).parent/'measurements.tar.zst')
p.add_argument('--manifest',type=Path,default=Path(__file__).parent/'task-files.jsonl')
a=p.parse_args();archive=a.archive;manifest=a.manifest
expected={r['path']:r for r in map(json.loads,manifest.read_text().splitlines())};seen={};count=0;total=0;start=time.time()
p=subprocess.Popen(['zstd','-dc',str(archive)],stdout=subprocess.PIPE,stderr=subprocess.PIPE)
with tarfile.open(fileobj=p.stdout,mode='r|') as t:
 for member in t:
  if member.isdir():continue
  assert member.name in expected,('unexpected',member.name)
  assert member.name not in seen,('duplicate',member.name)
  r=expected[member.name];assert member.mode==r['mode'],('mode',member.name)
  if member.issym():assert r['type']=='symlink' and member.linkname==r['target'];seen[member.name]=r;continue
  assert r['type']=='file',member.name
  if member.islnk():
   prior=seen[member.linkname];assert prior['sha256']==r['sha256'] and prior['bytes']==r['bytes']
  else:
   assert member.isfile() and member.size==r['bytes'],member.name
   f=t.extractfile(member);h=hashlib.sha256()
   for chunk in iter(lambda:f.read(1048576),b''):h.update(chunk)
   assert h.hexdigest()==r['sha256'],('SHA mismatch',member.name)
  seen[member.name]=r;count+=1;total+=r['bytes']
assert p.wait()==0,p.stderr.read().decode();assert set(seen)==set(expected),(len(seen),len(expected))
h=hashlib.sha256()
with archive.open('rb') as f:
 for b in iter(lambda:f.read(1048576),b''):h.update(b)
report={'state':'ALL_ARCHIVED_MEMBERS_SHA256_VERIFIED','archive':str(archive),'archive_sha256':h.hexdigest(),'archive_bytes':archive.stat().st_size,'regular_files':count,'regular_uncompressed_bytes':total,'symlinks':len(seen)-count,'verified_members':len(seen),'seconds':time.time()-start,'manifest_sha256':hashlib.sha256(manifest.read_bytes()).hexdigest()}
print(json.dumps(report,indent=2))
