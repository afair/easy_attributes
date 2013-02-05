# EasyAttributes: Model Attribute Definition Helpers

The EasyAttributes ruby gem extends ruby classes with an attribute helper
DSL to declare attributes as:

  * Enumerated with symbolic names
  * Maps of symbolic names to internal and stored values
  * Shared between applications and models
  * Byte counts represented in KB, KiB, etc.
  * "Easy money" converting Fixed-point currency (e.g. dollars as cents)
  * Fixed-precision formatting stored as integers (e.g. 4.5 stored as 45)

## Setup

First, install the ``easy_attributes`` gem. For bundler, add this to
your Gemfile:

```ruby
gem 'easy_attributes', '~> 0.2.0'
```

Now, you may want to configure how EasyAttribute behaves. If you are
using Rails, you con do this in
`./config/initializers/easy_attributes.rb`, or somewhere else that
executes this code before your class is loaded.

```ruby
EasyAttributes::Config.orm = :active_model   # will generate some validations, etc.
```

To use the helpers in your model (or really any other class), include
the EasyAttributes module in your class, or you may add this do your
initializer file (above):

```ruby
class ActiveRecord::Base # Load EasyAttributes into all ActiveRecord models:
  include EasyAttributes
end
```

You can specify whatever ORM you are using. EasyAttributes tries to be
agnostic about this. As you can see above, if your configure your ORM
setting to be `:active_model`, you can use it with any ORM that
implements the ActiveModel interface.

If you need to load values from another application, file, database,
etc., you can do this from the initializer file as well. You can load
definitions from a file something like this:

```ruby
File.readlines("/path/to/other-app/values.txt").each do |rec|
  next unless rec =~ /^\w/
  (attribute, val, symbol, description) = rec.split(/\t/)
  defn = EasyAttributes::Definition.find_or_create(attribute)
  defn.add_symbol(symbol, val.to_i, title:description)
end
```

and use the `attr_shared` declaration to import into your model.

## Configurations

These are the available configurations

EasyAttributes::Config.orm =

  * :active_model - Attributes are treated as ActiveModel attributes
  * :attr - Uses ruby attr_accessor style operations

EasyAttributes::Config.kb_size =

  * :new, :iec, 1000 - Uses the new 1000-byte KiB definition (International
Electrotechnical Commission)
  * :old, :jedec, 1024 - Uses the older 1024-byte KB definition (Joint Electron Devices Engineering Council)

## attr_values

The `attr_values` declaration creates helpers to map symbolic names to
the allowed values of the attribute. For example, assume we are working
with a (legacy?) database table with a `status` column of type integer
with maps values to a user status. We declare the status attribute and
code with symbol names instead of numbers.

```ruby
class User < ActiveRecord::Base
  include EasyAttributes
  attr_values :status, signup:1, verified:2, expired:3, disabled:4
end
```

This creates a few helper methods:
 * Class Methods
   * User.status_of(symbol) - Returns matching value for symbol
   * User.status_options() - Returns [[name,value],...] pairs for HTML
options.
 * status_sym - returns a symbol matching the value of status()
 * status_sym=(symbol) - Sets status to the coorresponding value of
`symbol`
 * status_in(*symbols) - Boolean match if symbols.include?(status_sym)
 * status_cmp(symbol) - implements the <=> (`cmp`) method on status
   * Returns -1 if status < User.status_of(symbol)
   * Returns  0 if status == User.status_of(symbol)
   * Returns 1 if status > User.status_of(symbol)

If your orm is set to :active_model, attr_values will set up
```ruby
validates_inclusion_of :status, 
  in: Subscriber.easy_attribute_definition(:status).values.keys
```

Here are some usage examples:

```ruby
user.status                         #=> 1
user.status_sym = :verified         #=> :verified
user.status                         #=> 2
user.status_sym == :verified        #=> true
user.status_in(:expired, :disabled) #=> false
user.status_cmp(:expired)           #=> 1
user.valid?                         #=> true
user.status_sym = :wrong            #=> nil
user.valid?                         #=> false

User.status_of(:expired)            #=> 3
User.status_options                 #=> [["Signup", 1],...]
```

You can use this to generate the HTML <option> elements for a <select>
control for your field:

```ruby
f.input :status, collection:User.status_options
options_for_select(User.status_options, user.status)
```

## attr_enum

The attr_enum declaration provides a different syntax for attr_values,
but the results are the same. It also provides several ways to adjust
the value assignments:

 * start:value - This option will start the first symbol to this value,
defaults to 0.
 * step:value - This is the increment value between symbols, default 1.
 * nil - Using nil in the list will skip that value in assignments
 * fixnum - any integer will start the next symbol at this value
 * The start value can be any object that responds to "next." You can
use `start:"a"` and the values assigned would be ['a', 'b', 'c', ....].

All these are equivalent:
```ruby
attr_enum   :status, :signup, :verified, :expired, :disabled, start:1
attr_enum   :status, 1, :signup, :verified, :expired, :disabled
attr_enum   :status, nil, :signup, :verified, :expired, :disabled
attr_values :status, signup:1, verified:2, expired:3, disabled:4
```

Another example:
```ruby
attr_enum :month, 1, :jan, 5, :apr, :may, nil, :jul, ..., :start=>1, :step=>1
```

## attr_shared

```ruby
attr_shared :status, :my_rule=>:shared_rule
```

## attr_bytes

```ruby
attr_bytes :bandwidth

m.bandwidth_bytes = "1 KB"     #=> 1024
m.bandwidth_bytes              #=> 1024
m2.bandwidth_bytes(:MiB, precision:0) #=> "123 MB"
```

## attr_money, attr_dollars

Adds helper methods to edit money values stored as fixed-precision
integers (defaults to a stored value of 100 as "1.00" dollars).

Created suffix methods 
 * x_money() - returns a string of "dollar" amount: "123.00"
 * x_money=() - Takes a string like "123.00" and sets x to 12300

The _money suffix can be overriden by the method_suffix:"unit" option.

The attr_dollars method defines the money attribute with a "dollars" suffix.

```ruby
attr_money :amount       #=> use amount_money to get/set
                         #=> amount_money(), amount_money=()
addr_dollars :amount     #=> amount_dollars(), amount_dollars=()
attr_money :quatloos, :method_suffix=>'quatloos', :precision=>3,
    :zero=>'even', :nil=>'no bet', :negative=>'%.3f Loss', :unit=>'Q',
    :negative_regex=>/^(-?)(.+\d)\s*Loss/i
                         #=> amount_quatloos(), amount_quatloos=()
```

## attr_fixed

Say you want to store someone's NTRP Tennis level (1.0 to 4.0 by 0.5).

```ruby
attr_fixed :tennis_level, precision:1
```
