unit uMain;

interface

uses
    Winapi.Windows
  , System.SysUtils
  , System.Classes
  , Vcl.Controls
  , Vcl.Forms
  , Vcl.Dialogs
  , Data.DB
  , Vcl.Grids
  , Vcl.DBGrids
  , Vcl.StdCtrls
  , Vcl.ExtCtrls
  , RO.DBConnectionIntf
  , RO.DBGenericImpl
  , RO.DBUniImpl
  , ConnectionInfoIntf
  , ConnectionInfo
  ;

type
  TfMain = class(TForm)
    pnlMenu: TPanel;
    lblTitle: TLabel;
    lblHostname: TLabel;
    edHostname: TEdit;
    lblDatabase: TLabel;
    edDatabase: TEdit;
    lblUsername: TLabel;
    edUsername: TEdit;
    lblPassword: TLabel;
    edPassword: TEdit;
    bConnect: TButton;
    bExit: TButton;
    gridPosts: TDBGrid;
    edPort: TEdit;
    lblPort: TLabel;
    dsPosts: TDataSource;
    lblHowTo: TLabel;
    lblHowToDetail: TLabel;
    edTablePreffix: TEdit;
    lblTablePreffix: TLabel;
    procedure bExitClick(Sender: TObject);
    procedure bConnectClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure MemoHandler(Sender: TField; var Text: string; DisplayText: Boolean);
    procedure gridPostsDblClick(Sender: TObject);
    procedure gridPostsKeyPress(Sender: TObject; var Key: Char);
    procedure gridPostsTitleClick(Column: TColumn);
  private type
    TOrderField = object
    private
      FFieldName: string;
      FDesc: Boolean;
      procedure SetFieldName(Value: string);
    public
      property FieldName: string write SetFieldName;
      function AsString: string;
    end;
  private
    OrderField: TOrderField;
    dbSQL: IDatabase;
    qPosts: IDBQuery;
    ConnectionInfo: IConnectionInfo;
    procedure LoadConnectionInfo;
    procedure SaveConnectionInfo;
    procedure LoadPosts(const FieldName: string);
    procedure ChangePageViews(const PostID: Integer; const NewValue: LongWord);
  end;

var
  fMain: TfMain;

implementation

uses
    RO.TIf
  ;

{$R *.dfm}

procedure TfMain.bConnectClick(Sender: TObject);
begin
  if edHostname.Text = ''
    then begin
      edHostname.SetFocus;
      Exit;
    end;

  dbSQL := TDatabase.New(
    TServer.New(
      edHostname.Text,
      StrToInt(edPort.Text),
      edUsername.Text,
      edPassword.Text,
      TServerType.stMySQL
    ),
    edDatabase.Text
  ).Connect;

  if dbSQL.IsConnected
    then begin
      SaveConnectionInfo;
      LoadPosts('post_title');
      gridPosts.SetFocus;
    end
    else begin
      ShowMessage('It was not possible to establish a connection to the server. . .');
    end;
end;

procedure TfMain.bExitClick(Sender: TObject);
begin
  if Assigned(dbSQL)
    then dbSQL.Disconnect;
  Application.Terminate;
end;

