{
  Merge Plugins Script v1.8.7
  Created by matortheeternal
  http://skyrim.nexusmods.com/mod/37981
  
  *CHANGES*
  v1.8.7
  - Internal logging now used instead of TES5Edit logging.  Some TES5Edit
    log messages will still be used.  Logs are automatically saved to a
    text document in Edit Scripts/mp/logs/merge_<date>_<time>.txt.  The
    log can be viewed during execution by clicking on the Show Details
    button.
  - Logs folder is automatically created if it didn't exist before the
    script was executed.
  - New separate "Advanced Options" window for setting script options.
  - Settings specified in the advanced options window will be saved to a
    the file Edit Scripts\mp\config.ini whenever you click OK.  These 
    settings are then loaded and used each time the script is run in the
    future.
  - Automatic detection of Mod Organizer's directory has been added.
  - Log saves even if script terminates prematurely.
  - Better messages when a record fails to copy.
  - Note: Several of the options in the Advanced Options window are
    disabled because they haven't been implemented yet.
  - New option: Renumber Conflicting FormIDs only renumbers FormIDs that 
    conflict with each other.  
  - Fixed asset copying to work with MO's virtual data directory as well 
    as a real Skyrim data directory (e.g. NMM or manual installation).
  - Fixed renumbering methods to not terminate prematurely.
  - Made it so the script will wait for the user to close the progress 
    window after execution instead of closing it automatically.
  - Enhanced the advanced options GUI with hints and messages to help 
    the user use the script properly.
  - Added separate Asset destination directory so the user can set where 
    the script copies assets to.
  - Added CopyAll option, which copies assets from Mod Organizer mod 
    folders to the asset destination folder.
  - Fixed reference redirection error in Renumber Conflicting FormIDs 
    method.
  - Added BSA extraction.
  - Added asset destination directory helper which will help the user if 
    the directory they have set isn't empty. 
  - Improved logging and clearer difference between normal mode and 
    debug mode.
  - File Specific asset copying fixed to also copy from BSAs.
  
    
  *DESCRIPTION*
  This script will allow you to merge ESP files.  This won't work on files with 
  corrupted data.  You can set user variables at in the constants section (const) 
  to customize how the script runs.
}

unit mergePlugins;

uses mteFunctions;

const
  vs = 'v1.8.7';
  dashes = '-----------------------------------------------------------------------------';
  debug = false; // debug messages
  mcmdebug = false;
  debugsearch = false;

var
  slMerge, slMasters, slFails, slSelectedFiles, slMgfMasters, slDictionary, 
  slTranslations, slCopiedFrom: TStringList;
  OldForms, NewForms: TList;
  rn, mm, sp, rCount: integer;
  moPath, astPath, bsaName: string;
  SkipProcess, disableColoring, extractBSAs, disableESPs, 
  usingMo, copyAll, firstRun: boolean;
  mgf: IInterface;
  cbArray: Array[0..254] of TCheckBox;
  lbArray: Array[0..254] of TLabel;
  slArray: Array[0..30] of TStringList;
  frm: TForm;
  memo: TMemo;
  mnPopup: TPopupMenu;
  btnDetails, btnSave: TButton;
  gear, browse: TPicture;
  cb1, cb2: TCheckbox;
  btnFind: TButton;
  ed1, ed2: TEdit;
  imgBrowse1, imgBrowse2, imgBrowse3: TImage;
 
 
{*************************************************************************}
{***************************** GUI Functions *****************************}
{*************************************************************************}

//=========================================================================
// LogMessage: Posts a message to the log stringlist
procedure LogMessage(msg: String);
begin
  memo.Lines.add(msg);
end;
  
//=========================================================================
// GetDefinitionHint: Generates a hint based on the definition
function GetDefinitionHint(sl: TStringList): string;
var
  notes: String;
