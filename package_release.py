"""白名单打包、逐文件 SHA-256、归档复核与模拟解压安装。"""
from pathlib import Path
import hashlib,json,zipfile
root=Path(__file__).parent
outputs=root/'dist'
outputs.mkdir(exist_ok=True)
files={
 'reframework/autorun/PocketCamp.lua':root/'release-build/reframework/autorun/PocketCamp.lua',
 'README.md':root/'release-src/README.md',
 'CHANGELOG.md':root/'release-src/CHANGELOG.md',
}
payload={name:path.read_bytes() for name,path in files.items()}
hashes={name:hashlib.sha256(data).hexdigest() for name,data in payload.items()}
payload['SHA256SUMS.txt']=''.join(f'{digest}  {name}\n' for name,digest in hashes.items()).encode()
archive=outputs/'Pocket-Camp-1.0.0.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
 for name,data in payload.items():
  info=zipfile.ZipInfo(name,date_time=(2026,11,15,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED
  z.writestr(info,data)
test=root/'release-install-test'
test.mkdir(exist_ok=True)
sentinel=test/'reframework/autorun/OtherMod.lua'
sentinel.parent.mkdir(parents=True,exist_ok=True)
sentinel.write_text('-- unrelated mod\n',encoding='utf-8')
with zipfile.ZipFile(archive) as z:
 assert set(z.namelist())==set(payload)
 assert z.testzip() is None
 for name,data in payload.items(): assert z.read(name)==data
 z.extractall(test)
 # 重复覆盖安装不得影响非本 Mod 文件。
 z.extractall(test)
assert sentinel.read_text(encoding='utf-8')=='-- unrelated mod\n'
assert (test/'reframework/autorun/PocketCamp.lua').read_bytes()==payload['reframework/autorun/PocketCamp.lua']
assert len(list(test.glob('reframework/autorun/PocketCamp*.lua')))==1
report={'version':'1.0.0','archive':archive.name,'archive_sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),
 'archive_bytes':archive.stat().st_size,'uncompressed_bytes':sum(map(len,payload.values())),
 'files':hashes,'single_runtime_file':True,'zip_integrity':True,'fresh_and_overlay_install':True,
 'external_publish':False}
(root/'evidence/release-package.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
(outputs/'Pocket-Camp-1.0.0.sha256').write_text(report['archive_sha256']+'  '+archive.name+'\n',encoding='ascii')
print(json.dumps(report,ensure_ascii=False,indent=2))
