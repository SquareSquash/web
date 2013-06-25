# Let's make SafeYAML act exactly like YAML by default, to avoid surprising
# behavior.
SafeYAML::OPTIONS[:default_mode]        = :unsafe
SafeYAML::OPTIONS[:deserialize_symbols] = true

# And let's whitelist the things we transmit over YAML
SafeYAML.whitelist! Squash::Javascript::SourceMap, Squash::Java::Namespace
