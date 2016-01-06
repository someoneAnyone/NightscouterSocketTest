# Uncomment this line to define a global platform for your project
# platform :ios, '8.0'
# Uncomment this line if you're using Swift
use_frameworks!

target 'NightscouterSocketTest' do
    pod 'Socket.IO-Client-Swift', '~> 4.1.6' # Or latest version
    pod 'SwiftyJSON', :git => 'https://github.com/SwiftyJSON/SwiftyJSON.git'
    pod 'DateTools'
end

plugin 'cocoapods-keys', {
    :project => "NightscouterSocketTest",
    :keys => [
    "NightscoutTestSite",
    "NightscoutSecretSHA1Key",
    ]
}