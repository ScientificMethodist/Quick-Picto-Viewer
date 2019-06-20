; Script Name:    AHK Picture Viewer
; Language:       English
; Platform:       Windows XP or later
; Author:         sbc and Marius Șucan
; Script Original Version: 1.0.0 on Oct 4, 2010
; Script Current Version: 2.0.0 on vendredi 24 mai 2019
; Script Function:
; Display images and slideshows; jpeg, jpg, bmp, png, gif, tif, emf
;
; Website of SBC: http://sites.google.com/site/littlescripting/
; Website of Marius Șucan: http://marius.sucan.ro/
;
; AHK forum address for the original script:
; https://autohotkey.com/board/topic/58226-ahk-picture-viewer/
; Licence: GPL. Please reffer to this page for more information. http://www.gnu.org/licenses/gpl.html
;_________________________________________________________________________________________________________________Auto Execute Section____

#Noenv
#NoTrayIcon
#MaxMem, 1524
#Singleinstance, off
#Include, Gdip.ahk

Global PVhwnd, hGDIwin, resultedFilesList := []
   , currentFileIndex, maxFilesIndex := 0
   , appTitle := "AHK Picture Viewer", FirstRun := 1
   , hPicOnGUI, scriptStartTime := A_TickCount
   , prevDisplayiedIMGs := [], SLDhasFiles := 0
   , prevDisplayiedIMGnow := 0, GDIPToken, Agifu
   , slideShowRunning := 0, CurrentSLD := ""
   , LargeListCount := 1, usrFilesFilteru := ""
   , mainSettingsFile := "ahk-picture-viewer.ini"
; User settings
   , WindowBgrColor := "010101", slideShowDelay := 3000
   , IMGresizingMode := 1, SlideHowMode := 1
   , imgFxMode := 1, FlipImgH := 0, FlipImgV := 0
   , filesFilter := ""

DetectHiddenWindows, On
CoordMode, Mouse, Screen
OnExit, Cleanup
Loop, 9
   OnMessage(255+A_Index, "PreventKeyPressBeep" )   ; 0x100 to 0x108

if !(GDIPToken := Gdip_Startup())
{
   Msgbox, 48, %appTitle%, Error: unable to initialize GDI+... Program exits.
   ExitApp
}
IniRead, FirstRun, % mainSettingsFile, General, FirstRun, @
If (FirstRun!=0)
{
   writeSlideSettings(mainSettingsFile)
   FirstRun := 0
   IniWrite, % FirstRun, % mainSettingsFile, General, FirstRun
} Else readSlideSettings(mainSettingsFile)

BuildTray()
BuildGUI()
; OpenSLD("E:\Sucan twins\photos test\tv-only.sld")
Return
;_________________________________________________________________________________________________________________Hotkeys_________________

OpenSLD(fileNamu, doFilesCheck:=0, dontStartSlide:=0) {
  If !FileExist(fileNamu)
  {
     SoundBeep 
     ToolTip, Failed to load file..
     SetTimer, RemoveTooltip, -2000
     Return
  }

  ToolTip, Loading files - please wait...
  Gui, 1: Show,, Loading files - please wait...
  sldGenerateFilesList(fileNamu, doFilesCheck)
  If (dontStartSlide=1)
  {
     SetTimer, RemoveTooltip, -2000
     Return
  }

  If (maxFilesIndex>2)
  {
     RandomPicture()
     InfoToggleSlideShowu()
  } Else
  {
     currentFileIndex := 1
     IDshowImage(1)
  }
  SetTimer, RemoveTooltip, -2000
}

OpenThisFileFolder() {
    If (slideShowRunning=1)
       ToggleSlideShowu()
    resultu := resultedFilesList[currentFileIndex]
    If resultu
    {
       SplitPath, resultu, , dir2open
       Run, %dir2open%
    }
}

OpenThisFile() {
    If (slideShowRunning=1)
       ToggleSlideShowu()
    IDshowImage(currentFileIndex, 1)
}

IncreaseSlideSpeed() {
   slideShowDelay := slideShowDelay + 1000
   If (slideShowDelay>12000)
      slideShowDelay := 12500
   resetSlideshowTimer(1)
}

resetSlideshowTimer(showMsg) {
   If (slideShowRunning=1)
   {
      ToggleSlideShowu()
      Sleep, 1
      ToggleSlideShowu()
   }

   If (showMsg=1)
   {
      delayu := slideShowDelay//1000
      ToolTip, Slideshow speed: %delayu%
      SetTimer, RemoveTooltip, -2000
   }
}

DecreaseSlideSpeed() {
   slideShowDelay := slideShowDelay - 1000
   If (slideShowDelay<900)
      slideShowDelay := 500
   resetSlideshowTimer(1)
}

CopyImagePath() {
  If (slideShowRunning=1)
     ToggleSlideShowu()

  imgpath := resultedFilesList[currentFileIndex]
  If FileExist(imgpath)
     Clipboard := imgpath
}

CopyImage2clip() {
  If (slideShowRunning=1)
     ToggleSlideShowu()

  imgpath := resultedFilesList[currentFileIndex]
  FileGetSize, fileSizu, %imgpath%
  If (FileExist(imgpath) && fileSizu>500)
  {
     pBitmap := Gdip_CreateBitmapFromFile(imgpath)
     If !pBitmap
     {
        Tooltip, Failed to copy image to clipboard...
        SoundBeep 
        SetTimer, RemoveTooltip, -2000
        Return
     }
     FlipImgV := FlipImgH := 0
     imgFxMode := 1
     Sleep, 2
     r := Gdip_SetBitmapToClipboard(pBitmap)
     Sleep, 2
     Gdip_DisposeImage(pBitmap)
     If r
        ToolTip, Image copied to the clipboard...
     SetTimer, RemoveTooltip, -2000
     IDshowImage(currentFileIndex)
  } Else
  {
     Tooltip, Failed to copy image to clipboard...
     SoundBeep 
     SetTimer, RemoveTooltip, -2000
  }
}

#If (WinActive("ahk_id " PVhwnd))
    ~^vk4F::    ; Ctrl+O
       OpenFiles()
    Return

    ~+vk4F::    ; Shift+O
       OpenFolders()
    Return

    ~Esc::
       Gosub, Cleanup
    Return
#If

