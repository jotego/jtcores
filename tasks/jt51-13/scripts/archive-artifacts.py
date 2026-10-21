#!/usr/bin/env python3
"""Archive stopped measurement producers and verify every decompressed member."""
import argparse, hashlib, json, os, stat, subprocess, sys, time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--case',type=Path,required=True)
    parser.add_argument('--producers-stopped',action='store_true',required=True)
    args=parser.parse_args();case=args.case.resolve()
    assert case.parent==Path('/gdrive/jotego/reverse/YM2151') and case.is_dir()
    artifacts=ROOT/'artifacts';prefix='tasks/jt51-13/artifacts'
    inventory=[]
    for p in sorted(artifacts.rglob('*')):
        s=p.lstat()
        if stat.S_ISDIR(s.st_mode):continue
        row={'path':prefix+'/'+str(p.relative_to(artifacts)),'mode':stat.S_IMODE(s.st_mode)}
        if p.is_symlink():row.update(type='symlink',target=os.readlink(p))
        else:
            assert stat.S_ISREG(s.st_mode),p
            row.update(type='file',bytes=s.st_size,sha256=digest(p))
        inventory.append(row)
    manifest=case/'task-files.jsonl'
    with manifest.open('x') as f:
        for row in inventory:f.write(json.dumps(row,sort_keys=True)+'\n')
    partial=case/'measurements.tar.zst.partial';final=case/'measurements.tar.zst'
    assert not partial.exists() and not final.exists()
    with (case/'tar.stderr').open('x') as terr,(case/'zstd.stderr').open('x') as zerr:
        tar=subprocess.Popen(['tar','-C',str(ROOT.parents[1]),'-cf','-',prefix],stdout=subprocess.PIPE,stderr=terr)
        compressor=subprocess.Popen(['zstd','-T2','-9','-o',str(partial)],stdin=tar.stdout,stdout=subprocess.DEVNULL,stderr=zerr)
        tar.stdout.close();zcode=compressor.wait();tcode=tar.wait()
    assert tcode==0 and zcode==0,(tcode,zcode)
    # Detect any producer that changed data while the snapshot was being built.
    current={prefix+'/'+str(p.relative_to(artifacts)) for p in artifacts.rglob('*') if not p.is_dir() or p.is_symlink()}
    assert current=={r['path'] for r in inventory},'artifact membership changed'
    for row in inventory:
        p=ROOT.parents[1]/row['path'];s=p.lstat()
        assert stat.S_IMODE(s.st_mode)==row['mode'],p
        if row['type']=='symlink':assert p.is_symlink() and os.readlink(p)==row['target'],p
        else:assert s.st_size==row['bytes'] and digest(p)==row['sha256'],p
    command=[sys.executable,str(ROOT/'scripts/verify-archive.py'),str(partial),'--manifest',str(manifest)]
    result=subprocess.run(command,capture_output=True,text=True)
    with (case/'archive-verifier.stderr').open('x') as f:f.write(result.stderr)
    assert result.returncode==0,result.stderr
    proof=json.loads(result.stdout);assert proof['state']=='ALL_ARCHIVED_MEMBERS_SHA256_VERIFIED'
    # A concurrent final publication must never be replaced.
    os.link(partial,final)
    partial.unlink()
    proof.update(archive=str(final),atomic_install=True,install_method='hardlink_no_clobber',actual_verifier_exit=result.returncode,source_artifact_members=len(inventory),scope='All task artifacts, including raw data, stimuli, producer snapshots, models, failures, features, plots and audits. Final committed task sources are preserved separately under sources/.')
    with (case/'archive-member-verification.json').open('x') as f:json.dump(proof,f,indent=2);f.write('\n')
    print(json.dumps(proof,indent=2))
def digest(p):
    h=hashlib.sha256()
    with p.open('rb') as f:
        for b in iter(lambda:f.read(1048576),b''):h.update(b)
    return h.hexdigest()
if __name__=='__main__':main()
