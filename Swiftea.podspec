#
# Be sure to run `pod lib lint Swiftea.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'Swiftea'
  s.version          = '0.1.0'
  s.summary          = 'Swiftea is a Swift implementation of The Elm Arcitecture (TEA) design pattern'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
Swiftea is a Swift implementation of The Elm Arcitecture (TEA) design pattern. It's simple, It's use Combine, It's straightforward. Just as TEA Design pattern.
                       DESC

  s.homepage         = 'https://github.com/cooler333/Swiftea'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Dmitrii Coolerov' => 'utm4@mail.ru' }
  s.source           = { :git => 'https://github.com/cooler333/Swiftea.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '13.0'

  s.source_files = 'Sources/**/*.swift'
  
  s.swift_versions = ["5.0"]
  s.resource_bundles = {
    'Swiftea' => ['Sources/Swiftea/Resources/**/*.{txt}']
  }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'

  s.test_spec 'Tests' do |test_spec|
    test_spec.source_files = 'Tests/SwifteaTests/**/*.swift'
    # test_spec.dependency 'OCMock' # This dependency will only be linked with your tests.
  end  
end
