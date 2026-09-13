import AppKit
let canvas=CGSize(width:1600,height:1000)
for source in [CGSize(width:400,height:1200),CGSize(width:2400,height:400),canvas] {
 for fill in [true,false] {
  for zoom:CGFloat in [1,2,4] {
   for offset:CGFloat in [-1,0,1] {
    let p=ImagePlacement(fill:fill,zoom:zoom,x:offset,y:offset)
    let r=p.rect(source:source,canvas:canvas)
    assert(abs(r.width/r.height-source.width/source.height)<0.0001)
    if fill { assert(r.minX<=0.001 && r.minY<=0.001 && r.maxX>=1599.999 && r.maxY>=999.999) }
    if !fill && zoom==1 { assert(r.minX >= -0.001 && r.minY >= -0.001 && r.maxX<=1600.001 && r.maxY<=1000.001) }
   }
  }
 }
}
print("PASS: 54 placements preserve proportions, fill covers canvas, fit contains whole image")
let app=NSApplication.shared; app.setActivationPolicy(.accessory)
let c=CGContext(data:nil,width:400,height:1200,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
c.setFillColor(NSColor.systemTeal.cgColor);c.fill(CGRect(x:0,y:0,width:400,height:1200));c.setFillColor(NSColor.orange.cgColor);c.fillEllipse(in:CGRect(x:50,y:450,width:300,height:300))
let editor=ImageCropEditor(image:c.makeImage()!,size:canvas,placement:ImagePlacement())
editor.panel.contentView!.layoutSubtreeIfNeeded()
let view=editor.panel.contentView!
for child in view.subviews { assert(child.frame.maxY<=view.bounds.maxY+1) }
let fitted=ImagePlacement(fill:false).render(c.makeImage()!,size:canvas)!
assert(fitted.width==1600 && fitted.height==1000)
print("PASS: output dimensions and editor layout")
