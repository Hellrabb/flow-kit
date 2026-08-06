import os,sys,json
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from pptx import Presentation; import theme
from masters import LAYOUTS; from utils import render_diagrams as RD

OUT='/home/hellrabbit/unisoc/flow-kit/flow-kit-技术设计.pptx'
I=['d0_three_layer_arch.png','d1_go_routing.png','d2_pipeline.png',
   'd4_three_layer_gate.png','d5_goal_sequence.png',
   'd6_fk_resolve_model.png','d7_adr_evolution.png']

SL=json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)),'slides.json')))

def main():
    RD.render_all()
    for s in SL:
        if s.get('image'):
            p=os.path.join(RD.DIAG_DIR,s['image'])
            assert os.path.exists(p),f'MISSING:{p}'
            r=RD.aspect_ratio(p)
            print(f'  {s["image"]} r={r:.2f}:1 {RD.fold_verdict(r)}')
    print(f'=== Build {len(SL)} slides ===')
    prs=Presentation(); prs.slide_width=theme.SLIDE_W; prs.slide_height=theme.SLIDE_H
    for i,s in enumerate(SL,1):
        LAYOUTS[s['layout']](prs,s)
        print(f'  {i:>2} {s["layout"]:<11} {s.get("title","")[:46]}')
    prs.save(OUT)
    from pptx import Presentation as P2; P2(OUT)
    print(f'\nOK: {OUT}  slides={len(prs.slides)}  P0-5 pass')

if __name__=='__main__': main()