procedure TfMain.ChangePageViews(const PostID: Integer; const NewValue: LongWord);
begin
  if MessageDlg(
       Format('%d will be saved as the new page views value.'#10'Confirm?', [NewValue]),
       mtConfirmation,
       [mbYes, mbNo],
       0,
       mbYes
     ) = mrYes
    then begin
      dbSQL.Run(
        TSQLStatement.New(
          'UPDATE ' + edTablePreffix.Text + 'popularpostsdata ' +
          '   SET pageviews = ' + NewValue.ToString + ' ' +
          ' WHERE postid = ' + PostID.ToString
        )
      );
      dsPosts.Dataset.Refresh;
    end;
end;

procedure TfMain.FormCreate(Sender: TObject);
begin
  lblHowToDetail.Caption :=
    '1. Insert your server access data'#10 +
    '2. Click ''Connect'''#10 +
    '3. Double Click the post you need to change'#10 +
    '4. Insert new value'#10 +
    #10 +
    'Clicking in the column title sorts the column';
  ConnectionInfo := TConnectionInfo.New(
    ChangeFileExt(
      ParamStr(0),
      '.ini'
    )
  );
end;

procedure TfMain.FormShow(Sender: TObject);
begin
  LoadConnectionInfo;
  if edHostname.Text <> ''
    then bConnect.SetFocus;
end;

procedure TfMain.gridPostsDblClick(Sender: TObject);
var
  NewValue: Integer;
begin
  try
    NewValue := StrToInt(
      InputBox(
        'Replace page views value',
        Format('What is the new value for post '#10'"%s"?', [dsPosts.DataSet.FieldByName('post_title').AsString]),
        dsPosts.DataSet.FieldByName('pageviews').AsString
      )
    );
  except
    on E: EConvertError do
      begin
        ShowMessage('Value must be a number.');
        NewValue := dsPosts.DataSet.FieldByName('pageviews').AsInteger;
      end;
  end;

  if NewValue <> dsPosts.DataSet.FieldByName('pageviews').AsInteger
    then begin
      ChangePageViews(
        dsPosts.DataSet.FieldByName('ID').AsInteger,
        NewValue
      );
    end;
end;

procedure TfMain.gridPostsKeyPress(Sender: TObject; var Key: Char);
begin
  if (Key = #13) and Assigned(dsPosts.DataSet) and (dsPosts.DataSet.RecordCount > 0)
    then begin
      gridPostsDblClick(Sender);
      Key := #0;
    end;
end;

procedure TfMain.gridPostsTitleClick(Column: TColumn);
begin
  LoadPosts(Column.FieldName);
end;

procedure TfMain.LoadConnectionInfo;
begin
  edHostname.Text     := ConnectionInfo.Hostname;
  edPort.Text         := ConnectionInfo.Port.ToString;
  edDatabase.Text     := ConnectionInfo.Database;
  edTablePreffix.Text := ConnectionInfo.TablePreffix;
  edUsername.Text     := ConnectionInfo.Username;
  edPassword.Text     := ConnectionInfo.Password;
end;

procedure TfMain.LoadPosts(const FieldName: string);
begin
  OrderField.FieldName := FieldName;
  qPosts := dbSQL.NewQuery(
    TSQLStatement.New(
      'select ' + edTablePreffix.Text + 'posts.ID, ' + edTablePreffix.Text + 'posts.post_title, ' + edTablePreffix.Text + 'popularpostsdata.pageviews '+
      '  from ' + edTablePreffix.Text + 'posts '+
      ' inner join ' + edTablePreffix.Text + 'popularpostsdata on ' + edTablePreffix.Text + 'popularpostsdata.postid = ' + edTablePreffix.Text + 'posts.ID '+
      ' where post_status = ''publish'' '+
      '   and post_title <> '''' '+
      ' order by ' + OrderField.AsString
    )
  ).Run
   .Publish(dsPosts);
  dsPosts.DataSet.FieldByName('post_title').OnGetText := MemoHandler;
end;

procedure TfMain.MemoHandler(Sender: TField; var Text: string; DisplayText: Boolean);
begin
  Text := Copy(dsPosts.DataSet.FieldByName('post_title').AsString, 1, 400);
end;

procedure TfMain.SaveConnectionInfo;
begin
  ConnectionInfo.Hostname     := edHostname.Text;
  ConnectionInfo.Port         := StrToInt(edPort.Text);
  ConnectionInfo.Database     := edDatabase.Text;
  ConnectionInfo.TablePreffix := edTablePreffix.Text;
  ConnectionInfo.Username     := edUsername.Text;
  ConnectionInfo.Password     := edPassword.Text;
end;

{ TfMain.TOrderField }

function TfMain.TOrderField.AsString: string;
begin
  Result := TIf<string>.New(
    FDesc,
    FFieldName + ' DESC',
    FFieldName
  ).Eval;
end;

procedure TfMain.TOrderField.SetFieldName(Value: string);
begin
  FDesc := TIf<Boolean>.New(
    Value = FFieldName,
    not FDesc,
    False
  ).Eval;
  FFieldName := Value;
end;

end.
