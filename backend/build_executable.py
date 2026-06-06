#!/usr/bin/env python3
"""
PyInstaller 打包脚本 - Ono 后端服务
将 app_server.py 打包成独立可执行文件
"""

import subprocess
import sys
import os

def install_pyinstaller():
    """安装 PyInstaller"""
    print("📦 正在安装 PyInstaller...")
    subprocess.run([sys.executable, "-m", "pip", "install", "pyinstaller"], check=True)
    print("✅ PyInstaller 安装完成")

def create_spec_file():
    """创建 PyInstaller spec 文件"""
    spec_content = '''# -*- mode: python ; coding: utf-8 -*-

block_cipher = None

a = Analysis(
    ['app_server.py'],
    pathex=[],
    binaries=[],
    datas=[
        ('brain_engine.py', '.'),  # 包含 brain_engine.py
    ],
    hiddenimports=[
        'fastapi',
        'uvicorn',
        'pydantic',
        'ollama',
        'sqlite3',
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name='ono_backend',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=True,  # 改为 False 可隐藏终端窗口
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
'''
    
    with open('ono_backend.spec', 'w') as f:
        f.write(spec_content)
    
    print("✅ Spec 文件已创建: ono_backend.spec")

def build_executable():
    """执行 PyInstaller 打包"""
    print("🔨 开始打包可执行文件...")
    subprocess.run(["pyinstaller", "ono_backend.spec", "--clean"], check=True)
    print("✅ 打包完成！")
    print(f"📂 可执行文件路径: {os.path.abspath('dist/ono_backend')}")

def test_executable():
    """测试可执行文件"""
    exe_path = os.path.abspath('dist/ono_backend')
    
    if not os.path.exists(exe_path):
        print("❌ 可执行文件不存在，打包可能失败")
        return False
    
    print("🧪 测试可执行文件...")
    print(f"   路径: {exe_path}")
    print("   请在新终端运行以下命令测试:")
    print(f"   {exe_path}")
    print("   如果看到 'Uvicorn running on http://0.0.0.0:8000' 说明成功")
    return True

def main():
    print("=" * 60)
    print("🚀 Ono 后端打包工具")
    print("=" * 60)
    print()
    
    try:
        # 步骤 1: 安装 PyInstaller
        install_pyinstaller()
        print()
        
        # 步骤 2: 创建 spec 文件
        create_spec_file()
        print()
        
        # 步骤 3: 打包
        build_executable()
        print()
        
        # 步骤 4: 测试
        test_executable()
        print()
        
        print("=" * 60)
        print("✅ 全部完成！")
        print("=" * 60)
        print()
        print("📋 后续步骤:")
        print("1. 测试可执行文件: ./dist/ono_backend")
        print("2. 如果测试通过，复制到 Flutter 项目:")
        print("   cp dist/ono_backend ../macos/Runner/")
        print("3. 在 Flutter 中调用这个可执行文件")
        print()
        
    except subprocess.CalledProcessError as e:
        print(f"❌ 错误: 命令执行失败 - {e}")
        sys.exit(1)
    except Exception as e:
        print(f"❌ 错误: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
