// Copyright 2013 Square Inc.
//
//    Licensed under the Apache License, Version 2.0 (the "License");
//    you may not use this file except in compliance with the License.
//    You may obtain a copy of the License at
//
//        http://www.apache.org/licenses/LICENSE-2.0
//
//    Unless required by applicable law or agreed to in writing, software
//    distributed under the License is distributed on an "AS IS" BASIS,
//    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//    See the License for the specific language governing permissions and
//    limitations under the License.

// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or vendor/assets/javascripts of plugins, if any, can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// the compiled file.
//
// WARNING: THE FIRST BLANK LINE MARKS THE END OF WHAT'S TO BE PROCESSED, ANY BLANK LINE SHOULD
// GO AFTER THE REQUIRES BELOW.
//
//= require jquery
//= require jquery_ujs
//
//= require jquery-cookie
//= require jquery-leanModal
//= require jquery-timers
//
//= require flot/flot
//= require flot/resize
//= require flot/stack
//= require flot/time
//
//= require sh/manifest
//
//= require bootstrap
//
//= require squash_javascript
//= require configure_squash_client
//
//= require accordion
//= require autocomplete
//= require bug_file_formatter
//= require buttons
//= require context
//= require disclosure
//= require dropdown
//= require dynamic_search_field
//= require editor_links
//= require email_alias_form
//= require error_tooltip
//= require feed
//= require flash
//= require form_with_errors
//= require live_update
//= require member_panel
//= require search
//= require smart_form
//= require sortable_table
//= require tabs
//= require utilities
//= require value_inspector
//
//= require aggregation
//= require histogram
//
//= require navbar

$(document).ready(function() {
  // run SyntaxHighlighter on PREs
  SyntaxHighlighter.all();

  // enable leanModal on all modal links
  $("a[rel*=modal]").leanModal({closeButton: '.close'});
  $("button[rel*=modal]").leanModal({closeButton: '.close'});
});

$.ajaxSetup({
  headers: { 'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content') }
});
