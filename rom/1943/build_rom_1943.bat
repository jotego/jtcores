@echo off

set    zip=1942.zip
set ifiles=srb-03.m3+srb-04.m4+srb-05.m5+srb-06.m6+srb-06.m6+srb-07.m7+sr-01.c11+sr-02.f2+sr-10.a3+sr-11.a4+sr-08.a1+sr-09.a2+sr-12.a5+sr-13.a6+sr-12.a5+sr-13.a6+sr-14.l1+sr-16.n1+sr-15.l2+sr-17.n2+sb-1.k6+sb-2.d1+sb-3.d2+sb-4.d6+sb-5.e8+sb-6.e9+sb-7.e10+sb-0.f1+sb-8.k3+sb-9.m11
set  ofile=a.1942.rom


rem =====================================
setlocal ENABLEDELAYEDEXPANSION

set pwd=%~dp0
echo.
echo.

if EXIST %zip% (

	!pwd!7za x -otmp %zip%
	if !ERRORLEVEL! EQU 0 ( 
		cd tmp

		copy /b/y %ifiles% !pwd!%ofile%
		if !ERRORLEVEL! EQU 0 ( 
			echo.
			echo ** done **
			echo.
			echo Copy "%ofile%" into root of SD card
		)
		cd !pwd!
		rmdir /s /q tmp
	)

) else (

	echo Error: Cannot find "%zip%" file
	echo.
	echo Put "%zip%", "7za.exe" and "%~nx0" into the same directory
)

echo.
echo.
pause


rem  'main0'  srb-03.m3", 16
rem  'main1'  srb-04.m4", 16
rem  'main2'  srb-05.m5", 16
rem  'main3'  srb-06.m6", 8
rem  'main3'  srb-06.m6", 8
rem  'main4'  srb-07.m7", 16
rem
rem  'audio'  sr-01.c11", 16
rem
rem  'char'   sr-02.f2", 8
rem
rem  'scr2'   sr-10.a3", 8
rem  'scr0'   sr-08.a1", 8
rem  'scr3'   sr-11.a4", 8
rem  'scr1'   sr-09.a2", 8
rem
rem  'scr4'   sr-12.a5", 8
rem  'scr5'   sr-13.a6", 8
rem  'scr4'   sr-12.a5", 8
rem  'scr5'   sr-13.a6", 8
rem
rem  'obj0'   sr-14.l1", 16
rem  'obj2'   sr-16.n1", 16
rem
rem  'obj1'   sr-15.l2", 16
rem  'obj3'   sr-17.n2", 16
rem
rem  'k6'     sb-1.k6",
rem  'd1'     sb-2.d1",
rem  'd2'     sb-3.d2",
rem  'd6'     sb-4.d6",
rem  'e8'     sb-5.e8",
rem  'e9'     sb-6.e9",
rem  'e10'    sb-7.e10",
rem  'f1'     sb-0.f1",
rem  'k3'     sb-8.k3",
rem  'm11'    sb-9.m11",
