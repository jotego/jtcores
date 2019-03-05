rem version 1.02 - 2019/03/05
@echo off
mode 150,50
color 2 
Title 1942's Arcade Rom Creator
:MENU
cls
rem echo 1942's Arcade Rom Creator
echo   @@@   @@@@@@        @@@    @@@@@@   
echo  @@@@  @@@@@@@@      @@@@   @@@@@@@@  
echo @@@!!  @@!  @@@     @@!@!        @@@  
echo   !@!  !@!  @!@    !@!!@!       @!@   
echo   @!@  !!@!!@!!   @!! @!!      !!@    
echo   !@!    !!@!!!  !!!  !@!     !!:     
echo   !!:       !!!  :!!:!:!!:   !:!      
echo   :!:       !:!  !:::!!:::  :!:       
echo   :::  ::::: ::       :::   :: :::::  
echo    ::   : :  :        :::   :: : :::  

echo.
echo 1 - 1942 (Revision B) - 1942.zip (Mame) - ORIGINAL
echo 2 - 1942 (Revision A) - 1942a.zip (Mame)
echo 3 - Supercharger 1942 - 1942h.zip (Mame)
echo 4 - 1942 (First Version) - 1942b.zip (Mame)
echo 5 - 1942 (Williams Electronics license) - 1942w.zip (Mame)
echo 6 - 1942 (With C64 music) - 1942.zip (HBMame)
echo 7 - 1942 (With attract mode in free play) - 1942.zip (HBMame)
echo 8 - 1942 (Galaga X) - 1942.zip (HBMame)
echo 9 - 1942 Supercharger + C64 Music - 1942h.zip (Mame) + 1942.zip (HBMame)
echo 10 - 1942 GalagaX + C64 Music - 1942.zip (HBMame)

echo.
echo 0 - Quit
rem BAD SET: 1942 (Revision A, bootleg) - 1942abl.zip (Mame)
rem BAD SET: 1942 (Tecfri PCB, bootleg?) - 1942p.zip (Mame)


echo.
SET /P M="Choose option and then press ENTER (or 0 to quit): "
IF '%M%'=='1' GOTO 1942
IF '%M%'=='2' GOTO 1942A
IF '%M%'=='3' GOTO 1942H
IF '%M%'=='4' GOTO 1942B
IF '%M%'=='5' GOTO 1942W
IF '%M%'=='6' GOTO 1942C64
IF '%M%'=='7' GOTO 1942FPA
IF '%M%'=='8' GOTO GALAGAX
IF '%M%'=='9' GOTO 1942HC64
IF '%M%'=='10' GOTO 1942GXC64

IF '%M%'=='0' GOTO QUIT

GOTO MENU

:1942
set zip1=1942.zip
set ifiles=srb-03.m3+srb-04.m4+srb-05.m5+srb-06.m6+srb-06.m6+srb-07.m7+sr-01.c11+sr-02.f2+sr-10.a3+sr-11.a4+sr-08.a1+sr-09.a2+sr-12.a5+sr-13.a6+sr-12.a5+sr-13.a6+sr-14.l1+sr-16.n1+sr-15.l2+sr-17.n2+sb-1.k6+sb-2.d1+sb-3.d2+sb-4.d6+sb-5.e8+sb-6.e9+sb-7.e10+sb-0.f1+sb-8.k3+sb-9.m11
set md5valid=b034856e2abf228761a3828c8c883b4c
set  ofile=JT1942.rom
GOTO START

:1942A
set zip1=1942a.zip
set ifiles=sra-03.m3+sr-04.m4+sr-05.m5+sr-06.m6+sr-06.m6+sr-07.m7+sr-01.c11+sr-02.f2+sr-10.a3+sr-11.a4+sr-08.a1+sr-09.a2+sr-12.a5+sr-13.a6+sr-12.a5+sr-13.a6+sr-14.l1+sr-16.n1+sr-15.l2+sr-17.n2+sb-1.k6+sb-2.d1+sb-3.d2+sb-4.d6+sb-5.e8+sb-6.e9+sb-7.e10+sb-0.f1+sb-8.k3+sb-9.m11
set md5valid=a9ffdccb561adf728460315be7c7c7b9
set  ofile=JT1942A.rom
GOTO START

