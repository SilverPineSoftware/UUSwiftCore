Pod::Spec.new do |s|
  	s.name             = "UUSwiftCore"
  	s.version          = "1.0.3"

  	s.description      = <<-DESC
                       UUSwiftCore is a framework to extend the base Foundation and UIKit classes. UUSwiftCore eliminates many of the tedious tasks associated with Swift development such as date formating and string manipulation.
                       DESC
  	s.summary          = "UUSwift extends Foundation and UIKit to add additional functionality to make development more efficient."

  	s.homepage         = "https://github.com/SilverPineSoftware/UUSwiftCore"
  	s.author           = "Silverpine Software"
  	s.license          = { :type => 'MIT' }
  	s.source           = { :git => "https://github.com/SilverPineSoftware/UUSwiftCore.git", :tag => s.version.to_s }

	s.ios.deployment_target = "10.0"
	s.osx.deployment_target = "10.10"
	s.swift_version = "5.0"

	s.subspec 'Core' do |ss|
    	ss.source_files = 'UUSwift/*.{swift}'
    	ss.ios.frameworks = 'UIKit', 'Foundation'
		ss.osx.frameworks = 'CoreFoundation'
		ss.tvos.frameworks = 'UIKit', 'Foundation'
  	end

end

