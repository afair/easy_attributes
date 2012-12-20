# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run the gemspec command
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{easy_attributes}
  s.version = "0.2.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Allen Fair"]
  s.date = %q{2012-12-12}
  s.description = %q{Easy Attributes is a Ruby DSL to give more control to attributes. It provides a unique attribute enum setup, and conversions to bytes and float-as-integer (money, frequencies, Ratings, etc.) / fixed-decimal precision as integer (See the easy_money gem).}
  s.email = %q{allen.fair@gmail.com}
  s.extra_rdoc_files = [
    "LICENSE",
     "README.rdoc"
  ]
  s.files = [
    ".document",
     ".gitignore",
     "LICENSE",
     "README.rdoc",
     "Rakefile",
     "VERSION",
     "easy_attributes.gemspec",
     "lib/easy_attributes.rb",
     "test/helper.rb",
     "test/test_easy_attributes.rb"
  ]
  s.homepage = %q{http://github.com/afair/easy_attributes}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.7}
  s.summary = %q{Easy Attributes for Ruby: Enum, Bytes, Money, float-as-integer views and forms}
  s.test_files = [
    "test/helper.rb",
     "test/test_easy_attributes.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end

