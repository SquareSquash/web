source 'https://rubygems.org'

# Load all files under the Gemfile.d directory.

Dir.glob(File.join(File.dirname(__FILE__), 'Gemfile.d', '*.rb')).sort.each do |file|
  eval File.read(file), binding, file
end
