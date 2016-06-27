Pod::Spec.new do |s|
  s.name         = "ICSMainFramework"
  s.version      = "0.0.1"
  s.summary      = "ICSMainFramework"
  s.description  = <<-DESC
                   ICSMainFramework.
                   DESC
  s.homepage     = "http://icodesign.me"
  s.license      = "MIT"
  s.author       = { "iCodesign" => "leimagnet@gmail.com" }
  s.platform     = :ios, "8.0"
  s.source       = { :path => "." }
  s.source_files  = "ICSMainFramework", "ICSMainFramework/**/*.{h,m,swift}"
  s.exclude_files = "ICSMainFramework/Exclude"
end
