unit FMain;

{$mode objfpc}{$H+}

interface

uses
  Forms, SysUtils, Dialogs, Graphics,
  UWebBrowserWrapper2, StdCtrls, Grids, ExtCtrls, Spin, activexcontainer,
  Classes, IdHTTP, IdSSLOpenSSL, IdGlobal, jsonparser, fpjson;
type

  { TForm1 }

  TForm1 = class(TForm)
    ActiveXContainer1: TActiveXContainer;
    lbDegrad: TLabel;
    nbNavTest: TButton;
    edOAuthResult: TMemo;
    edToken: TEdit;
    edVehicle: TEdit;
    lbCarInfo: TLabel;
    lbCarState: TLabel;
    Page1: TPage;
    Page2: TPage;
    tiCheckCarState: TTimer;
    lbCntDown: TLabel;
    sgSoC: TStringGrid;
    nxButtons: TNotebook;
    nbOAuth: TButton;
    Label1: TLabel;
    edEmail: TEdit;
    lbPAssword: TLabel;
    edPassword: TEdit;
    nbCarData: TButton;
    nbWake: TButton;
    edChargeLimit: TSpinEdit;
    nbSetChargeLimit: TButton;
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure nbOAuthClick(Sender: TObject);
    procedure nbWakeClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure tiCheckCarStateTimer(Sender: TObject);
    procedure nbCarDataClick(Sender: TObject);
    procedure nbSetChargeLimitClick(Sender: TObject);
    procedure nbNavTestClick(Sender: TObject);
  private
    FCarState: String;
    CarStateCountDown: Integer;
    web: TWebBrowserWrapper;
    fs: TFormatSettings;
    idHTTP: TIdHTTP;
    IdSSL: TIdSSLIOHandlerSocketOpenSSL;
    function FormatFloat2(fmt: String; inp: Double): String;
    procedure ResetHTTPRequest;
    function REST_OAuth(out token: String; out info: String): Boolean;
    function REST_SetChargeLimit(newLimit: Integer; out info: String): Boolean;
    function REST_UpdateCarData(out data: TJSONData; out info: String): Boolean;
    function REST_UpdateCarState(out state, vehicle: String; out info: String
      ): Boolean;
    function REST_WAKEUP(out info: String): Boolean;
    function StrToFloat2(inp: String): Double;
    function tokm(inp: Double): String;
    procedure UpdateCarState(fillInfo: Boolean);
    Procedure UpdateCarData;
    procedure UpdateAuth;
    procedure SaveToken;
    procedure SetCarState(const Value: String);
    procedure WebNavigatTo(lon, lat: Double);
    procedure CreateIdHTTP;
    { Private-Deklarationen }
  public
    { Public-Deklarationen }
    property CarState: String read FCarState write SetCarState;
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}


uses
  StrUtils,
  iniFiles;


const
  CRLF =  #13#10;
  webPage : String =
  '<html><body>' + CRLF +
  '  <div id="mapdiv"></div>' + CRLF +
  '  <script src="http://www.openlayers.org/api/OpenLayers.js"></script>' + CRLF +
  '  <script>' + CRLF +
  '    map = new OpenLayers.Map("mapdiv");' + CRLF +
  '    map.addLayer(new OpenLayers.Layer.OSM());' + CRLF +
  '' + CRLF +
  '    var lonLat = new OpenLayers.LonLat( %lon% , %lat% )' + CRLF +
  '          .transform(' + CRLF +
  '            new OpenLayers.Projection("EPSG:4326"), // transform from WGS 1984' + CRLF +
  '            map.getProjectionObject() // to Spherical Mercator Projection' + CRLF +
  '          );' + CRLF +
  '          ' + CRLF +
  '    var zoom=16;' + CRLF +
  '' + CRLF +
  '    var markers = new OpenLayers.Layer.Markers( "Markers" );' + CRLF +
  '    map.addLayer(markers);' + CRLF +
  '    ' + CRLF +
  '    markers.addMarker(new OpenLayers.Marker(lonLat));' + CRLF +
  '    ' + CRLF +
  '    map.setCenter (lonLat, zoom);' + CRLF +
  '  </script>' + CRLF +
  '</body></html>';


const
  BASE_URL = 'https://owner-api.teslamotors.com/';


