rem version 2.20 - 2019/08/16 by Bruno Silva
@echo off
setlocal ENABLEDELAYEDEXPANSION
set pwd=%~dp0
MODE CON COLS=132 LINES=50
color 2 
Title 1943's Arcade Rom Creator
set "verb=> nul"
set /A merged=0

:MENU
cls
echo   .o   .ooooo.         .o     .oooo.   
echo o888  888' `Y88.     .d88   .dP"Y88b  
echo  888  888    888   .d'888         ]8P' 
echo  888   `Vbood888 .d'  888       ^<88b.  
echo  888        888' 88ooo888oo      `88b. 
echo  888      .88P'       888   o.   .88P  
echo o888o   .oP'         o888o  `8bd88P'   

echo.
if %merged% EQU 0 (
echo Copy Mame Non-Merged set files to !pwd!MAME folder
) else (
echo Copy Mame Merged set files to !pwd!MAME folder
)
echo Copy HBMame Merged set files to !pwd!HBMAME folder
echo.
echo This bat file was tested with mame version 0.212
echo.
echo Press H for Help
echo.
echo ** MENU **
echo 1 - 1943: The Battle of Midway (US, Rev C) - Default
echo 2 - 1943 Kai: Midway Kaisen (Japan)
echo 3 - 1943: Midway Kaisen (Japan)
echo 4 - 1943: Midway Kaisen (Japan, no protection hack)
echo 5 - 1943: Midway Kaisen (Japan, Rev B)
echo 6 - 1943: The Battle of Midway (Euro)
echo 7 - 1943: The Battle of Midway (US)
echo 8 - 1943: The Battle of Midway Mark II (US)
echo 9 - 1943 Kai: Midway Kaisen(Ex Super Version 2009-02-10) - HBMame
echo 10 - 1943: The Battle of Midway (bootleg set 2, hack of Japan set) - HBMame

echo.
if %merged% EQU 0 (
echo C - Change from Non-Merged to Merged MAME ROM SET
) else (
echo C - Change from Merged to Non-Merged MAME ROM SET
)
if "%verb%" EQU "" (
echo V - Set verbose Off
) else (
echo V - Set verbose On
)
echo H - HELP
echo Q - Quit


if NOT EXIST "!pwd!MAME" mkdir "!pwd!MAME" 2> nul
if NOT EXIST "!pwd!HBMAME" mkdir "!pwd!HBMAME" 2> nul
echo.
SET /P M="Choose option and then press ENTER (or Q to quit): "
IF '%M%'=='1' GOTO 1943U
IF '%M%'=='2' GOTO 1943KAI
IF '%M%'=='3' GOTO 1943JA
IF '%M%'=='4' GOTO 1943JAH
IF '%M%'=='5' GOTO 1943J
IF '%M%'=='6' GOTO 1943
IF '%M%'=='7' GOTO 1943UA
IF '%M%'=='8' GOTO 1943MII
IF '%M%'=='9' GOTO 1943KAIS01HB
IF '%M%'=='10' GOTO 1943HHB

echo.
IF '%M%'=='c' GOTO CHANGEMERGED
IF '%M%'=='C' GOTO CHANGEMERGED
IF '%M%'=='h' GOTO HELP
IF '%M%'=='H' GOTO HELP
IF '%M%'=='v' GOTO VERBOSE
IF '%M%'=='V' GOTO VERBOSE
IF '%M%'=='q' GOTO QUIT
IF '%M%'=='Q' GOTO QUIT

GOTO MENU

