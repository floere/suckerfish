Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  
  s.name = 'suckerfish'
  s.version = '0.0.1'
  
  s.homepage = 'http://florianhanke.com/suckerfish'
  
  s.author = 'Florian Hanke'
  s.email = 'florian.hanke+suckerfish@gmail.com'
  
  s.description = "Suckerfish: Allows you to change your app's configuration running in Unicorn on the fly."
  s.summary = "Suckerfish: Change your app's configuration running in Unicorn on the fly."
  
  s.files = Dir["lib/**/*.*"]
end