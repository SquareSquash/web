# Ugh. The sourcemap gem defines a module called SourceMap, which shares the name
# of one of our models. So we have to rename it before we load our model.
if ::SourceMap.kind_of?(Module)
  ::GemSourceMap = ::SourceMap
  Object.send :remove_const, :SourceMap
elsif ::SourceMap.kind_of?(Class)
  raise "SourceMap (the model) defined prior to SourceMap (the module) -- see application.rb"
else
  raise "SourceMap must be defined -- see application.rb"
end

# and redefine the methods that use the other SourceMap class

# @private
class Sprockets::Asset
  def sourcemap
    relative_path = if pathname.to_s.include?(Rails.root.to_s)
                      pathname.relative_path_from(Rails.root)
                    else
                      pathname
                    end.to_s
    # any extensions after the ".js" can be removed, because they will have
    # already been processed
    relative_path.gsub! /(?<=\.js)\..*$/, ''
    resource_path = [Rails.application.config.assets.prefix, logical_path].join('/')

    mappings = Array.new
    to_s.lines.each_with_index do |_, index|
      offset = GemSourceMap::Offset.new(index, 0)
      mappings << GemSourceMap::Mapping.new(relative_path, offset, offset)
    end
    GemSourceMap::Map.new(mappings, resource_path)
  end
end

# @private
class Sprockets::BundledAsset < Sprockets::Asset
  def sourcemap
    to_a.inject(GemSourceMap::Map.new) do |map, asset|
      map + asset.sourcemap
    end
  end
end
