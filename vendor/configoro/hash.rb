module Configoro
  class Hash < HashWithIndifferentAccess

    # @private
    def initialize(hsh={})
      if hsh.kind_of?(::Hash) then
        super()
        update hsh
      else
        super
      end
    end

    # Deep-merges additional hash entries into this hash.
    #
    # @return [Configoro::Hash] This object.
    # @overload <<(hash)
    #   Adds the entries from another hash.
    #   @param [::Hash] hash The additional keys to add.
    # @overload <<(path)
    #   Adds the entries from a YAML file. The entries will be added under a
    #   sub-hash named after the YAML file's name.
    #   @param [String] path The path to a YAML file ending in ".yml".
    #   @raise [ArgumentError] If the filename does not end in ".yml".

    def <<(hsh_or_path)
      case hsh_or_path
        when String
          raise ArgumentError, "Only files ending in .yml can be added" unless File.extname(hsh_or_path) == '.yml'
          return self unless File.exist?(hsh_or_path)
          data = load_preprocessed_yaml(hsh_or_path)
          deep_merge! File.basename(hsh_or_path, ".yml") => data
        when ::Hash
          deep_merge! hsh_or_path
      end
    end

    alias_method :push, :<<

    # @private
    def dup
      Hash.new(self)
    end

    # Recursively merges this hash with another hash. All nested hashes are forced
    # to be `Configoro::Hash` instances.
    #
    # @param [::Hash] other_hash The hash to merge into this one.
    # @return [Configoro::Hash] This object.

    def deep_merge!(other_hash)
      other_hash.each_pair do |k, v|
        tv      = self[k]
        self[k] = if v.kind_of?(::Hash) then
                    if tv.kind_of?(::Hash) then
                      Configoro::Hash.new(tv).deep_merge!(v)
                    else
                      Configoro::Hash.new(v)
                    end
                  else
                    v
                  end
      end
      self
    end

    # @private
    #
    # To optimize access, we create a getter method every time we encounter a
    # key that exists in the hash. If the key is later deleted, the method will
    # be removed.

    def method_missing(meth, *args)
      if include?(meth.to_s) then
        if args.empty? then
          create_getter meth
        else
          raise ArgumentError, "wrong number of arguments (#{args.size} for 0)"
        end
      elsif meth.to_s =~ /^(.+)\?$/ and include?(root_meth = $1) then
        if args.empty? then
          !!create_getter(root_meth) #TODO duplication of logic
        else
          raise ArgumentError, "wrong number of arguments (#{args.size} for 0)"
        end
      else
        super
      end
    end

    # @private
    def inspect
      "#{to_hash.inspect}:#{self.class.to_s}"
    end

    protected

    def self.new_from_hash_copying_default(hash)
      Configoro::Hash.new(hash).tap do |new_hash|
        new_hash.default = hash.default
      end
    end

    def convert_value(value, options={})
      if value.is_a? ::Hash
        if options[:for] == :to_hash
          value.to_hash
        else
          #value.nested_under_indifferent_access
          self.class.new_from_hash_copying_default(value)
        end
      elsif value.is_a?(Array)
        unless options[:for] == :assignment
          value = value.dup
        end
        value.map! { |e| convert_value(e, options) }
      else
        value
      end
    end

    private

    def create_getter(meth)
      singleton_class.send(:define_method, meth) do
        if include?(meth.to_s) then
          self[meth.to_s]
        else
          remove_getter meth
        end
      end

      singleton_class.send(:define_method, :"#{meth}?") do
        if include?(meth.to_s) then
          !!self[meth.to_s]
        else
          remove_getter meth
        end
      end

      self[meth.to_s]
    end

    def remove_getter(meth)
      if methods.include?(meth.to_sym) then
        instance_eval "undef #{meth.to_sym.inspect}"
      end

      if methods.include?(:"#{meth}?") then
        instance_eval "undef #{:"#{meth}?".inspect}"
      end

      raise NameError, "undefined local variable or method `#{meth}' for #{self.inspect}"
    end

    def load_preprocessed_yaml(path)
      YAML.load(ERB.new(IO.read(path)).result)
    end
  end
end
