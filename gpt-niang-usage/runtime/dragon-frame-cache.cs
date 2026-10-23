// Background PNG decode. Frozen WPF sources cross threads safely; no UI callbacks.
using System;
using System.IO;
using System.Collections.Generic;
using System.Threading;
using System.Windows.Media;
using System.Windows.Media.Imaging;
public sealed class DragonFrameCache : IDisposable {
  readonly object gate=new object();
  readonly Dictionary<string,BitmapSource> cache=new Dictionary<string,BitmapSource>();
  readonly Queue<string> order=new Queue<string>();
  readonly Queue<string> pending=new Queue<string>();
  readonly HashSet<string> queued=new HashSet<string>();
  readonly AutoResetEvent wake=new AutoResetEvent(false);
  readonly Thread worker;
  bool stopped;
  public int Hits,Misses,Failures;
  public int Count {get{lock(gate)return cache.Count;}}
  public DragonFrameCache(){worker=new Thread(Run);worker.IsBackground=true;worker.Name="Dragon PNG prefetch";worker.Start();}
  BitmapSource Decode(string file){
    BitmapSource result;
    using(var stream=new FileStream(file,FileMode.Open,FileAccess.Read,FileShare.Read)){
      result=BitmapDecoder.Create(stream,BitmapCreateOptions.PreservePixelFormat,BitmapCacheOption.OnLoad).Frames[0];
      if(result.Format!=PixelFormats.Bgra32)result=new FormatConvertedBitmap(result,PixelFormats.Bgra32,null,0);
      // Detach from the decoder too: a frozen BitmapFrame may retain thread-bound metadata.
      int stride=result.PixelWidth*4;var pixels=new byte[stride*result.PixelHeight];result.CopyPixels(pixels,stride,0);
      result=BitmapSource.Create(result.PixelWidth,result.PixelHeight,96,96,PixelFormats.Bgra32,null,pixels,stride);
      result.Freeze();
    }
    return result;
  }
  void Save(string file,BitmapSource im){lock(gate){
    if(stopped||cache.ContainsKey(file))return;
    while(order.Count>=40)cache.Remove(order.Dequeue());
    cache.Add(file,im);order.Enqueue(file);
  }}
  public BitmapSource Get(string file){
    lock(gate){if(stopped)throw new ObjectDisposedException("DragonFrameCache");BitmapSource im;if(cache.TryGetValue(file,out im)){Hits++;return im;}Misses++;}
    var value=Decode(file);Save(file,value);return value;
  }
  public void Prefetch(string[] files,bool reset){lock(gate){
    if(stopped)return;
    if(reset){pending.Clear();queued.Clear();}
    foreach(var file in files)if(pending.Count<24&&!cache.ContainsKey(file)&&queued.Add(file))pending.Enqueue(file);
    wake.Set();
  }}
  void Run(){try{while(true){
    string file=null;
    lock(gate){if(stopped)return;if(pending.Count>0){file=pending.Dequeue();queued.Remove(file);}}
    if(file==null){wake.WaitOne();continue;}
    try{Save(file,Decode(file));}catch{Interlocked.Increment(ref Failures);}
  }}finally{wake.Dispose();}}
  public void Dispose(){lock(gate){if(stopped)return;stopped=true;pending.Clear();cache.Clear();order.Clear();wake.Set();}worker.Join(1500);}
}