:1943U
set zip1m=MAME\1943.zip
set ifilesm=1943u\bmu01c.12d+1943u\bmu02c.13d+1943u\bmu03c.14d+bm05.4k+bm04.5h+bm14.5f+bm23.8k+bm15.10f+bm19.10j+bm16.11f+bm20.11j+bm17.12f+bm21.12j+bm18.14f+bm22.14j+bm24.14k+bm25.14l+bm06.10a+bm10.10c+bm07.11a+bm11.11c+bm08.12a+bm12.12c+bm09.14a+bm13.14c+bm10.7l+bm11.12l+bm1.12a+bm12.12m+bm2.13a+bm3.14a+bm4.12c+bm5.7f+bm6.4b+bm7.7c+bm8.8c+bm9.6l
set zip1=MAME\1943u.zip
set ifiles=bmu01c.12d+bmu02c.13d+bmu03c.14d+bm05.4k+bm04.5h+bm14.5f+bm23.8k+bm15.10f+bm19.10j+bm16.11f+bm20.11j+bm17.12f+bm21.12j+bm18.14f+bm22.14j+bm24.14k+bm25.14l+bm06.10a+bm10.10c+bm07.11a+bm11.11c+bm08.12a+bm12.12c+bm09.14a+bm13.14c+bm10.7l+bm11.12l+bm1.12a+bm12.12m+bm2.13a+bm3.14a+bm4.12c+bm5.7f+bm6.4b+bm7.7c+bm8.8c+bm9.6l
set md5valid=9b5cfef91f91462265c977a365a453a6
set ofile=jt1943.rom
set fullname=1943: The Battle of Midway (US, Rev C) - Default
GOTO START

:1943KAI
set zip1m=MAME\1943kai.zip
set ifilesm=bmk01.12d+bmk02.13d+bmk03.14d+bmk05.4k+bmk04.5h+bmk14.5f+bmk23.8k+bm15.10f+bm19.10j+bmk16.11f+bmk20.11j+bmk17.12f+bmk21.12j+bmk18.14f+bmk22.14j+bmk24.14k+bmk25.14l+bmk06.10a+bmk10.10c+bmk07.11a+bmk11.11c+bmk08.12a+bmk12.12c+bmk09.14a+bmk13.14c+bmk10.7l+bmk11.12l+bmk1.12a+bmk12.12m+bmk2.13a+bmk3.14a+bm4.12c+bmk5.7f+bm6.4b+bmk7.7c+bmk8.8c+bmk9.6l
set zip1=MAME\1943kai.zip
set ifiles=bmk01.12d+bmk02.13d+bmk03.14d+bmk05.4k+bmk04.5h+bmk14.5f+bmk23.8k+bm15.10f+bm19.10j+bmk16.11f+bmk20.11j+bmk17.12f+bmk21.12j+bmk18.14f+bmk22.14j+bmk24.14k+bmk25.14l+bmk06.10a+bmk10.10c+bmk07.11a+bmk11.11c+bmk08.12a+bmk12.12c+bmk09.14a+bmk13.14c+bmk10.7l+bmk11.12l+bmk1.12a+bmk12.12m+bmk2.13a+bmk3.14a+bm4.12c+bmk5.7f+bm6.4b+bmk7.7c+bmk8.8c+bmk9.6l
set md5valid=a22833b3bf0c0bc6c95c53147f17b48f
set ofile=1943 Kai Midway Kaisen (Japan).rom
set fullname=1943 Kai: Midway Kaisen (Japan)
GOTO START

:1943JA
set zip1m=MAME\1943.zip
set ifilesm=1943ja\bm01.12d+1943b\bm02.13d+1943b\bm03.14d+bm05.4k+bm04.5h+bm14.5f+bm23.8k+bm15.10f+bm19.10j+bm16.11f+bm20.11j+bm17.12f+bm21.12j+bm18.14f+bm22.14j+bm24.14k+bm25.14l+bm06.10a+bm10.10c+bm07.11a+bm11.11c+bm08.12a+bm12.12c+bm09.14a+bm13.14c+bm10.7l+bm11.12l+bm1.12a+bm12.12m+bm2.13a+bm3.14a+bm4.12c+bm5.7f+bm6.4b+bm7.7c+bm8.8c+bm9.6l
set zip1=MAME\1943ja.zip
set ifiles=bm01.12d+bm02.13d+bm03.14d+bm05.4k+bm04.5h+bm14.5f+bm23.8k+bm15.10f+bm19.10j+bm16.11f+bm20.11j+bm17.12f+bm21.12j+bm18.14f+bm22.14j+bm24.14k+bm25.14l+bm06.10a+bm10.10c+bm07.11a+bm11.11c+bm08.12a+bm12.12c+bm09.14a+bm13.14c+bm10.7l+bm11.12l+bm1.12a+bm12.12m+bm2.13a+bm3.14a+bm4.12c+bm5.7f+bm6.4b+bm7.7c+bm8.8c+bm9.6l
set md5valid=42fc270d829ccb930b734d9f76ce704b
set ofile=1943 Midway Kaisen (Japan).rom
set fullname=1943: Midway Kaisen (Japan)
GOTO START

