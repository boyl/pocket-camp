"""仅从白名单生成可复现的单文件运行脚本。"""
from pathlib import Path
root=Path(__file__).parent
source=root/'release-src'
out=root/'release-build/reframework/autorun'
out.mkdir(parents=True,exist_ok=True)
parts=['-- Pocket Camp 1.0.0 | Monster Hunter Rise / Sunbreak\n-- Generated from release-src; no external Lua modules required.\n']
for name in ('gamepad','controller','runtime'):
    parts.append(f'local {name.title()} = (function()\n'+(source/f'{name}.lua').read_text(encoding='utf-8')+'\nend)()\n')
parts.append('-- ENTRY\n'+(source/'entry.lua').read_text(encoding='utf-8'))
(out/'PocketCamp.lua').write_text('\n'.join(parts),encoding='utf-8',newline='\n')
print('Built release-build/reframework/autorun/PocketCamp.lua')
