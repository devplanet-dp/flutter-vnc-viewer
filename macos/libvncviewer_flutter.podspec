#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint libvncviewer_flutter.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'libvncviewer_flutter'
  s.version          = '0.0.1'
  s.summary          = 'LibVncViewer Flutter plugins.'
  s.description      = <<-DESC
LibVncViewer Flutter plugins.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Yangzhao' => 'yangzhaojava@gmail.com' }

  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'

  s.vendored_libraries = 'frameworks/libvncclient.a'
  s.libraries = 'z'
  
  current_directory = __dir__
 puts "Current directory: #{current_directory}"
 
 s.xcconfig = { "HEADER_SEARCH_PATHS" => "#{current_directory}/include","SWIFT_OBJC_BRIDGING_HEADER" => "#{current_directory}/Classes/LibvncviewerFlutterPlugin-Bridging-Header.h"}

  s.platform = :osx, '10.11'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
