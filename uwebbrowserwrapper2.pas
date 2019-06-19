unit UWebBrowserWrapper2;

{$mode objfpc}{$H+}

interface
uses
  Classes, SysUtils, Forms,
  activexcontainer, shdocvw_1_1_tlb, ActiveX, Windows, LCLProc ;

type

  { TWebBrowserWrapper }

  TWebBrowserWrapper = class(TObject)
  private
    ActiveXContainer1: TActiveXContainer;
  public
    constructor Create(ActiveXContainer: TActiveXContainer);
    procedure InternalLoadDocumentFromStream(const Stream: TStream);
    procedure LoadFromString(const HTML: string);
    function WebBrowser: IWebBrowser2;
    procedure LoadFromStream(const Stream: TStream);
    procedure NavigateToURL(const URL: string);

  end;

implementation

uses
  strutils;

const
  navNoHistory = $00000002;
  navNoReadFromCache = $00000004;
  navNoWriteToCache = $00000008;

constructor TWebBrowserWrapper.Create(ActiveXContainer: TActiveXContainer);
var
  Browser: TEvsWebBrowser;
begin
  ActiveXContainer1 := ActiveXContainer;
  Browser:=TEvsWebBrowser.Create(ActiveXContainer.owner);
  ActiveXContainer1.ComServer := Browser.ComServer;
  ActiveXContainer1.Active:=true;
end;

procedure TWebBrowserWrapper.InternalLoadDocumentFromStream(
  const Stream: TStream);
var
  PersistStreamInit: IPersistStreamInit;
  StreamAdapter: IStream;
begin
  if not Assigned(WebBrowser.Document) then
    Exit;
  // Get IPersistStreamInit interface on document object
  if WebBrowser.Document.QueryInterface(
    IPersistStreamInit, PersistStreamInit
  ) = S_OK then
  begin
    // Clear document
    if PersistStreamInit.InitNew = S_OK then
    begin
      // Get IStream interface on stream
      StreamAdapter:= TStreamAdapter.Create(Stream);
      // Load data from Stream into WebBrowser
      PersistStreamInit.Load(StreamAdapter);
    end;
  end;
end;

function TWebBrowserWrapper.WebBrowser: IWebBrowser2;
begin
  result := ActiveXContainer1.ComServer as IWebBrowser2;
end;


procedure TWebBrowserWrapper.LoadFromStream(const Stream: TStream);
begin
  NavigateToURL('about:blank');
  InternalLoadDocumentFromStream(Stream);
end;

procedure TWebBrowserWrapper.LoadFromString(const HTML: string);
var
  StringStream: TStringStream;
begin
  StringStream := TStringStream.Create(HTML);
  try
    LoadFromStream(StringStream);
  finally
    StringStream.Free;
  end;
end;

procedure TWebBrowserWrapper.NavigateToURL(const URL: string);
  // ---------------------------------------------------------------------------
  procedure Pause(const ADelay: Cardinal);
  var
    StartTC: Cardinal;  // tick count when routine called
  begin
    StartTC := Windows.GetTickCount;
    repeat
      Application.ProcessMessages;
    until Int64(Windows.GetTickCount) - Int64(StartTC) >= ADelay;
  end;
  // ---------------------------------------------------------------------------
var
  Flags, onull: OleVariant;  // flags that determine action
begin
  // Don't record in history
  Flags := navNoHistory;
  if AnsiStartsText('res://', URL) or AnsiStartsText('file://', URL)
    or AnsiStartsText('about:', URL) or AnsiStartsText('javascript:', URL)
    or AnsiStartsText('mailto:', URL) then
    // don't use cache for local files
    Flags := Flags or navNoReadFromCache or navNoWriteToCache;
  // Do the navigation and wait for it to complete
  onull := NULL;

  WebBrowser.Navigate(WideString(URL), Flags, onull, onull, onull);
  while WebBrowser.ReadyState <> READYSTATE_COMPLETE do
    Pause(5);
end;

end.

