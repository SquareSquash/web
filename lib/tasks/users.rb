# Copyright 2014 Square Inc.
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

require 'highline/import'

namespace :users do

	task create: :environment do  |t, args|

	 	user = get_user_data

		until user.valid?
			say("Unable to create user:")
			user.errors.full_messages.each do |err|
				say("<%= color('#{err}', :red) %>")
				user = get_user_data(user)
			end
		end

		user.create
	end

	def get_user_data(user_data = User.new)
		User.new do |user|
			user.username 	= ask("username: ")  	{ |q| q.default = user_data.username } 
			user.email_address = ask("email: ")  	{ |q| q.default = user_data.email_address }
			user.first_name = ask("first name: ") { |q| q.default = user_data.first_name }
			user.last_name 	= ask("last name: ")  { |q| q.default = user_data.last_name }

			until user.password == user.password_confirmation && user.password.present?
				say("<%= color(\"Passwords don't match. Try Again\", :red) %>")  if user.password.present?
				user.password = ask("password: ") { |q| q.echo = false }
				user.password_confirmation = ask("password confirmation: ") { |q| q.echo = false }
			end

		end
	end

end
