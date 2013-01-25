# encoding: utf-8

# Copyright 2012 Square Inc.
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

require Rails.root.join('app', 'views', 'projects', 'show.html.rb')

module Views
  module Projects
    # @private
    class Edit < Views::Projects::Show
      include Accordion

      def page_title() "Edit #{@project.name}" end
      def breadcrumbs() [@project, "Configuration"] end

      private

      def environments_grid
        api_key

        h3 do
          span "3", class: 'step-number'
          text "Configure your project settings."
        end
        if [:admin, :owner].include?(current_user.role(@project))
          configuration
        else
          p "You must be a project owner or administrator to configure project settings."
        end
      end

      def api_key
        h3 do
          span "1", class: 'step-number'
          text "Modify your code to use Squash."
        end

        p do
          text "Learn "
          a "how to add Squash to your project", href: '#configure-project', rel: 'modal'
          text ". Your API key is "
          code @project.api_key
          text "."
        end
        p do
          button "Regenerate your API key",
                 href:              rekey_project_url(@project),
                 :'data-method' =>  'put',
                 :'data-confirm' => "This will break any existing Squash client integrations. Continue?"
        end if [:owner, :admin].include?(current_user.role(@project))

        h3 do
          span "2", class: 'step-number'
          text "Make sure that your Git repository is accessible to Squash."
        end

        configure_project_modal
      end

      def configure_project_modal
        div(class: 'modal', id: 'configure-project', style: 'display: none') do
          a "×", class: 'close'
          h1 "Configure #{@project.name} to use Squash"
          div(class: 'modal-body') do
            accordion('configure-clients') do |accordion|
              accordion.accordion_item('ruby-on-rails', "Ruby on Rails") { ruby_on_rails }
              accordion.accordion_item('ruby', "Pure Ruby") { pure_ruby }
              accordion.accordion_item('ios', "Cocoa + Objective-C (iOS)") { cocoa_ios }
              accordion.accordion_item('osx', "Cocoa + Objective-C (Mac OS X)") { cocoa_osx }
              accordion.accordion_item('javascript', "JavaScript") { javascript_client }
              accordion.accordion_item('java', "Java (Generic)") { java }
            end
          end
        end
      end

      def ruby_on_rails
        p do
          text "Add the "
          strong "squash_rails"
          text " gem to your Gemfile, then configure Squash like so:"
        end
        pre <<-RUBY, class: 'brush: ruby; light: true'
Squash::Ruby.configure :api_host => '#{request.protocol + request.host_with_port}',
                       :api_key => '#{@project.api_key}'
        RUBY

        p do
          text "Enable automatic exception notification as part of the request process by extending your "
          code "ApplicationController"
          text ":"
        end
        pre <<-RUBY.chomp, class: 'brush: ruby; light: true'
class ApplicationController < ActionController::Base
  include Squash::Ruby::ControllerMethods
  enable_squash_client
end
        RUBY

        p do
          text "See the "
          a "Pure Ruby", rel: 'accordion', href: '#ruby'
          text " section for more information."
        end
      end

      def pure_ruby
        p do
          text "Add the "
          strong "squash_ruby"
          text " gem to your Gemfile, then configure Squash like so:"
        end
        pre <<-RUBY, class: 'brush: ruby; light: true'
Squash::Ruby.configure :api_host => '#{request.protocol + request.host_with_port}',
                       :api_key => '#{@project.api_key}',
                       :environment => 'production'
        RUBY

        p do
          text "Surround your code with a "
          code 'begin'
          text '/'
          code 'rescue'
          text " statement, and call "
          code 'Squash::Ruby.notify'
          text " in the rescue block:"

          pre <<-RUBY.chomp, class: 'brush: ruby; light: true'
begin
  your_code_here
rescue Object => error
  Squash::Ruby.notify error
  raise # for normal Ruby exception handling
