rem version 2.20 - 2019/08/16 by Bruno Silva
@echo off
setlocal ENABLEDELAYEDEXPANSION
set pwd=%~dp0
MODE CON COLS=132 LINES=50
color 2 
Title Black Tiger's Arcade Rom Creator
set "verb=> nul"
set /A merged=0

:MENU
cls
echo                                                  .,G:                                              ,;           
echo   .                      i                      ,WtE#,    :                t           .Gt       f#i j.         
echo   Ef.                   LE              ..     i#D.E#t  .GE       GEEEEEEELEj         j#W:     .E#t  EW,        
echo   E#Wi                 L#E             ;W,    f#f  E#t j#K;       ,;;L#K;;.E#,      ;K#f      i#W,   E##j       
echo   E#K#D:              G#W.            j##,  .D#i   E#GK#f            t#E   E#t    .G#D.      L#D.    E###D.     
echo   E#t,E#f.           D#K.            G###, :KW,    E##D.             t#E   E#t   j#K;      :K#Wfff;  E#jG#W;    
echo   E#WEE##Wt         E#K.           :E####, t#f     E##Wi             t#E   E#t ,K#f   ,GD; i##WLLLLt E#t t##f   
echo   E##Ei;;;;.      .E#E.           ;W#DG##,  ;#G    E#jL#D:           t#E   E#t  j#Wi   E#t  .E#L     E#t  :K#E: 
echo   E#DWWt         .K#E            j###DW##,   :KE.  E#t ,K#j          t#E   E#t   .G#D: E#t    f#E:   E#KDDDD###i
echo   E#t f#K;      .K#D            G##i,,G##,    .DW: E#t   jD          t#E   E#t     ,K#fK#t     ,WW;  E#f,t#Wi,,,
echo   E#Dfff##E,   .W#G           :K#K:   L##,      L#,j#t               t#E   E#t       j###t      .D#; E#t  ;#W:  
echo   jLLLLLLLLL; :W##########Wt ;##D.    L##,       jt ,;                fE   E#t        .G#t        tt DWi   ,KK: 
echo               :,,,,,,,,,,,,,.,,,      .,,                              :   ,;.          ;;                      

echo.
if %merged% EQU 0 (
echo Copy Mame Non-Merged set files to !pwd!MAME folder
) else (
echo Copy Mame Merged set files to !pwd!MAME folder
)
echo.
echo This bat file was tested with mame version 0215
echo.
echo Press H for Help
echo.
echo ** MENU **
echo 1 - Black Tiger - Default
echo 2 - Black Dragon (bootleg)
echo 3 - Black Dragon (Japan)
echo 4 - Black Tiger (bootleg set 1)
echo 5 - Black Tiger (bootleg set 2)
echo 6 - Black Tiger (older)
echo 7 - Black Tiger / Black Dragon (mixed bootleg?)

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

echo.
SET /P M="Choose option and then press ENTER (or Q to quit): "
IF '%M%'=='1' GOTO BLKTIGER
IF '%M%'=='2' GOTO BLKDRGONB
IF '%M%'=='3' GOTO BLKDRGON
IF '%M%'=='4' GOTO BLKTIGERB1
IF '%M%'=='5' GOTO BLKTIGERB2
IF '%M%'=='6' GOTO BLKTIGERA
IF '%M%'=='7' GOTO BLKTIGERB3

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

:BLKTIGER
set zip1m=MAME\blktiger.zip
set ifilesm=bdu-02a.6e+bdu-03a.8e+bd-04.9e+bd-05.10e+bdu-01a.5e+bd-06.1l+bd-15.2n+bd-15.2n+bd-14.9b+bd-13.8b+bd-12.5b+bd-11.4b+bd-08.5a+bd-07.4a+bd-10.9a+bd-09.8a+bd.6k+bd01.8j+bd02.9j+bd03.11k+bd04.11l
set zip1=MAME\blktiger.zip
set ifiles=bdu-02a.6e+bdu-03a.8e+bd-04.9e+bd-05.10e+bdu-01a.5e+bd-06.1l+bd-15.2n+bd-15.2n+bd-14.9b+bd-13.8b+bd-12.5b+bd-11.4b+bd-08.5a+bd-07.4a+bd-10.9a+bd-09.8a+bd.6k+bd01.8j+bd02.9j+bd03.11k+bd04.11l
set md5valid=5d864c2ff5386bf87ecc66d99a29e06d
set ofile=JTBTIGER.rom
set fullname=Black Tiger - Default
GOTO START

