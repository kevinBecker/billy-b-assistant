#!/usr/bin/env python3
"""
Test script for Billy Bass Wyoming Integration

This script tests the basic functionality without requiring
the full Wyoming-Satellite setup.
"""

import asyncio
import logging
import sys
import time

# Setup logging
logging.basicConfig(level=logging.INFO)
_LOGGER = logging.getLogger()

def test_motion_system():
    """Test Billy's motion system."""
    print("🐟 Testing Billy's motion system...")
    
    try:
        from core.movements import move_head, move_tail_async, stop_all_motors
        
        print("  ✓ Head movement test")
        move_head("on")
        time.sleep(1)
        move_head("off")
        
        print("  ✓ Tail movement test")
        move_tail_async(duration=0.5)
        time.sleep(1)
        
        print("  ✓ Motor stop test")
        stop_all_motors()
        
        print("✅ Motion system test passed!")
        return True
        
    except Exception as e:
        print(f"❌ Motion system test failed: {e}")
        return False


def test_audio_system():
    """Test audio system detection."""
    print("🎤 Testing audio system...")
    
    try:
        from core.audio import detect_devices
        detect_devices(debug=True)
        print("✅ Audio system test passed!")
        return True
        
    except Exception as e:
        print(f"❌ Audio system test failed: {e}")
        return False


def test_wyoming_imports():
    """Test Wyoming imports."""
    print("🛰️ Testing Wyoming imports...")
    
    try:
        from wyoming_satellite.satellite import WakeStreamingSatellite
        from wyoming_satellite.settings import SatelliteSettings
        from wyoming.info import Info
        print("✅ Wyoming imports test passed!")
        return True
        
    except ImportError as e:
        print(f"❌ Wyoming imports test failed: {e}")
        print("   Make sure to install Wyoming-Satellite first:")
        print("   cd wyoming-satellite && pip install -e .")
        return False


def test_configuration():
    """Test configuration loading."""
    print("⚙️ Testing configuration...")
    
    try:
        from billy_wyoming_config import create_billy_satellite_settings
        settings = create_billy_satellite_settings()
        
        # Check key settings
        assert settings.mic.enabled == True
        assert settings.snd.enabled == True
        assert settings.wake.enabled == True
        
        print("✅ Configuration test passed!")
        return True
        
    except Exception as e:
        print(f"❌ Configuration test failed: {e}")
        print("   This might be due to missing Wyoming configuration files")
        return False


def test_button_system():
    """Test button system."""
    print("🔘 Testing button system...")
    
    try:
        import core.button
        # Test if we can import the module without initializing GPIO
        print("✅ Button system test passed!")
        return True
        
    except Exception as e:
        print(f"❌ Button system test failed: {e}")
        print("   This might be due to GPIO being busy or unavailable")
        return False


def test_mqtt_system():
    """Test MQTT system."""
    print("📡 Testing MQTT system...")
    
    try:
        from core.mqtt import mqtt_available
        available = mqtt_available()
        print(f"  MQTT available: {available}")
        print("✅ MQTT system test passed!")
        return True
        
    except Exception as e:
        print(f"❌ MQTT system test failed: {e}")
        return False


def test_event_handler():
    """Test event handler."""
    print("🎭 Testing event handler...")
    
    try:
        # Test if we can import the event handler module
        from billy_wyoming_event_handler import BillyWyomingEventHandler
        print("✅ Event handler test passed!")
        return True
        
    except Exception as e:
        print(f"❌ Event handler test failed: {e}")
        print("   This might be due to missing Wyoming event handler files")
        return False


def main():
    """Run all tests."""
    print("🧪 Billy Bass Wyoming Integration Test Suite")
    print("=" * 50)
    
    tests = [
        ("Motion System", test_motion_system),
        ("Audio System", test_audio_system),
        ("Wyoming Imports", test_wyoming_imports),
        ("Configuration", test_configuration),
        ("Button System", test_button_system),
        ("MQTT System", test_mqtt_system),
        ("Event Handler", test_event_handler),
    ]
    
    passed = 0
    total = len(tests)
    
    for test_name, test_func in tests:
        print(f"\n📋 Running {test_name} test...")
        try:
            if asyncio.iscoroutinefunction(test_func):
                result = asyncio.run(test_func())
            else:
                result = test_func()
            
            if result:
                passed += 1
            else:
                print(f"⚠️  {test_name} test failed")
                
        except Exception as e:
            print(f"❌ {test_name} test crashed: {e}")
    
    print("\n" + "=" * 50)
    print(f"📊 Test Results: {passed}/{total} passed")
    
    if passed == total:
        print("🎉 All tests passed! Billy is ready for Wyoming integration.")
        return 0
    else:
        print("⚠️  Some tests failed. Please check the errors above.")
        return 1


if __name__ == "__main__":
    sys.exit(main())
