Pod::Spec.new do |s|
  s.name         = "Aspects"
  s.version      = "0.0.1"
  s.summary      = "Aspects"
  s.description  = <<-DESC
                   Aspects swift.
                   DESC
  s.homepage     = "http://icodesign.me"
  s.license      = "MIT"
  s.author       = { "iCodesign" => "leimagnet@gmail.com" }
  s.platform     = :ios, "8.0"
  s.source       = { :path => "." }
  s.source_files  = "Aspects", "Aspects/**/*.{h,m,swift}"
  s.exclude_files = "Aspects/Exclude"
end
