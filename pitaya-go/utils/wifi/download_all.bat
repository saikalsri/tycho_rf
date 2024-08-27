@ECHO off
setlocal EnableDelayedExpansion

:: %1 type of bus
:: %2 (aardvark_serial_number or 0)
:: %3 com port eg 1 for COM1
:: %4 TLS_CLIENT_KEY_RSA   file eg ..\..\..\..\..\certs\pitaya_rsa.key or 'none'
:: %5 TLS_CLIENT_CRT_RSA   file eg ..\..\..\..\..\certs\pitaya_rsa.cer or 'none'
:: %6 TLS_CLIENT_CRT_ECDSA file eg ..\..\..\..\..\certs\pitaya_ecdsa.cer or 'none'

SET FIRMWARE_3A0_PATH=../../../firmware/m2m_aio_3a0.bin

SET OTA_3A0=../../../ota_firmware/m2m_ota_3a0.bin

SET CA_DIR=../../../../../certs/CA

rem Either specify all certs, even if that is to explicitly set them to none or specify none for defaults
if /I "a%4a" == "aa" (
	SET TLS_CLIENT_KEY_RSA=../../../../../certs/pitaya_rsa.key
	SET TLS_CLIENT_CRT_RSA=../../../../../certs/pitaya_rsa.cer
	echo Defaulting to RSA key cert pair @ %TLS_CLIENT_CRT_RSA% and %TLS_CLIENT_KEY_RSA%

	SET TLS_CLIENT_CRT_ECDSA=../../../../../certs/pitaya_ecdsa.cer
	echo Defaulting to ECDSA certificate @ %TLS_CLIENT_CRT_ECDSA%
) else (
	if /I "a%4a" == "anonea" (
	
		SET TLS_CLIENT_KEY_RSA=

		if /I "a%5a" == "anonea" (
			SET TLS_CLIENT_CRT_RSA=
		) else (
			SET TLS_CLIENT_CRT_RSA=%5
			echo RSA needs a key and cert [cert with no key]
			goto usage
		)
	
	) else (
	
		SET TLS_CLIENT_KEY_RSA=%4

		if /I "a%5a" == "anonea" (
			SET TLS_CLIENT_CRT_RSA=
			echo RSA needs a key and cert [key with no cert]
			goto usage
		) else (
			SET TLS_CLIENT_CRT_RSA=%5
		)
	)
	
	if /I "a%6a" == "aa" (
		rem RSA specifically switched off, but no ECDSA
		echo No ECDSA certificate specified [use 'none' if this is intentional]
		goto usage
	) else (
		if /I "a%6a" == "anonea" (
			SET TLS_CLIENT_CRT_ECDSA=
		) else (
			SET TLS_CLIENT_CRT_ECDSA=%6
		)
	)
)

echo Mode %1
if /I "%1" == "UART"  Goto contine_UART
if /I "%1" == "I2C"   Goto contine_I2C
if /I "%1" == "OTA"   Goto contine_OTA

goto usage

:contine_I2C
Set  FMode=debug_i2c
set Mode=I2C
goto START

:contine_OTA
Set  FMode=debug_ota
set Mode=OTA
goto START

:contine_UART
Set  FMode=debug_uart
set Mode=UART
goto START

:START

rem must jump past else the file check gives a syntax error that delayed expansion cannot fix?
IF "a%TLS_CLIENT_CRT_RSA%a"=="aa" goto rsacertchkd
pushd Tools\root_certificate_downloader\%FMode%
if not exist %TLS_CLIENT_CRT_RSA% (
	echo Cannot find certificate. %TLS_CLIENT_CRT_RSA%
	pwd
	popd
	goto usage
)
popd
:rsacertchkd

IF "a%TLS_CLIENT_KEY_RSA%a"=="aa" goto rsakeychkd
pushd Tools\root_certificate_downloader\%FMode%
if not exist %TLS_CLIENT_KEY_RSA% (
	echo Cannot find certificate. %TLS_CLIENT_KEY_RSA%
	pwd
	popd
	goto usage
)
popd
:rsakeychkd

IF "a%TLS_CLIENT_CRT_ECDSA%a"=="aa" goto ecdsacertchkd
pushd Tools\root_certificate_downloader\%FMode%
if not exist %TLS_CLIENT_CRT_ECDSA% (
	echo Cannot find certificate. %TLS_CLIENT_CRT_ECDSA%
	pwd
	popd
	goto usage
)
popd
:ecdsacertchkd

