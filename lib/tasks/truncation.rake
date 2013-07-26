# Copyright 2013 Square Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

namespace :truncate do
  desc "Remove metadata from occurrences to free DB space. Specify AGE=n (days)"
  task occurrences: :environment do
    age = nil
    begin
      age = Integer(ENV['AGE'].presence || 30)
    rescue ArgumentError
      $stderr.puts <<-EOF
Specify AGE=n, where `n` is the number of days old an occurrence must be to be
truncated (default 30).
      EOF
      exit 1
    end

    Occurrence.truncate! Occurrence.where('occurred_at < ?', age.days.ago)
  end

  desc "Truncate all truncatable records"
  task all: :occurrences
end