#If (WinActive("ahk_id " PVhwnd) && CurrentSLD)
    ~^vk4A::    ; Ctrl+J
       Jump2index()
    Return

    ~Insert::
       imgpath := resultedFilesList[currentFileIndex]
       newShowImage(imgpath)
    Return

    ~^vk43::    ; Ctrl+C
       CopyImage2clip()
    Return

    ~+vk43::    ; Shift+C
       CopyImagePath()
    Return

    ~vk4F::   ; O
      OpenThisFile()
    Return

    ~^vk45::   ; Ctrl+E
      OpenThisFileFolder()
    Return
    ~^vk46::   ; Ctrl+F
      enableFilesFilter()
    Return

    ~vk53::   ; S
       SwitchSlideModes()
    Return

    ~vk54::   ; T
       ToggleImageSizingMode()
    Return

    ~BackSpace::
       PrevRandyPicture()
    Return

    ~^BackSpace::
    ~+BackSpace::
    ~!BackSpace::
       NextRandyPicture()
    Return

    ~vkBD::   ; [-]
       DecreaseSlideSpeed()
    Return

    ~F5::
       RefreshFilesList()
    Return

    ~+F5::
       invertRecursiveness()
    Return

    ~^F5::
       If (RegExMatch(CurrentSLD, "i)(\.sld)$") && SLDhasFiles=1)
          cleanFilesList()
       Else
          RefreshFilesList()
    Return

    ~vkBB::    ; [=]
       IncreaseSlideSpeed()
    Return

    ~vk48::    ; H
       TransformIMGh()
    Return

    ~vk56::    ; V
       TransformIMGv()
    Return

    ~Space::
       InfoToggleSlideShowu()
    Return 

    ~vk52::     ; R
       RandomPicture()
    Return

    ~^vk52::     ; Ctrl+R
       RenameThisFile()
    Return

    ~vk46::     ; F
       ToggleImgFX()
    Return

    ~AppsKey::
       Gosub, GuiContextMenu
    Return

    ~Del::
       DeletePicture()
    Return

    ~WheelUp::
    ~Right::
       If (slideShowRunning=1)
          ToggleSlideShowu()
       NextPicture()
    Return

    ~WheelDown::
    ~Left::
       If (slideShowRunning=1)
          ToggleSlideShowu()
       PreviousPicture()
    Return

    ~PgDn::
       resetSlideshowTimer(0)
       NextPicture()
    Return

    ~PgUp::
       resetSlideshowTimer(0)
       PreviousPicture()
    Return

    ~Home:: 
       FirstPicture()
    Return

    ~End:: 
       LastPicture()
    Return
#If

;_________________________________________________________________________________________________________________Labels__________________


invertRecursiveness() {
   If (RegExMatch(CurrentSLD, "i)(\.sld)$") || !CurrentSLD)
      Return
   isPipe := InStr(CurrentSLD, "|") ? 1 : 0
   If (isPipe=1)
      CurrentSLD := StrReplace(CurrentSLD, "|")
   Else
      CurrentSLD := "|" CurrentSLD
   RefreshFilesList()
}

ReloadThisPicture() {
  IDshowImage(currentFileIndex)
}

FirstPicture() { 
   If (slideShowRunning=1)
      ToggleSlideShowu()

   currentFileIndex := 1
   IDshowImage(1)
   Tooltip, Total images loaded: %maxFilesIndex%.
   SetTimer, RemoveTooltip, -2000
}

LastPicture() { 
   If (slideShowRunning=1)
      ToggleSlideShowu()
   currentFileIndex := maxFilesIndex
   IDshowImage(maxFilesIndex)
   Tooltip, Total images loaded: %maxFilesIndex%.
   SetTimer, RemoveTooltip, -2000
}

GuiClose:
Cleanup:
   writeSlideSettings(mainSettingsFile)
   Gdip_Shutdown(GDIPToken)  
ExitApp

OnlineHelp:
   Run, http://www.autohotkey.com/forum/topic62808.html
Return

GuiContextMenu:
   If (slideShowRunning=1)
      ToggleSlideShowu()
   BuildMenu()
Return 

GuiSize:
   If (A_EventInfo=1 || !CurrentSLD)   ;minimized
      Return
   If (maxFilesIndex>0) && (A_TickCount - scriptStartTime>500)
   {
      ShowTheImage("lol", 1)
   } Else
   {
      GuiControl, Hide, PicOnGui1
      GuiControl, Hide, PicOnGui2
   }
Return

ProvokeExit() {
   Static lastInvoked := 0
   If (A_TickCount - lastInvoked<250) && (lastInvoked>1)
      Gosub, Cleanup
   Else If (maxFilesIndex>1 && CurrentSLD)
      GoNextSlide()

   lastInvoked := A_TickCount
}

ToggleImageSizingMode() {
    If (slideShowRunning=1)
       resetSlideshowTimer(0)
    IMGresizingMode++
    If (IMGresizingMode>3)
       IMGresizingMode := 1
    friendly := DefineImgSizing()
    Tooltip, Rescaling mode: %friendly%
    SetTimer, RemoveTooltip, -2000
    IDshowImage(currentFileIndex)
}

DefineImgSizing() {
   friendly := (IMGresizingMode=1) ? "ADAPT ALL INTO VIEW" : "ADAPT ONLY LARGE IMAGES"
   If (IMGresizingMode=3)
      friendly := "NONE (ORIGINAL SIZES)"
   Return friendly
}

InfoToggleSlideShowu() {
  ToggleSlideShowu()
  If (slideShowRunning!=1)
  {
     ToolTip, Slideshow stopped.
     SetTimer, RemoveTooltip, -2000
  } Else 
  {
     delayu := slideShowDelay//1000
     friendly := DefineSlideShowType()
     etaTime := "Estimated time: " SecToHHMMSS(Round((slideShowDelay/1000)*maxFilesIndex))
     ToolTip, Started %friendly% slideshow (speed: %delayu%).`nTotal files: %maxFilesIndex%.`n%etaTime%
     SetTimer, RemoveTooltip, -2000
  }
}

preventScreenOff() {
  If (slideShowRunning=1 && WinActive("A")=PVhwnd)
  {
     MouseMove, 1, 0, 1, R
     MouseMove, -1, 0, 1, R
     SendEvent, {Up}
  }
}

ToggleSlideShowu() {
  If (slideShowRunning=1)
  {
     slideShowRunning := 0
     SetTimer, RandomPicture, Off
     SetTimer, NextPicture, Off
     SetTimer, PreviousPicture, Off
     SetTimer, preventScreenOff, Off
  } Else 
  {
     slideShowRunning := 1
     SetTimer, preventScreenOff, 59520
     If (SlideHowMode=1)
        SetTimer, RandomPicture, %slideShowDelay%
     Else If (SlideHowMode=2)
        SetTimer, PreviousPicture, %slideShowDelay%
     Else If (SlideHowMode=3)
        SetTimer, NextPicture, %slideShowDelay%
  }
}


GoNextSlide() {
  If (slideShowRunning=1)
     resetSlideshowTimer(0)

  If (SlideHowMode=1)
     RandomPicture()
  Else If (SlideHowMode=2)
     PreviousPicture()
  Else If (SlideHowMode=3)
     NextPicture()
}