if /I "a%2a" == "aa" (
	set AARDVARK=0
) else (
	set AARDVARK=%2
)

if /I "a%3a" == "aa" (
  echo No comport specified
  goto usage
) else (
  if /I "a%3a" == "a0a" (
  	echo Comport should NOT be 0
  	goto usage
  ) else (
	set COMPORT=-port %3
  )
)

set VARIANT=3A0
goto parmsok

:USAGE
echo Usage %0 (I2C-UART-OTA) (aardvark_serial_number or 0) (comport) (rsa key or none) (rsa cert or none if key is none) (ecdsa cert or none)
pause
exit /b 2

:parmsok

IF %FMode%==debug_ota (
	echo Creating Image...
	pushd Tools\image_builder\debug\

	image_builder ^
		-1003A0 ^
		-no_wait ^
		-ota_img  %OTA_3A0% ^
		-fw_path ../../../firmware/wifi_v111/ASIC_3A0/wifi_firmware.bin ^
		-op_path %FIRMWARE_3A0_PATH% ^
		-bf_bin  ../../../boot_firmware/release3A0/boot_firmware.bin ^
		-pf_bin  ../../../programmer_firmware/release3A0/programmer_firmware.bin ^
		-df_bin  ../../../downloader_firmware/release3A0/downloader_firmware.bin ^
		-ate_img ../../../ate_firmware/burst_tx_firmware_winc1500.bin 
	IF ERRORLEVEL 1 goto FAILED

	popd
	goto SUCCESS
)

pushd Tools\image_downloader\%FMode%
echo Downloading Image... (pod %AARDVARK%) (comport %COMPORT%)

echo image_downloader.exe ^
	-no_wait ^
	-aardvark %AARDVARK% %COMPORT% ^
	-vflash_path ../../../vflash_image_downloader.bin ^
	-bf_bin  ../../../boot_firmware/release%VARIANT%/boot_firmware.bin ^
	-pf_bin  ../../../programmer_firmware/release%VARIANT%/programmer_firmware.bin ^
	-df_bin  ../../../downloader_firmware/release%VARIANT%/downloader_firmware.bin ^
	-fw3a0_path %FIRMWARE_3A0_PATH%

if exist .\..\..\..\vflash_image_downloader.bin (
	echo Deleting vflash_image_downloader.bin
	del .\..\..\..\vflash_image_downloader.bin
)

goto doboth
rem goto dofwpll
rem goto dopllfw

:doboth
image_downloader.exe ^
	-no_wait ^
	-aardvark %AARDVARK% %COMPORT% ^
	-vflash_path ../../../vflash_image_downloader.bin ^
	-bf_bin  ../../../boot_firmware/release%VARIANT%/boot_firmware.bin ^
	-pf_bin  ../../../programmer_firmware/release%VARIANT%/programmer_firmware.bin ^
	-df_bin  ../../../downloader_firmware/release%VARIANT%/downloader_firmware.bin ^
	-fw3a0_path %FIRMWARE_3A0_PATH%
goto goby
:dofwpll
image_downloader.exe ^
	-no_wait ^
	-skip_pll_update ^
	-aardvark %AARDVARK% %COMPORT% ^
	-vflash_path ../../../vflash_image_downloader.bin ^
	-bf_bin  ../../../boot_firmware/release%VARIANT%/boot_firmware.bin ^
	-pf_bin  ../../../programmer_firmware/release%VARIANT%/programmer_firmware.bin ^
	-df_bin  ../../../downloader_firmware/release%VARIANT%/downloader_firmware.bin ^
	-fw3a0_path %FIRMWARE_3A0_PATH%
image_downloader.exe ^
	-no_wait ^
	-skip_fw_update ^
	-aardvark %AARDVARK% %COMPORT% ^
	-vflash_path ../../../vflash_image_downloader.bin ^
	-bf_bin  ../../../boot_firmware/release%VARIANT%/boot_firmware.bin ^
	-pf_bin  ../../../programmer_firmware/release%VARIANT%/programmer_firmware.bin ^
	-df_bin  ../../../downloader_firmware/release%VARIANT%/downloader_firmware.bin ^
	-fw3a0_path %FIRMWARE_3A0_PATH%
goto goby
:dopllfw
image_downloader.exe ^
	-no_wait ^
	-skip_fw_update ^
	-aardvark %AARDVARK% %COMPORT% ^
	-vflash_path ../../../vflash_image_downloader.bin ^
	-bf_bin  ../../../boot_firmware/release%VARIANT%/boot_firmware.bin ^
	-pf_bin  ../../../programmer_firmware/release%VARIANT%/programmer_firmware.bin ^
	-df_bin  ../../../downloader_firmware/release%VARIANT%/downloader_firmware.bin ^
	-fw3a0_path %FIRMWARE_3A0_PATH%