:1943JAH
set zip1m=MAME\1943.zip
set ifilesm=1943jah\bm01_hack.12d+1943b\bm02.13d+1943b\bm03.14d+bm05.4k+bm04.5h+bm14.5f+bm23.8k+bm15.10f+bm19.10j+bm16.11f+bm20.11j+bm17.12f+bm21.12j+bm18.14f+bm22.14j+bm24.14k+bm25.14l+bm06.10a+bm10.10c+bm07.11a+bm11.11c+bm08.12a+bm12.12c+bm09.14a+bm13.14c+bm10.7l+bm11.12l+bm1.12a+bm12.12m+bm2.13a+bm3.14a+bm4.12c+bm5.7f+bm6.4b+bm7.7c+bm8.8c+bm9.6l
set zip1=MAME\1943jah.zip
set ifiles=bm01_hack.12d+bm02.13d+bm03.14d+bm05.4k+bm04.5h+bm14.5f+bm23.8k+bm15.10f+bm19.10j+bm16.11f+bm20.11j+bm17.12f+bm21.12j+bm18.14f+bm22.14j+bm24.14k+bm25.14l+bm06.10a+bm10.10c+bm07.11a+bm11.11c+bm08.12a+bm12.12c+bm09.14a+bm13.14c+bm10.7l+bm11.12l+bm1.12a+bm12.12m+bm2.13a+bm3.14a+bm4.12c+bm5.7f+bm6.4b+bm7.7c+bm8.8c+bm9.6l
set md5valid=98d75a7859c6ab18ce02e17eb04886b4
set ofile=1943 Midway Kaisen (Japan, no protection hack).rom
set fullname=1943: Midway Kaisen (Japan, no protection hack)
GOTO START

:1943J
set zip1m=MAME\1943.zip
set ifilesm=1943j\bm01b.12d+1943j\bm02b.13d+1943j\bm03b.14d+bm05.4k+bm04.5h+bm14.5f+bm23.8k+bm15.10f+bm19.10j+bm16.11f+bm20.11j+bm17.12f+bm21.12j+bm18.14f+bm22.14j+bm24.14k+bm25.14l+bm06.10a+bm10.10c+bm07.11a+bm11.11c+bm08.12a+bm12.12c+bm09.14a+bm13.14c+bm10.7l+bm11.12l+bm1.12a+bm12.12m+bm2.13a+bm3.14a+bm4.12c+bm5.7f+bm6.4b+bm7.7c+bm8.8c+bm9.6l
set zip1=MAME\1943j.zip
set ifiles=bm01b.12d+bm02b.13d+bm03b.14d+bm05.4k+bm04.5h+bm14.5f+bm23.8k+bm15.10f+bm19.10j+bm16.11f+bm20.11j+bm17.12f+bm21.12j+bm18.14f+bm22.14j+bm24.14k+bm25.14l+bm06.10a+bm10.10c+bm07.11a+bm11.11c+bm08.12a+bm12.12c+bm09.14a+bm13.14c+bm10.7l+bm11.12l+bm1.12a+bm12.12m+bm2.13a+bm3.14a+bm4.12c+bm5.7f+bm6.4b+bm7.7c+bm8.8c+bm9.6l
set md5valid=ed51564a2680da2172a4a3203a7d6768
set ofile=1943 Midway Kaisen (Japan, Rev B).rom
set fullname=1943: Midway Kaisen (Japan, Rev B)
GOTO START

:1943
set zip1m=MAME\1943.zip
set ifilesm=bme01.12d+bme02.13d+bme03.14d+bm05.4k+bm04.5h+bm14.5f+bm23.8k+bm15.10f+bm19.10j+bm16.11f+bm20.11j+bm17.12f+bm21.12j+bm18.14f+bm22.14j+bm24.14k+bm25.14l+bm06.10a+bm10.10c+bm07.11a+bm11.11c+bm08.12a+bm12.12c+bm09.14a+bm13.14c+bm10.7l+bm11.12l+bm1.12a+bm12.12m+bm2.13a+bm3.14a+bm4.12c+bm5.7f+bm6.4b+bm7.7c+bm8.8c+bm9.6l
set zip1=MAME\1943.zip
set ifiles=bme01.12d+bme02.13d+bme03.14d+bm05.4k+bm04.5h+bm14.5f+bm23.8k+bm15.10f+bm19.10j+bm16.11f+bm20.11j+bm17.12f+bm21.12j+bm18.14f+bm22.14j+bm24.14k+bm25.14l+bm06.10a+bm10.10c+bm07.11a+bm11.11c+bm08.12a+bm12.12c+bm09.14a+bm13.14c+bm10.7l+bm11.12l+bm1.12a+bm12.12m+bm2.13a+bm3.14a+bm4.12c+bm5.7f+bm6.4b+bm7.7c+bm8.8c+bm9.6l
set md5valid=5006722f516b6fd1709046a542d3dd71
set ofile=1943 The Battle of Midway (Euro).rom
set fullname=1943: The Battle of Midway (Euro)
GOTO START

