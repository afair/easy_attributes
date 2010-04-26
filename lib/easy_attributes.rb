# require 'rubygems'
# require 'easy_money'

module EasyAttributes
  
  def self.included(base) #:nodoc:
    base.extend( ClassMethods )
    EasyAttributes::Config
  end
  
  # Configuration class for EasyAttributes, set at load time.
  class Config
    @@orm = nil
    @@attribs = {}
    @@values = {}
    
    def self.orm=(o)
      @@orm = o
    end
    
    def self.orm; @@orm; end

    def self.define(name, hash)
      @@attribs[name] = hash
    end
    
    def self.attribs; @@attribs; end
    
    def self.load(filename)
      File.open(filename).each do |r|
        next unless r =~ /^\w/
        (col, val, priv, symbol, word, desc) = r.split(/\t/)
        next if desc.nil? || desc.empty? || symbol.empty? || word.empty? || symbol.nil?
        col = col.to_sym
        @@values[col] = {:sym=>{}, :val=>{}, :rec=>{}} unless @@values.has_key?(col)
        @@values[col][:sym][symbol.to_sym] = val.to_i
        @@values[col][:val][val] = symbol.to_sym
        @@values[col][:rec][symbol.to_sym] = {:word=>word, :description=>desc, :value=>val.to_i}
        @@attribs[col.to_s] ||= {}
        @@attribs[col.to_s][symbol.to_sym] = val.to_i
      end
    end
  end
  
  module ClassMethods
    # Defines an attribute as a sequence of names. :name1=>1, :name2=>2, etc.
    # attr_sequence :attr, :name, ... :start=>n, :step=>:n
    def attr_sequence(method, *names)
      opt = EasyAttributes.pop_hash(names)
      values = {}
      names.inject(opt[:start]||1) { |seq, n| values[n]=seq; seq+=(opt[:step]||1)}
      attr_values( method, values, opt)
    end
    
    # Defines an attribute as a hash like {:key=>value,...} where key names are used interchangably with values
    def attr_values(method, *args)
      opt = args.size > 1 ? args.pop : {}
      hash = args.first
      
      # Use :like=>colname to copy from another definition (ClassName#method) or from the loaded table columns
      if opt[:like]
        hash = EasyAttributes::Config.attribs[opt[:like]]
      end
      
      name = "#{self.name}##{method}"
      EasyAttributes.add_definition( name, hash)
      code = ''
      #code = hash.map {|k,v| "#{method.to_s.upcase}_#{k.to_s.upcase}=#{v.inspect}\n"}.join()
      if EasyAttributes::Config.orm == :active_model
        validates_inclusion_of method, :in=>hash.values
        code += %Q(
          def #{method}
            self.attributes[:#{method}]
          end
          def #{method}=(v)
            v = EasyAttributes.value_for_sym("#{name}", v) if v.is_a?(Symbol)
            self.write_attribute(:#{method}, v)
          end
        )
      else
        code += %Q(
          def #{method}
            @#{method}
          end
          def #{method}=(v)
            v = EasyAttributes.value_for_sym("#{name}", v) if v.is_a?(Symbol)
            @#{method} = v
          end
        )
      end
      code += %Q(
        def #{method}_sym
          EasyAttributes.sym_for_value("#{name}", #{method})
        end
        def self.#{method}_values
          EasyAttributes::Config.attribs["#{name}"]
        end
        def #{method}_is?(*args)
          EasyAttributes.value_is?("#{name}", method, *args)
        end
      )
      #puts code
      class_eval code
    end
    
    # Creates an alias to the easy_money gem definition
    def attr_money(*args)
      # easy_money *args
    end
  end
  
  def self.pop_hash(*args)
    args.last.is_a?(Hash) ? args.pop : {}
  end
  
  def self.add_definition(method, hash, opt={})
    EasyAttributes::Config.define method, hash
  end
  
  # Returns the defined value for the given symbol and attribute
  def self.value_for_sym(attribute, sym)
    EasyAttributes::Config.attribs[attribute][sym]
  end
  
  # Returns the defined symbol for the given value on the attribute
  def self.sym_for_value(attribute, value)
    EasyAttributes::Config.attribs[attribute].each {|k,v| return k if v==value}
  end
  
  def self.value_is?(method, value, *args)
    case args.first
    when :between then
      value >= EasyAttributes::Config.attribs[method][args[1]] && value <= EasyAttributes::Config.attribs[method][args[2]]
    when :gt, :greater_than then
      value > EasyAttributes::Config.attribs[method][args[1]]
    when :ge, :greater_than_or_equal_to then
      value >= EasyAttributes::Config.attribs[method][args[1]]
    when :lt, :less_than then
      value < EasyAttributes::Config.attribs[method][args[1]]
    when :le, :less_than_or_equal_to then
      value <= EasyAttributes::Config.attribs[method][args[1]]
    #when :not, :not_in
    #  ! args.include? EasyAttributes::Config.attribs[method].keys
    else
      args.include? EasyAttributes.sym_for_value(v)
    end
  end
  
end