:BLKDRGONB
set zip1m=MAME\blktiger.zip
set ifilesm=blkdrgon\bd_02.6e+blkdrgonb\a3+blkdrgon\bd_04.9e+blkdrgon\bd_05.10e+blkdrgonb\a1+bd-06.1l+blkdrgonb\b5+blkdrgonb\b5+blkdrgon\bd_14.9b+blkdrgonb\b3+blkdrgon\bd_12.5b+blkdrgonb\b1+bd-08.5a+bd-07.4a+bd-10.9a+bd-09.8a+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd01.8j+bd02.9j+bd03.11k+bd04.11l
set zip1=MAME\blkdrgonb.zip
set ifiles=blkdrgon.6e+a3+blkdrgon.9e+blkdrgon.10e+a1+bd-06.1l+b5+b5+blkdrgon.9b+b3+blkdrgon.5b+b1+bd-08.5a+bd-07.4a+bd-10.9a+bd-09.8a+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd01.8j+bd02.9j+bd03.11k+bd04.11l
set md5valid=ba4bd532aa917f64282ea2e3f9931ba0
set ofile=Black Dragon (bootleg).rom
set fullname=Black Dragon (bootleg)
GOTO START

:BLKDRGON
set zip1m=MAME\blktiger.zip
set ifilesm=blkdrgon\bd_02.6e+blkdrgon\bd_03.8e+blkdrgon\bd_04.9e+blkdrgon\bd_05.10e+blkdrgon\bd_01.5e+bd-06.1l+blkdrgon\bd_15.2n+blkdrgon\bd_15.2n+blkdrgon\bd_14.9b+blkdrgon\bd_13.8b+blkdrgon\bd_12.5b+blkdrgon\bd_11.4b+bd-08.5a+bd-07.4a+bd-10.9a+bd-09.8a+bd.6k+bd01.8j+bd02.9j+bd03.11k+bd04.11l
set zip1=MAME\blkdrgon.zip
set ifiles=bd_02.6e+bd_03.8e+bd_04.9e+bd_05.10e+bd_01.5e+bd_06.1l+bd_15.2n+bd_15.2n+bd_14.9b+bd_13.8b+bd_12.5b+bd_11.4b+bd_08.5a+bd_07.4a+bd_10.9a+bd_09.8a+bd.6k+bd01.8j+bd02.9j+bd03.11k+bd04.11l
set md5valid=27b235d9b6c835f4cc1c1b04f66c0cc1
set ofile=Black Dragon (Japan).rom
set fullname=Black Dragon (Japan)
GOTO START

:BLKTIGERB1
set zip1m=MAME\blktiger.zip
set ifilesm=bdu-02a.6e+blktigerb1\btiger3.j6+bd-04.9e+bd-05.10e+blktigerb1\btiger1.f6+bd-06.1l+bd-15.2n+bd-15.2n+bd-14.9b+bd-13.8b+bd-12.5b+bd-11.4b+bd-08.5a+bd-07.4a+bd-10.9a+bd-09.8a+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd01.8j+bd02.9j+bd03.11k+bd04.11l
set zip1=MAME\blktigerb1.zip
set ifiles=bdu-02a.6e+btiger3.j6+bd-04.9e+bd-05.10e+btiger1.f6+bd-06.1l+bd-15.2n+bd-15.2n+bd-14.9b+bd-13.8b+bd-12.5b+bd-11.4b+bd-08.5a+bd-07.4a+bd-10.9a+bd-09.8a+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd01.8j+bd02.9j+bd03.11k+bd04.11l
set md5valid=8d354249f58e84c13454d60da2b3c0fa
set ofile=Black Tiger (bootleg set 1).rom
set fullname=Black Tiger (bootleg set 1)
GOTO START

:BLKTIGERB2
set zip1m=MAME\blktiger.zip
set ifilesm=bdu-02a.6e+blktigerb1\btiger3.j6+bd-04.9e+bd-05.10e+blktigerb2\1.bin+bd-06.1l+bd-15.2n+bd-15.2n+bd-14.9b+bd-13.8b+bd-12.5b+bd-11.4b+bd-08.5a+bd-07.4a+bd-10.9a+bd-09.8a+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd01.8j+bd02.9j+bd03.11k+bd04.11l
set zip1=MAME\blktigerb2.zip
set ifiles=bdu-02a.6e+3.bin+bd-04.9e+bd-05.10e+1.bin+bd-06.1l+bd-15.2n+bd-15.2n+bd-14.9b+bd-13.8b+bd-12.5b+bd-11.4b+bd-08.5a+bd-07.4a+bd-10.9a+bd-09.8a+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd01.8j+bd02.9j+bd03.11k+bd04.11l
set md5valid=d4204ac5d626ff49730cbf7498e4dd89
set ofile=Black Tiger (bootleg set 2).rom
set fullname=Black Tiger (bootleg set 2)
GOTO START

