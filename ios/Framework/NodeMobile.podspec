Pod::Spec.new do |s|
  s.name = 'NodeMobile'
  s.version = '1.0.0'
  s.summary = 'NodeMobile framework'
  s.homepage = 'https://github.com/JackLeeo/ios_tvbox'
  s.license = { :type => 'MIT' }
  s.author = { 'JackLeeo' => 'your@email.com' }
  s.platform = :ios, '13.0'
  s.vendored_frameworks = 'NodeMobile.xcframework'
  s.source = { :path => '.' }
end
