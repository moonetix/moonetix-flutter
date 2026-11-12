Pod::Spec.new do |s|
  s.name             = 'moonetix_offerwall'
  s.version          = '2.0.1'
  s.summary          = 'Moonetix offerwall for Flutter apps.'
  s.description      = <<-DESC
Flutter plugin for the Moonetix offerwall. On iOS it uses the Moonetix iOS SDK (MoonetixOfferwall 2.0.1).
                       DESC
  s.homepage         = 'https://docs.moonetix.com/flutter-sdk'
  s.license          = { :type => 'Apache-2.0', :file => '../LICENSE' }
  s.author           = { 'Moonetix' => 'partners@moonetix.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'moonetix_offerwall/Sources/moonetix_offerwall/**/*.swift'
  s.resource_bundles = { 'moonetix_offerwall_privacy' => ['moonetix_offerwall/Sources/moonetix_offerwall/PrivacyInfo.xcprivacy'] }
  s.dependency 'Flutter'
  s.vendored_frameworks = 'moonetix_offerwall/Frameworks/MoonetixOfferwall.xcframework'
  s.platform         = :ios, '13.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version    = '5.0'
end
