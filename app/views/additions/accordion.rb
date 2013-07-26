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

# Adds methods for creating Bootstrap accordions to your Erector widget.

module Accordion

  # Creates a new accordion. Yields an {AccordionBuilder} that allows you to add
  # items to the accordion.
  #
  # @param [String] id The unique ID of the DOM element to create.
  # @param [Hash<Symbol, String>] options Additional attributes to apply to the
  #   DIV tag.
  # @yield [builder] A block in which to build accordion items.
  # @yieldparam [AccordionBuilder] builder The object that builds the accordion
  #   items.

  def accordion(id, options={})
    options[:class] = "#{options[:class]} accordion"
    div(options.merge(id: id)) { yield AccordionBuilder.new(id, self) }
  end
end

# Proxy object that adds accordion items to an accordion.

class AccordionBuilder
  # @private
  def initialize(id, receiver)
    @id = id
    @receiver = receiver
  end

  # Creates a collapsible accordion item.
  #
  # @param [String] id The unique ID of the DOM element to create.
  # @param [String] title The text of the item's title bar.
  # @param [true, false] visible Whether or not this accordion item is visible
  #   initially.
  # @yield The markup to place into the accordion item's body.

  def accordion_item(id, title, visible=false, &block)
    @receiver.div(id: id, class: "accordion-pair #{visible ? 'shown' : nil}") do
      @receiver.h5 { @receiver.a title, rel: 'accordion', href: "##{id}" }
      @receiver.div({style: (visible ? nil : 'display: none')}, &block)
    end
  end
end
