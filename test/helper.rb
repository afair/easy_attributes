require 'rubygems'
require 'test/unit'

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'easy_attributes'

EasyAttributes::Definition.find_or_create(:status, {forsale:1, contract:2, sold:3})
EasyAttributes::Definition.find_or_create(:status).add_symbol(:deleted, 9)

class Sample
  include EasyAttributes
  #attr_accessor :price, :balance
  #attr_money :price
  #attr_money :balance
  attr_values :status, active:1, retired:5, inactive:10
  attr_enum :lifestage, :baby, :toddler, :child, :teen, :adult, :elderly, :dead
  attr_shared status1: :status2
end
