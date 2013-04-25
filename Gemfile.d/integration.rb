conditionally('jira.disabled', false, nil) do
  gem 'jira-ruby', require: 'jira'
end
