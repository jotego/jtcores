rem version 1.02 - 2019/03/05
@echo off
mode 150,50
color 2 
Title 1943's Arcade Rom Creator
:MENU
cls
rem echo 1943's Arcade Rom Creator
echo   .o   .ooooo.         .o     .oooo.   
echo o888  888' `Y88.     .d88   .dP"Y88b  
echo  888  888    888   .d'888         ]8P' 
echo  888   `Vbood888 .d'  888       ^<88b.  
echo  888        888' 88ooo888oo      `88b. 
echo  888      .88P'       888   o.   .88P  
echo o888o   .oP'         o888o  `8bd88P'   

echo.
echo 1 - 1943: The Battle of Midway (US, Rev C) - 1943u.zip (Mame) - ORIGINAL
echo 2 - 1943: The Battle of Midway (Euro) - 1943.zip (Mame)
echo 3 - 1943: The Battle of Midway (US) - 1943ua.zip (Mame)
echo 4 - 1943: Midway Kaisen (Japan, Rev B) - 1943j.zip (Mame)
echo 5 - 1943: Midway Kaisen (Japan) - 1943ja.zip (Mame)
echo 6 - 1943: Midway Kaisen (Japan, no protection hack) - 1943jah.zip (Mame)
echo 7 - 1943 Kai: Midway Kaisen (Japan) - 1943kai.zip (Mame)
echo 8 - 1943: The Battle of Midway Mark II (US) - 1943mii.zip (Mame)
echo 9 - 1943: The Battle of Midway (bootleg set 2, hack of Japan set) - 1943.zip (HBMame)
echo 10 - 1943 Kai: Midway Kaisen(Ex Super Version)(2009-02-10)(Japan) - 1943kai.zip (HBMame)

echo.
echo 0 - Quit
rem BAD SET: 1943: Battle of Midway (bootleg, hack of Japan set) - 1943b.zip (Mame)
rem BAD SET: 1943: Midway Kaisen (bootleg) - 1943bj.zip (Mame)
rem BAD SET: 1943: Midway Kaisen (bootleg set 2, hack of Japan set) - 1943b2.zip (HBMame)


echo.
SET /P M="Choose option and then press ENTER (or 0 to quit): "
IF '%M%'=='1' GOTO 1943U
IF '%M%'=='2' GOTO 1943
IF '%M%'=='3' GOTO 1943UA
IF '%M%'=='4' GOTO 1943J
IF '%M%'=='5' GOTO 1943JA
IF '%M%'=='6' GOTO 1943JAH
IF '%M%'=='7' GOTO 1943KAI
IF '%M%'=='8' GOTO 1943MII
IF '%M%'=='9' GOTO 1943H
IF '%M%'=='10' GOTO 1943KAIS01

IF '%M%'=='0' GOTO QUIT

GOTO MENU

:1943U
set zip1=1943u.zip
set ifiles=bmu01c.12d+bmu02c.13d+bmu03c.14d+bm05.4k+bm04.5h+bm14.5f+bm23.8k+bm15.10f+bm19.10j+bm16.11f+bm20.11j+bm17.12f+bm21.12j+bm18.14f+bm22.14j+bm24.14k+bm25.14l+bm06.10a+bm10.10c+bm07.11a+bm11.11c+bm08.12a+bm12.12c+bm09.14a+bm13.14c+bm10.7l+bm11.12l+bm1.12a+bm12.12m+bm2.13a+bm3.14a+bm4.12c+bm5.7f+bm6.4b+bm7.7c+bm8.8c+bm9.6l
set md5valid=9b5cfef91f91462265c977a365a453a6
set  ofile=JT1943.rom
GOTO START

