@echo off
cd /d "%~dp0"
chcp 65001
setlocal EnableDelayedExpansion


echo 欢迎使用小白的 BaiNotez 启动脚本!
echo made by 小白
echo --------------------
echo     /\_/\     欢迎大家给我点stars 👉 https://github.com/Wang-baizhu
echo    ( o.o )    づ
echo    /  ^  \_____/
echo    \  _  /    
echo --------------------
:: Set environment variables
set CONDA_ENV_NAME=BaiNotez
set PYTHON_VERSION=3.10

:: Check if Conda is installed
where conda >nul 2>nul
if !ERRORLEVEL! neq 0 (
    echo [ERROR] Conda not found. Please install Anaconda or Miniconda first
    echo Download: https://www.anaconda.com/download
    pause
    exit /b 1
)
echo [INFO] Conda detected [OK]

:: Check if conda environment exists
echo [INFO] Checking Conda environment: %CONDA_ENV_NAME%
call conda env list | find "%CONDA_ENV_NAME%" >nul
if !ERRORLEVEL! neq 0 (
    echo [INFO] Creating new Conda environment: %CONDA_ENV_NAME%
    call conda create -n %CONDA_ENV_NAME% python=%PYTHON_VERSION% -y
    if !ERRORLEVEL! neq 0 (
        echo [ERROR] Failed to create Conda environment
        pause
        exit /b 1
    )
)
echo [INFO] Conda environment ready [OK]

call conda init
echo [INFO] Conda init [OK]

:: Activate environment
echo [INFO] Activating environment...
call conda activate %CONDA_ENV_NAME%

if !ERRORLEVEL! neq 0 (
    echo [ERROR] Failed to activate Conda environment
    pause
    exit /b 1
)
echo [INFO] Environment activated [OK]

:: Check if PyTorch is installed
python -c "import torch" >nul 2>nul
if !ERRORLEVEL! neq 0 (
    echo [INFO] PyTorch not found. Installing...

    :: Use Python to detect CUDA version
    for /f "delims=" %%i in ('python detect_cuda.py') do (
        set "CUDA_VERSION=%%i"
    )
    echo [DEBUG] CUDA_VERSION = !CUDA_VERSION!

    :: Check if CUDA_VERSION is defined
    if not defined CUDA_VERSION (
        echo [WARN] CUDA_VERSION is not defined.
        echo.
        echo Press 1 to set VERSION to "cpu", or press any other key to exit.
        set /p CHOICE="Enter your choice: "
        if "!CHOICE!"=="1" (
            set "CUDA_VERSION=cpu"
            echo [INFO] CUDA_VERSION set to "cpu"
        ) else (
            echo [INFO] Exiting...
            pause
            exit /b 1
        )
    )
    echo [INFO] Using Python from:
    :: Output final CUDA version
    echo [INFO] Final CUDA_VERSION = !CUDA_VERSION!

    if defined CUDA_VERSION (
        set "SHORT_CUDA=!CUDA_VERSION!"
        echo [DEBUG] SHORT_CUDA = !SHORT_CUDA!

        :: Extract major and minor versions (e.g., 12.6 → major 12, minor 6)
        for /f "tokens=1,2 delims=." %%a in ("!SHORT_CUDA!") do (
            set "CUDA_MAJOR=%%a"
            set "CUDA_MINOR=%%b"
        )

        :: Compatibility logic
        if "!CUDA_MAJOR!"=="12" (
            if "!CUDA_MINOR!"=="6" (
                pip install torch==2.6.0 torchvision==0.21.0 torchaudio==2.6.0 --index-url https://download.pytorch.org/whl/cu126
            ) else if "!CUDA_MINOR!"=="4" (
                pip install torch==2.6.0 torchvision==0.21.0 torchaudio==2.6.0 --index-url https://download.pytorch.org/whl/cu124
            ) else if "!CUDA_MINOR!"=="1" (
                pip install torch==2.5.1 torchvision==0.20.1 torchaudio==2.5.1 --index-url https://download.pytorch.org/whl/cu121
            ) else (
                echo [WARN] CUDA 12 version too low, not supported: !SHORT_CUDA!
                pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
            )
        ) else if "!CUDA_MAJOR!"=="11" (
            if "!CUDA_MINOR!"=="8" (
                pip install torch==2.6.0 torchvision==0.21.0 torchaudio==2.6.0 --index-url https://download.pytorch.org/whl/cu118
            ) else if "!CUDA_MINOR!"=="7" (
                pip install torch==2.0.1 torchvision==0.15.2 torchaudio==2.0.2 --index-url https://download.pytorch.org/whl/cu117
            ) else if "!CUDA_MINOR!"=="6" (
                pip install torch==1.13.1+cu116 torchvision==0.14.1+cu116 torchaudio==0.13.1 --extra-index-url https://download.pytorch.org/whl/cu116
            ) else if "!CUDA_MINOR!"=="3" (
                pip install torch==1.12.1+cu113 torchvision==0.13.1+cu113 torchaudio==0.12.1 --extra-index-url https://download.pytorch.org/whl/cu113
            ) else if "!CUDA_MINOR!"=="1" (
                pip install torch==1.9.0+cu111 torchvision==0.10.0+cu111 torchaudio==0.9.0 -f https://download.pytorch.org/whl/torch_stable.html
            ) else (
                echo [WARN] CUDA 11 version too low, not supported: !SHORT_CUDA!
                pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
            )
        ) else if "!CUDA_MAJOR!"=="10" (
            if "!CUDA_MINOR!"=="2" (
                pip install torch==1.12.1+cu102 torchvision==0.13.1+cu102 torchaudio==0.12.1 --extra-index-url https://download.pytorch.org/whl/cu102
            ) else if "!CUDA_MINOR!"=="1" (
                pip install torch==1.7.1+cu101 torchvision==0.8.2+cu101 torchaudio==0.7.2 -f https://download.pytorch.org/whl/torch_stable.html
            ) else (
                echo [WARN] CUDA 10 version too low, not supported: !SHORT_CUDA!
                pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
            )
        ) else if "!CUDA_MAJOR!"=="9" (
            if "!CUDA_MINOR!"=="2" (
                pip install torch==1.6.0+cu92 torchvision==0.7.0+cu92 -f https://download.pytorch.org/whl/torch_stable.html
            ) else (
                echo [WARN] CUDA 9 version too low, not supported: !SHORT_CUDA!
                pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
            )
        ) else if "!CUDA_VERSION!"=="cpu" (
            echo [INFO] Installing CPU version of PyTorch
            pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
        ) else (
            echo [WARN] Unrecognized CUDA major version: !CUDA_MAJOR!
            pip install torch torchvision torchaudio
        ) 
        ) else (
            echo [INFO] CUDA_VERSION not defined. Installing CPU version of PyTorch.
            pip install torch torchvision torchaudio
        ) 
    ) else (
        echo [INFO] PyTorch is already installed
    )

