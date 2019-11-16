
Pod::Spec.new do |s|
  s.name         = "RNReax"
  s.version      = "1.2.0"
  s.summary      = "RNReax"
  s.description  = <<-DESC
  Event driven RPC between a Swift backend and a Clojurescript front end. Influenced by the Xi-editor.
                   DESC
  s.homepage     = "https://github.com/wavejumper/reax"
  s.license      = "MIT"
  # s.license    = { :type => "MIT", :file => "LICENSE" }
  s.author       = { "author" => "crowley@kibu.com.au" }
  s.platform     = :ios, "7.0"
  s.source       = { :git => "https://github.com/wavejumper/RNReax.git", :tag => "master" }
  s.source_files  = "Sources/**"
  s.requires_arc = true


  s.dependency "React"
  #s.dependency "others"

end

  