:1942H
set zip1=1942h.zip
set ifiles=supercharger_1942_@3.m3+supercharger_1942_@4.m4+supercharger_1942_@5.m5+srb-06.m6+srb-06.m6+srb-07.m7+sr-01.c11+sr-02.f2+sr-10.a3+sr-11.a4+sr-08.a1+sr-09.a2+sr-12.a5+sr-13.a6+sr-12.a5+sr-13.a6+sr-14.l1+sr-16.n1+sr-15.l2+sr-17.n2+sb-1.k6+sb-2.d1+sb-3.d2+sb-4.d6+sb-5.e8+sb-6.e9+sb-7.e10+sb-0.f1+sb-8.k3+sb-9.m11
set md5valid=eb38d2264925fcfeb336b561cd1ea220
set  ofile=JT1942H.rom
GOTO START

:1942B
set zip1=1942b.zip
set ifiles=sr-03.m3+sr-04.m4+sr-05.m5+sr-06.m6+sr-06.m6+sr-07.m7+sr-01.c11+sr-02.f2+sr-10.a3+sr-11.a4+sr-08.a1+sr-09.a2+sr-12.a5+sr-13.a6+sr-12.a5+sr-13.a6+sr-14.l1+sr-16.n1+sr-15.l2+sr-17.n2+sb-1.k6+sb-2.d1+sb-3.d2+sb-4.d6+sb-5.e8+sb-6.e9+sb-7.e10+sb-0.f1+sb-8.k3+sb-9.m11
set md5valid=df862aa587fda54c94d6762a8cfcc96c
set  ofile=JT1942B.rom
GOTO START

:1942W
set zip1=1942w.zip
set ifiles=sw-03.m3+sw-04.m4+sw-05.m5+sw-06.m6+sw-06.m6+sw-07.m7+sr-01.c11+sw-02.f2+sr-10.a3+sr-11.a4+sr-08.a1+sr-09.a2+sr-12.a5+sr-13.a6+sr-12.a5+sr-13.a6+sr-14.l1+sr-16.n1+sr-15.l2+sr-17.n2+sb-1.k6+sb-2.d1+sb-3.d2+sb-4.d6+sb-5.e8+sb-6.e9+sb-7.e10+sb-0.f1+sb-8.k3+sb-9.m11
set md5valid=87c218d3e44a36c0e7cb83a0516f0124
set  ofile=JT1942W.rom
GOTO START

:1942C64
set zip1=1942.zip
set ifiles=srb-03.m3+srb-04.m4+srb-05.m5+srb-06.m6+srb-06.m6+srb-07.m7+1942c64\1942c64.c11+sr-02.f2+sr-10.a3+sr-11.a4+sr-08.a1+sr-09.a2+sr-12.a5+sr-13.a6+sr-12.a5+sr-13.a6+sr-14.l1+sr-16.n1+sr-15.l2+sr-17.n2+sb-1.k6+sb-2.d1+sb-3.d2+sb-4.d6+sb-5.e8+sb-6.e9+sb-7.e10+sb-0.f1+sb-8.k3+sb-9.m11
set md5valid=787fafc8c9cc0288d8e6626f0bcb4188
set  ofile=JT1942C64.rom
GOTO START

:1942FPA
set zip1=1942.zip
set ifiles=1942fpa\1942fpa.m3+1942fpa\1942fpa.m4+srb-05.m5+srb-06.m6+srb-06.m6+srb-07.m7+sr-01.c11+sr-02.f2+sr-10.a3+sr-11.a4+sr-08.a1+sr-09.a2+sr-12.a5+sr-13.a6+sr-12.a5+sr-13.a6+sr-14.l1+sr-16.n1+sr-15.l2+sr-17.n2+sb-1.k6+sb-2.d1+sb-3.d2+sb-4.d6+sb-5.e8+sb-6.e9+sb-7.e10+sb-0.f1+sb-8.k3+sb-9.m11
set md5valid=eb2454e91698958a0d3464442d9ad053
set  ofile=JT1942FPA.rom
GOTO START

