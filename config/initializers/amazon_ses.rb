if Rails.env == 'production'
  rails_root = ENV['RAILS_ROOT'] || File.dirname(__FILE__) + '/../..'
  config = YAML.load_file(rails_root.to_s + '/config/amazon_ses.yml')

  ActionMailer::Base.add_delivery_method :ses, AWS::SES::Base,
    :access_key_id      => config[Rails.env].id,
    :secret_access_key  => config[Rails.env].key
end
