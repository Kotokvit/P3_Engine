#!/usr/bin/env python3
"""
CLI Tool to Convert Markdown / Text to Professional DOCX and read DOCX.
Usage:
  python md_to_docx.py convert <input.md> <output.docx>
  python md_to_docx.py read <input.docx>
"""

import sys
import os
import docx
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH

def md_to_docx(input_file, output_file):
    doc = Document()
    
    # Set standard margins
    sections = doc.sections
    for section in sections:
        section.top_margin = Inches(0.8)
        section.bottom_margin = Inches(0.8)
        section.left_margin = Inches(0.8)
        section.right_margin = Inches(0.8)
        
    with open(input_file, 'r', encoding='utf-8') as f:
        lines = f.readlines()
        
    for line in lines:
        line_str = line.rstrip()
        if not line_str:
            doc.add_paragraph()
            continue
            
        if line_str.startswith("# "):
            p = doc.add_heading(line_str[2:], level=1)
        elif line_str.startswith("## "):
            p = doc.add_heading(line_str[3:], level=2)
        elif line_str.startswith("### "):
            p = doc.add_heading(line_str[4:], level=3)
        elif line_str.startswith("#### "):
            p = doc.add_heading(line_str[5:], level=4)
        elif line_str.startswith("- ") or line_str.startswith("* "):
            p = doc.add_paragraph(line_str[2:], style='List Bullet')
        elif line_str.startswith("> "):
            p = doc.add_paragraph(line_str[2:], style='Quote')
        else:
            p = doc.add_paragraph(line_str)
            
    doc.save(output_file)
    print(f"✅ Успішно збережено в DOCX: {output_file}")

def read_docx(docx_file):
    doc = Document(docx_file)
    full_text = []
    for para in doc.paragraphs:
        full_text.append(para.text)
    content = "\n".join(full_text)
    print(f"=== ЗМІСТ {docx_file} ({len(doc.paragraphs)} параграфів) ===")
    print(content[:3000])

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Використання: md_to_docx.py convert <in.md> <out.docx> АБО read <in.docx>")
        sys.exit(1)
        
    action = sys.argv[1]
    if action == "convert":
        md_to_docx(sys.argv[2], sys.argv[3])
    elif action == "read":
        read_docx(sys.argv[2])