image_downloader.exe ^
	-no_wait ^
	-skip_pll_update ^
	-aardvark %AARDVARK% %COMPORT% ^
	-vflash_path ../../../vflash_image_downloader.bin ^
	-bf_bin  ../../../boot_firmware/release%VARIANT%/boot_firmware.bin ^
	-pf_bin  ../../../programmer_firmware/release%VARIANT%/programmer_firmware.bin ^
	-df_bin  ../../../downloader_firmware/release%VARIANT%/downloader_firmware.bin ^
	-fw3a0_path %FIRMWARE_3A0_PATH%
:goby
IF ERRORLEVEL 1 goto FAILED

popd
copy vflash_image_downloader.bin vflash_gain_builder.bin
pushd Tools\gain_builder\%FMode%

echo Downloading Gain Values...

Set GAIN_FILE=-table 1 ../gain_sheets/atwinc1500_gain_setting_default.csv  -index 1

echo gain_builder.exe ^
	%GAIN_FILE% ^
	-aardvark %AARDVARK% %COMPORT% ^
	-vflash_path ../../../vflash_gain_builder.bin ^
	-bf_bin  ../../../boot_firmware/release%VARIANT%/boot_firmware.bin ^
	-pf_bin  ../../../programmer_firmware/release%VARIANT%/programmer_firmware.bin ^
	-df_bin  ../../../downloader_firmware/release%VARIANT%/downloader_firmware.bin ^
	-no_wait
gain_builder.exe ^
	%GAIN_FILE% ^
	-aardvark %AARDVARK% %COMPORT% ^
	-vflash_path ../../../vflash_gain_builder.bin ^
	-bf_bin  ../../../boot_firmware/release%VARIANT%/boot_firmware.bin ^
	-pf_bin  ../../../programmer_firmware/release%VARIANT%/programmer_firmware.bin ^
	-df_bin  ../../../downloader_firmware/release%VARIANT%/downloader_firmware.bin ^
	-no_wait
IF ERRORLEVEL 1 goto FAILED

popd
copy vflash_gain_builder.bin vflash_tls_cert_flash_tool.bin

rem first cert written needs erase option
set ERASEOPT=-erase

IF "%TLS_CLIENT_CRT_RSA%"=="" (
    echo No TLS Client RSA Certificate specified.
) ELSE (
    pushd Tools\tls_cert_flash_tool\%FMode%
    echo Downloading TLS Client RSA Certificate Materials...
	tls_cert_flash_tool.exe ^
		WRITE ^
		-aardvark %AARDVARK% %COMPORT% ^
		-vflash_path ../../../vflash_tls_cert_flash_tool.bin ^
		-pf_bin  ../../../programmer_firmware/release%VARIANT%/programmer_firmware.bin ^
		-key  %TLS_CLIENT_KEY_RSA% ^
		-cert %TLS_CLIENT_CRT_RSA% ^
		-cadir %CA_DIR% ^
		-nowait %ERASEOPT%
	IF ERRORLEVEL 1 goto FAILED
	set ERASEOPT=
    popd
)

IF "%TLS_CLIENT_CRT_ECDSA%"=="" (
    echo No TLS Client ECDSA Certificate specified.
) ELSE (
    pushd Tools\tls_cert_flash_tool\%FMode%
    echo Downloading TLS Client ECDSA Certificate Materials...
	tls_cert_flash_tool.exe ^
		WRITE ^
		-aardvark %AARDVARK% %COMPORT% ^
		-vflash_path ../../../vflash_tls_cert_flash_tool.bin ^
		-pf_bin  ../../../programmer_firmware/release%VARIANT%/programmer_firmware.bin ^
		-nokey ^
		-cert %TLS_CLIENT_CRT_ECDSA% ^
		-cadir %CA_DIR% ^
		-nowait %ERASEOPT%
	IF ERRORLEVEL 1 goto FAILED
	set ERASEOPT=
    popd
)

copy vflash_tls_cert_flash_tool.bin vflash_root_certificate_downloader.bin

pushd Tools\root_certificate_downloader\%FMode%

