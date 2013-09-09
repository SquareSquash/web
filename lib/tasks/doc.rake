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

if Rails.env.development?
  require 'yard'

  # bring sexy back (sexy == tables)
  module YARD::Templates::Helpers::HtmlHelper
    def html_markup_markdown(text)
      markup_class(:markdown).new(text, :gh_blockcode, :fenced_code, :autolink, :tables, :no_intraemphasis).to_html
    end
  end

  YARD::Rake::YardocTask.new do |doc|
    doc.options << '-m' << 'markdown' << '-M' << 'redcarpet'
    doc.options << '--protected' << '--no-private'
    doc.options << '-r' << 'README.md'
    doc.options << '-o' << 'doc/app'
    doc.options << '--title' << "Squash Documentation"

    doc.files = %w( app/**/*.rb lib/**/*.rb - doc/*.md )
  end
end

desc "Generate fdoc documentation to doc/fdoc-html"
task :fdoc do
  system 'fdoc_to_html', 'doc/fdoc', 'doc/fdoc-html'
end
