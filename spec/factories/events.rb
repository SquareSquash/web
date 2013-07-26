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

FactoryGirl.define do
  factory :event do
    association :user
    bug do |obj|
      membership = FactoryGirl.create(:membership, user: obj.user)
      FactoryGirl.create :bug, environment: FactoryGirl.create(:environment, project: membership.project)
    end

    kind 'open'
    data('status' => 'fixed', 'from' => 'closed', 'revision' => '8f29160c367cc3e73c112e34de0ee48c4c323ff7')
  end

  factory :complex_event, parent: :event do
    kind 'comment'
    data { |obj| {comment_id: FactoryGirl.create(:comment, bug: obj.bug, user: FactoryGirl.create(:user, project: obj.bug.project))} }
  end
end