echo Downloading root certificates...
set /a c = 0
set seq=
for %%X in (..\binary\*.cer) do (
	set /a c+=1
	@set seq=!seq! %%X
)
echo root_certificate_downloader.exe ^
	-n %c% %seq% ^
	-no_wait ^
	-aardvark %AARDVARK% %COMPORT% ^
	-vflash_path ../../../vflash_root_certificate_downloader.bin ^
	-bf_bin  ../../../boot_firmware/release%VARIANT%/boot_firmware.bin ^
	-pf_bin  ../../../programmer_firmware/release%VARIANT%/programmer_firmware.bin ^
	-df_bin  ../../../downloader_firmware/release%VARIANT%/downloader_firmware.bin ^
	-e
root_certificate_downloader.exe ^
	-n %c% %seq% ^
	-no_wait ^
	-aardvark %AARDVARK% %COMPORT% ^
	-vflash_path ../../../vflash_root_certificate_downloader.bin ^
	-bf_bin  ../../../boot_firmware/release%VARIANT%/boot_firmware.bin ^
	-pf_bin  ../../../programmer_firmware/release%VARIANT%/programmer_firmware.bin ^
	-df_bin  ../../../downloader_firmware/release%VARIANT%/downloader_firmware.bin ^
	-e
IF ERRORLEVEL 1 goto FAILED
popd

pushd Tools\image_cloner\%FMode%
echo  Readback flash... (pod %AARDVARK%) (comport %COMPORT%)

echo image_cloner.exe ^
	-no_wait ^
	-span 524288 ^
	-aardvark %AARDVARK% %COMPORT% ^
	-out_path ../../../readback_flash.bin
image_cloner.exe ^
	-no_wait ^
	-span 524288 ^
	-aardvark %AARDVARK% %COMPORT% ^
	-out_path ../../../readback_flash.bin
IF ERRORLEVEL 1 goto FAILED

popd

echo.
echo Verifing...
fc /B vflash_root_certificate_downloader.bin readback_flash.bin > flashdiff.txt
IF ERRORLEVEL 1 goto UNVERIFY
echo *************** Flash programming verified OK *****************

rem This section is a possible alternative, prepare the image on disk, then burn and verify in one operation.
rem Echo test simple program and verify
rem echo %TIME%
rem pushd Tools\image_cloner\%FMode%
rem image_cloner.exe -no_wait -aardvark %AARDVARK% %COMPORT% -in_path ../../../vflash_root_certificate_downloader.bin -out_path ../../../readback_verify.bin
rem popd
rem echo %TIME%
	
goto SUCCESS

:UNVERIFY
echo *************** Failed to verify *****************
popd
echo     #######################################################################
echo     ##                                                                   ##
echo     ##                    ########    ###     ####  ##                   ##
echo     ##                    ##         ## ##     ##   ##                   ##
echo     ##                    ##        ##   ##    ##   ##                   ##
echo     ##                    ######   ##     ##   ##   ##                   ##
echo     ##                    ##       #########   ##   ##                   ##
echo     ##                    ##       ##     ##   ##   ##                   ##
echo     ##                    ##       ##     ##  ####  ########             ##
echo     ##                                                                   ##
echo     ####################################################################### 
pause
exit /b 2

:FAILED
popd
echo *************** Failed to download *****************
popd
echo     #######################################################################
echo     ##                                                                   ##
echo     ##                    ########    ###     ####  ##                   ##
echo     ##                    ##         ## ##     ##   ##                   ##
echo     ##                    ##        ##   ##    ##   ##                   ##
echo     ##                    ######   ##     ##   ##   ##                   ##
echo     ##                    ##       #########   ##   ##                   ##
echo     ##                    ##       ##     ##   ##   ##                   ##
echo     ##                    ##       ##     ##  ####  ########             ##
echo     ##                                                                   ##
echo     ####################################################################### 
pause
exit /b 1

:SUCCESS

echo Chip Restarting ...
TIMEOUT /T 5 
echo Done

echo *************** Download worked *****************
echo OK
echo     #######################################################################
echo     ##                                                                   ##
echo     ##                 ########     ###     ######   ######              ##
echo     ##                 ##     ##   ## ##   ##    ## ##    ##             ##
echo     ##                 ##     ##  ##   ##  ##       ##                   ##
echo     ##                 ########  ##     ##  ######   ######              ##
echo     ##                 ##        #########       ##       ##             ##
echo     ##                 ##        ##     ## ##    ## ##    ##             ##
echo     ##                 ##        ##     ##  ######   ######              ##
echo     ##                                                                   ##
echo     #######################################################################

echo Downloading ends successfully
pause