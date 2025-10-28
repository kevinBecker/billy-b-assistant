#!/usr/bin/env python3
"""
Debug script to check Wyoming package installation
"""

import sys

def test_wyoming_import():
    """Test Wyoming package import and show detailed error info."""
    print("🔍 Testing Wyoming package import...")
    
    try:
        import wyoming
        print(f"✅ Wyoming imported successfully")
        print(f"   Version: {getattr(wyoming, '__version__', 'Unknown')}")
        print(f"   Location: {wyoming.__file__}")
        return True
    except ImportError as e:
        print(f"❌ Wyoming import failed: {e}")
        print(f"   Error type: {type(e).__name__}")
        return False
    except Exception as e:
        print(f"❌ Unexpected error importing Wyoming: {e}")
        print(f"   Error type: {type(e).__name__}")
        return False

def test_wyoming_satellite_import():
    """Test Wyoming-Satellite package import."""
    print("\n🔍 Testing Wyoming-Satellite package import...")
    
    try:
        import wyoming_satellite
        print(f"✅ Wyoming-Satellite imported successfully")
        print(f"   Version: {getattr(wyoming_satellite, '__version__', 'Unknown')}")
        print(f"   Location: {wyoming_satellite.__file__}")
        return True
    except ImportError as e:
        print(f"❌ Wyoming-Satellite import failed: {e}")
        print(f"   Error type: {type(e).__name__}")
        return False
    except Exception as e:
        print(f"❌ Unexpected error importing Wyoming-Satellite: {e}")
        print(f"   Error type: {type(e).__name__}")
        return False

def check_installed_packages():
    """Check what Wyoming packages are installed."""
    print("\n📦 Checking installed packages...")
    
    try:
        import pkg_resources
        
        wyoming_packages = []
        for package in pkg_resources.working_set:
            if 'wyoming' in package.project_name.lower():
                wyoming_packages.append(f"  {package.project_name}=={package.version}")
        
        if wyoming_packages:
            print("✅ Found Wyoming packages:")
            for package in wyoming_packages:
                print(package)
        else:
            print("❌ No Wyoming packages found")
            
    except Exception as e:
        print(f"⚠️  Could not check installed packages: {e}")

def check_python_path():
    """Check Python path and environment."""
    print(f"\n🐍 Python environment info:")
    print(f"   Python version: {sys.version}")
    print(f"   Python executable: {sys.executable}")
    print(f"   Python path: {sys.path[:3]}...")  # Show first 3 paths

def main():
    """Run all tests."""
    print("🧪 Wyoming Package Debug Script")
    print("=" * 40)
    
    check_python_path()
    check_installed_packages()
    
    wyoming_ok = test_wyoming_import()
    satellite_ok = test_wyoming_satellite_import()
    
    print("\n" + "=" * 40)
    print("📊 Results:")
    print(f"   Wyoming: {'✅ OK' if wyoming_ok else '❌ FAILED'}")
    print(f"   Wyoming-Satellite: {'✅ OK' if satellite_ok else '❌ FAILED'}")
    
    if wyoming_ok and satellite_ok:
        print("\n🎉 All packages working correctly!")
        return 0
    else:
        print("\n⚠️  Some packages have issues. Check the errors above.")
        return 1

if __name__ == "__main__":
    sys.exit(main())
