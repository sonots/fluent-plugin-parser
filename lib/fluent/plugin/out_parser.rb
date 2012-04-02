class Fluent::ParserOutput < Fluent::Output
  Fluent::Plugin.register_output('parser', self)

  config_param :tag, :string, :default => nil
  config_param :remove_prefix, :string, :default => nil
  config_param :add_prefix, :string, :default => nil
  config_param :key_name, :string
  config_param :reserve_data, :bool, :default => false

  def initialize
    super
    require 'time'
  end

  def configure(conf)
    super

    if not @tag and not @remove_prefix and not @add_prefix
      raise Fluent::ConfigError, "missing both of remove_prefix and add_prefix"
    end
    if @tag and (@remove_prefix or @add_prefix)
      raise Fluent::ConfigError, "both of tag and remove_prefix/add_prefix must not be specified"
    end
    if @remove_prefix
      @removed_prefix_string = @remove_prefix + '.'
      @removed_length = @removed_prefix_string.length
    end
    if @add_prefix
      @added_prefix_string = @add_prefix + '.'
    end

    @parser = Fluent::TextParser.new
    @parser.configure(conf)

    m = if @parser.regexp.named_captures['time']
          method(:parse_with_time)
        else
          method(:parse_without_time)
        end
    (class << self; self; end).module_eval do
      define_method(:parse, m)
    end
  end

  def parse_with_time(value)
    @parser.parse(value)
  end

  def parse_without_time(value)
    t,r = @parser.parse(value)
    return [nil, r]
  end

  def emit(tag, es, chain)
    tag = if @tag
            @tag
          else
            if @remove_prefix and
                ( (tag.start_with?(@removed_prefix_string) and tag.length > @removed_length) or tag == @remove_prefix)
              tag = tag[@removed_length..-1]
            end 
            if @add_prefix 
              tag = if tag and tag.length > 0
                      @added_prefix_string + tag
                    else
                      @add_prefix
                    end
            end
            tag
          end
    if @reserve_data
      es.each {|time,record|
        value = record[@key_name]
        t,values = if value
                     parse(value)
                   else
                     [nil, {}]
                   end
        t ||= time
        record.update(values)
        Fluent::Engine.emit(tag, t, record)
      }
    else
      es.each {|time,record|
        value = record[@key_name]
        t,values = if value
                     parse(value)
                   else
                     [nil, {}]
                   end
        t ||= time
        Fluent::Engine.emit(tag, t, values)
      }
    end
    chain.next
  end
end