:1943UA
set zip1m=MAME\1943.zip
set ifilesm=1943ua\bmu01.12d+1943ua\bmu02.13d+1943ua\bmu03.14d+bm05.4k+bm04.5h+bm14.5f+bm23.8k+bm15.10f+bm19.10j+bm16.11f+bm20.11j+bm17.12f+bm21.12j+bm18.14f+bm22.14j+bm24.14k+bm25.14l+bm06.10a+bm10.10c+bm07.11a+bm11.11c+bm08.12a+bm12.12c+bm09.14a+bm13.14c+bm10.7l+bm11.12l+bm1.12a+bm12.12m+bm2.13a+bm3.14a+bm4.12c+bm5.7f+bm6.4b+bm7.7c+bm8.8c+bm9.6l
set zip1=MAME\1943ua.zip
set ifiles=bmu01.12d+bmu02.13d+bmu03.14d+bm05.4k+bm04.5h+bm14.5f+bm23.8k+bm15.10f+bm19.10j+bm16.11f+bm20.11j+bm17.12f+bm21.12j+bm18.14f+bm22.14j+bm24.14k+bm25.14l+bm06.10a+bm10.10c+bm07.11a+bm11.11c+bm08.12a+bm12.12c+bm09.14a+bm13.14c+bm10.7l+bm11.12l+bm1.12a+bm12.12m+bm2.13a+bm3.14a+bm4.12c+bm5.7f+bm6.4b+bm7.7c+bm8.8c+bm9.6l
set md5valid=ca46e4b63b7a4da585b535d479ef6499
set ofile=1943 The Battle of Midway (US).rom
set fullname=1943: The Battle of Midway (US)
GOTO START

:1943MII
set zip1m=MAME\1943mii.zip
set ifilesm=01.12d+02.13d+03.14d+05.4k+04.5h+14.5f+23.8k+bm15.10f+bm19.10j+bm16.11f+bm20.11j+17.12f+21.12j+18.14f+22.14j+24.14k+25.14l+06.10a+10.10c+07.11a+11.11c+08.12a+12.12c+09.14a+13.14c+10.7l+11.12l+bmk1.12a+12.12m+bmk2.13a+bmk3.14a+4.12c+5.7f+6.4b+7.7c+8.8c+9.6l
set zip1=MAME\1943mii.zip
set ifiles=01.12d+02.13d+03.14d+05.4k+04.5h+14.5f+23.8k+bm15.10f+bm19.10j+bm16.11f+bm20.11j+17.12f+21.12j+18.14f+22.14j+24.14k+25.14l+06.10a+10.10c+07.11a+11.11c+08.12a+12.12c+09.14a+13.14c+10.7l+11.12l+bmk1.12a+12.12m+bmk2.13a+bmk3.14a+4.12c+5.7f+6.4b+7.7c+8.8c+9.6l
set md5valid=e56b41c808ea01274b7245c5d89fdef4
set ofile=1943 The Battle of Midway Mark II (US).rom
set fullname=1943: The Battle of Midway Mark II (US)
GOTO START

