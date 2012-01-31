###############################################################################
# EasyAttributes Module - Provides attribute handling enahancements.
#
# Features include:
#
#  * Attribute Enum support, giving symbolic names for numeric or other values
#    * Provides optional ActiveModel ORM enhancements for validations, etc.
#  * Byte datatype helpers
#  * Fixed-decimal datatype (e.g. Dollars) helpers
#
# To Use:
#
#   * Require the easy_attributes gem if you need.
#   * Mix in the EasyAttributes module into your class.
#   * Load any external enum definitions at application start-up
#   * Define attribute enhancers  in your class
#
#   Gemfile (add entry, then `bundle install`):
#       gem 'easy_attributes'
#   Or manually
#       require 'easy_attributes'
#   Then
#       class MyClass
#         include EasyAttributes
#         attr_enum :my_attribute, :zero, :one, :two
#       end
#
###############################################################################
module EasyAttributes

  # Called by Ruby after including to add our ClassMethods to the parent class
  def self.included(base) #:nodoc:
    base.extend(ClassMethods)
  end

  #############################################################################
  # EasyAttributes::Definition - Class of a attribute value definition
  #############################################################################
  class Definition
    include Enumerable
    attr_accessor :attribute, :values, :symbols, :options, :attr_options

    # Public: Returns an existing or new definition for the atribute name
    # Call this method to define a global or shared setting
    #
    # attribute - The name of the attribute
    # definition - The optional definition list passed to initialize
    #
    # Examples
    #
    #   Definition.find_or_create(:status).add_symbol(:retired, 3)
    #   Definition.find_or_create(:status, active:1, inactive:2)
    #
    # Returns an existing or new instance of Definition
    #
    def self.find_or_create(attribute, *definition)
      @attributes ||= {}
      @attributes[attribute.to_sym] ||= Definition.new(attribute, *definition)
    end

    # Public: Creates a new Definition for the attribute and definition list
    # Call this method to create a non-shared definition, else call find_or_create
    #
    # Examples
    #
    #   Definition.find_or_create(:status, active:1, inactive:2)
    #
    # Returns the new instance
    def initialize(attribute, *definition)
      self.attribute = attribute.to_sym
      self.values = {}
      self.symbols = {}
      self.options = {}
      self.attr_options = {}
      self.define(*definition)
    end

    # Public: Create an attribute definition
    #
    # symbols - Hash of {symbol:value,...} for the attribute, or
    #         - Array of enum definitions for the attribute
    # options - Hash of {name:value,...} to track for the attribute. Optional.
    #           attr_options: {attribute: {....}, ...}
    #
    # Examples
    #
    #   definition.define(active:1, inactive:2)
    #   definition.define(:active, :inactive)
    #
    def define(*args)
      return define_enum(*args) unless args.first.is_a?(Hash)

      symbols = Hash[* args.first.collect {|k,v| [k.to_sym, v]}.flatten]
      self.symbols.merge!(symbols)
      self.values  = Hash[* self.symbols.collect {|k,v| [v, k]}.flatten]
      self.options.merge!(options)
      #puts "DEFINED #{@attribute} #{self.symbols.inspect}"
    end

    # Public: Defines an Symbol/Value for the attribute
    #
    # attrib  - name of the attribute or database column
    # symbol  - internal symbolic name for the value
    #         - If nil, it will use the next value from the set of current values
    # value   - Value to store in class or database
    # options - Hash of {name:value,...} to track for the symbol. Optional.
    #
    # Examples
    #
    #   definition.add_symbol(:active, 1)
    #   EasyAttributes::Config.define_value :status, :active, 1, name:"Active"
    #
    def add_symbol(symbol, value=nil, attr_options={})
      symbol = symbol.to_sym
      if value.nil?
        if a.size > 0
          value = self.values.keys.max.next
        else
          value = 0
        end
      end

      value = self.values.keys.max || 0  if value.nil?
      self.symbols[symbol] = value
      self.values[value] = symbol
      self.attr_options[symbol] = attr_options
    end

    # Public: Defines an attribute as an enumerated set of symbol/values
    #
    # args    - list of symbols, reset values, with an optional options Hash
    #           a non-symbolic arg resets the counter to that value
    #           Non-integer values can be given if the #next() method is provided
    #           nil can be passed to skip the positional value
    #
    # Examples
    #
    #   definition.define_enum(:active, :inactive)
    #   definition.define_enum(:active, :inactive, start:1, step:10)
    #   definition.define_enum(:active, 11, :retired, nil, :inactive)
    #
    def define_enum(*args)
      opt = {step:1}.merge(args.last.is_a?(Hash) ? args.pop : {})
      opt[:start] ||= (self.values.keys.max||0) + opt[:step]
      hash = {}
      i = opt[:start]
      args.each do |arg|
        if arg.is_a?(Symbol) || arg.nil?
          hash[arg] = i unless arg.nil?
          opt[:step].times {i = i.next}
        else
          i = arg
        end
      end
      define(hash)
    end

    # Public: Returns the defined value for the given symbol, or returns
    # the supplied default, nil, or a value yeilded by a block
    #
    # symbol - symbolic name of value, eg. :active
    #
    # Examples
    #
    #   definition.value_of(:active)  # => 1
    #
    # Returns the defined value of symbol for the attribute
    def value_of(sym, default=nil)
      self.symbols.fetch(sym.to_sym) { block_given? ? yield(sym) : default }
    end

    # Public: Returns the defined symbol for the given value, or returns
    # the supplied default, nil, or a value yeilded by a block
    #
    # value     - raw value of attribute, eg. 1
    #
    # Examples
    #
    #   definition.symbol_of(1)  # => :active
    #
    # Returns the defined symbol (eg.:active) for the given value on the attribute
    def self.symbol_of(value, default=nil)
      self.values.fetch(value) { block_given? ? yield(value) : default }
    end

    # Public: Returns true if the current value of the attribute is (or is in the list of
    # values) referenced by their symbolic names
    #
    # value   - The value to match 
    # symbols - array of symbolic value names, eg. :active, :inactive
    #
    # Examples
    #
    #   definition.value_is?(self.status, :active)         # => false (maybe)
    #   definition.value_is?(self.:status, :active, :inactive)  # => true (maybe)
    #   self.value_is?(:status, :between, :active, :inactive)  # => true (maybe)
    #
    # Returns true if the value matches
    def value_is?(value, *args)
      args.each do |arg|
        return true if value == value_of(arg)
      end
    end

    # Public: Implements the comparison operator (cmp, <=>) for a value against a symbolic name
    #
    # Examples
    #
    #   definition.cmp(1,:active)  # => -1. 0, or 1 according to the <=> op defined on the value class
    #
    # Returns -1 if value < symbol, 0 if value == symbol, or 1 of value < symbol
    def cmp(value, symbol)
      other = value_of(symbol)
      value <=> other
    end

    # Public: Compares the value to be between the representation of of the two symbolic names
    # Returns true if value withing the designated range, false otherwise
    def between(value, op, symbol1, symbol2=nil)
      v1 = value_of(symbol1)
      v2 = value_of(symbol2)
      value >= v1  && value <= v2
    end

    # Public: Returns the next value in the definition from the given value
    def next(value, default=nil)
      self.values.keys.sort.each {|i| return i if i > value }
      default
    end
    alias :succ :next

    # Public: Returns the next value in the definition from the given value
    def previous(value, default=nil)
      self.values.keys.sort.reverse.each {|i| return i if i < value }
      default
    end

    # Public: Builds a list of [name, value] pairs usefule for HTML select options
    # The name is the capitalized symbol name.
    #
    # attribute - symbolic name of attribute
    #
    # Returns an array of [name, value] pairs.
    def select_option_values(attrib)
      self.symbols.collect {|s,v| [s.to_s.capitalize, v]}
    end

    # Private: Builds a list of [name, symbol] pairs usefule for HTML select options
    # The name is the capitalized symbol name.
    #
    # attribute - symbolic name of attribute
    #
    # Returns an array of [name, symbol] pairs.
    def select_option_symbols(attrib)
      self.symbols.collect {|s,v| [s.to_s.capitalize, s]}
    end

    # Defines each() for Enumerable
    def each
      @definition.symbols.each {|s,v| yield(s,v)}
    end

    # Defines <=>() for Enumberable comparisons
    def <=>(other)
      @definition.cmp(@value,other)
    end

    # For the experimental Value class. Takes a value or symbol
    def value(v)
      Value.new(self, v)
    end
  end

  #############################################################################
  # EasyAttributes::Value - Experiment! Value Class for attribute values
  #############################################################################
  class Value
    include Comparable

    # Usage: Value.new(definition, symbol_or_value)
    def initialize(definition, value)
      @definition = definition
      @attribute = @definition.attribute
      if value.is_a?(Symbol)
        @value = @definition.value_of(value)
      else
        @value = value
      end
    end

    # Returns the symbolic name of this value
    def to_sym
      @definition.symbol_of(@value)
    end

    # Compare with a defined symbol or another value. Required for Comparable
    def <=>(other)
      if other.is_a?(Symbol)
        @value <=> @definition.value_of(other)
      else
        @value <=> other
      end
    end

    # Returns the next value in the definition as a Value object
    def next
      Value.new(@definition.next(@value))
    end
    alias :succ :next

    # Forward all other methods to the actual @value class
    def method_missing(method, *args)
      @value.send(method, *args)
    end
  end

  #############################################################################
  # EasyAttributes::Config - Namespace to define and hold configuration data.
  #############################################################################
  class Config
    @orm        = :attr    # :attr, :active_model
    @kb_size    = :iec     # :iec, :old, :new

    # Public: Set the default size for a kilobyte/kibibyte
    #  Refer to: http://en.wikipedia.org/wiki/Binary_prefix
    #
    # setting - How to represent kilobyte
    #       :new, :iec            uses KiB=1024, no KB
    #       :old, :jedec, or 1024 uses KB=1024
    #       1000, :decimal        uses only KB (1000) (other values mix KB and KiB units)
    #       Note: "IEC" is the International Electrotechnical Commission
    #             "JEDEC" is the Joint Electron Devices Engineering Council
    #
    # Examples
    #
    #   EasyAttributes::Config.kb_size = :iec
    #
    # Returns new setting
    #
    def self.kb_size=(setting)
      @kb_size = setting
    end

    # Public: Returns the current kb_size setting for use in computing Bytes
    #
    # Returns the current kb_size setting
    #
    def self.kb_size
      @kb_size
    end

    # Public: Sets the ORM (Object Relational Mapper) to a supported policy
    #
    # new_orm - value
    #   :attr = attr_accessor style operations
    #   :acitve_model = Rails ActiveModel operations
    #
    # Returns the new ORM setting
    #
    def self.orm=(new_orm)
      @orm = new_orm
    end

    # Public: Returns the current ORM setting
    #
    # Returns the current ORM setting
    #
    def self.orm
      @orm
    end

  end

  #############################################################################
  # EasyAttributes::ClassMethods - Module defining methods added to classes when included
  #
  # Examples
  #   class MyClass
  #     include EasyAttributes
  #     attr_values  :attr, name:value, ...
  #     attr_enum    :attr, :name, ....
  #     attr_defined :attr, :attr=>:defined_attr
  #     attr_bytes   :attr, ..., :base=>2
  #     attr_money   :attr, :precision=>2
  #     attr_fixed_point :attr, :precision=>2
  #############################################################################
  module ClassMethods

    # Public: Defines an attribute with a Hash of symbolic synonyms for the values.
    #
    # attribute - symbolic name of the attribute
    # values    - a hash of {symbol:value, ....} mappings
    #             a optional key of :options=>{name:value} defines any options for the attribute
    # Examples
    #
    #   attr_values :status, active:1, inactive:2
    #
    # Creates these instance methods (for a "status" attribute):
    #
    #   status_sym()                # Returns the symbolic name instead of value
    #   status_sym=(:inactive)      # Used for setting the attrivute by symbolic name instead
    #   status_is?(symbol, ...)     # Returns true if the attribute symbol is in the list of symbols
    #   status_cmp(symbol)          # Returns the comparison of the value <=> symbol
    #
    # And these class methods:
    #
    #   status_attribute()
    #     Returns the EasyAttributes::Definition for the attribute, on which you can call cool things like
    #     value_of(), symbol_of(), select_options(), etc.
    #
    # Returns nothing
    def attr_values(attribute, *args)
      defn = Definition.find_or_create(attribute, *args)
      easy_attribute_accessors(attribute, defn)
    end

    # Public: Defines an attribute as an Enumeration of symbol name.
    #
    # By default, the first symbol is mapped to 0 (zero), and increments by 1. The :start and
    # :step values in the options hash can change those settings. Also, "#next()" is called on
    # the start value, so any non-numeric object that supports that call can be used (such as
    # a string). A nil in a position will skip that value, and any other non-symbol will reset
    # the value of the next symbol to that one.
    #
    # This is an alternate syntax for the attr_values() method
    #
    # attribute - symbolic name of the attribute
    # args      - a list of symbol names, nil skip tokens, and value changes
    #             * A symbol name will map to the current value
    #             * A nil skips the current value in the list
    #             * Any other value replaces the current value for the subsequent symbol
    # options   - a optional key of :options=>{name:value} defines any options for the attribute
    #
    # Examples
    #
    #   attr_enum :status, :active, :inactive             # => {active:0, inactive:1}
    #   attr_enum :month,  :jan, :feb, ..., :dec, start:1 # => {jan:1, feb:2, ..., dec:12}
    #   attr_enum :status, :active, :inactive, nil, :suspended, 99, :deleted, start:10, step:10
    #     # => same as: {active:10, inactive:20, suspended:40, deleted:99}
    #
    # Creates the same methods as attr_values().
    #
    # Returns nothing
    def attr_enum(attribute, *args)
      defn = Definition.find_or_create(attribute, *args)
      easy_attribute_accessors(attribute, defn)
    end

    # Public: Imports global definitions into the class by attribute name or Hash mapping.
    #
    # attributes - List of attributes to import from Config definitions
    # mappings   - Hash of atttribute names to a matching alternate name in the Config definitions
    #
    # Exanples
    #
    #   attr_name :status, :role, widget_type: :general_type
    #
    # Calls attr_values with each definition
    def attr_names(*attributes)
      mapping = attributes.last.is_a?(Hash) ? attributes.pop : {}
      attributes.each { |attribute| attr_values(attribute) }
      mapping.each { |attribute,alternate_name| easy_attribute_accessors(attribute, Definition.find_or_create(alternate_name)) }
    end

    # Private: Creates attribute accessors for the attribute /definition for attr_values
    #
    # Creates
    #   self.<attribute>_attribute()
    #   <attribute>_sym()
    #   <attribute>_sym=()
    #   <attribute>_is?()
    #   <attribute>_cmp()
    #
    def easy_attribute_accessors(attribute, defn)
      attribute = attribute.to_sym
      @easy_attribute_definitions ||= {}
      @easy_attribute_definitions[attribute] = defn
      name = "#{self.name}##{attribute}"
      opt = defn.options
      code = ''

      if EasyAttributes::Config.orm == :active_model || opt[:orm] == :active_model
        validates_inclusion_of attribute, :in=>defn.symbols.values
        # Add named_scope (scope) for each value
        if opt[:named_scope]
          defn.symbols.each { |k,v| code += "named_scope :#{k}, :conditions=>{:#{attribute}=>#{v.inspect}}\n" }
        end
        if opt[:scope]
          defn.symbols.each { |k,v| code += "scope :#{k}, where({:#{attribute}=>#{v.inspect}})\n" }
        end
      else
        attr_accessor attribute
      end

      code += %Q(
        def self.#{attribute}_definition
          @easy_attribute_definitions.fetch(:#{attribute}) { raise "Attribute #{attribute} not found" }
        end
        def #{attribute}_sym
          #{self.name}.#{attribute}_definition.symbol_of(#{attribute})
        end
        def #{attribute}_sym=(v)
          self.#{attribute} = #{self.name}.#{attribute}_definition.value_of(v)
        end
        def #{attribute}_is?(*args)
          #{self.name}.#{attribute}_definition.value_is?(#{attribute}, *args)
        end
        def #{attribute}_cmp(other)
          #{self.name}.#{attribute}_definition.cmp(#{attribute}, other)
        end

        # Experimental for the EasyAttributes::Value class
        def #{attribute}_value
          return #{attribute} if #{attribute}.is_a?(EasyAttributes::Value)
          #{self.name}.#{attribute}_definition.value(#{attribute})
        end
        def #{attribute}_value=(v)
          self.#{attribute} = #{self.name}.#{attribute}_definition.value(v)
        end
      )

      puts code
      class_eval code
    end
  end
end









#!    ###########################################################################
#!    # EasyAttributes Byte Helpers
#!    ###########################################################################
#!
#!    # attr_bytes allows manipultion and display as kb, mb, gb, tb, pb
#!    # Adds method: attribute_bytes=() and attribute_bytes(:unit, :option=>value )
#!    def attr_bytes(attribute, *args)
#!      name = "#{self.name}##{attribute}"
#!      opt = EasyAttributes.pop_options(args)
#!      #getter, setter = EasyAttributes.getter_setter(attribute)
#!      attr_accessor attribute if EasyAttributes::Config.orm == :attr
#!      code = %Q(
#!        def #{attribute}_bytes(*args)
#!          args.size == 0 ? v : EasyAttributes::format_bytes(self.#{attribute}, *args)
#!        end
#!        def #{attribute}_bytes=(v)
#!          self.#{attribute} = EasyAttributes.parse_bytes(v)
#!        end
#!      )
#!      #puts code
#!      class_eval code
#!    end
#!
#!    # Creates an money instance method for the given method, named "#{attribute}_money" which returns
#!    # a formatted money string, and a #{attribute}_money= method used to set an edited money string.
#!    # The original method stores the value as integer (cents, or other precision/currency setting). Options:
#!    # * :money_method - Use this as the alternative name to the money-access methods
#!    # * :units - Use this as an alternative suffix name to the money methods ('dollars' gives 'xx_dollars')
#!    # * :precision - The number of digits implied after the decimal, default is 2
#!    # * :separator - The character to use after the integer part, default is '.'
#!    # * :delimiter - The character to use between every 3 digits of the integer part, default none
#!    # * :positive - The sprintf format to use for positive numbers, default is based on precision
#!    # * :negative - The sprintf format to use for negative numbers, default is same as :positive
#!    # * :zero - The sprintf format to use for zero, default is same as :positive
#!    # * :nil - The sprintf format to use for nil values, default none
#!    # * :unit - Prepend this to the front of the money value, say '$', default none
#!    # * :blank - Return this value when the money string is empty or has no digits on assignment
#!    # * :negative_regex - A Regular Expression used to determine if a number is negative (and without a - sign)
#!    #
#!    def attr_money(attribute, *args)
#!      opt = args.last.is_a?(Hash) ? args.pop : {}
#!      money_method = opt.delete(:money_method) || "#{attribute}_#{opt.delete(:units)||'money'}"
#!
#!      class_eval %Q(
#!      def #{money_method}(*args)
#!        opt = args.last.is_a?(Hash) ? args.pop : {}
#!        EasyAttributes.integer_to_money( #{attribute}, #{opt.inspect}.merge(opt))
#!      end
#!
#!      def #{money_method}=(v, *args)
#!        opt = args.last.is_a?(Hash) ? args.pop : {}
#!        self.#{attribute} = EasyAttributes.money_to_integer( v, #{opt.inspect}.merge(opt))
#!      end
#!      )
#!    end
#!
#!    # Returns a [getter_code, setter_code] depending on the orm configuration
#!    def self.getter_setter(attribute)
#!      if EasyAttributes::Config.orm == :active_model
#!        ["self.attributes[:#{attribute}]", "self.write_attribute(:#{attribute}, v)"]
#!      else
#!        ["@#{attribute}", "@#{attribute} = v"]
#!      end
#!    end
#!
#!    def self.pop_options(args, defaults={})
#!      args.last.is_a?(Hash) ? defaults.merge(args.pop) : defaults
#!    end
#!
#!    def self.add_definition(attribute, hash, opt={})
#!      EasyAttributes::Config.define attribute, hash
#!    end
#!
#!    ##############################################################################
#!    # attr_byte helpers
#!    ##############################################################################
#!
#!    # Official Definitions for kilobyte and kibibyte quantity prefixes
#!    KB =1000; MB =KB **2; GB= KB **3; TB =KB **4; PB =KB **5; EB =KB **6; ZB =KB **7; YB =KB **8
#!    KiB=1024; MiB=KiB**2; GiB=KiB**3; TiB=KiB**4; PiB=KiB**5; EiB=KiB**6; ZiB=KiB**7; YiB=KiB**8
#!    DECIMAL_PREFIXES = {:B=>1, :KB=>KB, :MB=>MB, :GB=>GB, :TB=>TB, :PB=>PB, :EB=>EB, :ZB=>ZB, :TB=>YB}
#!    BINARY_PREFIXES = {:B=>1, :KiB=>KiB, :MiB=>MiB, :GiB=>GiB, :TiB=>TiB, :PiB=>PiB, :EiB=>EiB, :ZiB=>ZiB, :TiB=>YiB}
#!
#!    # Returns a hash of prefix names to decimal quantities for the given setting
#!    def self.byte_prefixes(kb_size=0)
#!      case kb_size
#!      when 1000, :decimal, :si then DECIMAL_PREFIXES
#!      when :old, :jedec, 1024 then {:KB=>KiB, :MB=>MiB, :GB=>GiB, :TB=>TiB, :PB=>PiB, :EB=>EiB, :ZB=>ZiB, :TB=>YiB}
#!      when :new, :iec then BINARY_PREFIXES
#!      else DECIMAL_PREFIXES.merge(BINARY_PREFIXES) # Both? What's the least surprise?
#!      end
#!    end
#!
#!    # Takes a number of bytes and an optional :unit argument and :precision option, returns a formatted string of units
#!    def self.format_bytes(v, *args)
#!      opt = EasyAttributes.pop_options(args, :precision=>3)
#!      prefixes = EasyAttributes.byte_prefixes(opt[:kb_size]||EasyAttributes::Config.kb_size||0)
#!      if args.size > 0 && args.first.is_a?(Symbol)
#!        (unit, precision) = args
#!        v = "%.#{precision||opt[:precision]}f" % (1.0 * v / (prefixes[unit]||1))
#!        return "#{v} #{unit}"
#!      else
#!        precision = args.shift || opt[:precision]
#!        prefixes.sort{|a,b| a[1]<=>b[1]}.reverse.each do |pv|
#!          next if pv[1] > v
#!          v = "%f.10f" % (1.0 * v / pv[1])
#!          v = v[0,precision+1] if v =~ /^(\d)+\.(\d+)/ && v.size > (precision+1)
#!          v.gsub!(/\.0*$/, '')
#!          return "#{v} #{pv[0]}"
#!        end
#!      end
#!      v.to_s
#!    end
#!
#!    # Takes a string of "number units" or Array of [number, :units] and returns the number of bytes represented.
#!    def self.parse_bytes(v, *args)
#!      opt = EasyAttributes.pop_options(args, :precision=>3)
#!      # Handle v= [100, :KB]
#!      if v.is_a?(Array)
#!        bytes = v.shift
#!        v = "#{bytes} #{v.shift}"
#!      else
#!        bytes = v.to_f
#!      end
#!
#!      if v.downcase =~ /^\s*(?:[\d\.]+)\s*([kmgtpezy]i?b)/i
#!        units = ($1.size==2 ? $1.upcase : $1[0,1].upcase+$1[1,1]+$1[2,1].upcase).to_sym
#!        prefixes = EasyAttributes.byte_prefixes(opt[:kb_size]||EasyAttributes::Config.kb_size||0)
#!        bytes *= prefixes[units] if prefixes.has_key?(units)
#!        #puts "v=#{v} b=#{bytes} u=#{units} #{units.class} bp=#{prefixes[units]} kb=#{opt[:kb_size]} P=#{prefixes.inspect}"
#!      end
#!      (bytes*100).to_i/100
#!    end
#!
#!    ###########################################################################
#!    # EasyAttributes Fixed-Precision as Integer Helpers
#!    ###########################################################################
#!
#!    # Returns the money string of the given integer value. Uses relevant options from #easy_money
#!    def self.integer_to_money(value, *args)
#!      opt = args.last.is_a?(Hash) ? args.pop : {}
#!      opt[:positive] ||= "%.#{opt[:precision]||2}f"
#!      pattern =
#!      if value.nil?
#!        value = 0
#!        opt[:nil] || opt[:positive]
#!      else
#!        case value <=> 0
#!        when 1 then opt[:positive]
#!        when 0 then opt[:zero] || opt[:positive]
#!        else
#!          value = -value if opt[:negative] && opt[:negative] != opt[:positive]
#!          opt[:negative] || opt[:positive]
#!        end
#!      end
#!      value = self.format_money( value, pattern, opt)
#!      value = opt[:unit]+value if opt[:unit]
#!      value.gsub!(/\./,opt[:separator]) if opt[:separator]
#!      if opt[:delimiter] && (m = value.match(/^(\D*)(\d+)(.*)/))
#!        # Adapted From Rails' ActionView::Helpers::NumberHelper
#!        n = m[2].gsub(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1#{opt[:delimiter]}")
#!        value=m[1]+n+m[3]
#!      end
#!      value
#!    end
#!
#!    def self.integer_to_float(value, *args)
#!      opt = args.last.is_a?(Hash) ? args.pop : {}
#!      return (opt[:blank]||nil) if value.nil?
#!      value = 1.0 * value / (10**(opt[:precision]||2))
#!    end
#!
#!    # Returns the integer of the given money string. Uses relevant options from #easy_money
#!    def self.money_to_integer(value, *args)
#!      opt = args.last.is_a?(Hash) ? args.pop : {}
#!      value = value.gsub(opt[:delimiter],'') if opt[:delimiter]
#!      value = value.gsub(opt[:separator],'.') if opt[:separator]
#!      value = value.gsub(/^[^\d\.\-\,]+/,'')
#!      return (opt[:blank]||nil) unless value =~ /\d/
#!      m = value.to_s.match(opt[:negative_regex]||/^(-?)(.+\d)\s*cr/i)
#!      value = value.match(/^-/) ? m[2] : "-#{m[2]}" if m && m[2]
#!
#!      # Money string ("123.45") to proper integer withough passing through the float transformation
#!      match = value.match(/(-?\d*)\.?(\d*)/)
#!      return 0 unless match
#!      value = match[1].to_i * (10 ** (opt[:precision]||2))
#!      cents = match[2]
#!      cents = cents + '0' while cents.length < (opt[:precision]||2)
#!      cents = cents.to_s[0,opt[:precision]||2]
#!      value += cents.to_i * (value<0 ? -1 : 1)
#!      value
#!    end
#!
#!    # Returns the integer (cents) value from a Float
#!    def self.float_to_integer(value, *args)
#!      opt = args.last.is_a?(Hash) ? args.pop : {}
#!      return (opt[:blank]||nil) if value.nil?
#!      value = (value.to_f*(10**((opt[:precision]||2)+1))).to_i/10 # helps rounding 4.56 -> 455 ouch!
#!    end
#!
#!    # Replacing the sprintf function to deal with money as float. "... %[flags]m ..."
#!    def self.format_money(value, pattern="%.2m", *args)
#!      opt = args.last.is_a?(Hash) ? args.pop : {}
#!      sign = value < 0 ? -1 : 1
#!      dollars, cents = value.abs.divmod( 10 ** (opt[:precision]||2))
#!      dollars *= sign
#!      parts = pattern.match(/^(.*)%([-\. \d+0]*)[fm](.*)/)
#!      return pattern unless parts
#!      intdec = parts[2].match(/(.*)\.(\d*)/)
#!      dprec, cprec = intdec ? [intdec[1], intdec[2]] : ['', '']
#!      dollars = sprintf("%#{dprec}d", dollars)
#!      cents = '0' + cents.to_s while cents.to_s.length < (opt[:precision]||2)
#!      cents = cents.to_s[0,cprec.to_i]
#!      cents = cents + '0' while cents.length < cprec.to_i
#!      value = parts[1] + "#{(dollars.to_i==0 && sign==-1) ? '-' : '' }#{dollars}#{cents>' '? '.':''}#{cents}" + parts[3]
#!      value
#!    end

