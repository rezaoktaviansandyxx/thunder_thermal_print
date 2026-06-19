Pod::Spec.new do |s|
  s.name             = 'thunder_thermal_print'
  s.version          = '1.0.0'
  s.summary          = 'Universal Flutter Thermal Printer Plugin'
  s.description      = 'macOS implementation for thermal printing'
  s.homepage         = 'https://thunderlab.id'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'ThunderLab' => 'dev@thunderlab.id' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'
  s.platform         = :osx, '10.15'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version    = '5.0'
  s.frameworks       = 'CoreBluetooth', 'Network'
end
