#!/usr/bin/env python3
"""
Fix PPT animations: change click-triggered to auto-play.
Standalone tool - can be used independently of the main pipeline.

Usage:
    python fix_ppt_animations.py <input.pptx> [output.pptx]

If output not specified, creates <input>_auto.pptx
"""

import os
import sys
import zipfile
import tempfile
import shutil
from lxml import etree


def fix_animations(src_pptx, dst_pptx):
    """
    Modify PPTX XML to auto-play all animations.
    Changes delay="indefinite" to delay="0" in slide XML.
    Returns number of animations fixed.
    """
    tmpdir = tempfile.mkdtemp()

    try:
        with zipfile.ZipFile(src_pptx, 'r') as zf:
            zf.extractall(tmpdir)

        slides_dir = os.path.join(tmpdir, 'ppt', 'slides')
        if not os.path.exists(slides_dir):
            # No slides found, just copy
            shutil.copy2(src_pptx, dst_pptx)
            return 0

        slide_files = sorted([f for f in os.listdir(slides_dir) if f.endswith('.xml')])
        total_changes = 0

        for slide_file in slide_files:
            slide_path = os.path.join(slides_dir, slide_file)
            tree = etree.parse(slide_path)
            root = tree.getroot()

            changed = 0
            for elem in root.iter():
                tag = etree.QName(elem.tag).localname
                if tag == 'cond':
                    delay = elem.get('delay', '')
                    if delay == 'indefinite':
                        elem.set('delay', '0')
                        changed += 1

            if changed > 0:
                tree.write(slide_path, xml_declaration=True, encoding='UTF-8', standalone=True)
                print(f"  {slide_file}: {changed} clicks -> auto")
                total_changes += changed

        # Re-zip
        with zipfile.ZipFile(dst_pptx, 'w', zipfile.ZIP_DEFLATED) as zf:
            for root_dir, dirs, files in os.walk(tmpdir):
                for file in files:
                    file_path = os.path.join(root_dir, file)
                    arcname = os.path.relpath(file_path, tmpdir)
                    zf.write(file_path, arcname)

        return total_changes

    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


def main():
    if len(sys.argv) < 2:
        print("Usage: python fix_ppt_animations.py <input.pptx> [output.pptx]")
        sys.exit(1)

    src = sys.argv[1]
    if not os.path.exists(src):
        print(f"Error: File not found: {src}")
        sys.exit(1)

    if len(sys.argv) >= 3:
        dst = sys.argv[2]
    else:
        base, ext = os.path.splitext(src)
        dst = f"{base}_auto{ext}"

    print(f"Input: {src}")
    print(f"Output: {dst}")

    changes = fix_animations(src, dst)
    print(f"\nTotal animations fixed: {changes}")
    print(f"Output: {dst} ({os.path.getsize(dst)/1024/1024:.2f}MB)")


if __name__ == '__main__':
    main()