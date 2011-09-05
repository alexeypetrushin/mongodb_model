module Mongo::Model::Conversion
  def to_json *args, &block
    to_rson(*args, &block).to_json
  end

  def to_xml *args, &block
    to_rson(*args, &block).to_xml
  end

  def to_rson options = {}
    if profile = options[:profile]
      raise "no other optins are allowed when using :profile option!" if options.size > 1
      profile_options = self.class.profiles[profile] || raise("profile :#{profile} not defined for #{self.class}!")
      to_rson profile_options.merge(_profile: profile)
    else
      options.validate_options! :only, :except, :methods, :_profile
      child_options = options[:_profile] ? {profile: options[:_profile]} : {}

      instance_variables = Mongo::Object.instance_variables(self)

      if only = options[:only]
        instance_variables &= Array(only).collect{|n| :"@#{n}"}
      elsif except = options[:except]
        instance_variables -= Array(except).collect{|n| :"@#{n}"}
      end

      result = {}
      instance_variables.each do |iv_name|
        value = instance_variable_get iv_name
        value = Mongo::Object.convert value, :to_rson, child_options
        result[iv_name[1.. -1]] = value
      end

      methods = options[:methods] ? Array(options[:methods]) : []

      methods.each do |method|
        value = send method
        value = Mongo::Object.convert value, :to_rson, child_options
        result[method.to_s] = value
      end

      result
    end
  end

  module ClassMethods
    inheritable_accessor :profiles, {}
    def profile name, options = {}
      profiles[name] = options
    end
  end
end