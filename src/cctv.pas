{$apptype windows}

{$reference System.Drawing.dll}
{$reference System.Windows.Forms.dll}
{$reference AForge.Video.dll}
{$reference AForge.Video.DirectShow.dll}

{$resource res\icon.ico}
{$resource res\refresh.png}
{$resource res\start.png}
{$resource res\stop.png}

{$mainresource res\res.res}


uses
  System,
  System.Drawing,
  System.Windows.Forms,
  System.Reflection,
  System.Threading,
  AForge.Video,
  AForge.Video.DirectShow;


var
  Main         : Form;
  SourcesUpdate: Button;
  SourceSelect : ComboBox;
  ModeSelect   : ComboBox;
  ViewStart    : Button;
  ViewStop     : Button;
  ViewBox      : PictureBox;
  VideoDevices : FilterInfoCollection;
  VideoDevice  : VideoCaptureDevice;
  CurResolution: Size;
  

{$region Routines}
function VideoCaptureDevice.IsConnected(): boolean;
begin
  result := false;
  
  var devs := new FilterInfoCollection(FilterCategory.VideoInputDevice);
  if devs.Count > 0 then
    foreach var dev: FilterInfo in devs do
      if dev.MonikerString = self.Source then
        begin
          result := true;
          break;
        end;
end;
{$endregion}

{$region Handlers}
procedure MainResize(sender: object; e: EventArgs);
begin
  var dy := SourcesUpdate.Top + SourcesUpdate.Height;
  
  var cw := Main.ClientSize.Width;
  var ch := Main.ClientSize.Height - dy;
  
  if cw >= CurResolution.Width then
    begin
      ViewBox.Width := CurResolution.Width;
      ViewBox.Left  := (cw - CurResolution.Width) div 2;
    end
  else
    begin
      ViewBox.Width := cw - 2;
      ViewBox.Left  := 1;
    end;
  
  if ch >= CurResolution.Height then
    begin
      ViewBox.Height := CurResolution.Height;
      ViewBox.Top    := dy + Math.Max((ch - CurResolution.Height) div 2, 0);
    end
  else
    begin
      ViewBox.Height := ch - 2;
      ViewBox.Top    := dy + 1;
    end;
end;

procedure MainFormClosing(sender: object; e: FormClosingEventArgs);
begin
  if VideoDevice <> nil then
    if VideoDevice.IsRunning then
      VideoDevice.Stop();
end;

procedure VideoDeviceNewFrame(sender: object; e: NewFrameEventArgs);
begin
  var old := ViewBox.Image;
  
  Monitor.Enter(Main);
  ViewBox.Image := e.Frame.Clone() as Bitmap;
  Monitor.Exit(Main);
  
  e.Frame.Dispose();
  
  if old <> nil then
    begin
      old.Dispose();
      old := nil;
    end;
end;

procedure SourcesUpdateClick(sender: object; e: EventArgs);
begin
  SourceSelect.Items.Clear();
  ModeSelect.Items.Clear();
  
  VideoDevices := new FilterInfoCollection(FilterCategory.VideoInputDevice);
  if VideoDevices.Count > 0 then
    begin
      foreach var dev: FilterInfo in VideoDevices do
        SourceSelect.Items.Add(dev.Name);
      
      SourceSelect.SelectedIndex := 0;
    end
  else
    begin
      ViewStart.Enabled := false;
      ViewStop.Enabled  := false;
    end;
end;

procedure SourceSelectSelectedIndexChanged(sender: object; e: EventArgs);
begin
  var index := SourceSelect.SelectedIndex;
  
  if index > -1 then
    begin
      var vd := VideoDevices[index].MonikerString;
      
      try
        VideoDevice          := new VideoCaptureDevice(vd);
        VideoDevice.NewFrame += VideoDeviceNewFrame;
      except
        MessageBox.Show($'Can not create video device: "{vd}".', 'Error', MessageBoxButtons.OK, MessageBoxIcon.Error);
        index := -1;
      end;
      
      var caps := VideoDevice.VideoCapabilities;
      if (caps <> nil) and (caps.Length > 0) then
        begin
          for var i := 0 to caps.Length-1 do
            ModeSelect.Items.Add($'{caps[i].FrameSize.Width}x{caps[i].FrameSize.Height}@{caps[i].AverageFrameRate}');
          
          ModeSelect.SelectedIndex := 0;
        end;
    end;
  
  ViewStart.Enabled := index > -1;
end;

procedure ModeSelectSelectedIndexChanged(sender: object; e: EventArgs);
begin
  var index := ModeSelect.SelectedIndex;
  
  if index > -1 then
    begin
      var cap := VideoDevice.VideoCapabilities[index];
      VideoDevice.VideoResolution := cap;
      
      CurResolution := cap.FrameSize;
    end;
end;

