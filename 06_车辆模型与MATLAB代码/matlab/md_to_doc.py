# -*- coding: utf-8 -*-
"""将 markdown 实验方案转为 .doc 文件保存到桌面"""
import re
from docx import Document
from docx.shared import Pt
from docx.oxml.ns import qn

src = r'C:\Users\LENOVO\tanker_trucksim_cosim\docs\实验方案.md'

with open(src, 'r', encoding='utf-8') as f:
    lines = f.readlines()

doc = Document()

# 默认字体宋体
style = doc.styles['Normal']
style.font.name = '宋体'
style.font.size = Pt(12)
style.element.rPr.rFonts.set(qn('w:eastAsia'), '宋体')


def set_font(run, name, size, bold=False):
    run.font.name = name
    run.font.size = Pt(size)
    run.font.bold = bold
    run._element.rPr.rFonts.set(qn('w:eastAsia'), name)


def add_table(rows):
    table = doc.add_table(rows=len(rows), cols=len(rows[0]))
    table.style = 'Table Grid'
    for i, row in enumerate(rows):
        for j, cell in enumerate(row):
            table.cell(i, j).text = cell.strip()
            for p in table.cell(i, j).paragraphs:
                for run in p.runs:
                    set_font(run, '宋体', 10)
    return table


i = 0
in_code = False
code_lines = []
table_buffer = []

while i < len(lines):
    line = lines[i].rstrip('\n')

    if line.strip().startswith('```'):
        if in_code:
            code_text = '\n'.join(code_lines)
            p = doc.add_paragraph()
            set_font(p.add_run(code_text), 'Consolas', 10)
            in_code = False
            code_lines = []
        else:
            in_code = True
        i += 1
        continue

    if in_code:
        code_lines.append(line)
        i += 1
        continue

    if line.strip().startswith('|'):
        table_buffer.append(line)
        i += 1
        continue
    elif table_buffer:
        rows = []
        for tl in table_buffer:
            cells = [c.strip() for c in tl.strip().strip('|').split('|')]
            if all(re.match(r'^:?-+:?$', c) for c in cells):
                continue
            rows.append(cells)
        if rows:
            add_table(rows)
            doc.add_paragraph()
        table_buffer = []
        continue

    if line.startswith('# '):
        p = doc.add_heading(line[2:], level=1)
        for run in p.runs:
            set_font(run, '黑体', 18, True)
    elif line.startswith('## '):
        p = doc.add_heading(line[3:], level=2)
        for run in p.runs:
            set_font(run, '黑体', 15, True)
    elif line.startswith('### '):
        p = doc.add_heading(line[4:], level=3)
        for run in p.runs:
            set_font(run, '黑体', 13, True)
    elif line.startswith('#### '):
        p = doc.add_heading(line[5:], level=4)
        for run in p.runs:
            set_font(run, '黑体', 12, True)
    elif line.strip().startswith('- '):
        doc.add_paragraph(line.strip(), style='List Bullet')
    elif re.match(r'^\d+\.\s', line.strip()):
        doc.add_paragraph(line.strip(), style='List Number')
    elif line.strip() == '':
        pass
    else:
        p = doc.add_paragraph(line)
        for run in p.runs:
            set_font(run, '宋体', 12)

    i += 1

if table_buffer:
    rows = []
    for tl in table_buffer:
        cells = [c.strip() for c in tl.strip().strip('|').split('|')]
        if all(re.match(r'^:?-+:?$', c) for c in cells):
            continue
        rows.append(cells)
    if rows:
        add_table(rows)

out_docx = r'C:\Users\LENOVO\OneDrive\桌面\实验方案.docx'
doc.save(out_docx)
print('docx saved:', out_docx)
