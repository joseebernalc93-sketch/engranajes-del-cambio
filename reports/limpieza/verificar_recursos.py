from pathlib import Path
import os,re,json
root=Path.cwd()
paths={}
stack=[root]
while stack:
    folder=stack.pop()
    for p in folder.iterdir():
        if p.is_symlink() or p.is_junction(): continue
        if p.is_dir(): stack.append(p)
        elif p.is_file(): paths[p.relative_to(root).as_posix()]=p.stat().st_size
source_ext={'.gd','.tscn','.tres','.godot','.cfg','.gdshader','.gdshaderinc','.json','.svg'}
source_roots={'assets','scripts','scenes','shaders','tests'}
refs={}
missing={}
for p in paths:
    if '/' in p and p.split('/')[0] not in source_roots: continue
    if Path(p).suffix not in source_ext: continue
    data=(root/p).read_text(encoding='utf-8-sig',errors='replace')
    refs[p]=[]
    for match in re.finditer(r'[\"\']\*?(res://[^\"\'\r\n]+)[\"\']',data):
        target=match.group(1)[6:]
        # Capture tools create these outputs; they are not input resources.
        if p.startswith('tests/') and target.startswith(('tmp/','output/')): continue
        if target in paths: refs[p].append(target)
        elif not (root/target).is_dir() and not any(c in target for c in '%*{'):
            missing.setdefault(p,[]).append(target)
seen=set()
todo=['project.godot']
while todo:
    p=todo.pop()
    if p in seen: continue
    seen.add(p)
    todo.extend(refs.get(p,[]))
active_missing={p:v for p,v in missing.items() if p in seen}
test_missing={p:v for p,v in missing.items() if p.startswith('tests/')}
plan=json.loads((root/'reports/limpieza/manifest.json').read_text(encoding='utf-8-sig'))
assert not active_missing,active_missing
assert not test_missing,test_missing
assert all((root/p).is_file() for p in plan['protected_test_only'])
assert all(not (root/p['path']).exists() for p in plan['files'])
folders={}
for p,n in paths.items():
    group=p.split('/')[0] if '/' in p else '(root)'
    folders[group]=folders.get(group,0)+n
source_bytes=sum(n for p,n in paths.items() if '/' not in p or p.split('/')[0] in source_roots)
report={'runtime_resource_files':len(seen),'missing_active_references':active_missing,'missing_test_references':test_missing,'protected_resources_present':len(plan['protected_test_only']),'deleted_manifest_files':len(plan['files']),'total_bytes':sum(paths.values()),'source_bytes':source_bytes,'folder_bytes':folders}
(root/'reports/limpieza/verificacion_recursos.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(report,ensure_ascii=False,indent=2))