procedure ViewStartClick(sender: object; e: EventArgs);
begin
  if VideoDevice.IsConnected() then
    begin
      try
        VideoDevice.Start();
        
        ViewStart.Enabled     := false;
        SourcesUpdate.Enabled := false;
        SourceSelect.Enabled  := false;
        ModeSelect.Enabled    := false;
        ViewStop.Enabled      := true;
      except on ex: Exception do
        MessageBox.Show('Can not open video device: {ex.Message}.', 'Error', MessageBoxButtons.OK, MessageBoxIcon.Error);
      end;
    end
  else
    MessageBox.Show('The video device could not be opened because it was disconnected.', 'Error', MessageBoxButtons.OK, MessageBoxIcon.Error);
end;

procedure ViewStopClick(sender: object; e: EventArgs);
begin
  if VideoDevice.IsRunning then
    VideoDevice.Stop();
  
  ViewStop.Enabled      := false;
  SourceSelect.Enabled  := true;
  SourcesUpdate.Enabled := true;
  ModeSelect.Enabled    := true;
  ViewBox.Image         := nil;
  ViewStart.Enabled     := true;
end;
{$endregion}

begin
  {$region App}
  Application.EnableVisualStyles();
  Application.SetCompatibleTextRenderingDefault(false);
  {$endregion}
  
  {$region MainForm}
  Main               := new Form();
  Main.Text          := 'CCTV';
  Main.Icon          := new Icon(Assembly.GetEntryAssembly().GetManifestResourceStream('icon.ico'));
  Main.StartPosition := FormStartPosition.CenterScreen;
  Main.MinimumSize   := new Size(600, 500);
  Main.Resize        += MainResize;
  Main.FormClosing   += MainFormClosing;
  {$endregion}
  
  {$region Sources}
  SourcesUpdate          := new Button();
  SourcesUpdate.Size     := new Size(25, 25);
  SourcesUpdate.Location := new Point(1, 1);
  SourcesUpdate.Image    := Image.FromStream(Assembly.GetEntryAssembly().GetManifestResourceStream('refresh.png'));
  SourcesUpdate.Click    += SourcesUpdateClick;
  Main.Controls.Add(SourcesUpdate);
  
  SourceSelect                      := new ComboBox();
  SourceSelect.Size                 := new Size(120, 24);
  SourceSelect.Location             := new Point(SourcesUpdate.Left+SourcesUpdate.Width+1, SourcesUpdate.Top+1);
  SourceSelect.DropDownStyle        := ComboBoxStyle.DropDownList;
  SourceSelect.Font                 := new Font('Microsoft Sans Serif', 8.75, FontStyle.Regular, GraphicsUnit.Point);
  SourceSelect.SelectedIndexChanged += SourceSelectSelectedIndexChanged;
  Main.Controls.Add(SourceSelect);
  {$endregion}
  
  {$region Mode}
  ModeSelect                      := new ComboBox();
  ModeSelect.Size                 := new Size(120, 24);
  ModeSelect.Location             := new Point(SourceSelect.Left+SourceSelect.Width+2, SourceSelect.Top);
  ModeSelect.DropDownStyle        := ComboBoxStyle.DropDownList;
  ModeSelect.Font                 := SourceSelect.Font;
  ModeSelect.SelectedIndexChanged += ModeSelectSelectedIndexChanged;
  Main.Controls.Add(ModeSelect);
  {$endregion}
  
  {$region Start Stop}
  ViewStart          := new Button();
  ViewStart.Size     := new Size(SourcesUpdate.Width, SourcesUpdate.Height);
  ViewStart.Location := new Point(ModeSelect.Left+ModeSelect.Width+1, SourcesUpdate.Top);
  ViewStart.Image    := Image.FromStream(Assembly.GetEntryAssembly().GetManifestResourceStream('start.png'));
  ViewStart.Enabled  := false;
  ViewStart.Click    += ViewStartClick;
  Main.Controls.Add(ViewStart);
  
  ViewStop          := new Button();
  ViewStop.Size     := new Size(ViewStart.Width, ViewStart.Height);
  ViewStop.Location := new Point(ViewStart.Left+ViewStart.Width, ViewStart.Top);
  ViewStop.Image    := Image.FromStream(Assembly.GetEntryAssembly().GetManifestResourceStream('stop.png'));
  ViewStop.Enabled  := false;
  ViewStop.Click    += ViewStopClick;
  Main.Controls.Add(ViewStop);
  {$endregion}
  
  {$region ViewBox}
  ViewBox           := new PictureBox();
  ViewBox.Size      := new Size(480, 360);
  ViewBox.Location  := new Point(SourcesUpdate.Left, SourcesUpdate.Top+SourcesUpdate.Height+1);
  ViewBox.BackColor := Color.Black;
  Main.Controls.Add(ViewBox);
  {$endregion}
  
  {$region App}
  SourcesUpdateClick(SourcesUpdate, EventArgs.Empty);
  if SourceSelect.SelectedIndex = -1 then
    Main.Size := new Size(610, 510)
  else
    Main.ClientSize := new Size(CurResolution.Width + 2, CurResolution.Height + ViewBox.Top + 1);
  
  Application.Run(Main);
  {$endregion}
end.