:1943
set zip1=1943.zip
set ifiles=bme01.12d+bme02.13d+bme03.14d+bm05.4k+bm04.5h+bm14.5f+bm23.8k+bm15.10f+bm19.10j+bm16.11f+bm20.11j+bm17.12f+bm21.12j+bm18.14f+bm22.14j+bm24.14k+bm25.14l+bm06.10a+bm10.10c+bm07.11a+bm11.11c+bm08.12a+bm12.12c+bm09.14a+bm13.14c+bm10.7l+bm11.12l+bm1.12a+bm12.12m+bm2.13a+bm3.14a+bm4.12c+bm5.7f+bm6.4b+bm7.7c+bm8.8c+bm9.6l
set md5valid=5006722f516b6fd1709046a542d3dd71
set  ofile=JT1943E.rom
GOTO START

:1943UA
set zip1=1943ua.zip
set ifiles=bmu01.12d+bmu02.13d+bmu03.14d+bm05.4k+bm04.5h+bm14.5f+bm23.8k+bm15.10f+bm19.10j+bm16.11f+bm20.11j+bm17.12f+bm21.12j+bm18.14f+bm22.14j+bm24.14k+bm25.14l+bm06.10a+bm10.10c+bm07.11a+bm11.11c+bm08.12a+bm12.12c+bm09.14a+bm13.14c+bm10.7l+bm11.12l+bm1.12a+bm12.12m+bm2.13a+bm3.14a+bm4.12c+bm5.7f+bm6.4b+bm7.7c+bm8.8c+bm9.6l
set md5valid=ca46e4b63b7a4da585b535d479ef6499
set  ofile=JT1943UA.rom
GOTO START

:1943J
set zip1=1943j.zip
set ifiles=bm01b.12d+bm02b.13d+bm03b.14d+bm05.4k+bm04.5h+bm14.5f+bm23.8k+bm15.10f+bm19.10j+bm16.11f+bm20.11j+bm17.12f+bm21.12j+bm18.14f+bm22.14j+bm24.14k+bm25.14l+bm06.10a+bm10.10c+bm07.11a+bm11.11c+bm08.12a+bm12.12c+bm09.14a+bm13.14c+bm10.7l+bm11.12l+bm1.12a+bm12.12m+bm2.13a+bm3.14a+bm4.12c+bm5.7f+bm6.4b+bm7.7c+bm8.8c+bm9.6l
set md5valid=ed51564a2680da2172a4a3203a7d6768
set  ofile=JT1943J.rom
GOTO START

:1943JA
set zip1=1943ja.zip
set ifiles=bm01.12d+bm02.13d+bm03.14d+bm05.4k+bm04.5h+bm14.5f+bm23.8k+bm15.10f+bm19.10j+bm16.11f+bm20.11j+bm17.12f+bm21.12j+bm18.14f+bm22.14j+bm24.14k+bm25.14l+bm06.10a+bm10.10c+bm07.11a+bm11.11c+bm08.12a+bm12.12c+bm09.14a+bm13.14c+bm10.7l+bm11.12l+bm1.12a+bm12.12m+bm2.13a+bm3.14a+bm4.12c+bm5.7f+bm6.4b+bm7.7c+bm8.8c+bm9.6l
set md5valid=42fc270d829ccb930b734d9f76ce704b
set  ofile=JT1943JA.rom
GOTO START

:1943JAH
set zip1=1943jah.zip
set ifiles=bm01_hack.12d+bm02.13d+bm03.14d+bm05.4k+bm04.5h+bm14.5f+bm23.8k+bm15.10f+bm19.10j+bm16.11f+bm20.11j+bm17.12f+bm21.12j+bm18.14f+bm22.14j+bm24.14k+bm25.14l+bm06.10a+bm10.10c+bm07.11a+bm11.11c+bm08.12a+bm12.12c+bm09.14a+bm13.14c+bm10.7l+bm11.12l+bm1.12a+bm12.12m+bm2.13a+bm3.14a+bm4.12c+bm5.7f+bm6.4b+bm7.7c+bm8.8c+bm9.6l
set md5valid=98d75a7859c6ab18ce02e17eb04886b4
set  ofile=JT1943JAH.rom
GOTO START