SecToHHMMSS(Sec) {
  OldFormat := A_FormatFloat
  SetFormat, Float, 02.0
  Hrs  := Sec//3600/1
  Min := Mod(Sec//60, 60)/1
  Sec := Mod(Sec,60)/1
  SetFormat, Float, %OldFormat%
  Return (Hrs ? Hrs ":" : "") Min ":" Sec
}

DefineSlideShowType() {
   friendly := (SlideHowMode=1) ? "RANDOM" : "BACKWARD"
   If (SlideHowMode=3)
      friendly := "FORWARD"
   Return friendly
}

DefineFXmodes() {
   friendly := (imgFxMode=1) ? "ORIGINAL" : "GRAYSCALE"
   If (imgFxMode=3)
      friendly := "INVERTED"
   Return friendly
}

SwitchSlideModes() {
   If (slideShowRunning=1)
      resetSlideshowTimer(0)
   SlideHowMode++
   If (SlideHowMode>3)
      SlideHowMode := 1
   friendly := DefineSlideShowType()
   ToolTip, Slideshow mode: %friendly%.
   SetTimer, RemoveTooltip, -2000
}

ToggleImgFX() {
   If (slideShowRunning=1)
      resetSlideshowTimer(0)
   imgFxMode++
   If (imgFxMode>3)
      imgFxMode := 1
   friendly := DefineFXmodes()
   ToolTip, Image colors: %friendly%.
   SetTimer, RemoveTooltip, -2000
   IDshowImage(currentFileIndex)
}

TransformIMGv() {
   If (slideShowRunning=1)
      resetSlideshowTimer(0)
   FlipImgV := !FlipImgV
   If (FlipImgV=1)
   {
      ToolTip, Image mirrored vertically.
      SetTimer, RemoveTooltip, -2000
   }
   IDshowImage(currentFileIndex)
}

TransformIMGh() {
   If (slideShowRunning=1)
      resetSlideshowTimer(0)
   FlipImgH := !FlipImgH
   If (FlipImgH=1)
   {
      ToolTip, Image mirrored horizonatally.
      SetTimer, RemoveTooltip, -2000
   }
   IDshowImage(currentFileIndex)
}

NextPicture() {
   currentFileIndex++
   If (currentFileIndex<1)
      currentFileIndex := 1
   If (currentFileIndex>maxFilesIndex)
      currentFileIndex := maxFilesIndex
   IDshowImage(currentFileIndex)
}

Jump2index() {
   If (maxFilesIndex<3)
      Return

   If (slideShowRunning=1)
      ToggleSlideShowu()

   InputBox, jumpy, Jump at index #, Type the Type the index number you want to jump to.,,,,,,,, %currentFileIndex%
   If !ErrorLevel
   {
      If jumpy is not Number
         Return

      currentFileIndex := jumpy
      If (currentFileIndex<1)
         currentFileIndex := 1
      If (currentFileIndex>maxFilesIndex)
         currentFileIndex := maxFilesIndex
      IDshowImage(currentFileIndex)
   }
}

enableFilesFilter() {
   Static chars2escape := ".+[{()}-]"
   If (maxFilesIndex<3)
      Return

   If (slideShowRunning=1)
      ToggleSlideShowu()

   If StrLen(filesFilter)>1
   {
      ToolTip, To exclude files matching the string - `nplease insert '&' (and) into your string`nCurrent filter: %filesFilter%
      SetTimer, RemoveTooltip, -5000
   } Else LargeListCount := maxFilesIndex

   InputBox, usrFilesFilteru, Files filter: %usrFilesFilteru%, Type the string to filter files. Files path and/or name must include the string you provide.,,,,,,,, %usrFilesFilteru%
   If !ErrorLevel
   {
      ToolTip, Please wait... Filtering files...
      doFilesCheck := (LargeListCount<2048) ? 2 : 10
      filesFilter := usrFilesFilteru
      Loop, Parse, chars2escape
          filesFilter := StrReplace(filesFilter, A_LoopField, "\" A_LoopField)
      filesFilter := StrReplace(filesFilter, "&")
      ; MsgBox, % filesFilter
      RefreshFilesList(doFilesCheck)
      If (maxFilesIndex<1)
      {
         MsgBox,, %appTitle%, No files matched your filtering criteria:`n%usrFilesFilteru%`n`nThe application will now reload the full list of files.
         usrFilesFilteru := filesFilter := ""
         RefreshFilesList(doFilesCheck)
      }
      SoundBeep, 950, 100
      SetTimer, RemoveTooltip, -2000
   }
}

throwMSGwriteError() {
  Static lastInvoked := 1
  If (ErrorLevel=1)
  {
     SoundBeep, 300, 900
     MsgBox, 16, %appTitle%: ERROR, Unable to write or access the files: permission denied...
     lastInvoked := A_TickCount
  }
}


SaveFilesList() {
   Critical, on
   If StrLen(maxFilesIndex)>1
      FileSelectFile, file2save, S26,, Save files list as Slideshow, Slideshow (*.sld)

   If (!ErrorLevel && StrLen(file2save)>3)
   {
      backCurrentSLD := CurrentSLD
      CurrentSLD := ""
      If !RegExMatch(file2save, "i)(.\.sld)$")
         file2save .= ".sld"
      If FileExist(file2save)
      {
         SplitPath, file2save, OutFileName, OutDir
         MsgBox, 52, %appTitle%, Are you sure you want to overwrite selected file?`n`n%OutFileName%
         IfMsgBox, Yes
         {
            FileSetAttrib, -R, %file2save%
            Sleep, 2
            FileDelete, %file2save%
            throwMSGwriteError()
         } Else
         {
            SaveFilesList()
            Return
         }
      }
      Sleep, 2
      MsgBox, 52, %appTitle%, Do you want to store the current slideshow settings as well ?
      IfMsgBox, Yes
      {
         writeSlideSettings(file2save)
         Sleep, 2
      }

      ToolTip, (Please wait) Saving files list into`n%file2save%
      Loop, % maxFilesIndex + 1
      {
          r := resultedFilesList[A_Index]
          If (r && FileExist(r))
             filesListu .= r "`n"
      }
      FileAppend, %filesListu%, %file2save%, utf-16
      throwMSGwriteError()
      SetTimer, RemoveTooltip, -2000
      SoundBeep, 900, 100
      CurrentSLD := backCurrentSLD
   }
}

cleanFilesList() {
   Critical, on

   If (maxFilesIndex>1)
   {
      backCurrentSLD := CurrentSLD
      CurrentSLD := ""
      ToolTip, (Please wait) Checking files list...
      Loop, % maxFilesIndex + 1
      {
          r := resultedFilesList[A_Index]
          If (r && FileExist(r))
             filesListu .= r "`n"
      }
      Sort, filesListu, U D`n
      file2save := "temp-" A_NowUTC ".sld"
      FileAppend, %filesListu%, %file2save%, utf-16
      throwMSGwriteError()
      ToolTip, (Please wait) Removing duplicates from the list...
      renewCurrentFilesList()
      Loop, Read, %file2save%
      {
         If StrLen(A_LoopReadLine)<4
            Continue

         maxFilesIndex++
         resultedFilesList[maxFilesIndex] := A_LoopReadLine
      }
      SoundBeep, 950, 100
      Sleep, 25
      FileDelete, %file2save%
      throwMSGwriteError()
      RandomPicture()
      SetTimer, RemoveTooltip, -2000
      CurrentSLD := backCurrentSLD
   }
}

readSlideSettings(readThisFile) {
     IniRead, tstslideShowDelay, %readThisFile%, General, slideShowDelay, @
     IniRead, tstIMGresizingMode, %readThisFile%, General, IMGresizingMode, @
     IniRead, tstSlideHowMode, %readThisFile%, General, SlideHowMode, @
     IniRead, tstimgFxMode, %readThisFile%, General, imgFxMode, @
     IniRead, tstWindowBgrColor, %readThisFile%, General, WindowBgrColor, @
     IniRead, tstfilesFilter, %readThisFile%, General, usrFilesFilteru, @
     IniRead, tstFlipImgH, %readThisFile%, General, FlipImgH, @
     IniRead, tstFlipImgV, %readThisFile%, General, FlipImgV, @

     If (tstslideshowdelay!="@" && tstslideshowdelay>300)
        slideShowDelay := tstslideShowDelay
     If (tstimgresizingmode!="@" && StrLen(tstIMGresizingMode)=1 && tstIMGresizingMode<4)
        IMGresizingMode := tstIMGresizingMode
     If (tstimgFxMode!="@" && StrLen(tstimgFxMode)=1 && tstimgFxMode<4)
        imgFxMode := tstimgFxMode
     If (tstFlipImgV!="@" && (tstFlipImgV=1 || tstFlipImgV=0))
        FlipImgV := tstFlipImgV
     If (tstFlipImgH!="@" && (tstFlipImgH=1 || tstFlipImgH=0))
        FlipImgV := tstFlipImgV
     If (tstslidehowmode!="@" && StrLen(tstSlideHowMode)=1 && tstSlideHowMode<4)
        SlideHowMode := tstSlideHowMode
     If (tstWindowBgrColor!="@" && StrLen(tstWindowBgrColor)=6)
     {
        WindowBgrColor := tstWindowBgrColor
        If (scriptInit=1)
           Gui, 1: Color, %tstWindowBgrColor%
     }
     If (tstfilesFilter!="@" && StrLen(Trim(tstfilesFilter))>2)
        usrFilesFilteru := tstfilesFilter
}

writeSlideSettings(file2save) {
    IniWrite, % IMGresizingMode, %file2save%, General, IMGresizingMode
    IniWrite, % imgFxMode, %file2save%, General, imgFxMode
    IniWrite, % SlideHowMode, %file2save%, General, SlideHowMode
    IniWrite, % slideShowDelay, %file2save%, General, slideShowDelay
    ; IniWrite, % filesFilter, %file2save%, General, filesFilter
    IniWrite, % WindowBgrColor, %file2save%, General, WindowBgrColor
    IniWrite, % FlipImgH, %file2save%, General, FlipImgH
    IniWrite, % FlipImgV, %file2save%, General, FlipImgV
    throwMSGwriteError()
}

RandomPicture() {
  Static maxLimitReached, prevJump1, prevjump2

  Random, newJump, 1, %maxFilesIndex%
  Loop, 3
  {
     If (newJump=currentFileIndex || newJump=prevJump1 || newJump=prevJump2) && (maxFilesIndex>1)
        Random, newJump, 1, %maxFilesIndex%
  }
  If (maxFilesIndex=2)
     newJump := (currentFileIndex=2) ? 1 : 2

  prevJump2 := prevJump1
  prevJump1 := newJump
  currentFileIndex := newJump
  resultu := resultedFilesList[currentFileIndex]
  If resultu
  {
     r := ShowTheImage(resultu)
     If (r="fail")
        Return

     If (maxLimitReached!=1)
        findLatestRandyID()
     prevDisplayiedIMGnow++
     If (prevDisplayiedIMGnow>50)
     {
        prevDisplayiedIMGnow := 1
        maxLimitReached := 1
     }
     prevDisplayiedIMGs[prevDisplayiedIMGnow] := resultu
  }
}

findLatestRandyID() {
   Loop, 50
   {
      imgpath := prevDisplayiedIMGs[51 - A_Index]
      If StrLen(imgpath)>3
      {
         prevDisplayiedIMGnow := 51 - A_Index
         Break
      }
   }
}

PrevRandyPicture() {
  If (slideShowRunning=1)
     ToggleSlideShowu()

  If (prevDisplayiedIMGnow<2)
  {
     findLatestRandyID()
     prevDisplayiedIMGnow++
  }

  prevDisplayiedIMGnow--
  If (prevDisplayiedIMGnow<1)
     prevDisplayiedIMGnow := 1

  imgpath := prevDisplayiedIMGs[prevDisplayiedIMGnow]
  If imgpath
  {
     currentFileIndex := detectFileID(imgpath)
     ShowTheImage(imgpath)
  }
}

NextRandyPicture() {
  If (slideShowRunning=1)
     ToggleSlideShowu()

  prevDisplayiedIMGnow++
  imgpath := prevDisplayiedIMGs[prevDisplayiedIMGnow]
  If !imgpath
  {
     prevDisplayiedIMGnow := 1
     imgpath := prevDisplayiedIMGs[prevDisplayiedIMGnow]
  }

  If imgpath
  {
     currentFileIndex := detectFileID(imgpath)
     ShowTheImage(imgpath)
  }
}

DeletePicture() {
  If (slideShowRunning=1)
     ToggleSlideShowu()
  file2rem := resultedFilesList[currentFileIndex]
  ToolTip, File deleted...
  FileSetAttrib, -R, %file2rem%
  Sleep, 2
  FileDelete, %file2rem%
  If ErrorLevel
  {
     ToolTip, File already deleted or access denied...
     SoundBeep
  }
  Sleep, 500
  Tooltip
}

RenameThisFile() {
  If (slideShowRunning=1)
     ToggleSlideShowu()
  file2rem := resultedFilesList[currentFileIndex]
  If !FileExist(file2rem)
  {
     ToolTip, File does not exist...
     SetTimer, RemoveTooltip, -2000
     SoundBeep 
     Return
  }
  SplitPath, file2rem, OutFileName, OutDir
  InputBox, newFileName, Rename file, Please type the new file name.,,,,,,,, %OutFileName%
  If !ErrorLevel
  {
     If FileExist(OutDir "\" newFileName)
     {
        SoundBeep 
        MsgBox, 52, %appTitle%, A file with the name provided already exists.`nDo you want to overwrite it?`n`n%newFileName%
        IfMsgBox, Yes
        {
           FileSetAttrib, -R, %file2rem%
           Sleep, 2
           FileDelete, %OutDir%\%newFileName%
        } Else
        {
           Tooltip, Rename operation canceled...
           SetTimer, RemoveTooltip, -2000
           Return
        }
     }

     Sleep, 2
     FileMove, %file2rem%, %OutDir%\%newFileName%
     If ErrorLevel
     {
        SoundBeep
        ToolTip, ERROR: Access denied...
        SetTimer, RemoveTooltip, -2000
     } Else
     {
        resultedFilesList[currentFileIndex] := OutDir "\" newFileName
        IDshowImage(currentFileIndex)
     }
  }
}

PreviousPicture() {
   currentFileIndex--
   If (currentFileIndex<1)
      currentFileIndex := 1
   If (currentFileIndex>maxFilesIndex)
      currentFileIndex := maxFilesIndex
   IDshowImage(currentFileIndex)
}

OpenFolders() {
   If (slideShowRunning=1)
      ToggleSlideShowu()

   FileSelectFolder, SelectedDir, *%A_WorkingDir%, 2, Select the folder with images. All images found in sub-folders will be loaded as well.
   If (SelectedDir)
   {
      usrFilesFilteru := filesFilter := CurrentSLD := ""
      Gui, 1: Show,, Loading files - please wait...
      coreOpenFolder(SelectedDir)
      CurrentSLD := SelectedDir
   }
}

renewCurrentFilesList() {
  prevDisplayiedIMGs := []
  prevDisplayiedIMGnow := 0
  resultedFilesList := []
  maxFilesIndex := 0
  currentFileIndex := 1
}

coreOpenFolder(thisFolder) {
   If StrLen(thisFolder)>3
   {
      renewCurrentFilesList()
      GetFilesList(thisFolder "\*")
      If (maxFilesIndex>0)
         IDshowImage(1)
      Else
         Gosub, GuiSize
   }
}

RefreshFilesList(mustDoFilesCheck:=0) {
  If (slideShowRunning=1)
     ToggleSlideShowu()

  If (StrLen(filesFilter)<3)
     LargeListCount := maxFilesIndex

  If RegExMatch(CurrentSLD, "i)(\.sld)$")
  {
     currentFileIndex := 1
     doFilesCheck := (LargeListCount<2048) ? 1 : 0
     If (mustDoFilesCheck=10)
        doFilesCheck := 0

     OpenSLD(CurrentSLD, 0, 1)
     If (doFilesCheck=1)
        cleanFilesList()
     Else
        RandomPicture()
  } Else If StrLen(CurrentSLD)>3
     coreOpenFolder(CurrentSLD)
}

OpenFiles() {
   If (slideShowRunning=1)
      ToggleSlideShowu()

    pattern := "Images (*.jpg; *.bmp; *.png; *.gif; *.tif; *.emf; *.sld; *.jpeg)"
    FileSelectFile, SelectImg, M1, %A_WorkingDir%, Open Image or Slideshow, %pattern%
    if (!SelectImg || ErrorLevel)
       Return

    Loop, parse, SelectImg, `n
    {
       If (A_Index=1)
          SelectedDir := A_LoopField
       Else if (A_Index=2)
          imgpath = %SelectedDir%\%A_LoopField%
       Else if (A_Index>2)
          Break
    }

   if (SelectedDir)
   {
      Tooltip, Opening file...
      usrFilesFilteru := filesFilter := CurrentSLD := ""
      renewCurrentFilesList()
      If RegExMatch(imgpath, "i)(.\.sld)$")
      {
         OpenSLD(imgpath)
         Return
      }
      Gui, 1: Show,, Loading files - please wait...
      GetFilesList(SelectedDir "\*|")
      currentFileIndex := detectFileID(imgpath)
      IDshowImage(currentFileIndex)
      Tooltip
      CurrentSLD := "|" SelectedDir
   }
}

detectFileID(imgpath) {
    Loop, % maxFilesIndex + 1
    {
       r := resultedFilesList[A_Index]
       If (r=imgpath)
       {
          good := A_Index
          Break
       }
    }
    If !good
       good := 1

    Return good
}

GuiDropFiles:
   Loop, parse, A_GuiEvent, `n
   {
;     MsgBox, % A_LoopField
      If (A_Index>1500)
         Break
      Else If RegExMatch(A_LoopField, "i)(\.(jpg|emf|tif|jpeg|png|bmp|gif|sld))$")
         imgpath := A_LoopField
   }

   if (imgpath)
   {
      Tooltip, Opening file...
      If (slideShowRunning=1)
         ToggleSlideShowu()

      SplitPath, imgpath,,imagedir
      If !imagedir
         Return

      usrFilesFilteru := filesFilter := CurrentSLD := ""
      renewCurrentFilesList()
      If RegExMatch(imgpath, "i)(.\.sld)$")
      {
         OpenSLD(imgpath)
         Return
      }
      GetFilesList(imagedir "\*|")
      currentFileIndex := detectFileID(imgpath)
      IDshowImage(currentFileIndex)
      CurrentSLD := "|" imagedir
      Tooltip
   }
Return

RemoveTooltip() {
   Tooltip
}

GetImgDimension(imgpath, ByRef w, ByRef h) {
   Static prevImgPath, prevW, prevH
   If (prevImgPath=imgpath && h>1 && w>1)
   {
      W := prevW
      H := prevH
      Return 1
   }

   pBM := Gdip_CreateBitmapFromFile(imgpath)
   w := Gdip_GetImageWidth( pBM )
   h := Gdip_GetImageHeight( pBM )
   Gdip_DisposeImage( pBM )
   r := (w>1 && h>1) ? 1 : 0
   Return r
}

BuildTray() {
   Menu, Tray, NoStandard
   Menu, Tray, Add, &Open File`tShift+O, OpenFiles
   Menu, Tray, Add, &Open Folders`tCtrl+O, OpenFolders
   Menu, Tray, Add,
   Menu, Tray, Add, &More options, BuildMenu
   Menu, Tray, Add,
   Menu, Tray, Add, &About / Help, OnlineHelp
   Menu, Tray, Add,
   Menu, Tray, Add, &Exit`tEsc, Cleanup
}

BuildMenu() {
   Static wasCreated
   If (wasCreated=1)
   {
      Menu, PVmenu, Delete
      Menu, PVsliMenu, Delete
      Menu, PVnav, Delete
      Menu, PVview, Delete
      Menu, PVfList, Delete
      Menu, PVtFile, Delete
   }

   sliMode := DefineSlideShowType()
   sliSpeed := slideShowDelay//1000
   Menu, PVsliMenu, Add, &Start slideshow`tSpace, ToggleSlideShowu
   Menu, PVsliMenu, Add, Next &slide`tL-Click, GoNextSlide
   Menu, PVsliMenu, Add,
   Menu, PVsliMenu, Add, &Toggle slideshow mode`tS, SwitchSlideModes
   Menu, PVsliMenu, Add, %sliMode%, SwitchSlideModes
   Menu, PVsliMenu, Disable, %sliMode%
   Menu, PVsliMenu, Add,
   Menu, PVsliMenu, Add, &Increase speed`tMinus [-], IncreaseSlideSpeed
   Menu, PVsliMenu, Add, &Decrease speed`tEqual [=], DecreaseSlideSpeed
   Menu, PVsliMenu, Add, Current speed: %sliSpeed%, DecreaseSlideSpeed
   Menu, PVsliMenu, Disable, Current speed: %sliSpeed%

   infoImgResize := DefineImgSizing()
   infoImgFX := DefineFXmodes()
   Menu, PVview, Add, &Toggle Resizing Mode`tT, ToggleImageSizingMode
   Menu, PVview, Add, %infoImgResize%, ToggleImageSizingMode
   Menu, PVview, Disable, %infoImgResize%
   Menu, PVview, Add,
   Menu, PVview, Add, &Switch colors display`tF, ToggleImgFX
   Menu, PVview, Add, %infoImgFX%, ToggleImgFX
   Menu, PVview, Disable, %infoImgFX%
   Menu, PVview, Add,
   Menu, PVview, Add, Mirror &horizontally`tH, TransformIMGh
   Menu, PVview, Add, Mirror &vertically`tV, TransformIMGv
   If (FlipImgV=1)
      Menu, PVview, Check, Mirror &vertically`tV

   If (FlipImgH=1)
      Menu, PVview, Check, Mirror &horizontally`tH

   imgpath := prevDisplayiedIMGs[prevDisplayiedIMGnow]
   Menu, PVnav, Add, &First`tHome, FirstPicture
   Menu, PVnav, Add, &Previous`tRight, PreviousPicture
   Menu, PVnav, Add, &Next`tLeft, NextPicture
   Menu, PVnav, Add, &Last`tEnd, LastPicture
   Menu, PVnav, Add,
   Menu, PVnav, Add, &Jump at #`tCtrl+J, Jump2index
   Menu, PVnav, Add, &Random`tR, RandomPicture
   If imgpath
      Menu, PVnav, Add, &Prev. random image`tBackspace, PrevRandyPicture

   Menu, PVtFile, Add, &Copy image to Clipboard`tCtrl+C, CopyImage2clip
   Menu, PVtFile, Add, 
   Menu, PVtFile, Add, &Open (with external app)`tO, OpenThisFile
   Menu, PVtFile, Add, &Open containing folder`tCtrl+E, OpenThisFileFolder
   Menu, PVtFile, Add, &Rename`tCtrl+R, RenameThisFile
   Menu, PVtFile, Add, &Delete`tDelete, DeletePicture

   DefNAMErefresh := RegExMatch(CurrentSLD, "i)(\.sld)$") ? "Reload .SLD file" : "Refresh opened folder(s)"
   Menu, PVfList, Add, %DefNAMErefresh%`tF5, RefreshFilesList
   If (maxFilesIndex>2)
   {
      If (RegExMatch(CurrentSLD, "i)(\.sld)$") && SLDhasFiles=1)
         Menu, PVfList, Add, Clean duplicate/inexistent entries, cleanFilesList
      Menu, PVfList, Add, Text filtering`tCtrl+F, enableFilesFilter
      If StrLen(filesFilter)>1
         Menu, PVfList, Check, Text filtering`tCtrl+F
      Menu, PVfList, Add, Save as slideshow, SaveFilesList
   }

   Menu, PVmenu, Add, &Open File`tCtrl+O, OpenFiles
   Menu, PVmenu, Add, &Open Folders`tShift+O, OpenFolders
   Menu, PVmenu, Add,
   If (maxFilesIndex>0 && CurrentSLD)
   {
      Menu, PVmenu, Add, File, :PVtFile
      Menu, PVmenu, Add, Files list, :PVfList
      Menu, PVmenu, Add, View, :PVview
      If (maxFilesIndex>1 && CurrentSLD)
      {
         Menu, PVmenu, Add, Navigation, :PVnav
         Menu, PVmenu, Add, Slideshow, :PVsliMenu
      }
      Menu, PVmenu, Add,
   }

   Menu, PVmenu, Add, About / Help, OnlineHelp
   Menu, PVmenu, Add,
   Menu, PVmenu, Add, &Exit`tEsc, Cleanup
   wasCreated := 1
   Menu, PVmenu, Show
}

BuildGUI() {
   global ;PicOnGUI, PVhwnd, appTitle, ScriptMsg , ScriptMsgW, ScriptMsgH, hue
   local MaxGUISize, MinGUISize, initialwh, guiw, guih
   MaxGUISize = -DPIScale
   MinGUISize := "-DpiScale +MinSize" . A_ScreenWidth//4 . "x" . A_ScreenHeight//4
   initialwh := "w" . A_ScreenWidth//3 . " h" . A_ScreenHeight//3
   Gui, 1: Color, %WindowBgrColor%
   Gui, 1: Margin, 0, 0
   GUI, 1: -DPIScale +Resize %MaxGUISize% %MinGUISize% +hwndPVhwnd +LastFound +OwnDialogs
   Gui, 1: Add, Picture, x1 y1 gProvokeExit vPicOnGUI1
   Gui, 1: Add, Picture, x1 y1 gProvokeExit vPicOnGUI2
   ; GuiControl, Disable, PicOnGui1
   ; GuiControl, Disable, PicOnGui2
   GuiControl, Hide, PicOnGui1
   GuiControl, Hide, PicOnGui2
   Gui, 1: Show, maximize center %initialwh%, %appTitle%

   Gui, 2: -Caption +E0x80000 +LastFound +AlwaysOnTop +ToolWindow +OwnDialogs +hwndhGDIwin
   Gui, 2: Show, NoActivate
}

newShowImage(imgpath) {
    If !pBitmap := Gdip_CreateBitmapFromFile(imgpath)
       Return

    OriginalWidth := Gdip_GetImageWidth(pBitmap)
    OriginalHeight := Gdip_GetImageHeight(pBitmap)
    Ratio := OriginalWidth/OriginalHeight

    If (OriginalWidth >= A_ScreenWidth//2) || (OriginalHeight >= A_ScreenHeight//2)
    {
      If (OriginalWidth >= OriginalHeight)
         Width := A_ScreenWidth//2, Height := Width*(1/Ratio)
      Else
         Height := A_ScreenHeight//2, Width := Height*Ratio
    } Else
    {
        Width := OriginalWidth
        Height := OriginalHeight
    }

    Gdip_GetRotatedDimensions(Width, Height, Angle, RWidth, RHeight)
    Gdip_GetRotatedTranslation(Width, Height, Angle, xTranslation, yTranslation)
    hbm := CreateDIBSection(RWidth, RHeight)
    hdc := CreateCompatibleDC()
    obm := SelectObject(hdc, hbm)
    G := Gdip_GraphicsFromHDC(hdc)
    Gdip_SetInterpolationMode(G, 1)

    Gdip_TranslateWorldTransform(G, xTranslation, yTranslation)
    Gdip_RotateWorldTransform(G, Angle)
    If Horizontal
       Gdip_ScaleWorldTransform(G, -1, 1), Gdip_TranslateWorldTransform(G, -Width, 0)
    If Vertical
       Gdip_ScaleWorldTransform(G, 1, -1), Gdip_TranslateWorldTransform(G, 0, -Height)
    Gdip_DrawImage(G, pBitmap, 0, 0, Width, Height, 0, 0, OriginalWidth, OriginalHeight)
    Gdip_ResetWorldTransform(G)
    UpdateLayeredWindow(hGDIwin, hdc, (A_ScreenWidth-RWidth)//2, (A_ScreenHeight-RHeight)//2, RWidth, RHeight)
    Gdip_DeleteGraphics(G)
    Gdip_DisposeImage(pBitmap)
}

ShowTheImage(imgpath, usePrevious:=0) {
   Static prevImgH, prevImgW, prevImgPath
        , lastInvoked := 1, prevPicCtrl := 1
        , lastInvoked2 := 1

   If (usePrevious=1 && StrLen(prevImgPath)>3)
      imgpath := prevImgPath

   FileGetSize, fileSizu, %imgpath%
   If (!FileExist(imgpath) && !fileSizu && usePrevious=0)
   {
      If (WinActive("A")=PVhwnd)
      {
         Gui, 1: Show,, *!(%currentFileIndex%/%maxFilesIndex%) %imgpath%
         Tooltip, ERROR: Unable to load the file...`n%imgpath%
         SetTimer, RemoveTooltip, -2000
      }
      If (A_TickCount - lastInvoked2>125)
         SoundBeep, 300, 50
      lastInvoked2 := A_TickCount
      Return "fail"
   }

   lastInvoked2 := A_TickCount
   SplitPath, imgpath, imgname
   WinGetPos, mainX, mainY,,, ahk_id %PVhwnd%
   GetClientSize(mainWid, mainHeig, PVhwnd)
   If (WinActive("A")!=PVhwnd && slideShowRunning=1)
      Gui, 1: Show, NoActivate x%mainX% y%mainY% w%mainWid% h%mainHeig%, (%currentFileIndex%/%maxFilesIndex%) %imgpath%
   Else
      Gui, 1: Show,, (%currentFileIndex%/%maxFilesIndex%) %imgpath%

   If (A_TickCount - lastInvoked>95) || (usePrevious=1)
   {
     lastInvoked := A_TickCount
     thisPicCtrl := (prevPicCtrl=1) ? 2 : 1
     If (usePrevious!=1 && StrLen(imgpath)>3)
     {
        r := GetImgDimension(imgpath, imgW, imgH)
        prevImgW := imgW
        prevImgH := imgH
     } Else If (usePrevious=1 && StrLen(prevImgPath)>3)
     {
        thisPicCtrl := prevPicCtrl
        r := 1, imgW := prevImgW
        imgH := prevImgH
     }

     if !r
     {
        If (WinActive("A")=PVhwnd)
        {
           Tooltip, ERROR: Unable to display the image...
           SetTimer, RemoveTooltip, -2000
        }
        SoundBeep, 300, 100
        Return "fail"
     }

     result := ResizeImage(thisPicCtrl, mainWid, mainHeig, imgpath, imgW, imgH, usePrevious)
     If (usePrevious!=1 && StrLen(imgpath)>3)
        prevImgPath := imgpath
     prevPicCtrl := thisPicCtrl
     lastInvoked := A_TickCount
   } Else SetTimer, ReloadThisPicture, -300
   lastInvoked := A_TickCount
}

ResizeImage(tehCtrl, GuiW, GuiH, imgpath, imgW, imgH, usePrevious) {
   Static ohBitmap
   PicRatio := Round(imgW/imgH, 5)
   GuiRatio := Round(GuiW/GuiH, 5)
   if (imgW <= GuiW) && (imgH <= GuiH)
   {
      ResizedW := GuiW
      ResizedH := Round(ResizedW / PicRatio, 5)
      If (ResizedH>GuiH)
      {
         ResizedH := (imgH <= GuiH) ? GuiH : imgH         ;set the maximum picture height to the original height
         ResizedW := Round(ResizedH * PicRatio, 5)
      }   

      If (IMGresizingMode=2)
      {
         ResizedW := imgW
         ResizedH := imgH
      }
   } else if (PicRatio > GuiRatio)
   {
      ResizedW := GuiW
      ResizedH := Round(ResizedW / PicRatio, 5)
   } else
   {
      ResizedH := (imgH >= GuiH) ? GuiH : imgH         ;set the maximum picture height to the original height
      ResizedW := Round(ResizedH * PicRatio, 5)
   }

   If (IMGresizingMode=3)
   {
      ResizedW := imgW
      ResizedH := imgH
   }

   wscale := Round(ResizedW / imgW, 3)
   hscale := Round(ResizedH / imgH, 3)
   ; If RegExMatch(imgpath, "i)(\.gif)$")
   ; {
   ;    SoundBeep 
   ;    GuiControl, Hide, PicOnGUI1
   ;    GuiControl, Hide, PicOnGUI2
   ;    Agifu := AddAnimatedGIF(imgpath, (GuiW-ResizedW)//2, (GuiH-ResizedH)//2, ResizedW, ResizedH)
   ;    Return
   ; }

   If (usePrevious=0)
   {
      DeleteObject(ohBitmap)
      ohBitmap := Gdip_ShowImgonGui(imgpath, wscale, hscale, imgW, imgH)
   }
   otherPicCtrl := (tehCtrl=1) ? 2 : 1
   GuiControl, MoveDraw, PicOnGui%tehCtrl%, % "w" ResizedW " h" ResizedH " x" (GuiW-ResizedW)//2 " y" (GuiH-ResizedH)//2
   GuiControl,, PicOnGui%tehCtrl%, HBITMAP:*%ohBitmap%
   GuiControl, Show, PicOnGUI%tehCtrl%
   GuiControl, Hide, PicOnGUI%otherPicCtrl%
   Return 1
}

Gdip_ShowImgonGui(imgfile, wscale, hscale, Width, Height) {
  pBitmap := Gdip_CreateBitmapFromFile(imgfile)
  If !pBitmap || ErrorLevel
  {
     SoundBeep 
     Return 0
  }
  If (imgFxMode=2)       ; grayscale
     matrix := "0.299|0.299|0.299|0|0|0.587|0.587|0.587|0|0|0.114|0.114|0.114|0|0|0|0|0|1|0|0|0|0|0|1"
  Else If (imgFxMode=3)  ; negative / invert
     matrix := "-1|0|0|0|0|0|-1|0|0|0|0|0|-1|0|0|0|0|0|1|0|1|1|1|0|1"

  newW := Width * wscale
  newH := Height * hscale
  pBitmap2 := Gdip_CreateBitmap(newW, newH)
  G2 := Gdip_GraphicsFromImage(pBitmap2)
  Gdip_SetInterpolationMode(G2, 1)
  Gdip_SetSmoothingMode(G2, 1)
  If (FlipImgH=1)
     Gdip_ScaleWorldTransform(G2, -1, 1), Gdip_TranslateWorldTransform(G2, -newW, 0)
  If (FlipImgV=1)
     Gdip_ScaleWorldTransform(G2, 1, -1), Gdip_TranslateWorldTransform(G2, 0, -newH)

  Gdip_DrawImage(G2, pBitmap, 0, 0, Width * wscale, Height * hscale, 0, 0, Width, Height, matrix)
  ohBitmap := Gdip_CreateHBITMAPFromBitmap(pBitmap2)
  Gdip_DeleteGraphics(G), Gdip_DisposeImage(pBitmap)
  Gdip_DeleteGraphics(G2), Gdip_DisposeImage(pBitmap2)
  Return ohBitmap
}

GetClientSize(ByRef w, ByRef h, hwnd) {
; by Lexikos http://www.autohotkey.com/forum/post-170475.html
    VarSetCapacity(rc, 16, 0)
    DllCall("GetClientRect", "uint", hwnd, "uint", &rc)
    w := NumGet(rc, 8, "int")
    h := NumGet(rc, 12, "int")
} 

sldGenerateFilesList(readThisFile, doFilesCheck) {
    renewCurrentFilesList()
    CurrentSLD := ""
    SLDhasFiles := 0
    FileRead, tehFileVar, %readThisFile%
    FileReadLine, firstLine, %readThisFile%, 1
    If InStr(firstLine, "[General]")
    {
       properFormat := 1
       readSlideSettings(readThisFile)
    } Else
       tehFileVar := RegExReplace(tehFileVar, "\x22", "@")

    filterBehaviour := InStr(usrFilesFilteru, "&") ? 1 : 2
    Loop, Parse, tehFileVar,`n,`r
    {
       line := StrReplace(A_LoopField, "@-")
       If (properFormat!=1)
          line := StrReplace(line, "@")
       line := Trim(line)
       If InStr(A_LoopField, "|")
       {
          doRecursive := 2
          line := StrReplace(line, "|")
       } Else doRecursive := 1

       SplitPath, line, OutFileName, OutDir
       If (StrLen(OutDir)>2 && RegExMatch(line, "i)(\.(tif|emf|jpg|jpeg|png|bmp|gif))$"))
       {
          If (doFilesCheck=1)
          {
             If !FileExist(line)
                Continue
          }

          If StrLen(filesFilter)>1
          {
             If (!RegExMatch(line, "i)(" filesFilter ")") && filterBehaviour=2)
                Continue
             Else If (RegExMatch(line, "i)(" filesFilter ")") && filterBehaviour=1)
                Continue
          }
          maxFilesIndex++
          SLDhasFiles := 1
          resultedFilesList[maxFilesIndex] := line
       } Else If (StrLen(OutDir)>2 && StrLen(OutFileName)<2)
       {
          GetFilesList(OutDir "\*", doRecursive)
       }
    }
    currentFileIndex := 1
    CurrentSLD := readThisFile
}

GetFilesList(strDir, doRecursive:=1) {
  ToolTip, Loading the list of files... please wait.`n%strDir%

  filterBehaviour := InStr(usrFilesFilteru, "&") ? 1 : 2
  If InStr(strDir, "|")
  {
     doRecursive := 2
     strDir := StrReplace(strDir, "|")
  }

  dig := (doRecursive=2) ? "" : "R"
  Loop, Files, %strDir%, %dig%
  {
      If RegExMatch(A_LoopFileName, "i)(\.(tif|emf|jpg|jpeg|png|bmp|gif))$")
      {
         If StrLen(filesFilter)>1
         {
            If (!RegExMatch(A_LoopFileFullPath, "i)(" filesFilter ")") && filterBehaviour=2)
               Continue
            Else If (RegExMatch(A_LoopFileFullPath, "i)(" filesFilter ")") && filterBehaviour=1)
               Continue
         }
         maxFilesIndex++
         resultedFilesList[maxFilesIndex] := A_LoopFileFullPath
      }
  }
  SetTimer, RemoveTooltip, -2000
}

IDshowImage(imgID,opentehFile:=0) {
    resultu := resultedFilesList[imgID]
    If !resultu
    {
       SoundBeep 
       Return
    }

    If (opentehFile=1)
    {
       If !FileExist(resultu)
       {
          Tooltip, ERROR: The file is missing...
          SoundBeep 
          SetTimer, RemoveTooltip, -2000
          Sleep, 900
       }
       Run, %resultu%
    } Else ShowTheImage(resultu)
}

PreventKeyPressBeep() {
   IfEqual,A_Gui,1,Return 0 ; prevent keystrokes for GUI 1 only
}

AddAnimatedGIF(imagefullpath , x="", y="", w="", h="", guiname = "1") {
  global AG1
  static AGcount:=0, controlAdded, pic
  AGcount := 1
  html := "<html><body style='background-color: transparent' style='overflow:hidden' leftmargin='0' topmargin='0'><img src='" imagefullpath "' width=" w " height=" h " border=0 padding=0></body></html>"
  Gui, AnimGifxx:Add, Picture, vpic, %imagefullpath%
  GuiControlGet, pic, AnimGifxx:Pos
  Gui, AnimGifxx:Destroy
  If (controlAdded!=1)
  {
     controlAdded := 1
     Gui, %guiname%: Add, ActiveX, % (x = "" ? " " : " x" x ) . (y = "" ? " " : " y" y ) . (w = "" ? " w" picW : " w" w ) . (h = "" ? " h" picH : " h" h ) " vAG" AGcount, Shell.Explorer
  }
  AG%AGcount%.navigate("about:blank")
  AG%AGcount%.document.write(html)
  return "AG" AGcount
}
