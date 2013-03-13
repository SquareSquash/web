config_dir = ENV['CONFIG_DIR']

if config_dir && File.directory?(config_dir)
  Dir["#{config_dir}/**/*.yml"].sort.each do |config|
    Squash::Configuration << config
  end
end