begin
  if sl.Count < 6 then
    Result := 'No user reports for this plugin have been submitted.'
  else begin
    notes := Trim(StringReplace(sl[5], '@13', #13, [rfReplaceAll]));
    Result := 'Average rating: '+sl[3]+#13+'Number of ratings: '+sl[4]+#13+'User notes: '+#13+notes;
  end;
end;
  
//=========================================================================
// GetMergeColor: gets the color associated with the file's merge rating
function GetMergeColor(sl: TStringList): integer;
var
  rating, k1, k2: float;
  c1, c2, c3, fc: TColor;
begin
  if sl.Count < 2 then
    Result := $404040
  else begin
    c1.Red := $FF; c1.Green := $00; c1.Blue := $00;
    c2.Red := $E5; c2.Green := $A8; c2.Blue := $00;
    c3.Red := $00; c3.Green := $90; c3.Blue := $00;
    fc.Blue := $00;
    rating := StrToFloat(sl[3]);
    if (rating > 2.0) then begin
      k2 := (rating - 2.0)/2.0;
      k1 := 1.0 - k2;
      fc.Red := c2.Red * k1 + c3.Red * k2;
      fc.Green := c2.Green * k1 + c3.Green * k2;
    end
    else begin
      k2 := (rating/2.0);
      k1 := 1.0 - k2;
      fc.Red := c1.Red * k1 + c2.Red * k2;
      fc.Green := c1.Green * k1 + c2.Green * k2;
    end;
    Result := ColorToInt(fc.Red, fc.Green, fc.Blue);
  end;
end;

//=========================================================================
// GetDefinition: gets a definition for the file from the dictionary
function GetDefinition(f: IInterface; r: boolean; v: boolean): string;
var
  i: integer;
  search: string;
begin
  Result := '';
  search := GetFileName(f) + ';';
  if r then
    search := search + IntToStr(RecordCount(f)) + ';';
  if v then
    search := search + vs + ';';
  for i := 0 to Pred(slDictionary.Count) do begin
    if Pos(search, slDictionary[i]) = 1 then begin
      Result := slDictionary[i];
      break;
    end;
  end;
end;

//=========================================================================
// FileSelectM: File selection window for merging
function FileSelectM(lbl: string): IInterface;
var
  cmbFiles: TComboBox;
  btnOk, btnCancel: TButton;
  lbl01: TLabel;
  i, j, llo: integer;
  s: string;
  f: IInterface;
begin
  frm := TForm.Create(frm);
  try
    frm.Caption := 'Select File';
    frm.Width := 290;
    frm.Height := 190;
    frm.Position := poScreenCenter;
    
    lbl01 := TLabel.Create(frm);
    lbl01.Parent := frm;
    lbl01.Width := 250;
    lbl01.Height := 60;
    lbl01.Left := 8;
    lbl01.Top := 8;
    lbl01.Caption := lbl;
    lbl01.Autosize := false;
    lbl01.Wordwrap := True;
    
    cmbFiles := TComboBox.Create(frm);
    cmbFiles.Parent := frm;
    cmbFiles.Items.Add('-- CREATE NEW FILE --');
    cmbFiles.Style := csDropDownList;
    cmbFiles.Top := 33 + lbl01.Height;
    cmbFiles.Left := 8;
    cmbFiles.Width := 225;
    llo := 0;
    
    for j := 0 to slMerge.Count - 1 do 
      if llo < Integer(slMerge.Objects[j]) then 
        llo := Integer(slMerge.Objects[j]);
    for i := 0 to FileCount - 1 do begin
      s := GetFileName(FileByIndex(i));
      if Pos(s, bethesdaFiles) > 0 then Continue;
      if slMerge.IndexOf(s) > -1 then Continue;
      if GetLoadOrder(FileByIndex(i)) < llo then Continue;
      cmbFiles.Items.Add(s);
    end;
    cmbFiles.ItemIndex := 0;
    
    ConstructOkCancelButtons(frm, frm, cmbFiles.Top + 50);
    
    if frm.ShowModal = mrOk then begin
      if (cmbFiles.Items[cmbFiles.ItemIndex] = '-- CREATE NEW FILE --') then begin
        f := AddNewFile;
        Result := f;
      end
      else begin
        for i := 0 to FileCount - 1 do begin
          if (cmbFiles.Items[cmbFiles.ItemIndex] = GetFileName(FileByIndex(i))) then begin
            Result := FileByIndex(i);
            Continue;
          end;
          if i = FileCount - 1 then begin
            AddMessage('The script couldn''t find the file you entered.');
            Result := FileSelectM(lbl);
          end;
        end;
      end;
    end;
  finally
    frm.Free;
  end;
end;

//=========================================================================
// CheckDirectories: Checks if ed1 and ed2 directories are valid.
procedure ofrm.CheckDirectories;
var
  moValid, astValid: boolean;
begin
  moValid := DirectoryExists(ed1.Caption);
  astValid := DirectoryExists(ed2.Caption);
  btnSave.Enabled := (moValid or not cb1.Checked) and astValid;
end;

//=========================================================================
// MoPathHelper: Tells the user if their Mod Organizer path is invalid
procedure ofrm.MoPathHelper;
var
  moValid: boolean;
begin
  moValid := DirectoryExists(ed1.Caption);
  if not moValid then begin
    // tell user their mod organizer path is invalid
    MessageDlg('Your Mod Organizer path is invalid. Either enter a valid '
      'path or uncheck "I''m using Mod Organizer".', mtConfirmation, [mbOk], 0);
  end;
end;

//=========================================================================
// AssetPathHelper: Tells the user if their asset path is invalid
procedure ofrm.AssetPathHelper;
var
  astValid: boolean;
begin
  astValid := DirectoryExists(ed2.Caption);
  if not astValid then begin
    // tell user their asset is invalid
    MessageDlg('Your asset destination directory is invalid. Please enter '
      'a valid path.', mtConfirmation, [mbOk], 0);
  end;
end;

//=========================================================================
// AssetPathBrowse: Browse for asset destination path
procedure ofrm.AssetPathBrowse;
var
  s: string;
begin
  if DirectoryExists(ed2.Caption) then
    s := SelectDirectory('Select a directory', '', ed2.Text, '')
  else if cb1.Checked and DirectoryExists(ed1.Caption) then
    s := SelectDirectory('Select a directory', '', ed1.Text, '')
  else
    s := SelectDirectory('Select a directory', '', DataPath, '');
  if s <> '' then begin
    ed2.Text := s + '\';
  end;
end;

//=========================================================================
// MoPathBrowse: Browse for Mod Organizer path
procedure ofrm.MoPathBrowse;
var
  s: string;
begin
  s := SelectDirectory('Select a directory', '', ed1.Text, '');
  if s <> '' then begin
    ed1.Text := s + '\';
  end;
end;

//=========================================================================
// UsingModOrganizer: Toggle for controls
procedure ofrm.UsingModOrganizer;
begin
  ed1.Enabled := cb1.Checked;
  btnFind.Enabled := cb1.Checked;
  cb2.Enabled := cb1.Checked;
  imgBrowse1.Enabled := cb1.Checked;
  CheckDirectories;
end;

//=========================================================================
procedure ofrm.DetectModOrganizer;
var
  i: int;
  modOrganizerPath, paths, v: string;
  pathList: TStringList;
  rec: TSearchRec;
begin
  for i := 65 to 90 do begin
    paths := paths + chr(i) + ':\Program Files;' + chr(i) + ':\Program Files (x86);';
  end;
  
  modOrganizerPath := FileSearch('Mod Organizer\ModOrganizer.exe', paths);
  if (modOrganizerPath = '') then begin
    // search each folder in each valid Program Files directory for ModOrganizer.exe
    pathList := TStringList.Create;
    while (Pos(';', paths) > 0) do begin
      pathList.Add(Copy(paths, 1, Pos(';', paths) - 1));
      paths := Copy(paths, Pos(';', paths) + 1, Length(paths));
    end;
    for i := 0 to pathList.Count - 1 do begin
      if FindFirst(pathList[i] + '\*', faDirectory, rec) = 0 then begin
        repeat
          if debugsearch then AddMessage('Searching '+pathList[i]+'\'+rec.Name);
          modOrganizerPath := FileSearch('ModOrganizer.exe', pathList[i] + '\' + rec.Name);
          if (modOrganizerPath <> '') then begin
            //modOrganizerPath := Copy(modOrganizerPath, 1, Length(modOrganizerPath) - 1);
            break;
          end;
        until FindNext(rec) <> 0;
        
        FindClose(rec);
        if (modOrganizerPath <> '') then break;
      end;
    end;
  end;
  
  if (modOrganizerPath <> '') then begin
    ed1.Caption := Copy(modOrganizerPath, 1, length(modOrganizerPath) - 16);
    ed2.Caption := ed1.Caption + 'overwrite\';
  end
  else begin
    AddMessage('Couldn''t automatically detect Mod Organizer''s file path.  Please enter it manually.');
    ed1.Caption := '';
  end;
end;

//=========================================================================
// SaveSettings: Saves the current script settings/options
procedure SaveSettings;
var
  ini: TMemIniFile;
begin
  ini := TMemIniFile.Create(ScriptsPath + 'mp\config.ini');
  if usingMO then ini.WriteString('Config', 'usingMO', '1')
  else ini.WriteString('Config', 'usingMO', '0');
  ini.WriteString('Config', 'moPath', moPath);
  ini.WriteString('Config', 'astPath', astPath);
  if copyAll then ini.WriteString('Config', 'copyAllAssets', '1')
  else ini.WriteString('Config', 'copyAllAssets', '0');
  ini.WriteString('Config', 'renumberingMode', IntToStr(rn));
  ini.WriteString('Config', 'copyMode', IntToStr(mm));
  ini.WriteString('Config', 'secondPassMode', IntToStr(sp));
  if disableColoring then ini.WriteString('Config', 'disableColoring', '1')
  else ini.WriteString('Config', 'disableColoring', '0');
  if extractBSAs then ini.WriteString('Config', 'extractBSAs', '1')
  else ini.WriteString('Config', 'extractBSAs', '0');
  if disableESPs then ini.WriteString('Config', 'disableESPs', '1')
  else ini.WriteString('Config', 'disableESPs', '0');
  ini.UpdateFile;
end;

//=========================================================================
// SaveSettings: Saves the current script settings/options
procedure LoadSettings;
var
  ini: TMemIniFile;
  cfgPath: string;
begin
  cfgPath := FileSearch('mp\config.ini', ScriptsPath);
  if (cfgPath = '') then begin
    MessageDlg('It seems this is the first time you''re running the script.  Please set up your '
      'advanced options for future merges.  The window will come up automatically, and you can '
      'get back to it at any time by clicking the gear in the bottom right corner of the script '
      'window.', mtConfirmation, [mbOk], 0);
    firstRun := true;
  end;
  ini := TMemIniFile.Create(ScriptsPath + 'mp\config.ini');
  usingMO := (ini.ReadString('Config', 'usingMO', '0') = '1');
  moPath := ini.ReadString('Config', 'moPath', '');
  astPath := ini.ReadSTring('Config', 'astPath', DataPath);
  copyAll := (ini.ReadString('Config', 'copyAllAssets', '0') = '1');
  rn := IntToStr(ini.ReadString('Config', 'renumberingMode', '1'));
  mm := IntToStr(ini.ReadString('Config', 'copyMode', '1'));
  sp := IntToStr(ini.ReadString('Config', 'secondPassMode', '1'));
  disableColoring := (ini.ReadString('Config', 'disableColoring', '0') = '1');
  extractBSAs := (ini.ReadString('Config', 'extractBSAs', '0') = '1');
  disableESPs := (ini.ReadString('Config', 'disableESPs', '0') = '1');
end;

//=========================================================================
// AdvancedOptions: 
procedure AdvancedOptions;
var
  ofrm: TForm;
  lbl1, lbl2: TLabel;
  cb3, cb4, cb5: TCheckBox;
  gb1, gb2: TGroupBox;
  btnDiscard: TButton;
  rg1, rg2, rg3: TRadioGroup;
  rb1, rb2, rb3, rb4, rb5, rb6, rb7, rb8, rb9: TRadioButton;
begin
  ofrm := TForm.Create(nil);
  try
    ofrm.Caption := 'Advanced Options';
    ofrm.Width := 610;
    ofrm.Position := poScreenCenter;
    ofrm.Height := 550;
    
    gb1 := TGroupBox.Create(ofrm);
    gb1.Parent := ofrm;
    gb1.Left := 16;
    gb1.Height := 120;
    gb1.Top := 16;
    gb1.Width := 560;
    gb1.Caption := 'Mod Organizer options';
    gb1.ClientHeight := 105;
    gb1.ClientWidth := 556;
    
    cb1 := TCheckBox.Create(gb1);
    cb1.Parent := gb1;
    cb1.Left := 16;
    cb1.Top := 20;
    cb1.Width := 150;
    cb1.Caption := ' I''m using Mod Organizer';
    cb1.Checked := usingMO;
    cb1.OnClick := UsingModOrganizer;
    cb1.Hint := 
      'You must check this for asset copying to work correctly if you''re'#13
      'using Mod Organizer.  This must not be checked if you''re not using'#13
      'Mod Organizer.';
    cb1.ShowHint := true;
    
    lbl1 := TLabel.Create(gb1);
    lbl1.Parent := gb1;
    lbl1.Left := 16;
    lbl1.Top := cb1.Top + cb1.Height + 12;
    lbl1.Width := 90;
    lbl1.Caption := 'Mod Organizer directory: ';
    
    ed1 := TEdit.Create(gb1);
    ed1.Parent := gb1;
    ed1.Left := lbl1.Left + lbl1.Width + 24;
    ed1.Top := lbl1.Top;
    ed1.Width := 250;
    ed1.Caption := moPath;
    ed1.Enabled := usingMO;
    ed1.Hint := 
      'The path to the folder containing ModOrganizer.exe.  This path must be entered'#13
      'if you checked the "I''m using Mod Organizer" checkbox.';
    ed1.ShowHint := true;
    ed1.OnChange := CheckDirectories;
    ed1.OnExit := MoPathHelper;
    
    imgBrowse1 := TImage.Create(gb1);
    imgBrowse1.Parent := gb1;
    imgBrowse1.Picture := browse;
    imgBrowse1.Width := 18;
    imgBrowse1.Height := 18;
    imgBrowse1.ShowHint := true;
    imgBrowse1.Hint := 'Browse for Mod Organizer';
    imgBrowse1.Enabled := usingMO;
    imgBrowse1.OnClick := MoPathBrowse;
    imgBrowse1.Left := ed1.Left + ed1.Width + 8;
    imgBrowse1.Top := ed1.Top;
    
    btnFind := TButton.Create(gb1);
    btnFind.Parent := ofrm;
    btnFind.Caption := 'Detect';
    btnFind.ShowHint := true;
    btnFind.Hint :=
      'Have the script attempt to find Mod Organizer on your hard drive by searching'#13
      'locations where it is usually installed.  If MO is found, directories will be'#13
      'automatically updated.';
    btnFind.Left := imgBrowse1.Left + imgBrowse1.Width + 24;
    btnFind.Top := lbl1.Top + btnFind.Height div 2;
    btnFind.OnClick := DetectModOrganizer;
    btnFind.Enabled := usingMO;
    
    cb2 := TCheckBox.Create(gb1);
    cb2.Parent := gb1;
    cb2.Left := 16;
    cb2.Top := lbl1.Top + lbl1.Height + 12;
    cb2.Width := 140;
    cb2.Caption := ' Copy general assets';
    cb2.Checked := copyAll;
    cb2.Enabled := usingMO;
    cb2.Hint := 
      'Have the script copy general assets from the Mod Organizer mod folders associated'#13
      'with the ESPs you''re merging.  This will make it so you have to do no file copying'#13
      'in Mod Organizer after merging.';
    cb2.ShowHint := true;
    
    rg1 := TRadioGroup.Create(ofrm);
    rg1.Parent := ofrm;
    rg1.Left := 16;
    rg1.Height := 60;
    rg1.Top := gb1.Top + gb1.Height + 12;
    rg1.Width := 560;
    rg1.Caption := 'Renumbering options';
    rg1.ClientHeight := 45;
    rg1.ClientWidth := 556;
    
    rb1 := TRadioButton.Create(rg1);
    rb1.Parent := rg1;
    rb1.Left := 26;
    rb1.Top := 18;
    rb1.Caption := 'Don''t renumber FormIDs';
    rb1.ShowHint := true;
    rb1.Hint := 
      'You can use this option, but if there are any records with the same local FormIDs'#13
      'in the files you''re merging, they will cause errors ingame.';
    rb1.Width := 160;
    rb1.Checked := (rn = 0);
    
    rb2 := TRadioButton.Create(rg1);
    rb2.Parent := rg1;
    rb2.Left := rb1.Left + rb1.Width + 16;
    rb2.Top := rb1.Top;
    rb2.Caption := 'Renumber conflicting FormIDs';
    rb2.ShowHint := true;
    rb2.Hint :=
      'This is the best option for you to use.  Only FormIDs that conflict are renumbered'#13
      'when you use this option.';
    rb2.Width := 160;
    rb2.Checked := (rn = 1);
    
    rb3 := TRadioButton.Create(rg1);
    rb3.Parent := rg1;
    rb3.Left := rb2.Left + rb2.Width + 16;
    rb3.Top := rb1.Top;
    rb3.Caption := 'Renumber all FormIDs';
    rb3.ShowHint := true;
    rb3.Hint :=
      'This will make sure there are no conflicts in any FormIDs, but it can also create'#13
      'problems.  It''s best to use Renumber conflicting FormIDs.';
    rb3.Width := 160;
    rb3.Checked := (rn = 2);
    
    rg2 := TRadioGroup.Create(ofrm);
    rg2.Parent := ofrm;
    rg2.Left := rg1.Left;
    rg2.Height := rg1.Height;
    rg2.Top := rg1.Top + rg1.Height + 16;
    rg2.Width := rg1.Width;
    rg2.Caption := 'Copying options';
    rg2.ClientHeight := rg1.ClientHeight;
    rg2.ClientWidth := rg1.ClientWidth;
    
    rb4 := TRadioButton.Create(rg2);
    rb4.Parent := rg2;
    rb4.Left := 26;
    rb4.Top := 18;
    rb4.Caption := 'Copy records';
    rb4.ShowHint := true;
    rb4.Hint :=
      'This option will copy every record in the files to be merged to the merged file.'#13
      'Because some records actually hold other records (e.g. Cells), this can lead to'#13
      'the same records being copied twice, making it slower than it needs to be.';
    rb4.Width := 160;
    rb4.Checked := (mm = 0);
    
    rb5 := TRadioButton.Create(rg2);
    rb5.Parent := rg2;
    rb5.Left := rb4.Left + rb4.Width + 16;
    rb5.Top := rb4.Top;
    rb5.Caption := 'Copy intelligently';
    rb5.ShowHint := true;
    rb5.Hint :=
      'This option will recursively traverse the record groups in the files to be merged,'#13
      'copying found records to the merged file.  The recursion will stop at records that'#13
      'hold other records (e.g. Cells), so no record will be copied twice.';
    rb5.Width := 160;
    rb5.Checked := (mm = 1);
    
    rb6 := TRadioButton.Create(rg2);
    rb6.Parent := rg2;
    rb6.Left := rb5.Left + rb5.Width + 16;
    rb6.Top := rb4.Top;
    rb6.Caption := 'Copy groups';
    rb6.ShowHint := true;
    rb6.Hint :=
      'This option will copy the record groups from the files to be merged to the merged file.'#13
      'The issue with this option is if something goes wrong copying any record in a group,'#13
      'the entire record group may fail to copy and you will have trouble finding the record'#13
      'responsible for the failure.';
    rb6.Width := 160;
    rb6.Checked := (mm = 2);
    
    rg3 := TRadioGroup.Create(ofrm);
    rg3.Parent := ofrm;
    rg3.Left := rg1.Left;
    rg3.Height := rg1.Height;
    rg3.Top := rg2.Top + rg2.Height + 16;
    rg3.Width := rg1.Width;
    rg3.Caption := 'Second pass copying options';
    rg3.ClientHeight := rg1.ClientHeight;
    rg3.ClientWidth := rg1.ClientWidth;
    
    rb7 := TRadioButton.Create(rg3);
    rb7.Parent := rg3;
    rb7.Left := 26;
    rb7.Top := 18;
    rb7.Caption := 'No second pass';
    rb7.ShowHint := true;
    rb7.Hint :=
      'Second pass copying forces certain records which often fail to associate with each other'#13
      'to work more often.  Not using a second pass will save on merge time, but can lead to issues'#13
      'with mods that alter NavMeshs or that are heavily scripted.';
    rb7.Width := 160;
    rb7.Checked := (sp = 0);
    
    rb8 := TRadioButton.Create(rg3);
    rb8.Parent := rg3;
    rb8.Left := rb7.Left + rb7.Width + 16;
    rb8.Top := rb7.Top;
    rb8.Caption := 'Second pass same as first';
    rb8.ShowHint := true;
    rb8.Hint :=
      'This second pass method will use the same copying method you selected above.  This is the'#13
      'best option for second pass copying.';
    rb8.Width := 160;
    rb8.Checked := (sp = 1);
    
    rb9 := TRadioButton.Create(rg3);
    rb9.Parent := rg3;
    rb9.Left := rb8.Left + rb8.Width + 16;
    rb9.Top := rb7.Top;
    rb9.Caption := 'Second pass copy by groups';
    rb9.ShowHint := true;
    rb9.Hint :=
      'The original second pass copying routine.  It''s main downfall is if a single record in'#13
      'a record group fails to copy, the entire record group may fail to copy.  May be more stable'#13
      'than the Second pass same as first option.';
    rb9.Width := 160;
    rb9.Checked := (sp = 2);
    
    gb2 := TGroupBox.Create(ofrm);
    gb2.Parent := ofrm;
    gb2.Left := 16;
    gb2.Height := 150;
    gb2.Top := rg3.Top + rg3.Height + 16;
    gb2.Width := 560;
    gb2.Caption := 'Other options';
    gb2.ClientHeight := 135;
    gb2.ClientWidth := 556;
    
    lbl2 := TLabel.Create(gb2);
    lbl2.Parent := gb2;
    lbl2.Left := 16;
    lbl2.Top := 25;
    lbl2.Width := 90;
    lbl2.Caption := 'Asset destination directory: ';
    
    ed2 := TEdit.Create(gb2);
    ed2.Parent := gb2;
    ed2.Left := ed1.Left;
    ed2.Top := lbl2.Top;
    ed2.Width := 350;
    ed2.Caption := astPath;
    ed2.Hint := 
      'Destination folder for assets that are copied by the script.  If you''re using'#13
      'Mod Organizer this should be the overwrite folder in Mod Organizer''s'#13
      'directory.  If you''re not using Mod Organizer this should be your Skyrim'#13
      'data folder or another location you''ve decided on for holding assets.';
    ed2.ShowHint := true;
    ed2.OnChange := CheckDirectories;
    ed2.OnExit := AssetPathHelper;
    
    imgBrowse2 := TImage.Create(gb2);
    imgBrowse2.Parent := gb2;
    imgBrowse2.Picture := browse;
    imgBrowse2.Width := 18;
    imgBrowse2.Height := 18;
    imgBrowse2.ShowHint := true;
    imgBrowse2.Hint := 'Browse for asset destination directory';
    imgBrowse2.OnClick := AssetPathBrowse;
    imgBrowse2.Left := ed2.Left + ed2.Width + 8;
    imgBrowse2.Top := ed2.Top;
    
    cb3 := TCheckBox.Create(gb2);
    cb3.Parent := gb2;
    cb3.Left := lbl2.Left;
    cb3.Top := lbl2.Top +lbl2.Height + 12;
    cb3.Width := 120;
    cb3.Caption := ' Disable label coloring';
    cb3.ShowHint := true;
    cb3.Hint := 
      'Changing this option will require a restart of the script to take effect.'#13
      'Check this if you can''t see any of the filenames in the main merge window.';
    cb3.Checked := disableColoring;
    
    cb4 := TCheckBox.Create(gb2);
    cb4.Parent := gb2;
    cb4.Left := cb3.Left;
    cb4.Top := cb3.Top + cb3.Height + 8;
    cb4.Width := 120;
    cb4.Caption := ' Extract BSAs';
    cb4.ShowHint := true;
    cb4.Hint :=
      'If this is checked, the script will extract all BSAs associated with the'#13
      'plugins being merged into the asset destination directory.';
    cb4.Checked := extractBSAs;
    
    cb5 := TCheckBox.Create(gb2);
    cb5.Parent := gb2;
    cb5.Left := cb3.Left;
    cb5.Top := cb4.Top + cb4.Height + 8;
    cb5.Width := 220;
    cb5.Caption := ' Disable merged ESPs after merging';
    cb5.Checked := disableESPs;
    cb5.Enabled := false;
    
    btnSave := TButton.Create(ofrm);
    btnSave.Parent := ofrm;
    btnSave.Caption := 'Save';
    btnSave.ShowHint := true;
    btnSave.Hint :=
      'Click to save these options for this merge and all future merges.';
    btnSave.ModalResult := mrOk;
    btnSave.Left := ofrm.Width div 2 - btnSave.Width - 8;
    btnSave.Top := gb2.Top + gb2.Height + 15;
    
    btnDiscard := TButton.Create(ofrm);
    btnDiscard.Parent := ofrm;
    btnDiscard.Caption := 'Discard';
    btnDiscard.ShowHint := true;
    btnDiscard.Hint :=
      'Click to discard changes to options.';
    btnDiscard.ModalResult := mrCancel;
    btnDiscard.Left := btnSave.Left + btnSave.Width + 16;
    btnDiscard.Top := btnSave.Top;
    
    ofrm.ActiveControl := btnSave;
    
    if ofrm.ShowModal = mrOk then begin
      if rb1.Checked then rn := 0 else
      if rb2.Checked then rn := 1 else
      if rb3.Checked then rn := 2;
      if rb4.Checked then mm := 0 else
      if rb5.Checked then mm := 1 else
      if rb6.Checked then mm := 2;
      if rb7.Checked then sp := 0 else
      if rb8.Checked then sp := 1 else
      if rb9.Checked then sp := 2;
      disableColoring := cb3.Checked;
      extractBSAs := cb4.Checked;
      disableESPs := cb5.Checked;
      usingMO := cb1.Checked;
      moPath := ed1.Caption;
      copyAll := cb2.Checked;
      astPath := ed2.Caption;
      SaveSettings;
    end;
  finally
    ofrm.Free;
  end;
end;

//=========================================================================
// AssetHelperBrowse: Show user their asset destination directory
procedure afrm.AssetHelperBrowse;
begin
  ShellExecute(TForm(frmMain).Handle, 'open', astPath, '', '', SW_SHOWNORMAL)
end;

//=========================================================================
// AssetHelper: Helps the user set up their asset destination folder
function AssetHelper: boolean;
var
  afrm: TForm;
  lbl1: TLabel;
  btnBrowse, btnOk, btnCancel: TButton;
begin
  Result := true;
  if (astPath = DataPath) then begin
    if firstrun then 
      Result := (MessageDlg(
        'You''re using Skyrim''s data directory as the destination directory '+
        'for assets copied by the script.  This will make your data directory '+
        'very messy over time, and isn''t recommended.  Are you sure you '+
        'want to continue?',  mtCustom, [mbYes,mbNo], 0) = mrYes);
  end
  else if not IsDirectoryEmpty(astPath) then begin
    afrm := TForm.Create(nil);
    try
      afrm.Caption := 'Asset Destination Helper';
      afrm.Width := 300;
      afrm.Position := poScreenCenter;
      afrm.Height := 130;
      
      lbl1 := TLabel.Create(afrm);
      lbl1.Parent := afrm;
      lbl1.Top := 8;
      lbl1.Width := 250;
      lbl1.Height := 30;
      lbl1.AutoSize := False;
      lbl1.Wordwrap := True;
      lbl1.Caption := 'Your asset destination directory isn''t empty.  You should clear it before proceeding.';
      lbl1.Left := 8;
      
      btnOk := TButton.Create(afrm);
      btnOk.Parent := afrm;
      btnOk.Caption := 'Proceed';
      btnOk.ShowHint := true;
      btnOk.Hint := 'Proceed with the merge';
      btnOk.ModalResult := mrOk;
      btnOk.Left := (afrm.Width - 10) div 2 - (btnOk.Width * 1.5 + 8);
      btnOk.Top := lbl1.Top + lbl1.Height + 16;
      
      btnBrowse := TButton.Create(afrm);
      btnBrowse.Parent := afrm;
      btnBrowse.Caption := 'Browse';
      btnBrowse.ShowHint := true;
      btnBrowse.Hint := 'Browse asset destination directory';
      btnBrowse.OnClick := AssetHelperBrowse;
      btnBrowse.Left := btnOk.Left + btnOk.Width + 8;
      btnBrowse.Top := btnOk.Top;
      
      btnCancel := TButton.Create(afrm);
      btnCancel.Parent := afrm;
      btnCancel.Caption := 'Cancel';
      btnCancel.ShowHint := true;
      btnCancel.Hint := 'Cancel the merge';
      btnCancel.ModalResult := mrCancel;
      btnCancel.Left := btnBrowse.Left + btnBrowse.Width + 8;
      btnCancel.Top := btnOk.Top;
      
      if afrm.ShowModal = mrCancel then
        Result := false;
    finally
      afrm.Free;
    end;
  end;
end;

//=========================================================================
// MergeForm: Provides user with options for merging
procedure MergeForm;
var
  mfrm: TForm;
  btnOk, btnCancel, btnFocus: TButton;
  imgOptions: TImage;
  lbl1, lbl2, lbl3: TLabel;
  pnl: TPanel;
  sb: TScrollBox;
  i, j, k, height, m: integer;
  holder: TObject;
  masters, e, f: IInterface;
  s: string;
  slDefinition: TStringList;
begin
  LoadSettings;
  mfrm := TForm.Create(nil);
  try
    mfrm.Caption := 'Merge Plugins';
    mfrm.Width := 425;
    mfrm.Position := poScreenCenter;
    for i := 0 to FileCount - 1 do begin
      s := GetFileName(FileByLoadOrder(i));
      if Pos(s, bethesdaFiles) > 0 then Continue;
      Inc(m);
    end;
    height := m*25 + 120;
    if height > (Screen.Height - 100) then begin
      mfrm.Height := Screen.Height - 100;
      sb := TScrollBox.Create(mfrm);
      sb.Parent := mfrm;
      sb.Height := Screen.Height - 210;
      sb.Align := alTop;
      holder := sb;
    end
    else begin
      mfrm.Height := height;
      holder := mfrm;
    end;

    lbl1 := TLabel.Create(holder);
    lbl1.Parent := holder;
    lbl1.Top := 8;
    lbl1.Left := 8;
    lbl1.AutoSize := False;
    lbl1.Wordwrap := True;
    lbl1.Width := 300;
    lbl1.Height := 50;
    lbl1.Caption := 'Select the plugins you want to merge.';
    
    // create file list
    for i := 0 to FileCount - 1 do begin
      s := GetFileName(FileByIndex(i));
      if (Pos(s, bethesdaFiles) > 0) or (s = '') then Continue;
      j := 25 * k;
      Inc(k);
      
      // load definition
      slDefinition := TStringList.Create;
      slDefinition.StrictDelimiter := true;
      slDefinition.Delimiter := ';';
      slDefinition.DelimitedText := GetDefinition(FileByIndex(i), false, false);
      
      // set up checkbox
      cbArray[i] := TCheckBox.Create(holder);
      cbArray[i].Parent := holder;
      cbArray[i].Left := 24;
      cbArray[i].Top := 40 + j;
      cbArray[i].Width := 350;
      cbArray[i].ShowHint := true;
      cbArray[i].Hint := GetDefinitionHint(slDefinition);
        
      if (slSelectedFiles.IndexOf(s) > - 1) then 
        cbArray[i].Checked := True;
      
      // set up label
      lbArray[i] := TLabel.Create(holder);
      lbArray[i].Parent := holder;
      lbArray[i].Left := 44;
      lbArray[i].Top := cbArray[i].Top;
      lbArray[i].Caption := '  [' + IntToHex64(i + 1, 2) + ']  ' + s;
      if not disableColoring then begin
        lbArray[i].Font.Color := GetMergeColor(slDefinition);
        if slDefinition.Count > 5 then
          lbArray[i].Font.Style := lbArray[i].Font.Style + [fsbold];
      end;
      
      // free definition
      slDefinition.Free;
    end;
    
    if holder = sb then begin
      lbl2 := TLabel.Create(holder);
      lbl2.Parent := holder;
      lbl2.Top := j + 60;
    end;
    
    pnl := TPanel.Create(mfrm);
    pnl.Parent := mfrm;
    pnl.BevelOuter := bvNone;
    pnl.Align := alBottom;
    pnl.Height := 50;
    
    imgOptions := TImage.Create(pnl);
    imgOptions.Parent := pnl;
    imgOptions.Picture := gear;
    imgOptions.Width := 24;
    imgOptions.Height := 24;
    imgOptions.ShowHint := true;
    imgOptions.Hint := 'Advanced Options';
    imgOptions.OnClick := AdvancedOptions;
    imgOptions.Left := mfrm.Width - 50;
    imgOptions.Top := pnl.Height - 40;
    
    btnOk := TButton.Create(mfrm);
    btnOk.Parent := pnl;
    btnOk.Caption := 'OK';
    btnOk.ModalResult := mrOk;
    btnOk.Left := 120;
    btnOk.Top := pnl.Height - 40;
    
    btnCancel := TButton.Create(mfrm);
    btnCancel.Parent := pnl;
    btnCancel.Caption := 'Cancel';
    btnCancel.ModalResult := mrCancel;
    btnCancel.Left := btnOk.Left + btnOk.Width + 16;
    btnCancel.Top := btnOk.Top;
    
    mfrm.ActiveControl := btnOk;
    
    if (firstRun) then AdvancedOptions;
    
    if mfrm.ShowModal = mrOk then begin
      for i := 0 to FileCount - 1 do begin
        f := FileByIndex(i);
        s := GetFileName(f);
        if Pos(s, bethesdaFiles) > 0 then Continue;        
        
        if cbArray[i].State = cbChecked then begin
          slMerge.AddObject(s, TObject(GetLoadOrder(f)));
          slMasters.Add(s);
          // add masters from files to be merged
          masters := ElementByName(ElementByIndex(f, 0), 'Master Files');
          for j := 0 to ElementCount(masters) - 1 do begin
            e := ElementByIndex(masters, j);
            s := GetElementNativeValues(e, 'MAST');
            slMasters.Add(s);
          end;
        end;
      end;
    end;
  finally
    mfrm.Free;
  end;
end;

//======================================================================
// ShowDetails: Enables the visibilty of the TMemo log
procedure ShowDetails;
begin
  frm.Height := 600;
  frm.Position := poScreenCenter;
  memo.Height := frm.Height - 150;
  btnDetails.Visible := false;
  memo.Visible := true;
end;


{*************************************************************************}
{**************************** Merge Functions ****************************}
{*************************************************************************}

//=========================================================================
// FindFolder: looks for a folder matching the given name at the given path
function FindFolder(path: string; filename: string): string;
var
  info: TSearchRec;
begin
  Result := '';
  if FindFirst(path+'*', faDirectory, info) = 0 then begin
    repeat
      if Lowercase(info.Name) = Lowercase(filename) then begin
        Result := path + info.Name +'\';
        break;
      end;
    until FindNext(info) <> 0;
  end;
end;

//=========================================================================
// CopyGeneralAssets: copies all assets from a matching Mod Organizer folder
procedure CopyGeneralAssets(filename: string);
var
  slIgnore: TStringList;
  rec: TSearchRec;
  src, dst, modPath: string;
begin
  // construct ignore stringlist to ignore filename spe
  slIgnore := TStringList.Create;
  slIgnore.Add('facegendata');
  slIgnore.Add('voice');
  slIgnore.Add('translations');
  slIgnore.Add('meta.ini');
  slIgnore.Add('.');
  slIgnore.Add('..');
  slIgnore.Add('*.esp');
  slIgnore.Add('*.esm');
  if extractBSAs then begin
    slIgnore.Add('*.bsa');
    slIgnore.Add('*.bsl');
  end;
  
  // find mod directory in Mod Organizer's mods folder
  if FindFirst(moPath + 'mods\*', faDirectory, rec) = 0 then begin
    repeat
      modPath := FileSearch(filename, moPath + 'mods\' + rec.Name);
      if (modPath <> '') then begin
        modPath := moPath + 'mods\'+ rec.Name;
        break;
      end;
    until FindNext(rec) <> 0;
    
    FindClose(rec);
    if (modPath = '') then exit;
  end;
  
  // copy assets from folder
  if slCopiedFrom.IndexOf(modPath) = -1 then begin
    slCopiedFrom.Add(modPath);
    LogMessage('    Copying assets from directory "'+modPath+'"');
    CopyDirectory(modPath, astPath, slIgnore, debug);
  end;
end;

//=========================================================================
// CopyAssets: copies assets in filename specific directories
procedure CopyActorAssets(path: string; mergeIndex: integer);
var
  info: TSearchRec;
  src, dst, newForm, srcPath, dstPath: string;
  index: integer;
begin
  // see if there is a folder matching the filename
  srcPath := FindFolder(path, slMerge[mergeIndex]);
  
  // if no folder found, exit
  if (srcPath = '') then exit;
  
  // prepare destination
  dstPath := StringReplace(path + GetFileName(mgf) + '\', DataPath, astPath, [rfReplaceAll]);
  ForceDirectories(dstPath);
  
  // copy all assets
  index := -1;
  LogMessage('        Copying assets from directory "'+srcPath+'"');
  LogMessage('        Copying assets to directory "'+dstPath+'"');
  if FindFirst(srcPath+'*', faAnyFile, info) = 0 then begin
    repeat
      src := info.Name;
      // skip . and ..
      if (Length(src) >= 8) then begin
        if (rn > 0) then
          index := TStringList(OldForms[mergeIndex]).IndexOf(Copy(src, 1, 8));
        // asset not renumbered
        if (index = -1) then begin
          dst := info.Name;
          LogMessage('            Copying asset "'+src+'" to "'+dst+'"');
          CopyFile(PChar(srcPath + src), PChar(dstPath + dst), false);
        end
        // asset renumbered
        else begin
          newForm := '00' + Copy(NewForms[index], 3, 6);
          dst := StringReplace(info.Name, Copy(src, 1, 8), newForm, [rfReplaceAll]);
          CopyFile(PChar(srcPath + src), PChar(dstPath + dst), false);
          LogMessage('            Copying asset "'+src+'" to "'+dst+'"');
        end;
      end;
    until FindNext(info) <> 0;
    FindClose(info);
  end;
end;

//=========================================================================
// CopyVoiceAssets: copies voice assets in filename specific directories
procedure CopyVoiceAssets(path: string; mergeIndex: integer);
var
  info, info2: TSearchRec;
  src, dst, newForm, srcPath, dstPath: string;
  index: integer;
begin
  // see if there is a folder matching the filename
  srcPath := FindFolder(path, slMerge[mergeIndex]);
  
  // if no folder found, exit
  if (srcPath = '') then exit;
  
  // prepare destination
  dstPath := StringReplace(path + GetFileName(mgf) + '\', DataPath, astPath, [rfReplaceAll]);
  ForceDirectories(dstPath);
  
  // copy subfolders and their contents
  index := -1;
  LogMessage('        Copying voice assets from directory "'+srcPath+'"');
  LogMessage('        Copying voice assets to directory "'+dstPath+'"');
  if FindFirst(srcPath+'*', faDirectory, info) = 0 then begin
    repeat
      if (Pos('.', info.Name) <> 1) then begin
        CreateDir(dstPath+info.Name);
        // copy contents of subdirectory into new directory
        if FindFirst(srcPath+info.Name+'\'+'*', faAnyFile, info2) = 0 then begin
          repeat
            // skip '.' and '..'
            if (Length(info2.Name) >= 8) then begin
              src := info.Name + '\' + info2.Name;
              if (rn > 0) then 
                index := TStringList(OldForms[mergeIndex]).IndexOf(Copy(info2.Name, 1, 8));
              // asset not renumbered
              if (index = -1) then begin
                dst := info.Name + '\' + info2.Name;
                LogMessage('            Copying asset "'+src+'" to "'+dst+'"');
                CopyFile(PChar(srcPath + src), PChar(dstPath + dst), false);
              end
              // asset renumbered
              else begin
                newForm := '00' + Copy(NewForms[index], 3, 6);
                dst := info.Name + '\' + StringReplace(info.Name + '\' + info2.Name, Copy(info2.Name, 1, 8), newForm, [rfReplaceAll]);
                CopyFile(PChar(srcPath + src), PChar(dstPath + dst), false);
                LogMessage('            Copying asset "'+src+'" to "'+dst+'"');
              end;
            end;
          until FindNext(info2) <> 0;
        end;
      end;
    until FindNext(info) <> 0;
  end;
end;

//=========================================================================
// CopyTranslations: copies MCM translation files
procedure CopyTranslations(path: string; mergeIndex: integer);
var
  info: TSearchRec;
  t, fn, srcPath, dstPath: string;
  slSrc: TStringList;
  index: integer;
begin
  fn := slMerge[mergeIndex];
  fn := Lowercase(Copy(fn, 1, Length(fn) - 4)); // trim .esp off
  LogMessage('     Copying MCM Translations associated with '+fn);
  
  // search for translation files
  if FindFirst(path+'*.txt', faAnyFile and faDirectory, info) = 0 then begin
    repeat
      // translation file found
      if (Pos(fn, Lowercase(info.Name)) = 1) then begin
        t := StringReplace(Lowercase(info.Name), fn, '', [rfReplaceAll]);
        index := slTranslations.IndexOf(t);
        // other translation files for same language found, concatenate
        if index > -1 then begin
          slSrc := TStringList.Create;
          if mcmdebug then LogMessage('            LoadFromFile: "'+path+info.Name+'"');
          slSrc.LoadFromFile(path+info.Name);
          slArray[index].Text := slArray[index].Text + #13#10#13#10 + slSrc.Text;
          slSrc.Free;
        end
        // add new translation to stringlist
        else begin
          slArray[slTranslations.Count] := TStringList.Create;
          if mcmdebug then LogMessage('            LoadFromFile: "'+path+info.Name+'"');
          slArray[slTranslations.Count].LoadFromFile(path+info.Name);
          slTranslations.Add(t);
        end;
        if mcmdebug then LogMessage('            Copying MCM translation "'+info.Name+'"');
      end;
    until FindNext(info) <> 0;
  end;
end;

//=========================================================================
// SaveTranslations
procedure SaveTranslations(path: string);
var
  i: integer;
begin
  // terminate if we have no translation files to save
  if slTranslations.Count = 0 then
    exit;
  
  // use MO's overwrite folder as destination if user is using MO
  path := StringReplace(path + GetFileName(mgf) + '\', DataPath, astPath, [rfReplaceAll]);
  ForceDirectories(path);
  
  // save all new translation files
  for i := 0 to slTranslations.Count - 1 do begin
    if mcmdebug then 
      LogMessage('            Output MCM translation "'+path+Copy(GetFileName(mgf), 1, Length(GetFileName(mgf)) - 4) + slTranslations[i]);
    slArray[i].SaveToFile(path + Copy(GetFileName(mgf), 1, Length(GetFileName(mgf)) - 4) + slTranslations[i]);
    slArray[i].Free;
  end;
  slTranslations.Free;
end;

//=========================================================================
// CopyElement: copies an element to the merged file
procedure CopyElement(e: IInterface);
var
  cr: IInterface;
begin
  // correct Tamriel camera data
  if (geev(e, 'EDID') = 'Tamriel') then begin
    Remove(ElementByPath(e, 'MNAM'));
    Add(e, 'MNAM', True);
    seev(e, 'MNAM\Cell Coordinates\NW Cell\X', '-30');
    seev(e, 'MNAM\Cell Coordinates\NW Cell\Y', '15');
    seev(e, 'MNAM\Cell Coordinates\SE Cell\X', '40');
    seev(e, 'MNAM\Cell Coordinates\SE Cell\Y', '-40');
    seev(e, 'MNAM\Cell Coordinates\SE Cell\Y', '-40');
    seev(e, 'MNAM\Camera Data\Min Height', '50000');
    seev(e, 'MNAM\Camera Data\Max Height', '80000');
    seev(e, 'MNAM\Camera Data\Initial Pitch', '50');
  end;
  
  // attempt to copy record to merged file, alert user on exception
  try
    cr := wbCopyElementToFile(e, mgf, False, True);
    if debug then LogMessage('        Copying '+SmallName(e));
  except
    on x : Exception do begin
      LogMessage('        Failed to copy '+Name(e)+'; '+x.Message);
      slFails.Add(FullPath(e)+'; '+x.Message);
    end;
  end;
end;

//=========================================================================
// MergeByRecords: merges by copying records
procedure MergeByRecords(g: IInterface);
var
  i: integer;
  e: IInterface;
begin
  for i := 0 to RecordCount(g) - 1 do begin
    e := RecordByIndex(g, i);
    if Signature(e) = 'TES4' then Continue;
    CopyElement(e);
  end;
end;

//=========================================================================
// MergeIntelligently: merges by copying records, skipping records in group records
procedure MergeIntelligently(g: IInterface);
var
  i: integer;
  e: IInterface;
begin
  for i := 0 to ElementCount(g) - 1 do begin
    e := ElementByIndex(g, i);
    if Signature(e) = 'TES4' then Continue;
    if Signature(e) = 'GRUP' then begin
      if Pos('GRUP Cell', Name(e)) = 1 then CopyElement(e) else 
      if Pos('GRUP Exterior Cell', Name(e)) = 1 then CopyElement(e) 
      else MergeIntelligently(e);
    end
    else CopyElement(e);
  end;
end;

//=========================================================================
// MergeByGroups: merges by copying entire group records
procedure MergeByGroups(g: IInterface);
var
  i: integer;
  e: IInterface;
begin
  for i := 0 to ElementCount(g) - 1 do begin
    e := ElementByIndex(g, i);
    if Signature(e) = 'TES4' then Continue;
    CopyElement(e);
  end;
end;

// ========================================================================
// FindHighestFormID: find highest formID in files to be merged
function FindHighestFormID(): Cardinal;
var
  i, j: integer;
  x: Cardinal;
  e, f: IInterface;
begin
  Result := 0;
  
  // check files to be merged for highest formID
  for i := 0 to slMerge.Count - 1 do begin
    f := FileByLoadOrder(Integer(slMerge.Objects[i]));
    for j := 0 to RecordCount(f) - 1 do begin
      e := RecordByIndex(f, j);
      if not Equals(e, MasterOrSelf(e)) then Continue;
      x := FileFormID(e);
      if x > Result then Result := x;
    end;
  end;
  
  // check merge file for a higher form ID
  for i := 0 to RecordCount(mgf) - 1 do begin
    if not Equals(e, MasterOrSelf(e)) then Continue;
    e := RecordByIndex(mgf, i);
    x := FileFormID(e);
    if x > Result then Result := x;
  end;
end;

//=========================================================================
// CopyFileSpecificAssets: performs all file specific asset copying
procedure CopyFileSpecificAssets(i: integer);
begin
  // extract assets from BSAs if necessary
  if (Pos('.esp', slMerge[i]) > 0) then
    bsaName := StringReplace(slMerge[i], '.esp', '.bsa', [rfReplaceAll]);
  if (Pos('.esm', slMerge[i]) > 0) then
    bsaName := StringReplace(slMerge[i], '.esm', '.bsa', [rfReplaceAll]);
  if (Pos('.bsa', bsaName) > 0) and FileExists(DataPath + bsaName) then begin
    ExtractPathBSA(DataPath + bsaName, TempPath, 'textures\actors\character\facegendata\facetint\');
    ExtractPathBSA(DataPath + bsaName, TempPath, 'meshes\actors\character\facegendata\facegeom\');
    ExtractPathBSA(DataPath + bsaName, TempPath, 'sound\voice');
    ExtractPathBSA(DataPath + bsaName, TempPath, 'interface\translations\');
  end;
  
  // Copy assets when done renumbering
  // copy loose File/FormID specific assets
  CopyActorAssets(DataPath + 'Textures\Actors\Character\FacegenData\facetint\', i); // copy actor textures
  CopyActorAssets(DataPath + 'Meshes\actors\character\facegendata\facegeom\', i); // copy actor meshes
  CopyVoiceAssets(DataPath + 'Sound\Voice\', i); // copy voice assets
  CopyTranslations(DataPath + 'Interface\Translations\', i); // copy MCM translation files
  
  // copy archived File/FormID specific assets
  CopyActorAssets(TempPath + 'Textures\Actors\Character\FacegenData\facetint\', i); // copy actor textures
  CopyActorAssets(TempPath + 'Meshes\actors\character\facegendata\facegeom\', i); // copy actor meshes
  CopyVoiceAssets(TempPath + 'Sound\Voice\', i); // copy voice assets
  CopyTranslations(TempPath + 'Interface\Translations\', i); // copy MCM translation files
end;

// ========================================================================
// RenumberConflicting: renumber only conflicting FormIDs.
procedure RenumberConflicting(pb: TProgressBar);
var
  i, j, k, rc, pre: integer;
  HighestFormID, OldFormID, NewFormID, BaseFormID, offset, x, prc: Cardinal;
  e, f: IInterface;
  Records: array [0..$FFFFFF] of IInterface;
  self: boolean;
  loadFormID, fileFormID: String;
  slAllForms: TStringList;
begin
  pb.Position := 1;
  slAllForms := TStringList.Create;
  LogMessage(#13#10+'Renumbering conflicting FormIDs before merging...');
  
  // find a safe NewFormID to start at
  HighestFormID := FindHighestFormID();
  BaseFormID := HighestFormID + 4096;
  
  // form id renumbering for each file
  for i := 0 to slMerge.Count - 1 do begin
    f := FileByLoadOrder(Integer(slMerge.Objects[i]));
    RC := RecordCount(f) - 1;
    LogMessage('    Renumbering records in file '+GetFileName(f));
    OldForms.Add(TStringList.Create);
    NewForms.Add(TStringList.Create);
    
    // create records array for file because the indexed order of records changes as we alter their formIDs
    for j := 0 to RC do
      Records[j] := RecordByIndex(f, j);
    
    // set newformID to use the load order of the file currently being processed.
    offset := Integer(slMerge.Objects[i]) * 16777216;
    NewFormID := BaseFormID + offset;

    // renumber the records in the file
    for j := 0 to RC do begin
      e := Records[j];
      // skip header record
      if (Signature(e) = 'TES4') then Continue;
      
      loadFormID := HexFormID(e);
      // skip non-file records (overwrite and injected)
      pre := StrToInt('$' + Copy(loadFormID, 1, 2));
      if (pre <> Integer(slMerge.Objects[i])) then begin
        TStringList(OldForms[i]).Add(loadFormID);
        TStringList(NewForms[i]).Add(loadFormID);
        Continue;
      end;
      
      OldFormID := StrToInt64('$' + loadFormID);
      fileFormID := '00' + Copy(loadFormID, 3, 6);
      // if not conflicting FormID, add to list and continue.
      if (slAllForms.IndexOf(fileFormID) = -1) then begin
        slAllForms.Add(fileFormID);
        TStringList(OldForms[i]).Add(loadFormID);
        TStringList(NewForms[i]).Add(loadFormID);
        Continue;
      end
      else begin
        // else renumber it
        // print log message first, then change references, then change form
        if debug then 
          LogMessage(Format('        Changing FormID to [%s] on %s', 
          [IntToHex64(NewFormID, 8), SmallName(e)]));
        prc := 0;
        while ReferencedByCount(e) > 0 do begin
          if prc = ReferencedByCount(e) then break;
          prc := ReferencedByCount(e);
          CompareExchangeFormID(ReferencedByIndex(e, 0), OldFormID, NewFormID);
        end;
        SetLoadOrderFormID(e, NewFormID);
        TStringList(OldForms[i]).Add(loadFormID);
        TStringList(NewForms[i]).Add(IntToHex64(NewFormID, 8));
        
        Inc(rCount);
        // increment formid
        Inc(BaseFormID);
        Inc(NewFormID);
      end;
    end;
    
    // copy file specific assets
    CopyFileSpecificAssets(i);
    
    pb.Position := pb.Position + 29/slMerge.Count;
  end;
  SaveTranslations(DataPath + 'Interface\Translations\');
  slAllForms.Free;
end;

//=========================================================================
// RenumberOld: the old renumbering method, pre 3.0.33
procedure RenumberOld(pb: TProgressBar);
var
  i, j, k, rc, pre: integer;
  HighestFormID, OldFormID, NewFormID, BaseFormID, offset, x, prc: Int64;
  e, f: IInterface;
  Records: array [0..$FFFFFF] of IInterface;
  self: boolean;
  loadFormID, fileFormID: String;
begin
  pb.Position := 1;
  LogMessage(#13#10+'Renumbering FormIDs before merging...');
  
  // find a safe NewFormID to start at
  HighestFormID := FindHighestFormID();
  BaseFormID := HighestFormID + 4096;
  
  // form id renumbering for each file
  for i := 0 to slMerge.Count - 1 do begin
    f := FileByLoadOrder(Integer(slMerge.Objects[i]));
    RC := RecordCount(f) - 1;
    LogMessage('    Renumbering records in file '+GetFileName(f));
    OldForms.Add(TStringList.Create);
    NewForms.Add(TStringList.Create);
    
    // create records array for file because the indexed order of records changes as we alter their formIDs
    for j := 0 to RC do
      Records[j] := RecordByIndex(f, j);
      
    // set newformID to use the load order of the file currently being processed.
    offset := Integer(slMerge.Objects[i]) * 16777216;
    NewFormID := BaseFormID + offset;
    
    // renumber the records in the file
    for j := 0 to RC do begin
      e := Records[j];
      if (Signature(e) = 'TES4') then Continue;
      
      loadFormID := HexFormID(e);
      // skip non-file records (overwrite and injected)
      pre := StrToInt('$' + Copy(loadFormID, 1, 2));
      if (pre <> Integer(slMerge.Objects[i])) then begin
        TStringList(OldForms[i]).Add(loadFormID);
        TStringList(NewForms[i]).Add(loadFormID);
        Continue;
      end;
      
      // print log message first, then change references, then change form
      OldFormID := StrToInt64('$' + loadFormID);
      fileFormID := '00' + Copy(loadFormID, 3, 6);
      if debug then 
        LogMessage(Format('        Changing FormID to [%s] on %s', 
        [IntToHex64(NewFormID, 8), SmallName(e)]));
      prc := 0;
      while ReferencedByCount(e) > 0 do begin
        if prc = ReferencedByCount(e) then break;
        prc := ReferencedByCount(e);
        CompareExchangeFormID(ReferencedByIndex(e, 0), OldFormID, NewFormID);
      end;
      SetLoadOrderFormID(e, NewFormID);
      TStringList(OldForms[i]).Add(loadFormID);
      TStringList(NewForms[i]).Add(IntToHex64(NewFormID, 8));
      
      Inc(rCount);
      // increment formid
      Inc(BaseFormID);
      Inc(NewFormID);
    end;
    
    // copy file specific assets
    CopyFileSpecificAssets(i);
    
    pb.Position := pb.Position + 29/slMerge.Count;
  end;
  SaveTranslations(DataPath + 'Interface\Translations\');
end;

//=========================================================================
// RenumberNew: the new renumbering method, for 3.033 and above
procedure RenumberNew(pb: TProgressBar);
var
  i, j, k, rc, pre: integer;
  HighestFormID, OldFormID, NewFormID, BaseFormID, offset, x, prc: Cardinal;
  e, f: IInterface;
  Records: array [0..$FFFFFF] of IInterface;
  self: boolean;
  fileFormID, loadFormID: String;
begin
  pb.Position := 1;
  LogMessage(#13#10+'Renumbering FormIDs before merging...');
  
  // find a safe NewFormID to start at
  HighestFormID := FindHighestFormID();
  BaseFormID := HighestFormID + 4096;
  
  // form id renumbering for each file
  for i := 0 to slMerge.Count - 1 do begin
    f := FileByLoadOrder(Integer(slMerge.Objects[i]));
    RC := RecordCount(f) - 1;
    LogMessage('    Renumbering records in file '+GetFileName(f));
    OldForms.Add(TStringList.Create);
    NewForms.Add(TStringList.Create);
    
    // create records array for file because the indexed order of records changes as we alter their formIDs
    for j := 0 to RC do
      Records[j] := RecordByIndex(f, j);
      
    // set newformID to use the load order of the file currently being processed.
    offset := Integer(slMerge.Objects[i]) * 16777216;
    NewFormID := BaseFormID + offset;
    
    // renumber the records in the file
    for j := 0 to RC do begin
      e := Records[j];
      if (Signature(e) = 'TES4') then Continue;
      
      loadFormID := HexFormID(e);
      // skip non-file records (overwrite and injected)
      pre := StrToInt('$' + Copy(loadFormID, 1, 2));
      if (pre <> Integer(slMerge.Objects[i])) then begin
        TStringList(OldForms[i]).Add(loadFormID);
        TStringList(NewForms[i]).Add(loadFormID);
        Continue;
      end;
      
      // print log message first, then change references, then change form
      OldFormID := GetLoadOrderFormID(e);
      fileFormID := '00' + Copy(loadFormID, 3, 6);
      if debug then 
        LogMessage(Format('        Changing FormID to [%s] on %s', 
        [IntToHex64(NewFormID, 8), SmallName(e)]));
      prc := 0;
      while ReferencedByCount(e) > 0 do begin
        if prc = ReferencedByCount(e) then break;
        prc := ReferencedByCount(e);
        CompareExchangeFormID(ReferencedByIndex(e, 0), OldFormID, NewFormID);
      end;
      SetLoadOrderFormID(e, NewFormID);
      TStringList(OldForms[i]).Add(loadFormID);
      TStringList(NewForms[i]).Add(IntToHex64(NewFormID, 8));
      
      Inc(rCount);
      // increment formid
      Inc(BaseFormID);
      Inc(NewFormID);
    end;
    
    // copy file specific assets
    CopyFileSpecificAssets(i);
    
    pb.Position := pb.Position + 29/slMerge.Count;
  end;
  SaveTranslations(DataPath + 'Interface\Translations\');
end;


{**************************************************************************}
{**************************** Script Execution ****************************}
{**************************************************************************}

//=========================================================================
// Initialize
function Initialize: integer;
begin
  // welcome messages
  AddMessage(#13#10#13#10);
  AddMessage(dashes);
  AddMessage('Merge plugins '+vs+': Merges files.  For use with TES5Edit and FNVEdit.');
  AddMessage(dashes);
 
  // stringlist creation
  slSelectedFiles := TStringList.Create;
  slMerge := TStringList.Create;
  slFails := TStringList.Create;
  slMasters := TStringList.Create;
  slMasters.Sorted := True;
  slMasters.Duplicates := dupIgnore;
  slMgfMasters := TStringList.Create;
  slDictionary := TStringList.Create;
  slDictionary.LoadFromFile(ScriptsPath + '\mp\dictionary.txt');
  slTranslations := TStringList.Create;
  slCopiedFrom := TStringList.Create;
  OldForms := TList.Create;
  NewForms := TList.Create;
  
  // load gui elements
  gear := TPicture.Create;
  gear.LoadFromFile(ProgramPath + 'Edit Scripts\mp\assets\gear.png');
  browse := TPicture.Create;
  browse.LoadFromFile(ProgramPath + 'Edit Scripts\mp\assets\browse.png');
  
  // process only file elements
  try 
    ScriptProcessElements := [etFile];
  except on Exception do
    SkipProcess := true;
  end;
end;

//=========================================================================
// Process: put files to be merged into stringlists
function Process(f: IInterface): integer;
var
  i: integer;
  s: string;
begin
  if SkipProcess then 
    exit;
    
  if (ElementType(f) = etMainRecord) then 
    exit;
    
  s := GetFileName(f);
  slSelectedFiles.AddObject(s, TObject(GetLoadOrder(f)));
end;

//=========================================================================
// Finalize: this is where all the good stuff happens
function Finalize: integer;
var
  i, j, k, rc, wait, waitTick: integer;
  f, e, group, masters, master: IInterface;
  merge, id, desc, version, fn, masterName, mergeDesc: string;
  done, b, recordFromMerge, didNothing: boolean;
  lbl: TLabel;
  pb: TProgressBar;
  today : TDateTime;
begin
  // change hint duration
  Application.HintHidePause := 10000;
  
  // check version
  try
    k := wbVersionNumber;
    version := GetVersionString(k);
    AddMessage(version);
  except on Exception do
    ;// nothing
  end;
  if k = 0 then begin
    AddMessage('This version of xEdit is out of date, you must update it to use this script!'+#13#10);
    slMerge.Free; slMasters.Free; slSelectedFiles.Free; slFails.Free; slMgfMasters.Free;
    exit;
  end;
  
  // if 128 or more files loaded, alert user and terminate script
  // unless version is 3.0.33 or newer
  if (FileCount >= 128) and (k < 50340096) then begin
    AddMessage('You cannot load 128 or more plugins into this version of TES5Edit when Merging Plugins.');
    AddMessage('Please reopen TES5Edit and select 127 or fewer plugins to load, or download and use TES5Edit 3.0.33.'+#13#10);
    slMerge.Free; slMasters.Free; slSelectedFiles.Free; slFails.Free; slMgfMasters.Free;
    exit;
  end;
  
  MergeForm;
  
  // terminate script if mergelist contains less than one file
  if slMerge.Count < 1 then begin
    AddMessage(#13#10+'Select at least 1 file to merge!  Terminating script.'+#13#10);
    slMerge.Free; slMasters.Free; slSelectedFiles.Free; slFails.Free; slMgfMasters.Free;
    exit;
  end;
  
  // terminate script if usingMO is true but moPath isn't correct
  if (usingMO) and ((moPath = '') or (moPath = '?')) then begin
    AddMessage(#13#10+
    'Mod Organizer path invalid.  If you''re not using Mod Organizer, please uncheck '#13#10
    'the checkbox saying that you are from the Advanced Options window. If you are '#13#10
    'using Mod Organzier please enter it''s path on the Advanced Options window.'#13#10);
    slMerge.Free; slMasters.Free; slSelectedFiles.Free; slFails.Free; slMgfMasters.Free;
    exit;
  end;
  
  // provide user with asset destination helper
  if not AssetHelper then begin
    AddMessage(#13#10'User canceled merge.  Terminating script.'#13#10);
    slMerge.Free; slMasters.Free; slSelectedFiles.Free; slFails.Free; slMgfMasters.Free;
    exit;
  end;
  
  // create or identify merge file
  done := False;
  mgf := nil;
  AddMessage(#13#10+'Preparing merged file...');
  mgf := FileSelectM('Choose the file you want to merge into below, or '+#13#10+'choose -- CREATE NEW FILE -- to create a new one.');

  // merge file confirmation or termination
  if not Assigned(mgf) then begin
    AddMessage('    No merge file assigned.  Terminating script.'+#13#10);
    exit;
  end;
  AddMessage('    Script is using ' + GetFileName(mgf) + ' as the merge file.');
  
  // display progress bar
  frm := TForm.Create(nil);
  try
    frm.Caption := 'Merging plugins...';
    frm.Width := 700;
    frm.Position := poScreenCenter;
    frm.Height := 150;
    
    lbl := TLabel.Create(frm);
    lbl.Parent := frm;
    lbl.Top := 20;
    lbl.Left := 20;
    lbl.Width := frm.Width - 55;
    lbl.Height := 30;
    lbl.Caption := 'Initializing... ';
    lbl.Visible := true;
    
    pb := TProgressBar.Create(frm);
    pb.Parent := frm;
    pb.Top := 40;
    pb.Left := 20;
    pb.Width := frm.Width - 55;
    pb.Height := 20;
    pb.Step := 1;
    pb.Min := 0;
    pb.Max := 100;
    pb.Position := 0;
    
    memo := TMemo.Create(frm);
    memo.Parent := frm;
    memo.Top := 70;
    memo.Left := 20;
    memo.Width := pb.Width;
    memo.WordWrap := false;
    memo.ScrollBars := ssBoth;
    memo.Visible := false;
    memo.ReadOnly := true;
    
    btnDetails := TButton.Create(frm);
    btnDetails.Parent := frm;
    btnDetails.Top := pb.Top + pb.Height + 8;
    btnDetails.Left := pb.Left;
    btnDetails.Caption := 'Show Details';
    btnDetails.Width := 100;
    btnDetails.OnClick := ShowDetails;
    
    frm.Show;
    application.processmessages;
    
    // print initial log messages
    LogMessage(dashes);
    LogMessage('Merge Plugins '+vs+': Merges files.  For use with TES5Edit and FNVEdit.');
    LogMessage(dashes);
    LogMessage(version+#13#10);
    for i := 0 to slMerge.Count - 1 do
      LogMessage('Merging '+slMerge[i]);
    
    LogMessage(#13#10+'Script is using ' + GetFileName(mgf) + ' as the merge file.');
    
    // set up for saving log
    SetCurrentDir(ScriptsPath + '\mp\');
    CreateDir('logs'); // create directory if it doesn't already exist
    today := Now;
    fn := 'merge_'+StringReplace(DateToStr(today), '/', '', [rfReplaceAll])+
        '_'+StringReplace(TimeToStr(today), ':', '', [rfReplaceAll])+'.txt';
  
    // add masters
    lbl.Caption := 'Adding masters...';
    LogMessage('    Adding masters to merge file...');
    AddMastersToFile(mgf, slMasters, true);
     
    // renumber forms in files to be merged
    rCount := 0;
    if (rn = 2) and (k >= 50340096) then begin
      lbl.Caption := 'Renumbering All FormIDs...';
      RenumberNew(pb);
      LogMessage('    '+IntToStr(rCount)+' records renumbered.');
    end
    else if (rn = 2) and (FileCount < 128) then begin
      lbl.Caption := 'Renumbering All FormIDs...';
      RenumberOld(pb);
      LogMessage('    '+IntToStr(rCount)+' records renumbered.');
    end
    else if (rn = 1) and (k >= 50340096) then begin
      lbl.Caption := 'Renumbering conflicting FormIDs...';
      RenumberConflicting(pb);
      LogMessage('    '+IntToStr(rCount)+' records renumbered.');
    end
    else if (rn = 0) then begin
      // make formID text files
      for i := 0 to slMerge.Count - 1 do begin
        f := FileByLoadOrder(Integer(slMerge.Objects[i]));
        RC := RecordCount(f) - 1;
        NewForms.Add(TStringList.Create);
        for j := 0 to RC do begin
          e := RecordByIndex(f, j);
          if (Signature(e) = 'TES4') then Continue;
          TStringList(NewForms[i]).Add(HexFormID(e));
        end;
      end;
      
      // copy File specific asets
      LogMessage(#13#10+'Copying file specific Assets...');
      lbl.Caption := 'Copying file specific Assets...';
      for i := 0 to slMerge.Count - 1 do CopyFileSpecificAssets(i);
    end;
    
    // save log
    memo.Lines.SaveToFile(ScriptsPath+'\mp\logs\'+fn);
    
    // mod organizer CopyGeneralAssets option
    if copyAll then begin
      didNothing := true;
      LogMessage(#13#10+'Copying general assets from Mod Organizer directories.');
      lbl.Caption := 'Copying general assets from Mod Organizer directories...';
      for i := 0 to slMerge.Count - 1 do begin
        CopyGeneralAssets(slMerge[i]);
        Application.processmessages;
        didNothing := false;
      end;
      if didNothing then
        LogMessage('    No general assets copied.');
    end;
    
    // save log
    memo.Lines.SaveToFile(ScriptsPath+'\mp\logs\'+fn);
    
    // extract BSAs option
    if extractBSAs then begin
      didNothing := true;
      LogMessage(#13#10+'Extracting BSAs.');
      lbl.Caption := 'Extracting BSAs';
      for i := 0 to slMerge.Count - 1 do begin
        if (Pos('.esp', slMerge[i]) > 0) then
          bsaName := StringReplace(slMerge[i], '.esp', '.bsa', [rfReplaceAll]);
        if (Pos('.esm', slMerge[i]) > 0) then
          bsaName := StringReplace(slMerge[i], '.esm', '.bsa', [rfReplaceAll]);
        if (Pos('.bsa', bsaName) > 0) and FileExists(DataPath + bsaName) then begin
          LogMessage('    Extracting '+bsaName+' to '+astPath);
          ExtractBSA(DataPath + bsaName, astPath);
          Application.processmessages;
          didNothing := false;
        end;
      end;
      if didNothing then
        LogMessage('    No BSAs extracted.');
    end;
    
    // save log
    memo.Lines.SaveToFile(ScriptsPath+'\mp\logs\'+fn);

    // copy records
    LogMessage(#13#10+'Copying records...');
    lbl.Caption := 'Copying records...';
    pb.Position := 29;
    for i := slMerge.Count - 1 downto 0 do begin
      f := FileByLoadOrder(Integer(slMerge.Objects[i]));
      LogMessage('    Copying records from '+GetFileName(f));
      if mm = 0 then MergeByRecords(f) else 
      if mm = 1 then MergeIntelligently(f) else 
      if mm = 2 then MergeByGroups(f);
      pb.Position := pb.Position + 30/slMerge.Count;
      Application.processmessages;
    end;
    
    // save log
    memo.Lines.SaveToFile(ScriptsPath+'\mp\logs\'+fn);
   
    // removing masters
    LogMessage(#13#10+'Removing unnecessary masters...');
    lbl.Caption := 'Removing masters...';
    pb.Position := 59;
    masters := ElementByName(ElementByIndex(mgf, 0), 'Master Files');
    for i := ElementCount(masters) - 1 downto 0 do begin
      e := ElementByIndex(masters, i);
      masterName := GetElementNativeValues(e, 'MAST');
      if (masterName = '') then Continue;
      for j := 0 to slMerge.Count - 1 do begin
        if (slMerge[j] = masterName) then begin
          LogMessage('    Removing master '+masterName);
          RemoveElement(masters, e);
        end;
      end;
    end;
    
    // creating description
    desc := 'Merged Plugin: ';
    lbl.Caption := 'Creating description';
    pb.Position := 60;
    desc := nil;
    desc := geev(ElementByIndex(mgf, 0), 'SNAM');
    if not Assigned(desc) then
      Add(ElementByIndex(mgf, 0), 'SNAM', True)
    else if Pos('Merged Plugin', desc) = 0 then 
      desc := '';
    for i := 0 to slMerge.Count - 1 do begin
      mergeDesc := geev(ElementByIndex(FileByLoadOrder(Integer(slMerge.Objects[i])), 0), 'SNAM');
      if Pos('Merged Plugin', mergeDesc) > 0 then
        desc := desc+StringReplace(mergeDesc, 'Merged Plugin: ', '', [rfReplaceAll])
      else
        desc := desc+#13#10+'  '+slMerge[i];
    end;
    seev(ElementByIndex(mgf, 0), 'CNAM', 'Merge Plugins Script '+vs);
    seev(ElementByIndex(mgf, 0), 'SNAM', desc);
    
    // save log
    memo.Lines.SaveToFile(ScriptsPath+'\mp\logs\'+fn);
    
    // second pass copying
    if (sp > 0) then begin
      // removing records for second pass copying
      pb.Position := 61;
      LogMessage(#13#10+'Removing records for second pass.');
      lbl.Caption := 'Removing records...';
      for i := RecordCount(mgf) - 1 downto 1 do begin
        e := RecordByIndex(mgf, i);
        id := HexFormID(e);
        for j := 0 to slMerge.Count - 1 do begin
          recordFromMerge := TStringList(NewForms[j]).IndexOf(id) > -1;
          if (recordFromMerge) then begin
            b := true;
            break;
          end;
        end;
        if b then begin
          b := false;
          Inc(rCount);
          Remove(e);
        end;
      end;
      LogMessage('    '+IntToStr(rCount)+' records removed.');
      
      // copy records again
      LogMessage(#13#10+'Performing second pass copying...');
      pb.Position := 65;
      lbl.Caption := 'Copying records (second pass)...';
      for i := slMerge.Count - 1 downto 0 do begin
        f := FileByLoadOrder(Integer(slMerge.Objects[i]));
        LogMessage('    Copying records from '+GetFileName(f));
        if (sp = 1) then begin
          if mm = 0 then MergeByRecords(f) else 
          if mm = 1 then MergeIntelligently(f) else 
          if mm = 2 then MergeByGroups(f);
        end
        else MergeByGroups(f);
        pb.Position := pb.Position + 30/slMerge.Count;
        Application.processmessages;
      end;
    end;
    
    // save log
    memo.Lines.SaveToFile(ScriptsPath+'\mp\logs\'+fn);
    
    // create formID list group
    Add(mgf, 'FLST', true);
    // create formlists
    lbl.Caption := 'Creating FormLists...';
    pb.Position := 98;
    LogMessage(#13#10+'Creating FormLists...');
    for i := 0 to slMerge.Count - 1 do begin
      LogMessage('    Creating formlist for '+slMerge[i]);
      e := Add(GroupBySignature(mgf, 'FLST'), 'FLST', True);
      seev(e, 'EDID', Copy(slMerge[i], 1, Length(slMerge[i]) - 4)+'Forms');
      Add(e, 'FormIDs', True);
      try
        slev(e, 'FormIDs', TStringList(NewForms[i]));
      except on Exception do
        ; // nothing we can really do
      end;
      Application.processmessages;
    end;
    
    // save log
    memo.Lines.SaveToFile(ScriptsPath+'\mp\logs\'+fn);

    // script is done, print confirmation messages
    pb.Position := 100;
    lbl.Caption := 'Merge Completed.';
    LogMessage(#13#10);
    LogMessage(dashes);
    LogMessage('Your merged file has been created successfully.  It has '+IntToStr(RecordCount(mgf))+' records.');
    // inform user about records that failed to copy
    if (slFails.Count > 0) then begin
      ShowDetails;
      Application.processmessages;
      MessageDlg('Some records failed to copy, so your merged file is incomplete.  '
      'Please refer to the message log so you can address these records manually.  '
      '(the merged file likely will not work without these records!)', mtConfirmation, [mbOk], 0);
      LogMessage('The following records failed to copy: ');
      for i := 0 to slFails.Count - 1 do 
        LogMessage('    '+slFails[i]);
    end;
    LogMessage(#13#10);
  
    // save log
    memo.Lines.SaveToFile(ScriptsPath+'\mp\logs\'+fn);
    
    // wait for user to close form if details visible
    if (memo.Visible) then begin
      frm.Visible := false;
      frm.ShowModal;
    end;
    
  finally
    frm.Free;
  end;
  // free gui elements
  gear.Free;
  // free stringlists
  NewForms.Free; OldForms.Free; slMerge.Free;  slSelectedFiles.Free;  slMasters.Free;  slFails.Free;
  // return hinthidepasue to default value
  Application.HintHidePause := 1000;
end;


end.