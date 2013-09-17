# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'Peppermill/version'

Gem::Specification.new do |spec|
  spec.name          = 'Peppermill'
  spec.version       = Peppermill::VERSION
  spec.authors       = ['Kate von Roeder']
  spec.email         = %w(katevonroeder@gmail.com)
  spec.description   = %q{An IRC bot for APepperShaker.com}
  spec.summary       = %q{An IRC bot for APepperShaker.com}
  spec.homepage      = 'http://apeppershaker.com'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = %w(lib)

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake'
end