:1943KAIS01HB
set zip1m=HBMAME\1943kai.zip
set ifilesm=1943kais01\bmk01.12dhc01+bmk02.13d+bmk03.14d+bmk05.4k+bmk04.5h+bmk14.5f+bmk23.8k+bm15.10f+bm19.10j+bmk16.11f+bmk20.11j+bmk17.12f+bmk21.12j+bmk18.14f+bmk22.14j+bmk24.14k+bmk25.14l+bmk06.10a+bmk10.10c+bmk07.11a+bmk11.11c+bmk08.12a+bmk12.12c+bmk09.14a+bmk13.14c+bmk10.7l+bmk11.12l+bmk1.12a+bmk12.12m+bmk2.13a+bmk3.14a+bm4.12c+bmk5.7f+bm6.4b+bmk7.7c+bmk8.8c+bmk9.6l
set zip1=HBMAME\1943kai.zip
set ifiles=1943kais01\bmk01.12dhc01+bmk02.13d+bmk03.14d+bmk05.4k+bmk04.5h+bmk14.5f+bmk23.8k+bm15.10f+bm19.10j+bmk16.11f+bmk20.11j+bmk17.12f+bmk21.12j+bmk18.14f+bmk22.14j+bmk24.14k+bmk25.14l+bmk06.10a+bmk10.10c+bmk07.11a+bmk11.11c+bmk08.12a+bmk12.12c+bmk09.14a+bmk13.14c+bmk10.7l+bmk11.12l+bmk1.12a+bmk12.12m+bmk2.13a+bmk3.14a+bm4.12c+bmk5.7f+bm6.4b+bmk7.7c+bmk8.8c+bmk9.6l
set md5valid=1e15ba96c05f857dc26b34a30b8a58f9
set ofile=1943 Kai Midway Kaisen(Ex Super Version 2009-02-10) - HB.rom
set fullname=1943 Kai: Midway Kaisen(Ex Super Version 2009-02-10)
GOTO START

:1943HHB
set zip1m=HBMAME\1943.zip
set ifilesm=1943h\bme01addontext.12d+bme02.13d+bme03.14d+bm05.4k+bm04.5h+bm14.5f+bm23.8k+bm15.10f+bm19.10j+bm16.11f+bm20.11j+bm17.12f+bm21.12j+bm18.14f+bm22.14j+bm24.14k+bm25.14l+bm06.10a+bm10.10c+bm07.11a+bm11.11c+bm08.12a+bm12.12c+bm09.14a+bm13.14c+bm10.7l+bm11.12l+bm1.12a+bm12.12m+bm2.13a+bm3.14a+bm4.12c+bm5.7f+bm6.4b+bm7.7c+bm8.8c+bm9.6l
set zip1=HBMAME\1943.zip
set ifiles=1943h\bme01addontext.12d+bme02.13d+bme03.14d+bm05.4k+bm04.5h+bm14.5f+bm23.8k+bm15.10f+bm19.10j+bm16.11f+bm20.11j+bm17.12f+bm21.12j+bm18.14f+bm22.14j+bm24.14k+bm25.14l+bm06.10a+bm10.10c+bm07.11a+bm11.11c+bm08.12a+bm12.12c+bm09.14a+bm13.14c+bm10.7l+bm11.12l+bm1.12a+bm12.12m+bm2.13a+bm3.14a+bm4.12c+bm5.7f+bm6.4b+bm7.7c+bm8.8c+bm9.6l
set md5valid=dfda2fd57d15b4db52679088c23068d5
set ofile=1943 The Battle of Midway (bootleg set 2, hack of Japan set) - HB.rom
set fullname=1943: The Battle of Midway (bootleg set 2, hack of Japan set)
GOTO START


:CHANGEMERGED
if %merged% EQU 0 (
	set /A merged=1
	echo.
	echo You will now use Merged MAME ROM SET. Press a key to continue...
) else (
	set /A merged=0
	echo.
	echo You will now use Non-Merged MAME ROM SET. Press a key to continue...
)
pause > nul
GOTO MENU

:VERBOSE
if "%verb%" EQU "" (
	set "verb=> nul"
	echo.
	echo Verbose is Off. Press a key to continue...
) else (
	set "verb="
	echo.
	echo Verbose is On. Press a key to continue...
)
pause > nul
GOTO MENU

:START

rem =====================================
echo.
echo.

if %merged% EQU 1 (
	set zip1=%zip1m%
	set ifiles=%ifilesm%
)


