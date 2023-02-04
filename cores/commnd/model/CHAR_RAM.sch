EESchema Schematic File Version 4
LIBS:commando-cache
EELAYER 26 0
EELAYER END
$Descr A4 11693 8268
encoding utf-8
Sheet 3 3
Title ""
Date ""
Rev ""
Comp ""
Comment1 ""
Comment2 ""
Comment3 ""
Comment4 ""
$EndDescr
$Comp
L jt74xx:74LS32 5H1
U 2 1 5D53F19F
P 3250 3500
F 0 "5H1" H 3250 3183 50  0000 C CNN
F 1 "74LS32" H 3250 3274 50  0000 C CNN
F 2 "" H 3250 3500 50  0001 C CNN
F 3 "http://www.ti.com/lit/gpn/sn74LS32" H 3250 3500 50  0001 C CNN
	2    3250 3500
	-1   0    0    1   
$EndComp
$Comp
L jt74xx:74LS32 5H1
U 3 1 5D53F281
P 4100 3900
F 0 "5H1" H 4100 3583 50  0000 C CNN
F 1 "74LS32" H 4100 3674 50  0000 C CNN
F 2 "" H 4100 3900 50  0001 C CNN
F 3 "http://www.ti.com/lit/gpn/sn74LS32" H 4100 3900 50  0001 C CNN
	3    4100 3900
	-1   0    0    1   
$EndComp
Wire Wire Line
	3550 3400 3850 3400
Wire Wire Line
	3850 3400 3850 2950
Wire Wire Line
	3850 2950 2800 2950
Text GLabel 2800 2950 0    50   Input ~ 0
phiB
Text GLabel 2800 3500 0    50   Output ~ 0
phiMAIN
Wire Wire Line
	2800 3500 2950 3500
Wire Wire Line
	3550 3600 3700 3600
Wire Wire Line
	3700 3600 3700 3900
Wire Wire Line
	3700 3900 3800 3900
Text GLabel 2800 4150 0    50   Input ~ 0
phiSC
Wire Wire Line
	2800 4150 4400 4150
Wire Wire Line
	4400 4150 4400 4000
$Comp
L arcade:rpulldown pd2
U 1 1 5D53F3F5
P 4650 3800
F 0 "pd2" H 4728 4090 50  0000 L CNN
F 1 "rpulldown" H 4728 3999 50  0000 L CNN
F 2 "" H 4450 3800 50  0001 C CNN
F 3 "" H 4450 3800 50  0001 C CNN
	1    4650 3800
	1    0    0    -1  
$EndComp
Wire Wire Line
	4650 3800 4400 3800
$EndSCHEMATC
