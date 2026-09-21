from pathlib import Path
import re,html,json
from reportlab.pdfgen.canvas import Canvas
from reportlab.platypus import SimpleDocTemplate,Paragraph,Spacer,PageBreak
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from pypdf import PdfReader

pdfmetrics.registerFont(TTFont('CJK','C:/Windows/Fonts/msyh.ttc',subfontIndex=0))
pdfmetrics.registerFont(TTFont('CJKB','C:/Windows/Fonts/msyhbd.ttc',subfontIndex=0))
pdfmetrics.registerFontFamily('CJK',normal='CJK',bold='CJKB',italic='CJK',boldItalic='CJKB')
body=ParagraphStyle('body',fontName='CJK',fontSize=10,leading=17,spaceAfter=9,wordWrap='CJK',textColor=colors.HexColor('#252525'))
styles={
'body':body,
'title':ParagraphStyle('title',parent=body,fontName='CJKB',fontSize=24,leading=34,spaceAfter=18),
'h2':ParagraphStyle('h2',parent=body,fontName='CJKB',fontSize=16,leading=24,spaceAfter=15,keepWithNext=True),
'h3':ParagraphStyle('h3',parent=body,fontName='CJKB',fontSize=11.5,leading=19,spaceBefore=7,spaceAfter=7,keepWithNext=True),
'note':ParagraphStyle('note',parent=body,fontSize=9,leading=15,spaceAfter=12),
'reference':ParagraphStyle('reference',parent=body,fontSize=9.2,leading=14.5,spaceAfter=7),
}
def inline(t):
    t=html.escape(t)
    t=re.sub(r'\*\*(.+?)\*\*',r'<b>\1</b>',t)
    t=re.sub(r'\[\^(\d+)\]',r'<super>[\1]</super>',t)
    t=re.sub(r'(https?://[^\s。；）]+)',lambda m:'<link href="'+m.group(1)+'" color="#244765">'+m.group(1)+'</link>',t)
    return t
class NumberedCanvas(Canvas):
    def __init__(self,*a,**kw):
        Canvas.__init__(self,*a,**kw);self.states=[]
    def showPage(self):
        self.states.append(dict(self.__dict__));self._startPage()
    def save(self):
        total=len(self.states)
        for s in self.states:
            self.__dict__.update(s)
            self.setStrokeColor(colors.HexColor('#B9C1C8'));self.setLineWidth(.4)
            self.line(50,48,A4[0]-50,48)
            self.setFont('CJK',8);self.setFillColor(colors.HexColor('#626B75'))
            self.drawString(50,34,'油罐车侧翻 | 半年研究设计评审稿 | 2026-09-10')
            self.drawRightString(A4[0]-50,34,f'{self._pageNumber} / {total}')
            Canvas.showPage(self)
        Canvas.save(self)

src=Path('outputs/油罐车侧翻_半年研究指导书.md')
dst=src.with_suffix('.pdf')
story=[]
reference_section=False
for block in re.split(r'\n\s*\n',src.read_text(encoding='utf-8')):
    block=block.strip()
    if not block:continue
    if block=='<!-- pagebreak -->':story.append(PageBreak());continue
    if block.startswith('# '):story.append(Paragraph(inline(block[2:]),styles['title']));continue
    if block.startswith('## '):
        reference_section=block.startswith('## 14.')
        story.append(Paragraph(inline(block[3:]),styles['h2']));continue
    if block.startswith('### '):story.append(Paragraph(inline(block[4:]),styles['h3']));continue
    for line in block.splitlines():
        style=styles['note'] if line.startswith('[^') else (styles['reference'] if reference_section else styles['body'])
        if line.startswith('[^'):line=re.sub(r'^\[\^(\d+)\]:',r'[\1]',line)
        if line.startswith('- '):line='• '+line[2:]
        story.append(Paragraph(inline(line),style))
doc=SimpleDocTemplate(str(dst),pagesize=A4,leftMargin=50,rightMargin=50,topMargin=47,bottomMargin=67,title='油罐车侧翻：半年研究指导书',author='研究设计评审稿')
doc.build(story,canvasmaker=NumberedCanvas)
r=PdfReader(dst)
qa=[]
for i,p in enumerate(r.pages,1):
    t=p.extract_text() or ''
    qa.append({'page':i,'chars':len(t),'first':t[:90],'replacement_chars':t.count('\ufffd')})
Path('work/paper_guide/pdf_text_qa.json').write_text(json.dumps(qa,ensure_ascii=False,indent=2),encoding='utf-8')
print('PDF pages:',len(r.pages),'total chars:',sum(x['chars'] for x in qa),'replacement:',sum(x['replacement_chars'] for x in qa))
