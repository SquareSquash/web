paths = Gem.find_files('configoro/simple')
if paths.empty?
  puts "NOTE: Because Configoro is not installed, only required gems will be",
       "installed. Re-run 'bundle' again to install additional gems."
  # not necessary; make conditionally a noop
  def conditionally(*) end
else
  paths.each { |p| require p }

  rails_root = ENV['RAILS_ROOT'] || File.join(File.dirname(__FILE__), '..')
  Configoro.paths << File.join(rails_root, 'config', 'environments')

  def traverse_hash(hsh, *keys)
    if keys.size == 1
      hsh[keys.first]
    else
      traverse_hash hsh[keys.shift], *keys
    end
  end

  def conditionally(configuration_path, *values, &block)
    groups = []
    dev    = Configoro.load_environment('development')
    test   = Configoro.load_environment('test')
    prod   = Configoro.load_environment('production')

    configuration_path = configuration_path.split('.')
    groups << :development if values.include?(traverse_hash(dev,  *configuration_path))
    groups << :test        if values.include?(traverse_hash(test, *configuration_path))
    groups << :production  if values.include?(traverse_hash(prod, *configuration_path))

    groups.each { |g| group g, &block }
  end
end
