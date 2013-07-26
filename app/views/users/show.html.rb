# encoding: utf-8

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

require Rails.root.join('app', 'views', 'layouts', 'application.html.rb')

module Views
  # @private
  module Users
    # @private
    class Show < Views::Layouts::Application
      needs :user

      protected

      def page_title() @user.name end

      def body_content
        full_width_section do
          h1 do
            image_tag @user.gravatar
            text @user.name
          end

          user_info
        end
      end

      private

      def user_info
        dl do
          dt "Username"
          dd @user.username
          dt "Joined"
          dd l(@user.created_at, format: :short_date)
          dt "Projects"
          dd @user.memberships.count
          dt "Projects Owned"
          dd @user.owned_projects.count
        end
      end
    end
  end
end