:: Install additional dependencies
echo [INFO] Checking other dependencies...
for %%P in (aiohttp aiohttp_cors langchain-openai faster_whisper python-multipart uvicorn) do (
    python -c "import %%P" >nul 2>nul
    if !ERRORLEVEL! neq 0 (
        echo [INFO] Installing %%P...
        pip install %%P
    )
)
echo [INFO] Dependency installation completed [OK]

:: Run  script
@echo off
title 应用程序启动器

@echo off
title 应用程序启动器
@echo off
setlocal enabledelayedexpansion
title 应用程序启动器
@echo off
setlocal enabledelayedexpansion
title 应用程序启动器
chcp 65001

:MENU
cls
echo =================================
echo         应用程序启动选项
echo =================================
echo.
echo 请选择启动模式:
echo.
echo  1. 无窗口模式 (后台运行)
echo  2. 正常模式 (显示控制台窗口)
echo.
echo  0. 退出
echo.
echo =================================
echo.

choice /C 120 /N /M "请输入选项 [1-2, 0退出]: "

if errorlevel 3 goto EXIT
if errorlevel 2 goto NORMAL_MODE
if errorlevel 1 goto WINDOWLESS_MODE

:WINDOWLESS_MODE
echo [INFO] 正在以无窗口模式启动应用程序...
start /B pythonw gateway.py
start /B pythonw worker.py
echo [INFO] 应用程序已在后台启动，正在检查健康状态...
goto CHECK_HEALTH

:NORMAL_MODE
echo [INFO] 正在以正常模式启动应用程序...
start python gateway.py
start python worker.py
echo [INFO] 应用程序已启动，正在检查健康状态...
goto CHECK_HEALTH

:CHECK_HEALTH
set "HEALTH_CHECK_URL=http://127.0.0.1:8001/api/health"
set "MAX_ATTEMPTS=10"
set "DELAY=2"
set "ATTEMPT=0"

:HEALTH_LOOP
set /a ATTEMPT+=1
echo [INFO] 健康检查尝试 %ATTEMPT%/%MAX_ATTEMPTS%...

:: 使用PowerShell执行curl并提取Content字段
powershell -Command "$response = Invoke-WebRequest -Uri '%HEALTH_CHECK_URL%'; $response.Content | Out-File -FilePath 'health_check.tmp' -Encoding ASCII"
if !ERRORLEVEL! neq 0 (
    echo [WARN] 无法连接到 %HEALTH_CHECK_URL%，尝试 %ATTEMPT%/%MAX_ATTEMPTS%
) else (
    :: 检查返回的JSON中是否包含"status": "ok"（注意有空格）
    findstr /C:"\"status\": \"ok\"" health_check.tmp > nul
    if !ERRORLEVEL! equ 0 (
        echo [INFO] 应用程序已成功启动并运行正常！
        del health_check.tmp 2>nul
        goto SUCCESS
    )
)

:: 清理临时文件
del health_check.tmp 2>nul

:: 检查是否已达到最大尝试次数
if !ATTEMPT! geq !MAX_ATTEMPTS! (
    echo [ERROR] 健康检查失败，应用程序可能未正常启动。
    echo         请检查网关服务是否在端口8001上运行，或8001、8002端口是否被占用。
    goto END
)

:: 等待一段时间后重试
timeout /t !DELAY! /nobreak > nul
goto HEALTH_LOOP

:SUCCESS
echo.
echo =================================
echo      应用程序启动成功！
echo =================================
echo.
echo 应用程序已成功启动并通过健康检查，请通过ipconfig命令查找本机IP并填入你的本地配置（后面带上8001端口号），如http://xxx.xxx.xx.xxx:8001
echo =================================
echo.

:END
echo [INFO] 脚本执行完成，如需关闭，无窗口模式请杀死进程，正常模式直接关闭即可！
cmd /k
exit /b 0

:EXIT
echo 已取消启动。
exit /b 0