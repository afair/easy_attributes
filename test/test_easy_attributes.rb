require 'helper'
EasyAttributes::Config.orm = :attr

class TestEasyAttributes < Test::Unit::TestCase
  include EasyAttributes
  attr_sequence :tas, :n1, :n2
  attr_values :tav, :k1=>1, :k2=>2, :k3=>3
  attr_values :status, {}, :like=>'TestEasyAttributes#tav'
  attr_bytes  :bw
  attr_money  :amount
  
  def test_attr_sequence
    self.tas_sym = :n1
    assert_equal self.tas, 1
    assert_equal self.tas_sym, :n1
  end
  
  def test_attr_values
    self.tav_sym = :k1
    assert_equal tav, 1
    self.tav_sym = :k2
    assert_equal tav, 2
    assert_equal tav_sym, :k2
    assert_equal tav_is?(:k2), true
    assert_equal tav_is?(:k1, :k3), false
    #self.tav = :k1
    #assert_equal tav, 1
  end
  
  def test_like
    self.status_sym = :k1
    assert_equal self.status, 1
  end

  # Removed for now, not shipping my data file!
  def test_load
    #EasyAttributes::Config.load "values"
    #assert_equal EasyAttributes::Config.attributes['status'][:ok], 8
  end
  
  def test_attr_bytes
    self.bw = 1024
    assert_equal bw, 1024
    assert_equal bw_bytes(:KiB, :precision=>0), "1 KiB"
    self.bw = [1, :kb]
  end
  
  def test_format_bytes
    EasyAttributes::Config.kb_size = :both
    assert_equal EasyAttributes.format_bytes( 900 ), "900 B"
    assert_equal EasyAttributes.format_bytes( 1000 ), "1 KB"
    assert_equal EasyAttributes.format_bytes( 12345 ), "12 KiB"
    assert_equal EasyAttributes.format_bytes( 123456789 ), "117 MiB"
    assert_equal EasyAttributes.format_bytes( 9999999999 ), "9.31 GiB"
    assert_equal EasyAttributes.format_bytes( 123456789,  :KiB ), "120563.271 KiB"
    assert_equal EasyAttributes.format_bytes( 123456789,  :KiB, 1 ), "120563.3 KiB"
    assert_equal EasyAttributes.format_bytes( 123456789,  :KiB, 0 ), "120563 KiB"
  end
  
  def test_parse_bytes
    EasyAttributes::Config.kb_size=:both
    assert_equal EasyAttributes.parse_bytes( "1.5 KiB" ), 1536
    assert_equal EasyAttributes.parse_bytes( "1 gb" ), EasyAttributes::GB
    assert_equal EasyAttributes.parse_bytes( "1kb", :kb_size=>1000 ), 1000
    assert_equal EasyAttributes.parse_bytes( "1kb", :kb_size=>1024 ), 1024
  end
  
  def test_include
    sample = Sample.new
    flunk "no price_money method" unless sample.respond_to?(:price_money)
    flunk "no price_money= method" unless sample.respond_to?(:price_money=)
  end

  def test_method_money
    s = Sample.new
    [ 10000, 123456, 0, -1 -9876 ].each do |p|
      s.price = p
      m = s.price_money
      s.price_money = m
      flunk "Assignment error: p=#{p} m=#{m} price=#{s.price}" unless s.price = p
    end
  end

  def test_method_money=
    s = Sample.new
    { "0.00"=>0, "12.34"=>1234, "-1.2345"=>-123, "12"=>1200, "4.56CR"=>-456 }.each do |m,p|
      s.price_money = m
      flunk "Assignment error: p=#{p} m=#{m} price=#{s.price}" unless s.price = p
    end
  end

  def test_integer_to_money
    assert EasyAttributes.integer_to_money(123) == '1.23'
    assert EasyAttributes.integer_to_money(-12333) == '-123.33'
    assert EasyAttributes.integer_to_money(0) == '0.00'
    assert EasyAttributes.integer_to_money(nil, :nil=>'?') == '?'
    assert EasyAttributes.integer_to_money(-1, :negative=>'%.2f CR') == '0.01 CR'
    assert EasyAttributes.integer_to_money(0, :zero=>'free') == 'free'
    assert EasyAttributes.integer_to_money(100, :unit=>'$') == '$1.00'
    assert EasyAttributes.integer_to_money(100, :separator=>',') == '1,00'
    assert EasyAttributes.integer_to_money(12345678900, :separator=>',', :delimiter=>'.') == '123.456.789,00'
    assert EasyAttributes.integer_to_money(333, :precision=>3) == '0.333'
    assert EasyAttributes.integer_to_money(111, :precision=>1) == '11.1'
    assert EasyAttributes.integer_to_money(111, :precision=>0) == '111'
  end

  def test_money_to_integer
    assert EasyAttributes.money_to_integer('1.23'        ) == 123
    assert EasyAttributes.money_to_integer('0.00'        ) == 0
    assert EasyAttributes.money_to_integer('-1.23'       ) == -123
    assert EasyAttributes.money_to_integer('1.23 CR'     ) == -123
    assert EasyAttributes.money_to_integer('$-2.34 CR'   ) == 234
    assert EasyAttributes.money_to_integer('   1.234'    ) == 123
    assert EasyAttributes.money_to_integer('$1'          ) == 100
    assert EasyAttributes.money_to_integer('1'           ) == 100
    assert EasyAttributes.money_to_integer(''            ) == nil
    assert EasyAttributes.money_to_integer('1,00', :separator=>',',:delimiter=>'.') == 100
    assert EasyAttributes.money_to_integer('$123.456.789,00 CR', :separator=>',',:delimiter=>'.') == -12345678900
    assert EasyAttributes.money_to_integer('4.44', :precision=>4 ) == 44400
    assert EasyAttributes.money_to_integer('4.44', :precision=>0 ) == 4
  end

  def test_float_to_integer
    assert EasyAttributes.float_to_integer(1.00   ) == 100
    assert EasyAttributes.float_to_integer(1.001  ) == 100
    assert EasyAttributes.float_to_integer(-1.23  ) == -123
    assert EasyAttributes.float_to_integer(9.0    ) == 900
    assert EasyAttributes.float_to_integer(nil    ) == nil
    assert EasyAttributes.float_to_integer(0.00   ) == 0
  end

  def test_integer_to_float
    assert EasyAttributes.integer_to_float(1      ) == 0.01
    assert EasyAttributes.integer_to_float(0      ) == 0.0
    assert EasyAttributes.integer_to_float(-100   ) == -1.00
    assert EasyAttributes.integer_to_float(nil    ) == nil
    assert EasyAttributes.integer_to_float(9999888, :precision=>3 ) == 9999.888
  end
  
  def test_format_money
    assert EasyAttributes.format_money(12345) == '123.45'
    assert EasyAttributes.format_money(12345, "%07.2m") == '0000123.45'
    assert EasyAttributes.format_money(12345, "%07.3m") == '0000123.450'
    assert EasyAttributes.format_money(12345, "%m") == '123'
    assert EasyAttributes.format_money(12345, "free") == 'free'
    assert EasyAttributes.format_money(-12345) == '-123.45'
    assert EasyAttributes.format_money(-12345, "%07.1m") == '-000123.4'
    assert EasyAttributes.format_money(-1) == '-0.01'
  end
  
end
