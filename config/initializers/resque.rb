rails_root = ENV['RAILS_ROOT'] || File.dirname(__FILE__) + '/../..'
rails_env = ENV['RAILS_ENV'] || 'development'

if Squash::Application.config.resque
  Bundler.require(:resque)

  resque_config = YAML.load_file(rails_root.to_s + '/config/resque.yml')
  Resque.redis = resque_config[rails_env]
end
