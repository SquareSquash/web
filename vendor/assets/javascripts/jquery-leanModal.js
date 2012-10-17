// This code is based on leanModal by Ray Stone, which is distributed under the
// MIT license:
//
// Copyright (c) 2012 Ray Stone
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
// This modified version is sublicensed under the Apache License:
//
// Copyright 2012 Square Inc.
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

(function($) {
  var close_modal = function(modal) {
    $("#lean_overlay").fadeOut(200);
    modal.css({ 'display': 'none' });
  };

  var showModal = function(modal, o) {
    $("#lean_overlay").click(function() { close_modal(modal); });
    $(o.closeButton).click(function() { close_modal(modal); });

    var modal_height = modal.outerHeight();
    var modal_width = modal.outerWidth();

    $('#lean_overlay').css({ 'display': 'block', opacity: 0 });
    $('#lean_overlay').fadeTo(200, o.overlay);

    modal.css({

                'display':     'block',
                'position':    'fixed',
                'opacity':     0,
                'z-index':     11000,
                'left':        50 + '%',
                'margin-left': -(modal_width / 2) + "px",
                'top':         o.top + "px"

              });
    modal.fadeTo(200, 1);
  };

  $.fn.extend({
                leanModal: function(options) {
                  var defaults = {
                    top:         100,
                    overlay:     0.5,
                    closeButton: null
                  };

                  var overlay = $("<div id='lean_overlay'></div>");
                  $("body").append(overlay);

                  options = $.extend(defaults, options);
                  return this.each(function() {
                    var o = options;
                    $(this).click(function(e) {
                      var modal_id = $(this).attr("href");
                      var modal = $(modal_id);
                      showModal(modal, o);
                      e.preventDefault();
                    });
                  });
                },

                showModal: function(options) {
                  var defaults = {
                    top:         100,
                    overlay:     0.5,
                    closeButton: null
                  };

                  var overlay = $("<div id='lean_overlay'></div>");
                  $("body").append(overlay);

                  options = $.extend(defaults, options);
                  showModal($(this), options);
                }
              });
})(jQuery);
