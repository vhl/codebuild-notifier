module CodeBuildNotifier
  # Provides access to build state and configuration settings extracted
  # from ENV vars.
  module Environment
    ## Values extracted from CODEBUILD_* ENV vars present in each CodeBuild
    # job container.
    def build_id
      ENV['CODEBUILD_BUILD_ID']
    end

    def commit_hash
      ENV['CODEBUILD_RESOLVED_SOURCE_VERSION']
    end

    def current_status
      ENV['CODEBUILD_BUILD_SUCCEEDING'].to_s == '1' ? 'SUCCEEDED' : 'FAILED'
    end

    def project_code
      build_id.split(':').first
    end

    def trigger
      # Uses .to_s to ensure consistent behaviour when ENV var does not exist,
      # and when it exists but has no value.
      ENV['CODEBUILD_WEBHOOK_TRIGGER'].to_s
    end

    def git_repo
      ENV['CODEBUILD_SOURCE_REPO_URL'].gsub(/\.git\z/, '')
    end

    ## Configuration values specific to CodeBuild Notifier. CB_ prefix is
    # used because ENV vars with CODEBUILD_ prefix are reserved for use by AWS.

    def dynamo_table_name
      ENV['CB_NOTIFIER_DYNAMO_TABLE_NAME'] || 'branch-build-status'
    end

    def secrets_manager_slack_secret_name
      ENV['CB_NOTIFIER_SLACK_SECRET_NAME'] || 'slack/codebuild'
    end

    def whitelisted_branches
      env_branch_names = ENV['CB_NOTIFIER_NON_PULL_REQUEST_BRANCHES']
      env_branch_names&.split(',') || %w[master release]
    end

    def region
      ENV['AWS_REGION']
    end
  end
end
