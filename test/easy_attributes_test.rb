require 'test_helper'

EasyAttributes::Config.orm = :attr
EasyAttributes::Config.constantize = true
EasyAttributes::Definition.shared(:status, {forsale:1, contract:2, sold:3})
EasyAttributes::Definition.shared(:status).add_symbol(:deleted, 9)

class EasyAttributesTest < Minitest::Test
  include EasyAttributes
  attr_enum   :tas, :n1, :n2, nil, :n4, 8, :n8
  attr_values :tav, :k1=>1, :k2=>2, :k3=>3
  attr_shared :status, status1: :status
  attr_bytes  :bw
  attr_money  :amount
  attr_allowed :type, %w(mammal insect amphibian)

  def test_definitions
    EasyAttributes::Definition.find_or_create(:role, {admin:'a', moderator:'m', user:'u'})
  end

  def test_attr_enum
    self.tas_sym = :n1
    assert_equal self.tas, 1
    assert_equal self.tas_sym, :n1
    assert_equal EasyAttributesTest.easy_attribute_definition(:tas).value_of(:n4), 4
    assert_equal EasyAttributesTest.easy_attribute_definition(:tas).value_of(:n8), 8
  end

  def test_attr_values
    self.tav_sym = :k1
    assert_equal tav, 1
    self.tav_sym = :k2
    assert_equal tav, 2
    assert_equal tav_sym, :k2
    assert_equal tav_in(:k2), true
    assert_equal tav_in(:k1, :k3), false
  end

  def test_attr_allowed
    self.type_sym = :mammal
    assert_equal type, "mammal"
    assert_equal type_sym, :mammal
  end

  def test_attr_shared
    #puts EasyAttributes::Definition.definitions
    self.status_sym = :forsale
    assert_equal self.status, 1
    self.status_sym = :deleted
    assert_equal status, 9
    self.status1_sym = :forsale
    assert_equal self.status1, 1
  end

  def test_attr_bytes
    self.bw = 1024
    assert_equal bw, 1024
    assert_equal bw_bytes(:KiB, :precision=>0), "1 KiB"
    self.bw = [1, :kb]
  end

  def test_format_bytes
    EasyAttributes::Config.kb_size = :both
    assert_equal format_bytes_case( 900 ), "900 B"
    assert_equal format_bytes_case( 1000 ), "1 KB"
    assert_equal format_bytes_case( 12345 ), "12 KiB"
    assert_equal format_bytes_case( 123456789 ), "118 MiB" # 117.7
    assert_equal format_bytes_case( 9999999999, precision:2 ), "9.31 GiB"
    assert_equal format_bytes_case( 123456789,  :KiB, precision:3 ), "120563.271 KiB"
    assert_equal format_bytes_case( 123456789,  :KiB, precision:1 ), "120563.3 KiB"
    assert_equal format_bytes_case( 123456789,  :KiB, precision:0 ), "120563 KiB"
  end

  def test_parse_bytes
    EasyAttributes::Config.kb_size=:both
    assert_equal parse_bytes_case( "1.5 KiB" ), 1536
    assert_equal parse_bytes_case( "1 gb" ), 1_000_000_000
    assert_equal parse_bytes_case( "1kb", :kb_size=>1000 ), 1000
    assert_equal parse_bytes_case( "1kb", :kb_size=>1024 ), 1024
  end

  def test_include
    sample = Sample.new
    flunk "no price_money method" unless sample.respond_to?(:price_money)
    flunk "no price_money= method" unless sample.respond_to?(:price_money=)
  end

  def test_method_money
    s = Sample.new
    [ 10000, 123456, 0, -1, -9876 ].each do |p|
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
    assert EasyAttributes::FixedPoint.integer_to_fixed_point(123) == '1.23'
    assert EasyAttributes::FixedPoint.integer_to_fixed_point(-12333) == '-123.33'
    assert EasyAttributes::FixedPoint.integer_to_fixed_point(0) == '0.00'
    assert EasyAttributes::FixedPoint.integer_to_fixed_point(nil, :nil=>'?') == '?'
    assert EasyAttributes::FixedPoint.integer_to_fixed_point(-1, :negative=>'%.2f CR') == '0.01 CR'
    assert EasyAttributes::FixedPoint.integer_to_fixed_point(0, :zero=>'free') == 'free'
    assert EasyAttributes::FixedPoint.integer_to_fixed_point(100, :unit=>'$') == '$1.00'
    assert EasyAttributes::FixedPoint.integer_to_fixed_point(100, :separator=>',') == '1,00'
    assert EasyAttributes::FixedPoint.integer_to_fixed_point(12345678900, :separator=>',', :delimiter=>'.') == '123.456.789,00'
    assert EasyAttributes::FixedPoint.integer_to_fixed_point(333, :precision=>3) == '0.333'
    assert EasyAttributes::FixedPoint.integer_to_fixed_point(111, :precision=>1) == '11.1'
    assert EasyAttributes::FixedPoint.integer_to_fixed_point(111, :precision=>0) == '111'
  end

  def test_money_to_integer
    assert EasyAttributes::FixedPoint.fixed_point_to_integer('1.23'        ) == 123
    assert EasyAttributes::FixedPoint.fixed_point_to_integer('0.00'        ) == 0
    assert EasyAttributes::FixedPoint.fixed_point_to_integer('-1.23'       ) == -123
    assert EasyAttributes::FixedPoint.fixed_point_to_integer('1.23 CR'     ) == -123
    assert EasyAttributes::FixedPoint.fixed_point_to_integer('$-2.34 CR'   ) == 234
    assert EasyAttributes::FixedPoint.fixed_point_to_integer('   1.234'    ) == 123
    assert EasyAttributes::FixedPoint.fixed_point_to_integer('$1'          ) == 100
    assert EasyAttributes::FixedPoint.fixed_point_to_integer('1'           ) == 100
    assert EasyAttributes::FixedPoint.fixed_point_to_integer(''            ) == nil
    assert EasyAttributes::FixedPoint.fixed_point_to_integer('1,00', :separator=>',',:delimiter=>'.') == 100
    assert EasyAttributes::FixedPoint.fixed_point_to_integer('$123.456.789,00 CR', :separator=>',',:delimiter=>'.') == -12345678900
    assert EasyAttributes::FixedPoint.fixed_point_to_integer('4.44', :precision=>4 ) == 44400
    assert EasyAttributes::FixedPoint.fixed_point_to_integer('4.44', :precision=>0 ) == 4
  end

  def test_float_to_integer
    assert EasyAttributes::FixedPoint.float_to_integer(1.00   ) == 100
    assert EasyAttributes::FixedPoint.float_to_integer(1.001  ) == 100
    assert EasyAttributes::FixedPoint.float_to_integer(-1.23  ) == -123
    assert EasyAttributes::FixedPoint.float_to_integer(9.0    ) == 900
    assert EasyAttributes::FixedPoint.float_to_integer(nil    ) == nil
    assert EasyAttributes::FixedPoint.float_to_integer(0.00   ) == 0
  end

  def test_integer_to_float
    assert EasyAttributes::FixedPoint.integer_to_float(1      ) == 0.01
    assert EasyAttributes::FixedPoint.integer_to_float(0      ) == 0.0
    assert EasyAttributes::FixedPoint.integer_to_float(-100   ) == -1.00
    assert EasyAttributes::FixedPoint.integer_to_float(nil    ) == nil
    assert EasyAttributes::FixedPoint.integer_to_float(9999888, :precision=>3 ) == 9999.888
  end

  def test_format_fixed_point
    assert EasyAttributes::FixedPoint.format_fixed_point(12345) == '123.45'
    assert EasyAttributes::FixedPoint.format_fixed_point(12345, "%07.2m") == '0000123.45'
    assert EasyAttributes::FixedPoint.format_fixed_point(12345, "%07.3m") == '0000123.450'
    assert EasyAttributes::FixedPoint.format_fixed_point(12345, "%m") == '123'
    assert EasyAttributes::FixedPoint.format_fixed_point(12345, "free") == 'free'
    assert EasyAttributes::FixedPoint.format_fixed_point(-12345) == '-123.45'
    assert EasyAttributes::FixedPoint.format_fixed_point(-12345, "%07.1m") == '-000123.4'
    assert EasyAttributes::FixedPoint.format_fixed_point(-1) == '-0.01'
  end

  def test_constantize
    assert EasyAttributesTest::STATUS_FORSALE == 1
  end

end
