# This module handles initialization of the Configoro object, and contains some
# utility methods.

module Configoro

  # Creates the configuration dictionary and stores it under
  # `MyApp::Configuration` (assuming an application named `MyApp`).

  def self.initialize
    namespace.const_set :Configuration, load_environment(Rails.env)
  end

  # The search paths Configoro uses to locate configuration files. By default
  # this list contains one item, `RAILS_ROOT/config/environments`. You can edit
  # this list to add your own search paths. Any such paths should have
  # subdirectories for each environment, and `common`, as expected by Configoro.
  #
  # Be sure to add paths before the Configoro initializer is called (see the
  # example).
  #
  # Paths are processed in the order they appear in this array.
  #
  # @return [Array<String>] An editable array of search paths.
  #
  # @example Adding additional paths (application.rn)
  #   config.before_initialize do
  #     Configoro.paths << '/my/custom/path'
  #   end

  def self.paths
    @paths ||= begin
      paths = []
      paths << "#{Rails.root}/config/environments" if defined?(Rails)
      paths
    end
  end

  # Resets any custom configuration paths set using {.paths}.

  def self.reset_paths
    remove_instance_variable :@paths
  end

  # Loads the configuration for an environment and returns it as a {Hash}. Use
  # this method to access Configoro options outside the context of your Rails
  # app. You will need to configure paths first (see example).
  #
  # @param [String] env The Rails environment.
  # @return [Configoro::Hash] The configuration for that environment.
  #
  # @example Accessing Configoro options outside of Rails
  #   Configoro.paths << "#{rails_root}/config/environments"
  #   Configoro.load_environment(rails_env) #=> { ... }

  def self.load_environment(env)
    config = Configoro::Hash.new
    load_data config, env
    config
  end

  private

  def self.namespace
    Object.const_get Rails.application.class.to_s.split('::').first
  end

  def self.load_data(config, env)
    paths.each do |path|
      Dir.glob("#{path}/common/*.yml").sort.each { |file| config << file }
      Dir.glob("#{path}/#{env}/*.yml").sort.each { |file| config << file }
    end
  end
end
