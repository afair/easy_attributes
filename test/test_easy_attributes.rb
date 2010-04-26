require 'helper'

class TestEasyAttributes < Test::Unit::TestCase
  include EasyAttributes
  EasyAttributes::Config.load "#{ENV['BIGLIST_DIR']}/etc/salsa.values"
  attr_sequence :tas, :n1, :n2
  attr_values :tav, :k1=>1, :k2=>2, :k3=>3
  attr_values :status, {}, :like=>'status'
  
  def test_attr_sequence
    self.tas = :n1
    assert_equal self.tas, 1
    puts self.tas_sym
    assert_equal self.tas_sym, :n1
  end
  
  def test_attr_values
    self.tav = :k1
    assert_equal tav, 1
    self.tav = :k2
    assert_equal tav, 2
  end
  
  def test_like
    self.status = :ok
    assert_equal self.status, 8
  end

  def test_load
    assert_equal EasyAttributes::Config.attribs['status'][:ok], 8
  end
end