end
          RUBY
        end
      end

      def cocoa_ios
        p do
          text "Download and compile the "
          a "Squash Cocoa client library", href: 'https://github.com/SquareSquash/cocoa'
          text ", and add the compiled library and SquashCocoa.h files to your project. Add the library to your Link Binary With Libraries build phase, "
          code '#import "SquashCocoa.h"'
          text ", then configure Squash like so:"
        end

        cocoa_common
      end

      def cocoa_osx
        p do
          text "Download and compile the "
          a "Squash Cocoa client framework", href: 'https://github.com/SquareSquash/cocoa'
          text ", and add the compiled framework to your project. Add the framework to your Link Binary With Libraries build phase, "
          code '#import <SquashCocoa/SquashCocoa.h>'
          text ", then configure Squash like so:"
        end

        cocoa_common
      end

      def cocoa_common
        pre <<-OBJC, class: 'brush: obj-c; light: true'
- (BOOL) application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [SquashCocoa sharedClient].APIHost = @"#{request.protocol + request.host_with_port}";
    [SquashCocoa sharedClient].APIKey = @"#{@project.api_key}";
    [SquashCocoa sharedClient].environment = @"production";
    [SquashCocoa sharedClient].revision = @"GIT_REVISION_OF_RELEASED_PRODUCT";
    [[SquashCocoa sharedClient] reportErrors];
    [[SquashCocoa sharedClient] hook];
    return YES;
}
        OBJC

        p do
          text "To symbolicate your exceptions, download the "
          strong "squash_ios_symbolicator"
          text " gem. This gem installs a "
          code "symbolicator"
          text " binary; add a Run Script phase to your project’s Archive scheme that executes that binary."
        end

        p do
          text "To notify Squash of releases (public or internal), use the "
          code "squash_release"
          text " binary installed by the same gem. Add a Run Script phase to your project's Archive scheme that executes the binary."
        end

        p "More information is available in the README for SquashCocoa."
      end

      def javascript_client
        p do
          text "Download the "
          a "Squash JavaScript client library", href: 'https://github.com/SquareSquash/javascript'
          text ". You can install it as a Rails engine, for Rails projects, or you can compile and minify the source and install it manually."
        end

        h5 "As a Rails engine"

        p do
          text "Add the "
          code "squash_javascript"
          text " gem to your Gemfile, then add the asset to your "
          code "application.js"
          text " manifest:"
        end
        pre <<-SH, class: 'brush: js, light: true'
//= require squash_client
        SH

        h5 "As a JavaScript asset"

        p do
          text "Compile and minify the CoffeeScript source by running "
          code "rake minify"
          text ", then copy the "
          code "vendor/assets/javascript/squash_client.min.js"
          text " file into your project, and include it in your layout."
        end

        h5 "Configuring"

        p "Configure Squash in a JavaScript file that is run before any errors can be thrown:"

        pre <<-SH, class: 'brush: js, light: true'
        Squash::Ruby.instance().configure({APIHost: '#{request.protocol + request.host_with_port}',
                                           APIKey: '#{@project.api_key}',
                                           environment: 'production',
                                           revision: 'GIT_REVISION_OF_DEPLOY'})
        SH

        h5 "Source-mapping"

        p do
          text "If your toolchain is capable of generating source maps (Clojure is), you can upload those source maps to Squash to un-minify your backtraces, using the "
          code "upload_source_map"
          text " binary (included as part of the gem). An example command that could be added to your deploy script:"
          pre <<-SH, class: 'brush: shell, light: true'
