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

module OccurrencesHelper
  def parameter_class(param)
    if parameter_complex?(param)
      param['class_name']
    else
      case param
        when String then "(string)"
        when Integer then "(integer)"
        when Float then "(decimal)"
        when NilClass then "(nil)"
        when TrueClass, FalseClass then "(boolean)"
        else "(#{param.class.to_s.humanize.downcase})"
      end
    end
  end

  def parameter_invalid?(param)
    parameter_class(param).nil?
  end

  def parameter_complex?(param)
    param.kind_of?(Hash)
  end

  def parameter_unformatted?(param)
    param.kind_of?(Numeric) || (param.kind_of?(String) && param.size < 50)
  end

  def parameter_primitive?(param)
    param.kind_of?(TrueClass) || param.kind_of?(FalseClass) || param.kind_of?(NilClass)
  end

  def format_parameter(param)
    case param
      when String
        if param.empty?
          content_tag :span, "(empty string)", class: 'aux'
        elsif param.blank?
          content_tag :span, "(string consisting entirely of non-printing characters)", class: 'aux'
        else
          h param
        end
      else
        h param.to_s
    end
  end
end
