Pod::Spec.new do |s|
  s.name             = 'Actomaton'
  s.version          = '0.2.1'
  s.summary          = 'A short description of Actomaton.'
  s.homepage         = 'https://github.com/arietis/Actomaton'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Yasuhiro Inami' => 'inamiy@gmail.com' }
  s.source           = { :git => 'https://github.com/arietis/Actomaton.git', :tag => s.version.to_s }
  s.ios.deployment_target = '13.0'
  s.swift_version = '5.5'
  s.source_files = 'Sources/Actomaton/**/*'
  s.dependency 'CasePaths'
end
