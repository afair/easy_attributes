# Mixes in attr_* definitions into ruby classes for using symbolic names as values, money, and bytes
module EasyAttributes
  
  def self.included(base) #:nodoc:
    base.extend( ClassMethods )
  end
  
  # Configuration class for EasyAttributes, set at load time.
  class Config
    @@orm = :attr # :attr, :active_model
    @@attributes = {}
    @@values = {}
    @@kb_size=:iec
    
    # Values: :old, :jedec, or 1024 uses KB=1024
    #         :new, :iec            uses KiB=1024, no KB
    #         1000, :decimal        uses only KB (1000) (other values mix KB and KiB units)
    def self.kb_size=(b)
      @@kb_size = b
    end
    
    # Returns the kb_size setting
    def self.kb_size
      @@kb_size
    end
    
    # Set the ORM or attribute manager, currently to :attr (attr_accessor) or :active_model
    def self.orm=(o)
      @@orm = o
    end
    
    # Returns the ORM setting
    def self.orm
      @@orm
    end

    # Defines a symbol name to a hash of :name=>value
    def self.define(name, hash)
      @@attributes[name] = hash
    end
    
    # Returns the symbol table
    def self.attributes
      @@attributes
    end
    
    # Loads a tab-delimted filename into the symbol table in format: 
    # attribute value role symbolic_name short_description long_description (useful for "<option>" data)
    # If a block is given, it should parse a file line and return an array of 
    # [attribute, value, role*, name, short*, long_description*], *denotes not required, but placeholder required
    def self.load(filename)
      File.open(filename).each do |r|
        next unless r =~ /^\w/
        (col, val, priv, symbol, word, desc) = block_given? ? yield(r) : r.split(/\t/)
        next if desc.nil? || desc.empty? || symbol.empty? || word.empty? || symbol.nil?
        col = col.to_sym
        @@values[col] = {:sym=>{}, :val=>{}, :rec=>{}} unless @@values.has_key?(col)
        @@values[col][:sym][symbol.to_sym] = val.to_i
        @@values[col][:val][val] = symbol.to_sym
        @@values[col][:rec][symbol.to_sym] = {:word=>word, :description=>desc, :value=>val.to_i}
        @@attributes[col.to_s] ||= {}
        @@attributes[col.to_s][symbol.to_sym] = val.to_i
      end
    end
  end
  
  module ClassMethods
    # Defines an attribute as a sequence of names. :name1=>1, :name2=>2, etc.
    # attr_sequence :attr, :name, ... :start=>n, :step=>:n
    def attr_sequence(attribute, *names)
      opt = EasyAttributes.pop_options(names)
      values = {}
      names.inject(opt[:start]||1) { |seq, n| values[n]=seq; seq+=(opt[:step]||1)}
      attr_values( attribute, values, opt)
    end
    
    # Defines an attribute as a hash like {:key=>value,...} where key names are used interchangably with values
    def attr_values(attribute, *args)
      opt = args.size > 1 ? args.pop : {}
      hash = args.first
      
      # Use :like=>colname to copy from another definition (ClassName#attribute) or from the loaded table columns
      if opt[:like]
        hash = EasyAttributes::Config.attributes[opt[:like]]
      end
      
      name = "#{self.name}##{attribute}"
      EasyAttributes.add_definition( name, hash)
      code = ''
      if EasyAttributes::Config.orm == :active_model
        validates_inclusion_of attribute, :in=>hash.values
        # Add named_scope (scope) for each value
        hash.each { |k,v| code += "named_scope :#{k}, :conditions=>{:#{attribute}=>#{v.inspect}}\n" }
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
          EasyAttributes::Config.attributes["#{name}"]
        end
        def #{attribute}_is?(*args)
          EasyAttributes.value_is?("#{name}", attribute, *args)
        end
      )
      #puts code
      class_eval code
    end
    
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
      args.include? EasyAttributes.sym_for_value(v)
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
  
  ##############################################################################
  # attr_money helpers
  ##############################################################################
  
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