:1943KAI
set zip1=1943kai.zip
set ifiles=bmk01.12d+bmk02.13d+bmk03.14d+bmk05.4k+bmk04.5h+bmk14.5f+bmk23.8k+bm15.10f+bm19.10j+bmk16.11f+bmk20.11j+bmk17.12f+bmk21.12j+bmk18.14f+bmk22.14j+bmk24.14k+bmk25.14l+bmk06.10a+bmk10.10c+bmk07.11a+bmk11.11c+bmk08.12a+bmk12.12c+bmk09.14a+bmk13.14c+bmk10.7l+bmk11.12l+bmk1.12a+bmk12.12m+bmk2.13a+bmk3.14a+bm4.12c+bmk5.7f+bm6.4b+bmk7.7c+bmk8.8c+bmk9.6l
set md5valid=a22833b3bf0c0bc6c95c53147f17b48f
set  ofile=JT1943KAI.rom
GOTO START

:1943MII
set zip1=1943mii.zip
set ifiles=01.12d+02.13d+03.14d+05.4k+04.5h+14.5f+23.8k+bm15.10f+bm19.10j+bm16.11f+bm20.11j+17.12f+21.12j+18.14f+22.14j+24.14k+25.14l+06.10a+10.10c+07.11a+11.11c+08.12a+12.12c+09.14a+13.14c+10.7l+11.12l+bmk1.12a+12.12m+bmk2.13a+bmk3.14a+4.12c+5.7f+6.4b+7.7c+8.8c+9.6l
set md5valid=e56b41c808ea01274b7245c5d89fdef4
set  ofile=JT1943MII.rom
GOTO START

:1943H
set zip1=1943.zip
set ifiles=1943h\bme01addontext.12d+bme02.13d+bme03.14d+bm05.4k+bm04.5h+bm14.5f+bm23.8k+bm15.10f+bm19.10j+bm16.11f+bm20.11j+bm17.12f+bm21.12j+bm18.14f+bm22.14j+bm24.14k+bm25.14l+bm06.10a+bm10.10c+bm07.11a+bm11.11c+bm08.12a+bm12.12c+bm09.14a+bm13.14c+bm10.7l+bm11.12l+bm1.12a+bm12.12m+bm2.13a+bm3.14a+bm4.12c+bm5.7f+bm6.4b+bm7.7c+bm8.8c+bm9.6l
set md5valid=dfda2fd57d15b4db52679088c23068d5
set  ofile=JT1943H.rom
GOTO START

:1943KAIS01
set zip1=1943kai.zip
set ifiles=1943kais01\bmk01.12dhc01+bmk02.13d+bmk03.14d+bmk05.4k+bmk04.5h+bmk14.5f+bmk23.8k+bm15.10f+bm19.10j+bmk16.11f+bmk20.11j+bmk17.12f+bmk21.12j+bmk18.14f+bmk22.14j+bmk24.14k+bmk25.14l+bmk06.10a+bmk10.10c+bmk07.11a+bmk11.11c+bmk08.12a+bmk12.12c+bmk09.14a+bmk13.14c+bmk10.7l+bmk11.12l+bmk1.12a+bmk12.12m+bmk2.13a+bmk3.14a+bm4.12c+bmk5.7f+bm6.4b+bmk7.7c+bmk8.8c+bmk9.6l
set md5valid=1e15ba96c05f857dc26b34a30b8a58f9
set  ofile=JT1943KAIS01.rom
GOTO START



:START

rem =====================================
setlocal ENABLEDELAYEDEXPANSION

set pwd=%~dp0
echo.
echo.

if NOT EXIST %zip1% GOTO ERRORZIP1
if NOT EXIST "!pwd!7za.exe" GOTO ERROR7Z
echo.
echo Unziping rom file...
echo.
For /F "Tokens=*" %%I in ('"!pwd!7za" x -y -otmp %zip1%') Do Set RESUNZ=%%I

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

