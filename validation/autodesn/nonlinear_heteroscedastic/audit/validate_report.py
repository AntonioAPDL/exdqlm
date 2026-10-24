"""Render every report page; record visual approval only after actual inspection."""
import argparse,hashlib,json,subprocess
from pathlib import Path
from datetime import datetime,timezone
from pypdf import PdfReader
from PIL import Image,ImageDraw
HERE=Path(__file__).resolve().parent

def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--confirm-visual-review',action='store_true',help='Use only after inspecting all rendered pages for clipping, overlap and legibility')
 a=p.parse_args();pdf=HERE/'evidence/NHS1_Diagnostic_Audit.pdf'
 folder=HERE/'artifacts/validation/report_render';folder.mkdir(parents=True,exist_ok=True)
 digest=hashlib.sha256(pdf.read_bytes()).hexdigest();pages=len(PdfReader(pdf).pages)
 stamp=folder/'render.json'
 if not stamp.exists() or json.loads(stamp.read_text()).get('pdf_sha256')!=digest:
  for pattern in ['page-*.png','contact-*.png']:
   for q in folder.glob(pattern):q.unlink()
  subprocess.run(['pdftoppm','-r','115','-png',str(pdf),str(folder/'page')],check=True)
  pngs=sorted(folder.glob('page-*.png'));assert len(pngs)==pages
  for start in range(0,len(pngs),6):
   canvas=Image.new('RGB',(900,2*450),'#dce2e8');draw=ImageDraw.Draw(canvas)
   for j,name in enumerate(pngs[start:start+6]):
    image=Image.open(name).convert('RGB');image.thumbnail((285,620));x=(j%3)*300+(300-image.width)//2;y=(j//3)*450+25
    canvas.paste(image,(x,y));draw.text(((j%3)*300+12,(j//3)*450+8),f'Page {start+j+1}',fill='black')
   canvas.save(folder/f'contact-{start//6+1:02}.png')
  stamp.write_text(json.dumps(dict(pdf_sha256=digest,pages=pages,rendered_all_pages=True),indent=2))
 assert len(list(folder.glob('page-*.png')))==pages
 if a.confirm_visual_review:
  out=dict(complete=True,pdf_sha256=digest,pages=pages,rendered_all_pages=True,visual_inspection='All pages inspected for clipping, overlap, table breaks, figure labels and legibility.',approved_UTC=datetime.now(timezone.utc).isoformat())
  (HERE/'artifacts/validation/report_validation.json').write_text(json.dumps(out,indent=2))
  print(json.dumps(out))
 else:print(f'Rendered {pages} pages to {folder}. Inspect every page before --confirm-visual-review.')
if __name__=='__main__':main()
