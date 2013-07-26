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

# Downloads MySQL message templates from the MySQL documentation website.
# Requires Nokogiri.

require 'nokogiri'
require 'open-uri'
require 'yaml'

yaml_path                 = File.dirname(__FILE__) + '/../data/message_templates.yml'
templates                 = YAML.load_file(yaml_path)
templates['Mysql::Error'] = []

%w( 5.6 5.5 5.1 5.0 ).each do |version|
  page = Nokogiri::HTML(open("http://dev.mysql.com/doc/refman/#{version}/en/error-messages-server.html"))
  page.css('div.itemizedlist>ul>li>p').each do |tag|
    next unless tag.children.all?(&:text?)
    next unless tag.content.strip =~ /^Message: (.+)$/

    message = $1.gsub(/[\s]+/, ' ').strip
    next unless message =~ /%\w+/
    next if message =~ /^%[^\s]+$/

    rx = Regexp.escape(message)
    rx.gsub!('%s', ".*?")
    rx.gsub!('%d', "-?\\d+")
    rx.gsub!('%lu', "\\d+")
    rx.gsub!('%ld', "-?\\d+")
    rx.gsub!('%u', "\\d+")

    output = message.gsub('%s', "[STRING]")
    output.gsub!('%d', "[NUMBER]")
    output.gsub!('%lu', "[NUMBER]")
    output.gsub!('%ld', "[NUMBER]")
    output.gsub!('%u', "[NUMBER]")

    next if templates['Mysql::Error'].any? { |(other_rx, other_output)| other_output == output }
    templates['Mysql::Error'] << [Regexp.compile(rx), output]
  end
end

templates['Mysql::Error'].sort_by! { |(_, msg)| -msg.length }
templates['Mysql2::Error'] = %w( Mysql::Error )

File.open(yaml_path, 'w') { |f| f.puts templates.to_yaml }
