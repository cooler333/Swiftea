#
# Be sure to run `pod lib lint Swiftea.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'Swiftea'
  s.version          = '0.9.2'
  s.summary          = 'Swiftea is a Swift implementation of The Elm Arcitecture (TEA) design pattern'

  s.description      = <<-DESC
Swiftea is a Swift implementation of The Elm Arcitecture (TEA) design pattern. It's simple, It's use Combine, It's straightforward. Just as TEA Design pattern.
                       DESC

  s.homepage         = 'https://github.com/cooler333/Swiftea'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Dmitrii Coolerov' => 'utm4@mail.ru' }
  s.source           = { :git => 'https://github.com/cooler333/Swiftea.git', :tag => s.version.to_s }

  s.ios.deployment_target = '13.0'

  s.source_files = 'Sources/**/*.swift'
  
  s.swift_versions = ["5.5"]

  s.test_spec 'Tests' do |test_spec|
    test_spec.source_files = 'Tests/SwifteaTests/**/*.swift'
  end  
end
