# generate.py — flow-kit 技术设计 PPT v3 (25 slides)
# All text uses SINGLE quotes to avoid " conflicts with Chinese 「」 brackets.
import os,sys,json; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from pptx import Presentation,util
import theme; from masters import LAYOUTS; from utils import render_diagrams as RD

ROOT='/home/hellrabbit/unisoc/flow-kit'
OUT=os.path.join(ROOT,'flow-kit-技术设计.pptx')
C=theme.HEX_COLORS;B=theme.SIZE_BODY;S=theme.SIZE_SMALL
D={'d0':'d0_three_layer_arch.png','d1':'d1_go_routing.png','d2':'d2_pipeline.png',
   'd4':'d4_three_layer_gate.png','d5':'d5_goal_sequence.png',
   'd6':'d6_fk_resolve_model.png','d7':'d7_adr_evolution.png'}
X=lambda **kw:kw
SL=[
X(layout='cover',title='flow-kit 技术设计',subtitle='AI 驱动的软件开发流程框架 · 设计理念与重要技术细节',
  taglines=['三层架构 · artifact-first · protect-the-weakest · 三层门禁 · 双轮独立审查'],
  date='2026-07-24 | github.com/hellrabb/flow-kit'),

# === 2. 三层架构 ===
X(layout='text_image',image_side='right',image=D['d0'],
  title='flow-kit 不是什么「纯 markdown」',subtitle='三层架构：核心引擎 + Hook 运行时 + Skill 包装',
  body=[
    P('flow-kit 不是纯 markdown 文档集——它有运行时。三层架构各司其职：',size=B,sp=6),
    P('核心引擎层（markdown，无运行时依赖）',bold=1,color='primary'),
    P('GO.md 统一入口路由 + prompts/ 阶段指令 + reference/ 查阅型参考 + templates/ 产物模板',lv=1,sz=S),
    P('不被工具更新坑到。改哪条编程约定就改哪个 md。',lv=1,sz=S,color='muted'),
    P('Hook 运行时层（bash，自动门禁与兜底）',bold=1,color='accent',sb=4),
    P('Stop 链式执行 17 个模块化脚本：从 transcript 解析到状态完整性交叉验证',lv=1,sz=S),
    P('PreToolUse 2 个：每次 Write/Edit/Bash 前自动 checkpoint + 硬拦截未经 review 的 commit/PR',lv=1,sz=S),
    P('SessionStart 2 个：会话启动时恢复状态 + 注入矫正指令 + 显示审查结果',lv=1,sz=S),
    P('Skill 包装层（IDE 适配，跨 IDE 一致）',bold=1,color='success',sb=4),
    P('17 个 flow-* skills 将核心引擎暴露为 /flow-go、/flow 等斜杠命令',lv=1,sz=S),
    P('brooks-lint 6 skills 将 12 本软件工程经典书籍的诊断框架暴露为可调用 skill',lv=1,sz=S),
  ]),
]
# Convert: bold→bold, lv→level, sz→size, sp→space_after, sb→space_before
def _conv(spec):
    if 'body' in spec:
        spec['body'] = [{
            'text': b['text'],
            **({'bold':True} if b.get('bold') else {}),
            **({'level':b['lv']} if 'lv' in b else {}),
            **({'size':b['sz']} if 'sz' in b else {'size':B}),
            **({'space_after':b['sp']} if 'sp' in b else {'space_after':4}),
            **({'space_before':b['sb']} if 'sb' in b else {}),
            **({'color':{'primary':'1F3A5F','accent':'2E86AB','success':'2A9D8F','warning':'E9A23B','danger':'C7463B','muted':'6C757D','dark':'1A1A2E'}[b['color']]} if b.get('color') else {}),
        } for b in b['body']]
    return spec

SL = [_conv(s) for s in SL]
print(f'SLIDES: {len(SL)}')
# Test: generate
RD.render_all()
prs=Presentation();prs.slide_width=theme.SLIDE_W;prs.slide_height=theme.SLIDE_H
for i,s in enumerate(SL,1):
    LAYOUTS[s['layout']](prs,s)
    print(f'  {i}. {s["layout"]:<11} {s.get("title","")[:40]}')
prs.save(OUT)
print(f'{OUT} slides={len(prs.slides)}')
from pptx import Presentation as P2; P2(OUT); print('P0-5 OK')