function TForm1.REST_OAuth(out token: String; out info: String): Boolean;
var
  url: String;
  js: TJSONObject;
  ss: TStringStream;
  jsd: TJSONData;
  res: String;
begin
  result := False;
  info := '';
  token := '';

  ResetHTTPRequest;
  ss := nil;
  jsd := nil;
  js := TJSONObject.Create;
  try
    js.add('grant_type', 'password');
    js.add('client_id', '81527cff06843c8634fdc09e8ac0abefb46ac849f38fe1e431c2ef2106796384');
    js.add('client_secret', 'c7257eb71a564034f9419ee651c7d0e5f7aa6bfbd18bafb5c5c033b093bb2fa3');
    js.add('email', edEmail.Text);
    js.add('password', edPassword.Text);

    ss := TStringStream.Create(js.AsJSON);

    url := BASE_URL + 'oauth/token';
    try
      res := idHttp.Post(url, ss);
      result := (idHttp.Response.ResponseCode div 100) = 2;
    except
    end;
    info := idHttp.Response.ResponseText + CRLF + res;
    if result then begin
      jsd := GetJSON(res);
      token := ( jsd.FindPath('access_token').AsString);
      info := jsd.FormatJSON();
      CreateIdHTTP;            //workaround
    end;
  finally
    jsd.Free;
    js.Free;
    ss.Free;
  end;
end;


function TForm1.REST_SetChargeLimit(newLimit: Integer; out info: String): Boolean;
var
  url: String;
  js: TJSONObject;
  ss: TStringStream;
  jsd: TJSONData;
  res: String;
begin
  result := False;
  info := '';

  ResetHTTPRequest;
  UpdateAuth;
  ss := nil;
  jsd := nil;
  js := TJSONObject.Create;
  try
    js.add('percent', IntToStr(newLimit));

    ss := TStringStream.Create(js.AsJSON);

    url := BASE_URL + 'api/1/vehicles/' + edVehicle.Text + '/command/set_charge_limit';
    try
      res := idHttp.Post(url, ss);
      result := (idHttp.Response.ResponseCode div 100) = 2;
    except
    end;
    info := idHttp.Response.ResponseText + CRLF + res;
    if result then begin
      jsd := GetJSON(res);
      info := jsd.FormatJSON();
    end;
  finally
    jsd.Free;
    js.Free;
    ss.Free;
  end;


end;


procedure TForm1.ResetHTTPRequest;
begin
  idHttp.Request.Clear;
  idHttp.Request.ContentType := 'application/json';
  idHttp.Request.BasicAuthentication := true;
  idHttp.Request.AcceptEncoding := '';
  idHttp.Request.Accept := 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8';
  //idHttp.Request.AcceptLanguage := 'pt-BR,pt;q=0.8,en-US;q=0.6,en;q=0.4';
  idHttp.Request.CacheControl := 'no-cache';

  idHttp.Response.ContentType := 'application/json';

end;

function TForm1.tokm(inp: Double): String;
begin
  result := FormatFloat('#0.0', inp * 1.60934);
end;

function TForm1.StrToFloat2(inp: String): Double;
begin
  result := StrToFloat(inp, fs);
end;

function TForm1.FormatFloat2(fmt: String; inp: Double): String;
begin
  result := FormatFloat(fmt, inp, fs);
end;

procedure TForm1.nbWakeClick(Sender: TObject);
var
  info: String;
begin
  REST_WAKEUP(info);
  edOAuthResult.Text := info;
  UpdateCarState(False);
end;

function TForm1.REST_WAKEUP(out info: String): Boolean;
var
  url: String;
  js: TJSONObject;
  ss: TStringStream;
  jsd: TJSONData;
  res: String;
begin
  result := False;
  info := '';

  ResetHTTPRequest;
  UpdateAuth;
  ss := nil;
  jsd := nil;
  js := TJSONObject.Create;
  try
    ss := TStringStream.Create(js.AsJSON);
    url := BASE_URL + 'api/1/vehicles/' + edVehicle.Text + '/wake_up';
    try
      res := idHttp.Post(url, ss);
      result := (idHttp.Response.ResponseCode div 100) = 2;
    except
    end;
    info := idHttp.Response.ResponseText + CRLF + res;
    if result then begin
      jsd := GetJSON(res);
      info := jsd.FormatJSON();
    end;
  finally
    jsd.Free;
    js.Free;
    ss.Free;
  end;
