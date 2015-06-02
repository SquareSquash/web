# encoding: utf-8

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

# @private
module Views
  # @private
  module Layouts
    # @private
    class Application < Erector::Widget
      def content
        rawtext "<!DOCTYPE html>"
        html(lang: 'en') do
          head_portion
          body_portion
        end
      end

      protected

      # Override this method with your web page content.
      def body_content
        raise NotImplementedError
      end

      # Override this method to return `true` if you are using
      # {#tabbed_section}. Sets the proper body background color so as to bleed
      # the tab background color all the way to the bottom.
      def tabbed?() false end

      # Call as part of {#body_content} to generate a full-width
      # (sixteen-column) content area with a white background. Yields to render
      # content.
      def full_width_section(alt=false)
        div(class: "content-container#{alt ? '-alt' : ''}") do
          div(class: 'container') do
            div(class: 'row') { div(class: 'sixteen columns') { yield } }
          end
        end
      end

      # Call as part of {#body_content} to generate a full-width
      # (sixteen-column) content area with a shaded background below a tabbed
      # header portion. The `tabs_proc` should render a `<UL>` with your tab
      # headers, and the `content_proc` should render the tab bodies. See
      # tabs.js.coffee for how to organize it.
      def tabbed_section(tabs_proc, content_proc)
        div(class: 'tab-header-container') do
          div(class: 'container') do
            div(class: 'row') { div(class: 'sixteen columns') { tabs_proc.() } }
          end
        end

        div(class: 'tab-container') do
          div(class: 'container') do
            div(class: 'row') { div(class: 'sixteen columns') { content_proc.() } }
          end
        end
      end

      # Call as part of {#body_content} to generate an inset, shaded
      # twelve-column content area simulating the appearance of a modal. Yields
      # to render content.
      def modal_section
        div(class: 'content-container') do
          div(class: 'container modal-container') do
            div(class: 'row row-modal') do
              div(class: 'two columns') { text! '&nbsp;' }
              div(class: 'twelve columns') { yield }
              div(class: 'two columns') { text! '&nbsp;' }
            end
          end
        end
      end

      # Override this method to customize the title tag.
      def page_title() nil end

      # Override this method with the chain of objects that corresponds to the
      # user's position in the navigational structure. For instance, if the user
      # is viewing a bug within an environment within a Project, you'd want to
      # return `[@project, @environment, @bug]`. This is used to build the
      # breadcrumbs section.
      #
      # @return [Array] The nested objects forming the navigational position of
      #   the current page.
      def breadcrumbs() [] end

      # Override this method to populate a set of at-a-glance numerical stats
      # that will appear alongside the breadcrumbs. This method should returrn
      # an array of arrays. The values of each inner array should be
      #
      # 1. the number to display,
      # 2. a description of what the number represents, in singular, and
      # 3. optionally, the plural form of #2.
      #
      # @return [Array<Array>] The stats to display alongside the breadcrumbs.
      def breadcrumbs_stats()
        []
      end

      ### HELPERS

      # Like link_to, but makes a button. This much simpler version does not
      # wrap it in a form, but instead uses the buttons.js.coffee file to add
      # `<A>` behavior to it.

      def button_to(name, location, overrides={})
        button name, overrides.reverse_merge(href: location)
      end

      private

      def head_portion
        metas
        page_title ?
          title("Squash | #{page_title}") :
          title("Squash: A Squarish exception tool")

        stylesheet_link_tag 'application'
        inline_css
        comment('[if lt IE 9]') { javascript_include_tag 'http://html5shim.googlecode.com/svn/trunk/html5.js' }
        comment('[if lt IE 8]') { javascript_include_tag 'flot/excanvas' }
      end

      def metas
        meta charset: 'utf-8'
        meta name: 'description', content: "A Squarish bug reporting, analytics, and management tool."
        meta name: 'author', content: "Square, Inc."
        meta name: 'viewport', content: 'width=device-width, initial-scale=1.0'
        favicon_link_tag
        csrf_meta_tags
      end

      def body_portion
        body(class: "#{controller_name} #{tabbed? ? 'tabbed' : nil}", id: [controller_name, action_name].join('-')) do
          div(id: 'navbar-container') do
            navbar_small
            navbar_large
          end
          div(id: 'breadcrumbs-container') do
            div(class: 'container') do
              render_breadcrumbs(*breadcrumbs)
              stats = breadcrumbs_stats
              render_breadcrumbs_stats(stats) unless stats.empty?
            end
          end if breadcrumbs.present?

          body_content
          footer_portion

          div id: 'flashes'

          javascript_include_tag 'application'
          inline_javascript
          jquery(                                    "new Flash('alert'  ).text(\"#{escape_javascript flash[:alert]  }\")")     if flash[:alert]
          jquery("$(window).oneTime(250, function() { new Flash('notice' ).text(\"#{escape_javascript flash[:notice] }\"); })") if flash[:notice]
          jquery("$(window).oneTime(500, function() { new Flash('success').text(\"#{escape_javascript flash[:success]}\"); })") if flash[:success]
        end
      end

      def navbar_large
        nav(class: 'container full-size-only') do
          ul do
            li(id: 'logo') do
              link_to(root_url) do
                image_tag 'bug.png'
                text "Squash"
              end
            end
            if logged_in?
              navbar_projects('large')
              navbar_environments('large') if @project
              li(id: 'quicknav-container') { input type: 'search', id: 'quicknav', placeholder: 'Search' }
              li { link_to "My Account", account_url }
              unless third_party_login?
                li { link_to(logout_url) { i class: 'icon-signout'} }
              end
            else
              li(id: 'quicknav-container') { text! '&nbsp;' }
              li { link_to "Log In", login_url }
            end
          end
        end
      end

      def navbar_small
        nav(class: 'container compact-only') do
          ul do
            li(id: 'logo') do
              link_to(root_url) do
                image_tag 'bug.png'
                text "Squash"
              end
            end
            if logged_in?
              li(id: 'quicknav-container') { text! '&nbsp;' }
              li { link_to(logout_url) { i class: 'icon-signout'} }
              li { a class: 'icon-chevron-down', rel: 'dropdown', href: '#expanded-nav' } if logged_in?
            else
              li(id: 'quicknav-container') { text! '&nbsp;' }
              li { link_to(login_url) { i class: 'icon-signin' } }
            end
          end
        end
        nav(class: 'container compact-only', id: 'expanded-nav') do
          ul do
            navbar_projects('small')
            navbar_environments('small') if @project
            li { link_to "My Account", account_url }
          end
        end if logged_in?
      end

      def navbar_projects(suffix)
        li(class: 'with-dropdown') do
          a(rel: 'dropdown', href: "#navbar-projects-#{suffix}") do
            text(@project ? @project.name : "Projects")
            i class: 'icon-chevron-down'
          end

          ul(id: "navbar-projects-#{suffix}", class: 'subnav') do
            if current_user.memberships.count == 0
              # do nothing
            elsif current_user.memberships.count > 10
              current_user.memberships.order('created_at DESC').limit(10).includes(:project).map(&:project).each do |project|
                li { a project.name, href: project_url(project) }
              end
              li { a "More…", href: projects_url }
              li class: 'divider'
            else
              current_user.memberships.order('created_at DESC').includes(:project).map(&:project).each do |project|
                li { a project.name, href: project_url(project) }
              end
              li class: 'divider'
            end
            li { a (current_user.memberships.count == 0 ? "All Projects" : "Other Project"), href: projects_url(anchor: 'find') }
            li do
              form_for current_user.owned_projects.build, url: projects_url(format: 'json'), id: "new_project-#{suffix}" do |f|
                p "New Project"
                f.text_field :name, placeholder: ::Project.human_attribute_name(:name), required: true
                f.text_field :repository_url, placeholder: ::Project.human_attribute_name(:repository_url), required: true
                p(class: 'help-block') do
                  strong "Note:"
                  text " This is the URL you would use with git-clone, not the GitHub web page for the repository."
                end
                f.submit class: 'default'
              end
            end
          end
        end
      end

      def navbar_environments(suffix)
        li(class: 'with-dropdown') do
          a(rel: 'dropdown', href: "#navbar-envs-#{suffix}") do
            text(@environment ? @environment.name : "Environments")
            i class: 'icon-chevron-down'
          end

          ul(id: "navbar-envs-#{suffix}", class: 'subnav') do
            if @project.environments.empty? then
              li { a "No Environments", href: '#', class: 'disabled' }
            else
              li { a @project.default_environment.name, href: project_environment_bugs_url(@project, @project.default_environment) } if @project.default_environment
              @project.environments.order('name ASC').includes(:project).limit(20).each do |environment|
                next if environment == @project.default_environment
                li { a environment.name, href: project_environment_bugs_url(@project, environment) }
              end
              li class: 'divider'
              li { a "View All", href: project_url(@project, show_environments: 'true') }
            end
          end
        end
      end

      def render_breadcrumbs(*crumbs)
        ul(class: 'breadcrumb') do
          0.upto(crumbs.length - 2) do |i|
            li do
              if crumbs[i].kind_of?(String)
                span crumbs[i]
              else
                options = {}
                options[:show_environments] = true if crumbs[i].kind_of?(Project) # hacky hack hack
                name = crumbs[i].kind_of?(Class) ? crumbs[i].model_name.human : crumbs[i].name

                url_path = crumbs[0..i]
                if url_path.last.kind_of?(Environment) # another hacky hack
                  name = url_path.last.name
                  url_path << Bug
                end
                a name, href: polymorphic_url(url_path, options)
              end
            end
            li "/", class: 'divider'
          end if crumbs.length > 1

          li (crumbs.last.kind_of?(String) ? crumbs.last : crumbs.last.name), class: 'active'
        end
      end

      def render_breadcrumbs_stats(stats)
        div(id: 'breadcrumbs-stats') do
          stats.each do |(number, singular, plural)|
            plural ||= singular.pluralize
            div(class: 'shown') do
              strong number_with_delimiter(number)
              span(' ' + (number == 1 ? singular : plural))
            end
          end
        end
      end

      def footer_portion
        footer do
          p { image_tag 'footer.png' }

          p do
            text "Hand-coded in San Francisco by Tim Morgan of "
            a "Square, Inc.", href: 'https://squareup.com'
          end
        end
      end

      def inline_javascript
        file = Rails.root.join('app', self.class.to_s.underscore + '.js')
        script(raw(File.read(file)), type: 'text/javascript') if File.exist?(file)

        file = Rails.root.join('app', self.class.to_s.underscore + '.js.erb')
        script(raw(ERB.new(File.read(file)).result(binding)), type: 'text/javascript') if File.exist?(file)
      end

      def inline_css
        file = Rails.root.join('app', self.class.to_s.underscore + '.css')
        style(raw(File.read(file)), type: 'text/css') if File.exist?(file)

        file = Rails.root.join('app', self.class.to_s.underscore + '.css.erb')
        style(raw(ERB.new(File.read(file)).result(binding)), type: 'text/css') if File.exist?(file)
      end
    end
  end
end
