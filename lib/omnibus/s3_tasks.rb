#
# Copyright:: Copyright (c) 2012 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

module Omnibus
  module S3Tasks
    extend Rake::DSL

    def self.define!
      require 'uber-s3'

      namespace :s3 do
        desc "List source packages which have the correct source package in the S3 cache"
        task :existing do
          S3Cache.new.list.each {|s| puts s.name}
        end

        desc "List all cached files (by S3 key)"
        task :list do
          S3Cache.new.list_by_key.each {|k| puts k}
        end

        desc "Lists source packages that are required but not yet cached"
        task :missing do
          S3Cache.new.missing.each {|s| puts s.name}
        end

        desc "Fetches missing source packages to local tmp dir"
        task :fetch do
          S3Cache.new.fetch_missing
        end

        desc "Populate the S3 Cache"
        task :populate do
          S3Cache.new.populate
        end

      end
    rescue LoadError

      desc "S3 tasks not available"
      task :s3 do
        puts(<<-F)
The `uber-s3` gem is required to cache new source packages in S3.
F
      end
    end
  end
end
