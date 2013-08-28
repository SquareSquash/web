#
# Copyright 2013 Cerner Corporation.
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
#

require 'YAML'
require 'base64'
require 'tempfile'
require 'Logger'

#
# The main driver for SquashIosCrashLogSymbolication.
#
# Used in conjunction with SquareSquash using the modified SquareSquash Cocoa library.
# The script leveraging this class will convert and symbolicate plcrashlog formatted
# user_info values from metadata column for iOS crash occurrences into crash_log value
# of metadata column in occurrence table within the SquareSquash postgres database.
#
# Note: this class requires configuration files:
#   config/symbolication_paths.yml
#   config/database.yml

class SquashIosCrashLogSymbolication
    
    # Configuration filename
    ConfigurationFileName = "symbolication_paths.yml"
    
    # Database configuration filename
    DatabaseConnectionConfigFileName = "database.yml"

    #
    # if we are in a Rails environment, use the Rails logger
    # otherwise use STDOUT
    #
    def self.logger
        (@logger ||=
            begin
                if(Rails)
                    Rails.logger
                end
            rescue Exception => ex
                Logger.new(STDOUT)
            end
        )
    end

    # Config environment to use:
    # 'development', 'test', or 'production'
    def self.env
        @env ||= ENV['env'] || 'development'
    end

    #
    # This method takes the unsymbolicated data, and the environment value
    # The squash_symbolicate_ios_crash cronscript uses this method in the
    # symbolication process. The SquareSquash web app can also use this method
    # if SquareSquash web app is installed and configured on a Mac.
    #
    #
    # Fully symbolicate your iOS crash logs stored in SquareSquash using Xcode and plcrashutil
    #
    # Arguments:
    #   user_data: a hashmap with a key containing 'PLCrashLog' which holds the iOS unsymbolicated, base64-encoded plcrashlog data
    #   environment: 'development' (default), 'test' or 'production'
    #
    # Return:
    #   crash_log: set to the contents of the symbolicated crash log
    #
    def self.symbolicate_crash(user_data, env = 'development')
        @env = env

        if (user_data.nil?)
            self.logger.warn 'symbolicate_crash: user_data is nil'
            return nil
        end

        # create temp filenames
        now = Time.now
        plcrash_filename = 'CrashLog.plcrash.' + now.to_i.to_s
        crash_log_filename = 'CrashLog.crash.' + now.to_i.to_s
        crash_log_done_filename = 'CrashLog.crash.done.' + now.to_i.to_s
        # create temp files
        pl_crash_log_file = Tempfile.new(plcrash_filename)
        pl_crash_log_file.binmode # <-- binary mode
        crash_log_file = Tempfile.new(crash_log_filename)
        crash_log_done_file = Tempfile.new(crash_log_done_filename)

        # grab PLCrashLog out of 'user_data', decode, and write Tempfile CrashLog.plcrash.XXXXXXX
        pl_crash_log = Base64.urlsafe_decode64(user_data["PLCrashLog"])

        pl_crash_log_file.write(pl_crash_log)
        pl_crash_log_file.close
        self.logger.info "#{pl_crash_log_file.path} written"

        # exec plcrashutil to convert to Xcode crash log format
        command = "#{SquashIosCrashLogSymbolication.plcrashutil_path} convert --format=ios #{pl_crash_log_file.path} > #{crash_log_file.path}"
        self.logger.info "executing #{command}..."

        # $? # The exit status of the last process terminated.
        output = `#{command}`; result=$?
        if($?.exitstatus == 0)
            self.logger.info "converted #{pl_crash_log_file.path} to #{crash_log_file.path}"

            # Use symbolicatecrash script from Xcode
            command = "#{SquashIosCrashLogSymbolication.symbolicatecrash_path} -o #{crash_log_done_file.path} #{crash_log_file.path} #{SquashIosCrashLogSymbolication.symbol_path}"
            self.logger.info "executing #{command}..."
            # $? # The exit status of the last process terminated.
            output = `#{command}`; result=$?
            if($?.exitstatus == 0)
                self.logger.info "symbolicated crash log to #{crash_log_done_file.path}"
            else
                self.logger.error "failed to symbolicate crash log to #{crash_log_done_file.path} - #{output}"
            end
        else
            self.logger.error "failed to converted #{pl_crash_log_file.path} to #{crash_log_file.path} - #{output}"
        end

        # now read the symbolicated crash log
        if (File.exists?("#{crash_log_done_file.path}"))
            symbolicated_crash_contents = File.read("#{crash_log_done_file.path}",File.size("#{crash_log_done_file.path}"))

            # set crash_log to our symbolicated crashlog contents
            crash_log = symbolicated_crash_contents

            begin
                # clean up
                crash_log_file.close
                crash_log_done_file.close
                pl_crash_log_file.unlink
                crash_log_file.unlink
                crash_log_done_file.unlink

            rescue Exception => ex
                self.logger.error "symbolicate_crash file clean up Exception:\n #{ex.to_s}"
                self.logger.error ex.message
                self.logger.error ex.backtrace.join("\n")
            end
        end

        crash_log # return nil or symbolicated crash log contents
    end

    #
    # This method is a wrapper to call bin/squash_symbolicate_ios_crash
    # It connects to PostgreSQL, selects the unsymbolicated data from the
    # occurrence table, symbolicates using commandline scripts, then makes
    # another connection to the database and performs an update, removing
    # the unsymbolicated data and inserting the symbolicated data.
    #
    # Example:
    #   => squash_symbolicate_ios_crash development
    #
    # Arguments:
    #   environment: 'development', 'test' or 'production'
    #
    def self.symbolicate(env = nil)
        @env = env
        # exec squash_symbolicate_ios_crash
        script = File.join("#{ENV['PWD']}", 'bin', 'squash_symbolicate_ios_crash')

        command = "#{script} #{env} 2>&1"
        puts "executing #{command}"

        # $? # The exit status of the last process terminated.
        output = `#{command}`; result=$?
        puts output
        return result
    end

    # If this is running on OS X, return true
    def self.osx?
        if RUBY_PLATFORM =~ /darwin/i
            true
        else
            false
        end
    end

    # Path to Xcode's symbolicatecrash script
    def self.symbolicatecrash_path
        symbolicatecrash_path = symbolication_paths_config['symbolicationcrash']
    end

    # Path to Xcode
    def self.xcode_path
        if (self.symbolicatecrash_path =~ /Xcode\.app/)
            $~.pre_match
        else
            nil
        end
    end

    # Path to PLCrashReporter's plcrashutil
    def self.plcrashutil_path
        symbolication_paths_config['plcrashutil']
    end

    # Path to Application symbols
    def self.symbol_path
        symbolication_paths_config['symbolpath']
    end

    #
    # = Configuration
    #

    # Search LOAD_PATH for config/filename
    # return path to config
    def self.config_path(filename)
        path = $LOAD_PATH.find { |dir|
            file = File.join(dir, '..', 'config', filename)
            # puts file
            File.exists?(file)
        }
        path ? File.join(path, '..', 'config') : 'config'
    end

    # The path to the database configuration file
    def self.symbolication_database_config_file
        File.join(config_path(DatabaseConnectionConfigFileName), DatabaseConnectionConfigFileName)
    end


    # The database configuration
    def self.symbolication_database_config
        (@database ||= YAML::load(File.read(symbolication_database_config_file)))[env]
    end

    # The path to the configuration file
    def self.symbolication_paths_config_file
        File.join(config_path(ConfigurationFileName), ConfigurationFileName)
    end

    # The path to the configuration file
    def self.symbolication_paths_config
        (@configuration ||= YAML::load(File.read(symbolication_paths_config_file)))[env]
    end
end

