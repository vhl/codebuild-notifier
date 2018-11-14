module CodeBuildNotifier
  class CurrentBuild
    attr_reader :build_id, :commit_hash, :git_repo_url, :status_code, :trigger

    # Default values are extracted from CODEBUILD_* ENV vars present in each
    # CodeBuild # job container.
    def initialize(
      build_id: ENV['CODEBUILD_BUILD_ID'],
      commit_hash: ENV['CODEBUILD_RESOLVED_SOURCE_VERSION'],
      git_repo: ENV['CODEBUILD_SOURCE_REPO_URL'],
      status_code: ENV['CODEBUILD_BUILD_SUCCEEDING'],
      trigger: ENV['CODEBUILD_WEBHOOK_TRIGGER']
    )
      @build_id = build_id
      @commit_hash = commit_hash
      # Handle repos specified with and without optional .git suffix.
      @git_repo_url = git_repo.to_s.gsub(/\.git\z/, '')
      @status_code = status_code
      @trigger = trigger
    end

    def status
      status_code.to_s == '1' ? 'SUCCEEDED' : 'FAILED'
    end

    def project_code
      @project_code ||= build_id.split(':').first
    end

    # If trigger is empty, this build was launched using the Retry command from
    # the console or api.
    def launched_by_retry?
      trigger.to_s.empty?
    end

    def for_pr?
      %r{^pr/}.match?(trigger.to_s)
    end

    # source_id, the primary key, is a composite of project_code and
    # trigger.
    # e.g.:
    #   my-app_ruby2-4:branch/master
    #   my-app_ruby2-3:pr/4056
    # project_code forms part of the key to support having repos with
    # multiple projects, for example, with different buildspec files for
    # different ruby versions, or for rspec vs cucumber.
    def source_id
      "#{project_code}:#{trigger}"
    end
  end
end
