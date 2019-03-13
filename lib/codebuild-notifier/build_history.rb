# codebuild-notifier
# Copyright © 2018 Adam Alboyadjian <adam@cassia.tech>
# Copyright © 2018 Vista Higher Learning, Inc.
#
# codebuild-notifier is free software: you can redistribute it
# and/or modify it under the terms of the GNU General Public
# License as published by the Free Software Foundation, either
# version 3 of the License, or (at your option) any later version.
#
# codebuild-notifier is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with codebuild-notifier.  If not, see <http://www.gnu.org/licenses/>.

require 'active_support'
require 'active_support/core_ext'
require 'aws-sdk-dynamodb'
require 'hashie'

module CodeBuildNotifier
  class BuildHistory
    attr_reader :config, :current_build

    delegate :dynamo_table, to: :config
    delegate :branch_name, :launched_by_retry?, to: :current_build

    def initialize(config, current_build)
      @config = config
      @current_build = current_build
    end

    def last_entry
      return @last_entry if defined?(@last_entry)
      # If this build was launched using the Retry command from the console
      # or api we don't have a Pull Request or branch name to use in the
      # primary key, so we query by commit hash and project instead.
      item = launched_by_retry? ? find_by_commit : find_by_id

      # Provide .dot access to hash values from Dynamo item.
      @last_entry = item && Hashie::Mash.new(item)
    end

    def write_entry(source_id)
      updates = hash_to_dynamo_update(new_entry).merge(
        key: {
          source_id: source_id,
          version_key: version_key
        }
      )

      yield updates if block_given?

      dynamo_client.update_item(
        updates.merge(table_name: dynamo_table)
      )
    end

    # The commit hash and project code are used to find which Pull Request
    # or branch the current build belongs to, and the previous build status
    # for that Pull Request or branch.
    private def find_by_commit
      find_latest_version(
        expression_attribute_values: commit_values,
        filter_expression: commit_filter,
        index_name: 'commit_hash_index',
        key_condition_expression: 'commit_hash = :commit_hash'
      )
    end

    # When searching by commit hash, if the current build source version
    # is for a PR, only return commits with that PR as the source ref.
    # If source version is not for a pr, only return source refs beginning
    # with branch/. This helps protect against the edge case where the same
    # commit appears in two different PRs, or in a PR and whitelisted branch
    # besides than the PR head.
    private def commit_values
      source_ref_val = if current_build.for_pr?
                         current_build.source_version
                       else
                         'branch/'
                       end
      {
        ':commit_hash' => current_build.commit_hash,
        ':project_code' => current_build.project_code,
        ':source_ref' => source_ref_val
      }
    end

    private def commit_filter
      source_ref_condition = if current_build.for_pr?
                               'source_ref = :source_ref'
                             else
                               'begins_with(source_ref, :source_ref)'
                             end
      "project_code = :project_code AND #{source_ref_condition}"
    end

    private def find_by_id
      find_latest_version(
        expression_attribute_values: {
          ':source_id' => current_build.source_id
        },
        key_condition_expression: 'source_id = :source_id'
      )
    end

    private def find_latest_version(args)
      dynamo_client.query(
        args.merge(
          scan_index_forward: false, # Reverse sort by range key
          table_name: dynamo_table
        )
      ).items.first
    end

    private def new_entry
      current_build.history_fields.tap do |memo|
        # If launched via manual re-try instead of via a webhook, we don't
        # want to overwrite the current source_ref value that tells us which
        # branch or pull request originally created the dynamo record.
        unless launched_by_retry?
          memo[:source_ref] = current_build.trigger
          memo[:branch_name] = branch_name unless branch_name.empty?
        end
      end
    end

    # The first component of the version_key is the timestamp for the
    # first build of the current commit hash. The second component
    # is the timestamp for the current build. This allows easily finding
    # either the latest commit, or the latest re-build of a commit.
    private def version_key
      if launched_by_retry?
        "#{last_entry.start_time}_#{current_build.start_time}"
      else
        "#{current_build.start_time}_#{current_build.start_time}"
      end
    end

    private def hash_to_dynamo_update(hash)
      update = hash.each_with_object(
        expression_attribute_names: {},
        expression_attribute_values: {},
        update_expression: []
      ) do |(key, value), memo|
        memo[:expression_attribute_names]["##{key}"] = key.to_s
        memo[:expression_attribute_values][":#{key}"] = value
        memo[:update_expression] << "##{key} = :#{key}"
      end
      update.merge(update_expression: "SET #{update[:update_expression].join(', ')}")
    end

    private def dynamo_client
      @dynamo_client || Aws::DynamoDB::Client.new(region: config.region)
    end
  end
end