/path/to/upload_source_map #{@project.api_key} production artifacts/mapping.json https://your.application/assets/minified.js
          SH
        end
      end
      
      def java
        p do
          text "Download the "
          a "Squash Java client library", href: 'https://github.com/SquareSquash/java'
          text ", and follow the instructions in the README.md file."
        end

        p do
          text "To deobfuscate and improve your exception backtraces, download the "
          strong "squash_java_deobfuscator"
          text " gem. This gem installs a "
          code "deobfuscate"
          text " binary; call it in your build-and-release or deploy script."
        end

        p do
          text "To notify Squash of releases (public or internal), use the "
          code "squash_release"
          text " binary installed by the same gem."
        end
      end

      def configuration
        form_for(@project, html: {class: 'labeled'}) do |f|
          fieldset do
            h5 "Application and library paths"

            f.label :filter_paths_string
            f.text_area :filter_paths_string, rows: 5, cols: ''
            p "List paths that are library, not application code, relative to your project root, one per line (or just paths to files you want excluded from blame). These can be whole paths or prefixes.", class: 'help-block'

            p(class: 'field-group') do
              label "Pre-fab paths: ", for: 'prefab'
              select(id: 'prefab', name: 'prefab') do
                option "", selected: 'selected'
                option "Ruby on Rails", value: 'rails'
              end
              text ' '
              button "Insert", id: 'insert-prefab', class: 'small'
            end

            f.label :whitelist_paths_string
            f.text_area :whitelist_paths_string, rows: 5, cols: ''
            p(class: 'help-block') do
              text "If you happen to have any files or paths within your filter paths (above) that "
              em "are"
              text " application code, you can include them here, and they will be re-whitelisted."
            end
          end

          fieldset do
            h5 "Emails"

            f.label :sender
            f.email_field :sender, placeholder: NotificationMailer.default[:from]
            p "Emails sent by Squash will appear to come from this address.", class: 'help-block'

            f.label :critical_mailing_list
            f.email_field :critical_mailing_list
            p "Unresolved bugs that occur frequently will be reported to this address. Most engineers should be on this mailing list.", class: 'help-block'

            f.label :all_mailing_list
            f.email_field :all_mailing_list
            p "All new bugs will be reported to this address. Few engineers should be on this mailing list.", class: 'help-block'

            f.label :critical_threshold, required: true
            f.number_field :critical_threshold, min: 2
            p "The number of times an exception has to occur before it is sent to the critical mailing list.", class: 'help-block'

            f.label :locale
            f.select :locale, I18n.available_locales.map(&:to_s), required: true

            f.label(:sends_emails_outside_team, class: 'checkbox-label') do
              f.check_box :sends_emails_outside_team
              text ::Project.human_attribute_name(:sends_emails_outside_team)
            end
            p "If unchecked, people must be added as members of this project before they will receive exception alerts.", class: 'help-block'

            f.label :trusted_email_domain
            f.text_field :trusted_email_domain, placeholder: Squash::Configuration.mailer.domain
            p "If the previous checkbox is checked, only email addresses with this domain will receive exception alerts. If blank, all email addresses will receive alerts.", class: 'help-block'
          end

          fieldset do
            h5 "Source control"

            f.label :repository_url
            f.text_field :repository_url, required: true
            p "If you change this, you might also want to change…", class: 'help-block'

            f.label :commit_url_format
            f.text_field :commit_url_format
            p(class: 'help-block') do
              text "This is the template Squash uses to generate links to web pages with information about a commit in your project. Type "
              kbd "%{commit}"
              text " where you want the commit’s ID to appear."
            end
          end

          fieldset do
            h5 "PagerDuty integration"

            p "Squash can create a PagerDuty incident for a bug once it’s reached its critical threshold (see above). When the bug is assigned, the incident will automatically be acknowledged. The incident will also be resolved automatically when the bug is resolved."

            f.label :pagerduty_service_key
            f.text_field :pagerduty_service_key

            f.label(:pagerduty_enabled, class: 'checkbox-label') do
              f.check_box :pagerduty_enabled
              text ::Project.human_attribute_name(:pagerduty_enabled)
            end
            p "If you uncheck this, PagerDuty will not be notified of any new occurrences. Acknowledgements and resolutions of existing incidents will still be sent.", class: 'help-block'
          end unless Squash::Configuration.pagerduty.disabled

          div(class: 'form-actions') { f.submit class: 'default' }
        end
      end
    end
  end
end