:BLKTIGERA
set zip1m=MAME\blktiger.zip
set ifilesm=blktigera\bdu-02.6e+blktigera\bdu-03.8e+bd-04.9e+bd-05.10e+blktigera\bdu-01.5e+bd-06.1l+bd-15.2n+bd-15.2n+bd-14.9b+bd-13.8b+bd-12.5b+bd-11.4b+bd-08.5a+bd-07.4a+bd-10.9a+bd-09.8a+bd.6k+bd01.8j+bd02.9j+bd03.11k+bd04.11l
set zip1=MAME\blktigera.zip
set ifiles=bdu-02.6e+bdu-03.8e+bd-04.9e+bd-05.10e+bdu-01.5e+bd-06.1l+bd-15.2n+bd-15.2n+bd-14.9b+bd-13.8b+bd-12.5b+bd-11.4b+bd-08.5a+bd-07.4a+bd-10.9a+bd-09.8a+bd.6k+bd01.8j+bd02.9j+bd03.11k+bd04.11l
set md5valid=9ae346b9d842ed19197fcc743cf672f0
set ofile=Black Tiger (older).rom
set fullname=Black Tiger (older)
GOTO START

:BLKTIGERB3
set zip1m=MAME\blktiger.zip
set ifilesm=bdu-02a.6e+blktigerb1\btiger3.j6+bd-04.9e+bd-05.10e+blktigerb2\1.bin+blktigerb3\6.1l+blkdrgon\bd_15.2n+blkdrgon\bd_15.2n+bd-14.9b+bd-13.8b+bd-12.5b+bd-11.4b+bd-08.5a+bd-07.4a+bd-10.9a+bd-09.8a+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd01.8j+bd02.9j+bd03.11k+bd04.11l
set zip1=MAME\blktigerb3.zip
set ifiles=2.6e+3.8e+4.9e+5.10e+1.5e+6.1l+15.2n+15.2n+14.9b+13.8b+12.5b+11.4b+8.5a+7.4a+10.9a+9.8a+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd04.11l+bd01.8j+bd02.9j+bd03.11k+bd04.11l
set md5valid=3c9fd4dba6b53a596627986a2d2d4068
set ofile=Black Tiger - Black Dragon (mixed bootleg).rom
set fullname=Black Tiger / Black Dragon (mixed bootleg?)
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
echo                                                  .,G:                                              ,;           
echo   .                      i                      ,WtE#,    :                t           .Gt       f#i j.         
echo   Ef.                   LE              ..     i#D.E#t  .GE       GEEEEEEELEj         j#W:     .E#t  EW,        
echo   E#Wi                 L#E             ;W,    f#f  E#t j#K;       ,;;L#K;;.E#,      ;K#f      i#W,   E##j       
echo   E#K#D:              G#W.            j##,  .D#i   E#GK#f            t#E   E#t    .G#D.      L#D.    E###D.     
echo   E#t,E#f.           D#K.            G###, :KW,    E##D.             t#E   E#t   j#K;      :K#Wfff;  E#jG#W;    
echo   E#WEE##Wt         E#K.           :E####, t#f     E##Wi             t#E   E#t ,K#f   ,GD; i##WLLLLt E#t t##f   
echo   E##Ei;;;;.      .E#E.           ;W#DG##,  ;#G    E#jL#D:           t#E   E#t  j#Wi   E#t  .E#L     E#t  :K#E: 
echo   E#DWWt         .K#E            j###DW##,   :KE.  E#t ,K#j          t#E   E#t   .G#D: E#t    f#E:   E#KDDDD###i
echo   E#t f#K;      .K#D            G##i,,G##,    .DW: E#t   jD          t#E   E#t     ,K#fK#t     ,WW;  E#f,t#Wi,,,
echo   E#Dfff##E,   .W#G           :K#K:   L##,      L#,j#t               t#E   E#t       j###t      .D#; E#t  ;#W:  
echo   jLLLLLLLLL; :W##########Wt ;##D.    L##,       jt ,;                fE   E#t        .G#t        tt DWi   ,KK: 
echo               :,,,,,,,,,,,,,.,,,      .,,                              :   ,;.          ;;                      

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
echo Copy JTBTIGER.rom to SDCard's root or bootrom folder (mister) and the other roms to JTBTIGER folder.
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