end;

procedure TForm1.SaveToken;
var
  ini: TMemIniFile;
begin
  ini := TMemIniFile.Create(Application.ExeName + '.ini');
  try
    ini.WriteString('Auth', 'Token', edToken.Text );
    ini.UpdateFile;
  finally
    ini.Free;
  end;
end;

procedure TForm1.SetCarState(const Value: String);
begin
  FCarState := Value;
end;

procedure TForm1.tiCheckCarStateTimer(Sender: TObject);
begin
  dec(CarStateCountDown);
  if (CarStateCountDown < 0) then begin
    CarStateCountDown := 60;
    UpdateCarState(False);
  end;
  lbCntDown.Caption := IntToStr(CarStateCountDown);
end;

procedure TForm1.UpdateAuth;
begin
  IdHTTP.Request.BasicAuthentication := False;
  IdHTTP.Request.CustomHeaders.FoldLines := False;
  IdHTTP.Request.CustomHeaders.Values['Authorization'] := 'Bearer ' + edToken.Text;
end;

procedure TForm1.UpdateCarData;
var
  lv: Double;
  exact: Double;
  data: TJSONData;
  info: String;

  function vs(path: String): String;
  begin
    result := data.FindPath(path).AsString;
  end;

  function vd(path: String): Double;
  var
    tmp: string;
  begin
    tmp := vs(path);
    result := StrToFloat2(tmp);
  end;

begin
  if (CarState = 'online') then begin
    if REST_UpdateCarData(data, info) then begin
      sgSoC.Cells[0, 1] := 'range';
      sgSoC.Cells[0, 2] := 'est.';
      sgSoC.Cells[0, 3] := 'ideal';
      lv := vd('response.charge_state.battery_level');
      sgSoC.Cells[1, 0] := FormatFloat('#0', lv) + '% (' +
        vs('response.charge_state.usable_battery_level') + '%)' ;
      sgSoC.Cells[2, 0] := '100%';

      sgSoC.Cells[1, 1] := tokm(vd('response.charge_state.battery_range')) + 'km';
      sgSoC.Cells[1, 2] := tokm(vd('response.charge_state.est_battery_range')) + 'km';
      sgSoC.Cells[1, 3] := tokm(vd('response.charge_state.ideal_battery_range')) + 'km';


      sgSoC.Cells[2, 1] := tokm(vd('response.charge_state.battery_range') / lv * 100) + 'km';
      sgSoC.Cells[2, 2] := tokm(vd('response.charge_state.est_battery_range') / lv * 100) + 'km';
      sgSoC.Cells[2, 3] := tokm(vd('response.charge_state.ideal_battery_range') / lv * 100) + 'km';

      exact := vd('response.charge_state.battery_range') / 310;
      sgSoC.Cells[3, 0] := FormatFloat('#0.00', exact * 100);

      sgSoC.Cells[3, 1] := tokm(vd('response.charge_state.battery_range') / exact ) + 'km';
      sgSoC.Cells[3, 2] := tokm(vd('response.charge_state.est_battery_range') / exact) + 'km';
      sgSoC.Cells[3, 3] := tokm(vd('response.charge_state.ideal_battery_range') / exact) + 'km';


      edChargeLimit.Value := StrToInt(vs('response.charge_state.charge_limit_soc'));

      lbDegrad.Caption := 'Degradiation: ' + FormatFloat('#0.000', 100 - (vd('response.charge_state.battery_range') / lv * 100 / 310 * 100)) + '%';

      WebNavigatTo(vd('response.drive_state.longitude') , vd('response.drive_state.latitude'));
      data.Free;
    end;
    edOAuthResult.Text := info;
  end else if CarState = 'asleep' then begin
  end else if CarState = 'offline' then begin
  end else begin
  end;
end;

function TForm1.REST_UpdateCarState(out state, vehicle: String; out info: String): Boolean;
var
  url: String;
  js: TJSONObject;
  jsd, r, c: TJSONData;
  res: String;
