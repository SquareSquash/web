FactoryGirl.define do
  factory :blame do
    repository_hash { random_sha }
    revision { random_sha }
    file "some/file.rb"
    line 123
    blamed_revision { random_sha }
  end
end
