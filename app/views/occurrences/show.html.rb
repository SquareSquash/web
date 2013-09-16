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

require 'rexml/document'
require Rails.root.join('app', 'views', 'layouts', 'application.html.rb')

module Views
  # @private
  module Occurrences
    # @private
    class Show < Views::Layouts::Application
      include BacktraceRendering

      needs :project, :environment, :bug, :occurrence

      protected

      def page_title() "Occurrence of Bug ##{number_with_delimiter @bug.number} (#{@project.name} #{@environment.name.capitalize})" end

      def body_content
        full_width_section do
          return truncated_info if @occurrence.truncated?

          div(id: 'occurrence-header') do
            h1 @bug.class_name
            if @occurrence.server?
              h4 @occurrence.hostname
            elsif @occurrence.web?
              h4 @occurrence.host
            elsif @occurrence.client?
              h4 @occurrence.device_type
            end
          end

          basic_info

          h5 "Message"
          pre @occurrence.message, class: 'scrollable'

          other_occurrence_info
        end
        tabbed_section -> { tab_header }, -> { tab_content }
      end

      def tab_header
        ul(class: 'tab-header') do
          li(class: 'active') { a "Backtrace", href: '#backtrace', rel: 'tab' }
          li { a "Parents", href: '#parents', rel: 'tab' } if @occurrence.nested?
          li { a "Rails", href: '#rails', rel: 'tab' } if @occurrence.rails?
          li { a "Request", href: '#request', rel: 'tab' } if @occurrence.request?
          li { a "Process", href: '#process', rel: 'tab' } if @occurrence.server?
          li { a "Device", href: '#device', rel: 'tab' } if @occurrence.client? || @occurrence.geo? || @occurrence.mobile?
          li { a "Browser", href: '#browser', rel: 'tab' } if @occurrence.browser? || @occurrence.screen?
          li { a "User Data", href: '#user_data', rel: 'tab' } if @occurrence.additional?
        end
      end

      def breadcrumbs() [@project, @environment, @bug, @occurrence] end

      private

      def truncated_info
        if @occurrence.redirect_target
          p(class: 'alert info') do
            text "This occurrence has been moved. (This typically happens when symbolication changes the bug's static analysis.) "
            a "Continue to the moved occurrence.",
              href: project_environment_bug_occurrence_url(@project, @environment, @occurrence.redirect_target.bug, @occurrence.redirect_target)
          end
        else
          p "This occurrence has been truncated. Only basic information is available.", class: 'alert error'
        end
        basic_info
      end

      def basic_info
        p do
          text "Occurred "
          time id: 'occurred-at', datetime: @occurrence.occurred_at.xmlschema
          text " on revision "
          text! commit_link(@project, @occurrence.revision)
          text ". Reported by the #{@occurrence.client} client library."
        end
      end

      def other_occurrence_info
        if @occurrence.web?
          h5 "Request"
          pre "#{@occurrence.request_method} #{@occurrence.url.to_s}", class: 'scrollable'
        end
      end

      def tab_content
        div(class: 'tab-content tab-primary') do
          div(class: 'active', id: 'backtrace') { backtrace_tab }
          div(id: 'parents') { parents_tab } if @occurrence.nested?
          div(id: 'rails') { rails_tab } if @occurrence.rails?
          div(id: 'request') { request_tab } if @occurrence.request?
          div(id: 'process') { process_tab } if @occurrence.server?
          div(id: 'device') { device_tab } if @occurrence.client? || @occurrence.geo? || @occurrence.mobile?
          div(id: 'browser') { browser_tab } if @occurrence.browser? || @occurrence.screen?
          div(id: 'user_data') { user_data_tab } if @occurrence.additional? || !orphan_data.empty?
        end
      end

      def backtrace_tab
        render_backtraces @occurrence.backtraces, 'root'
      end

      def parents_tab
        @occurrence.parent_exceptions.each_with_index do |parent, index|
          details do
            summary do
              tt parent['class_name']
              if parent['association'].present?
                text " (via "
                tt parent['association']
                text ")"
              end
            end
            h6 "Message"
            pre parent['message'], class: 'scrollable'

            ul(class: 'pills backtrace-tabs') do
              li(class: 'active') { a "Backtraces", href: "#backtraces#{index}", rel: 'tab' }
              li { a "Instance Variables", href: "#ivars#{index}", rel: 'tab' }
            end

            div(class: 'tab-content', id: 'parents-tab-content') do
              div(class: 'active', id: "backtraces#{index}") { render_backtraces Occurrence.convert_backtraces(parent['backtraces']), "parent#{index}" }
              div(id: "ivars#{index}") { parameter_table parent['ivars'] }
            end
          end
        end
      end

      def rails_tab
        dl do
          dt "Controller"
          dd @occurrence.controller
          dt "Action"
          dd @occurrence.action
        end

        if @occurrence.session
          h4 "Session"
          parameter_table @occurrence.session
        end

        if @occurrence.flash
          h4 "Flash"
          parameter_table @occurrence.flash
        end
      end

      def request_tab
        dl do
          dt "XMLHttpRequest (Ajax)"
          dd(@occurrence.xhr? ? 'Yes' : 'No')
        end

        h4 "Parameters"
        parameter_table @occurrence.params

        h4 "Headers"
        parameter_table @occurrence.headers
      end

      def process_tab
        dl do
          dt "Hostname"
          dd @occurrence.hostname
          dt "PID"
          dd @occurrence.pid
          if @occurrence.root?
            dt "Root"
            dd @occurrence.root
          end
          if @occurrence.parent_process?
            dt "Parent Process"
            dd @occurrence.parent_process
          end
          unless @occurrence.process_native.nil?
            dt "Ran Natively?"
            dd(@occurrence.process_native? ? "Yes" : "No")
          end
          if @occurrence.process_path?
            dt "Launch Path"
            dd @occurrence.process_path
          end
          if @occurrence.arguments
            dt "Launch Arguments"
            dd { kbd @occurrence.arguments }
          end
        end

        h4 "UNIX Environment"
        parameter_table @occurrence.env_vars
      end

      def device_tab
        h4 "Device"
        dl do
          if @occurrence.device_id?
            dt "Device ID"
            dd @occurrence.device_id
          end
          dt "Type"
          dd @occurrence.device_type
          if @occurrence.architecture?
            dt "Architecture"
            dd @occurrence.architecture
          end
          dt "Operating System"
          dd do
            text @occurrence.operating_system
            if @occurrence.os_version?
              text " #{@occurrence.os_version}"
            end
            if @occurrence.os_build?
              text " (#{@occurrence.os_build})"
            end
          end
          if @occurrence.physical_memory
            dt "Physical Memory"
            dd number_to_human_size(@occurrence.physical_memory)
          end
          if @occurrence.power_state
            dt "Power State"
            dd @occurrence.power_state
          end
          if @occurrence.orientation
            dt "Orientation"
            dd @occurrence.orientation
          end
        end

        h4 "Application"
        dl do
          if @occurrence.version?
            dt "Version"
            dd @occurrence.version
          end
          dt "Build"
          dd @occurrence.build
        end

        if @occurrence.geo?
          h4 "Geolocation"

          geotag = CGI.escape([@occurrence.lat, @occurrence.lon].join(','))
          iframe height: 350, frameborder: 0, scrolling: 0, marginheight: 0, marginwidth: 0, src: "http://maps.google.com/maps?f=q&source=s_q&hl=en&geocode=&q=#{geotag}&aq=&ie=UTF8&t=m&z=13&output=embed"

          dl do
            dt "Latitude"
            dd number_to_dms @occurrence.lat, :lat
            dt "Longitude"
            dd number_to_dms @occurrence.lon, :lon
            if @occurrence.altitude?
              dt "Altitude"
              dd "#{number_with_delimiter @occurrence.altitude} m"
            end
            if @occurrence.location_precision?
              dt "Precision"
              dd number_with_delimiter(@occurrence.location_precision)
            end
            if @occurrence.heading?
              dt "Heading"
              dd "#{@occurrence.heading}°"
            end
            if @occurrence.speed?
              dt "Speed"
              dd "#{number_with_delimiter @occurrence.speed} m/s"
            end
          end
        end

        if @occurrence.mobile?
          h4 "Mobile Network"
          dl do
            dt "Operator"
            dd @occurrence.network_operator
            dt "Type"
            dd @occurrence.network_type
            if @occurrence.connectivity?
              dt "Connectivity Source"
              dd @occurrence.connectivity
            end
          end
        end
      end

      def browser_tab
        if @occurrence.browser?
          dl do
            dt "Browser"
            dd "#{@occurrence.browser_name} — version #{@occurrence.browser_version}"
            dt "Operating System"
            dd @occurrence.browser_os
            dt "Render Engine"
            dd "#{@occurrence.browser_engine} — version #{@occurrence.browser_engine_version}"
          end
        end

        if @occurrence.screen?
          dl do
            if @occurrence.screen_width
              dt "Screen Dimensions"
              dd "#{@occurrence.screen_width} × #{@occurrence.screen_height}"
            end
            if @occurrence.window_width
              dt "Window Dimensions"
              dd "#{@occurrence.window_width} × #{@occurrence.window_height}"
            end
            if @occurrence.color_depth
              dt "Color Depth"
              dd "#{@occurrence.color_depth}-bit"
            end
          end
        end
      end

      def user_data_tab
        if @occurrence.ivars.present?
          h4 "Instance Variables"
          parameter_table @occurrence.ivars
        end

        if @occurrence.user_data.present?
          h4 "User Data"
          parameter_table @occurrence.user_data
        end

        if @occurrence.extra_data.present?
          h4 "Unrecognized Fields"
          parameter_table @occurrence.extra_data
        end

        unless orphan_data.empty?
          h4 "Other Fields"
          parameter_table orphan_data
        end
      end

      def parameter_table(values)
        table(class: 'parameter') do
          thead do
            tr do
              th "Name"
              th "Class"
              th "Value"
            end
          end
          if values.blank?
            td "No values", colspan: 3, class: 'no-results'
          else
            values.sort.each do |(name, value)|
              if parameter_invalid?(value)
                tr(class: 'error') do
                  td(colspan: 3) do
                    text "Parameter "
                    tt name
                    text " has an invalid format. This is a bug in the #{@occurrence.client} client library."
                  end
                end
                next
              end

              tr do
                td { tt name }
                td do
                  klass = parameter_class(value)
                  klass.start_with?('(') ? text(klass) : tt(klass)
                end
                td do
                  if parameter_unformatted?(value)
                    text! format_parameter(value)
                  elsif parameter_primitive?(value)
                    samp value.inspect
                  else
                    if parameter_complex?(value) && (xml = value['keyed_archiver'].presence)
                      value['keyed_archiver'] = ''
                      REXML::Document.new(xml).write(value['keyed_archiver'], 1)
                    end
                    div class: 'complex-object', :'data-object' => value.to_json
                  end
                end
              end
            end
          end
        end
      end

      # @return [Hash] Any data that would have appeared in a different section
      #   (e.g., as part of {#request?}) but didn't because one of the required
      #   fields was not present.

      def orphan_data
        @orphans ||= begin
          fields = Array.new
          fields << :schema << :host << :port unless @occurrence.web?
          fields << :params << :headers unless @occurrence.request?
          fields << :controller << :action << :session << :flash unless @occurrence.rails?
          fields << :hostname << :pid unless @occurrence.server?
          fields << :build << :device_type << :architecture <<
              :operating_system << :os_version << :os_build <<
              :physical_memory << :power_state << :orientation << :version <<
              :build unless @occurrence.client?
          fields << :lat << :lon << :altitude << :location_precision <<
              :heading << :speed unless @occurrence.geo?
          fields << :network_operator << :network_type << :connectivity unless @occurrence.mobile?
          fields << :browser_name << :browser_version << :browser_os <<
              :browser_engine << :browser_engine_version unless @occurrence.browser?
          fields << :window_width << :window_height << :screen_width <<
              :screen_height << :color_depth unless @occurrence.screen?

          orphans = @occurrence.send(:_metadata_hash).slice(*fields.map(&:to_s)).reject { |_, v| v.nil? }
          # we need to valueify the top-level hashes since they will now appear
          # underneath this new top-level hash (the "orphans")
          orphans.each { |k, v| orphans[k] = Squash::Ruby.valueify(v) if orphans[k].kind_of?(Hash) }
          orphans
        end
      end
    end
  end
end
