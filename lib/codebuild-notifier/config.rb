module CodeBuildNotifier
  class Config
    DEFAULT_WHITELIST = %w[master release]

    attr_reader :additional_channel, :dynamo_table, :region, :slack_admins,
                :slack_secret_name, :whitelist_branches

    # Configuration values specific to CodeBuild Notifier. CBN_ prefix is
    # used because ENV vars with CODEBUILD_ prefix are reserved for use by AWS.
    def initialize(
      additional_channel: ENV['CBN_ADDITIONAL_CHANNEL'],
      dynamo_table: ENV['CBN_DYNAMO_TABLE'] || 'branch-build-status',
      region: ENV['CBN_AWS_REGION'] || ENV['AWS_REGION'],
      slack_admins: ENV['CBN_SLACK_ADMIN_USERNAMES'],
      slack_secret_name: ENV['CBN_SLACK_SECRET_NAME'] || 'slack/codebuild',
      whitelist_branches: ENV['CBN_WHITELIST_BRANCHES']
    )
      @additional_channel = additional_channel
      @dynamo_table = dynamo_table
      @region = region
      @slack_admins = slack_admins&.split(',') || []
      @slack_secret_name = slack_secret_name
      @whitelist_branches = whitelist_branches&.split(',') || DEFAULT_WHITELIST
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
