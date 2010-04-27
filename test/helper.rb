require 'rubygems'
require 'test/unit'

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'easy_attributes'

class Test::Unit::TestCase
end
require 'rubygems'
require 'test/unit'


class Sample
  include EasyAttributes
  attr_accessor :price, :balance
  attr_money :price
  attr_money :balance
end
