Pod::Spec.new do |s|
  s.name             = 'pinpoint_feedback'
  s.version          = '0.1.0'
  s.summary          = 'In-app client feedback for Flutter.'
  s.description      = 'Reports the host app identity so feedback maps to the right app automatically.'
  s.homepage         = 'https://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Pinpoint' => 'dev@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
