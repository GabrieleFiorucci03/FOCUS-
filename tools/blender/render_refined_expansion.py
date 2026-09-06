"""Render the reimported expansion GLBs, never synthetic concept images."""
import argparse
import json
import sys
from pathlib import Path
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import render_refined_assets as renderer
ROOT=HERE.parents[1]
renderer.OUT=ROOT/'assets/previews/refined_expansion'

def main():
    p=argparse.ArgumentParser()
    p.add_argument('--asset',action='append');p.add_argument('--size',type=int,default=600)
    p.add_argument('--samples',type=int,default=16);p.add_argument('--views',default='front,rear')
    p.add_argument('--shard',type=int,default=0);p.add_argument('--shards',type=int,default=1)
    p.add_argument('--skip-existing',action='store_true')
    args=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    (renderer.OUT/'renders').mkdir(parents=True,exist_ok=True)
    # La libreria e' una cartella sola: il kit di base e l'espansione stanno
    # insieme e si distinguono per il campo 'collection' delle sue voci.
    catalog=[a for a in json.loads((ROOT/'assets/models/refined_v2/catalog.json').read_text(encoding='utf-8'))['assets']
             if a.get('collection')=='refined_expansion']
    for i,a in enumerate(catalog):
        if args.asset and a['id'] not in args.asset:continue
        if i%args.shards!=args.shard:continue
        for view in args.views.split(','):
            target=renderer.OUT/'renders'/f'{a["id"]}__refined_expansion__{view}.png'
            if args.skip_existing and target.exists():continue
            renderer.render(a,'refined_expansion',view,args.size,args.samples,'CYCLES',folder='refined_v2')

if __name__=='__main__':main()
