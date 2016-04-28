# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'easy_attributes/version'

Gem::Specification.new do |spec|
  spec.name          = "easy_attributes"
  spec.version       = EasyAttributes::VERSION
  spec.authors       = ["Allen Fair"]
  spec.email         = ["allen.fair@gmail.com"]

  spec.summary       = %q{Easy Attributes for Ruby: Enum, Bytes, Money, float-as-integer views and forms}
  spec.description   = %q{Easy Attributes is a Ruby DSL to give more control to attributes. It provides a unique attribute enum setup, and conversions to bytes and float-as-integer (money, frequencies, Ratings, etc.) / fixed-decimal precision as integer (See the easy_money gem).}
  spec.homepage      = "https://github.com/afair/easy_attributes"

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.11"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"
end
