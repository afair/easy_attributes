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
#   Gemfile (then `bundle install`):
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
  
  # EasyAttributes::Config - Namespace to define and hold configuration data.
  class Config
    @orm        = :attr    # :attr, :active_model
    @kb_size    = :iec     # :iec, :old, :new
    @attributes = {}       # {attribute:{symbols:{symbol:value, ... },
                           #             values: {value:symbol, ... },
                           #             options:{name:value,   ... }}, ... }
    
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

    # Public: Create an attrbiute definition
    #
    # attrib  - name of the attribute or database column
    # symbols - Hash of {symbol:value,...} for the attribute
    # options - Hash of {name:value,...} to track for the attribute. Optional.
    #
    # Examples
    #
    #   EasyAttributes::Config.define_attribute :status, active:1, inactive:2
    #   EasyAttributes::Config.define_attribute :status, {active:1, inactive:2}
    #     active:{name:"Active"}, inactive:{name:"Inactive}
    #
    # Returns the attribute definition structure
    #
    def self.define_attribute(attrib, symbols, options={})
      symbols = Hash[* symbols.collect {|k,v| [k.to_sym, v]}.flatten]
      values  = Hash[* symbols.collect {|k,v| [v, k]}.flatten]
      options = Hash[* options.collect  {|k,v| [k.to_sym, v]}.flatten]
      @attributes[attrib.to_sym] = {symbols:symbols, values:values, options:options}
    end

    # Public: Defines an Attribute/Symbol/Value tuple
    #
    # attrib  - name of the attribute or database column
    # symbol  - internal symbolic name for the value
    # value   - Value to store in class or database
    # options - Hash of {name:value,...} to track for the symbol. Optional.
    #
    # Examples
    #
    #   EasyAttributes::Config.define_value :status, :active, 1
    #   EasyAttributes::Config.define_value :status, :active, 1, name:"Active"
    #
    # Returns nothing
    def self.define_value(attrib, symbol, value, options={})
      attrib = attribute.to_sym
      symbol = symbol.to_sym
      @attributes[attrib] = {symbols:{}, values:{}, options:{}} unless @attributes.has_key?(attrib)
      @attributes[attrib][:symbols][symbol] = value
      @attributes[attrib][:values][value] = symbol
      @attributes[attrib][:options] = options
    end

    # Public: Defines an attribute as an enumerated set of symbol/values
    #
    # attrib  - name of the attribute or database column
    # args    - list of symbols, reset values, with an optional options Hash
    #           a non-symbolic arg resets the counter to that value
    #           Non-integer values can be given if the #next() method is provided
    #           nil can be passed to skip the positional value
    #
    # Examples
    #
    #   EasyAttributes::Config.define_enum :status, :active, :inactive
    #   EasyAttributes::Config.define_enum :status, :active, :inactive, start:1, step:10
    #   EasyAttributes::Config.define_enum :status, :active, 11, :inactive
    #   
    # Returns the attribute definition structure
    def self.define_enum(attrib, *args)
      opt = {start:0, step:1}.merge(args.last.is_a?(Hash) ? args.pop : {})
      symbols = {}
      i = opt[:start]
      args.each do |arg|
        if arg.is_a?(Symbol) || arg.nil?
          symbols[arg] = i unless arg.nil?
          opt[:step].times {i = i.next}
        else
          i = arg
        end
      end
      define_attribute(attrib, symbols)
    end
    
    # Public: Returns the definition for the given attribute
    #
    # attrib  - name of the attribute or database column
    #
    # Returns a Hash of {symbols:{symbol:value,}, values:{value:symbol}, options:{name:value}}
    #
    def self.definition(attrib)
      @attributes.fetch(attrib.to_sym) {Hash.new}
    end

   
    # Returns an array of [name,value] pairs useful for HTML select options
    #
    #  BELONGE ELSEWHERE
    #
    def select_options(attrib, *args)
      defn = definition.attrib
      return [] if defn.empty?
      return defn[:options][:select_options] if defn[:options].has_key?(:select_options)
      return defn[:options][:select_proc].call(attrib, defn, *args) if defn[:options].has_key?(:select_proc)
      defn[:symbols].collect {|s,v| [s.to_s.capitalize, v]}
    end
    
  end
  
  # attr_values :attr, name:value, ...
  # attr_enum   :attr, :name, ....
  # attr_defined :attr, :attr=>:defined_attr
  # attr_bytes  :attr, ..., :base=>2
  # attr_fixed_point :attr, :precision=>2
  # attr_money  :attr, :precision=>2
  #
  module ClassMethods
    
    # Public: Defines an attribute with a Hash of symbolic synonyms for the values.
    #
    # attribute - symbolic name of the attribute
    # values    - a hash of {symbol:value, ....} mappings
    #             a optional key of :options=>{name:value} defines any options for the attribute
    # Examples
    #
    #   attr_values :status, active:1, inactive:2
    #   attr_values :status, active:1, inactive:2, 
    #     options:{select_options:lambda { |*args| attr_select_options(*args) }
    #
    # Creates these instance methods (for a "status" attribute):
    #
    #   status_sym()                # Returns the symbolic name instead of value
    #   status_sym=(:inactive)      # Used for setting the attrivute by symbolic name instead
    #   status_is?(symbol1,...)     # Returns true if the attribute symbol is in the list of symbols
    #   
    # And these class methods:
    #
    #   status_select(*args)        # Returns an array of [symbol,value] pairs suitable for HTML Select Options
    #   status_values()             # Returns an array of all defined values for attribute
    #   status_symbols()            # Returns an array of all defined symbols for attribute
    #
    # Returns nothing
    def self.attr_values(attribute, *args)
      defn = Config.define_attribute(attribute, *args)
      define_attr_accessors(defn)
    end

    def self.define_attr_accessors(defn)
      name = "#{self.name}##{attribute}"
      EasyAttributes.add_definition( name, hash)
      code = ''
      if EasyAttributes::Config.orm == :active_model
        validates_inclusion_of attribute, :in=>hash.values
        # Add named_scope (scope) for each value
        if opt[:named_scope]
          hash.each { |k,v| code += "named_scope :#{k}, :conditions=>{:#{attribute}=>#{v.inspect}}\n" }
        end
        if opt[:scope]
          hash.each { |k,v| code += "scope :#{k}, where({:#{attribute}=>#{v.inspect}})\n" }
        end
      else
        attr_accessor attribute
      end
      code += %Q(
        def #{attribute}_sym=(v)
          self.#{attribute} = EasyAttributes.value_for_sym("#{name}", v)
        end
        def #{attribute}_sym
          EasyAttributes.sym_for_value("#{name}", #{attribute})
        end
        def self.#{attribute}_values
          EasyAttributes::Config.definition("#{name}")[:values][values]
        end
        def #{attribute}_is?(*args)
          EasyAttributes.value_is?("#{name}", #{attribute}, *args)
        end
      )

      ## status=(symbol_or_value)    # A setter for ActiveModel configurations
      #if EasyAttributes::Config.orm == :active_model
      #  code += %Q(
      #    def #{attribute}=(v)
      #      self[:#{attribute}] = v.is_a?(Symbol) ? EasyAttributes.value_for_sym("#{attribute}", v) : v; 
      #    end
      #  )
      #end
      #puts code

      class_eval code
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
    def self.attr_enum(attribute, *args)
      defn = Config.define_enum(attribute, *args)
      define_attr_accessors(defn)
    end

    ###########################################################################
    # EasyAttributes Byte Helpers
    ###########################################################################
    
    # attr_bytes allows manipultion and display as kb, mb, gb, tb, pb
    # Adds method: attribute_bytes=() and attribute_bytes(:unit, :option=>value )
    def attr_bytes(attribute, *args)
      name = "#{self.name}##{attribute}"
      opt = EasyAttributes.pop_options(args)
      #getter, setter = EasyAttributes.getter_setter(attribute)
      attr_accessor attribute if EasyAttributes::Config.orm == :attr
      code = %Q(
        def #{attribute}_bytes(*args)
          args.size == 0 ? v : EasyAttributes::format_bytes(self.#{attribute}, *args)
        end
        def #{attribute}_bytes=(v)
          self.#{attribute} = EasyAttributes.parse_bytes(v)
        end
      )
      #puts code
      class_eval code
    end
    
    # Creates an money instance method for the given method, named "#{attribute}_money" which returns
    # a formatted money string, and a #{attribute}_money= method used to set an edited money string.
    # The original method stores the value as integer (cents, or other precision/currency setting). Options:
    # * :money_method - Use this as the alternative name to the money-access methods
    # * :units - Use this as an alternative suffix name to the money methods ('dollars' gives 'xx_dollars')
    # * :precision - The number of digits implied after the decimal, default is 2
    # * :separator - The character to use after the integer part, default is '.'
    # * :delimiter - The character to use between every 3 digits of the integer part, default none
    # * :positive - The sprintf format to use for positive numbers, default is based on precision
    # * :negative - The sprintf format to use for negative numbers, default is same as :positive
    # * :zero - The sprintf format to use for zero, default is same as :positive
    # * :nil - The sprintf format to use for nil values, default none
    # * :unit - Prepend this to the front of the money value, say '$', default none
    # * :blank - Return this value when the money string is empty or has no digits on assignment
    # * :negative_regex - A Regular Expression used to determine if a number is negative (and without a - sign)
    #
    def attr_money(attribute, *args)
      opt = args.last.is_a?(Hash) ? args.pop : {}
      money_method = opt.delete(:money_method) || "#{attribute}_#{opt.delete(:units)||'money'}"

      class_eval %Q(
      def #{money_method}(*args)
        opt = args.last.is_a?(Hash) ? args.pop : {}
        EasyAttributes.integer_to_money( #{attribute}, #{opt.inspect}.merge(opt))
      end

      def #{money_method}=(v, *args)
        opt = args.last.is_a?(Hash) ? args.pop : {}
        self.#{attribute} = EasyAttributes.money_to_integer( v, #{opt.inspect}.merge(opt))
      end
      )
    end
    
  # Returns a [getter_code, setter_code] depending on the orm configuration
  def self.getter_setter(attribute)
    if EasyAttributes::Config.orm == :active_model
      ["self.attributes[:#{attribute}]", "self.write_attribute(:#{attribute}, v)"]
    else
      ["@#{attribute}", "@#{attribute} = v"]
    end
  end

  def self.pop_options(args, defaults={})
    args.last.is_a?(Hash) ? defaults.merge(args.pop) : defaults
  end
  
  def self.add_definition(attribute, hash, opt={})
    EasyAttributes::Config.define attribute, hash
  end
  
  ##############################################################################
  # attr_values helpers
  ##############################################################################
  
  # Returns the defined value for the given symbol and attribute
  def self.value_for_sym(attribute, sym)
    EasyAttributes::Config.attributes[attribute][sym]
  end
  
  # Returns the defined symbol for the given value on the attribute
  def self.sym_for_value(attribute, value)
    EasyAttributes::Config.attributes[attribute].each {|k,v| return k if v==value}
    raise "EasyAttribute #{attribute} symbol not found for #{value}"
  end
  
  def self.value_is?(attribute, value, *args)
    case args.first
    when :between then
      value >= EasyAttributes::Config.attributes[attribute][args[1]] && value <= EasyAttributes::Config.attributes[attribute][args[2]]
    when :gt, :greater_than then
      value > EasyAttributes::Config.attributes[attribute][args[1]]
    when :ge, :greater_than_or_equal_to then
      value >= EasyAttributes::Config.attributes[attribute][args[1]]
    when :lt, :less_than then
      value < EasyAttributes::Config.attributes[attribute][args[1]]
    when :le, :less_than_or_equal_to then
      value <= EasyAttributes::Config.attributes[attribute][args[1]]
    #when :not, :not_in
    #  ! args.include? EasyAttributes::Config.attributes[attribute].keys
    else
      args.include? EasyAttributes.sym_for_value(attribute, value)
    end
  end
  
  ##############################################################################
  # attr_byte helpers
  ##############################################################################

  # Official Definitions for kilobyte and kibibyte quantity prefixes
  KB =1000; MB =KB **2; GB= KB **3; TB =KB **4; PB =KB **5; EB =KB **6; ZB =KB **7; YB =KB **8
  KiB=1024; MiB=KiB**2; GiB=KiB**3; TiB=KiB**4; PiB=KiB**5; EiB=KiB**6; ZiB=KiB**7; YiB=KiB**8
  DECIMAL_PREFIXES = {:B=>1, :KB=>KB, :MB=>MB, :GB=>GB, :TB=>TB, :PB=>PB, :EB=>EB, :ZB=>ZB, :TB=>YB}
  BINARY_PREFIXES = {:B=>1, :KiB=>KiB, :MiB=>MiB, :GiB=>GiB, :TiB=>TiB, :PiB=>PiB, :EiB=>EiB, :ZiB=>ZiB, :TiB=>YiB}

  # Returns a hash of prefix names to decimal quantities for the given setting
  def self.byte_prefixes(kb_size=0)
    case kb_size
    when 1000, :decimal, :si then DECIMAL_PREFIXES
    when :old, :jedec, 1024 then {:KB=>KiB, :MB=>MiB, :GB=>GiB, :TB=>TiB, :PB=>PiB, :EB=>EiB, :ZB=>ZiB, :TB=>YiB}
    when :new, :iec then BINARY_PREFIXES
    else DECIMAL_PREFIXES.merge(BINARY_PREFIXES) # Both? What's the least surprise?
    end
  end
  
  # Takes a number of bytes and an optional :unit argument and :precision option, returns a formatted string of units
  def self.format_bytes(v, *args)
    opt = EasyAttributes.pop_options(args, :precision=>3)
    prefixes = EasyAttributes.byte_prefixes(opt[:kb_size]||EasyAttributes::Config.kb_size||0)
    if args.size > 0 && args.first.is_a?(Symbol)
      (unit, precision) = args
      v = "%.#{precision||opt[:precision]}f" % (1.0 * v / (prefixes[unit]||1))
      return "#{v} #{unit}"
    else
      precision = args.shift || opt[:precision]
      prefixes.sort{|a,b| a[1]<=>b[1]}.reverse.each do |pv|
        next if pv[1] > v
        v = "%f.10f" % (1.0 * v / pv[1])
        v = v[0,precision+1] if v =~ /^(\d)+\.(\d+)/ && v.size > (precision+1)
        v.gsub!(/\.0*$/, '')
        return "#{v} #{pv[0]}"
      end
    end
    v.to_s
  end
  
  # Takes a string of "number units" or Array of [number, :units] and returns the number of bytes represented.
  def self.parse_bytes(v, *args)
    opt = EasyAttributes.pop_options(args, :precision=>3)
    # Handle v= [100, :KB]
    if v.is_a?(Array)
      bytes = v.shift
      v = "#{bytes} #{v.shift}"
    else
      bytes = v.to_f
    end
    
	  if v.downcase =~ /^\s*(?:[\d\.]+)\s*([kmgtpezy]i?b)/i
	    units = ($1.size==2 ? $1.upcase : $1[0,1].upcase+$1[1,1]+$1[2,1].upcase).to_sym
      prefixes = EasyAttributes.byte_prefixes(opt[:kb_size]||EasyAttributes::Config.kb_size||0)
	    bytes *= prefixes[units] if prefixes.has_key?(units)
	    #puts "v=#{v} b=#{bytes} u=#{units} #{units.class} bp=#{prefixes[units]} kb=#{opt[:kb_size]} P=#{prefixes.inspect}"
	  end
	  (bytes*100).to_i/100
  end
  
  ###########################################################################
  # EasyAttributes Fixed-Precision as Integer Helpers
  ###########################################################################
  
  # Returns the money string of the given integer value. Uses relevant options from #easy_money
  def self.integer_to_money(value, *args)
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
    value = self.format_money( value, pattern, opt)
    value = opt[:unit]+value if opt[:unit]
    value.gsub!(/\./,opt[:separator]) if opt[:separator]
    if opt[:delimiter] && (m = value.match(/^(\D*)(\d+)(.*)/))
      # Adapted From Rails' ActionView::Helpers::NumberHelper
      n = m[2].gsub(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1#{opt[:delimiter]}")
      value=m[1]+n+m[3]
    end
    value
  end

  def self.integer_to_float(value, *args)
    opt = args.last.is_a?(Hash) ? args.pop : {}
    return (opt[:blank]||nil) if value.nil?
    value = 1.0 * value / (10**(opt[:precision]||2)) 
  end

  # Returns the integer of the given money string. Uses relevant options from #easy_money
  def self.money_to_integer(value, *args)
    opt = args.last.is_a?(Hash) ? args.pop : {}
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
  def self.float_to_integer(value, *args)
    opt = args.last.is_a?(Hash) ? args.pop : {}
    return (opt[:blank]||nil) if value.nil?
    value = (value.to_f*(10**((opt[:precision]||2)+1))).to_i/10 # helps rounding 4.56 -> 455 ouch!
  end
  
  # Replacing the sprintf function to deal with money as float. "... %[flags]m ..."
  def self.format_money(value, pattern="%.2m", *args)
    opt = args.last.is_a?(Hash) ? args.pop : {}
    sign = value < 0 ? -1 : 1
    dollars, cents = value.abs.divmod( 10 ** (opt[:precision]||2))
    dollars *= sign
    parts = pattern.match(/^(.*)%([-\. \d+0]*)[fm](.*)/)
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
  
  end
end
