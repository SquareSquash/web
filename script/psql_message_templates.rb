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

# Loads PostgreSQL message templates from the PostgreSQL source localization
# files.

require 'yaml'

SIGILS = {
    '%d'     => [/-?\d+/, '[NUMBER]'],
    '%s'     => [/.*?/, '[STRING]'],
    '%m'     => [/.*?/, '[ERROR]'],
    '%X'     => [/[0-9A-F]+/, '[HEX]'],
    '%u'     => [/\d+/, '[NUMBER]'],
    '%g'     => [/-?\d+(\.\d+)?(e-?\d+)?/, '[NUMBER]'],
    '%lu'    => [/\d+/, '[NUMBER]'],
    '%ld'    => [/-?\d+/, '[NUMBER]'],
    '%c'     => [/./, '[CHAR]'],
    '%f'     => [/-?\d+(\.\d+)?/, '[NUMBER]'],
    /%0\dX/  => [/[0-9A-F]+/, '[HEX]'],
    '%i'     => [/-?\d+/, '[NUMBER]'],
    /%0\dd/  => [/-?\d+/, '[NUMBER]'],
    '%o'     => [/[0-7]+/, '[OCTAL]'],
    /%0\dx/  => [/[0-9a-f]+/, '[NUMBER]'],
    /%\.\df/ => [/-?\d+\.\d+/, '[NUMBER]']
}

def process_directory(tree)
  files = `git --git-dir=tmp/repos/postgres.git ls-tree #{tree}`.chomp.split(/\n/).map { |line| line.split(/\s+/) }
  files.each do |(_, type, sha, name)|
    case type
      when 'blob'
        next unless name[-2..-1] == '.c'
        process_file sha
      when 'tree'
        puts "processing tree #{name}"
        process_directory sha
    end
  end
end

def process_file(blob)
  content = `git --git-dir=tmp/repos/postgres.git cat-file blob #{blob}`.force_encoding('ISO-8859-1').chomp
  content.scan(/ereport\(ERROR,\s*\(\s*errcode\(\w+\)\s*,\s*errmsg\("(.*?[^\\])"[\),]/m).each do |(message)|
    message.gsub! /"\s*\\?\n\s*"/, ''
    message.gsub! '\\"', '"'
    message.gsub! '\\\\', '\\'

    rx     = Regexp.escape(message)
    output = message.dup
    SIGILS.each do |sigil, (sigil_rx, replacement)|
      rx.gsub! sigil, sigil_rx.to_s
      output.gsub! sigil, replacement
    end

    next if output =~ /^\s*(\[STRING\]\s*)*$/
    next if @templates['PGError'].any? { |(other_rx, other_output)| other_output == output }

    @templates['PGError'] << [Regexp.compile(rx), output]
  end
end

yaml_path             = File.dirname(__FILE__) + '/../data/message_templates.yml'
@templates            = YAML.load_file(yaml_path)
@templates['PGError'] = []

if Dir.exist?('tmp/repos/postgres.git')
  system 'git', '--git-dir=tmp/repos/postgres.git', 'fetch'
else
  system 'git', 'clone', '--mirror', 'git://github.com/postgres/postgres.git', 'tmp/repos/postgres.git'
end
system 'git', '--git-dir=tmp/repos/postgres.git', 'fetch', '--tags'

%w(REL7_2 REL7_3 REL7_4 REL8_0_0 REL8_1_0 REL8_2_0 REL8_3_0 REL8_4_0
   REL9_0_0 REL9_1_0 REL9_2_0).each do |tag|
  process_directory("#{tag}^{tree}")
end

@templates['PGError'].sort_by! { |_, msg| -msg.length }

File.open(yaml_path, 'w') { |f| f.puts @templates.to_yaml }
