Pod::Spec.new do |s|
  s.name             = 'thunder_thermal_print'
  s.version          = '1.0.0'
  s.summary          = 'Universal Flutter Thermal Printer Plugin'
  s.description      = 'Supports Bluetooth, BLE, USB, LAN, WiFi, and ESC/POS thermal printing'
  s.homepage         = 'https://thunderlab.id'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'ThunderLab' => 'dev@thunderlab.id' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version    = '5.0'
  s.frameworks       = 'CoreBluetooth', 'ExternalAccessory', 'Network'
end
