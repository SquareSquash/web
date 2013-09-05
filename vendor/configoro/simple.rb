# A stripped-down version of Configoro that works without any gems.

require 'erb'
require 'yaml'

load File.join(File.dirname(__FILE__), 'base.rb')

# @private
class Configoro::HashWithIndifferentAccess < ::Hash
  def deep_merge(other_hash)
    dup.deep_merge!(other_hash)
  end

  def deep_merge!(other_hash)
    other_hash.each_pair do |k, v|
      tv      = self[k]
      self[k] = tv.is_a?(Hash) && v.is_a?(Hash) ? tv.deep_merge(v) : v
    end
    self
  end
end

load File.join(File.dirname(__FILE__), 'hash.rb')
