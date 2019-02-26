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

module CodeBuildNotifier
  class Config
    DEFAULT_WHITELIST = %w[master release]

    attr_reader :additional_channel, :default_strategy, :dynamo_table, :region,
                :slack_admins, :slack_secret_name, :whitelist_branches

    # Configuration values specific to CodeBuild Notifier. CBN_ prefix is
    # used because ENV vars with CODEBUILD_ prefix are reserved for use by AWS.
    def initialize(
      additional_channel: ENV['CBN_ADDITIONAL_CHANNEL'],
      default_strategy: ENV['CBN_DEFAULT_NOTIFY_STRATEGY'] || 'fail_or_status_change',
      dynamo_table: ENV['CBN_DYNAMO_TABLE'] || 'branch-build-status',
      region: ENV['CBN_AWS_REGION'] || ENV['AWS_REGION'],
      slack_admins: ENV['CBN_SLACK_ADMIN_USERNAMES'],
      slack_secret_name: ENV['CBN_SLACK_SECRET_NAME'] || 'slack/codebuild',
      strategy_overrides: ENV['CBN_OVERRIDE_NOTIFY_STRATEGY'],
      whitelist_branches: ENV['CBN_WHITELIST_BRANCHES']
    )
      @additional_channel = additional_channel
      @default_strategy = default_strategy
      @dynamo_table = dynamo_table
      @region = region
      @slack_admins = slack_admins&.split(',') || []
      @slack_secret_name = slack_secret_name
      @strategy_overrides = strategy_overrides&.split(',') || []
      @whitelist_branches = whitelist_branches&.split(',') || DEFAULT_WHITELIST
    end

    def strategy_for_branch(branch_name)
      lookup = @strategy_overrides.map { |override| override.split(':') }.to_h
      lookup.fetch(branch_name, default_strategy)
    end

    # Match the format of the CodeBuild trigger variable
    def non_pr_branch_ids
      whitelist_branches.map { |name| "branch/#{name}" }
    end

    def whitelist
      whitelist_branches.join(', ')
    end
  end
end