if NOT EXIST %zip1% GOTO ERRORZIP1
if NOT EXIST "!pwd!7za.exe" GOTO ERROR7Z
echo.
echo Starting creating rom for %fullname%
echo.
echo Unziping rom file...
echo.
"!pwd!7za" x -y -otmp %zip1% %verb%

	if !ERRORLEVEL! EQU 0 ( 
		cd tmp
		echo.
		echo Creating rom file...
		echo.
		copy /b /y /v %ifiles% "!pwd!%ofile%" %verb%
		
			if !ERRORLEVEL! EQU 0 ( 
				cd "!pwd!"
				
				set "md5="
					echo.
					echo Checking MD5...
					echo.				
					for /f "skip=1 tokens=* delims=" %%# in ('certutil -hashfile "!pwd!%ofile%" MD5') do (
						if not defined md5 (
							for %%Z in (%%#) do  (
								set "md5=%%Z"
							)
						)
					)	
			
				if "%md5valid%" EQU "!md5!" (
					echo.
					echo ** Process is complete! **
					echo.
					echo Copy "%ofile%" into SD card
				) else (
					echo.
					echo ** PROBLEM IN ROM **
					echo.
					echo MD5 DOESN'T MATCH! CHECK YOU ZIP FILE
					echo It could work anyway...
					echo.
					echo MD5 is !md5! but should be "%md5valid%"
				)
			) else (
				GOTO ERRORCOPY
			)
		cd !pwd!
		rmdir /s /q tmp	
		GOTO END		
	) else (
		GOTO ERRORUNZIP
	)

:ERRORZIP1
	echo.
	echo Error: Cannot find "%zip1%" file.
	GOTO END
	
:ERROR7Z
	echo.
	echo Error: Cannot find "7za.exe" file. Put it in the same directory as "%~nx0"!
	GOTO END

:ERRORCOPY
	cd !pwd!
	rmdir /s /q tmp > nul
	echo.
	echo Error: Problem creating rom!
	echo. 
	GOTO END

:ERRORUNZIP
	cd !pwd!
	rmdir /s /q tmp > nul
	echo.
	echo Error: problem unzipping file!
	echo. 
	GOTO END
	

:HELP
color 7
cls
echo   .o   .ooooo.         .o     .oooo.   
echo o888  888' `Y88.     .d88   .dP"Y88b  
echo  888  888    888   .d'888         ]8P' 
echo  888   `Vbood888 .d'  888       ^<88b.  
echo  888        888' 88ooo888oo      `88b. 
echo  888      .88P'       888   o.   .88P  
echo o888o   .oP'         o888o  `8bd88P'   

echo.
echo HELP for this .bat file
echo.
echo ** Merged and Non-Merged mame roms **
echo By default this .bat file uses non-merged version of mame roms. You can change to merged version by pressing C in the menu
echo.
echo ** Verbose **
echo By default the .bat doesn't display the output of some commands (unzip/copy). You can see the output by pressing V in the menu.
echo.
echo ** Rom Creation **
echo Choose a number from the menu to create a rom from the zip files from mame. This .bat file checks the md5 for the rom created.
echo Having a different md5 doesn't mean that the rom doesn't work.
echo.
echo ** Copy Files to SD Card **
echo Copy jt1943.rom to SDCard's root or bootrom folder (mister) and the other roms to jt1943 folder.
echo.
echo ** For reference **
echo.
echo Merged Set:
echo A merged set takes the parent set and one or more clone sets and puts them all inside the parent set^'s storage. To use the 
echo existing Pac-Man example, combining the Puckman, Midway Pac-Man (USA) sets, along with various bootleg versions - and combining 
echo it all into PUCKMAN.ZIP, would be making a merged set.
echo Remark: The parent games in a merged set DO NOT include BIOS or DEVICE files - they are separate files within the set (An example 
echo would be 100lions (No BIOS in the parent) and Galaga (No device file in the parent) - This is per MAME design.
echo.
echo Non-Merged Set:
echo A non-merged set is one that contains absolutely everything necessary for a given game to run in one ZIP file.
echo The non-merged set is ideal for those people that work on Arcade PCBs as ALL roms/devices/bios files are contained within the game. 
echo This set is also great for those that for instance create their own arcade cabinets and want to copy only very specific games to 
echo their PC/Rapsberry/Other, the game.zip file contain all the files needed, no more searching for the dependent parent files, BIOS 
echo files, device files - just copy galaga.zip and you are set.
echo.
echo.
echo Press a key to return to menu...
pause > nul
color 2 
GOTO MENU



:END
echo.
echo.
echo Press a key to return to menu...
pause > nul
GOTO MENU

:QUIT