begin
  result := False;
  info := '';
  state := '';

  ResetHTTPRequest;
  UpdateAuth;
  jsd := nil;
  js := TJSONObject.Create;
  try

    url := BASE_URL + 'api/1/vehicles';
    try
      res := idHttp.Get(url);
      result := (idHttp.Response.ResponseCode div 100) = 2;
    except

    end;
    info := idHttp.Response.ResponseText + CRLF + res;
    if result then begin
      jsd := GetJSON(res);
      r := jsd.FindPath('response');
      c := r.FindPath('[0]');
      vehicle := c.FindPath('id').AsString;
      state := c.FindPath('state').AsString;
      info := jsd.FormatJSON();
    end;
  finally
    jsd.Free;
    js.Free;
  end;
end;

function TForm1.REST_UpdateCarData(out data: TJSONData; out info: String): Boolean;
var
  url: String;
  js: TJSONObject;
  jsd: TJSONData;
  res: String;
begin
  result := False;
  data := nil;
  info := '';

  ResetHTTPRequest;
  UpdateAuth;
  jsd := nil;
  js := TJSONObject.Create;
  try

    url := BASE_URL + 'api/1/vehicles/' + edVehicle.Text + '/data';
    try
      res := idHttp.Get(url);
      result := (idHttp.Response.ResponseCode div 100) = 2;
    except

    end;
    info := idHttp.Response.ResponseText + CRLF + res;
    if result then begin
      jsd := GetJSON(res);
      info := jsd.FormatJSON();
      data := jsd;
      jsd := nil;
    end;
  finally
    jsd.Free;
    js.Free;
  end;
end;


procedure TForm1.UpdateCarState(fillInfo: Boolean);
var
  state, vehicle, info: String;
begin
  if REST_UpdateCarState(state, vehicle, info) then begin
    nxButtons.PageIndex := 1;
    CarState := state;
    edVehicle.Text := vehicle;
    if fillInfo then begin
      edOAuthResult.Text := info;
    end;
  end else begin
    CarState := 'error';
    edOAuthResult.Text := info;
  end;
  lbCarState.Caption := CarState;
  lbCarState.Font.Style:= [fsBold];
end;



procedure TForm1.FormCreate(Sender: TObject);
var
  ini: TMemIniFile;
begin
  CreateIdHTTP;

  fs := DefaultFormatSettings;
  fs.DecimalSeparator:= '.';
  web := TWebBrowserWrapper.Create(ActiveXContainer1);

  CarStateCountDown := 60;
  nxButtons.PageIndex := 0;
  ini := TMemIniFile.Create(Application.ExeName + '.ini');
  try
    edToken.Text := ini.ReadString('Auth', 'Token', '');
  finally
    ini.Free;
  end;
  edVehicle.Text := '';
  edOAuthResult.Text := '';
  lbDegrad.Caption := '';
end;

procedure TForm1.nbCarDataClick(Sender: TObject);
begin
  UpdateCarState(False);
  UpdateCarData;
end;

procedure TForm1.nbOAuthClick(Sender: TObject);
var
  token, info: String;
begin
  if edToken.Text = '' then begin
    if REST_OAuth(token, info) then begin
      edToken.Text := token;
      Application.ProcessMessages;
      SaveToken;
    end;
    edOAuthResult.Text := info;
  end;
  UpdateCarState(True);

  tiCheckCarState.Enabled := True;
end;

procedure TForm1.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  if CloseAction = caFree then begin
    SaveToken;
  end;
end;

procedure TForm1.nbNavTestClick(Sender: TObject);
begin
  WebNavigatTo(12, 45);
end;

procedure TForm1.WebNavigatTo(lon, lat: Double);
var
  tmp: String;
begin
  tmp := ReplaceStr(webPage, '%lon%', FormatFloat2('#0.0000000', lon));
  tmp := ReplaceStr(tmp, '%lat%', FormatFloat2('#0.0000000', lat));
  web.LoadFromString(tmp);
end;

procedure TForm1.CreateIdHTTP;
begin
  FreeAndNil(IdSSL);
  FreeAndNil(idHTTP);

  idHTTP := TIdHTTP.Create(self);
  idHTTP.HTTPOptions := [hoNoProtocolErrorException];
  IdSSL := TIdSSLIOHandlerSocketOpenSSL.Create(self);
  IdSSL.SSLOptions.SSLVersions := [sslvSSLv23];
  idHTTP.IOHandler := IdSSL;
end;

procedure TForm1.nbSetChargeLimitClick(Sender: TObject);
var
  info: String;
begin
  REST_SetChargeLimit(edChargeLimit.Value, info);
  edOAuthResult.Text := info;
  UpdateCarState(False);
end;


end.
