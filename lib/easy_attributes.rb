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
  # EasyAttributes::Definition - Class of a attribute values definition
  # 
  #   attribute    - symbolic name of the attribute, field, or column.
  #   symbols      - Hash of {symbolic_value:value, ...}
  #   values       - Hash of {value => :symbolic_value, ...}
  #   options      - Hash of {option_name:value} for attribute settings
  #   attr_options - Hash of {value_name: {option_name:value, ...}, e.g.
  #                          :name  - Alternate text for the value name
  #                          :title - Alternate text for value definition
  #                          :role  - Identifier for a role allowed to set/see
  #############################################################################
  class Definition
    include Enumerable
    attr_accessor :attribute, :values, :symbols, :options, :attr_options

    # Public: Returns an existing or new definition for the atribute name
    # Call this method to define a global or shared setting
    #
    # attribute  - The name of the attribute
    # definition - The optional definition list passed to initialize
    #              A has of symbol_name => values
    #              Make sure the type of value matches your use,
    #              either a string "42" or integer "42".to_i
    # attr_options - A optional Hash of attribute names to a hash of additional info
    #              {status:{help:"...", title:"Status"}}
    #
    # Examples
    #
    #   defn = Definition.find_or_create(:status).add_symbol(:retired, 3)
    #   defn = Definition.find_or_create(:status, active:1, inactive:2)
    #   defn = Definition.find_or_create(:storage, {}, {kb_size:1000})
    #   defn.values #=> {value=>:symbol,...}
    #   defn.symbols #=> {:symbol=>:value,...}
    #
    #
    # Returns an existing or new instance of Definition
    #
    def self.find_or_create(attribute, *definition)
      attribute = attribute.to_sym
      @attributes ||= {}
      unless @attributes.has_key?(attribute)
        @attributes[attribute] = Definition.new(attribute, *definition)
      end
      @attributes[attribute]
    end

    def to_s
      "<#EasyAttributes::Definition #{@attribute} #{@symbols}>"
    end

    def self.definitions
      @attributes
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
    #         - Array of enum definitions for the attribute, or
    #         - Hash of {value:value, title:text, name:text, option_name:etc}
    # options - Hash of {name:value,...} to track for the attribute. Optional.
    #           attr_options: {attribute: {....}, ...}
    #
    # Examples
    #
    #   definition.define(active:1, inactive:2)
    #   definition.define(:active, :inactive)
    #
    def define(*args)
      return if args.first.nil?
      return define_enum(*args) if args.first.is_a?(Array)

      #symbols = Hash[* args.first.collect {|k,v| [k.to_sym, v]}.flatten]
      symbols = {}
      options = {}
      args.first.each do |k,v|
         if v.is_a?(Hash)
           symbols[k.to_sym] = v.delete(:value) {k.to_s}
           options[k.to_sym] = v
         else
           symbols[k.to_sym] = v
         end
      end

      self.symbols.merge!(symbols)
      self.values = Hash[* self.symbols.collect {|k,v| [v, k]}.flatten]
      self.attr_options.merge!(options)
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
    def define_enum(args, opt={})
      opt = {step:1}.merge(opt)
      opt[:start] ||= self.values.keys.max ? self.values.keys.max + opt[:step] : Config.enum_start
      hash = {}
      i = opt[:start]
      args.flatten.each do |arg|
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
    def symbol_of(value, default=nil)
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
    #   definition.value_in(self.status, :active)         # => false (maybe)
    #   definition.value_in(self.:status, :active, :inactive)  # => true (maybe)
    #   self.value_in(:status, :between, :active, :inactive)  # => true (maybe)
    #
    # Returns true if the value matches
    def value_in(value, *args)
      args.each do |arg|
        return true if value == value_of(arg)
      end
      false
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

    # Public: Builds a list of [option_name, value] pairs useful for HTML select options
    # Where option_name is the first found of:
    #   - attr_options[:option_name]
    #   - attr_options[:title]
    #   - attr_options[:name]
    #   - capitalized attribute name
    #
    # attribute - symbolic name of attribute
    #
    # Returns an array of [option_name, value] pairs.
    def select_option_values(*args)
      self.symbols.collect {|s,v| [symbol_option_name(s,*args), v]}
    end

    # Private: Builds a list of [option_name, symbol] pairs useful for HTML select options
    # Where option_name is as defined in selection_option_values
    #
    # attribute - symbolic name of attribute
    #
    # Returns an array of [option_name, symbol] pairs.
    def select_option_symbols(*args)
      self.symbols.collect {|s,v| [symbol_option_name(s,*args), s]}
    end

    def symbol_option_name(s, *args)
      if @attr_options.has_key?(s)
        args.each {|arg| return @attr_options[s][arg] if @attr_options[s].has_key?(arg) }
        [:option_name, :title, :name] .each do |f|
          return @attr_options[s][f] if @attr_options[s].has_key?(f)
        end
      end
      s.to_s.capitalize
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

    def inspect
      @value
    end

    ###########################################################################
    # Official Definitions for kilobyte and kibibyte quantity units
    ###########################################################################
    KB =1000; MB =KB ** 2; GB= KB ** 3; TB =KB ** 4; PB =KB ** 5; EB =KB ** 6; ZB =KB ** 7; YB =KB ** 8
    KiB=1024; MiB=KiB**2; GiB=KiB**3; TiB=KiB**4; PiB=KiB**5; EiB=KiB**6; ZiB=KiB**7; YiB=KiB**8
    BINARY_UNITS  = {:B=>1,:KiB=>KiB,:MiB=>MiB,:GiB=>GiB,:TiB=>TiB,:PiB=>PiB,:EiB=>EiB,:ZiB=>ZiB,:TiB=>YiB}
    DECIMAL_UNITS = {:B=>1,:KB=>KB,  :MB=>MB,  :GB=>GB,  :TB=>TB,  :PB=>PB,  :EB=>EB,  :ZB=>ZB,  :YB=>YB}
    JEDEC_UNITS   = {:B=>1,:KB=>KiB, :MB=>MiB, :GB=>GiB, :TB=>TiB, :PB=>PiB, :EB=>EiB, :ZB=>ZiB, :TB=>YiB}

    # Public: Maps the kb_size into a hash of desired unit_symbol=>bytes.
    #
    # kb_size   - For decimal units: 1000, :decimal, :si, :kb
    #             For binary units : 1024, :jedec, :old, :kib
    #             Otherwise a hash of combined values is returned
    #
    # Returns a hash of prefix names to decimal quantities for the given setting
    def self.byte_units(kb_size=0)
      case kb_size
      when 1000, :decimal, :si, :kb, :KB then DECIMAL_UNITS
      when :old, :jedec, 1024, :kib, :KiB then JEDEC_UNITS
      when :new, :iec then BINARY_UNITS
      else DECIMAL_UNITS.merge(BINARY_UNITS) # Both? What's the least surprise?
      end
    end

    # Private: Formats an integer as a byte-representation
    #
    #   v        - Integer value of bytes
    #   unit     - Optional Unit to use for representation, regardless of magnitude
    #   opt      - Optional hash of overrides for :kb_size, :precision, etc.
    #
    # Example:
    #   format_bytes(1000, :kb) # => "1 KB"
    #
    # Returns a string like "n.nn XB" representing the approximate bytes
    #
    def format_bytes(v, *args)
      #puts "&format_bytes(#{v},#{args.inspect})"
      #units = EasyAttributes.byte_units(opt[:kb_size]||EasyAttributes::Config.kb_size||0)
      opt = args.last.is_a?(Hash) ? args.pop : {}
      opt = attr_options.merge(opt)
      unit = args.shift
      units = Definition.byte_units(opt[:kb_size]||Config.kb_size||1000)
      precision = opt[:precision] || attr_options[:precision] || 0
      #vint = v

      if unit
        units = Definition.byte_units() unless units.has_key?(unit)
        v = "%.#{precision}f" % (1.0 * v / (units[unit]||1))
        #puts "format_bytes(#{vint},#{unit},#{precision}) => #{v} #{unit}"
        return "#{v} #{unit}"
      end

      units.sort{|a,b| a[1]<=>b[1]}.reverse.each do |pv|
        next if pv[1] > v
        v = "%.#{precision}f" % (1.0 * v / pv[1])
        v.gsub!(/\.0*$/, '')
        #puts "format_bytes(#{vint}) v=#{v}, p=#{precision}, #{pv.inspect}"
        return "#{v} #{pv[0]}"
      end
      v.to_s
    end

    # Private: Parses a "1.23 kb" style string and converts into an integer
    # v       - String to parse of the format "1.23 kb" or so
    #           Optionally, this can be an array of [1.23, :kb]
    # options - Hash of options to override defaults
    #           kb_size:1000
    #
    # Returns an integer of the parsed value.
    def parse_bytes(v, *args)
      opt = args.last.is_a?(Hash) ? args.pop : {}
      opt = attr_options.merge(opt)
      # Handle v= [100, :KB]
      if v.is_a?(Array)
        bytes = v.shift
        v = "#{bytes} #{v.shift}"
      else
        bytes = v.to_f
      end

      if v.downcase =~ /^\s*(?:[\d\.]+)\s*([kmgtpezy]i?b)/i
        unit = ($1.size==2 ? $1.upcase : $1[0,1].upcase+$1[1,1]+$1[2,1].upcase).to_sym
        units = Definition.byte_units(opt[:kb_size]||Config.kb_size||1000)
        units = Definition.byte_units(:both) unless units.has_key?(unit)
        #puts "parse_bytes(#{v}) unit=#{unit} b=#{bytes} * #{units[unit]}"
        bytes *= units[unit] if units.has_key?(unit)
      end
      (bytes*100 + 0.00001).to_i/100
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
      case @kb_size
      when :new, :iec then
        1024
      when :old, :jedec, :decimal
        1000
      else
        @kb_size
      end
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

    # Directive to create constants from field value names: FIELD_NAME_VALUE_NAME=value
    def self.constantize=(b)
      @constantize = b ? true : false
    end

    def self.constantize
      @constantize || false
    end

    # Starting point for enum sequences (usually 0 or 1)
    def self.enum_start
      @enum_start || 1
    end

    def self.enum_start=(n)
      @enum_start = n
    end
  end

  # Private Module: FixedPoint handles integer<->fixed-point numbers
  # Fixed-Point rules are a hash of these values
  #   :units          Use this as an alternative suffix name to the money methods ('dollars' gives 'xx_dollars')
  #   :precision      The number of digits implied after the decimal, default is 2
  #   :separator      The character to use after the integer part, default is '.'
  #   :delimiter      The character to use between every 3 digits of the integer part, default none
  #   :positive       The sprintf format to use for positive numbers, default is based on precision
  #   :negative       The sprintf format to use for negative numbers, default is same as :positive
  #   :zero           The sprintf format to use for zero, default is same as :positive
  #   :nil            The sprintf format to use for nil values, default none
  #   :unit           Prepend this to the front of the money value, say '$', default none
  #   :blank          Return this value when the money string is empty or has no digits on assignment
  #   :negative_regex A Regular Expression used to determine if a number is negative (and without a - sign)
  module FixedPoint
    ###########################################################################
    # EasyAttributes Fixed-Precision as Integer Helpers
    ###########################################################################

    # Private: Formats an integer value as the defined fixed-point representation
    # value  - integer representation of number
    # rules    - hash of fixed-point conversion rules
    #
    # Returns the fixed-point representation as a string for editing
    def self.integer_to_fixed_point(value, *args)
      opt = args.last.is_a?(Hash) ? args.pop : {}
      opt[:positive] ||= "%.#{opt[:precision]||2}f"
      pattern =
      if value.nil?
        value = 0
        opt[:nil] || opt[:positive]
      else
        case value <=> 0
        when 1 then opt[:positive]
        when 0 then opt[:zero] || opt[:positive]
        else
          value = -value if opt[:negative] && opt[:negative] != opt[:positive]
          opt[:negative] || opt[:positive]
        end
      end
      value = self.format_fixed_point( value, pattern, opt)
      value = opt[:unit]+value if opt[:unit]
      value.gsub!(/\./,opt[:separator]) if opt[:separator]
      if opt[:delimiter] && (m = value.match(/^(\D*)(\d+)(.*)/))
        # Adapted From Rails' ActionView::Helpers::NumberHelper
        n = m[2].gsub(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1#{opt[:delimiter]}")
        value=m[1]+n+m[3]
      end
      value
    end

    # Private: Converts the integer into a float value with the given fixed-point definition
    #
    # value    - integer to convert
    # rules    - hash of fixed-point conversion rules
    #
    # Returns a float of the converted value
    def self.integer_to_float(value, *args)
      opt = args.last.is_a?(Hash) ? args.pop : {}
      return (opt[:blank]||nil) if value.nil?
      value = 1.0 * value / (10**(opt[:precision]||2))
    end

    # Private: Takes a string of a fixed-point representation (from editing) and converts it to
    # the integer representation according to the passed rules hash
    # rules    - hash of fixed-point conversion rules
    #
    # Returns the integer of the given money string. Uses relevant options from #easy_money
    def self.fixed_point_to_integer(value, *args)
      opt = args.last.is_a?(Hash) ? args.pop : {}
      value = value.to_s
      value = value.gsub(opt[:delimiter],'') if opt[:delimiter]
      value = value.gsub(opt[:separator],'.') if opt[:separator]
      value = value.gsub(/^[^\d\.\-\,]+/,'')
      return (opt[:blank]||nil) unless value =~ /\d/
      m = value.to_s.match(opt[:negative_regex]||/^(-?)(.+\d)\s*cr/i)
      value = value.match(/^-/) ? m[2] : "-#{m[2]}" if m && m[2]

      # Money string ("123.45") to proper integer withough passing through the float transformation
      match = value.match(/(-?\d*)\.?(\d*)/)
      return 0 unless match
      value = match[1].to_i * (10 ** (opt[:precision]||2))
      cents = match[2]
      cents = cents + '0' while cents.length < (opt[:precision]||2)
      cents = cents.to_s[0,opt[:precision]||2]
      value += cents.to_i * (value<0 ? -1 : 1)
      value
    end

    # Returns the integer (cents) value from a Float
    # rules    - hash of fixed-point conversion rules
    def self.float_to_integer(value, *args)
      opt = args.last.is_a?(Hash) ? args.pop : {}
      return (opt[:blank]||nil) if value.nil?
      value = (value.to_f*(10**((opt[:precision]||2)+1))).to_i/10 # helps rounding 4.56 -> 455 ouch!
    end

    # Replacing the sprintf function to deal with money as float. "... %[flags]m ..."
    # rules    - hash of fixed-point conversion rules
    def self.format_fixed_point(value, pattern="%.2m", *args)
      opt = args.last.is_a?(Hash) ? args.pop : {}
      sign = value < 0 ? -1 : 1
      dollars, cents = value.abs.divmod( 10 ** (opt[:precision]||2))
      dollars *= sign
      parts = pattern.match(/^(.*)%([-\. \d+]*)[fm](.*)/)
      return pattern unless parts
      intdec = parts[2].match(/(.*)\.(\d*)/)
      dprec, cprec = intdec ? [intdec[1], intdec[2]] : ['', '']
      dollars = sprintf("%#{dprec}d", dollars)
      cents = '0' + cents.to_s while cents.to_s.length < (opt[:precision]||2)
      cents = cents.to_s[0,cprec.to_i]
      cents = cents + '0' while cents.length < cprec.to_i
      value = parts[1] + "#{(dollars.to_i==0 && sign==-1) ? '-' : '' }#{dollars}#{cents>' '? '.':''}#{cents}" + parts[3]
      value
    end
  end # FixedPoint


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
  #     attr_fixed   :attr, :precision=>2
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
    #   status_in(symbol, ...)     # Returns true if the attribute symbol is in the list of symbols
    #   status_cmp(symbol)          # Returns the comparison of the value <=> symbol
    #
    # And these class methods:
    #
    #   status_definition()
    #     Returns the EasyAttributes::Definition for the attribute, on which you can call cool things like
    #     value_of(), symbol_of(), select_options(), etc.
    #
    # Returns nothing
    def attr_values(attribute, *args)
      #defn = Definition.find_or_create(attribute, *args)
      defn = Definition.new(attribute, *args)
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
      opt = args.last.is_a?(Hash) ? args.pop : {}
      #defn = Definition.find_or_create(attribute, args, opt)
      defn = Definition.new(attribute, args, opt)
      easy_attribute_accessors(attribute, defn)
    end

    # Public: Imports global definitions into the class by attribute name or Hash mapping.
    #
    # attributes - List of attributes to import from Config definitions
    # mappings   - Hash of atttribute names to a matching alternate name in the Config definitions
    #
    # Exanples
    #
    #   attr_shared :status, :role, widget_type: :general_type, colname: :sharedname
    #   attr_shared employee_status:Employee.status_definition()
    #
    # Calls attr_values with each definition
    def attr_shared(*attributes)
      mapping = attributes.last.is_a?(Hash) ? attributes.pop : {}
      attributes.each { |attribute| attr_values(attribute) }
      mapping.each do |attribute,alternate_name|
        defn = if alternate_name.is_a?(Definition)
                   alternate_name
                 else
                   Definition.find_or_create(alternate_name)
                 end
        easy_attribute_accessors(attribute, defn)
      end
    end

    # Private: Creates attribute accessors for the attribute /definition for attr_values
    #
    # Creates these methods dynamically on the host class
    #   self.<attribute>_definition()
    #   <attribute>_sym()
    #   <attribute>_sym=()
    #   <attribute>_in()
    #   <attribute>_cmp()
    #
    # If Config.constantize, create ATTRIBUTE_SYMBOL=value constants
    #
    def easy_attribute_accessors(attribute, defn)
      attribute = attribute.to_sym
      @easy_attribute_definitions ||= {}
      @easy_attribute_definitions[attribute] = defn
      opt = defn.options
      code = ''

      if EasyAttributes::Config.orm == :active_model || opt[:orm] == :active_model
        self.validates_inclusion_of attribute, :in=>defn.symbols.values
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

      #------------------------------------------------------------------------
      # Class Methods
      #------------------------------------------------------------------------

      define_easy_attribute_definition
      # # Adds once to class: Returns the EasyAttribute::Definition of the passed
      # # Easy Attribute name
      # unless self.respond_to?(:easy_attribute_definition)
      #   define_singleton_method(:easy_attribute_definition) do |attrib|
      #     @easy_attribute_definitions.fetch(attrib.to_sym) { raise "EasyAttribute #{attrib} not found" }
      #   end
      # end

      # <attribute>_options() Returns an array of (HTML Select) option pairs
      # => [["Option Name", :symbol], ...]
      self.define_singleton_method("#{attribute}_options") do |*args|
        easy_attribute_definition(attribute).select_option_symbols(*args)
      end

      # <attribute>_of(:sym [,:default_sym]) Returns the symbol/value hash for the attribute
      self.define_singleton_method("#{attribute}_of") do |*args, &block|
        easy_attribute_definition(attribute).symbols.fetch(args.first.to_sym) do |sym| 
          if args.size>1
            easy_attribute_definition(attribute).symbols.fetch(args[1].to_sym, &block)
          else
            raise "#{attribute} symbolic name #{sym} not found" 
          end
        end
      end

      # Define Constants Model::ATTRIBUTE_SYMBOL = value
      if Config::constantize
        easy_attribute_definition(attribute).symbols.each do |sym, value|
          #puts("#{attribute.upcase}_#{sym.to_s.upcase}= #{value}")
          const_set("#{attribute.upcase}_#{sym.to_s.upcase}", value)
        end
      end

      #------------------------------------------------------------------------
      # Instance Methods
      #------------------------------------------------------------------------

      # <attribute>_definition()
      # Returns the definition ojbect for the easy attribute
      define_method("#{attribute}_definition") do
        self.class.easy_attribute_definition(attribute)
      end

      # <attribute>_sym()
      # Returns the symbolic name of the current value of "attribute"
      define_method("#{attribute}_sym") do
        self.class.easy_attribute_definition(attribute).symbol_of(self.send(attribute))
      end

      # <attribute>_sym=(new_symbol)
      # Sets the value of "attribute" to the associated value of the passed symbolic name
      define_method("#{attribute}_sym=") do |sym|
        self.send("#{attribute}=", self.class.easy_attribute_definition(attribute).value_of(sym))
      end

      # <attribute>_in(*names)
      # Returns true if the symbolic name of the current value of "attribute" is in the list of names.
      define_method("#{attribute}_in") do |*args|
        self.class.easy_attribute_definition(attribute).value_in(self.send(attribute),*args)
      end

      # <attribute>_cmp(other)
      # Standard "cmp" or <=> compare for "attribute" against a symbolic name.
      define_method("#{attribute}_cmp") do |other|
        self.class.easy_attribute_definition(attribute).cmp(self.send(attribute),other)
      end

      ## <attribute>_value()
      ## Experimental for the EasyAttributes::Value class, getter and setter methods
      #define_method("#{attribute}_value") do
      #  self.class.easy_attribute_definition(attribute).value(self.send(attribute))
      #end

      ## <attribute>value=(new_value_object)
      #define_method("#{attribute}_value=") do |v|
      #  self.send("#{attribute}=", self.class.easy_attribute_definition(attribute).value(v))
      #end
    end

    # Adds once to class: Returns the EasyAttribute::Definition of the passed
    def define_easy_attribute_definition
      unless self.respond_to?(:easy_attribute_definition)
        define_singleton_method(:easy_attribute_definition) do |attrib|
          @easy_attribute_definitions.fetch(attrib.to_sym) { raise "EasyAttribute #{attrib} not found" }
        end
      end
    end

    # Public: Adds byte attributes helpers to the class
    # attr_bytes allows manipultion and display as kb, mb, gb, tb, pb
    # Adds method: attribute_bytes=() and attribute_bytes(:unit, :option=>value )
    #
    # attribites - List of attribute names to generate helpers for
    # options    - Hash of byte helper options
    #
    # Example
    #
    #   attr_bytes :bandwidth
    #   attr_bytes :storage, :kb_size=>1000, :precision=>2
    #
    # Adds the following helpers
    #
    #   bandwidth_bytes()         # => "10 GB"
    #   bandwidth_bytes=("10 GB") # => 10_000_000_000
    #
    def attr_bytes(*args)
      define_easy_attribute_definition
      @easy_attribute_definitions ||= {}
      opt = args.last.is_a?(Hash) ? args.op : {}

      args.each do |attribute|
        attribute = attribute.to_sym
        unless EasyAttributes::Config.orm == :active_model || opt[:orm] == :active_model
          attr_accessor attribute if EasyAttributes::Config.orm == :attr
        end
        #defn = Definition.find_or_create(attribute, {}, opt)
        defn = Definition.new(attribute, {}, opt)
        @easy_attribute_definitions[attribute] = defn

        # <attribute>_bytes()
        # Returns the symbolic name of the current value of "attribute"
        define_method("#{attribute}_bytes") do |*bargs|
          self.class.easy_attribute_definition(attribute).format_bytes(self.send(attribute), *bargs)
        end

        # <attribute>_bytes=(new_symbol)
        # Sets the value of "attribute" to the associated value of the passed symbolic name
        define_method("#{attribute}_bytes=") do |sym|
          self.send("#{attribute}=", self.class.easy_attribute_definition(attribute).parse_bytes(sym))
        end
      end
    end

    # Public: Adds methods to get and set a fixed-point value stored as an integer.
    #
    # attributes - list of attribute names to define
    # options    - Optional hash of definitions for the given list of attributes
    #       :method_suffix - Use this as the alternative name to the *_fixed method names
    #       :units - Use this as an alternative suffix name to the money methods ('dollars' gives 'xx_dollars')
    #       :precision - The number of digits implied after the decimal, default is 2
    #       :separator - The character to use after the integer part, default is '.'
    #       :delimiter - The character to use between every 3 digits of the integer part, default none
    #       :positive - The sprintf format to use for positive numbers, default is based on precision
    #       :negative - The sprintf format to use for negative numbers, default is same as :positive
    #       :zero - The sprintf format to use for zero, default is same as :positive
    #       :nil - The sprintf format to use for nil values, default none
    #       :unit - Prepend this to the front of the money value, say '$', default none
    #       :blank - Return this value when the money string is empty or has no digits on assignment
    #       :negative_regex - A Regular Expression used to determine if a number is negative (and without a - sign)
    #
    # Examples:
    #   attr_fixed :gpa, precision:1
    #   attr_fixed :price, precision:2
    #
    # Adds the following helpers
    #
    #   gpa_fixed()               #=> "3.8"
    #   gpa_fixed=("3.8")         #=> 38
    #   gpa_float()               #=> 3.8
    #
    # Returns nothing
    def attr_fixed(*args)
      define_easy_attribute_definition
      @easy_attribute_definitions ||= {}
      opt = args.last.is_a?(Hash) ? args.pop : {}
      suffix = opt.fetch(:method_suffix) { 'fixed' }

      args.each do |attribute|
        attribute = attribute.to_sym
        unless EasyAttributes::Config.orm == :active_model || opt[:orm] == :active_model
          attr_accessor attribute if EasyAttributes::Config.orm == :attr
        end
        #defn = Definition.find_or_create(attribute, {}, opt)
        defn = Definition.new(attribute, {}, opt)
        @easy_attribute_definitions[attribute] = defn

        # <attribute>_fixed()
        # Returns the symbolic name of the current value of "attribute"
        define_method("#{attribute}_#{suffix}") do
          FixedPoint::integer_to_fixed_point(send(attribute), self.class.easy_attribute_definition(attribute).attr_options)
        end

        # <attribute>_fixed=(new_value)
        # Sets the value of "attribute" to the associated value of the passed symbolic name
        define_method("#{attribute}_#{suffix}=") do |val|
          self.send("#{attribute}=", FixedPoint::fixed_point_to_integer(val,
            self.class.easy_attribute_definition(attribute).attr_options))
        end

        # <attribute>_float()
        # Returns the value of the attribite as a float with desired precision point
        define_method("#{attribute}_float") do
          FixedPoint::integer_to_float(send(attribute), self.class.easy_attribute_definition(attribute).attr_options)
        end
      end
    end

    # Public: Alias of attr_fixed for a money type with suffix of 'money' and precision of 2.
    #
    # args       - list of money attributes
    # options    - hash of attr_fixed options.
    #
    # Examples:
    #   attr_money :price
    #   attr_money :wager, method_suffix:'quatloos', precision:1, unit:'QL'
    #
    # Adds the following helpers
    #
    #   price_money()               #=> "42.00"
    #   price_money=("3.8")         #=> 380
    #   price_float()               #=> 3.8
    #
    def attr_money(*args)
      opt = args.last.is_a?(Hash) ? args.pop : {}
      opt = {method_suffix:'money', precision:2}.merge(opt)
      args << opt
      attr_fixed(*args)
    end

    def attr_dollars(*args)
      opt = args.last.is_a?(Hash) ? args.pop : {}
      attr_money(*args, opt.merge(method_suffix:'dollars'))
    end

  end # EasyAttributes::ClassMethods
end # EasyAttributes Module