:GALAGAX
set zip1=1942.zip
set ifiles=galagax\galagax1.n3+galagax\galagax1.n4+galagax\galagax1.n5+galagax\1-n6.bin+galagax\1-n6.bin+galagax\1-n7.bin+sr-01.c11+galagax\galagax1.f2+galagax\galagax2.a3+galagax\galagax2.a4+galagax\galagax2.a1+galagax\galagax2.a2+galagax\galagax2.a5+galagax\galagax2.a6+galagax\galagax2.a5+galagax\galagax2.a6+galagax\galagax2.l1+galagax\galagax2.n1+galagax\galagax2.l2+galagax\galagax2.n2+sb-1.k6+sb-2.d1+sb-3.d2+sb-4.d6+sb-5.e8+sb-6.e9+sb-7.e10+sb-0.f1+sb-8.k3+sb-9.m11
set md5valid=217e43305cb120a553cea32244439a18
set  ofile=JT1942GALAGAX.rom
GOTO START

:1942HC64
set zip1=1942h.zip
set zip2=1942.zip
set ifiles=supercharger_1942_@3.m3+supercharger_1942_@4.m4+supercharger_1942_@5.m5+srb-06.m6+srb-06.m6+srb-07.m7+1942c64\1942c64.c11+sr-02.f2+sr-10.a3+sr-11.a4+sr-08.a1+sr-09.a2+sr-12.a5+sr-13.a6+sr-12.a5+sr-13.a6+sr-14.l1+sr-16.n1+sr-15.l2+sr-17.n2+sb-1.k6+sb-2.d1+sb-3.d2+sb-4.d6+sb-5.e8+sb-6.e9+sb-7.e10+sb-0.f1+sb-8.k3+sb-9.m11
set md5valid=ba98c8f0d34b514f9adbd9ea739e3c33
set  ofile=JT1942HC64.rom
GOTO START

:1942GXC64
set zip1=1942.zip
set ifiles=galagax\galagax1.n3+galagax\galagax1.n4+galagax\galagax1.n5+galagax\1-n6.bin+galagax\1-n6.bin+galagax\1-n7.bin+1942c64\1942c64.c11+galagax\galagax1.f2+galagax\galagax2.a3+galagax\galagax2.a4+galagax\galagax2.a1+galagax\galagax2.a2+galagax\galagax2.a5+galagax\galagax2.a6+galagax\galagax2.a5+galagax\galagax2.a6+galagax\galagax2.l1+galagax\galagax2.n1+galagax\galagax2.l2+galagax\galagax2.n2+sb-1.k6+sb-2.d1+sb-3.d2+sb-4.d6+sb-5.e8+sb-6.e9+sb-7.e10+sb-0.f1+sb-8.k3+sb-9.m11
set md5valid=06c2ac35650f07456fd078eaefcb463b
set  ofile=JT1942GXC64.rom
GOTO START



:START

rem =====================================
setlocal ENABLEDELAYEDEXPANSION

set pwd=%~dp0
echo.
echo.

if NOT EXIST %zip1% GOTO ERRORZIP1
if "%zip2%" NEQ "" if NOT EXIST %zip2% GOTO ERRORZIP2
if NOT EXIST "!pwd!7za.exe" GOTO ERROR7Z
echo.
echo Unziping rom file...
echo.
For /F "Tokens=*" %%I in ('"!pwd!7za" x -y -otmp %zip1%') Do Set RESUNZ=%%I
if "%zip2%" NEQ "" For /F "Tokens=*" %%I in ('"!pwd!7za" x -y -otmp %zip2%') Do Set RESUNZ=%%I

	if !ERRORLEVEL! EQU 0 ( 
		cd tmp
		echo.
		echo Creating rom file...
		echo.
		For /F "Tokens=*" %%I in ('copy /b /y /v %ifiles% "!pwd!%ofile%"') Do Set RESCOPY=%%I
		
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
					echo.
					echo MD5 is "!md5!" but should be "%md5valid%"
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
	echo Error: Cannot find "%zip1%" file. Put it in the same directory as "%~nx0"!
	GOTO END

:ERRORZIP2
	echo.
	echo Error: Cannot find "%zip2%" file. Put it in the same directory as "%~nx0"!
	GOTO END
	
:ERROR7Z
	echo.
	echo Error: Cannot find "7za.exe" file. Put it in the same directory as "%~nx0"!
	GOTO END

:ERRORCOPY
	echo.
	echo Error: Problem creating rom!
	echo. 
	echo %RESCOPY%	
	GOTO END

:ERRORUNZIP
	echo.
	echo Error: problem unzipping file!
	echo. 
	echo %RESUNZ%	
	GOTO END
	

:END
echo.
echo.
pause
GOTO MENU

:QUIT

